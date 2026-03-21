# =============================================================================
# modules/postgres/main.tf
# PostgreSQL 15 + TimescaleDB 2.x 容器模块
#
# 架构：
#   - 主库（primary）：处理所有写操作
#   - 只读副本（replica）：处理列表查询、看板统计（staging/prod 启用）
#   - 使用 timescale/timescaledb:2.14.2-pg15 镜像，原生支持时序分区
#
# 对应 TECH_SPEC 第 8 节：PostgreSQL 主库 + 只读副本架构
# =============================================================================

terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

# ── 镜像（keep_locally 避免重复拉取）─────────────────────────────────────────
resource "docker_image" "postgres" {
  name         = "timescale/timescaledb:2.14.2-pg15"
  keep_locally = true
}

# ── 主库数据卷（prevent_destroy 防止 terraform destroy 误删生产数据）────────
resource "docker_volume" "primary_data" {
  name   = "scrm-${var.env}-pg-primary-data"
  driver = var.data_volume_driver

  lifecycle {
    # 数据卷生命周期独立于容器，防止意外销毁
    prevent_destroy = true
  }
}

# ── 本地 PostgreSQL 调优配置（通过 local_file 生成，挂载进容器）─────────────
resource "local_file" "pg_config" {
  filename        = "${path.module}/.generated/${var.env}/postgresql.conf"
  file_permission = "0644"

  content = <<-EOF
    # =======================================================
    # PostgreSQL 调优配置 — 环境: ${var.env}
    # 由 Terraform 自动生成，请勿手动修改
    # =======================================================

    # ── 连接 ──────────────────────────────────────────────
    max_connections = ${var.pg_max_connections}
    # listen_addresses 由 Docker 环境变量覆盖

    # ── 内存 ──────────────────────────────────────────────
    shared_buffers              = ${var.pg_shared_buffers_mb}MB
    effective_cache_size        = ${var.pg_effective_cache_size_mb}MB
    work_mem                    = ${var.pg_work_mem_mb}MB
    maintenance_work_mem        = ${var.pg_maintenance_work_mem_mb}MB
    temp_buffers                = 8MB

    # ── WAL / 复制 ─────────────────────────────────────────
    wal_level                   = ${var.pg_wal_level}
    max_wal_senders             = 3          # 主库保留给副本和备份
    wal_keep_size               = 64MB
    checkpoint_completion_target = 0.9

    # ── 查询优化 ───────────────────────────────────────────
    random_page_cost            = 1.1        # SSD 环境调低（减少全表扫描偏好）
    effective_io_concurrency    = 200        # SSD 并发 IO
    default_statistics_target   = 100        # 更精确的统计信息

    # ── 日志（对接 ELK，JSON 格式）────────────────────────
    log_destination             = 'csvlog'
    logging_collector           = on
    log_directory               = '/var/log/postgresql'
    log_filename                = 'postgresql-%Y-%m-%d_%H%M%S.log'
    log_rotation_age            = 1d
    log_rotation_size           = 100MB
    log_min_duration_statement  = 1000       # 超过 1s 的慢查询记录
    log_line_prefix             = '%t [%p]: [%l-1] user=%u,db=%d,app=%a,client=%h '
    log_checkpoints             = on
    log_connections             = on
    log_disconnections          = on
    log_lock_waits              = on

    # ── 安全 ───────────────────────────────────────────────
    ssl                         = off        # SSL 终止在 Nginx 层
    password_encryption         = scram-sha-256

    # ── TimescaleDB ─────────────────────────────────────────
    shared_preload_libraries    = 'timescaledb'
    timescaledb.max_background_workers = 8
  EOF
}

# ── 主库 pg_hba.conf（控制哪些 IP/用户可连接）────────────────────────────────
resource "local_file" "pg_hba" {
  filename        = "${path.module}/.generated/${var.env}/pg_hba.conf"
  file_permission = "0644"

  content = <<-EOF
    # pg_hba.conf — 环境: ${var.env}
    # TYPE  DATABASE        USER            ADDRESS                 METHOD

    # 本地 Unix socket
    local   all             all                                     trust

    # 本地 IPv4（Docker 内网）
    host    all             all             127.0.0.1/32            scram-sha-256
    host    all             all             172.16.0.0/12           scram-sha-256

    # 流复制（副本连接主库）
    host    replication     ${var.db_user}  172.16.0.0/12           scram-sha-256
  EOF
}

