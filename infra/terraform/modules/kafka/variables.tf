# =============================================================================
# modules/kafka/variables.tf
# Kafka 3.x (KRaft 模式，无需 Zookeeper) + XXL-Job 调度中心
# =============================================================================

variable "env" {
  description = "环境标识"
  type        = string
}

variable "network_name" {
  description = "Docker 网络名称"
  type        = string
}

variable "memory_mb" {
  description = "Kafka Broker 内存限制（MiB）：dev=1024, test=2048, staging/prod=4096"
  type        = number
}

variable "cpu_shares" {
  description = "Kafka CPU 权重：dev=512, test=1024, staging/prod=2048"
  type        = number
}

variable "kafka_heap_opts" {
  description = "Kafka JVM Heap 设置：-Xms512m -Xmx1g（生产加大）"
  type        = string
  default     = "-Xms512m -Xmx1g"
}

variable "host_log_path" {
  description = "宿主机日志挂载根目录"
  type        = string
}

variable "log_retention_hours" {
  description = "Kafka 消息保留时长（小时）：dev=4, prod=168（7天）"
  type        = number
  default     = 168
}

variable "log_retention_bytes" {
  description = "单 Partition 最大存储字节数（-1 表示无限制）"
  type        = number
  default     = 1073741824  # 1GB
}

variable "default_replication_factor" {
  description = "Topic 默认副本数：dev/test=1, staging/prod=1（MVP 单节点）"
  type        = number
  default     = 1
}

variable "num_partitions" {
  description = "Topic 默认分区数（影响消费并发度）"
  type        = number
  default     = 3
}

# XXL-Job 调度中心配置
variable "xxljob_admin_password" {
  description = "XXL-Job Admin 管理员密码（通过 TF_VAR 注入）"
  type        = string
  sensitive   = true
}

variable "xxljob_db_host" {
  description = "XXL-Job 使用的数据库 host（复用 scrm PostgreSQL）"
  type        = string
  default     = "postgres-primary"
}

variable "xxljob_db_name" {
  description = "XXL-Job 数据库名"
  type        = string
  default     = "scrm"
}

variable "xxljob_db_user" {
  description = "XXL-Job 数据库用户名"
  type        = string
  default     = "scrm_user"
}

variable "xxljob_db_password" {
  description = "XXL-Job 数据库密码"
  type        = string
  sensitive   = true
}

variable "xxljob_memory_mb" {
  description = "XXL-Job 内存限制（MiB）：dev=512, prod=1024"
  type        = number
  default     = 512
}
