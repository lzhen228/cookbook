# SCRM 监控告警系统 — 快速上手

## 目录结构

```
monitoring/
├── prometheus/
│   ├── prometheus.yml              # 采集配置
│   └── rules/
│       └── alert_rules.yml         # 告警规则（6 组，30+ 条）
├── alertmanager/
│   ├── alertmanager.yml            # 路由 + 接收者配置
│   └── templates/
│       ├── wechat.tmpl             # 企微 Markdown 模板
│       └── email.tmpl              # HTML 邮件模板
└── grafana/
    ├── provisioning/
    │   ├── datasources/prometheus.yml
    │   └── dashboards/default.yml
    └── dashboards/
        └── scrm-overview.json      # 可直接导入的大盘 JSON
```

---

## 1. 环境变量准备

```bash
# 复制模板
cp .env.example .env.monitoring

# 编辑以下必填项
vim .env.monitoring
```

| 变量名 | 说明 | 示例 |
|--------|------|------|
| `SMTP_HOST` | SMTP 服务器 | `smtp.exmail.qq.com` |
| `SMTP_USERNAME` | 发件邮箱 | `scrm-alert@company.com` |
| `SMTP_PASSWORD` | 邮箱密码 | 从 Vault 注入 |
| `WECHAT_WEBHOOK_URL` | 企微机器人 Webhook | `https://qyapi.weixin.qq.com/...` |
| `ALERT_EMAIL_CRITICAL` | 紧急告警收件人 | `sre@company.com` |
| `ALERT_EMAIL_OPS` | Ops 告警收件人 | `ops@company.com` |
| `ALERT_EMAIL_DBA` | DBA 告警收件人 | `dba@company.com` |
| `GRAFANA_ADMIN_PASSWORD` | Grafana 管理员密码 | 从 Vault 注入 |
| `DB_USERNAME` / `DB_PASSWORD` | PG 连接信息 | 同主应用 |
| `REDIS_PASSWORD` | Redis 密码 | 同主应用 |

---

## 2. 启动监控栈

```bash
# 方式一：随主应用栈一起启动（推荐生产）
docker-compose \
  -f docker-compose.yml \
  -f docker-compose.monitoring.yml \
  --env-file .env.monitoring \
  up -d

# 方式二：单独启动监控栈（应用已在运行）
docker-compose \
  -f docker-compose.monitoring.yml \
  --env-file .env.monitoring \
  up -d

# 查看启动状态
docker-compose -f docker-compose.monitoring.yml ps
```

---

## 3. 访问地址

| 服务 | 地址 | 说明 |
|------|------|------|
| Grafana | http://localhost:3000 | 默认账号 admin，密码见 .env.monitoring |
| Prometheus | http://localhost:9090 | 原始指标 + 告警规则 |
| Alertmanager | http://localhost:9093 | 告警状态管理 |

---

## 4. Grafana 大盘导入（如自动加载失败）

1. 登录 Grafana → **Dashboards** → **Import**
2. 上传文件：`monitoring/grafana/dashboards/scrm-overview.json`
3. 选择数据源：Prometheus
4. 点击 **Import**

---

## 5. 验证告警规则

```bash
# 验证规则文件语法
docker run --rm \
  -v $(pwd)/monitoring/prometheus/rules:/rules \
  prom/prometheus:v2.51.0 \
  promtool check rules /rules/alert_rules.yml

# 查看当前触发中的告警
curl -s http://localhost:9090/api/v1/alerts | jq '.data.alerts[] | {name: .labels.alertname, state: .state}'

# 热重载 Prometheus 配置（修改后无需重启）
curl -X POST http://localhost:9090/-/reload

# 热重载 Alertmanager 配置
curl -X POST http://localhost:9093/-/reload
```

---

## 6. Spring Boot 接入配置

在 `services/api/src/main/resources/application.yml` 中确认已开启：

```yaml
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics,prometheus
  metrics:
    export:
      prometheus:
        enabled: true
    tags:
      application: scrm-api
      env: ${APP_ENV:dev}
    distribution:
      percentiles-histogram:
        http.server.requests: true   # 开启直方图（P95/P99 计算必需）
      percentiles:
        http.server.requests: 0.5, 0.95, 0.99
      sla:
        http.server.requests: 200ms, 500ms, 800ms, 2000ms
```

同时在 `pom.xml` 中添加（若未添加）：

```xml
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

---

## 7. PostgreSQL 慢查询监控前置条件

```sql
-- 在 PostgreSQL 中开启 pg_stat_statements 扩展
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- 在 postgresql.conf 中添加
shared_preload_libraries = 'pg_stat_statements'
pg_stat_statements.track = all
pg_stat_statements.max = 10000
```

---

## 8. 告警规则阈值速查

| 指标 | 警告阈值 | 严重阈值 | 对应 TECH_SPEC 要求 |
|------|---------|---------|---------------------|
| API P95 延迟 | — | > 800ms | ✅ 接口 P95 < 800ms |
| API 错误率 | — | > 1% | ✅ 错误率 < 1% |
| Kafka Lag | — | > 1000 条 | ✅ 消费延迟 < 1000 |
| Redis 命中率 | — | < 80% | ✅ 命中率 ≥ 80% |
| CPU 使用率 | > 80% | > 95% | 运维指标 |
| 内存使用率 | > 85% | — | 运维指标 |
| 磁盘使用率 | > 85% | > 95% | 运维指标 |
| PG 连接数 | > 80% max | > 95% max | 运维指标 |

---

## 9. 常用运维命令

```bash
# 查看 Alertmanager 当前告警
curl -s http://localhost:9093/api/v2/alerts | jq '.[].labels'

# 临时静默某个告警（4小时，例如计划维护期间）
curl -X POST http://localhost:9093/api/v2/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [{"name": "alertname", "value": "HostCpuHigh", "isRegex": false}],
    "startsAt": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
    "endsAt": "'$(date -u -d '+4 hours' +%Y-%m-%dT%H:%M:%SZ)'",
    "comment": "计划维护窗口",
    "createdBy": "ops"
  }'

# 查看 Prometheus 采集目标状态
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health, lastError: .lastError}'
```
