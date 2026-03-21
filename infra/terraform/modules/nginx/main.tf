# =============================================================================
# modules/nginx/main.tf
# Nginx 反向代理容器模块
#
# 职责：
#   - SSL 终止（staging/prod 开启，dev/test 关闭）
#   - 反向代理 API 后端（负载均衡多副本）
#   - 前端静态资源直出
#   - 限流（全局 200req/s/IP，登录 10req/min/IP，TECH_SPEC 6.3）
#   - 安全响应头（CSP / X-Frame-Options / HSTS）
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "nginx" {
  name         = "nginx:1.25-alpine"  # 固定小版本，禁止 latest
  keep_locally = true
}

# ── 生成 nginx.conf（主配置）─────────────────────────────────────────────────
resource "local_file" "nginx_conf" {
  filename        = "${path.module}/.generated/${var.env}/nginx.conf"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/nginx.conf.tpl", {
    env                     = var.env
    domain                  = var.domain
    ssl_enabled             = var.ssl_enabled
    worker_processes        = var.worker_processes
    worker_connections      = var.worker_connections
    rate_limit_global_rps   = var.rate_limit_global_rps
    rate_limit_login_rpm    = var.rate_limit_login_rpm
    api_upstream_hosts      = var.api_upstream_hosts
    api_port                = var.api_port
    client_max_body_size_mb = var.client_max_body_size_mb
    enable_gzip             = var.enable_gzip
    proxy_read_timeout_s    = var.proxy_read_timeout_s
  })
}

# ── 生成 locations.conf（路由规则）──────────────────────────────────────────
resource "local_file" "locations_conf" {
  filename        = "${path.module}/.generated/${var.env}/locations.conf"
  file_permission = "0644"

  content = templatefile("${path.module}/templates/locations.conf.tpl", {
    env                  = var.env
    ssl_enabled          = var.ssl_enabled
    proxy_read_timeout_s = var.proxy_read_timeout_s
  })
}

# ── Nginx 容器 ────────────────────────────────────────────────────────────────
resource "docker_container" "nginx" {
  name    = "scrm-${var.env}-nginx"
  image   = docker_image.nginx.image_id
  restart = "unless-stopped"

  memory     = var.memory_mb
  cpu_shares = var.cpu_shares

  # ── 端口映射（宿主机暴露，其他容器通过内网通信）─────────
  ports {
    internal = 80
    external = var.env == "prod" ? 80 : (
      var.env == "staging" ? 8180 : (
        var.env == "test" ? 8280 : 8380
      )
    )
    protocol = "tcp"
  }

  dynamic "ports" {
    for_each = var.ssl_enabled ? [1] : []
    content {
      internal = 443
      external = var.env == "prod" ? 443 : 8443
      protocol = "tcp"
    }
  }

  # ── 挂载：Nginx 主配置 ────────────────────────────────────
  volumes {
    host_path      = abspath(local_file.nginx_conf.filename)
    container_path = "/etc/nginx/nginx.conf"
    read_only      = true
  }

  # ── 挂载：Location 路由配置 ───────────────────────────────
  volumes {
    host_path      = abspath(local_file.locations_conf.filename)
    container_path = "/etc/nginx/conf.d/locations.conf"
    read_only      = true
  }

  # ── 挂载：SSL 证书（ssl_enabled=true 时挂载）────────────
  dynamic "volumes" {
    for_each = var.ssl_enabled ? [1] : []
    content {
      host_path      = var.ssl_cert_path
      container_path = "/etc/nginx/ssl/fullchain.pem"
      read_only      = true
    }
  }

  dynamic "volumes" {
    for_each = var.ssl_enabled ? [1] : []
    content {
      host_path      = var.ssl_key_path
      container_path = "/etc/nginx/ssl/privkey.pem"
      read_only      = true
    }
  }

  # ── 挂载：访问日志 + 错误日志 ────────────────────────────
  volumes {
    host_path      = "${var.host_log_path}/nginx"
    container_path = "/var/log/nginx"
  }

  # ── 健康检查 ─────────────────────────────────────────────
  healthcheck {
    test         = ["CMD-SHELL", "wget -q -O /dev/null http://localhost/health || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "10s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["nginx", "gateway"]
  }

  depends_on = [
    local_file.nginx_conf,
    local_file.locations_conf,
  ]

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "nginx"
  }
}
