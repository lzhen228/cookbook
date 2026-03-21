# =============================================================================
# modules/nginx/variables.tf
# Nginx 反向代理、SSL 终止、限流模块变量
# =============================================================================

variable "env" {
  description = "环境标识：dev / test / staging / prod"
  type        = string
}

variable "network_name" {
  description = "Docker 网络名称"
  type        = string
}

variable "memory_mb" {
  description = "内存限制（MiB）"
  type        = number
  default     = 512
}

variable "cpu_shares" {
  description = "CPU 权重"
  type        = number
  default     = 1024
}

variable "host_log_path" {
  description = "宿主机日志挂载根目录"
  type        = string
}

# ── SSL 配置 ─────────────────────────────────────────────────────────────────
variable "ssl_enabled" {
  description = "是否启用 HTTPS（dev=false，staging/prod=true）"
  type        = bool
  default     = false
}

variable "ssl_cert_path" {
  description = "宿主机 SSL 证书路径（e.g. /etc/ssl/scrm/fullchain.pem）"
  type        = string
  default     = "/etc/ssl/scrm/fullchain.pem"
}

variable "ssl_key_path" {
  description = "宿主机 SSL 私钥路径（e.g. /etc/ssl/scrm/privkey.pem）"
  type        = string
  default     = "/etc/ssl/scrm/privkey.pem"
}

variable "domain" {
  description = "服务域名（e.g. scrm.company.com），dev 可使用 localhost"
  type        = string
  default     = "localhost"
}

# ── 上游 API 实例列表 ────────────────────────────────────────────────────────
variable "api_upstream_hosts" {
  description = "API 容器 hostname 列表（单节点=1个，prod=2个）"
  type        = list(string)
  # e.g. ["scrm-prod-api-0", "scrm-prod-api-1"]
}

variable "api_port" {
  description = "API 容器监听端口"
  type        = number
  default     = 8080
}

variable "frontend_container_name" {
  description = "前端静态资源容器名称（Nginx 直出）"
  type        = string
}

# ── 限流配置（对应 TECH_SPEC 6.3 接口限流细化）────────────────────────────
variable "rate_limit_global_rps" {
  description = "全局 IP 级限流（req/s）：200，对应 TECH_SPEC 6.3"
  type        = number
  default     = 200
}

variable "rate_limit_login_rpm" {
  description = "登录接口限流（req/min/IP）：10，失败 5 次锁定 15min"
  type        = number
  default     = 10
}

# ── 性能配置 ─────────────────────────────────────────────────────────────────
variable "worker_processes" {
  description = "Nginx worker 进程数（auto=CPU 核数）"
  type        = string
  default     = "auto"
}

variable "worker_connections" {
  description = "每个 worker 最大并发连接数"
  type        = number
  default     = 1024
}

variable "proxy_read_timeout_s" {
  description = "代理读超时（秒），API P99 ≤ 1s，留余量设为 30s"
  type        = number
  default     = 30
}

variable "client_max_body_size_mb" {
  description = "最大请求体（MB），报告上传场景"
  type        = number
  default     = 50
}

variable "enable_gzip" {
  description = "是否开启 Gzip 压缩（JSON 响应压缩率约 70%）"
  type        = bool
  default     = true
}
