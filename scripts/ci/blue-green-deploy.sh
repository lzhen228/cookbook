#!/usr/bin/env bash
# =============================================================================
# scripts/ci/blue-green-deploy.sh — 蓝绿部署核心脚本（零停机切换）
#
# 用法：
#   bash blue-green-deploy.sh <env> <tag> <api_image_base> <frontend_image_base>
#
# 示例：
#   bash blue-green-deploy.sh prod a1b2c3d4-20260320 \
#     registry.company.com/scrm-api \
#     registry.company.com/scrm-frontend
#
# 蓝绿切换流程：
#   1. 读取当前活跃色（/opt/scrm/active_color，默认 blue）
#   2. 确定非活跃色（新版本将部署到此色）
#   3. Docker login 到 Registry
#   4. 停止并移除旧的非活跃色容器（清理残留）
#   5. 启动新版本到非活跃色（注入所有敏感环境变量）
#   6. 健康检查（liveness + readiness，最长 120s）
#   7. 通过 → 更新 Nginx upstream 配置文件 → nginx -s reload
#   8. 等待 30s 观察期（监控错误率）
#   9. 执行冒烟测试
#   10. 成功 → 停止旧活跃色容器 → 写入新 active_color
#   11. 失败 → 恢复旧 upstream → nginx -s reload → 停新容器 → 告警
#
# 敏感变量（由调用方通过 env 注入，不写入脚本）：
#   REGISTRY, REGISTRY_USER, REGISTRY_PASS
#   DB_PASSWORD, REDIS_PASSWORD, MINIO_SECRET, JWT_SECRET, XXLJOB_TOKEN
#   WXBOT_WEBHOOK, NOTIFY_EMAIL（可选，用于失败告警）
# =============================================================================

set -euo pipefail

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
BLUE_C='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log_info()  { echo -e "${GREEN}[INFO]${NC}  $(date '+%H:%M:%S') $*"; }
log_warn()  { echo -e "${YELLOW}[WARN]${NC}  $(date '+%H:%M:%S') $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $(date '+%H:%M:%S') $*" >&2; }
log_step()  { echo -e "\n${BLUE_C}${BOLD}▶ $*${NC}"; }

# ── 参数解析 ──────────────────────────────────────────────────────────────────
ENV="${1:?'缺少参数: env (dev|test|staging|prod)'}"
TAG="${2:?'缺少参数: image tag'}"
API_IMAGE_BASE="${3:?'缺少参数: api image base'}"
FRONTEND_IMAGE_BASE="${4:?'缺少参数: frontend image base'}"

API_IMAGE="${API_IMAGE_BASE}:${TAG}"
FRONTEND_IMAGE="${FRONTEND_IMAGE_BASE}:${TAG}"

# ── 配置常量 ──────────────────────────────────────────────────────────────────
STATE_FILE="/opt/scrm/active_color"           # 活跃色状态文件
NGINX_UPSTREAM_FILE="/etc/nginx/conf.d/scrm-upstream.conf"  # Nginx upstream 配置
NGINX_UPSTREAM_BACKUP="${NGINX_UPSTREAM_FILE}.backup"
SCRM_NETWORK="scrm-${ENV}-network"           # Docker 网络
API_REPLICA_COUNT=2                           # API 副本数（staging/prod）
API_PORT=8080                                 # API 容器内部端口
HEALTH_CHECK_TIMEOUT=120                      # 健康检查超时（秒）
HEALTH_CHECK_INTERVAL=5                       # 健康检查间隔（秒）
OBSERVE_SECONDS=30                            # 切换后观察期（秒）
LOG_DIR="/var/log/scrm/${ENV}"               # 日志目录

# staging 单副本
[ "$ENV" = "staging" ] && API_REPLICA_COUNT=1

# ── 必要环境变量检查 ──────────────────────────────────────────────────────────
check_required_env() {
  local REQUIRED=(REGISTRY_USER REGISTRY_PASS DB_PASSWORD REDIS_PASSWORD JWT_SECRET)
  for var in "${REQUIRED[@]}"; do
    [ -z "${!var:-}" ] && { log_error "必须设置环境变量：${var}"; exit 1; }
  done
}

# ── Docker 登录（凭证不落入命令历史）─────────────────────────────────────────
docker_login() {
  log_step "Docker Login..."
  echo "${REGISTRY_PASS}" | docker login "${REGISTRY:-}" \
    --username "${REGISTRY_USER}" \
    --password-stdin
  log_info "Docker Login 成功"
}

