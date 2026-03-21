# =============================================================================
# environments/prod/main.tf
# 生产环境基础设施编排
#
# 生产规格（TECH_SPEC 8.2 prod 配置）：
#   PostgreSQL  : 8GB / 2CPU（主）+ 4GB/1CPU（只读副本）
#   Redis       : 4GB / 2CPU（maxmemory 3.2GB）
#   MinIO       : 4GB / 2CPU
#   Kafka       : 8GB / 4CPU（JVM 4GB）
#   XXL-Job     : 1GB / 0.5CPU
#   API         : 2 副本 × 4GB/2CPU
#   Frontend    : 512MB
#   Nginx       : 1GB / 2CPU（SSL 启用，高并发优化）
#
# 关键生产保护措施：
#   - 所有数据卷 prevent_destroy = true
#   - 敏感变量全部 sensitive = true，不输出到 terraform output
#   - 网络子网独立，与其他环境完全隔离
#   - 全局 API 限流 200req/s，登录限流 10req/min
# =============================================================================

locals {
  env           = "prod"
  host_log_path = "/var/log/scrm/prod"
  network_name  = "scrm-prod-network"
}

# ── Docker 网络（生产环境独立子网）───────────────────────────────────────────
resource "docker_network" "prod" {
  name   = local.network_name
  driver = "bridge"
  ipam_config {
    subnet  = "172.23.0.0/24"  # prod: 172.23.0.x（最高位，独立隔离）
    gateway = "172.23.0.1"
  }
  labels {
    label = "com.scrm.env"
    value = local.env
  }
}

# ── PostgreSQL（主库 + 只读副本，生产开启 replica）──────────────────────────
module "postgres" {
  source = "../../modules/postgres"

  env                        = local.env
  network_name               = docker_network.prod.name
  db_password                = var.db_password
  memory_mb                  = 8192   # 8GB
  cpu_shares                 = 2048   # ~2 核
  enable_replica             = true   # 生产必须开启只读副本
  host_log_path              = local.host_log_path
  pg_max_connections         = 200    # 双 API 副本 × 最大 20 连接 + 余量
  pg_shared_buffers_mb       = 2048   # 8GB × 25%
  pg_effective_cache_size_mb = 6144   # 8GB × 75%
  pg_work_mem_mb             = 32     # 适中，避免多排序并发时 OOM
  pg_maintenance_work_mem_mb = 512    # VACUUM / CREATE INDEX 加速
  pg_wal_level               = "replica"
}

# ── Redis（生产全量缓存）──────────────────────────────────────────────────────
module "redis" {
  source = "../../modules/redis"

  env              = local.env
  network_name     = docker_network.prod.name
  redis_password   = var.redis_password
  memory_mb        = 4096
  cpu_shares       = 2048
  maxmemory_mb     = 3276   # 80% of 4GB
  maxmemory_policy = "allkeys-lru"
  enable_aof       = true
  aof_fsync        = "everysec"
  enable_rdb       = true
  host_log_path    = local.host_log_path
}

# ── MinIO（生产报告存储）─────────────────────────────────────────────────────
module "minio" {
  source = "../../modules/minio"

  env                       = local.env
  network_name              = docker_network.prod.name
  minio_root_password       = var.minio_root_password
  memory_mb                 = 4096
  cpu_shares                = 2048
  host_log_path             = local.host_log_path
  presigned_url_ttl_minutes = 15  # TECH_SPEC glossary: 预签名 URL TTL 15min
}

# ── Kafka + XXL-Job（生产高吞吐配置）─────────────────────────────────────────
module "kafka" {
  source = "../../modules/kafka"

  env                        = local.env
  network_name               = docker_network.prod.name
  memory_mb                  = 8192   # 8GB（JVM 4GB + OS page cache 4GB）
  cpu_shares                 = 4096   # ~4 核
  kafka_heap_opts            = "-Xms2g -Xmx4g -XX:+UseG1GC"
  log_retention_hours        = 168    # 7 天
  log_retention_bytes        = 2147483648  # 2GB per partition
  default_replication_factor = 1     # MVP 单 Broker（后续扩展 3 副本）
  num_partitions             = 3
  xxljob_admin_password      = var.xxljob_admin_password
  xxljob_db_password         = var.xxljob_db_password
  xxljob_memory_mb           = 1024
  host_log_path              = local.host_log_path
}

# ── 应用层（API × 2 副本，生产配置）─────────────────────────────────────────
module "app" {
  source = "../../modules/app"

