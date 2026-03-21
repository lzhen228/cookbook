# =============================================================================
# modules/app/outputs.tf
# =============================================================================

output "api_container_names" {
  description = "所有 API 实例容器名称列表（供 Nginx upstream 配置使用）"
  value       = [for c in docker_container.api : c.name]
}

output "api_upstream_hosts" {
  description = "Nginx upstream 使用的 API hostname 列表（Docker 网络 DNS）"
  value       = [for i in range(var.api_replica_count) : "scrm-${var.env}-api-${i}"]
}

output "frontend_container_name" {
  description = "前端容器名称"
  value       = docker_container.frontend.name
}