# ── 拉取镜像 ──────────────────────────────────────────────────────────────────
pull_images() {
  log_step "拉取镜像..."
  docker pull "${API_IMAGE}"
  docker pull "${FRONTEND_IMAGE}"
  log_info "镜像拉取完成"
}

# ── 启动新色容器 ──────────────────────────────────────────────────────────────
start_new_color() {
  local COLOR="$1"
  log_step "启动新色容器（${COLOR}）..."

  for i in $(seq 0 $((API_REPLICA_COUNT - 1))); do
    local CONTAINER_NAME="scrm-${ENV}-api-${COLOR}-${i}"

    # 清理同名残留容器
    docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

    # 宿主机日志目录
    mkdir -p "${LOG_DIR}/api-${COLOR}-${i}"

    docker run -d \
      --name    "${CONTAINER_NAME}" \
      --network "${SCRM_NETWORK}" \
      --network-alias "api-${COLOR}-${i}" \
      --restart unless-stopped \
      --memory  "4g" \
      --cpus    "2" \
      --label   "com.scrm.env=${ENV}" \
      --label   "com.scrm.color=${COLOR}" \
      --label   "com.scrm.tag=${TAG}" \
      --label   "com.scrm.instance=${i}" \
      \
      -e SPRING_PROFILES_ACTIVE="${ENV}" \
      -e SERVER_PORT="${API_PORT}" \
      -e APP_LOG_LEVEL="INFO" \
      \
      -e DB_HOST="postgres-primary" \
      -e DB_PORT="5432" \
      -e DB_NAME="scrm" \
      -e DB_USERNAME="scrm_user" \
      -e DB_PASSWORD="${DB_PASSWORD}" \
      -e DB_READONLY_HOST="postgres-replica" \
      -e DB_POOL_MAX_SIZE="20" \
      \
      -e REDIS_HOST="redis" \
      -e REDIS_PORT="6379" \
      -e REDIS_PASSWORD="${REDIS_PASSWORD}" \
      \
      -e KAFKA_BOOTSTRAP_SERVERS="kafka:9092" \
      -e KAFKA_CONSUMER_GROUP_ID="scrm-${ENV}-api" \
      \
      -e MINIO_ENDPOINT="http://minio:9000" \
      -e MINIO_ACCESS_KEY="scrm_minio_admin" \
      -e MINIO_SECRET_KEY="${MINIO_SECRET:-}" \
      -e MINIO_BUCKET_REPORTS="scrm-reports" \
      \
      -e JWT_SECRET="${JWT_SECRET}" \
      -e JWT_ACCESS_TOKEN_TTL_SECONDS="7200" \
      -e JWT_REFRESH_TOKEN_TTL_SECONDS="604800" \
      \
      -e XXLJOB_ADMIN_URL="http://xxljob:8088/xxl-job-admin" \
      -e XXLJOB_ACCESS_TOKEN="${XXLJOB_TOKEN:-}" \
      -e XXLJOB_EXECUTOR_PORT="$((9000 + i))" \
      -e XXLJOB_EXECUTOR_APP_NAME="scrm-executor-${ENV}" \
      \
      -e SCRM_SCORING_EXECUTOR_CORE_POOL_SIZE="8" \
      -e SCRM_SCORING_EXECUTOR_MAX_POOL_SIZE="16" \
      -e EXT_HTTP_CONNECT_TIMEOUT_SECONDS="3" \
      -e EXT_HTTP_READ_TIMEOUT_SECONDS="10" \
      \
      -e JAVA_OPTS="-server -Xms2g -Xmx3g -XX:+UseG1GC -XX:MaxGCPauseMillis=200 -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/app/logs/heapdump.hprof -Dfile.encoding=UTF-8" \
      \
      -v "${LOG_DIR}/api-${COLOR}-${i}:/app/logs" \
      "${API_IMAGE}"

    log_info "容器启动：${CONTAINER_NAME}"
  done
}

