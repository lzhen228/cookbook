# 供应链风险管理平台（SCRM）—— 生产运维 Runbook

> **版本：** v1.0
> **更新日期：** 2026-03-21
> **维护人：** 技术团队 / SRE
> **适用环境：** Dev / Staging / Production
> **机密级别：** 内部使用

---

## 目录

1. [环境信息总览](#1-环境信息总览)
2. [部署流程](#2-部署流程)
3. [常用运维操作](#3-常用运维操作)
4. [故障排查手册](#4-故障排查手册)
5. [应急方案](#5-应急方案)
6. [监控与告警配置](#6-监控与告警配置)
7. [值班规范](#7-值班规范)

---

## 1. 环境信息总览

### 1.1 服务架构一览

```
Internet
    │
  Nginx (80/443)          # 反向代理 + 限流 + SSL 终止
    ├── /                 → Frontend (React SPA, port 3000)
    └── /api/v1           → Backend API (Spring Boot, port 8080)
                              │
                 ┌────────────┼────────────┐
            PostgreSQL     Redis 7      Kafka 3.6
            port 5432      port 6379    port 9092
            (+ TimescaleDB)              │
                              MinIO (port 9000/9001)
```

### 1.2 各环境连接信息

| 参数 | Dev (本地) | Staging | Production |
|------|------------|---------|------------|
| API Base URL | `http://localhost:8080/api/v1` | `https://scrm-staging.company.com/api/v1` | `https://scrm.company.com/api/v1` |
| PostgreSQL Host | `localhost:5432` | `pg-staging.internal:5432` | `pg-prod.internal:5432` |
| PostgreSQL DB | `scrm` | `scrm_staging` | `scrm_prod` |
| PostgreSQL User | `scrm_user` | `scrm_staging` | `scrm_prod` |
| Redis Host | `localhost:6379` | `redis-staging.internal:6379` | `redis-prod.internal:6379` |
| Kafka Brokers | `localhost:9092` | `kafka-staging.internal:9092` | `kafka-prod.internal:9092` |
| MinIO Endpoint | `http://localhost:9000` | `https://minio-staging.internal` | `https://minio-prod.internal` |
| Frontend URL | `http://localhost:3000` | `https://scrm-staging.company.com` | `https://scrm.company.com` |

> **注意：** 生产环境密码从 Vault 注入，禁止在本文件中明文记录。

### 1.3 服务端口与健康检查

| 服务 | 容器名 | 端口 | 健康检查端点 |
|------|--------|------|-------------|
| 后端 API | `scrm-api` | 8080 | `GET /api/v1/actuator/health/liveness` |
| 后端就绪 | `scrm-api` | 8080 | `GET /api/v1/actuator/health/readiness` |
| 前端 Nginx | `scrm-frontend` | 80/443 | `curl -f http://localhost/` |
| PostgreSQL | `scrm-postgres` | 5432 | `pg_isready -U scrm_user -d scrm_prod` |
| Redis | `scrm-redis` | 6379 | `redis-cli -a $REDIS_PASSWORD ping` |
| Kafka | `scrm-kafka` | 9092 | `kafka-topics.sh --list --bootstrap-server localhost:9092` |
| MinIO | `scrm-minio` | 9000 | `curl -f http://localhost:9000/minio/health/live` |

---

## 2. 部署流程

### 2.1 标准发布流程（GitLab CI 自动化）

```
开发在 feature/* 分支开发
        │
        ▼
  MR → develop 分支
        │
  CI 自动执行：
  ① lint (checkstyle + ESLint)    ≈ 2 min
  ② test (单元 + 集成测试)          ≈ 8 min
  ③ build (Maven + pnpm build)    ≈ 5 min
  ④ docker build + Trivy 扫描     ≈ 6 min
  ⑤ push 镜像至 Harbor            ≈ 3 min
        │
  打 Release Tag (v1.x.x)
        │
  CI 自动部署至 Staging
        │
  QA 回归测试（≥ 30 min 浸泡）
        │
  Tech Lead 手动审批 Production 部署
        │
  滚动更新（不停机）
        │
  10 分钟观察期 → 关闭 Issue / 回滚
```

### 2.2 镜像标签规范

```bash
# 格式：{service}:{git-short-sha}-{yyyyMMdd}
scrm-api:a1b2c3d4-20260321
scrm-frontend:a1b2c3d4-20260321

# latest 仅由 CI 在 main 合并后打，人工禁止操作
```

### 2.3 手动部署命令（紧急情况）

```bash
# ① 拉取最新镜像
docker pull harbor.company.com/scrm/scrm-api:${TAG}
docker pull harbor.company.com/scrm/scrm-frontend:${TAG}

# ② 更新并启动（滚动替换）
docker-compose -f docker-compose.prod.yml up -d --no-deps --build api
docker-compose -f docker-compose.prod.yml up -d --no-deps --build frontend

# ③ 验证健康状态（等待最多 90s）
for i in {1..9}; do
  STATUS=$(curl -s http://localhost:8080/api/v1/actuator/health/readiness | jq -r '.status')
  echo "[$(date)] Readiness: $STATUS"
  [ "$STATUS" = "UP" ] && break || sleep 10
done

# ④ 查看启动日志
docker logs --tail 100 -f scrm-api
```

### 2.4 数据库迁移

Flyway 在应用启动时自动执行，**无需手动操作**。以下命令用于紧急情况：

```bash
# 查看当前迁移版本
docker exec scrm-api java -jar flyway-cli.jar \
  -url=jdbc:postgresql://${DB_HOST}:5432/${DB_NAME} \
  -user=${DB_USERNAME} -password=${DB_PASSWORD} info

# 修复失败迁移（仅在明确了解风险后执行）
docker exec scrm-api java -jar flyway-cli.jar ... repair
```

### 2.5 环境变量清单

所有环境变量参见项目根目录 `.env.example`，生产值从 Vault 注入：

```bash
# 关键变量（必须配置，无默认值）
DB_USERNAME, DB_PASSWORD
REDIS_PASSWORD
JWT_SECRET
MINIO_ACCESS_KEY, MINIO_SECRET_KEY
EXT_QICHA_API_KEY

# 可选变量（有合理默认值）
DB_HOST=localhost, DB_PORT=5432, DB_NAME=scrm
REDIS_HOST=localhost, REDIS_PORT=6379
JWT_ACCESS_TOKEN_TTL_SECONDS=7200   # 2小时
JWT_REFRESH_TOKEN_TTL_SECONDS=604800 # 7天
MINIO_BUCKET=scrm-reports
MINIO_PRESIGN_TTL_MINUTES=15
```

---

## 3. 常用运维操作

### 3.1 服务重启

```bash
# 重启后端 API（保留其他服务）
docker-compose -f docker-compose.prod.yml restart api
# 或强制重建
docker-compose -f docker-compose.prod.yml up -d --force-recreate api

# 重启前端
docker-compose -f docker-compose.prod.yml restart frontend

# 重启全部服务（谨慎！）
docker-compose -f docker-compose.prod.yml restart

# 检查重启后健康状态
curl -s http://localhost:8080/api/v1/actuator/health | jq .
```

### 3.2 查看服务日志

```bash
# 实时查看后端日志（JSON 格式，需 jq 美化）
docker logs -f scrm-api | jq '.'

# 按 traceId 追踪单次请求全链路
docker logs scrm-api 2>&1 | grep '"traceId":"abc123"'

# 查看最近 500 行 ERROR 日志
docker logs scrm-api 2>&1 | grep '"level":"ERROR"' | tail -500

# 查看 Kafka 消费日志
docker logs scrm-api 2>&1 | grep "supplier.data.updated"

# 前端 Nginx 访问日志
docker logs scrm-frontend | tail -200

# PostgreSQL 慢查询日志（需提前配置 log_min_duration_statement=500）
docker exec scrm-postgres psql -U scrm_user -d scrm_prod \
  -c "SELECT query, calls, mean_exec_time FROM pg_stat_statements ORDER BY mean_exec_time DESC LIMIT 20;"
```

### 3.3 Redis 缓存操作

```bash
# 进入 Redis CLI
docker exec -it scrm-redis redis-cli -a $REDIS_PASSWORD

# 查看所有供应商 Tab 缓存 Key
KEYS supplier:tab:*

# 查看 Key 剩余 TTL（秒）
TTL supplier:tab:1001:basic-info

# 清除单个供应商所有 Tab 缓存（供应商数据更新后手动触发）
DEL supplier:tab:1001:basic-info
DEL supplier:tab:1001:business-info
DEL supplier:tab:1001:judicial
DEL supplier:tab:1001:credit
DEL supplier:tab:1001:tax

# 批量清除某供应商全部 Tab 缓存（慎用 FLUSHDB！）
redis-cli -a $REDIS_PASSWORD --scan --pattern "supplier:tab:1001:*" | xargs redis-cli -a $REDIS_PASSWORD DEL

# 查看 Redis 内存使用
INFO memory | grep used_memory_human

# 查看当前 Key 总数
DBSIZE

# 查看缓存命中率
INFO stats | grep keyspace
```

### 3.4 MinIO 操作

```bash
# 查看报告存储桶文件数量
mc ls minio/scrm-reports --recursive | wc -l

# 手动为指定报告生成预签名 URL（15分钟有效）
mc share download minio/scrm-reports/supplier/1001/report_20260321.pdf

# 清理 30 天前的旧报告（配合定期维护）
mc rm --recursive --force --older-than 30d minio/scrm-reports/
```

### 3.5 数据库常用查询

```sql
-- 查看当前数据库连接数
SELECT count(*), state FROM pg_stat_activity WHERE datname='scrm_prod' GROUP BY state;

-- 查看活跃慢查询（执行超过 5s）
SELECT pid, now() - pg_stat_activity.query_start AS duration, query, state
FROM pg_stat_activity
WHERE state != 'idle' AND (now() - query_start) > interval '5 seconds'
ORDER BY duration DESC;

-- 终止特定慢查询
SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE pid = <target_pid>;

-- 查看最新评分批次执行情况
SELECT DATE(created_at) AS batch_date, COUNT(*) AS snapshot_count, AVG(health_score) AS avg_score
FROM supplier_health_snapshot
GROUP BY DATE(created_at)
ORDER BY batch_date DESC
LIMIT 7;

-- 查看今日新增高风险供应商
SELECT s.id, s.name, s.unified_code, shs.health_score
FROM supplier s
JOIN supplier_health_snapshot shs ON shs.supplier_id = s.id
WHERE shs.snapshot_date = CURRENT_DATE AND shs.health_level = 'high_risk'
ORDER BY shs.health_score ASC;

-- 查看未通知的风险事项（is_notified=false）
SELECT COUNT(*) FROM risk_event WHERE is_notified = FALSE AND status = 'open';
```

---

## 4. 故障排查手册

### 4.1 接口响应超时（P95 > 800ms）

**症状：** 用户反馈供应商列表页加载缓慢，Nginx 出现 504。

**排查步骤：**

```bash
# Step 1: 确认是否为全量超时还是部分请求
docker logs scrm-api 2>&1 | grep '"level":"WARN"' | grep "slow" | tail -50

# Step 2: 检查 HikariCP 连接池是否满载
curl -s http://localhost:8080/api/v1/actuator/metrics/hikaricp.connections.active | jq .
# 若 active ≈ max(20)，说明连接池耗尽

# Step 3: 检查 PostgreSQL 活跃慢查询
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT pid, now() - query_start AS duration, left(query, 100)
  FROM pg_stat_activity
  WHERE state = 'active' AND (now() - query_start) > interval '1 second'
  ORDER BY duration DESC LIMIT 10;"

# Step 4: 确认索引是否被使用（EXPLAIN ANALYZE）
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  EXPLAIN (ANALYZE, BUFFERS)
  SELECT id, name, health_score_cache FROM supplier
  WHERE cooperation_status = 'cooperating' AND health_level_cache = 'high_risk'
  ORDER BY health_score_cache ASC, id ASC LIMIT 20;"

# Step 5: 检查 Redis 缓存命中率
docker exec scrm-redis redis-cli -a $REDIS_PASSWORD INFO stats | grep "keyspace_hits\|keyspace_misses"
```

**常见原因与处置：**

| 原因 | 处置方式 |
|------|---------|
| 游标分页未走覆盖索引 | 执行 `REINDEX INDEX CONCURRENTLY idx_supplier_list_covering;` |
| HikariCP 连接池满 | 临时增大 `maximum-pool-size` 并重启，同时排查连接泄漏 |
| Redis 缓存失效 Tab 数据全量回源 | 检查 TTL 抖动配置，必要时预热缓存 |
| pg_trgm 模糊搜索未用 GIN 索引 | 确认 pg_trgm 扩展已安装，重建 `idx_supplier_name_trgm` |

---

### 4.2 数据库慢查询

**症状：** `pg_stat_statements` 报告某查询 mean_exec_time > 500ms。

**排查步骤：**

```bash
# Step 1: 找出 Top 10 慢查询
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT
    left(query, 120) AS query_snippet,
    calls,
    round(mean_exec_time::numeric, 1) AS avg_ms,
    round(total_exec_time::numeric / 1000, 1) AS total_sec
  FROM pg_stat_statements
  ORDER BY mean_exec_time DESC
  LIMIT 10;"

# Step 2: 检查表膨胀（dead tuples）
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT relname, n_dead_tup, n_live_tup,
         round(n_dead_tup * 100.0 / NULLIF(n_live_tup + n_dead_tup, 0), 2) AS dead_pct
  FROM pg_stat_user_tables
  ORDER BY n_dead_tup DESC LIMIT 10;"

# Step 3: 若 dead_pct > 20%，触发 VACUUM
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "VACUUM ANALYZE supplier;"
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "VACUUM ANALYZE supplier_health_snapshot;"

# Step 4: 检查索引使用率
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT indexrelname, idx_scan, idx_tup_read
  FROM pg_stat_user_indexes
  WHERE relname = 'supplier'
  ORDER BY idx_scan DESC;"
```

**快速优化操作：**

```sql
-- 重建 GIN 索引（不锁表）
REINDEX INDEX CONCURRENTLY idx_supplier_name_trgm;
REINDEX INDEX CONCURRENTLY idx_supplier_supply_items;

-- 更新统计信息
ANALYZE supplier;
ANALYZE supplier_health_snapshot;

-- snapshot 表按月分区清理（保留最近 90 天）
DELETE FROM supplier_health_snapshot
WHERE snapshot_date < CURRENT_DATE - INTERVAL '90 days';
```

---

### 4.3 Kafka 消费失败

**症状：** `supplier.data.updated` Topic 消息积压，供应商数据未更新触发预警。

**排查步骤：**

```bash
# Step 1: 查看消费组 Lag（消息积压量）
docker exec scrm-kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --describe --group scrm-api

# Step 2: 查看后端 Kafka 消费异常日志
docker logs scrm-api 2>&1 | grep "KafkaConsumer\|supplier.data.updated\|ListenerExecutionFailedException"

# Step 3: 检查死信队列（DLQ）是否有消息
docker exec scrm-kafka kafka-console-consumer.sh \
  --bootstrap-server localhost:9092 \
  --topic supplier.data.updated.DLT \
  --from-beginning --max-messages 10

# Step 4: 检查消费者线程池是否阻塞
curl -s http://localhost:8080/api/v1/actuator/metrics/executor.active | jq .
```

**处置措施：**

```bash
# 方案 A：重置消费 offset（从最新开始，丢弃积压消息，适合非关键数据）
docker exec scrm-kafka kafka-consumer-groups.sh \
  --bootstrap-server localhost:9092 \
  --group scrm-api \
  --topic supplier.data.updated \
  --reset-offsets --to-latest --execute

# 方案 B：从 DLQ 重放消息（适合需要重新处理的场景）
# 1. 将 DLQ 消息 copy 回原 Topic（需自行实现或使用 kafka-streams）

# 方案 C：暂停消费，排查根因后重启消费者
docker-compose -f docker-compose.prod.yml restart api
```

---

### 4.4 批量评分任务异常

**症状：** XXL-Job 控制台显示评分任务执行失败或超过 4 小时未完成。

**排查步骤：**

```bash
# Step 1: 查看评分任务日志
docker logs scrm-api 2>&1 | grep "scoring\|ScoringJob\|scoringExecutor"

# Step 2: 检查线程池队列是否溢出
curl -s http://localhost:8080/api/v1/actuator/metrics/executor.queue.remaining | jq .

# 线程池配置参考（application.yml）：
# core-pool-size: 8, max-pool-size: 16, queue-capacity: 200

# Step 3: 查看未完成的快照记录（是否有当日数据）
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT COUNT(*) FROM supplier_health_snapshot WHERE snapshot_date = CURRENT_DATE;"

# Step 4: 检查是否有供应商批次卡住（锁等待）
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT pid, relation::regclass, mode, granted
  FROM pg_locks WHERE NOT granted;"
```

**应急处置：**

```bash
# 手动触发评分任务（通过 XXL-Job 控制台或直接调用）
curl -X POST http://localhost:8080/api/v1/internal/scoring/trigger \
  -H "Authorization: Bearer $INTERNAL_TOKEN"

# 若任务已死锁，强制终止并重新触发
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE query LIKE '%supplier_health_snapshot%' AND state != 'idle';"
```

---

### 4.5 预签名 URL 失效（报告下载失败）

**症状：** 用户点击下载报告，返回 403 / URL expired。

**原因：** MinIO 预签名 URL TTL 默认 15 分钟，页面停留过久后链接失效。

**处置：** 这是设计行为（安全策略），引导用户刷新页面重新点击下载即可。
若频繁反馈，可将 `MINIO_PRESIGN_TTL_MINUTES` 调大至 60。

---

## 5. 应急方案

### 5.1 后端服务挂掉（API 全量不可用）

**判断标准：** `/actuator/health/liveness` 返回非 200，或 Nginx 返回 502/503。

```bash
# 应急步骤（总耗时目标：< 5 分钟恢复）

# Step 1: 确认容器状态
docker ps | grep scrm-api
# 若 STATUS 为 Exited，查看退出原因
docker inspect scrm-api | jq '.[0].State'

# Step 2: 查看最后 200 行日志，定位崩溃原因
docker logs --tail 200 scrm-api

# Step 3: 尝试快速重启
docker-compose -f docker-compose.prod.yml up -d api
# 等待 60s 观察健康状态
sleep 60 && curl -f http://localhost:8080/api/v1/actuator/health/readiness

# Step 4: 若重启失败，回滚至上一稳定版本
# 查看上一版本镜像
docker images harbor.company.com/scrm/scrm-api | head -5
# 回滚
docker-compose -f docker-compose.prod.yml up -d \
  --no-deps api  # 先修改 docker-compose.prod.yml 中的 image tag

# Step 5: 通知相关干系人，更新状态页
```

**联系人升级链：**
```
值班工程师 → Tech Lead → CTO（P0 故障超 15 分钟）
```

---

### 5.2 数据库宕机

**判断标准：** `pg_isready` 返回非 0，或 HikariCP 报 connection timeout。

```bash
# Step 1: 检查 PostgreSQL 容器状态
docker inspect scrm-postgres | jq '.[0].State.Status'

# Step 2: 尝试重启数据库
docker-compose -f docker-compose.prod.yml restart postgres
sleep 30 && docker exec scrm-postgres pg_isready -U scrm_user -d scrm_prod

# Step 3: 若数据目录损坏，从备份恢复
# 恢复前必须停止 API（防止写入损坏数据）
docker-compose -f docker-compose.prod.yml stop api

# 从最近一次备份恢复（备份路径根据实际配置）
# pg_restore -h localhost -U scrm_user -d scrm_prod /backup/scrm_prod_20260320.dump

# Step 4: 恢复后验证数据完整性
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c \
  "SELECT COUNT(*) FROM supplier; SELECT COUNT(*) FROM supplier_health_snapshot;"

# Step 5: 重启 API
docker-compose -f docker-compose.prod.yml up -d api
```

**数据备份策略（生产环境必须配置）：**
- 全量备份：每日 02:00，使用 `pg_dump` 存至对象存储
- WAL 归档：实时，支持 PITR（Point-in-Time Recovery）
- 备份验证：每周自动恢复至测试实例，验证可用性

---

### 5.3 Redis 宕机

**影响分析：**
- Tab 缓存全部失效 → 全量回源第三方 API，响应时间上升（预期 P95 > 2s）
- 评分缓存失效 → 触发重新计算（自动降级）
- **不影响核心数据读写（PostgreSQL 为权威数据源）**

```bash
# Step 1: 重启 Redis
docker-compose -f docker-compose.prod.yml restart redis
sleep 10 && docker exec scrm-redis redis-cli -a $REDIS_PASSWORD ping

# Step 2: 重启后缓存自动通过业务写入重建（无需手动预热）
# 若需加速预热，可触发供应商列表页的批量查询

# Step 3: 若持久化数据丢失（RDB/AOF 损坏），评估影响范围
# Redis 仅为缓存层，数据丢失不影响业务正确性，重建即可
```

---

### 5.4 数据丢失（误操作 / 软件 Bug）

**原则：优先确定数据范围，再决定恢复策略，禁止在生产 DB 上直接修复数据。**

```bash
# Step 1: 评估影响范围
# 查看 audit_log 追溯操作记录
docker exec scrm-postgres psql -U scrm_user -d scrm_prod -c "
  SELECT operator_name, action, target_type, target_id, diff, operated_at
  FROM audit_log
  WHERE operated_at > NOW() - INTERVAL '2 hours'
  ORDER BY operated_at DESC LIMIT 50;"

# Step 2: 如需 PITR 恢复，联系 DBA 操作
# 恢复至指定时间点（需 WAL 归档支持）

# Step 3: 若仅少量记录丢失，从快照/备份中提取并手动恢复
# 始终通过 Flyway 管理变更，禁止裸 DDL

# Step 4: 记录故障复盘 Issue，评估预防措施
```

---

## 6. 监控与告警配置

### 6.1 关键监控指标

| 指标 | 告警阈值 | 告警级别 | 通知方式 |
|------|----------|----------|----------|
| API P95 响应时间 | > 800ms（持续 5min） | WARNING | 企微群 |
| API P99 响应时间 | > 2000ms（持续 2min） | ERROR | 企微 + 电话 |
| API 错误率（5xx） | > 1%（持续 3min） | ERROR | 企微 + 电话 |
| HikariCP 活跃连接 | > 18（max=20） | WARNING | 企微群 |
| PostgreSQL 活跃连接 | > 80（max=100） | WARNING | 企微群 |
| Redis 内存使用率 | > 80% | WARNING | 企微群 |
| Kafka 消费 Lag | > 1000（持续 10min） | ERROR | 企微 + 电话 |
| 评分任务执行时长 | > 4 小时 | ERROR | 企微 + 电话 |
| 磁盘使用率 | > 80% | WARNING | 企微群 |
| 服务 liveness 失败 | 连续 3 次 | P0 | 电话唤醒 |

### 6.2 Spring Actuator 监控端点

```bash
# 应用整体健康状态
GET /api/v1/actuator/health

# 存活探针（Kubernetes liveness probe）
GET /api/v1/actuator/health/liveness

# 就绪探针（Kubernetes readiness probe）
GET /api/v1/actuator/health/readiness

# JVM 内存指标
GET /api/v1/actuator/metrics/jvm.memory.used

# HikariCP 连接池指标
GET /api/v1/actuator/metrics/hikaricp.connections.active
GET /api/v1/actuator/metrics/hikaricp.connections.pending

# 线程池（评分执行器）
GET /api/v1/actuator/metrics/executor.active?tag=name:scoringExecutor
```

---

## 7. 值班规范

### 7.1 值班职责

- **工作日（9:00–18:00）：** 一线开发轮值，15 分钟内响应 WARNING，5 分钟内响应 ERROR
- **非工作日 / 夜间：** SRE 轮值，P0 故障 10 分钟内响应，15 分钟内给出初步方案

### 7.2 故障严重级别

| 级别 | 描述 | 响应时限 | 恢复时限 |
|------|------|----------|----------|
| P0 | 服务全量不可用 | 5 min | 30 min |
| P1 | 核心功能不可用（列表/画像） | 10 min | 1 h |
| P2 | 非核心功能异常（报告下载/通知） | 30 min | 4 h |
| P3 | 性能下降但不影响功能 | 1 h | 次日修复 |

### 7.3 故障复盘模板

```markdown
## 故障复盘报告

**故障编号：** INCIDENT-YYYY-NNN
**时间线：**
- HH:MM 故障发生
- HH:MM 告警触发
- HH:MM 开始响应
- HH:MM 故障恢复

**根本原因：** [一句话描述]

**影响范围：** [受影响用户数 / 接口 / 数据]

**处置经过：** [按时间线叙述]

**改进措施：**
| 措施 | 负责人 | 完成时间 |
|------|--------|----------|
| ... | ... | ... |
```

---

*文档版本：v1.0 | 最后更新：2026-03-21 | 变更须通知 Tech Lead 审批*
