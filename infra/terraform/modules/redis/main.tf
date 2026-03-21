# =============================================================================
# modules/redis/main.tf
# Redis 7 容器模块
#
# 缓存职责（对应 TECH_SPEC 7.2 缓存策略）：
#   - 风险看板统计：Hash，TTL 10min（±随机抖动防雪崩）
#   - 供应商画像 Tab 数据：Hash per Tab，TTL 24h（±30min 随机抖动）
#   - 列表热门筛选组合：String，TTL 5min（±30s 抖动）
#   - Session / Refresh Token：String，TTL 7d（AES-256 加密存储）
#   - 缓存穿透防护：空值 TTL 60s
#
# 安全：密码认证 + 禁用危险命令（KEYS/FLUSHALL）
# 持久化：AOF everysec + RDB 快照（dev 关闭 AOF）
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "redis" {
  name         = "redis:7.2-alpine"
  keep_locally = true
}

# ── Redis 数据卷（AOF + RDB 持久化文件）──────────────────────────────────────
resource "docker_volume" "redis_data" {
  name = "scrm-${var.env}-redis-data"

  lifecycle {
    prevent_destroy = true
  }
}

# ── Redis 配置文件（通过 local_file 生成，挂载到容器）──────────────────────
resource "local_file" "redis_conf" {
  filename        = "${path.module}/.generated/${var.env}/redis.conf"
  file_permission = "0640"

  content = <<-EOF
    # =====================================================
    # Redis 配置 — 环境: ${var.env}
    # 由 Terraform 自动生成，请勿手动修改
    # =====================================================

    # ── 网络 ──────────────────────────────────────────────
    bind 0.0.0.0
    port 6379
    protected-mode yes

    # ── 认证（禁止匿名访问）────────────────────────────────
    requirepass ${var.redis_password}

    # ── 内存管理 ───────────────────────────────────────────
    maxmemory ${var.maxmemory_mb}mb
    maxmemory-policy ${var.maxmemory_policy}
    # 所有 Key 必须设置 TTL，禁止永不过期（TECH_SPEC 6.2 约束 #10）
    # 应用层通过 RedisTemplate.expire() 强制设置

    # ── 持久化：AOF ─────────────────────────────────────────
    appendonly ${var.enable_aof ? "yes" : "no"}
    appendfilename "appendonly.aof"
    appendfsync ${var.aof_fsync}
    no-appendfsync-on-rewrite no
    auto-aof-rewrite-percentage 100
    auto-aof-rewrite-min-size 64mb

    # ── 持久化：RDB 快照 ────────────────────────────────────
    ${var.enable_rdb ? "save 3600 1\nsave 300 100\nsave 60 10000" : "save \"\""}
    dbfilename dump.rdb
    dir /data

    # ── 安全：禁用高危命令（防止误操作清空缓存）────────────
    rename-command KEYS     ""
    rename-command FLUSHALL ""
    rename-command FLUSHDB  ""
    rename-command DEBUG    ""
    rename-command CONFIG   "CONFIG_ADMIN_${substr(md5(var.redis_password), 0, 8)}"

    # ── 慢查询日志 ──────────────────────────────────────────
    slowlog-log-slower-than 10000    # 超过 10ms 记录
    slowlog-max-len 128

    # ── 客户端超时 ──────────────────────────────────────────
    timeout 300                      # 5 分钟空闲断开
    tcp-keepalive 60

    # ── 连接数 ──────────────────────────────────────────────
    maxclients 256

    # ── 日志 ────────────────────────────────────────────────
    loglevel notice
    logfile /var/log/redis/redis.log

    # ── 延迟监控 ────────────────────────────────────────────
    latency-monitor-threshold 100    # 超过 100ms 记录延迟事件
    latency-history-event-count 10
  EOF
}

# ── Redis 容器 ────────────────────────────────────────────────────────────────
resource "docker_container" "redis" {
  name    = "scrm-${var.env}-redis"
  image   = docker_image.redis.image_id
  restart = "unless-stopped"

  # ── 资源限制 ─────────────────────────────────────────────
  memory     = var.memory_mb
  cpu_shares = var.cpu_shares

  # ── 挂载：配置文件 ────────────────────────────────────────
  volumes {
    host_path      = abspath(local_file.redis_conf.filename)
    container_path = "/etc/redis/redis.conf"
    read_only      = true
  }

  # ── 挂载：持久化数据目录（AOF + RDB 文件）────────────────
  volumes {
    volume_name    = docker_volume.redis_data.name
    container_path = "/data"
  }

  # ── 挂载：日志目录 ────────────────────────────────────────
  volumes {
    host_path      = "${var.host_log_path}/redis"
    container_path = "/var/log/redis"
  }

  # 使用自定义配置文件启动（覆盖镜像默认参数）
  command = ["redis-server", "/etc/redis/redis.conf"]

  # ── 健康检查：验证认证 + PING ─────────────────────────────
  healthcheck {
    test         = ["CMD-SHELL", "redis-cli -a '${var.redis_password}' --no-auth-warning PING | grep -q PONG"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "15s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["redis"]
  }

  depends_on = [local_file.redis_conf]

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "redis"
  }
}