# ── 容器健康检查（等待 readiness probe） ─────────────────────────────────────
wait_for_healthy() {
  local COLOR="$1"
  log_step "健康检查（${COLOR}色容器）..."

  for i in $(seq 0 $((API_REPLICA_COUNT - 1))); do
    local CONTAINER="scrm-${ENV}-api-${COLOR}-${i}"
    local ELAPSED=0

    log_info "检查容器：${CONTAINER}"
    until docker exec "${CONTAINER}" \
        curl -sf "http://localhost:${API_PORT}/actuator/health/readiness" > /dev/null 2>&1; do

      if [ $ELAPSED -ge $HEALTH_CHECK_TIMEOUT ]; then
        log_error "容器 ${CONTAINER} 健康检查超时（${HEALTH_CHECK_TIMEOUT}s）"
        # 输出容器日志帮助诊断
        docker logs --tail=50 "${CONTAINER}" >&2 || true
        return 1
      fi

      sleep $HEALTH_CHECK_INTERVAL
      ELAPSED=$((ELAPSED + HEALTH_CHECK_INTERVAL))
      printf "  等待就绪...（%ds / %ds）\r" $ELAPSED $HEALTH_CHECK_TIMEOUT
    done

    echo ""
    log_info "容器就绪：${CONTAINER}（耗时 ${ELAPSED}s）"
  done

  log_info "[✓] 所有 ${COLOR}色容器健康检查通过"
}

# ── 生成 Nginx upstream 配置 ──────────────────────────────────────────────────
generate_nginx_upstream() {
  local COLOR="$1"
  local FILE="$2"

  cat > "${FILE}" <<NGINX
# =====================================================================
# Nginx upstream — 环境: ${ENV} | 活跃色: ${COLOR} | 版本: ${TAG}
# 由 blue-green-deploy.sh 自动生成，请勿手动修改
# 生成时间: $(date -u '+%Y-%m-%dT%H:%M:%SZ')
# =====================================================================
upstream scrm_api {
$(for i in $(seq 0 $((API_REPLICA_COUNT - 1))); do
  echo "    server scrm-${ENV}-api-${COLOR}-${i}:${API_PORT} weight=1 max_fails=3 fail_timeout=30s;"
done)
    keepalive 32;
}
NGINX
}

# ── 切换 Nginx upstream ───────────────────────────────────────────────────────
switch_nginx_upstream() {
  local NEW_COLOR="$1"
  log_step "切换 Nginx upstream → ${NEW_COLOR}..."

  # 备份当前 upstream（回滚时恢复用）
  cp "${NGINX_UPSTREAM_FILE}" "${NGINX_UPSTREAM_BACKUP}" 2>/dev/null || true

  # 写入新 upstream
  generate_nginx_upstream "${NEW_COLOR}" "${NGINX_UPSTREAM_FILE}"

  # 语法检测 + 零停机 reload（使用 nginx -s reload 而非 restart）
  nginx -t 2>&1 || {
    log_error "Nginx 配置语法错误，恢复备份"
    cp "${NGINX_UPSTREAM_BACKUP}" "${NGINX_UPSTREAM_FILE}"
    return 1
  }
  nginx -s reload
  log_info "[✓] Nginx upstream 已切换至 ${NEW_COLOR}，reload 完成"
}

# ── 恢复 Nginx upstream（回滚时调用）─────────────────────────────────────────
restore_nginx_upstream() {
  log_step "恢复 Nginx upstream（回滚）..."
  if [ -f "${NGINX_UPSTREAM_BACKUP}" ]; then
    cp "${NGINX_UPSTREAM_BACKUP}" "${NGINX_UPSTREAM_FILE}"
    nginx -t && nginx -s reload
    log_info "[✓] Nginx upstream 已恢复"
  else
    log_warn "找不到备份文件，手动检查 Nginx 配置"
  fi
}

# ── 停止容器组 ────────────────────────────────────────────────────────────────
stop_color_containers() {
  local COLOR="$1"
  local ACTION="${2:-stop}"  # stop | rm
  log_step "${ACTION} ${COLOR}色容器..."

  for i in $(seq 0 $((API_REPLICA_COUNT - 1))); do
    local CONTAINER="scrm-${ENV}-api-${COLOR}-${i}"
    if docker ps -q --filter "name=^${CONTAINER}$" | grep -q .; then
      docker stop "${CONTAINER}" 2>/dev/null || true
      [ "$ACTION" = "rm" ] && docker rm "${CONTAINER}" 2>/dev/null || true
      log_info "${ACTION}：${CONTAINER}"
    else
      log_info "容器不存在，跳过：${CONTAINER}"
    fi
  done
}

