# =============================================================================
# modules/postgres/outputs.tf
# =============================================================================

output "primary_container_name" {
  description = "主库容器名称（Docker DNS 内网可直接寻址）"
  value       = docker_container.primary.name
}

output "primary_container_id" {
  description = "主库容器 ID"
  value       = docker_container.primary.id
}

output "replica_container_name" {
  description = "只读副本容器名称（enable_replica=false 时为 null）"
  value       = var.enable_replica ? docker_container.replica[0].name : null
}

output "db_host_primary" {
  description = "应用连接主库的 hostname（Docker 网络内 DNS 名称）"
  value       = "postgres-primary"
}

output "db_host_replica" {
  description = "应用连接副本的 hostname（enable_replica=false 时回退到主库）"
  value       = var.enable_replica ? "postgres-replica" : "postgres-primary"
}

output "db_port" {
  description = "PostgreSQL 端口"
  value       = 5432
}

output "db_name" {
  description = "数据库名称"
  value       = var.db_name
}

output "db_user" {
  description = "数据库用户名"
  value       = var.db_user
}
