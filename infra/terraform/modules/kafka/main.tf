# =============================================================================
# modules/kafka/main.tf
# Kafka 3.6 (KRaft 模式) + XXL-Job 2.4.x 调度中心
#
# KRaft 模式（无 Zookeeper）优势：
#   - 减少组件数量，简化运维
#   - Kafka 3.3+ 生产可用，3.6 LTS
#
# Topic 规划（对应 TECH_SPEC 1.2 Kafka Topic 命名：kebab-case）：
#   - supplier.data.updated  ：供应商数据变更事件，触发实时预警引擎
#   - supplier.risk.triggered：预警触发事件，通知推送
#   - supplier.score.batch   ：批量评分任务消息
#
# 消费失败：最多重试 3 次 + 指数退避 + DLQ（.DLT 后缀）
# 单条事件处理 ≤ 30s（TECH_SPEC 2.2.2）
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# ── Kafka 3.6 镜像（bitnami，内置 KRaft 支持）────────────────────────────────
resource "docker_image" "kafka" {
  name         = "bitnami/kafka:3.6.1"
  keep_locally = true
}

resource "docker_image" "xxljob" {
  name         = "xuxueli/xxl-job-admin:2.4.0"
  keep_locally = true
}

# ── Kafka 数据卷（消息日志持久化）────────────────────────────────────────────
resource "docker_volume" "kafka_data" {
  name = "scrm-${var.env}-kafka-data"

  lifecycle {
    prevent_destroy = true
  }
}

# ── Kafka Broker（KRaft 单节点，MVP 阶段）────────────────────────────────────
resource "docker_container" "kafka" {
  name    = "scrm-${var.env}-kafka"
  image   = docker_image.kafka.image_id
  restart = "unless-stopped"

  memory     = var.memory_mb
  cpu_shares = var.cpu_shares

  env = [
    # ── KRaft 模式配置（无 Zookeeper）─────────────────────
    "KAFKA_CFG_NODE_ID=1",
    "KAFKA_CFG_PROCESS_ROLES=broker,controller",
    "KAFKA_CFG_CONTROLLER_QUORUM_VOTERS=1@kafka:9093",

    # ── 监听地址 ─────────────────────────────────────────
    # PLAINTEXT：Docker 内网通信（应用层使用）
    # CONTROLLER：KRaft 内部选举
    "KAFKA_CFG_LISTENERS=PLAINTEXT://:9092,CONTROLLER://:9093",
    "KAFKA_CFG_ADVERTISED_LISTENERS=PLAINTEXT://kafka:9092",
    "KAFKA_CFG_LISTENER_SECURITY_PROTOCOL_MAP=PLAINTEXT:PLAINTEXT,CONTROLLER:PLAINTEXT",
    "KAFKA_CFG_CONTROLLER_LISTENER_NAMES=CONTROLLER",
    "KAFKA_CFG_INTER_BROKER_LISTENER_NAME=PLAINTEXT",

    # ── Topic 默认配置 ────────────────────────────────────
    "KAFKA_CFG_NUM_PARTITIONS=${var.num_partitions}",
    "KAFKA_CFG_DEFAULT_REPLICATION_FACTOR=${var.default_replication_factor}",
    "KAFKA_CFG_MIN_INSYNC_REPLICAS=1",

    # ── 消息保留策略 ──────────────────────────────────────
    "KAFKA_CFG_LOG_RETENTION_HOURS=${var.log_retention_hours}",
    "KAFKA_CFG_LOG_RETENTION_BYTES=${var.log_retention_bytes}",
    "KAFKA_CFG_LOG_SEGMENT_BYTES=536870912",      # 512MB per segment
    "KAFKA_CFG_LOG_CLEANUP_POLICY=delete",

    # ── 生产者/消费者可靠性配置 ───────────────────────────
    # acks=all + enable.idempotence=true 保证消息不丢失
    "KAFKA_CFG_OFFSETS_TOPIC_REPLICATION_FACTOR=1",
    "KAFKA_CFG_TRANSACTION_STATE_LOG_REPLICATION_FACTOR=1",
    "KAFKA_CFG_TRANSACTION_STATE_LOG_MIN_ISR=1",

    # ── 消费者超时（单条事件处理 ≤ 30s，TECH_SPEC 2.2.2）──
    "KAFKA_CFG_GROUP_MAX_SESSION_TIMEOUT_MS=60000",
    "KAFKA_CFG_GROUP_MIN_SESSION_TIMEOUT_MS=6000",

    # ── JVM ────────────────────────────────────────────────
    "KAFKA_HEAP_OPTS=${var.kafka_heap_opts}",
    "KAFKA_CFG_LOG_DIRS=/bitnami/kafka/data",
  ]

  volumes {
    volume_name    = docker_volume.kafka_data.name
    container_path = "/bitnami/kafka"
  }

  volumes {
    host_path      = "${var.host_log_path}/kafka"
    container_path = "/opt/bitnami/kafka/logs"
  }

  healthcheck {
    test = [
      "CMD-SHELL",
      "kafka-broker-api-versions.sh --bootstrap-server localhost:9092 2>/dev/null | grep -q 'kafka'"
    ]
    interval     = "30s"
    timeout      = "15s"
    retries      = 5
    start_period = "60s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["kafka"]
  }

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "kafka"
  }
}

