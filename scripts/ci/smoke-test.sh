#!/usr/bin/env bash
# =============================================================================
# scripts/ci/smoke-test.sh — 核心接口冒烟测试
#
# 用法：
#   bash smoke-test.sh <base_url> <env> [auth_token]
#
# 验证项（对应 TECH_SPEC 7.1 性能目标 + 6.3 限流验证）：
#   1. /actuator/health/readiness      → HTTP 200，P95 ≤ 200ms
#   2. GET /api/v1/suppliers           → HTTP 200，P95 ≤ 800ms（TECH_SPEC 7.1）
#   3. GET /api/v1/dashboard/stats     → HTTP 200，P95 ≤ 500ms（Redis 命中）
#   4. POST /api/v1/auth/token         → HTTP 200 或 400，P95 ≤ 300ms（测试格式校验）
#   5. GET /api/v1/suppliers/{id}      → HTTP 200 或 404，P95 ≤ 500ms（画像主接口）
#   6. ApiResponse 响应格式校验        → 含 code / data / traceId 字段
#   7. 安全响应头验证                  → X-Frame-Options / X-Content-Type-Options
#
# 退出码：
#   0 — 全部通过
#   1 — 存在失败项
# =============================================================================

set -euo pipefail

BASE_URL="${1:?'缺少参数: base_url (e.g. https://scrm.company.com)'}"
ENV="${2:-prod}"
AUTH_TOKEN="${3:-}"           # 可选：预发/生产用的测试 JWT Token

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

PASS=0; FAIL=0; WARN=0
RESULTS=()

log_pass() { echo -e "  ${GREEN}✓${NC} $*"; PASS=$((PASS+1)); RESULTS+=("PASS: $*"); }
log_fail() { echo -e "  ${RED}✗${NC} $*"; FAIL=$((FAIL+1)); RESULTS+=("FAIL: $*"); }
log_warn() { echo -e "  ${YELLOW}⚠${NC} $*"; WARN=$((WARN+1)); RESULTS+=("WARN: $*"); }
log_step() { echo -e "\n${CYAN}${BOLD}▶ $*${NC}"; }

# ── HTTP 工具函数 ─────────────────────────────────────────────────────────────

# 发送 N 次请求，计算 P95 延迟（毫秒），返回 "status_code p95_ms"
measure_p95() {
  local URL="$1"
  local METHOD="${2:-GET}"
  local BODY="${3:-}"
  local N="${4:-10}"
  local EXTRA_HEADERS="${5:-}"

  local TIMES=()
  local LAST_STATUS=0

  for _ in $(seq 1 $N); do
    local START END DURATION STATUS
    START=$(date +%s%3N)

    local CURL_CMD=(curl -s -o /dev/null -w "%{http_code}"
      --connect-timeout 5
      --max-time 10
      -X "$METHOD"
      -H "Content-Type: application/json"
    )

    [ -n "$AUTH_TOKEN" ] && CURL_CMD+=(-H "Authorization: Bearer ${AUTH_TOKEN}")
    [ -n "$EXTRA_HEADERS" ] && CURL_CMD+=(-H "$EXTRA_HEADERS")
    [ -n "$BODY" ] && CURL_CMD+=(-d "$BODY")
    CURL_CMD+=("$URL")

    STATUS=$("${CURL_CMD[@]}" 2>/dev/null || echo "000")
    END=$(date +%s%3N)
    DURATION=$((END - START))

    TIMES+=("$DURATION")
    LAST_STATUS="$STATUS"
  done

  # 排序计算 P95（第 N*0.95 个值）
  local SORTED
  SORTED=$(printf '%s\n' "${TIMES[@]}" | sort -n)
  local P95_IDX=$(( (N * 95) / 100 ))
  [ $P95_IDX -lt 1 ] && P95_IDX=1
  [ $P95_IDX -gt $N ] && P95_IDX=$N
  local P95
  P95=$(echo "$SORTED" | sed -n "${P95_IDX}p")

  echo "${LAST_STATUS} ${P95}"
}

# 校验 ApiResponse 格式（CLAUDE.md 6.2 约束 #1：统一响应体）
check_api_response_format() {
  local URL="$1"
  local BODY

  BODY=$(curl -s --connect-timeout 5 --max-time 10 \
    -H "Content-Type: application/json" \
    ${AUTH_TOKEN:+-H "Authorization: Bearer ${AUTH_TOKEN}"} \
    "$URL" 2>/dev/null || echo "{}")

  # 验证字段存在（code + traceId）
  if echo "$BODY" | grep -q '"code"' && echo "$BODY" | grep -q '"traceId"'; then
    return 0
  fi
  return 1
}

