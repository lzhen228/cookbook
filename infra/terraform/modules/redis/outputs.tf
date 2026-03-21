# =============================================================================
# modules/redis/outputs.tf
# =============================================================================

output "container_name" {
  description = "Redis 容器名称"
  value       = docker_container.redis.name
}

output "redis_host" {
  description = "应用连接 Redis 的 hostname（Docker 网络内 DNS）"
  value       = "redis"
}

output "redis_port" {
  description = "Redis 端口"
  value       = 6379
}
