# =============================================================================
# modules/kafka/outputs.tf
# =============================================================================

output "kafka_bootstrap_servers" {
  description = "Kafka bootstrap.servers 地址（Spring 应用配置使用）"
  value       = "kafka:9092"
}

output "kafka_container_name" {
  description = "Kafka Broker 容器名称"
  value       = docker_container.kafka.name
}

output "xxljob_container_name" {
  description = "XXL-Job 调度中心容器名称"
  value       = docker_container.xxljob.name
}

output "xxljob_admin_url" {
  description = "XXL-Job 管理后台 URL（内网访问）"
  value       = "http://xxljob:8088/xxl-job-admin"
}
