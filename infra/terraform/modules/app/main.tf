# =============================================================================
# modules/app/main.tf
# 应用层容器模块：Spring Boot API（多副本）+ React Frontend
#
# 部署特点（对应 TECH_SPEC 8.1 应用层双副本）：
#   - dev/test：1 个 API 实例
#   - staging/prod：2 个 API 实例，由 Nginx 做负载均衡
#   - 所有 API 实例连接同一主库 + 只读副本（读写分离）
#   - 批量评分线程池与 API 线程池物理隔离（通过 JVM 参数控制）
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# ── 拉取 API 镜像 ─────────────────────────────────────────────────────────────
resource "docker_image" "api" {
  name         = var.api_image
  keep_locally = true
}

resource "docker_image" "frontend" {
  name         = var.frontend_image
  keep_locally = true
}

# ── Spring Boot API 容器（支持多副本，count 控制）────────────────────────────
resource "docker_container" "api" {
  count   = var.api_replica_count
  name    = "scrm-${var.env}-api-${count.index}"
  image   = docker_image.api.image_id
  restart = "unless-stopped"

  memory     = var.api_memory_mb
  cpu_shares = var.api_cpu_shares

  # ─────────────────────────────────────────────────────────────────────────
  # 环境变量（敏感值通过 TF_VAR 注入，不进 git）
  # 命名规范：{SERVICE}_{CATEGORY}_{NAME}（CLAUDE.md 4.2）
  # ─────────────────────────────────────────────────────────────────────────
  env = [
    # ── Spring 应用配置 ────────────────────────────────────
    "SPRING_PROFILES_ACTIVE=${var.app_env}",
    "APP_ENV=${var.app_env}",
    "APP_LOG_LEVEL=${var.app_log_level}",
    "SERVER_PORT=${var.api_port}",

    # ── JVM 参数（虚拟线程 Java 17 + G1GC）────────────────
    "JAVA_OPTS=${var.api_java_opts} -Dspring.application.name=scrm-api-${count.index}",

    # ── PostgreSQL 主库（写操作） ───────────────────────────
    "DB_HOST=${var.db_host}",
    "DB_PORT=${var.db_port}",
    "DB_NAME=${var.db_name}",
    "DB_USERNAME=${var.db_user}",
    "DB_PASSWORD=${var.db_password}",
    # HikariCP 连接池配置
    "DB_POOL_MAX_SIZE=${var.hikari_max_pool_size}",
    "DB_POOL_MIN_IDLE=2",
    "DB_POOL_CONNECTION_TIMEOUT_MS=30000",
    "DB_POOL_IDLE_TIMEOUT_MS=600000",
    "DB_POOL_MAX_LIFETIME_MS=1800000",

    # ── PostgreSQL 只读副本（@Transactional(readOnly=true)）
    "DB_READONLY_HOST=${var.db_host_readonly}",
    "DB_READONLY_PORT=${var.db_port}",
    "DB_READONLY_NAME=${var.db_name}",
    "DB_READONLY_USERNAME=${var.db_user}",
    "DB_READONLY_PASSWORD=${var.db_password}",

    # ── Redis ──────────────────────────────────────────────
    "REDIS_HOST=${var.redis_host}",
    "REDIS_PORT=${var.redis_port}",
    "REDIS_PASSWORD=${var.redis_password}",

    # ── Kafka ──────────────────────────────────────────────
    "KAFKA_BOOTSTRAP_SERVERS=${var.kafka_bootstrap_servers}",
    # 消费者组（每个副本共享同一组，Kafka 按分区分配消费任务）
    "KAFKA_CONSUMER_GROUP_ID=scrm-${var.env}-api",
    # 消息消费失败重试策略（最多 3 次，指数退避，TECH_SPEC 6.2 约束 #7）
    "KAFKA_CONSUMER_MAX_RETRY=3",
    "KAFKA_CONSUMER_RETRY_BACKOFF_MS=1000",

    # ── MinIO ──────────────────────────────────────────────
    "MINIO_ENDPOINT=${var.minio_endpoint}",
    "MINIO_ACCESS_KEY=${var.minio_access_key}",
    "MINIO_SECRET_KEY=${var.minio_secret_key}",
    "MINIO_BUCKET_REPORTS=scrm-reports",
    "MINIO_PRESIGNED_URL_TTL_MINUTES=15",

    # ── JWT（无默认值，密钥为空则拒绝启动，CLAUDE.md 4.3）──
    "JWT_SECRET=${var.jwt_secret}",
    "JWT_ACCESS_TOKEN_TTL_SECONDS=${var.jwt_access_token_ttl_seconds}",
    "JWT_REFRESH_TOKEN_TTL_SECONDS=${var.jwt_refresh_token_ttl_seconds}",

    # ── XXL-Job 执行器注册 ─────────────────────────────────
    "XXLJOB_ADMIN_URL=${var.xxljob_admin_url}",
    "XXLJOB_ACCESS_TOKEN=${var.xxljob_access_token}",
    "XXLJOB_EXECUTOR_PORT=${9000 + count.index}",  # 每副本不同端口，避免冲突
    "XXLJOB_EXECUTOR_APP_NAME=scrm-executor-${var.env}",

    # ── 批量评分线程池（与 API 线程池物理隔离，TECH_SPEC 7.4）
    "SCRM_SCORING_EXECUTOR_CORE_POOL_SIZE=8",
    "SCRM_SCORING_EXECUTOR_MAX_POOL_SIZE=16",
    "SCRM_SCORING_EXECUTOR_QUEUE_CAPACITY=200",

    # ── 外部 API 超时（TECH_SPEC 6.2 约束 #6）─────────────
    "EXT_HTTP_CONNECT_TIMEOUT_SECONDS=3",
    "EXT_HTTP_READ_TIMEOUT_SECONDS=10",
  ]

  # ── 挂载：应用日志目录（JSON 格式，对接 ELK）─────────────
  volumes {
    host_path      = "${var.host_log_path}/api-${count.index}"
    container_path = "/app/logs"
  }

  # ── 挂载：临时文件目录（报告生成中间产物）───────────────
  volumes {
    host_path      = "${var.host_log_path}/../tmp/api-${count.index}"
    container_path = "/tmp/scrm"
  }

  # ── 健康检查（对应 TECH_SPEC 8.4 liveness/readiness）────
  healthcheck {
    # readiness 检查：包含 DB + Redis 连通性验证
    test         = ["CMD-SHELL", "curl -f http://localhost:${var.api_port}/actuator/health/readiness || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "90s"  # Spring Boot 启动 + Flyway 迁移时间
  }

  networks_advanced {
    name    = var.network_name
    # 每个实例有唯一别名，Nginx upstream 可寻址
    aliases = ["api-${count.index}", "scrm-${var.env}-api-${count.index}"]
  }

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "api"
  }
  labels {
    label = "com.scrm.instance"
    value = tostring(count.index)
  }
}

# ── React 前端容器（Nginx 静态资源服务）──────────────────────────────────────
# 前端 build 产物打包进镜像，由此容器的 /usr/share/nginx/html 提供
# 网关层 Nginx 反代此容器（或直接 root 指向 volume，视 CI/CD 方式而定）
resource "docker_container" "frontend" {
  name    = "scrm-${var.env}-frontend"
  image   = docker_image.frontend.image_id
  restart = "unless-stopped"

  memory     = var.frontend_memory_mb
  cpu_shares = 256

  env = [
    # 前端运行时注入（Vite 构建后可通过 window.ENV 或 /config.js 动态读取）
    "VITE_API_BASE_URL=/api",
    "VITE_APP_ENV=${var.app_env}",
  ]

  volumes {
    host_path      = "${var.host_log_path}/frontend"
    container_path = "/var/log/nginx"
  }

  healthcheck {
    test         = ["CMD-SHELL", "wget -q -O /dev/null http://localhost:80/index.html || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["frontend"]
  }

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "frontend"
  }
}
