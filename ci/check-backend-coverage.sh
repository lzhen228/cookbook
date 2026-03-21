#!/usr/bin/env bash
# ============================================================================
# 后端覆盖率校验脚本
# ============================================================================
#
# 功能：解析 JaCoCo XML 报告，按包（模块）维度校验行覆盖率。
#
# 核心模块覆盖率阈值（对齐 CLAUDE.md 7.1 节）：
#   - service 层：  ≥ 80%（核心业务逻辑）
#   - controller 层：≥ 70%（接口层）
#   - common 层：   ≥ 70%（工具/异常/响应）
#   - 项目整体：    ≥ 70%
#
# 依赖：
#   - bash 4+
#   - awk / grep / bc（ubuntu-latest / alpine 默认可用）
#   OR
#   - Python 3（作为 fallback 解析 XML）
#
# 用法：
#   bash ci/check-backend-coverage.sh
#
# 退出码：
#   0 — 全部达标
#   1 — 存在不达标模块
# ============================================================================

set -euo pipefail

JACOCO_XML="services/api/target/site/jacoco/jacoco.xml"
THRESHOLD_SERVICE=80
THRESHOLD_CONTROLLER=70
THRESHOLD_COMMON=70
THRESHOLD_OVERALL=70

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "============================================"
echo "  Backend Coverage Check (JaCoCo)"
echo "============================================"
echo ""

# ─────────────────────────────────────────────
# 检查报告文件是否存在
# ─────────────────────────────────────────────
if [ ! -f "$JACOCO_XML" ]; then
    echo -e "${YELLOW}[WARN] JaCoCo XML report not found: $JACOCO_XML${NC}"
    echo ""
    echo "Attempting to find report in alternate locations..."

    # 尝试其他常见路径
    ALT_PATHS=(
        "services/api/target/site/jacoco/jacoco.xml"
        "target/site/jacoco/jacoco.xml"
    )
    FOUND=false
    for p in "${ALT_PATHS[@]}"; do
        if [ -f "$p" ]; then
            JACOCO_XML="$p"
            FOUND=true
            echo "Found report at: $p"
            break
        fi
    done

    if [ "$FOUND" = false ]; then
        echo -e "${RED}[ERROR] No JaCoCo report found. Run 'mvnw test' first.${NC}"
        echo ""
        echo "Expected location: services/api/target/site/jacoco/jacoco.xml"
        echo "The JaCoCo Maven plugin generates this during the 'test' phase."
        exit 1
    fi
fi

echo "Report: $JACOCO_XML"
echo ""

# ─────────────────────────────────────────────
# 用 Python 解析 XML（比 awk 解析 XML 更可靠）
# ─────────────────────────────────────────────
FAILED=0

python3 - "$JACOCO_XML" "$THRESHOLD_SERVICE" "$THRESHOLD_CONTROLLER" "$THRESHOLD_COMMON" "$THRESHOLD_OVERALL" <<'PYTHON_SCRIPT'
import sys
import xml.etree.ElementTree as ET

xml_path = sys.argv[1]
t_service = int(sys.argv[2])
t_controller = int(sys.argv[3])
t_common = int(sys.argv[4])
t_overall = int(sys.argv[5])

tree = ET.parse(xml_path)
root = tree.getroot()

# ── 收集包级覆盖率 ──
package_coverage = {}
total_missed = 0
total_covered = 0

for pkg in root.findall('.//package'):
    pkg_name = pkg.get('name', '')
    for counter in pkg.findall('counter'):
        if counter.get('type') == 'LINE':
            missed = int(counter.get('missed', 0))
            covered = int(counter.get('covered', 0))
            total = missed + covered
            pct = round(covered / total * 100, 1) if total > 0 else 0
            package_coverage[pkg_name] = {
                'missed': missed,
                'covered': covered,
                'total': total,
                'pct': pct,
            }
            total_missed += missed
            total_covered += covered

overall_total = total_missed + total_covered
overall_pct = round(total_covered / overall_total * 100, 1) if overall_total > 0 else 0

# ── 模块 → 阈值映射 ──
# 按包路径前缀匹配核心模块
module_rules = [
    ('service', 'com/supply/risk/service', t_service),
    ('controller', 'com/supply/risk/controller', t_controller),
    ('common', 'com/supply/risk/common', t_common),
]

print("┌─────────────────────────────────────────────────────────┐")
print("│  Package                      │  Coverage  │  Threshold │")
print("├─────────────────────────────────────────────────────────┤")

failed = False

for module_name, prefix, threshold in module_rules:
    # 聚合该模块下所有包
    mod_missed = 0
    mod_covered = 0
    for pkg_name, data in package_coverage.items():
        if pkg_name.startswith(prefix):
            mod_missed += data['missed']
            mod_covered += data['covered']

    mod_total = mod_missed + mod_covered
    mod_pct = round(mod_covered / mod_total * 100, 1) if mod_total > 0 else 0

    status = "✅" if mod_pct >= threshold else "❌"
    if mod_pct < threshold:
        failed = True

    name_padded = f"{module_name} ({prefix})".ljust(30)
    print(f"│  {name_padded}│  {mod_pct:>5.1f}%   │  ≥{threshold}%     │ {status}")

# 整体
status_all = "✅" if overall_pct >= t_overall else "❌"
if overall_pct < t_overall:
    failed = True

print("├─────────────────────────────────────────────────────────┤")
print(f"│  {'OVERALL'.ljust(30)}│  {overall_pct:>5.1f}%   │  ≥{t_overall}%     │ {status_all}")
print("└─────────────────────────────────────────────────────────┘")
print()

# ── 各包明细 ──
print("Package detail:")
for pkg_name in sorted(package_coverage.keys()):
    data = package_coverage[pkg_name]
    print(f"  {pkg_name.ljust(50)} {data['pct']:>5.1f}%  ({data['covered']}/{data['total']} lines)")
print()

if failed:
    print("❌ COVERAGE CHECK FAILED — one or more modules below threshold")
    sys.exit(1)
else:
    print("✅ All coverage thresholds passed")
    sys.exit(0)
PYTHON_SCRIPT

exit $?
