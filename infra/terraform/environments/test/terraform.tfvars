# =============================================================================
# environments/test/terraform.tfvars — 非敏感变量
# 敏感变量通过 TF_VAR_ 环境变量注入（参考 dev/terraform.tfvars 注释）
# =============================================================================

api_image      = "registry.company.com/scrm-api:latest-test"
frontend_image = "registry.company.com/scrm-frontend:latest-test"
