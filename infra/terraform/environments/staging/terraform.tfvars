# =============================================================================
# environments/staging/terraform.tfvars
# ⚠️ 所有敏感变量（密码/密钥）必须通过 CI/CD 变量注入，不写入此文件
# =============================================================================

# 镜像 tag 由 CI/CD 流水线动态传入（terraform apply -var api_image=xxx）
api_image      = "registry.company.com/scrm-api:REPLACE_BY_CI"
frontend_image = "registry.company.com/scrm-frontend:REPLACE_BY_CI"

domain        = "staging.scrm.company.com"
ssl_cert_path = "/etc/ssl/scrm-staging/fullchain.pem"
ssl_key_path  = "/etc/ssl/scrm-staging/privkey.pem"
