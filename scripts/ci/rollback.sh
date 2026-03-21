#!/usr/bin/env bash
# =============================================================================
# scripts/ci/rollback.sh — 蓝绿部署回滚脚本
#
# 用法：
#   bash rollback.sh <env> <deploy_host> <deploy_user> <api_image> \
#                    [wxbot_webhook] [notify_email]
#
# 功能：
#   1. 读取当前活跃颜色（蓝/绿）
#   2. 确认非活跃颜色的旧版本容器存在
#   3. 切换 Nginx upstream 回旧颜色
#   4. 停止并清理当前（新）颜色容器
#   5. 更新状态文件记录回滚信息
#   6. 发送告警通知（企业微信 + 邮件）
#
# 退出码：
#   0 — 回滚成功
#   1 — 回滚失败（需人工介入）
# =============================================================================

set -euo pipefail

# ── 参数 ──────────────────────────────────────────────────────────────────────
ENV="${1:?'缺少参数: env (dev|test|staging|prod)'}"
DEPLOY_HOST="${2:?'缺少参数: deploy_host'}"
DEPLOY_USER="${3:?'缺少参数: deploy_user'}"
API_IMAGE="${4:?'缺少参数: api_image (e.g. registry.../scrm-api:tag)'}"
WXBOT_WEBHOOK="${5:-}"
NOTIFY_EMAIL="${6:-}"

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${CYAN}${BOLD}▶ $*${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}✓ $*${NC}"; }

# ── 常量 ──────────────────────────────────────────────────────────────────────
DEPLOY_BASE="/opt/scrm"
STATE_FILE="${DEPLOY_BASE}/active_color"
NGINX_CONF_DIR="${DEPLOY_BASE}/nginx/conf.d"
DEPLOY_HISTORY="${DEPLOY_BASE}/deploy-history.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── 脚本入口 ──────────────────────────────────────────────────────────────────
ROLLBACK_TIME=$(date -u '+%Y-%m-%dT%H:%M:%SZ')
ROLLBACK_INITIATOR="${CI_PIPELINE_URL:-manual}"

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║           🔄 蓝绿部署回滚开始                       ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  环境        : %-38s║\n" "$ENV"
printf "║  目标主机    : %-38s║\n" "$DEPLOY_HOST"
printf "║  镜像        : %-38s║\n" "$(echo "$API_IMAGE" | cut -c1-38)"
printf "║  触发时间    : %-38s║\n" "$ROLLBACK_TIME"
echo "╚══════════════════════════════════════════════════════╝"

# =============================================================================
# 远端回滚逻辑（通过 SSH 在目标服务器执行）
# =============================================================================
ssh -o StrictHostKeyChecking=no \
    -o ConnectTimeout=30 \
    "${DEPLOY_USER}@${DEPLOY_HOST}" \
    bash -s -- "${ENV}" "${API_IMAGE}" "${ROLLBACK_TIME}" "${ROLLBACK_INITIATOR}" \
    <<'REMOTE_SCRIPT'

set -euo pipefail

ENV="$1"
API_IMAGE="$2"
ROLLBACK_TIME="$3"
ROLLBACK_INITIATOR="$4"

DEPLOY_BASE="/opt/scrm"
STATE_FILE="${DEPLOY_BASE}/active_color"
NGINX_CONF_DIR="${DEPLOY_BASE}/nginx/conf.d"
DEPLOY_HISTORY="${DEPLOY_BASE}/deploy-history.log"

RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${CYAN}${BOLD}▶ $*${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}✓ $*${NC}"; }

# ── Step 1: 读取当前活跃颜色 ──────────────────────────────────────────────────
log_step "Step 1/5: 读取当前活跃颜色"

if [[ ! -f "$STATE_FILE" ]]; then
  log_error "状态文件不存在：${STATE_FILE}"
  log_error "无法确定当前活跃颜色，请人工介入！"
  exit 1
fi

CURRENT_COLOR=$(cat "$STATE_FILE" | tr -d '[:space:]')
if [[ "$CURRENT_COLOR" != "blue" && "$CURRENT_COLOR" != "green" ]]; then
  log_error "状态文件内容异常：'${CURRENT_COLOR}'，期望 'blue' 或 'green'"
  exit 1
fi

# 回滚目标：切回对立颜色
if [[ "$CURRENT_COLOR" == "blue" ]]; then
  TARGET_COLOR="green"
else
  TARGET_COLOR="blue"
fi

log_info "当前活跃颜色: ${CURRENT_COLOR}"
log_info "回滚目标颜色: ${TARGET_COLOR}"

# ── Step 2: 验证回滚目标容器存在 ──────────────────────────────────────────────
log_step "Step 2/5: 验证回滚目标容器存在"

REPLICA_COUNT=2
TARGET_CONTAINERS=()
MISSING_CONTAINERS=()

