# =============================================================================
# locations.conf.tpl — Nginx location 块模板
# 由 nginx.conf include，拆分便于 SSL/非SSL 共用同一份路由逻辑
#
# 环境: ${env}
# =============================================================================

# ── 安全响应头（全局） ────────────────────────────────────────────────────
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Content-Security-Policy（防 XSS，TECH_SPEC 6.3）
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self'" always;

%{ if ssl_enabled ~}
# HSTS（告知浏览器强制 HTTPS，max-age=1年）
add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
%{ endif ~}

# ── 代理公共配置（提取复用）────────────────────────────────────────────────
proxy_http_version      1.1;
proxy_set_header        Upgrade $http_upgrade;
proxy_set_header        Connection "";           # 支持 keepalive
proxy_set_header        Host $host;
proxy_set_header        X-Real-IP $remote_addr;
proxy_set_header        X-Forwarded-For $proxy_add_x_forwarded_for;
proxy_set_header        X-Forwarded-Proto $scheme;
proxy_set_header        X-Request-ID $request_id;  # 链路追踪 traceId

proxy_connect_timeout   3s;    # 连接超时 3s（TECH_SPEC 6.2 约束 #6）
proxy_read_timeout      ${proxy_read_timeout_s}s;
proxy_send_timeout      ${proxy_read_timeout_s}s;
proxy_buffering         on;
proxy_buffer_size       4k;
proxy_buffers           8 8k;

# ── 登录接口（严格限流：10 req/min/IP，失败保护）──────────────────────────
# 对应 TECH_SPEC 6.3：POST /auth/token 限流规则
location = /api/v1/auth/token {
    # nodelay：超过速率立即返回 429（不排队等待）
    limit_req zone=login_ip burst=3 nodelay;
    limit_req zone=global_ip burst=50 nodelay;

    # 限流响应体（符合 ApiResponse<T> 格式，TECH_SPEC 6.2 约束 #1）
    limit_req_dry_run off;

    proxy_pass  http://scrm_api;
}

# ── 全局 API 限流：200 req/s / IP（Nginx 层实现）─────────────────────────
# 对应 TECH_SPEC 6.3：全局 API 限流规则
location /api/ {
    limit_req zone=global_ip burst=100 nodelay;

    # 自定义 429 响应（JSON 格式，与 ApiResponse 一致）
    error_page 429 @rate_limit_exceeded;

    proxy_pass  http://scrm_api;
}

# ── 限流超限响应（JSON 格式）──────────────────────────────────────────────
location @rate_limit_exceeded {
    default_type application/json;
    return 429 '{"code":429001,"msg":"请求过于频繁，请稍后重试","data":null,"traceId":"$request_id"}';
}

# ── 前端静态资源（Nginx 直出，高效缓存）─────────────────────────────────
location / {
    root    /usr/share/nginx/html;
    index   index.html;

    # SPA 路由回退（所有非 API 路径都返回 index.html）
    try_files $uri $uri/ /index.html;

    # 静态资源长期缓存（带 hash 文件名）
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff2|woff|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
        access_log off;
    }

    # HTML 不缓存（确保部署后立即生效）
    location ~* \.html$ {
        expires -1;
        add_header Cache-Control "no-store, no-cache, must-revalidate";
    }
}

# ── 健康检查端点（负载均衡器探针，不限流，不记日志）─────────────────────
location = /health {
    access_log off;
    default_type text/plain;
    return 200 "ok\n";
}

# ── Actuator 端点（仅内网访问，防止信息泄露）─────────────────────────────
location /api/actuator/ {
    # 仅允许内网 IP（Docker 网络 + 运维机器）
    allow 172.16.0.0/12;
    allow 10.0.0.0/8;
    allow 192.168.0.0/16;
    deny all;

    proxy_pass http://scrm_api;
}

# ── WebSocket 支持（如有实时通知需求）───────────────────────────────────
location /ws/ {
    proxy_pass  http://scrm_api;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_read_timeout 3600s;
}

# ── 禁止访问隐藏文件（如 .git、.env）──────────────────────────────────
location ~ /\. {
    deny all;
    access_log off;
    log_not_found off;
}
