# =============================================================================
# environments/staging/main.tf
# 预发环境（同 Prod 配置，用于上线前回归测试和压测）
#
# 资源规格（与 Prod 一致，TECH_SPEC 8.2）：
#   PostgreSQL  : 8GB / 2CPU（主库）+ 4GB/1CPU（只读副本）
#   Redis       : 2GB / 1CPU
#   MinIO       : 2GB / 1CPU
#   Kafka       : 4GB / 2CPU
#   API         : 2 副本，各 4GB / 2CPU
#   SSL         : 已启用
# =============================================================================

locals {
  env           = "staging"
  host_log_path = "/var/log/scrm/staging"
  network_name  = "scrm-staging-network"
}

resource "docker_network" "staging" {
  name   = local.network_name
  driver = "bridge"
  ipam_config {
    subnet  = "172.22.0.0/24"  # staging: 172.22.0.x
    gateway = "172.22.0.1"
  }
  labels {
    label = "com.scrm.env"
    value = local.env
  }
}

module "postgres" {
  source = "../../modules/postgres"

  env                        = local.env
  network_name               = docker_network.staging.name
  db_password                = var.db_password
  memory_mb                  = 8192   # 8GB 主库
  cpu_shares                 = 2048   # ~2 核
  enable_replica             = true   # 预发开启副本，验证读写分离
  host_log_path              = local.host_log_path
  pg_max_connections         = 100
  pg_shared_buffers_mb       = 2048   # 内存 25%
  pg_effective_cache_size_mb = 6144   # 内存 75%
  pg_work_mem_mb             = 32
  pg_maintenance_work_mem_mb = 256
  pg_wal_level               = "replica"
}

module "redis" {
  source = "../../modules/redis"

  env              = local.env
  network_name     = docker_network.staging.name
  redis_password   = var.redis_password
  memory_mb        = 2048
  cpu_shares       = 1024
  maxmemory_mb     = 1600  # 80% 内存
  maxmemory_policy = "allkeys-lru"
  enable_aof       = true
  aof_fsync        = "everysec"
  enable_rdb       = true
  host_log_path    = local.host_log_path
}

module "minio" {
  source = "../../modules/minio"

  env                 = local.env
  network_name        = docker_network.staging.name
  minio_root_password = var.minio_root_password
  memory_mb           = 2048
  cpu_shares          = 1024
  host_log_path       = local.host_log_path
}

module "kafka" {
  source = "../../modules/kafka"

  env                        = local.env
  network_name               = docker_network.staging.name
  memory_mb                  = 4096
  cpu_shares                 = 2048
  kafka_heap_opts            = "-Xms1g -Xmx2g"
  log_retention_hours        = 168    # 7 天
  log_retention_bytes        = 1073741824
  default_replication_factor = 1     # MVP 单节点
  num_partitions             = 3
  xxljob_admin_password      = var.xxljob_admin_password
  xxljob_db_password         = var.xxljob_db_password
  xxljob_memory_mb           = 1024
  host_log_path              = local.host_log_path
}

module "app" {
  source = "../../modules/app"

  env               = local.env
  network_name      = docker_network.staging.name
  host_log_path     = local.host_log_path
  api_image         = var.api_image
  frontend_image    = var.frontend_image
  api_replica_count = 2   # 双副本，同 Prod
  api_memory_mb     = 4096
  api_cpu_shares    = 2048
  # Java 17 虚拟线程 + G1GC，批量评分线程池独立
  api_java_opts     = "-server -Xms2g -Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+UseStringDeduplication -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom"
  app_env           = "staging"
  app_log_level     = "INFO"

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
  hikari_max_pool_size = 20
  xxljob_access_token  = var.xxljob_admin_password
  xxljob_admin_url     = module.kafka.xxljob_admin_url
}

module "nginx" {
  source = "../../modules/nginx"

  env                     = local.env
  network_name            = docker_network.staging.name
  memory_mb               = 512
  cpu_shares              = 1024
  host_log_path           = local.host_log_path
  ssl_enabled             = true
  domain                  = var.domain
  ssl_cert_path           = var.ssl_cert_path
  ssl_key_path            = var.ssl_key_path
  api_upstream_hosts      = module.app.api_upstream_hosts
  frontend_container_name = module.app.frontend_container_name
  worker_processes        = "2"
  worker_connections      = 2048
}

output "staging_gateway_url" {
  value = module.nginx.gateway_url
}