# ── 主流程 ────────────────────────────────────────────────────────────────────
main() {
  echo ""
  echo "╔════════════════════════════════════════════════════════╗"
  echo "║           🚀 SCRM 蓝绿部署脚本                       ║"
  echo "╠════════════════════════════════════════════════════════╣"
  printf  "║  环境       : %-42s║\n" "$ENV"
  printf  "║  镜像 Tag   : %-42s║\n" "$TAG"
  printf  "║  时间       : %-42s║\n" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
  echo "╚════════════════════════════════════════════════════════╝"
  echo ""

  # 读取当前活跃色
  CURRENT_COLOR=$(cat "${STATE_FILE}" 2>/dev/null || echo "blue")
  if [ "$CURRENT_COLOR" = "blue" ]; then
    NEW_COLOR="green"
  else
    NEW_COLOR="blue"
  fi

  log_info "当前活跃色：${CURRENT_COLOR}  →  新部署色：${NEW_COLOR}"

  # 1. 前置检查
  check_required_env

  # 2. 登录并拉取镜像
  docker_login
  pull_images

  # 3. 启动新色容器
  start_new_color "${NEW_COLOR}"

  # 4. 健康检查（失败则立即清理新容器）
  if ! wait_for_healthy "${NEW_COLOR}"; then
    log_error "健康检查失败，中止蓝绿切换，清理新容器..."
    stop_color_containers "${NEW_COLOR}" "rm"
    # 发送告警
    if [ -n "${WXBOT_WEBHOOK:-}" ]; then
      bash "$(dirname "$0")/notify.sh" \
        "failure" "🚨 蓝绿部署失败：健康检查未通过" \
        "环境: ${ENV}\n版本: ${TAG}\n原因: 新色 (${NEW_COLOR}) 容器健康检查超时" \
        "${WXBOT_WEBHOOK}" "${NOTIFY_EMAIL:-}"
    fi
    exit 1
  fi

  # 5. 切换 Nginx upstream（零停机）
  switch_nginx_upstream "${NEW_COLOR}"

  # 6. 观察期（等待请求稳定路由到新容器）
  log_step "观察期 ${OBSERVE_SECONDS}s..."
  sleep "${OBSERVE_SECONDS}"

  # 7. 冒烟测试验证新版本
  log_step "冒烟测试验证新版本..."
  PROD_URL="https://$(hostname -f)"
  [ "$ENV" = "staging" ] && PROD_URL="https://staging.scrm.company.com"
  [ "$ENV" = "prod" ]    && PROD_URL="https://scrm.company.com"

  if bash "$(dirname "$0")/smoke-test.sh" "${PROD_URL}" "${ENV}" "${TEST_TOKEN:-}"; then
    # ── 成功：停止旧色容器，更新状态文件 ─────────────────────────────────
    log_step "冒烟测试通过，停止旧色容器（${CURRENT_COLOR}）..."
    stop_color_containers "${CURRENT_COLOR}" "rm"
    echo "${NEW_COLOR}" > "${STATE_FILE}"

    # 记录部署历史
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') ${ENV} ${TAG} ${NEW_COLOR} SUCCESS" \
      >> /opt/scrm/deploy-history.log

    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║          ✅ 蓝绿部署成功                              ║"
    printf  "║  新活跃色  : %-42s║\n" "${NEW_COLOR}"
    printf  "║  版本 Tag  : %-42s║\n" "${TAG}"
    echo "╚════════════════════════════════════════════════════════╝"
  else
    # ── 失败：恢复旧 upstream，停止新容器，告警 ────────────────────────────
    log_error "冒烟测试失败，执行蓝绿回滚..."
    restore_nginx_upstream
    sleep 5   # 等待 Nginx reload 生效
    stop_color_containers "${NEW_COLOR}" "rm"

    # 记录部署历史
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') ${ENV} ${TAG} ${NEW_COLOR} FAILED_ROLLBACK" \
      >> /opt/scrm/deploy-history.log

    # 发送告警
    if [ -n "${WXBOT_WEBHOOK:-}" ]; then
      bash "$(dirname "$0")/notify.sh" \
        "failure" "🚨 蓝绿部署失败：冒烟测试未通过，已自动回滚" \
        "环境: ${ENV}\n版本: ${TAG}\n回滚至: ${CURRENT_COLOR}色\n请查看日志" \
        "${WXBOT_WEBHOOK}" "${NOTIFY_EMAIL:-}"
    fi

    echo ""
    echo "╔════════════════════════════════════════════════════════╗"
    echo "║   ❌ 蓝绿部署失败，已恢复至旧版本                    ║"
    printf  "║  回滚至色  : %-42s║\n" "${CURRENT_COLOR}"
    echo "╚════════════════════════════════════════════════════════╝"
    exit 1
  fi
}

main "$@"