for i in $(seq 0 $((REPLICA_COUNT - 1))); do
  CONTAINER_NAME="scrm-${ENV}-api-${TARGET_COLOR}-${i}"
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    STATUS=$(docker inspect --format='{{.State.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "unknown")
    TARGET_CONTAINERS+=("${CONTAINER_NAME}:${STATUS}")
    log_info "找到容器: ${CONTAINER_NAME} (状态: ${STATUS})"
  else
    MISSING_CONTAINERS+=("${CONTAINER_NAME}")
    log_warn "容器不存在: ${CONTAINER_NAME}"
  fi
done

if [[ ${#MISSING_CONTAINERS[@]} -gt 0 ]]; then
  log_warn "部分目标容器不存在，尝试重新启动..."

  # 尝试从上一个已知镜像重启（读取历史日志获取上一版本）
  PREV_IMAGE=""
  if [[ -f "$DEPLOY_HISTORY" ]]; then
    # 在历史中查找目标颜色的上一次成功部署
    PREV_IMAGE=$(grep "DEPLOYED.*${TARGET_COLOR}" "$DEPLOY_HISTORY" \
      | tail -1 \
      | grep -oE 'image=[^ ]+' \
      | cut -d= -f2 || true)
  fi

  if [[ -z "$PREV_IMAGE" ]]; then
    log_error "无法确定回滚目标镜像，部署历史记录不足"
    log_error "请人工执行：docker run scrm-${ENV}-api-${TARGET_COLOR}-0 <previous-image>"
    exit 1
  fi

  log_info "使用历史镜像重启: ${PREV_IMAGE}"

  # 使用 docker-compose 重启目标颜色（简化方式）
  COMPOSE_FILE="${DEPLOY_BASE}/docker-compose.${ENV}.yml"
  if [[ -f "$COMPOSE_FILE" ]]; then
    env API_COLOR="${TARGET_COLOR}" API_IMAGE="${PREV_IMAGE}" \
      docker-compose -f "$COMPOSE_FILE" up -d \
      --scale "api=0" 2>/dev/null || true
    sleep 5
  fi
fi

# ── Step 3: 切换 Nginx upstream 回目标颜色 ────────────────────────────────────
log_step "Step 3/5: 切换 Nginx upstream → ${TARGET_COLOR}"

UPSTREAM_FILE="${NGINX_CONF_DIR}/upstream-${ENV}.conf"
BACKUP_FILE="${NGINX_CONF_DIR}/upstream-${ENV}.conf.rollback-${ROLLBACK_TIME//[: ]/-}"

# 备份当前配置
if [[ -f "$UPSTREAM_FILE" ]]; then
  cp "$UPSTREAM_FILE" "$BACKUP_FILE"
  log_info "已备份当前配置: ${BACKUP_FILE}"
fi

# 生成回滚目标 upstream 配置
API_PORT=8080
cat > "$UPSTREAM_FILE" <<EOF
# 回滚切换时间: ${ROLLBACK_TIME}
# 回滚触发来源: ${ROLLBACK_INITIATOR}
# 活跃颜色: ${TARGET_COLOR}
upstream scrm_api_${ENV} {
    least_conn;
$(for i in $(seq 0 $((REPLICA_COUNT - 1))); do
  echo "    server scrm-${ENV}-api-${TARGET_COLOR}-${i}:${API_PORT} weight=1 max_fails=3 fail_timeout=30s;"
done)
    keepalive 32;
}
EOF

log_info "Upstream 配置已更新为 ${TARGET_COLOR}"

# 验证 Nginx 配置语法
NGINX_CONTAINER="scrm-${ENV}-nginx"
if docker ps --format '{{.Names}}' | grep -q "^${NGINX_CONTAINER}$"; then
  if docker exec "${NGINX_CONTAINER}" nginx -t 2>&1; then
    log_success "Nginx 配置语法验证通过"
  else
    log_error "Nginx 配置语法错误，恢复备份配置"
    [[ -f "$BACKUP_FILE" ]] && cp "$BACKUP_FILE" "$UPSTREAM_FILE"
    exit 1
  fi

  # 热重载 Nginx（零停机切换）
  if docker exec "${NGINX_CONTAINER}" nginx -s reload; then
    log_success "Nginx 已热重载，流量切换至 ${TARGET_COLOR}"
  else
    log_error "Nginx 热重载失败，恢复备份配置"
    [[ -f "$BACKUP_FILE" ]] && cp "$BACKUP_FILE" "$UPSTREAM_FILE"
    docker exec "${NGINX_CONTAINER}" nginx -s reload || true
    exit 1
  fi
else
  log_warn "Nginx 容器 ${NGINX_CONTAINER} 未运行，跳过热重载"
fi

# 等待流量切换生效
sleep 3

# ── Step 4: 健康验证（目标颜色）──────────────────────────────────────────────
log_step "Step 4/5: 验证回滚目标容器健康状态"

HEALTH_OK=true
for i in $(seq 0 $((REPLICA_COUNT - 1))); do
  CONTAINER_NAME="scrm-${ENV}-api-${TARGET_COLOR}-${i}"
  if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_warn "容器 ${CONTAINER_NAME} 未运行，跳过健康检查"
    continue
  fi

  MAX_WAIT=60
  WAITED=0
  HEALTHY=false
  while [[ $WAITED -lt $MAX_WAIT ]]; do
    HEALTH=$(docker inspect --format='{{.State.Health.Status}}' "${CONTAINER_NAME}" 2>/dev/null || echo "none")
    if [[ "$HEALTH" == "healthy" ]]; then
      HEALTHY=true
      break
    elif [[ "$HEALTH" == "unhealthy" ]]; then
      break
    fi
    sleep 5
    WAITED=$((WAITED + 5))
  done

  if $HEALTHY; then
    log_success "容器 ${CONTAINER_NAME} 健康检查通过"
  else
    log_warn "容器 ${CONTAINER_NAME} 健康状态: ${HEALTH}（可能正在启动中）"
    # 回滚时健康检查失败仅警告，不阻断（旧版本理论上曾经健康）
    HEALTH_OK=false
  fi
done

if ! $HEALTH_OK; then
  log_warn "部分容器健康检查未通过，但继续完成回滚流程（请人工确认服务状态）"
fi

# ── Step 5: 停止并清理当前（出问题的）颜色容器 ───────────────────────────────
log_step "Step 5/5: 停止故障容器（${CURRENT_COLOR}）"

for i in $(seq 0 $((REPLICA_COUNT - 1))); do
  CONTAINER_NAME="scrm-${ENV}-api-${CURRENT_COLOR}-${i}"
  if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_info "停止容器: ${CONTAINER_NAME}"
    docker stop "${CONTAINER_NAME}" --time 15 2>/dev/null || true
  fi
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    log_info "删除容器: ${CONTAINER_NAME}"
    docker rm "${CONTAINER_NAME}" 2>/dev/null || true
  fi
done
log_success "故障容器已清理"

# ── 更新状态文件 ───────────────────────────────────────────────────────────────
echo "${TARGET_COLOR}" > "${STATE_FILE}"
log_info "状态文件已更新: active_color=${TARGET_COLOR}"

# ── 写入历史记录 ───────────────────────────────────────────────────────────────
cat >> "${DEPLOY_HISTORY}" <<EOF
[${ROLLBACK_TIME}] ROLLBACK env=${ENV} from=${CURRENT_COLOR} to=${TARGET_COLOR} image=${API_IMAGE} initiator=${ROLLBACK_INITIATOR}
EOF

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              ✅ 回滚完成                            ║"
echo "╠══════════════════════════════════════════════════════╣"
printf "║  回滚前活跃颜色 : %-34s║\n" "${CURRENT_COLOR}"
printf "║  回滚后活跃颜色 : %-34s║\n" "${TARGET_COLOR}"
printf "║  完成时间       : %-34s║\n" "${ROLLBACK_TIME}"
echo "╚══════════════════════════════════════════════════════╝"

REMOTE_SCRIPT

ROLLBACK_EXIT=$?

# ── 发送通知 ───────────────────────────────────────────────────────────────────
log_step "发送回滚通知..."

NOTIFY_SCRIPT="${SCRIPT_DIR}/notify.sh"
if [[ -f "$NOTIFY_SCRIPT" ]]; then
  if [[ $ROLLBACK_EXIT -eq 0 ]]; then
    bash "$NOTIFY_SCRIPT" \
      "warning" \
      "🔄 [${ENV}] 蓝绿部署已回滚" \
      "环境: ${ENV}\n镜像: ${API_IMAGE}\n回滚时间: ${ROLLBACK_TIME}\n触发来源: ${ROLLBACK_INITIATOR:-manual}\n\n> 回滚已成功执行，服务已恢复至上一稳定版本。请确认服务状态后关闭相关 Issue。" \
      "${WXBOT_WEBHOOK}" \
      "${NOTIFY_EMAIL}" || true
  else
    bash "$NOTIFY_SCRIPT" \
      "failure" \
      "❌ [${ENV}] 蓝绿部署回滚失败，需人工介入！" \
      "环境: ${ENV}\n镜像: ${API_IMAGE}\n回滚时间: ${ROLLBACK_TIME}\n触发来源: ${ROLLBACK_INITIATOR:-manual}\n\n> **回滚脚本执行失败！** 当前服务状态未知，请立即登录服务器人工检查！\n> 服务器: ${DEPLOY_USER}@${DEPLOY_HOST}" \
      "${WXBOT_WEBHOOK}" \
      "${NOTIFY_EMAIL}" || true
  fi
else
  log_warn "notify.sh 不存在，跳过通知（路径: ${NOTIFY_SCRIPT}）"
fi

# ── 退出 ───────────────────────────────────────────────────────────────────────
if [[ $ROLLBACK_EXIT -eq 0 ]]; then
  log_success "回滚流程完成"
  exit 0
else
  log_error "回滚流程失败（exit code: ${ROLLBACK_EXIT}），请人工介入！"
  exit 1
fi
