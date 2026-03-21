# =============================================================================
# environments/prod/variables.tf — 生产环境变量
# 所有 sensitive 变量必须从 Vault 或 CI/CD Masked Variables 注入
# =============================================================================

variable "db_password"           { type = string; sensitive = true }
variable "redis_password"        { type = string; sensitive = true }
variable "minio_root_password"   { type = string; sensitive = true }
variable "jwt_secret"            { type = string; sensitive = true }
variable "xxljob_admin_password" { type = string; sensitive = true }
variable "xxljob_db_password"    { type = string; sensitive = true }

variable "api_image" {
  description = "API 镜像（格式：registry/scrm-api:{git-sha}-{yyyyMMdd}，CLAUDE.md 8.1）"
  type        = string
}

variable "frontend_image" {
  description = "Frontend 镜像"
  type        = string
}

variable "domain" {
  description = "生产域名"
  type        = string
  default     = "scrm.company.com"
}

variable "ssl_cert_path" {
  description = "生产 SSL 证书路径（由 certbot 或运维管理）"
  type        = string
  default     = "/etc/ssl/scrm/fullchain.pem"
}

variable "ssl_key_path" {
  description = "生产 SSL 私钥路径"
  type        = string
  default     = "/etc/ssl/scrm/privkey.pem"
}
