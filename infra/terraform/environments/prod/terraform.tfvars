# =============================================================================
# environments/prod/terraform.tfvars
#
# ⚠️⚠️⚠️  生产环境安全规范  ⚠️⚠️⚠️
#
# 1. 本文件【禁止】包含任何密码、密钥、Token
# 2. 所有 sensitive 变量必须通过以下方式之一注入：
#    - Vault：由运维配置中心注入容器环境变量
#    - GitLab CI/CD Masked + Protected Variables
#    - 部署脚本读取 Vault 后 export TF_VAR_xxx
#
# 3. 镜像 tag 由 CI/CD 流水线构建完成后传入：
#    terraform apply -var="api_image=registry.../scrm-api:a1b2c3d4-20260320"
#
# 4. terraform plan 必须在 staging 验证通过后才能 apply
#    参考 CLAUDE.md 8.2 发布流程
# =============================================================================

# 镜像（由 CI/CD 动态替换，本文件值为占位符）
api_image      = "registry.company.com/scrm-api:REPLACE_BY_CI"
frontend_image = "registry.company.com/scrm-frontend:REPLACE_BY_CI"

# 域名和证书（由运维填写）
domain        = "scrm.company.com"
ssl_cert_path = "/etc/ssl/scrm/fullchain.pem"
ssl_key_path  = "/etc/ssl/scrm/privkey.pem"
