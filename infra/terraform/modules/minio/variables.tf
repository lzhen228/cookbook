# =============================================================================
# modules/minio/variables.tf
# MinIO 对象存储模块变量（存储供应商画像 PDF 报告，S3 兼容预签名 URL）
# =============================================================================

variable "env" {
  description = "环境标识"
  type        = string
}

variable "network_name" {
  description = "Docker 网络名称"
  type        = string
}

variable "minio_root_user" {
  description = "MinIO root 用户名（Access Key）"
  type        = string
  default     = "scrm_minio_admin"
}

variable "minio_root_password" {
  description = "MinIO root 密码（Secret Key），通过 TF_VAR_minio_root_password 注入"
  type        = string
  sensitive   = true
}

variable "memory_mb" {
  description = "内存限制（MiB）：dev=512, test=1024, staging/prod=2048"
  type        = number
}

variable "cpu_shares" {
  description = "CPU 权重"
  type        = number
}

variable "host_log_path" {
  description = "宿主机日志挂载根目录"
  type        = string
}

variable "buckets" {
  description = "自动创建的 Bucket 列表"
  type        = list(string)
  default     = ["scrm-reports", "scrm-exports", "scrm-temp"]
}

variable "presigned_url_ttl_minutes" {
  description = "预签名 URL 有效期（分钟），对应 TECH_SPEC 第 10 节 glossary"
  type        = number
  default     = 15
}
