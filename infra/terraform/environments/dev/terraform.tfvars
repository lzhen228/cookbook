# =============================================================================
# environments/dev/terraform.tfvars
# 开发环境非敏感变量值
#
# ⚠️  敏感变量（db_password / redis_password / jwt_secret 等）
#     不允许写入此文件！必须通过以下方式之一注入：
#
#     方式 1（推荐，本地开发）：
#       export TF_VAR_db_password="your-dev-password"
#       export TF_VAR_redis_password="your-redis-password"
#       export TF_VAR_minio_root_password="your-minio-password"
#       export TF_VAR_jwt_secret="your-256bit-jwt-secret"
#       export TF_VAR_xxljob_admin_password="your-xxljob-password"
#       export TF_VAR_xxljob_db_password="your-db-password"
#
#     方式 2（CI/CD）：
#       GitLab CI/CD Variables（Masked + Protected）
#
# 参考 .env.example 获取所需变量列表
# =============================================================================

# 镜像 tag（dev 环境使用本地构建 tag）
api_image      = "scrm-api:local"
frontend_image = "scrm-frontend:local"