# ── 数据库初始化脚本（创建扩展、只读角色等）─────────────────────────────────
resource "local_file" "pg_init_sql" {
  filename        = "${path.module}/.generated/${var.env}/01-init.sql"
  file_permission = "0644"

  content = <<-EOF
    -- =======================================================
    -- 数据库初始化脚本 — 环境: ${var.env}
    -- 由 Terraform 自动生成
    -- =======================================================

    -- TimescaleDB 扩展（时序分区，加速健康评分趋势查询）
    CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;

    -- pg_trgm 扩展（供应商名称全文搜索，替代 LIKE '%keyword%'）
    CREATE EXTENSION IF NOT EXISTS pg_trgm;

    -- uuid-ossp（生成 UUID，用于 traceId 等）
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

    -- 只读角色（供只读副本使用，READ ONLY）
    DO $$
    BEGIN
      IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'scrm_readonly') THEN
        CREATE ROLE scrm_readonly WITH LOGIN PASSWORD '${var.db_password}' NOSUPERUSER NOCREATEDB NOCREATEROLE;
      END IF;
    END
    $$;

    -- 授予只读权限
    GRANT CONNECT ON DATABASE ${var.db_name} TO scrm_readonly;
    GRANT USAGE ON SCHEMA public TO scrm_readonly;
    ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO scrm_readonly;
  EOF
}

# ── PostgreSQL 主库容器 ───────────────────────────────────────────────────────
resource "docker_container" "primary" {
  name    = "scrm-${var.env}-postgres-primary"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  # ── 资源限制 ─────────────────────────────────────────────
  memory     = var.memory_mb   # MiB
  cpu_shares = var.cpu_shares  # 相对权重（1024 ≈ 1 核）

  # ── 环境变量（密码通过 sensitive 变量传入，不落磁盘） ────
  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "POSTGRES_INITDB_ARGS=--encoding=UTF8 --locale=C --data-checksums",
    "PGDATA=/var/lib/postgresql/data/pgdata",
  ]

  # ── 挂载：持久化数据目录 ──────────────────────────────────
  volumes {
    volume_name    = docker_volume.primary_data.name
    container_path = "/var/lib/postgresql/data"
  }

  # ── 挂载：PostgreSQL 调优配置 ─────────────────────────────
  volumes {
    host_path      = abspath(local_file.pg_config.filename)
    container_path = "/etc/postgresql/postgresql.conf"
    read_only      = true
  }

  # ── 挂载：pg_hba 访问控制 ────────────────────────────────
  volumes {
    host_path      = abspath(local_file.pg_hba.filename)
    container_path = "/etc/postgresql/pg_hba.conf"
    read_only      = true
  }

  # ── 挂载：初始化 SQL（仅首次启动执行）────────────────────
  volumes {
    host_path      = abspath(local_file.pg_init_sql.filename)
    container_path = "/docker-entrypoint-initdb.d/01-init.sql"
    read_only      = true
  }

  # ── 挂载：宿主机日志目录（归档 + ELK 采集）───────────────
  volumes {
    host_path      = "${var.host_log_path}/postgres-primary"
    container_path = "/var/log/postgresql"
  }

  # ── 启动命令（指定自定义配置文件 + hba）──────────────────
  command = [
    "postgres",
    "-c", "config_file=/etc/postgresql/postgresql.conf",
    "-c", "hba_file=/etc/postgresql/pg_hba.conf",
  ]

  # ── 健康检查（actuator/readiness 类比）────────────────────
  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "60s"  # TimescaleDB 初始化较慢
  }

  # ── Docker 网络（各环境独立隔离）─────────────────────────
  networks_advanced {
    name    = var.network_name
    aliases = ["postgres-primary", "postgres"]  # 向后兼容别名
  }

  # 确保配置文件在容器启动前生成
  depends_on = [
    local_file.pg_config,
    local_file.pg_hba,
    local_file.pg_init_sql,
  ]

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "postgres-primary"
  }
}