# ── Kafka Topic 初始化容器（一次性）──────────────────────────────────────────
# 创建业务 Topic 并配置 DLQ（Dead Letter Queue）
resource "docker_container" "kafka_init" {
  name    = "scrm-${var.env}-kafka-init"
  image   = docker_image.kafka.image_id
  restart = "no"

  command = [
    "/bin/bash", "-c",
    <<-SCRIPT
      set -e
      echo "Waiting for Kafka to be ready..."
      until kafka-broker-api-versions.sh --bootstrap-server kafka:9092 2>/dev/null | grep -q 'kafka'; do
        sleep 3
      done
      echo "Kafka ready. Creating topics..."

      # 主业务 Topic
      kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists \
        --topic supplier.data.updated \
        --partitions ${var.num_partitions} \
        --replication-factor ${var.default_replication_factor} \
        --config retention.ms=604800000 \
        --config min.insync.replicas=1

      kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists \
        --topic supplier.risk.triggered \
        --partitions ${var.num_partitions} \
        --replication-factor ${var.default_replication_factor} \
        --config retention.ms=604800000

      kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists \
        --topic supplier.score.batch \
        --partitions ${var.num_partitions} \
        --replication-factor ${var.default_replication_factor} \
        --config retention.ms=86400000

      # Dead Letter Queue（消费失败 3 次后路由至 DLQ，TECH_SPEC 6.2 约束 #7）
      kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists \
        --topic supplier.data.updated.DLT \
        --partitions 1 \
        --replication-factor ${var.default_replication_factor} \
        --config retention.ms=2592000000

      kafka-topics.sh --bootstrap-server kafka:9092 --create --if-not-exists \
        --topic supplier.risk.triggered.DLT \
        --partitions 1 \
        --replication-factor ${var.default_replication_factor} \
        --config retention.ms=2592000000

      echo "All topics created successfully"
      kafka-topics.sh --bootstrap-server kafka:9092 --list
    SCRIPT
  ]

  networks_advanced {
    name = var.network_name
  }

  depends_on = [docker_container.kafka]
}

# ── XXL-Job 调度中心 ─────────────────────────────────────────────────────────
# 职责：触发每日 00:00 批量评分 Job（TECH_SPEC 2.2.2 指标计算引擎）
resource "docker_volume" "xxljob_data" {
  name = "scrm-${var.env}-xxljob-data"
}

resource "docker_container" "xxljob" {
  name    = "scrm-${var.env}-xxljob"
  image   = docker_image.xxljob.image_id
  restart = "unless-stopped"

  memory     = var.xxljob_memory_mb
  cpu_shares = 512  # XXL-Job 调度开销小，限制较低

  env = [
    # 数据库连接（复用 scrm PostgreSQL，需提前创建 xxl_job 相关表）
    # XXL-Job 2.4.x 支持 PostgreSQL
    "PARAMS=--spring.datasource.url=jdbc:postgresql://${var.xxljob_db_host}:5432/${var.xxljob_db_name}?currentSchema=xxl_job --spring.datasource.username=${var.xxljob_db_user} --spring.datasource.password=${var.xxljob_db_password} --xxl.job.accessToken=${var.xxljob_admin_password} --server.port=8088",
  ]

  volumes {
    volume_name    = docker_volume.xxljob_data.name
    container_path = "/data/applogs"
  }

  volumes {
    host_path      = "${var.host_log_path}/xxljob"
    container_path = "/data/applogs"
  }

  healthcheck {
    test         = ["CMD-SHELL", "curl -f http://localhost:8088/xxl-job-admin/actuator/health || exit 1"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 3
    start_period = "60s"
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["xxljob"]
  }

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "xxljob"
  }
}
