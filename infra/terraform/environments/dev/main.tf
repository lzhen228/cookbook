# =============================================================================
# environments/dev/main.tf
# 开发环境基础设施编排
#
# 资源规格（低配，单节点，无副本，AOF 关闭节省 IO）：
#   PostgreSQL  : 1GB / 0.5CPU
#   Redis       : 256MB / 0.25CPU
#   MinIO       : 512MB / 0.5CPU
#   Kafka       : 1GB / 0.5CPU
#   XXL-Job     : 512MB / 0.25CPU
#   API         : 1 副本，512MB / 0.5CPU
#   Frontend    : 256MB
#   Nginx       : 256MB / 无 SSL
# =============================================================================

locals {
  env             = "dev"
  host_log_path   = "/var/log/scrm/dev"
  host_data_path  = "/data/scrm/dev"
  network_name    = "scrm-dev-network"
  domain          = "localhost"
  api_image_tag   = var.api_image
  frontend_image_tag = var.frontend_image
}

# ── Docker 网络（dev 环境独立隔离）───────────────────────────────────────────
resource "docker_network" "dev" {
  name            = local.network_name
  driver          = "bridge"
  # 指定子网，各环境使用不同网段，避免冲突
  ipam_config {
    subnet  = "172.20.0.0/24"  # dev: 172.20.0.x
    gateway = "172.20.0.1"
  }

  labels {
    label = "com.scrm.env"
    value = local.env
  }
}

# ── PostgreSQL（主库，无只读副本）────────────────────────────────────────────
module "postgres" {
  source = "../../modules/postgres"

  env                        = local.env
  network_name               = docker_network.dev.name
  db_password                = var.db_password
  memory_mb                  = 1024   # 1GB
  cpu_shares                 = 512    # ~0.5 核
  enable_replica             = false  # dev 无需副本
  host_log_path              = local.host_log_path
  pg_max_connections         = 50     # dev 连接数小
  pg_shared_buffers_mb       = 256    # 内存 25%
  pg_effective_cache_size_mb = 768    # 内存 75%
  pg_work_mem_mb             = 8
  pg_maintenance_work_mem_mb = 32
  pg_wal_level               = "minimal"  # dev 不需要流复制
}

# ── Redis（无 AOF，dev 数据丢失可接受）───────────────────────────────────────
module "redis" {
  source = "../../modules/redis"

  env            = local.env
  network_name   = docker_network.dev.name
  redis_password = var.redis_password
  memory_mb      = 256
  cpu_shares     = 256
  maxmemory_mb   = 200
  enable_aof     = false  # dev 不持久化
  enable_rdb     = false
  host_log_path  = local.host_log_path
}

# ── MinIO ─────────────────────────────────────────────────────────────────────
module "minio" {
  source = "../../modules/minio"

  env                 = local.env
  network_name        = docker_network.dev.name
  minio_root_password = var.minio_root_password
  memory_mb           = 512
  cpu_shares          = 512
  host_log_path       = local.host_log_path
}

# ── Kafka + XXL-Job ───────────────────────────────────────────────────────────
module "kafka" {
  source = "../../modules/kafka"

  env                   = local.env
  network_name          = docker_network.dev.name
  memory_mb             = 1024
  cpu_shares            = 512
  kafka_heap_opts       = "-Xms256m -Xmx512m"
  log_retention_hours   = 4     # dev 保留 4 小时即可
  xxljob_admin_password = var.xxljob_admin_password
  xxljob_db_password    = var.xxljob_db_password
  xxljob_memory_mb      = 512
  host_log_path         = local.host_log_path
}

# ── 应用层（API × 1 + Frontend）─────────────────────────────────────────────
module "app" {
  source = "../../modules/app"

  env              = local.env
  network_name     = docker_network.dev.name
  host_log_path    = local.host_log_path
  api_image        = local.api_image_tag
  frontend_image   = local.frontend_image_tag
  api_replica_count = 1
  api_memory_mb    = 512
  api_cpu_shares   = 512
  api_java_opts    = "-server -Xms256m -Xmx512m -Dfile.encoding=UTF-8"
  app_env          = "dev"
  app_log_level    = "DEBUG"

  # 数据库（来自 postgres 模块 outputs）
  db_host          = module.postgres.db_host_primary
  db_host_readonly = module.postgres.db_host_replica  # dev 无副本，回退到主库
  db_port          = module.postgres.db_port
  db_name          = module.postgres.db_name
  db_user          = module.postgres.db_user
  db_password      = var.db_password

  # Redis
  redis_host     = module.redis.redis_host
  redis_port     = module.redis.redis_port
  redis_password = var.redis_password

  # Kafka
  kafka_bootstrap_servers = module.kafka.kafka_bootstrap_servers

  # MinIO
  minio_endpoint  = module.minio.minio_endpoint
  minio_access_key = "scrm_minio_admin"
  minio_secret_key = var.minio_root_password

  # JWT
  jwt_secret     = var.jwt_secret
  hikari_max_pool_size = 5

  # XXL-Job
  xxljob_access_token = var.xxljob_admin_password
  xxljob_admin_url    = module.kafka.xxljob_admin_url
}

# ── Nginx（HTTP only，无 SSL）────────────────────────────────────────────────
module "nginx" {
  source = "../../modules/nginx"

  env                     = local.env
  network_name            = docker_network.dev.name
  memory_mb               = 256
  cpu_shares              = 256
  host_log_path           = local.host_log_path
  ssl_enabled             = false
  domain                  = local.domain
  api_upstream_hosts      = module.app.api_upstream_hosts
  frontend_container_name = module.app.frontend_container_name
  rate_limit_global_rps   = 200
  rate_limit_login_rpm    = 10
}

# ── 输出（便于本地开发调试）──────────────────────────────────────────────────
output "dev_gateway_url" {
  description = "开发环境访问入口"
  value       = "http://localhost:${module.nginx.http_port}"
}

output "dev_minio_console" {
  description = "MinIO 控制台（内网访问）"
  value       = module.minio.minio_console_endpoint
}

output "dev_xxljob_admin" {
  description = "XXL-Job 调度中心（内网访问）"
  value       = module.kafka.xxljob_admin_url
}
