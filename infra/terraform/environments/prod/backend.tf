# =============================================================================
# environments/prod/backend.tf — 生产环境
# 生产环境必须使用远程 State（防止状态文件丢失导致资源失控）
# =============================================================================

terraform {
  # ⚠️ 生产环境必须配置远程后端，删除 local 后端并取消注释以下配置
  # backend "http" {
  #   address        = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/prod"
  #   lock_address   = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/prod/lock"
  #   unlock_address = "https://gitlab.company.com/api/v4/projects/<PROJECT_ID>/terraform/state/prod/lock"
  #   username       = "gitlab-ci-token"
  #   password       = "$CI_JOB_TOKEN"
  #   lock_method    = "POST"
  #   unlock_method  = "DELETE"
  #   retry_wait_min = 5
  # }

  # 临时使用本地 state（首次初始化用，务必迁移到远程后端）
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
  # 生产服务器 Docker socket
  host = "unix:///var/run/docker.sock"
}
