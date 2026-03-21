# =============================================================================
# modules/nginx/outputs.tf
# =============================================================================

output "container_name" {
  description = "Nginx 容器名称"
  value       = docker_container.nginx.name
}

output "http_port" {
  description = "HTTP 端口（宿主机映射）"
  value       = var.env == "prod" ? 80 : (var.env == "staging" ? 8180 : (var.env == "test" ? 8280 : 8380))
}

output "https_port" {
  description = "HTTPS 端口（宿主机映射，ssl_enabled=false 时为 null）"
  value       = var.ssl_enabled ? (var.env == "prod" ? 443 : 8443) : null
}

output "gateway_url" {
  description = "服务访问入口 URL"
  value       = var.ssl_enabled ? "https://${var.domain}" : "http://${var.domain}"
}