  env               = local.env
  network_name      = docker_network.prod.name
  host_log_path     = local.host_log_path
  api_image         = var.api_image
  frontend_image    = var.frontend_image
  api_replica_count = 2     # 生产双副本（TECH_SPEC 8.1 应用层双副本）
  api_memory_mb     = 4096  # 4GB per replica
  api_cpu_shares    = 2048  # ~2 核 per replica

  # Java 17 生产 JVM 参数：
  #   - 虚拟线程：提升 IO 并发能力（TECH_SPEC 3.2）
  #   - G1GC：MaxGCPauseMillis=200 控制停顿
  #   - HeapDumpOnOutOfMemoryError：OOM 时自动 dump
  api_java_opts = join(" ", [
    "-server",
    "-Xms2g -Xmx3g",
    "-XX:+UseG1GC",
    "-XX:MaxGCPauseMillis=200",
    "-XX:+UseStringDeduplication",
    "-XX:+HeapDumpOnOutOfMemoryError",
    "-XX:HeapDumpPath=/app/logs/heapdump.hprof",
    "-Dfile.encoding=UTF-8",
    "-Djava.security.egd=file:/dev/./urandom",
    # 禁止 DEBUG 日志（CLAUDE.md 8.5）
    "-Dlogging.level.root=INFO",
  ])

  app_env       = "prod"
  app_log_level = "INFO"

  db_host          = module.postgres.db_host_primary
  db_host_readonly = module.postgres.db_host_replica
  db_port          = module.postgres.db_port
  db_name          = module.postgres.db_name
  db_user          = module.postgres.db_user
  db_password      = var.db_password
  redis_host       = module.redis.redis_host
  redis_port       = module.redis.redis_port
  redis_password   = var.redis_password
  kafka_bootstrap_servers = module.kafka.kafka_bootstrap_servers
  minio_endpoint   = module.minio.minio_endpoint
  minio_access_key = "scrm_minio_admin"
  minio_secret_key = var.minio_root_password
  jwt_secret       = var.jwt_secret

  # JWT TTL（TECH_SPEC 6.1）
  jwt_access_token_ttl_seconds  = 7200    # 2h
  jwt_refresh_token_ttl_seconds = 604800  # 7d

  # HikariCP 连接池（双副本 × 20 = 40，pg max_connections=200 留余量）
  hikari_max_pool_size = 20

  xxljob_access_token = var.xxljob_admin_password
  xxljob_admin_url    = module.kafka.xxljob_admin_url

  frontend_memory_mb = 512
}

# ── Nginx（生产：SSL + 高并发 + 全限流规则）──────────────────────────────────
module "nginx" {
  source = "../../modules/nginx"

  env                     = local.env
  network_name            = docker_network.prod.name
  memory_mb               = 1024
  cpu_shares              = 2048
  host_log_path           = local.host_log_path

  # SSL 配置（生产必须 HTTPS）
  ssl_enabled   = true
  domain        = var.domain
  ssl_cert_path = var.ssl_cert_path
  ssl_key_path  = var.ssl_key_path

  # 上游 API（双副本负载均衡）
  api_upstream_hosts      = module.app.api_upstream_hosts
  frontend_container_name = module.app.frontend_container_name

  # 性能配置（生产高并发）
  worker_processes   = "auto"  # 自动匹配 CPU 核数
  worker_connections = 4096    # 单 worker 最大连接

  # 限流（TECH_SPEC 6.3 接口限流细化）
  rate_limit_global_rps = 200   # 全局 IP 限流：200 req/s
  rate_limit_login_rpm  = 10    # 登录接口：10 req/min/IP

  proxy_read_timeout_s    = 30
  client_max_body_size_mb = 50
  enable_gzip             = true
}

# ── 生产输出（注意：不输出任何敏感信息）─────────────────────────────────────
output "prod_gateway_url" {
  description = "生产环境入口 URL"
  value       = module.nginx.gateway_url
}

output "prod_api_instances" {
  description = "API 实例列表"
  value       = module.app.api_container_names
}

# 内部运维信息（不对外暴露）
output "prod_internal_endpoints" {
  description = "内网运维端点（仅内网可访问）"
  value = {
    minio_console  = module.minio.minio_console_endpoint
    xxljob_admin   = module.kafka.xxljob_admin_url
    pg_primary     = module.postgres.db_host_primary
    pg_replica     = module.postgres.db_host_replica
  }
}
