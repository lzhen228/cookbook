#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ENV_FILE="${ROOT_DIR}/.env.prod"
COMPOSE_FILE="${ROOT_DIR}/docker-compose.prod.yml"

require_command() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "[ERROR] missing command: $1" >&2
    exit 1
  fi
}

require_command docker
docker compose version >/dev/null 2>&1 || {
  echo "[ERROR] docker compose plugin is required" >&2
  exit 1
}

if [[ ! -f "${ENV_FILE}" ]]; then
  echo "[ERROR] missing ${ENV_FILE}" >&2
  echo "[INFO] copy .env.prod.example and fill real values before deployment" >&2
  exit 1
fi

cd "${ROOT_DIR}"

# 停止旧容器（保留 volume 数据），避免端口冲突
docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" down --remove-orphans || true

# 按已知容器名强制清理游离容器（历史部署残留，compose down 清不到同名旧容器）
for name in scrm-api scrm-frontend scrm-postgres scrm-redis scrm-minio; do
  if docker inspect "$name" &>/dev/null; then
    echo "[INFO] removing stale container: ${name}"
    docker rm -f "$name" || true
  fi
done

# 释放宿主机端口（兼容非 Docker 进程占用，如历史直接部署的 Java 进程）
for port in 8080 80; do
  if fuser "${port}/tcp" &>/dev/null 2>&1; then
    echo "[INFO] killing process on host port ${port}"
    fuser -k "${port}/tcp" || true
  elif ss -tlnp "sport = :${port}" 2>/dev/null | grep -q ":${port}"; then
    pid=$(ss -tlnp "sport = :${port}" | grep -oP 'pid=\K[0-9]+' | head -1)
    [[ -n "$pid" ]] && { echo "[INFO] killing pid ${pid} on port ${port}"; kill -9 "$pid" || true; }
  fi
done

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
