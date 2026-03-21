#!/usr/bin/env bash
# =============================================================================
# scripts/ci/notify.sh — CI/CD 告警通知脚本
#
# 用法：
#   bash notify.sh <status> <title> <body> [wxbot_webhook] [email]
#
# 参数：
#   status          : success | failure | warning | info
#   title           : 消息标题（显示在卡片顶部，建议 ≤ 30 字符）
#   body            : 消息正文（支持 Markdown，\n 转换为换行）
#   wxbot_webhook   : 企业微信机器人 Webhook URL（可选，不传则跳过）
#   email           : 收件人邮件地址（多个用逗号分隔，可选）
#
# 环境变量（优先级高于参数）：
#   WXBOT_WEBHOOK       企业微信机器人 Webhook URL
#   NOTIFY_EMAIL        收件人邮件地址
#   SMTP_HOST           SMTP 服务器地址（默认 localhost）
#   SMTP_PORT           SMTP 端口（默认 25）
#   SMTP_USER           SMTP 用户名（可选）
#   SMTP_PASS           SMTP 密码（可选，敏感信息通过 CI 变量注入）
#   SMTP_FROM           发件人地址（默认 scrm-ci@company.com）
#   CI_PIPELINE_URL     CI 流水线链接（自动追加到消息尾部）
#   CI_COMMIT_SHA       当前提交 SHA（自动追加）
#   CI_COMMIT_REF_NAME  当前分支/Tag
#   CI_PROJECT_NAME     项目名称
#   GITHUB_SERVER_URL   GitHub Actions 环境变量
#   GITHUB_RUN_ID       GitHub Actions Run ID
#   GITHUB_REPOSITORY   GitHub 仓库名
#
# 退出码：
#   0 — 至少一个渠道通知成功
#   1 — 所有通知渠道均失败（不会阻断 CI 流水线，调用方应使用 || true）
# =============================================================================

set -uo pipefail   # 注意：不加 -e，通知失败不阻断流水线

# ── 参数解析 ──────────────────────────────────────────────────────────────────
STATUS="${1:-info}"
TITLE="${2:-SCRM CI/CD 通知}"
BODY="${3:-}"
WXBOT_WEBHOOK="${WXBOT_WEBHOOK:-${4:-}}"
NOTIFY_EMAIL="${NOTIFY_EMAIL:-${5:-}}"

# ── 环境变量回退 ───────────────────────────────────────────────────────────────
SMTP_HOST="${SMTP_HOST:-localhost}"
SMTP_PORT="${SMTP_PORT:-25}"
SMTP_USER="${SMTP_USER:-}"
SMTP_PASS="${SMTP_PASS:-}"
SMTP_FROM="${SMTP_FROM:-scrm-ci@company.com}"

# ── 构建 CI 上下文链接 ─────────────────────────────────────────────────────────
build_ci_context() {
  local CONTEXT=""

  # GitLab CI 环境
  if [[ -n "${CI_PIPELINE_URL:-}" ]]; then
    CONTEXT+="流水线: ${CI_PIPELINE_URL}\n"
  fi
  if [[ -n "${CI_COMMIT_SHA:-}" ]]; then
    CONTEXT+="Commit: ${CI_COMMIT_SHA:0:8}"
    [[ -n "${CI_COMMIT_REF_NAME:-}" ]] && CONTEXT+=" (${CI_COMMIT_REF_NAME})"
    CONTEXT+="\n"
  fi
  if [[ -n "${CI_PROJECT_NAME:-}" ]]; then
    CONTEXT+="项目: ${CI_PROJECT_NAME}\n"
  fi

  # GitHub Actions 环境
  if [[ -n "${GITHUB_RUN_ID:-}" && -n "${GITHUB_REPOSITORY:-}" ]]; then
    CONTEXT+="流水线: ${GITHUB_SERVER_URL:-https://github.com}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}\n"
  fi
  if [[ -n "${GITHUB_SHA:-}" ]]; then
    CONTEXT+="Commit: ${GITHUB_SHA:0:8}"
    [[ -n "${GITHUB_REF_NAME:-}" ]] && CONTEXT+=" (${GITHUB_REF_NAME})"
    CONTEXT+="\n"
  fi

  echo "$CONTEXT"
}

# ── 状态映射 ───────────────────────────────────────────────────────────────────
get_status_emoji() {
  case "$1" in
    success) echo "✅" ;;
    failure) echo "❌" ;;
    warning) echo "⚠️" ;;
    info)    echo "ℹ️" ;;
    *)       echo "📢" ;;
  esac
}

get_wxbot_color() {
  case "$1" in
    success) echo "green" ;;
    failure) echo "red" ;;
    warning) echo "orange" ;;
    *)       echo "blue" ;;
  esac
}

