# 供应链风险管理平台 — 技术方案大纲

> **文档版本：** v0.1  
> **基于产品方案：** 供应链风险管理平台 V1.3（2026-03-18）  
> **编写日期：** 2026-03-21
> **状态：** 草稿，待评审

---

## 目录

1. [项目背景与目标](#1-项目背景与目标)
2. [核心模块划分](#2-核心模块划分)
3. [技术栈选型](#3-技术栈选型)
4. [核心数据模型设计](#4-核心数据模型设计)
5. [关键接口设计](#5-关键接口设计)
6. [安全设计](#6-安全设计)
7. [性能设计](#7-性能设计)
8. [部署架构与环境规划](#8-部署架构与环境规划)
9. [风险点与 Mitigation 方案](#9-风险点与-mitigation-方案)

---

## 1. 项目背景与目标

### 1.1 业务背景

采购与供应链部门面临四大核心痛点：

| 痛点         | 描述                                 |
| ------------ | ------------------------------------ |
| 风险管理滞后 | 缺乏主动识别机制，风险发生后才知晓   |
| 风险点增多   | 供应链复杂度上升，潜在风险点持续增加 |
| 管控闭环缺失 | 风险识别后缺乏跟踪与闭环管理         |
| 数据孤岛严重 | 内外部数据未打通，缺乏全局视角       |

### 1.2 本期目标（03.31 MVP）

以**供应商风险管理**为试点，完成三项核心交付：

1. **数据接入**：供应商内外部核心数据打通（合作状态、司法、信用、税务等）
2. **模型搭建**：基础风险评分模型（红线指标 + 常规指标加权）
3. **功能闭环**：风险预警配置 → 预警推送 → 供应商画像 → 风险看板的完整链路跑通

### 1.3 技术目标

- 系统可用性 ≥ 99.5%（非核心交易链路）
- 风险预警推送延迟 ≤ 5 分钟（从数据更新到通知触达）
- 供应商列表页响应时间 P95 ≤ 800ms
- 数据接入可扩展，后续可接入更多外部数据源

---

## 2. 核心模块划分

### 2.1 模块总览

```
供应链风险管理平台
├── 数据接入层
│   ├── 内部数据同步（ERP/SRM）
│   └── 外部数据适配（第三方征信/工商/司法）
├── 风险引擎
│   ├── 指标计算引擎
│   └── 预警触发引擎
├── 业务功能层
│   ├── 风险预警管理
│   │   ├── 指标规则配置
│   │   └── 预警方案配置
│   ├── 供应商信息管理
│   │   ├── 供应商列表
│   │   └── 供应商画像详情
│   └── 供应商风险分析
│       ├── 风险看板
│       └── 风险预警中心
└── 基础服务层
    ├── 用户与权限
    ├── 消息通知
    └── 报告生成
```

### 2.2 子模块说明

#### 2.2.1 数据接入层

| 子模块         | 职责                                                           | 设计理由                                     |
| -------------- | -------------------------------------------------------------- | -------------------------------------------- |
| 内部数据同步   | 从 ERP/SRM 拉取供应商基础信息、合作状态、采购记录              | 内部数据为权威数据源，需全量 + 增量同步机制  |
| 外部数据适配器 | 对接征信、工商、司法、税务等第三方 API，统一封装为标准数据格式 | 外部数据源多且接口差异大，适配器模式隔离变化 |

#### 2.2.2 风险引擎

| 子模块       | 职责                                                                | 设计理由                                                     |
| ------------ | ------------------------------------------------------------------- | ------------------------------------------------------------ |
| 指标计算引擎 | 按预设公式计算各供应商的维度得分与综合健康分（每日 00:00 批量计算） | 评分依赖多源数据聚合，批量离线计算更稳定，结果存储后前端直查 |
| 预警触发引擎 | 实时/准实时监听数据变化，触发阈值时生成风险事项并推送通知           | 与批量计算解耦，确保高优先级事件（红线触发）快速响应         |

#### 2.2.3 风险预警管理

| 子模块       | 职责                                                         |
| ------------ | ------------------------------------------------------------ |
| 指标规则配置 | 维护指标库（名称、介绍、维度、计算公式），支持搜索与列表展示 |
| 预警方案配置 | 配置方案的适用范围、指标权重、健康等级阈值；支持多方案共存   |

#### 2.2.4 供应商信息管理

| 子模块         | 职责                                                                                          |
| -------------- | --------------------------------------------------------------------------------------------- |
| 供应商列表     | 多维筛选 + 默认按健康分升序排列，展示名称、等级、趋势等核心字段                               |
| 供应商画像详情 | 整合企业核心数据、风险评分卡、风险事项列表、五个维度 Tab 详细信息；支持健康评估报告生成与下载 |

#### 2.2.5 供应商风险分析

| 子模块       | 职责                                                          |
| ------------ | ------------------------------------------------------------- |
| 风险看板     | 各等级统计、平均健康分趋势折线图、Top 10 高风险排行、评分列表 |
| 风险预警中心 | 以风险事项为维度的实时监控，展示今日新增数量与事项列表        |

---

## 3. 技术栈选型

### 3.1 后端

| 技术     | 选型                      | 选型理由                                                          |
| -------- | ------------------------- | ----------------------------------------------------------------- |
| 语言     | Java 17 + Spring Boot 3.x | 团队熟悉度高，生态成熟，对企业级数据处理有完善支持                |
| 任务调度 | XXL-Job                   | 轻量级分布式调度框架，满足每日 00:00 批量计算需求，可视化任务监控 |
| 消息队列 | Apache Kafka              | 解耦数据接入层与预警触发引擎；支持高吞吐数据流；消费者可独立扩展  |
| API 框架 | Spring MVC + OpenAPI 3.0  | 自动生成接口文档，前后端联调效率高                                |

**选型理由说明：** 选择 Kafka 而非 RabbitMQ，是因为外部数据拉取量较大（日均可能数万条记录变更），Kafka 的高吞吐与持久化能力更适合数据管道场景。

### 3.2 前端

| 技术      | 选型                  | 选型理由                                                    |
| --------- | --------------------- | ----------------------------------------------------------- |
| 框架      | React 18 + TypeScript | 组件化开发，配合 TS 降低大型表单与复杂看板的维护成本        |
| UI 组件库 | Ant Design 5.x        | 企业级中后台组件丰富（表格、筛选器、图表等），减少重复开发  |
| 图表      | ECharts               | 折线图、排行榜等复杂图表能力强，定制化程度高                |
| 状态管理  | Zustand               | 轻量，适合本项目中等复杂度的状态管理，无 Redux 样板代码负担 |

### 3.3 数据库

| 类型          | 选型                        | 用途                                                   | 选型理由                                                                   |
| ------------- | --------------------------- | ------------------------------------------------------ | -------------------------------------------------------------------------- |
| 主数据库      | PostgreSQL 15               | 供应商信息、指标配置、预警方案、风险事项等核心业务数据 | 支持 JSONB 存储扩展属性，JSON 操作能力强于 MySQL，适合供应商画像的灵活字段 |
| 缓存          | Redis 7                     | 健康分缓存、看板统计缓存、Session                      | 读多写少的场景（列表、看板），减少数据库压力                               |
| 时序/趋势数据 | PostgreSQL TimescaleDB 扩展 | 近 7 天/30 天健康分趋势数据                            | 避免引入新中间件，TimescaleDB 扩展即可满足 MVP 阶段的时序查询需求          |

### 3.4 中间件与基础设施

| 组件     | 选型                                | 用途                           |
| -------- | ----------------------------------- | ------------------------------ |
| 消息通知 | 企业微信机器人 / 邮件 SMTP          | 风险预警推送到相关责任人       |
| 文件存储 | MinIO / 对象存储                    | 健康评估报告 PDF 存储与下载    |
| API 网关 | Nginx                               | 反向代理、静态资源、限流       |
| 容器编排 | Docker + Docker Compose（MVP 阶段） | 快速部署，后续可平滑迁移至 K8s |

---

## 4. 核心数据模型设计

> 以下为核心表结构，字段为关键字段，非完整 DDL。

### 4.1 供应商主表 `supplier`

```sql
CREATE TABLE supplier (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,           -- 供应商名称
    unified_code    VARCHAR(50) UNIQUE,              -- 统一社会信用代码
    cooperation_status VARCHAR(20),                  -- 合作状态: cooperating/potential/qualified/blacklist/restricted
    region_province VARCHAR(50),                     -- 注册省份
    region_city     VARCHAR(50),                     -- 注册城市
    listed_status   VARCHAR(10),                     -- 上市状态: listed/unlisted
    is_china_top500 BOOLEAN DEFAULT FALSE,
    is_world_top500 BOOLEAN DEFAULT FALSE,
    supplier_type   VARCHAR(20),                     -- 类型: distributor/supplier/agent/other
    nature          VARCHAR(20),                     -- 性质: private/foreign/state/joint
    supply_items    JSONB,                           -- 供应物（数组），用JSONB存储支持灵活扩展
    is_followed     BOOLEAN DEFAULT FALSE,
    ext_data        JSONB,                           -- 外部数据扩展字段（工商、司法等）
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

**设计理由：** `supply_items` 和 `ext_data` 使用 JSONB，避免为每个外部数据字段增加列，支持后续数据源扩展而无需 DDL 变更。

### 4.2 健康评分快照表 `supplier_health_snapshot`

```sql
CREATE TABLE supplier_health_snapshot (
    id              BIGSERIAL PRIMARY KEY,
    supplier_id     BIGINT NOT NULL REFERENCES supplier(id),
    plan_id         BIGINT NOT NULL,                 -- 使用的预警方案ID
    health_score    DECIMAL(5,2),                    -- 综合健康分 0-100
    health_level    VARCHAR(20),                     -- high_risk/attention/low_risk
    dimension_scores JSONB,                          -- 各风险维度得分，如 {"legal":85,"finance":60}
    snapshot_date   DATE NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    INDEX idx_supplier_date (supplier_id, snapshot_date DESC)
);
```

**设计理由：** 每日快照而非覆盖更新，支持趋势分析（近 7 天折线图）。`snapshot_date` + `supplier_id` 联合索引保证时序查询效率。

### 4.3 风险预警方案表 `alert_plan`

```sql
CREATE TABLE alert_plan (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(30) UNIQUE NOT NULL,
    description     VARCHAR(100),
    scope_config    JSONB,                           -- 应用企业范围配置
    indicator_weights JSONB,                         -- 指标权重配置，如 [{"indicator_id":1,"weight":0.3}]
    redline_indicators JSONB,                        -- 红线指标ID列表
    level_thresholds JSONB,                          -- 健康等级阈值，如 {"high_risk":[0,40],"attention":[40,70],"low_risk":[70,100]}
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 4.4 指标库表 `indicator`

```sql
CREATE TABLE indicator (
    id              BIGSERIAL PRIMARY KEY,
    name            VARCHAR(100) NOT NULL,
    description     TEXT,
    risk_dimension  VARCHAR(50),                     -- 风险维度：legal/finance/operation/credit/tax
    formula         TEXT,                            -- 计算公式描述
    data_source     VARCHAR(50),                     -- 数据来源标识
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

### 4.5 风险事项表 `risk_event`

```sql
CREATE TABLE risk_event (
    id              BIGSERIAL PRIMARY KEY,
    supplier_id     BIGINT NOT NULL REFERENCES supplier(id),
    indicator_id    BIGINT REFERENCES indicator(id),
    risk_dimension  VARCHAR(50),
    description     TEXT NOT NULL,                   -- 风险事项描述
    source_url      VARCHAR(500),                    -- 来源跳转链接
    triggered_at    TIMESTAMPTZ NOT NULL,
    is_notified     BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ DEFAULT NOW()
);
```

---

## 5. 关键接口设计

> Base URL: `/api/v1`  
> 统一响应结构：`{ "code": 0, "msg": "ok", "data": {...} }`

### 5.1 供应商列表接口

**用途：** 供应商列表页，支持多维筛选、分页

```
GET /suppliers
```

**请求参数（Query String）：**

```json
{
  "keyword": "string | 供应商名称关键词",
  "health_level": "string[] | [high_risk, attention, low_risk]",
  "cooperation_status": "string[]",
  "region_province": "string",
  "listed_status": "string",
  "is_china_top500": "boolean",
  "supplier_type": "string[]",
  "nature": "string[]",
  "supply_items": "string[]",
  "is_followed": "boolean",
  "sort_by": "health_score | name，默认 health_score",
  "sort_order": "asc | desc，默认 asc",
  "page": "integer，default 1",
  "page_size": "integer，default 20，max 100"
}
```

**响应示例：**

```json
{
  "code": 0,
  "msg": "ok",
  "data": {
    "total": 256,
    "items": [
      {
        "id": 1001,
        "name": "某某半导体有限公司",
        "health_level": "high_risk",
        "health_score": 32.5,
        "week_trend": -3.2,
        "region": "广东省 深圳市",
        "cooperation_status": "cooperating",
        "is_followed": false
      }
    ]
  }
}
```

**设计理由：** 所有筛选参数均可选，后端根据传参动态拼接 SQL；健康分默认升序（高风险优先）与产品需求一致。

### 5.2 供应商画像详情接口

```
GET /suppliers/{supplier_id}/profile
```

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "basic": {
      "id": 1001,
      "name": "某某半导体有限公司",
      "cooperation_status": "cooperating",
      "region": "广东省 深圳市",
      "is_china_top500": false,
      "supply_items": ["半导体", "座舱域控"]
    },
    "health": {
      "score": 32.5,
      "level": "high_risk",
      "snapshot_date": "2026-03-20",
      "dimension_scores": {
        "legal": 20.0,
        "finance": 45.0,
        "credit": 60.0,
        "tax": 80.0,
        "operation": 70.0
      },
      "report_url": "https://oss.example.com/reports/1001_20260320.pdf"
    },
    "risk_events": [
      {
        "id": 5001,
        "risk_dimension": "legal",
        "description": "存在未结清执行案件，涉案金额 300 万",
        "triggered_at": "2026-03-19T14:30:00Z",
        "source_url": "https://xxx"
      }
    ]
  }
}
```

### 5.3 风险看板统计接口

```
GET /dashboard/risk-overview
```

**响应示例：**

```json
{
  "code": 0,
  "data": {
    "summary": {
      "high_risk_count": 12,
      "attention_count": 35,
      "low_risk_count": 209,
      "avg_health_score": 72.4
    },
    "trend": [
      { "date": "2026-03-14", "avg_score": 74.1 },
      { "date": "2026-03-15", "avg_score": 73.8 }
    ],
    "top10_high_risk": [
      { "supplier_id": 1001, "name": "xxx", "health_score": 32.5 }
    ]
  }
}
```

### 5.4 风险预警中心列表接口

```
GET /risk-events
```

**请求参数：**

```json
{
  "date_from": "ISO8601 date string",
  "date_to": "ISO8601 date string",
  "risk_dimension": "string",
  "supplier_name": "string",
  "page": "integer",
  "page_size": "integer"
}
```

**响应：** 返回分页风险事项列表，含 `today_new_count`（今日新增数量）。

### 5.5 预警方案保存接口

```
POST /alert-plans
PUT  /alert-plans/{plan_id}
```

**请求体：**

```json
{
  "name": "供应商标准风险方案",
  "description": "适用于常规合作供应商",
  "scope_config": {
    "cooperation_status": ["cooperating", "qualified"],
    "listed_status": ["listed", "unlisted"]
  },
  "redline_indicators": [3, 7],
  "indicator_weights": [
    { "indicator_id": 1, "weight": 0.3 },
    { "indicator_id": 2, "weight": 0.7 }
  ],
  "level_thresholds": {
    "high_risk": [0, 40],
    "attention": [40, 70],
    "low_risk": [70, 100]
  }
}
```

**设计理由：** 权重配置在后端校验总和是否等于 1.0（浮点允许 ±0.001 误差），返回 400 错误信息提示前端。

---

## 6. 安全设计

### 6.1 认证（Authentication）

| 方案      | 说明                                                  | 选型理由                                                     |
| --------- | ----------------------------------------------------- | ------------------------------------------------------------ |
| SSO 对接  | 对接企业内部统一身份认证（如 LDAP / OAuth2 企业 IdP） | 避免单独维护账号体系，复用现有企业账号安全策略               |
| JWT Token | 登录后颁发 JWT（Access Token 2h + Refresh Token 7d）  | 无状态认证，减少 Redis 查询压力；短期 AT 降低 Token 泄露风险 |

### 6.2 授权（Authorization）

| 角色       | 权限说明                                     |
| ---------- | -------------------------------------------- |
| 超级管理员 | 全功能，含预警方案配置                       |
| 风险分析师 | 查看看板、预警中心、供应商画像；不可修改方案 |
| 只读用户   | 仅查看供应商列表与画像                       |

- 接口层使用 Spring Security + 注解 `@PreAuthorize` 做方法级鉴权
- 数据隔离：部分场景需按**业务单元**隔离数据，在 SQL 层加 `tenant_id / bu_id` 过滤

### 6.3 数据安全

| 措施             | 说明                                                                                  |
| ---------------- | ------------------------------------------------------------------------------------- |
| 传输加密         | 全链路 HTTPS（TLS 1.2+）                                                              |
| 敏感字段脱敏     | 法人姓名、联系方式等在接口响应中脱敏（后四位掩码）                                    |
| 外部接口密钥管理 | 第三方数据源 API Key 存储于密钥管理服务（Vault / 配置中心加密存储），不写入代码仓库   |
| 操作审计         | 关键操作（方案配置变更、手动标记风险等）写入审计日志表，含操作人、时间、变更内容 diff |

---

## 7. 性能设计

### 7.1 吞吐量与延迟目标

| 场景             | 目标                                                 |
| ---------------- | ---------------------------------------------------- |
| 供应商列表查询   | P95 ≤ 800ms（含筛选，数据量 ≤ 10,000 供应商）        |
| 供应商画像详情   | P95 ≤ 1s                                             |
| 风险看板统计     | P95 ≤ 500ms（缓存命中）                              |
| 风险预警推送延迟 | ≤ 5 分钟（从数据更新到企微通知到达）                 |
| 健康评分批量计算 | 10,000 供应商在 4 小时内完成（00:00 - 04:00 窗口期） |

### 7.2 缓存策略

| 缓存项                     | 存储                 | TTL     | 更新策略                  |
| -------------------------- | -------------------- | ------- | ------------------------- |
| 风险看板统计数据           | Redis Hash           | 10 分钟 | 定时刷新 + 主动失效       |
| 供应商健康分（当日）       | Redis String         | 24h     | 每日批量计算完成后写入    |
| 供应商列表（热门筛选组合） | Redis                | 5 分钟  | 短 TTL 自动过期，避免脏读 |
| 指标规则配置               | 应用内存（Caffeine） | 30 分钟 | 配置变更后发广播失效      |

**设计理由：** 看板统计与健康分是读多写少场景，缓存收益显著。供应商列表因筛选组合多，仅缓存高频组合，TTL 短避免数据不一致。

### 7.3 数据库优化

- **必要索引：** `supplier_health_snapshot(supplier_id, snapshot_date DESC)`、`risk_event(supplier_id, triggered_at DESC)`、`supplier(health_level, cooperation_status)`
- **分页优化：** 大数据量列表使用 Keyset 分页（游标分页）替代 OFFSET，避免深分页性能下降
- **批量计算分批处理：** 每批 500 条供应商，避免单事务过大；利用数据库连接池（HikariCP）控制并发

### 7.4 异步处理

- 健康评估报告生成（PDF）异步执行，前端轮询状态或 WebSocket 推送完成通知
- 预警通知推送通过 Kafka Consumer 异步消费，与评分计算解耦

---

## 8. 部署架构与环境规划

### 8.1 环境规划

| 环境            | 用途                   | 数据策略                      |
| --------------- | ---------------------- | ----------------------------- |
| 开发（Dev）     | 日常开发联调           | 脱敏样本数据，约 100 条供应商 |
| 测试（Test）    | QA 功能测试 / 接口测试 | 脱敏仿真数据，约 1,000 条     |
| 预发（Staging） | 上线前回归、压测       | 生产数据全量脱敏副本          |
| 生产（Prod）    | 正式运行               | 真实数据，严格权限控制        |

### 8.2 MVP 阶段部署架构

```
                        ┌─────────────────────────────┐
                        │         用户浏览器/客户端      │
                        └──────────────┬──────────────┘
                                       │ HTTPS
                        ┌──────────────▼──────────────┐
                        │         Nginx（反向代理）      │
                        │   静态资源 / SSL 终止 / 限流   │
                        └──────┬───────────┬──────────┘
                               │           │
              ┌────────────────▼──┐  ┌─────▼────────────────┐
              │  前端静态资源 CDN  │  │  后端 API 服务（x2）   │
              │   React Build     │  │  Spring Boot           │
              └───────────────────┘  └──────┬───┬────────────┘
                                            │   │
                  ┌─────────────────────────┘   └──────────────────┐
                  │                                                  │
        ┌─────────▼──────────┐                       ┌─────────────▼──────┐
        │    PostgreSQL       │                       │       Redis         │
        │  (主 + 只读副本)    │                       │  (缓存 + Session)   │
        └────────────────────┘                       └────────────────────┘
                  │
        ┌─────────▼──────────┐        ┌──────────────────────────────────┐
        │      Kafka          │        │   XXL-Job 调度中心                │
        │  (数据变更事件流)   │        │   (每日批量计算 / 定时同步任务)   │
        └────────────────────┘        └──────────────────────────────────┘
                  │
        ┌─────────▼──────────┐
        │  外部数据适配服务   │
        │  (工商/司法/信用)   │
        └────────────────────┘
```

**设计理由：** MVP 阶段使用 2 副本 API 服务，通过 Nginx 负载均衡，保障可用性；数据库主从分离，列表查询走只读副本，写入走主库，读写分离降低主库压力。后续增长可平滑扩展至 K8s。

### 8.3 容器化规划

- 各服务均提供 `Dockerfile`，通过 `docker-compose.yml` 管理本地开发环境
- 生产环境通过 CI/CD 流水线（Jenkins / GitLab CI）构建镜像，推送至私有镜像仓库
- 配置通过环境变量注入，敏感配置（DB 密码、API Key）走密钥管理服务

---

## 9. 风险点与 Mitigation 方案

| #   | 风险描述                            | 影响                                   | 可能性 | Mitigation 方案                                                                                                                    |
| --- | ----------------------------------- | -------------------------------------- | ------ | ---------------------------------------------------------------------------------------------------------------------------------- |
| R1  | 外部数据源 API 稳定性差 / 限流      | 供应商画像数据不完整，评分失准         | 高     | 1. 建立本地数据缓存（最近一次成功拉取结果）；2. 接入失败降级使用历史数据，评分页面展示数据时效；3. 监控 API 成功率，告警阈值 < 95% |
| R2  | 健康分批量计算超时（供应商量增长）  | 00:00 窗口期内计算未完成，当日数据延迟 | 中     | 1. 分批并行处理（可配置并发数）；2. 优先计算高风险供应商；3. 计算任务耗时监控，超过 3h 告警                                        |
| R3  | 预警推送噪音过高（误报）            | 用户忽视预警，平台信任度下降           | 中     | 1. 设置红线指标与常规指标分开推送策略；2. 相同风险事项 24h 内不重复推送（去重）；3. 支持用户自定义推送频率                         |
| R4  | 内部数据（ERP/SRM）同步延迟         | 合作状态等核心信息不实时               | 中     | 1. 明确与 ERP/SRM 系统的数据同步 SLA（如每日一次）；2. 前端展示数据更新时间，设置用户预期                                          |
| R5  | 权重配置错误导致评分异常            | 所有供应商评分偏高或偏低，看板失真     | 低     | 1. 方案保存时后端校验权重总和 = 100%；2. 方案启用前提供评分预览（基于现有数据模拟计算）；3. 方案变更记录历史版本，支持回退         |
| R6  | 多预警方案与同一供应商匹配冲突      | 同一供应商存在多份健康分，前端展示混乱 | 低     | 1. MVP 阶段约定同一时间只有一个"激活"方案；2. 后续支持多方案时，供应商画像展示主方案得分，其他方案可切换查看                       |
| R7  | 敏感数据泄露（供应商经营/司法信息） | 合规风险，供应商关系受损               | 低     | 1. 细粒度角色权限（司法/信用数据仅限指定角色）；2. 关键查询记入审计日志；3. 外部数据协议确认合法使用范围                           |

---

## 附录

### A. 待确认事项（评审前需明确）

1. 外部数据源具体供应商是哪家？接口协议与调用频次限制？
2. 内部 ERP/SRM 数据同步方式：实时 Webhook / 定时批量拉取？
3. 预警通知渠道：企业微信 / 钉钉 / 邮件，是否需要多渠道并行？
4. 健康评估报告 PDF 是否有模板设计要求？
5. 是否需要对接公司现有 SSO？IdP 类型？

### B. 里程碑建议

| 周次     | 交付物                                             |
| -------- | -------------------------------------------------- |
| Week 1-2 | 数据模型确认、外部数据源接入联调、内部数据同步完成 |
| Week 3-4 | 指标引擎 + 预警方案配置功能完成                    |
| Week 5-6 | 供应商列表 + 画像详情页完成                        |
| Week 7   | 风险看板 + 预警中心完成                            |
| Week 8   | 联调、压测、安全扫描、上线准备                     |

---

_本文档为技术方案大纲，详细设计（接口文档、ERD、压测报告）在各阶段评审后输出。_
