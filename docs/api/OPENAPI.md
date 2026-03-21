# 供应链风险管理平台 —— API 技术文档

> **规范版本：** OpenAPI 3.0.3
> **API 版本：** v1.0.0
> **Base URL：** `https://scrm.company.com/api/v1`
> **更新日期：** 2026-03-21
> **鉴权方式：** Bearer JWT（Header: `Authorization: Bearer <access_token>`）

---

## 目录

1. [统一规范](#1-统一规范)
2. [供应商模块 API](#2-供应商模块-api)
3. [预警方案模块 API](#3-预警方案模块-api)
4. [风险事项模块 API](#4-风险事项模块-api)
5. [系统模块 API](#5-系统模块-api)
6. [架构部署图](#6-架构部署图)
7. [版本变更记录](#7-版本变更记录)

---

## 1. 统一规范

### 1.1 响应体结构

所有接口均返回统一响应体 `ApiResponse<T>`：

```json
{
  "code": 0,
  "msg": "success",
  "data": { },
  "traceId": "a1b2c3d4e5f6"
}
```

| 字段 | 类型 | 说明 |
|------|------|------|
| `code` | integer | `0` 表示成功，非零为业务错误码（见 1.3） |
| `msg` | string | 结果描述，成功为 `"success"` |
| `data` | object / null | 业务数据，失败时为 `null` |
| `traceId` | string | 全链路追踪 ID，排查问题时提供给技术支持 |

### 1.2 分页结构（游标分页）

列表接口统一使用 Keyset（游标）分页，禁止 OFFSET 深分页：

```json
{
  "code": 0,
  "msg": "success",
  "data": {
    "total": 1024,
    "page": 1,
    "page_size": 20,
    "next_cursor": "eyJzIjozMi41LCJpZCI6MTAwMX0",
    "items": [ ]
  }
}
```

**游标说明：** `next_cursor` 为 Base64 URL 编码的 JSON，格式 `{"s": <score>, "id": <id>}`，下一页请求传入 `cursor` 参数即可。`next_cursor` 为 `null` 表示已是最后一页。

### 1.3 业务错误码

| 错误码 | HTTP 状态 | 说明 |
|--------|-----------|------|
| `400001` | 400 | 请求参数格式错误 |
| `400002` | 400 | 分页参数超出限制（page_size 最大 100） |
| `400003` | 400 | 排序字段不在白名单 |
| `400004` | 400 | 健康等级枚举值非法 |
| `400005` | 400 | 合作状态枚举值非法 |
| `400010` | 400 | 预警方案权重总和不等于 100% |
| `400011` | 400 | 激活中的预警方案不可删除 |
| `400020` | 400 | Tab 名称非法 |
| `401001` | 401 | 未登录或 Token 已过期 |
| `403001` | 403 | 权限不足（需要更高角色） |
| `404001` | 404 | 资源不存在 |
| `409001` | 409 | 资源冲突（如方案名称重复） |
| `429001` | 429 | 请求频率超过限制 |
| `500001` | 500 | 服务内部错误 |
| `503001` | 503 | 外部服务（第三方 API）不可用 |

### 1.4 限流规则（Nginx 层）

| 端点 | 限制 | 说明 |
|------|------|------|
| `/api/v1/**` | 60 req/min/IP | 全局限流 |
| `GET /suppliers` | 30 req/min/user | 列表查询 |
| `GET /suppliers/{id}/tabs/*` | 60 req/min/user | Tab 懒加载 |
| `POST /suppliers/{id}/reports` | 5 req/min/user | 报告生成 |

### 1.5 RBAC 权限矩阵

| 接口 | RISK_ADMIN | RISK_ANALYST | READER |
|------|-----------|--------------|--------|
| 供应商列表/画像（读） | ✅ | ✅ | ✅ |
| 供应商关注/取关 | ✅ | ✅ | ❌ |
| 报告生成与下载 | ✅ | ✅ | ❌ |
| 预警方案管理 | ✅ | ❌ | ❌ |
| 指标管理 | ✅ | ❌ | ❌ |
| 风险事项处理 | ✅ | ✅ | ❌ |

---

## 2. 供应商模块 API

### 2.1 获取供应商列表

```
GET /suppliers
```

**权限：** `READER` 及以上

**Query 参数：**

| 参数名 | 类型 | 必填 | 默认值 | 说明 |
|--------|------|------|--------|------|
| `page` | integer | 否 | `1` | 页码，≥ 1 |
| `page_size` | integer | 否 | `20` | 每页数量，1–100 |
| `keyword` | string | 否 | — | 供应商名称关键字（pg_trgm 模糊搜索） |
| `health_level` | string | 否 | — | 健康等级，多值逗号分隔：`high_risk,attention,low_risk` |
| `cooperation_status` | string | 否 | — | 合作状态，多值逗号分隔：`cooperating,potential,qualified,blacklist,restricted` |
| `supply_items` | string | 否 | — | 供应物品，多值逗号分隔（JSONB @> 过滤） |
| `sort_by` | string | 否 | `health_score` | 排序字段白名单：`health_score / name / created_at` |
| `sort_order` | string | 否 | `asc` | 排序方向：`asc / desc` |
| `cursor` | string | 否 | — | 游标（第二页起传入上一页返回的 next_cursor） |

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "d9f3a2b1c4e5",
  "data": {
    "total": 342,
    "page": 1,
    "page_size": 20,
    "next_cursor": "eyJzIjozMi41LCJpZCI6MTAwMX0",
    "items": [
      {
        "id": 1001,
        "name": "华为技术有限公司",
        "unified_code": "91440300MA5FMHQ308",
        "health_score": 32.5,
        "health_level": "high_risk",
        "cooperation_status": "cooperating",
        "week_trend": -5.2,
        "region_province": "广东省",
        "region_city": "深圳市",
        "is_followed": false,
        "cache_updated_at": "2026-03-21T00:30:00+08:00"
      }
    ]
  }
}
```

**错误响应示例（400）：**

```json
{
  "code": 400003,
  "msg": "排序字段不合法，允许值：health_score, name, created_at",
  "data": null,
  "traceId": "d9f3a2b1c4e5"
}
```

---

### 2.2 获取供应商画像（主接口）

```
GET /suppliers/{supplierId}/profile
```

**权限：** `READER` 及以上

**Path 参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `supplierId` | integer(int64) | 供应商 ID |

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "e8f4a3c2d1b0",
  "data": {
    "basic_info": {
      "id": 1001,
      "name": "华为技术有限公司",
      "unified_code": "91440300MA5FMHQ308",
      "cooperation_status": "cooperating",
      "region_province": "广东省",
      "region_city": "深圳市",
      "listed_status": "listed",
      "is_china_top500": true,
      "is_world_top500": true,
      "supplier_type": "supplier",
      "nature": "private",
      "supply_items": ["半导体", "座舱域控"],
      "is_followed": false,
      "created_at": "2025-01-15T09:00:00+08:00"
    },
    "health_info": {
      "health_score": 32.5,
      "health_level": "high_risk",
      "week_trend": -5.2,
      "dimension_scores": {
        "legal": 20.0,
        "finance": 45.0,
        "credit": 38.0,
        "tax": 55.0,
        "operation": 30.0
      },
      "snapshot_date": "2026-03-21",
      "cache_updated_at": "2026-03-21T00:30:00+08:00"
    },
    "recent_risk_events": [
      {
        "id": 501,
        "risk_dimension": "legal",
        "description": "存在未结清司法判决，涉案金额 300 万元",
        "status": "open",
        "triggered_at": "2026-03-20T14:23:00+08:00"
      }
    ],
    "risk_event_total": 3
  }
}
```

**错误响应（404）：**

```json
{
  "code": 404001,
  "msg": "供应商不存在：supplierId=9999",
  "data": null,
  "traceId": "e8f4a3c2d1b0"
}
```

---

### 2.3 获取供应商 Tab 数据（懒加载）

```
GET /suppliers/{supplierId}/tabs/{tabName}
```

**权限：** `READER` 及以上

**Path 参数：**

| 参数名 | 类型 | 允许值 | 说明 |
|--------|------|--------|------|
| `supplierId` | integer(int64) | — | 供应商 ID |
| `tabName` | string | `basic-info / business-info / judicial / credit / tax` | Tab 标识 |

**响应示例（200 OK，含缓存陈旧标识）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "f7g5h4i3j2k1",
  "data": {
    "is_stale": false,
    "data_as_of": "2026-03-21T08:00:00+08:00",
    "content": {
      "registered_capital": "1000000万元",
      "established_date": "1987-09-15",
      "legal_representative": "任正非",
      "business_scope": "研究、开发、生产和销售通讯设备..."
    }
  }
}
```

> **降级说明：** 若外部数据源不可用，`is_stale: true`，`content` 返回最近一次缓存数据；若从未获取过，`content` 为 `null`，前端展示"暂无数据"。

**Tab 数据说明：**

| tabName | 数据来源 | Redis TTL | 内容描述 |
|---------|---------|-----------|----------|
| `basic-info` | ERP/SRM 内部 | 24h ± 30min | 注册信息、法人、经营范围 |
| `business-info` | 工商（外部 API） | 24h ± 30min | 股权结构、分支机构、年报 |
| `judicial` | 司法（外部 API） | 24h ± 30min | 诉讼记录、执行信息、失信记录 |
| `credit` | 征信（外部 API） | 24h ± 30min | 信用评分、违规记录 |
| `tax` | 税务（外部 API） | 24h ± 30min | 纳税等级、欠税记录 |

---

### 2.4 切换供应商关注状态

```
PATCH /suppliers/{supplierId}/follow
```

**权限：** `RISK_ANALYST` 及以上

**Path 参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `supplierId` | integer(int64) | 供应商 ID |

**请求体：**

```json
{
  "follow": true
}
```

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "g6h5i4j3k2l1",
  "data": {
    "id": 1001,
    "is_followed": true
  }
}
```

---

### 2.5 生成供应商报告

```
POST /suppliers/{supplierId}/reports
```

**权限：** `RISK_ANALYST` 及以上

**限流：** 5 次/分钟/用户

**请求体：**

```json
{
  "report_type": "full"
}
```

**响应示例（202 Accepted，异步生成）：**

```json
{
  "code": 0,
  "msg": "报告生成任务已提交",
  "traceId": "h5i4j3k2l1m0",
  "data": {
    "task_id": "task_20260321_1001",
    "estimated_seconds": 30,
    "status": "pending"
  }
}
```

---

### 2.6 获取报告下载 URL（预签名）

```
GET /suppliers/{supplierId}/reports/{reportId}/download-url
```

**权限：** `RISK_ANALYST` 及以上

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "i4j3k2l1m0n9",
  "data": {
    "download_url": "https://minio.company.com/scrm-reports/supplier/1001/report_20260321.pdf?X-Amz-Signature=...",
    "expires_at": "2026-03-21T10:15:00+08:00",
    "ttl_seconds": 900
  }
}
```

> **安全说明：** 预签名 URL TTL 为 15 分钟，禁止长期存储。每次下载需重新调用此接口获取新 URL。

---

## 3. 预警方案模块 API

### 3.1 获取预警方案列表

```
GET /alert-plans
```

**权限：** `READER` 及以上

**响应示例：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "j3k2l1m0n9o8",
  "data": [
    {
      "id": 1,
      "name": "默认预警方案",
      "description": "适用于所有合作供应商的基础风险评估方案",
      "is_active": true,
      "indicator_count": 6,
      "created_at": "2026-01-01T00:00:00+08:00"
    }
  ]
}
```

---

### 3.2 创建预警方案

```
POST /alert-plans
```

**权限：** `RISK_ADMIN`

**请求体：**

```json
{
  "name": "高风险供应商专项方案",
  "description": "针对高风险行业的强化审查方案",
  "level_thresholds": {
    "high_risk": [0, 40],
    "attention": [40, 70],
    "low_risk": [70, 100]
  },
  "scope_config": {
    "cooperation_status": ["cooperating", "qualified"]
  },
  "indicators": [
    { "indicator_id": 1, "weight": 0.3, "is_redline": true },
    { "indicator_id": 2, "weight": 0.2, "is_redline": false },
    { "indicator_id": 3, "weight": 0.5, "is_redline": false }
  ]
}
```

> **业务约束：** `indicators[].weight` 总和必须等于 1.0（允许 ±0.001 浮点误差）。

**响应示例（201 Created）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "k2l1m0n9o8p7",
  "data": { "id": 2, "name": "高风险供应商专项方案" }
}
```

---

### 3.3 激活预警方案

```
PATCH /alert-plans/{planId}/activate
```

**权限：** `RISK_ADMIN`

> **业务规则：** 同一时间只允许一个方案处于激活状态，激活新方案会自动停用当前激活方案。

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "l1m0n9o8p7q6",
  "data": { "id": 2, "is_active": true }
}
```

---

## 4. 风险事项模块 API

### 4.1 获取风险事项列表

```
GET /risk-events
```

**权限：** `READER` 及以上

**Query 参数：**

| 参数名 | 类型 | 说明 |
|--------|------|------|
| `page` | integer | 页码 |
| `page_size` | integer | 每页数量（最大 100） |
| `status` | string | 状态筛选：`open/confirmed/processing/closed/dismissed` |
| `risk_dimension` | string | 风险维度：`legal/finance/credit/tax/operation` |
| `supplier_id` | integer(int64) | 按供应商筛选 |
| `date_from` | string(date) | 触发日期起（`YYYY-MM-DD`） |
| `date_to` | string(date) | 触发日期止（`YYYY-MM-DD`） |

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "m0n9o8p7q6r5",
  "data": {
    "today_new_count": 5,
    "total": 128,
    "page": 1,
    "page_size": 20,
    "next_cursor": null,
    "items": [
      {
        "id": 501,
        "supplier_id": 1001,
        "supplier_name": "华为技术有限公司",
        "risk_dimension": "legal",
        "description": "存在未结清司法判决，涉案金额 300 万元",
        "status": "open",
        "assignee_id": null,
        "triggered_at": "2026-03-20T14:23:00+08:00",
        "created_at": "2026-03-20T14:23:05+08:00"
      }
    ]
  }
}
```

---

### 4.2 更新风险事项状态

```
PATCH /risk-events/{eventId}
```

**权限：** `RISK_ANALYST` 及以上

**请求体：**

```json
{
  "status": "processing",
  "assignee_id": 101,
  "close_note": null
}
```

**状态流转规则：**

```
open → confirmed → processing → closed
 └──────────────────────────→ dismissed
```

**响应示例（200 OK）：**

```json
{
  "code": 0,
  "msg": "success",
  "traceId": "n9o8p7q6r5s4",
  "data": {
    "id": 501,
    "status": "processing",
    "assignee_id": 101
  }
}
```

---

## 5. 系统模块 API

### 5.1 健康检查

```
GET /actuator/health/liveness
GET /actuator/health/readiness
```

**权限：** 无需鉴权（内网访问）

**响应示例：**

```json
{ "status": "UP" }
```

---

## 6. 架构部署图

### 6.1 整体架构

```
┌─────────────────────────────────────────────────────────────────────┐
│                           生产环境（Docker Compose / K8s）             │
│                                                                       │
│  ┌──────────────┐     ┌───────────────────────────────────────────┐  │
│  │    Nginx     │────▶│              scrm-frontend                 │  │
│  │  (80/443)    │     │   React SPA  /  nginx:1.25-alpine         │  │
│  │  反向代理     │     │   静态资源 1y 缓存 / SPA fallback           │  │
│  │  SSL 终止     │     └───────────────────────────────────────────┘  │
│  │  限流 60/min │     ┌───────────────────────────────────────────┐  │
│  │              │────▶│               scrm-api                    │  │
│  └──────────────┘     │   Spring Boot 3.2.1 / Java 17             │  │
│                        │   Port 8080 / HikariCP pool=20            │  │
│                        │   scoringExecutor: core=8, max=16         │  │
│                        └──────┬──────────┬──────────┬─────────────┘  │
│                               │          │          │                 │
│                    ┌──────────▼──┐  ┌────▼────┐  ┌─▼──────────────┐ │
│                    │ PostgreSQL  │  │ Redis 7 │  │  Kafka 3.6      │ │
│                    │ 15-alpine   │  │ 7-alpine│  │  KRaft mode     │ │
│                    │ Port 5432   │  │Port 6379│  │  Port 9092      │ │
│                    │ TimescaleDB │  │ TTL+AOF │  │  DLQ 支持        │ │
│                    └─────────────┘  └─────────┘  └────────────────┘ │
│                                                                       │
│                    ┌────────────────────────────────────────────────┐ │
│                    │               MinIO                             │ │
│                    │   Port 9000(API) / 9001(Console)               │ │
│                    │   scrm-reports bucket / 预签名 URL TTL=15min    │ │
│                    └────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────┘
```

### 6.2 请求链路（供应商列表）

```
用户浏览器
    │ GET /suppliers?health_level=high_risk&page_size=20
    ▼
Nginx（限流检查 30 req/min/user）
    │
    ▼
scrm-api (TraceFilter → RequestLogFilter → SecurityFilter)
    │
    ▼
SupplierController.listSuppliers()
    │ 参数校验 @Validated
    ▼
SupplierServiceImpl.listSuppliers()
    │ ① 白名单校验 sortBy
    │ ② 游标解码 Base64 → {score, id}
    ▼
SupplierMapper.selectSupplierList (SupplierMapper.xml)
    │ 覆盖索引 idx_supplier_list_covering
    │ pg_trgm 模糊搜索 / JSONB @> 过滤
    ▼
PostgreSQL 15
    │ 返回 20 条记录（P95 < 800ms）
    ▼
组装 SupplierListResponse（含 next_cursor）
    │
    ▼
ApiResponse.ok(data) → JSON → Nginx → 浏览器
```

### 6.3 数据流（批量评分）

```
每日 00:00 (XXL-Job)
    │
    ▼
ScoringJob.execute()
    │
    ├── 查询激活预警方案（Caffeine 本地缓存 30min）
    │
    ├── 分批次（每批 200 条）从 supplier 表拉取供应商
    │       │
    │       ▼
    │   scoringExecutor (core=8 / max=16 / queue=200)
    │   并行计算每批次健康分
    │       │
    │       ▼
    │   批量写入 supplier_health_snapshot
    │   批量回写 supplier.health_score_cache / health_level_cache
    │
    └── 完成后发布 Kafka 事件 supplier.scoring.completed
            │
            ▼
        预警触发引擎消费，检查阈值 → 生成 risk_event → 通知推送
```

---

## 7. 版本变更记录

| 版本 | 日期 | 变更类型 | 变更说明 |
|------|------|---------|---------|
| v1.0.0 | 2026-03-21 | 初版 | 供应商列表/画像/Tab/关注接口上线；游标分页；统一响应体 |
| v1.0.0 | 2026-03-21 | 初版 | 预警方案 CRUD；指标权重关联表；激活接口 |
| v1.0.0 | 2026-03-21 | 初版 | 风险事项列表/状态流转；MinIO 预签名报告下载 |

### 后续规划（v1.1.0，预计 04-30）

| 功能 | 说明 |
|------|------|
| 风险看板统计接口 | `GET /dashboard/overview` 含各等级数量/趋势/Top10 |
| 用户认证模块 | `POST /auth/login` / `POST /auth/refresh` / `POST /auth/logout` |
| 指标管理 CRUD | `GET/POST/PUT/DELETE /indicators` |
| 批量标记风险事项 | `PATCH /risk-events/batch` |
| 通知配置接口 | 企微 Webhook / SMTP 配置管理 |

---

*文档版本：v1.0.0 | 最后更新：2026-03-21 | 维护人：技术团队*
