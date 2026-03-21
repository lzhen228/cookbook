# =============================================================================
# environments/test/backend.tf
# Terraform 状态后端 — 测试环境
# =============================================================================

terraform {
  # Test 环境推荐使用 GitLab Managed State（团队共享状态）
  # 取消注释下方 http 后端并删除 local 后端即可切换
  #
  # backend "http" {
  #   address        = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/test"
  #   lock_address   = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/test/lock"
  #   unlock_address = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/test/lock"
  #   username       = "gitlab-ci-token"
  #   password       = "$TF_HTTP_PASSWORD"  # 从 CI 变量注入
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
  #   retry_wait_min = 5
  # }

  backend "local" {
    path = "terraform.tfstate"
  }

  required_version = ">= 1.6.0"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {
  host = "unix:///var/run/docker.sock"
}
