# =============================================================================
# nginx.conf.tpl — Nginx 配置模板
# 由 Terraform templatefile() 渲染生成
# 环境: ${env} | 域名: ${domain}
#
# 实现的安全与性能约束（TECH_SPEC 第 6、7 节）：
#   - 全局限流：${rate_limit_global_rps} req/s / IP
#   - 登录限流：${rate_limit_login_rpm} req/min / IP
#   - SSL 终止（${ssl_enabled ? "已启用" : "已禁用"}）
#   - 安全响应头（CSP / X-Frame-Options / HSTS）
#   - Gzip 压缩（${enable_gzip ? "已启用" : "已禁用"}）
#   - 上游健康检查
# =============================================================================

user  nginx;
worker_processes  ${worker_processes};
error_log  /var/log/nginx/error.log notice;
pid        /var/run/nginx.pid;

events {
    worker_connections  ${worker_connections};
    use epoll;
    multi_accept on;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    # ── 访问日志（JSON 格式，对接 ELK）────────────────────────────────────
    log_format json_combined escape=json
        '{'
            '"time":"$time_iso8601",'
            '"remote_addr":"$remote_addr",'
            '"method":"$request_method",'
            '"uri":"$request_uri",'
            '"status":$status,'
            '"body_bytes":$body_bytes_sent,'
            '"request_time":$request_time,'
            '"upstream_time":"$upstream_response_time",'
            '"http_referer":"$http_referer",'
            '"http_user_agent":"$http_user_agent",'
            '"http_x_forwarded_for":"$http_x_forwarded_for"'
        '}';

    access_log  /var/log/nginx/access.log  json_combined;

    sendfile        on;
    tcp_nopush      on;
    tcp_nodelay     on;
    keepalive_timeout  65;
    server_tokens  off;   # 隐藏 Nginx 版本，防信息泄露

    client_max_body_size ${client_max_body_size_mb}m;

    # ── Gzip 压缩（减少 JSON API 响应体积约 70%）───────────────────────
    %{ if enable_gzip ~}
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_min_length 256;
    gzip_types
        application/json
        application/javascript
        text/css
        text/javascript
        text/plain
        text/xml
        image/svg+xml;
    %{ endif ~}

    # ─────────────────────────────────────────────────────────────────────
    # 限流 Zone 定义（TECH_SPEC 6.3 接口限流细化）
    # ─────────────────────────────────────────────────────────────────────

    # 全局 IP 限流：${rate_limit_global_rps} req/s
    # 10m Zone 约可追踪 160,000 个唯一 IP
    limit_req_zone $binary_remote_addr zone=global_ip:10m rate=${rate_limit_global_rps}r/s;

    # 登录接口限流：${rate_limit_login_rpm} req/min / IP
    limit_req_zone $binary_remote_addr zone=login_ip:2m rate=${rate_limit_login_rpm}r/m;

    # 限流日志级别（记录 429 日志，便于监控告警）
    limit_req_status  429;
    limit_req_log_level warn;

    # ─────────────────────────────────────────────────────────────────────
    # 上游配置（API 负载均衡）
    # ─────────────────────────────────────────────────────────────────────
    upstream scrm_api {
        %{ for host in api_upstream_hosts ~}
        server ${host}:${api_port} weight=1 max_fails=3 fail_timeout=30s;
        %{ endfor ~}

        keepalive 32;  # 连接池，减少 TCP 握手开销
    }

    # ─────────────────────────────────────────────────────────────────────
    # HTTP Server（${ssl_enabled ? "重定向至 HTTPS" : "直接服务"}）
    # ─────────────────────────────────────────────────────────────────────
    server {
        listen 80;
        server_name ${domain};

        %{ if ssl_enabled ~}
        # HTTP → HTTPS 强制跳转
        return 301 https://$host$request_uri;
        %{ else ~}
        # 非 SSL 环境（dev/test）直接处理请求
        include /etc/nginx/conf.d/locations.conf;
        %{ endif ~}
    }

    %{ if ssl_enabled ~}
    # ─────────────────────────────────────────────────────────────────────
    # HTTPS Server（staging / prod）
    # ─────────────────────────────────────────────────────────────────────
    server {
        listen 443 ssl http2;
        server_name ${domain};

        # ── SSL 证书 ──────────────────────────────────────────────────
        ssl_certificate      /etc/nginx/ssl/fullchain.pem;
        ssl_certificate_key  /etc/nginx/ssl/privkey.pem;

        # ── SSL 加固（Mozilla Intermediate 兼容性配置）───────────────
        ssl_protocols TLSv1.2 TLSv1.3;
        ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256;
        ssl_prefer_server_ciphers off;
        ssl_session_cache shared:SSL:10m;
        ssl_session_timeout 1d;
        ssl_session_tickets off;

        # OCSP Stapling（减少证书验证延迟）
        ssl_stapling on;
        ssl_stapling_verify on;

        include /etc/nginx/conf.d/locations.conf;
    }
    %{ endif ~}
}
