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

# 强制停止仍占用关键端口的游离容器（历史部署残留，compose down 清不到）
for port in 8080 80; do
  cid=$(docker ps -q --filter "publish=${port}" 2>/dev/null || true)
  if [[ -n "$cid" ]]; then
    echo "[INFO] stopping stale container on port ${port}: ${cid}"
    docker stop "$cid" || true
  fi
done

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" up -d --build

docker compose --env-file "${ENV_FILE}" -f "${COMPOSE_FILE}" ps