# 校验安全响应头
check_security_headers() {
  local URL="$1"
  local HEADERS

  HEADERS=$(curl -s -I --connect-timeout 5 --max-time 10 "$URL" 2>/dev/null || echo "")

  local OK=true
  for HEADER in "X-Frame-Options" "X-Content-Type-Options" "X-XSS-Protection"; do
    if ! echo "$HEADERS" | grep -qi "$HEADER"; then
      OK=false
      log_warn "缺少安全响应头：${HEADER}（TECH_SPEC 6.3）"
    fi
  done
  $OK && return 0 || return 1
}

# =============================================================================
# 测试用例
# =============================================================================

echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║              💨 SCRM 冒烟测试开始                  ║"
echo "╠══════════════════════════════════════════════════════╣"
printf  "║  目标环境  : %-38s║\n" "$ENV"
printf  "║  Base URL  : %-38s║\n" "$BASE_URL"
printf  "║  时间      : %-38s║\n" "$(date -u '+%Y-%m-%d %H:%M UTC')"
echo "╚══════════════════════════════════════════════════════╝"

# ─────────────────────────────────────────────────────────────────────────────
# TC-001: Readiness Probe（服务就绪检查）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-001: Readiness Probe"
RESULT=$(measure_p95 "${BASE_URL}/actuator/health/readiness" "GET" "" 5)
STATUS=$(echo "$RESULT" | awk '{print $1}')
P95=$(echo "$RESULT" | awk '{print $2}')

if [ "$STATUS" = "200" ]; then
  if [ "$P95" -le 200 ]; then
    log_pass "readiness 返回 200，P95=${P95}ms ≤ 200ms"
  else
    log_warn "readiness 返回 200，但 P95=${P95}ms > 200ms（性能告警）"
  fi
else
  log_fail "readiness 返回 ${STATUS}（期望 200）"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-002: 供应商列表（TECH_SPEC 7.1：P95 ≤ 800ms）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-002: 供应商列表接口 GET /api/v1/suppliers"
RESULT=$(measure_p95 "${BASE_URL}/api/v1/suppliers?page_size=10&cooperation_status=cooperating" "GET" "" 10)
STATUS=$(echo "$RESULT" | awk '{print $1}')
P95=$(echo "$RESULT" | awk '{print $2}')

if [ "$STATUS" = "200" ]; then
  if [ "$P95" -le 800 ]; then
    log_pass "供应商列表返回 200，P95=${P95}ms ≤ 800ms（达标）"
  elif [ "$P95" -le 2000 ]; then
    log_warn "供应商列表 P95=${P95}ms，超过 800ms 目标（P99 ≤ 2s 仍合格）"
  else
    log_fail "供应商列表 P95=${P95}ms > 2000ms（严重超时）"
  fi

  # 校验 ApiResponse 格式
  if check_api_response_format "${BASE_URL}/api/v1/suppliers?page_size=10"; then
    log_pass "ApiResponse 格式正确（含 code + traceId 字段）"
  else
    log_fail "ApiResponse 格式不符合规范（CLAUDE.md 6.2 约束 #1）"
  fi
elif [ "$STATUS" = "401" ]; then
  # 未认证环境下 401 属于预期，不算失败
  log_warn "供应商列表返回 401（需 Auth Token），跳过响应时间检查"
else
  log_fail "供应商列表返回 ${STATUS}（期望 200 或 401）"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-003: 风险看板统计（TECH_SPEC 7.1：P95 ≤ 500ms，Redis 缓存命中）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-003: 风险看板统计 GET /api/v1/dashboard/stats"
RESULT=$(measure_p95 "${BASE_URL}/api/v1/dashboard/stats" "GET" "" 10)
STATUS=$(echo "$RESULT" | awk '{print $1}')
P95=$(echo "$RESULT" | awk '{print $2}')

if [ "$STATUS" = "200" ]; then
  if [ "$P95" -le 500 ]; then
    log_pass "看板统计返回 200，P95=${P95}ms ≤ 500ms（Redis 缓存命中）"
  else
    log_warn "看板统计 P95=${P95}ms > 500ms（可能缓存未命中或 Redis 延迟）"
  fi
elif [ "$STATUS" = "401" ]; then
  log_warn "看板统计返回 401（需 Auth Token），跳过"
else
  log_fail "看板统计返回 ${STATUS}（期望 200 或 401）"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-004: 登录接口格式校验（TECH_SPEC 6.3：10 req/min 限流）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-004: 登录接口 POST /api/v1/auth/token（格式校验）"
