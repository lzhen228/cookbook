#!/usr/bin/env bash
# ============================================================================
# 前端覆盖率校验脚本
# ============================================================================
#
# 功能：解析 Vitest 生成的 coverage-summary.json，按目录维度校验覆盖率。
#
# 核心模块覆盖率阈值（对齐 CLAUDE.md 7.1 节）：
#   - hooks/:       ≥ 80%（自定义 Hook）
#   - components/:  ≥ 60%（纯 UI 组件）
#   - pages/:       ≥ 60%（页面组件）
#   - api/:         ≥ 70%（API 请求函数）
#   - utils/:       ≥ 70%（工具函数）
#   - 项目整体:     ≥ 70%
#
# 依赖：
#   - bash 4+
#   - jq（ubuntu-latest 默认已有；GitLab CI 需在 before_script 安装）
#
# 输入文件：
#   services/frontend/coverage/coverage-summary.json
#   （由 vitest run --coverage 通过 @vitest/coverage-v8 生成）
#
# 用法：
#   bash ci/check-frontend-coverage.sh
#
# 退出码：
#   0 — 全部达标
#   1 — 存在不达标模块
# ============================================================================

set -euo pipefail

COVERAGE_JSON="services/frontend/coverage/coverage-summary.json"

# ── 阈值配置（行覆盖率 %） ──
THRESHOLD_HOOKS=80
THRESHOLD_COMPONENTS=60
THRESHOLD_PAGES=60
THRESHOLD_API=70
THRESHOLD_UTILS=70
THRESHOLD_OVERALL=70

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "============================================"
echo "  Frontend Coverage Check (Vitest v8)"
echo "============================================"
echo ""

# ─────────────────────────────────────────────
# 检查依赖
# ─────────────────────────────────────────────
if ! command -v jq &> /dev/null; then
    echo -e "${RED}[ERROR] jq is required but not installed.${NC}"
    echo "Install with: apt-get install -y jq"
    exit 1
fi

# ─────────────────────────────────────────────
# 检查报告文件
# ─────────────────────────────────────────────
if [ ! -f "$COVERAGE_JSON" ]; then
    echo -e "${YELLOW}[WARN] Coverage report not found: $COVERAGE_JSON${NC}"
    echo ""
    echo "Ensure 'pnpm test:coverage' runs with the correct reporter."
    echo "The @vitest/coverage-v8 plugin should generate coverage-summary.json."
    echo ""
    echo "Check vite.config.ts test.coverage settings:"
    echo '  coverage: { reporter: ["text", "json-summary", "lcov"] }'
    exit 1
fi

echo "Report: $COVERAGE_JSON"
echo ""

# ─────────────────────────────────────────────
# 解析函数：提取指定目录的聚合行覆盖率
# ─────────────────────────────────────────────
# coverage-summary.json 格式：
# {
#   "total": { "lines": { "total": N, "covered": N, "pct": N }, ... },
#   "path/to/file.ts": { "lines": { "total": N, "covered": N, "pct": N }, ... }
# }

get_module_coverage() {
    local module_pattern="$1"

    # 提取匹配路径的文件，聚合 lines.total 和 lines.covered
    local result
    result=$(jq -r --arg pattern "$module_pattern" '
        to_entries
        | map(select(.key != "total" and (.key | test($pattern))))
        | if length == 0 then
            {"total": 0, "covered": 0, "pct": 0}
          else
            {
              "total": (map(.value.lines.total) | add),
              "covered": (map(.value.lines.covered) | add)
            }
            | . + {"pct": (if .total > 0 then (.covered / .total * 100 | . * 10 | floor | . / 10) else 0 end)}
          end
    ' "$COVERAGE_JSON")

    echo "$result"
}

# ─────────────────────────────────────────────
# 校验各模块
# ─────────────────────────────────────────────
FAILED=0

check_module() {
    local name="$1"
    local pattern="$2"
    local threshold="$3"

    local result
    result=$(get_module_coverage "$pattern")

    local pct
    pct=$(echo "$result" | jq -r '.pct')
    local total
    total=$(echo "$result" | jq -r '.total')
    local covered
    covered=$(echo "$result" | jq -r '.covered')

    local status="✅"
    # 用 awk 做浮点比较（bash 不支持浮点）
    if echo "$pct $threshold" | awk '{exit ($1 >= $2) ? 0 : 1}'; then
        status="✅"
    else
        status="❌"
        FAILED=1
    fi

    printf "│  %-28s │  %5s%%   │  ≥%d%%     │ %s\n" \
        "$name" "$pct" "$threshold" "$status"
}

echo "┌─────────────────────────────────────────────────────────┐"
echo "│  Module                       │  Coverage  │  Threshold │"
echo "├─────────────────────────────────────────────────────────┤"

check_module "hooks/"      "src/hooks/"      "$THRESHOLD_HOOKS"
check_module "components/" "src/components/" "$THRESHOLD_COMPONENTS"
check_module "pages/"      "src/pages/"      "$THRESHOLD_PAGES"
check_module "api/"        "src/api/"        "$THRESHOLD_API"
check_module "utils/"      "src/utils/"      "$THRESHOLD_UTILS"

# ── 整体覆盖率（取 total 字段） ──
OVERALL_PCT=$(jq -r '.total.lines.pct // 0' "$COVERAGE_JSON")
OVERALL_TOTAL=$(jq -r '.total.lines.total // 0' "$COVERAGE_JSON")
OVERALL_COVERED=$(jq -r '.total.lines.covered // 0' "$COVERAGE_JSON")

OVERALL_STATUS="✅"
if echo "$OVERALL_PCT $THRESHOLD_OVERALL" | awk '{exit ($1 >= $2) ? 0 : 1}'; then
    OVERALL_STATUS="✅"
else
    OVERALL_STATUS="❌"
    FAILED=1
fi

echo "├─────────────────────────────────────────────────────────┤"
printf "│  %-28s │  %5s%%   │  ≥%d%%     │ %s\n" \
    "OVERALL" "$OVERALL_PCT" "$THRESHOLD_OVERALL" "$OVERALL_STATUS"
echo "└─────────────────────────────────────────────────────────┘"
echo ""

# ── 明细 ──
echo "File detail (top 20 lowest coverage):"
jq -r '
    to_entries
    | map(select(.key != "total"))
    | sort_by(.value.lines.pct)
    | .[:20]
    | .[]
    | "  \(.key | split("/") | .[-2:] | join("/"))  \(.value.lines.pct)%  (\(.value.lines.covered)/\(.value.lines.total) lines)"
' "$COVERAGE_JSON"
echo ""

# ── 结果 ──
if [ "$FAILED" -eq 1 ]; then
    echo -e "${RED}❌ COVERAGE CHECK FAILED — one or more modules below threshold${NC}"
    exit 1
else
    echo -e "${GREEN}✅ All coverage thresholds passed${NC}"
    exit 0
fi
