# =============================================================================
# environments/staging/backend.tf — 预发环境（同 Prod 配置，用于上线前验证）
# 推荐使用远程 State，与 CI/CD 流水线集成
# =============================================================================

terraform {
  # Staging 强烈推荐远程 State（取消注释并填写项目 ID）
  # backend "http" {
  #   address        = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/staging"
  #   lock_address   = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/staging/lock"
  #   unlock_address = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/staging/lock"
  #   username       = "gitlab-ci-token"
  #   password       = "$CI_JOB_TOKEN"
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
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
