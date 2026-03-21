# =============================================================================
# environments/test/variables.tf — 与 dev 结构相同
# =============================================================================

variable "db_password"           { type = string; sensitive = true }
variable "redis_password"        { type = string; sensitive = true }
variable "minio_root_password"   { type = string; sensitive = true }
variable "jwt_secret"            { type = string; sensitive = true }
variable "xxljob_admin_password" { type = string; sensitive = true }
variable "xxljob_db_password"    { type = string; sensitive = true }
variable "api_image"             { type = string }
variable "frontend_image"        { type = string }
