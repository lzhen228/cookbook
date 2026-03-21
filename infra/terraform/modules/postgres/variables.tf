# =============================================================================
# modules/postgres/variables.tf
# PostgreSQL 模块变量定义（主库 + 只读副本 + TimescaleDB）
# =============================================================================

variable "env" {
  description = "环境标识：dev / test / staging / prod"
  type        = string

  validation {
    condition     = contains(["dev", "test", "staging", "prod"], var.env)
    error_message = "env 必须是 dev、test、staging 或 prod 之一。"
  }
}

variable "network_name" {
  description = "容器所在的 Docker 网络名称（各环境独立隔离）"
  type        = string
}

variable "db_name" {
  description = "数据库名称"
  type        = string
  default     = "scrm"
}

variable "db_user" {
  description = "数据库主用户名"
  type        = string
  default     = "scrm_user"
}

variable "db_password" {
  description = "数据库密码（敏感值，通过 TF_VAR_db_password 环境变量或 Vault 注入，禁止硬编码）"
  type        = string
  sensitive   = true
}

variable "memory_mb" {
  description = "主库内存限制（MiB）：dev=1024, test=2048, staging/prod=8192"
  type        = number
}

variable "cpu_shares" {
  description = "CPU 权重（相对值，1024 ≈ 1 核）：dev=512, test=1024, staging/prod=2048"
  type        = number
}

variable "enable_replica" {
  description = "是否启用只读副本（staging/prod 必须开启，dev/test 关闭）"
  type        = bool
  default     = false
}

variable "data_volume_driver" {
  description = "数据卷存储驱动（local 或挂载 NFS 等）"
  type        = string
  default     = "local"
}

variable "host_log_path" {
  description = "宿主机日志挂载根目录（e.g. /var/log/scrm）"
  type        = string
}

variable "host_data_path" {
  description = "宿主机数据挂载根目录（dev 模式可使用 bind mount，prod 使用命名卷）"
  type        = string
  default     = ""
}

# PostgreSQL 调优参数（生产环境按实际内存计算）
variable "pg_max_connections" {
  description = "最大连接数（API 双副本 + XXL-Job 各 HikariCP 最大 20，留余量）"
  type        = number
  default     = 100
}

variable "pg_shared_buffers_mb" {
  description = "shared_buffers (MB)，建议为内存的 25%"
  type        = number
  default     = 256
}

variable "pg_effective_cache_size_mb" {
  description = "effective_cache_size (MB)，建议为内存的 75%"
  type        = number
  default     = 768
}

variable "pg_work_mem_mb" {
  description = "work_mem (MB)，每个排序/哈希操作的内存"
  type        = number
  default     = 16
}

variable "pg_maintenance_work_mem_mb" {
  description = "maintenance_work_mem (MB)，VACUUM/CREATE INDEX 使用"
  type        = number
  default     = 64
}

variable "pg_wal_level" {
  description = "WAL 级别：minimal（dev）/ replica（prod，支持流复制）"
  type        = string
  default     = "replica"
}
