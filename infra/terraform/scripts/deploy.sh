#!/usr/bin/env bash
# =============================================================================
# deploy.sh — 供应链风险管理平台 Terraform 部署脚本
#
# 用法：
#   ./scripts/deploy.sh <环境> <操作>
#
#   环境: dev | test | staging | prod
#   操作: init | plan | apply | destroy | output | validate
#
# 示例：
#   ./scripts/deploy.sh dev init
#   ./scripts/deploy.sh dev plan
#   ./scripts/deploy.sh dev apply
#   ./scripts/deploy.sh prod plan -var="api_image=registry.../scrm-api:abc123-20260320"
#   ./scripts/deploy.sh staging output
#
# 敏感变量注入（必须在执行前 export）：
#   export TF_VAR_db_password="your-password"
#   export TF_VAR_redis_password="your-redis-password"
#   export TF_VAR_minio_root_password="your-minio-password"
#   export TF_VAR_jwt_secret="your-256bit-secret"
#   export TF_VAR_xxljob_admin_password="your-xxljob-password"
#   export TF_VAR_xxljob_db_password="your-db-password"
#
# 注意事项（CLAUDE.md 8.2 发布流程）：
#   1. prod apply 前必须先在 staging 验证
#   2. prod apply 需要额外确认（脚本提示）
#   3. destroy 操作会二次确认，生产环境禁止使用
# =============================================================================

set -euo pipefail

# ── 颜色输出 ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