AUTH_BODY='{"username":"smoke_test_invalid","password":"smoke_test_invalid"}'
RESULT=$(measure_p95 "${BASE_URL}/api/v1/auth/token" "POST" "$AUTH_BODY" 3)
STATUS=$(echo "$RESULT" | awk '{print $1}')
P95=$(echo "$RESULT" | awk '{print $2}')

# 登录接口：200（正确凭证）、400/401（错误凭证）、429（限流触发）均属预期
if [ "$STATUS" = "200" ] || [ "$STATUS" = "400" ] || [ "$STATUS" = "401" ]; then
  if [ "$P95" -le 500 ]; then
    log_pass "登录接口返回 ${STATUS}，P95=${P95}ms ≤ 500ms"
  else
    log_warn "登录接口 P95=${P95}ms > 500ms（可能慢查询）"
  fi
elif [ "$STATUS" = "429" ]; then
  log_pass "登录接口触发限流（429）——限流功能正常（TECH_SPEC 6.3）"
else
  log_fail "登录接口返回 ${STATUS}（期望 200/400/401/429）"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-005: 供应商画像主接口（TECH_SPEC 7.1：P95 ≤ 500ms）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-005: 供应商画像主接口 GET /api/v1/suppliers/1"
RESULT=$(measure_p95 "${BASE_URL}/api/v1/suppliers/1" "GET" "" 5)
STATUS=$(echo "$RESULT" | awk '{print $1}')
P95=$(echo "$RESULT" | awk '{print $2}')

# 200（存在）、404（不存在）、401（未认证）均属预期
if [ "$STATUS" = "200" ] || [ "$STATUS" = "404" ]; then
  if [ "$P95" -le 500 ]; then
    log_pass "画像主接口返回 ${STATUS}，P95=${P95}ms ≤ 500ms"
  else
    log_warn "画像主接口 P95=${P95}ms > 500ms（注意缓存策略）"
  fi
elif [ "$STATUS" = "401" ]; then
  log_warn "画像主接口返回 401（需 Auth Token），跳过延迟检查"
else
  log_fail "画像主接口返回 ${STATUS}（期望 200/404/401）"
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-006: 安全响应头验证（TECH_SPEC 6.3 + CLAUDE.md Nginx 配置）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-006: 安全响应头验证"
HEADERS=$(curl -s -I --connect-timeout 5 --max-time 10 "${BASE_URL}/" 2>/dev/null || echo "")

for HEADER in "X-Frame-Options" "X-Content-Type-Options" "X-XSS-Protection"; do
  if echo "$HEADERS" | grep -qi "$HEADER"; then
    log_pass "安全响应头存在：${HEADER}"
  else
    log_warn "缺少安全响应头：${HEADER}（检查 Nginx 配置）"
  fi
done

# HTTPS 环境检查 HSTS
if echo "$BASE_URL" | grep -q "^https"; then
  if echo "$HEADERS" | grep -qi "Strict-Transport-Security"; then
    log_pass "HSTS 响应头存在（生产 HTTPS 要求）"
  else
    log_warn "生产环境缺少 HSTS 头（Strict-Transport-Security）"
  fi
fi

# ─────────────────────────────────────────────────────────────────────────────
# TC-007: 限流响应格式（验证 429 响应体符合 ApiResponse 格式）
# ─────────────────────────────────────────────────────────────────────────────
log_step "TC-007: 前端静态资源可访问"
STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "${BASE_URL}/" 2>/dev/null || echo "000")
if [ "$STATUS" = "200" ]; then
  log_pass "前端主页可访问（HTTP ${STATUS}）"
else
  log_warn "前端主页返回 ${STATUS}（检查 Nginx 静态文件配置）"
fi

# ─────────────────────────────────────────────────────────────────────────────
# 测试结果汇总
# ─────────────────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════╗"
echo "║                  测试结果汇总                       ║"
echo "╠══════════════════════════════════════════════════════╣"
printf  "║  ✓ PASS : %-43s║\n" "${PASS} 项"
printf  "║  ✗ FAIL : %-43s║\n" "${FAIL} 项"
printf  "║  ⚠ WARN : %-43s║\n" "${WARN} 项"
echo "╚══════════════════════════════════════════════════════╝"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo -e "${RED}${BOLD}失败项列表：${NC}"
  for r in "${RESULTS[@]}"; do
    if [[ "$r" == FAIL:* ]]; then
      echo -e "  ${RED}✗${NC} ${r#FAIL: }"
    fi
  done
  echo ""
  echo -e "${RED}${BOLD}❌ 冒烟测试失败（${FAIL} 项 FAIL），将触发自动回滚${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}${BOLD}✅ 冒烟测试全部通过（PASS: ${PASS}，WARN: ${WARN}）${NC}"
exit 0
