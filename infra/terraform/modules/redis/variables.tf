# =============================================================================
# modules/redis/variables.tf
# Redis 7 模块变量（缓存 + Session + Lua 原子操作防缓存击穿）
# =============================================================================

variable "env" {
  description = "环境标识：dev / test / staging / prod"
  type        = string
}

variable "network_name" {
  description = "Docker 网络名称"
  type        = string
}

variable "redis_password" {
  description = "Redis 认证密码（通过 TF_VAR_redis_password 注入，禁止硬编码）"
  type        = string
  sensitive   = true
}

variable "memory_mb" {
  description = "内存限制（MiB）：dev=256, test=512, staging/prod=2048"
  type        = number
}

variable "cpu_shares" {
  description = "CPU 权重：dev=256, test=512, staging/prod=1024"
  type        = number
}

variable "maxmemory_mb" {
  description = "Redis maxmemory（MB），建议为 memory_mb 的 80%，防止 OOM"
  type        = number
}

variable "maxmemory_policy" {
  description = "淘汰策略：allkeys-lru（缓存模式），noeviction（Session 模式）"
  type        = string
  default     = "allkeys-lru"

  validation {
    condition = contains([
      "noeviction", "allkeys-lru", "volatile-lru",
      "allkeys-random", "volatile-random", "volatile-ttl",
      "allkeys-lfu", "volatile-lfu"
    ], var.maxmemory_policy)
    error_message = "maxmemory_policy 必须是合法的 Redis 淘汰策略。"
  }
}

variable "host_log_path" {
  description = "宿主机日志挂载根目录"
  type        = string
}

variable "enable_aof" {
  description = "是否开启 AOF 持久化（dev=false，test/staging/prod=true）"
  type        = bool
  default     = true
}

variable "aof_fsync" {
  description = "AOF 刷盘策略：everysec（推荐）/ always（极高安全） / no（最快）"
  type        = string
  default     = "everysec"
}

variable "enable_rdb" {
  description = "是否开启 RDB 快照（生产环境建议开启）"
  type        = bool
  default     = true
}
