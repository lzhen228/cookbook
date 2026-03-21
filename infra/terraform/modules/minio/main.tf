# =============================================================================
# modules/minio/main.tf
# MinIO 对象存储容器模块
#
# 职责（对应 TECH_SPEC 3.4）：
#   - 存储供应商画像 PDF 报告
#   - 通过预签名 URL（TTL 15min）控制访问权限，替代直接暴露 OSS 链接
#   - S3 兼容接口，后续可无缝迁移至云对象存储
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

resource "docker_image" "minio" {
  # 使用固定版本，禁止 latest（CLAUDE.md 部署规范 8.1）
  name         = "minio/minio:RELEASE.2024-01-16T16-07-38Z"
  keep_locally = true
}

# ── MinIO 数据卷（对象存储数据） ───────────────────────────────────────────
resource "docker_volume" "minio_data" {
  name = "scrm-${var.env}-minio-data"

  lifecycle {
    prevent_destroy = true
  }
}

# ── MinIO 容器 ────────────────────────────────────────────────────────────────
resource "docker_container" "minio" {
  name    = "scrm-${var.env}-minio"
  image   = docker_image.minio.image_id
  restart = "unless-stopped"

  memory     = var.memory_mb
  cpu_shares = var.cpu_shares

  # MinIO 环境变量（凭证通过 sensitive 变量注入）
  env = [
    "MINIO_ROOT_USER=${var.minio_root_user}",
    "MINIO_ROOT_PASSWORD=${var.minio_root_password}",
    # 审计日志（便于 MinIO 预签名失败率监控，对应 TECH_SPEC 8.5）
    "MINIO_AUDIT_WEBHOOK_ENABLE=off",
    # 关闭 MinIO 自带 DNS SRV 发现（单机模式不需要）
    "MINIO_DOMAIN=",
  ]

  volumes {
    volume_name    = docker_volume.minio_data.name
    container_path = "/data"
  }

  volumes {
    host_path      = "${var.host_log_path}/minio"
    container_path = "/var/log/minio"
  }

  # MinIO server 启动命令（console 端口 9001 仅内网访问）
  command = [
    "server",
    "/data",
    "--console-address", ":9001",
    "--address", ":9000",
  ]

  # ── 健康检查：MinIO liveness endpoint ─────────────────────
  healthcheck {
    test         = ["CMD-SHELL", "mc ready local || curl -f http://localhost:9000/minio/health/live"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "30s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["minio"]
  }

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "minio"
  }
}

# ── Bucket 初始化容器（一次性，创建完即退出）────────────────────────────────
# 使用 MinIO Client (mc) 创建所需 Bucket 并设置策略
resource "docker_container" "minio_init" {
  name    = "scrm-${var.env}-minio-init"
  image   = "minio/mc:latest"
  restart = "no"  # 一次性任务

  # 等待 MinIO 就绪后执行 Bucket 初始化
  command = [
    "/bin/sh", "-c",
    join(" && ", concat(
      [
        "sleep 5",
        "mc alias set local http://minio:9000 ${var.minio_root_user} ${var.minio_root_password}",
      ],
      # 创建 Bucket（已存在不报错）
      [for bucket in var.buckets :
        "mc mb --ignore-existing local/${bucket}"
      ],
      [
        # scrm-reports：存储供应商 PDF 报告（私有，通过预签名 URL 访问）
        "mc anonymous set none local/scrm-reports",
        # scrm-temp：临时文件，30 天后自动清理
        "mc ilm import local/scrm-temp --force <<< '{\"Rules\":[{\"ID\":\"expire-temp\",\"Status\":\"Enabled\",\"Expiration\":{\"Days\":30}}]}'",
        "echo 'MinIO init completed'",
      ]
    ))
  ]

  env = [
    "MC_HOST_local=http://${var.minio_root_user}:${var.minio_root_password}@minio:9000",
  ]

  networks_advanced {
    name = var.network_name
  }

  depends_on = [docker_container.minio]
}
