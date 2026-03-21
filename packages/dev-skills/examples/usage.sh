#!/usr/bin/env bash
# @scrm/dev-skills Shell 调用示例
# 通过 Node.js 一行脚本调用 SDK 函数

set -euo pipefail

# ---- 前置条件 ----
# 1. 已安装 @scrm/dev-skills：pnpm add @scrm/dev-skills
# 2. 已配置 .env.local（参考 .env.example）

# ---- 日志查询 ----
echo "=== 日志查询 ==="
node --input-type=module -e "
import { loadConfig, queryLog } from '@scrm/dev-skills';
const config = loadConfig();
const result = await queryLog({
  startTime: '2026-03-20T00:00:00Z',
  endTime: '2026-03-20T23:59:59Z',
  level: 'ERROR',
}, config);
console.log(JSON.stringify(result, null, 2));
"

# ---- 数据库查询 ----
echo "=== PostgreSQL 查询 ==="
node --input-type=module -e "
import { loadConfig, queryDb } from '@scrm/dev-skills';
const config = loadConfig();
const result = await queryDb({
  sql: 'SELECT id, name FROM supplier LIMIT 5',
  dbType: 'pg',
}, config);
console.log(JSON.stringify(result, null, 2));
"

# ---- 获取 Token ----
echo "=== Token 获取 ==="
node --input-type=module -e "
import { loadConfig, getToken } from '@scrm/dev-skills';
const config = loadConfig();
const result = await getToken('RISK_ANALYST', config);
if (result.success) {
  echo \"Access Token: \${result.data.accessToken}\"
}
console.log(JSON.stringify(result, null, 2));
"

# ---- 服务重启 ----
echo "=== 服务重启 ==="
node --input-type=module -e "
import { loadConfig, restartService } from '@scrm/dev-skills';
const config = loadConfig();
const result = await restartService({ serviceName: 'scrm-api', env: 'dev' }, config);
console.log(JSON.stringify(result, null, 2));
"

# ---- 批量评分 ----
echo "=== 触发评分任务 ==="
node --input-type=module -e "
import { loadConfig, triggerScoreJob } from '@scrm/dev-skills';
const config = loadConfig();
const result = await triggerScoreJob({ batchSize: 500, startId: 1, endId: 10000 }, config);
console.log(JSON.stringify(result, null, 2));
"
