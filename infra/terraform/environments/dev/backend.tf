# =============================================================================
# environments/dev/backend.tf
# Terraform 状态后端配置 — 开发环境
#
# 本地后端用于开发环境（无需共享状态）
# 生产环境替换为远程后端（GitLab Terraform HTTP State / S3 等）
# =============================================================================

terraform {
  # Dev 使用本地 state（无需 CI/CD 共享）
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

# ── Docker Provider（连接本地 Docker Daemon）─────────────────────────────────
provider "docker" {
  # 默认连接本地 Docker socket
  # Linux: unix:///var/run/docker.sock
  # Windows（Docker Desktop）: npipe:////./pipe/docker_engine
  host = "unix:///var/run/docker.sock"
}
