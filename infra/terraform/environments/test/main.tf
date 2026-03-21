# =============================================================================
# environments/test/main.tf
# 测试环境基础设施编排（QA 功能测试 / 接口测试）
#
# 资源规格（中等，单节点，开启持久化）：
#   PostgreSQL  : 2GB / 1CPU
#   Redis       : 512MB / 0.25CPU
#   MinIO       : 1GB / 0.5CPU
#   Kafka       : 2GB / 1CPU
#   API         : 1 副本，1GB / 1CPU
# =============================================================================

locals {
  env           = "test"
  host_log_path = "/var/log/scrm/test"
  network_name  = "scrm-test-network"
  domain        = "test.scrm.internal"
}

resource "docker_network" "test" {
  name   = local.network_name
  driver = "bridge"
  ipam_config {
    subnet  = "172.21.0.0/24"  # test: 172.21.0.x（与 dev 隔离）
    gateway = "172.21.0.1"
  }
  labels {
    label = "com.scrm.env"
    value = local.env
  }
}

module "postgres" {
  source = "../../modules/postgres"

  env                        = local.env
  network_name               = docker_network.test.name
  db_password                = var.db_password
  memory_mb                  = 2048
  cpu_shares                 = 1024
  enable_replica             = false
  host_log_path              = local.host_log_path
  pg_max_connections         = 100
  pg_shared_buffers_mb       = 512
  pg_effective_cache_size_mb = 1536
  pg_work_mem_mb             = 16
  pg_maintenance_work_mem_mb = 64
  pg_wal_level               = "replica"
}

module "redis" {
  source = "../../modules/redis"

  env            = local.env
  network_name   = docker_network.test.name
  redis_password = var.redis_password
  memory_mb      = 512
  cpu_shares     = 256
  maxmemory_mb   = 400
  enable_aof     = true    # test 开启持久化，模拟生产行为
  enable_rdb     = true
  host_log_path  = local.host_log_path
}

module "minio" {
  source = "../../modules/minio"

  env                 = local.env
  network_name        = docker_network.test.name
  minio_root_password = var.minio_root_password
  memory_mb           = 1024
  cpu_shares          = 512
  host_log_path       = local.host_log_path
}

module "kafka" {
  source = "../../modules/kafka"

  env                   = local.env
  network_name          = docker_network.test.name
  memory_mb             = 2048
  cpu_shares            = 1024
  kafka_heap_opts       = "-Xms512m -Xmx1g"
  log_retention_hours   = 24
  xxljob_admin_password = var.xxljob_admin_password
  xxljob_db_password    = var.xxljob_db_password
  xxljob_memory_mb      = 512
  host_log_path         = local.host_log_path
}

module "app" {
  source = "../../modules/app"

  env               = local.env
  network_name      = docker_network.test.name
  host_log_path     = local.host_log_path
  api_image         = var.api_image
  frontend_image    = var.frontend_image
  api_replica_count = 1
  api_memory_mb     = 1024
  api_cpu_shares    = 1024
  api_java_opts     = "-server -Xms512m -Xmx1g -Dfile.encoding=UTF-8"
  app_env           = "test"
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
  hikari_max_pool_size = 10
  xxljob_access_token  = var.xxljob_admin_password
  xxljob_admin_url     = module.kafka.xxljob_admin_url
}

module "nginx" {
  source = "../../modules/nginx"

  env                     = local.env
  network_name            = docker_network.test.name
  memory_mb               = 256
  cpu_shares              = 256
  host_log_path           = local.host_log_path
  ssl_enabled             = false
  domain                  = local.domain
  api_upstream_hosts      = module.app.api_upstream_hosts
  frontend_container_name = module.app.frontend_container_name
}

output "test_gateway_url" {
  value = "http://${local.domain}:${module.nginx.http_port}"
}