log_info()    { echo -e "${GREEN}[INFO]${NC}  $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC}  $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_step()    { echo -e "\n${BLUE}${BOLD}▶ $*${NC}"; }
log_success() { echo -e "${GREEN}${BOLD}✓ $*${NC}"; }

# ── 脚本根目录 ────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# ── 参数解析 ──────────────────────────────────────────────────────────────────
ENV="${1:-}"
ACTION="${2:-}"
EXTRA_ARGS="${@:3}"  # 额外传递给 terraform 的参数（如 -var="xxx=yyy"）

if [[ -z "$ENV" || -z "$ACTION" ]]; then
  echo -e "${BOLD}用法：${NC}"
  echo "  $0 <环境> <操作> [额外参数]"
  echo ""
  echo -e "${BOLD}环境：${NC}"
  echo "  dev | test | staging | prod"
  echo ""
  echo -e "${BOLD}操作：${NC}"
  echo "  init      初始化 Terraform（首次执行或 provider 变更后）"
  echo "  plan      预览变更（不执行）"
  echo "  apply     执行变更"
  echo "  destroy   销毁资源（⚠️ 谨慎使用，生产禁止）"
  echo "  output    显示输出值"
  echo "  validate  验证配置语法"
  echo "  fmt       格式化代码"
  echo ""
  echo -e "${BOLD}示例：${NC}"
  echo "  $0 dev init"
  echo "  $0 dev apply"
  echo "  $0 prod plan -var=\"api_image=registry.../scrm-api:abc123-20260320\""
  exit 1
fi

# 验证环境参数
VALID_ENVS=("dev" "test" "staging" "prod")
if [[ ! " ${VALID_ENVS[@]} " =~ " ${ENV} " ]]; then
  log_error "无效环境：${ENV}。有效值：dev | test | staging | prod"
  exit 1
fi

# 环境目录
ENV_DIR="$TERRAFORM_ROOT/environments/$ENV"
if [[ ! -d "$ENV_DIR" ]]; then
  log_error "环境目录不存在：$ENV_DIR"
  exit 1
fi

# ── 前置检查 ──────────────────────────────────────────────────────────────────
check_prerequisites() {
  log_step "检查前置依赖..."

  # 检查 Terraform
  if ! command -v terraform &>/dev/null; then
    log_error "未找到 terraform 命令。请先安装 Terraform >= 1.6.0"
    log_info  "安装参考：https://developer.hashicorp.com/terraform/downloads"
    exit 1
  fi

  local tf_version
  tf_version=$(terraform version -json | python3 -c "import sys,json; print(json.load(sys.stdin)['terraform_version'])" 2>/dev/null || terraform version | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  log_info "Terraform 版本：$tf_version"

  # 检查 Docker
  if ! command -v docker &>/dev/null; then
    log_error "未找到 docker 命令。请先安装 Docker。"
    exit 1
  fi

  if ! docker info &>/dev/null; then
    log_error "Docker Daemon 未运行，请先启动 Docker。"
    exit 1
  fi

  log_info "Docker 版本：$(docker version --format '{{.Client.Version}}')"
  log_success "前置检查通过"
}

# ── 检查敏感变量是否已注入 ────────────────────────────────────────────────────
check_sensitive_vars() {
  log_step "检查敏感变量..."

  local REQUIRED_VARS=(
    "TF_VAR_db_password"
    "TF_VAR_redis_password"
    "TF_VAR_minio_root_password"
    "TF_VAR_jwt_secret"
    "TF_VAR_xxljob_admin_password"
    "TF_VAR_xxljob_db_password"
  )

  local MISSING=()
  for var in "${REQUIRED_VARS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      MISSING+=("$var")
    fi
  done

  if [[ ${#MISSING[@]} -gt 0 ]]; then
    log_error "以下敏感变量未注入（禁止写入 terraform.tfvars）："
    for var in "${MISSING[@]}"; do
      echo -e "  ${RED}✗${NC} $var"
    done
    echo ""
    log_info "注入方式（复制并填写真实值）："
    for var in "${MISSING[@]}"; do
      echo "  export ${var}=\"REPLACE_ME\""
    done
    exit 1
  fi

  # 验证 JWT Secret 长度（至少 32 字符 = 256 bit）
  if [[ "${#TF_VAR_jwt_secret}" -lt 32 ]]; then
    log_error "TF_VAR_jwt_secret 长度不足（当前：${#TF_VAR_jwt_secret} 字符，要求：≥ 32 字符）"
    exit 1
  fi

  log_success "所有敏感变量已注入"
}

# ── 生产环境额外保护 ──────────────────────────────────────────────────────────
prod_safety_check() {
  if [[ "$ENV" == "prod" && "$ACTION" == "apply" ]]; then
    echo ""
    echo -e "${RED}${BOLD}⚠️  生产环境变更确认  ⚠️${NC}"
    echo -e "${YELLOW}你即将对【生产环境】执行 terraform apply！${NC}"
    echo ""
    echo "请确认以下事项（CLAUDE.md 8.2 发布流程）："
    echo "  1. 已在 staging 环境验证通过"
    echo "  2. 已通过 Tech Lead Code Review"
    echo "  3. 已在 GitLab 创建发布 Issue"
    echo "  4. 当前在维护窗口内（非业务高峰期）"
    echo ""
    read -r -p "输入 'yes-deploy-prod' 确认执行，其他输入取消：" CONFIRM
    if [[ "$CONFIRM" != "yes-deploy-prod" ]]; then
      log_warn "已取消生产部署"
      exit 0
    fi
  fi

  if [[ "$ACTION" == "destroy" ]]; then
    if [[ "$ENV" == "prod" ]]; then
      log_error "生产环境禁止执行 destroy！如需销毁请联系 Tech Lead。"
      exit 1
    fi
    echo ""
    echo -e "${RED}${BOLD}⚠️  即将销毁 ${ENV} 环境所有资源！${NC}"
    read -r -p "输入 '${ENV}-destroy-confirm' 确认：" CONFIRM
    if [[ "$CONFIRM" != "${ENV}-destroy-confirm" ]]; then
      log_warn "已取消 destroy"
      exit 0
    fi
  fi
}

# ── 创建宿主机日志目录（首次部署时）─────────────────────────────────────────
create_host_dirs() {
  local LOG_BASE="/var/log/scrm/$ENV"
  local TMP_BASE="/data/scrm/$ENV/tmp"

  local DIRS=(
    "$LOG_BASE/postgres-primary"
    "$LOG_BASE/postgres-replica"
    "$LOG_BASE/redis"
    "$LOG_BASE/minio"
    "$LOG_BASE/kafka"
    "$LOG_BASE/xxljob"
    "$LOG_BASE/nginx"
    "$LOG_BASE/api-0"
    "$LOG_BASE/api-1"
    "$LOG_BASE/frontend"
    "$TMP_BASE/api-0"
    "$TMP_BASE/api-1"
  )

  log_step "创建宿主机目录..."
  for dir in "${DIRS[@]}"; do
    if [[ ! -d "$dir" ]]; then
      mkdir -p "$dir" && log_info "创建：$dir"
    fi
  done
  log_success "目录准备完成"
}

# ── 主执行函数 ────────────────────────────────────────────────────────────────
main() {
  echo -e "${CYAN}${BOLD}"
  echo "╔══════════════════════════════════════════════════════════╗"
  echo "║         供应链风险管理平台 — Terraform 部署工具          ║"
  echo "╚══════════════════════════════════════════════════════════╝"
  echo -e "${NC}"
  echo -e "  环境：${BOLD}${ENV}${NC}"
  echo -e "  操作：${BOLD}${ACTION}${NC}"
  echo -e "  目录：${ENV_DIR}"
  echo ""

  check_prerequisites

  # init/validate/fmt 不需要检查敏感变量
  if [[ "$ACTION" != "init" && "$ACTION" != "validate" && "$ACTION" != "fmt" && "$ACTION" != "output" ]]; then
    check_sensitive_vars
  fi

  prod_safety_check

  cd "$ENV_DIR"

  case "$ACTION" in
    init)
      log_step "terraform init — 初始化 Provider 和后端..."
      # -upgrade 确保使用最新兼容版本的 provider
      terraform init -upgrade $EXTRA_ARGS
      log_success "初始化完成"
      echo ""
      log_info "下一步：$0 $ENV validate"
      ;;

    validate)
      log_step "terraform validate — 验证配置语法..."
      terraform validate $EXTRA_ARGS
      log_success "配置语法验证通过"
      ;;

    fmt)
      log_step "terraform fmt — 格式化代码..."
      terraform fmt -recursive "$TERRAFORM_ROOT"
      log_success "格式化完成"
      ;;

    plan)
      log_step "terraform plan — 预览变更..."
      create_host_dirs
      # 将 plan 结果保存到文件，apply 时可直接使用（防止 plan 和 apply 之间状态变化）
      terraform plan \
        -out="tfplan-${ENV}-$(date +%Y%m%d%H%M%S)" \
        $EXTRA_ARGS
      log_success "Plan 完成。请仔细审查以上变更内容后再 apply。"
      ;;

    apply)
      log_step "terraform apply — 执行变更..."
      create_host_dirs

      # 检查是否有已保存的 plan 文件
      LATEST_PLAN=$(ls -t tfplan-${ENV}-* 2>/dev/null | head -1 || true)
      if [[ -n "$LATEST_PLAN" ]]; then
        log_info "发现已保存的 Plan 文件：$LATEST_PLAN"
        read -r -p "使用此 Plan 执行（y）还是重新 plan（n）？[y/n]: " USE_PLAN
        if [[ "$USE_PLAN" == "y" || "$USE_PLAN" == "Y" ]]; then
          terraform apply "$LATEST_PLAN"
          rm -f "$LATEST_PLAN"  # 使用后删除 plan 文件
          log_success "Apply 完成（使用已保存 Plan）"
          return
        fi
      fi

      # 直接 apply（适合 CI/CD 自动化场景）
      terraform apply \
        -auto-approve \
        $EXTRA_ARGS
      log_success "Apply 完成"

      echo ""
      log_step "输出服务端点..."
      terraform output
      ;;

    destroy)
      log_step "terraform destroy — 销毁资源..."
      terraform destroy \
        -auto-approve \
        $EXTRA_ARGS
      log_success "Destroy 完成"
      ;;

    output)
      log_step "terraform output — 显示输出值..."
      terraform output $EXTRA_ARGS
      ;;

    *)
      log_error "未知操作：$ACTION"
      echo "有效操作：init | plan | apply | destroy | output | validate | fmt"
      exit 1
      ;;
  esac
}

# ── 执行 ──────────────────────────────────────────────────────────────────────
main
