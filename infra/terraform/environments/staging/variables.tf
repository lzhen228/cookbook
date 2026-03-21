# =============================================================================
# environments/staging/variables.tf — 预发环境变量
# =============================================================================

variable "db_password"           { type = string; sensitive = true }
variable "redis_password"        { type = string; sensitive = true }
variable "minio_root_password"   { type = string; sensitive = true }
variable "jwt_secret"            { type = string; sensitive = true }
variable "xxljob_admin_password" { type = string; sensitive = true }
variable "xxljob_db_password"    { type = string; sensitive = true }

variable "api_image" {
  description = "API 镜像（格式：registry/scrm-api:{git-sha}-{date}）"
  type        = string
}

variable "frontend_image" {
  description = "Frontend 镜像"
  type        = string
}

variable "domain" {
  description = "预发环境域名"
  type        = string
  default     = "staging.scrm.company.com"
}

variable "ssl_cert_path" {
  description = "SSL 证书路径（宿主机）"
  type        = string
  default     = "/etc/ssl/scrm-staging/fullchain.pem"
}

variable "ssl_key_path" {
  description = "SSL 私钥路径（宿主机）"
  type        = string
  default     = "/etc/ssl/scrm-staging/privkey.pem"
}
