# =============================================================================
# modules/app/variables.tf
# 应用层模块变量（Spring Boot API + React Frontend）
# =============================================================================

variable "env" {
  description = "环境标识：dev / test / staging / prod"
  type        = string
}

variable "network_name" {
  description = "Docker 网络名称"
  type        = string
}

variable "host_log_path" {
  description = "宿主机日志挂载根目录"
  type        = string
}

# ── API 容器配置 ──────────────────────────────────────────────────────────────
variable "api_image" {
  description = "API 镜像（格式：registry/scrm-api:{git-sha}-{date}，CLAUDE.md 8.1）"
  type        = string
  # e.g. "registry.company.com/scrm-api:a1b2c3d4-20260320"
}

variable "api_replica_count" {
  description = "API 实例数：dev/test=1, staging/prod=2"
  type        = number
  default     = 1

  validation {
    condition     = var.api_replica_count >= 1 && var.api_replica_count <= 4
    error_message = "api_replica_count 取值范围 1-4。"
  }
}

variable "api_memory_mb" {
  description = "单个 API 实例内存限制（MiB）：dev=512, test=1024, staging/prod=4096"
  type        = number
}

variable "api_cpu_shares" {
  description = "单个 API 实例 CPU 权重：dev=512, test=1024, staging/prod=2048"
  type        = number
}

variable "api_port" {
  description = "API 容器监听端口"
  type        = number
  default     = 8080
}

variable "api_java_opts" {
  description = "JVM 启动参数（内存、GC、线程数等）"
  type        = string
  # 生产推荐：虚拟线程 + G1GC + 堆内存明确限制
  default     = "-server -Xms1g -Xmx2g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -Dfile.encoding=UTF-8 -Djava.security.egd=file:/dev/./urandom"
}

variable "app_env" {
  description = "Spring Profile（dev / test / staging / prod）"
  type        = string
}

variable "app_log_level" {
  description = "日志级别（dev=DEBUG, 其他=INFO）"
  type        = string
  default     = "INFO"

  validation {
    condition     = contains(["DEBUG", "INFO", "WARN", "ERROR"], var.app_log_level)
    error_message = "app_log_level 必须是 DEBUG、INFO、WARN 或 ERROR。"
  }
}

# ── 数据库连接参数（从 postgres/redis 模块 outputs 传入）────────────────────
variable "db_host" {
  description = "PostgreSQL 主库 host"
  type        = string
}

variable "db_host_readonly" {
  description = "PostgreSQL 只读副本 host（用于 @Transactional(readOnly=true) 路由）"
  type        = string
}

variable "db_port" {
  description = "PostgreSQL 端口"
  type        = number
  default     = 5432
}

variable "db_name" {
  description = "数据库名称"
  type        = string
}

variable "db_user" {
  description = "数据库用户名"
  type        = string
}

variable "db_password" {
  description = "数据库密码（sensitive）"
  type        = string
  sensitive   = true
}

variable "redis_host" {
  description = "Redis host"
  type        = string
}

variable "redis_port" {
  description = "Redis 端口"
  type        = number
  default     = 6379
}

variable "redis_password" {
  description = "Redis 密码（sensitive）"
  type        = string
  sensitive   = true
}

variable "kafka_bootstrap_servers" {
  description = "Kafka Bootstrap Servers"
  type        = string
}

variable "minio_endpoint" {
  description = "MinIO S3 端点"
  type        = string
}

variable "minio_access_key" {
  description = "MinIO Access Key（sensitive）"
  type        = string
  sensitive   = true
}

variable "minio_secret_key" {
  description = "MinIO Secret Key（sensitive）"
  type        = string
  sensitive   = true
}

variable "jwt_secret" {
  description = "JWT 签名密钥（256-bit+，sensitive）"
  type        = string
  sensitive   = true
}

variable "jwt_access_token_ttl_seconds" {
  description = "Access Token TTL（秒）：7200 = 2h，TECH_SPEC 6.1"
  type        = number
  default     = 7200
}

variable "jwt_refresh_token_ttl_seconds" {
  description = "Refresh Token TTL（秒）：604800 = 7d，TECH_SPEC 6.1"
  type        = number
  default     = 604800
}

variable "xxljob_access_token" {
  description = "XXL-Job 执行器接入 Token（sensitive）"
  type        = string
  sensitive   = true
}

variable "xxljob_admin_url" {
  description = "XXL-Job Admin 地址（API 注册执行器用）"
  type        = string
}

# HikariCP 连接池（TECH_SPEC 7.3 读写分离配置）
variable "hikari_max_pool_size" {
  description = "HikariCP 最大连接数：dev=5, prod=20"
  type        = number
  default     = 10
}

# ── 前端容器配置 ──────────────────────────────────────────────────────────────
variable "frontend_image" {
  description = "前端 Nginx 静态资源镜像"
  type        = string
}

variable "frontend_memory_mb" {
  description = "前端容器内存限制（MiB）"
  type        = number
  default     = 256
}
