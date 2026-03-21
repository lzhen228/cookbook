# =============================================================================
# modules/minio/outputs.tf
# =============================================================================

output "container_name" {
  description = "MinIO 容器名称"
  value       = docker_container.minio.name
}

output "minio_endpoint" {
  description = "MinIO S3 API 端点（Docker 网络内）"
  value       = "http://minio:9000"
}

output "minio_console_endpoint" {
  description = "MinIO 管理控制台端点（仅内网，不对外暴露）"
  value       = "http://minio:9001"
}