# =============================================================================
# 企业微信机器人通知
# 文档：https://developer.work.weixin.qq.com/document/path/91770
# =============================================================================
send_wxbot() {
  local WEBHOOK="$1"
  local TITLE="$2"
  local BODY="$3"

  if [[ -z "$WEBHOOK" ]]; then
    echo "[notify] 企业微信 Webhook 未配置，跳过"
    return 0
  fi

  local EMOJI
  EMOJI=$(get_status_emoji "$STATUS")
  local CI_CONTEXT
  CI_CONTEXT=$(build_ci_context)

  # 将 \n 转换为实际换行，构建完整 Markdown 消息体
  local FULL_BODY
  FULL_BODY=$(printf "%s" "$BODY" | sed 's/\\n/\n/g')
  [[ -n "$CI_CONTEXT" ]] && FULL_BODY+=$(printf "\n\n---\n%s" "$(printf "%s" "$CI_CONTEXT" | sed 's/\\n/\n/g')")

  # 构建 Markdown 类型消息（支持加粗、颜色标注）
  # 注意：企业微信 Markdown 颜色语法为 <font color="red">文字</font>
  local MD_CONTENT
  MD_CONTENT="${EMOJI} **${TITLE}**\n\n${FULL_BODY}"

  # JSON payload（使用 printf 避免特殊字符问题）
  local PAYLOAD
  PAYLOAD=$(printf '{"msgtype":"markdown","markdown":{"content":"%s"}}' \
    "$(printf '%s' "$MD_CONTENT" | python3 -c "
import sys, json
content = sys.stdin.read()
print(json.dumps(content)[1:-1])  # strip outer quotes
" 2>/dev/null || printf '%s' "$MD_CONTENT" | sed 's/"/\\"/g; s/\n/\\n/g')")

  local HTTP_CODE
  HTTP_CODE=$(curl -s -o /tmp/wxbot_response.json -w "%{http_code}" \
    --connect-timeout 10 \
    --max-time 30 \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$WEBHOOK" 2>/dev/null || echo "000")

  if [[ "$HTTP_CODE" == "200" ]]; then
    local ERRCODE
    ERRCODE=$(cat /tmp/wxbot_response.json 2>/dev/null | grep -o '"errcode":[0-9]*' | cut -d: -f2 || echo "0")
    if [[ "$ERRCODE" == "0" ]]; then
      echo "[notify] ✓ 企业微信通知发送成功"
      return 0
    else
      local ERRMSG
      ERRMSG=$(cat /tmp/wxbot_response.json 2>/dev/null | grep -o '"errmsg":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
      echo "[notify] ✗ 企业微信 API 错误: errcode=${ERRCODE}, errmsg=${ERRMSG}" >&2
      return 1
    fi
  else
    echo "[notify] ✗ 企业微信 HTTP 请求失败: status=${HTTP_CODE}" >&2
    return 1
  fi
}

# =============================================================================
# 邮件通知（通过 curl + SMTP 或 sendmail）
# =============================================================================
send_email() {
  local TO="$1"
  local SUBJECT="$2"
  local BODY_TEXT="$3"

  if [[ -z "$TO" ]]; then
    echo "[notify] 收件人邮箱未配置，跳过邮件通知"
    return 0
  fi

  local EMOJI
  EMOJI=$(get_status_emoji "$STATUS")
  local CI_CONTEXT
  CI_CONTEXT=$(build_ci_context)

  # 构建 HTML 邮件正文
  local STATUS_COLOR
  case "$STATUS" in
    success) STATUS_COLOR="#28a745" ;;
    failure) STATUS_COLOR="#dc3545" ;;
    warning) STATUS_COLOR="#ffc107" ;;
    *)       STATUS_COLOR="#17a2b8" ;;
  esac

  local BODY_HTML
  BODY_HTML=$(cat <<HTML
<!DOCTYPE html>
<html>
<head><meta charset="utf-8"></head>
<body style="font-family: -apple-system, sans-serif; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="border-left: 4px solid ${STATUS_COLOR}; padding: 12px 20px; background: #f8f9fa;">
    <h2 style="margin: 0 0 8px; color: ${STATUS_COLOR};">${EMOJI} ${SUBJECT}</h2>
  </div>
  <div style="padding: 20px 0; line-height: 1.6; white-space: pre-wrap;">
$(printf '%s' "$BODY_TEXT" | sed 's/\\n/\n/g' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
  </div>
$(if [[ -n "$CI_CONTEXT" ]]; then
  echo "<hr style='border: none; border-top: 1px solid #dee2e6;'>"
  echo "<div style='font-size: 12px; color: #6c757d; padding: 8px 0;'>"
  printf '%s' "$CI_CONTEXT" | sed 's/\\n/\n/g' | while IFS= read -r line; do
    [[ -n "$line" ]] && echo "<div>${line}</div>"
  done
  echo "</div>"
fi)
  <hr style="border: none; border-top: 1px solid #dee2e6;">
  <div style="font-size: 11px; color: #adb5bd;">此邮件由 SCRM CI/CD 系统自动发送，请勿直接回复。</div>
</body>
</html>
HTML
)

  # 方法 1：通过 curl SMTP（推荐，适合 CI 环境）
  if [[ -n "$SMTP_HOST" && "$SMTP_HOST" != "localhost" ]]; then
    local BOUNDARY="SCRM_CI_$(date +%s)"
    local MAIL_HEADERS
    MAIL_HEADERS="From: SCRM CI/CD <${SMTP_FROM}>
To: ${TO}
Subject: ${EMOJI} ${SUBJECT}
MIME-Version: 1.0
Content-Type: multipart/alternative; boundary=\"${BOUNDARY}\"
Date: $(date -u '+%a, %d %b %Y %H:%M:%S +0000')"

    local MAIL_BODY
    MAIL_BODY="${MAIL_HEADERS}

--${BOUNDARY}
Content-Type: text/plain; charset=utf-8

$(printf '%s' "$BODY_TEXT" | sed 's/\\n/\n/g')

$(printf '%s' "$CI_CONTEXT" | sed 's/\\n/\n/g')

--${BOUNDARY}
Content-Type: text/html; charset=utf-8

${BODY_HTML}
--${BOUNDARY}--"

    local CURL_ARGS=(
      curl -s
      --connect-timeout 15
      --max-time 30
      "smtp://${SMTP_HOST}:${SMTP_PORT}"
      --mail-from "$SMTP_FROM"
    )

    # 多收件人支持
    IFS=',' read -ra RECIPIENTS <<< "$TO"
    for RECIPIENT in "${RECIPIENTS[@]}"; do
      RECIPIENT=$(echo "$RECIPIENT" | tr -d ' ')
      CURL_ARGS+=(--mail-rcpt "$RECIPIENT")
    done

    [[ -n "$SMTP_USER" ]] && CURL_ARGS+=(--user "${SMTP_USER}:${SMTP_PASS}")
    # TLS 支持（587 端口使用 STARTTLS）
    [[ "$SMTP_PORT" == "587" ]] && CURL_ARGS+=(--ssl-reqd)
    [[ "$SMTP_PORT" == "465" ]] && CURL_ARGS+=(--ssl)

    if printf '%s' "$MAIL_BODY" | "${CURL_ARGS[@]}" --upload-file - 2>/dev/null; then
      echo "[notify] ✓ 邮件通知发送成功（SMTP: ${SMTP_HOST}:${SMTP_PORT}）"
      return 0
    else
      echo "[notify] ✗ 邮件发送失败（SMTP: ${SMTP_HOST}:${SMTP_PORT}）" >&2
    fi
  fi

  # 方法 2：回退到 sendmail（如果可用）
  if command -v sendmail &>/dev/null; then
    local SIMPLE_MAIL
    SIMPLE_MAIL="To: ${TO}
From: ${SMTP_FROM}
Subject: ${EMOJI} ${SUBJECT}
Content-Type: text/plain; charset=utf-8

$(printf '%s' "$BODY_TEXT" | sed 's/\\n/\n/g')

$(printf '%s' "$CI_CONTEXT" | sed 's/\\n/\n/g')"

    if printf '%s' "$SIMPLE_MAIL" | sendmail -t 2>/dev/null; then
      echo "[notify] ✓ 邮件通知发送成功（sendmail）"
      return 0
    fi
  fi

  echo "[notify] ✗ 邮件发送失败（SMTP 未配置，sendmail 不可用）" >&2
  return 1
}

# =============================================================================
# 主逻辑
# =============================================================================
main() {
  local SEND_OK=false
  local EMOJI
  EMOJI=$(get_status_emoji "$STATUS")

  echo "[notify] 发送 ${STATUS} 通知: ${TITLE}"

  # 发送企业微信通知
  if send_wxbot "$WXBOT_WEBHOOK" "$TITLE" "$BODY"; then
    SEND_OK=true
  fi

  # 发送邮件通知
  if send_email "$NOTIFY_EMAIL" "$TITLE" "$BODY"; then
    SEND_OK=true
  fi

  if $SEND_OK; then
    return 0
  else
    echo "[notify] 警告：所有通知渠道均失败" >&2
    return 1
  fi
}

main
