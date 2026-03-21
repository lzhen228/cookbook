# =============================================================================
# environments/dev/variables.tf
# 开发环境变量声明（sensitive 值通过 TF_VAR_ 环境变量注入）
# =============================================================================

# ── 密钥（必须通过环境变量注入，不允许写入 terraform.tfvars）───────────────
variable "db_password" {
  description = "PostgreSQL 密码（export TF_VAR_db_password=xxx）"
  type        = string
  sensitive   = true
}

variable "redis_password" {
  description = "Redis 密码（export TF_VAR_redis_password=xxx）"
  type        = string
  sensitive   = true
}

variable "minio_root_password" {
  description = "MinIO Secret Key（export TF_VAR_minio_root_password=xxx）"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT 签名密钥（export TF_VAR_jwt_secret=xxx，最少 256-bit）"
  type        = string
  sensitive   = true
}

variable "xxljob_admin_password" {
  description = "XXL-Job 管理员密码和执行器 Token"
  type        = string
  sensitive   = true
}

variable "xxljob_db_password" {
  description = "XXL-Job 数据库密码（复用 db_password）"
  type        = string
  sensitive   = true
}

# ── 镜像（dev 可用 latest 或本地构建 tag）────────────────────────────────────
variable "api_image" {
  description = "API 镜像 tag"
  type        = string
}

variable "frontend_image" {
  description = "Frontend 镜像 tag"
  type        = string
}