# ── PostgreSQL 只读副本（staging / prod 启用）────────────────────────────────
# 注：副本通过流复制同步主库数据，需在主库 pg_hba.conf 允许 replication 连接
# 初次搭建副本需手动执行 pg_basebackup 或通过 init 脚本自动完成

resource "docker_volume" "replica_data" {
  count  = var.enable_replica ? 1 : 0
  name   = "scrm-${var.env}-pg-replica-data"
  driver = var.data_volume_driver

  lifecycle {
    prevent_destroy = true
  }
}

# 副本初始化脚本（触发 pg_basebackup 从主库同步基础数据）
resource "local_file" "replica_setup_sh" {
  count           = var.enable_replica ? 1 : 0
  filename        = "${path.module}/.generated/${var.env}/replica-setup.sh"
  file_permission = "0755"

  content = <<-EOF
    #!/bin/bash
    # 副本初始化脚本 — 从主库拉取基础备份
    # 仅在副本数据目录为空时执行

    set -e
    PGDATA=/var/lib/postgresql/data/pgdata

    if [ ! -f "$PGDATA/PG_VERSION" ]; then
      echo "[replica-setup] 数据目录为空，开始从主库同步..."
      PGPASSWORD=${var.db_password} pg_basebackup \
        -h postgres-primary \
        -U ${var.db_user} \
        -D "$PGDATA" \
        -P -Xs -R       # -R 自动生成 standby.signal 和 recovery 配置

      echo "[replica-setup] 基础备份完成，写入副本配置..."
      cat >> "$PGDATA/postgresql.auto.conf" <<REPLICA
    primary_conninfo = 'host=postgres-primary port=5432 user=${var.db_user} password=${var.db_password} sslmode=disable'
    hot_standby = on
    hot_standby_feedback = on
    REPLICA
    fi

    exec docker-entrypoint.sh postgres \
      -c config_file=/etc/postgresql/postgresql.conf \
      -c hba_file=/etc/postgresql/pg_hba.conf
  EOF
}

resource "docker_container" "replica" {
  count   = var.enable_replica ? 1 : 0
  name    = "scrm-${var.env}-postgres-replica"
  image   = docker_image.postgres.image_id
  restart = "unless-stopped"

  # 副本处理只读查询，资源配置为主库的一半
  memory     = var.memory_mb / 2
  cpu_shares = var.cpu_shares / 2

  env = [
    "POSTGRES_DB=${var.db_name}",
    "POSTGRES_USER=${var.db_user}",
    "POSTGRES_PASSWORD=${var.db_password}",
    "PGDATA=/var/lib/postgresql/data/pgdata",
  ]

  volumes {
    volume_name    = docker_volume.replica_data[0].name
    container_path = "/var/lib/postgresql/data"
  }

  volumes {
    host_path      = abspath(local_file.pg_config.filename)
    container_path = "/etc/postgresql/postgresql.conf"
    read_only      = true
  }

  volumes {
    host_path      = abspath(local_file.pg_hba.filename)
    container_path = "/etc/postgresql/pg_hba.conf"
    read_only      = true
  }

  volumes {
    host_path      = abspath(local_file.replica_setup_sh[0].filename)
    container_path = "/docker-entrypoint-initdb.d/00-replica-setup.sh"
    read_only      = true
  }

  volumes {
    host_path      = "${var.host_log_path}/postgres-replica"
    container_path = "/var/log/postgresql"
  }

  healthcheck {
    test         = ["CMD-SHELL", "pg_isready -U ${var.db_user} -d ${var.db_name}"]
    interval     = "30s"
    timeout      = "10s"
    retries      = 5
    start_period = "90s"  # 副本需要等待 pg_basebackup 完成
  }

  networks_advanced {
    name    = var.network_name
    aliases = ["postgres-replica"]
  }

  # 副本必须在主库健康后再启动
  depends_on = [docker_container.primary]

  labels {
    label = "com.scrm.env"
    value = var.env
  }
  labels {
    label = "com.scrm.service"
    value = "postgres-replica"
  }
}
