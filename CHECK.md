现在我已完整阅读文档，开始评审。以下是评审结果，先看总分概览，再逐维度展开。总分 7.3，低于 8 分，以下是四个维度的详细拆解和可落地改进点。

---

## 维度一：API 设计合理性 — 7.5 分

**得分理由：** 统一响应体、错误码分层、Base URL 版本化、接口文档完整度都做得好。扣分原因如下。

**改进点 1：`/report/generate` 动词路径违反 REST 原则**

当前设计 `POST /suppliers/{id}/report/generate` 把动词放在 URL 里。REST 的核心是资源而非动作，改法：

```
# 修改模块：第 5.4 节接口设计

# 当前（错误）
POST /suppliers/{id}/report/generate

# 改为：对 report 子资源进行 POST（创建一次生成任务）
POST /suppliers/{id}/reports

# 响应：
{
  "data": {
    "report_id": "rpt-20260320-1001",
    "status": "generating",
    "supplier_id": 1001
  }
}

# 查询报告状态（轮询用）
GET /suppliers/{id}/reports/latest
```

**改进点 2：缺少 API 版本演进策略**

文档声明 `Base URL: /api/v1`，但没有说明当字段需要 breaking change 时怎么办。需在第 5.1 节补充：

```markdown
### 版本兼容策略

- 新增字段：直接在当前版本添加（向后兼容），无需升版本
- 修改/删除字段：必须发布 /api/v2，旧版本保留至少 3 个月并在响应头返回：
  Deprecation: true
  Sunset: 2026-09-20
- 枚举值新增：向后兼容，客户端须容忍未知枚举值（ignore-unknown 原则）
```

**改进点 3：供应商列表接口缺少 cursor 分页参数**

文档第 7.3 节提到了 Keyset 分页，但第 5.2 节的接口定义仍然只有 `page` + `page_size`，两者矛盾。需在 5.2 节接口入参中补充游标字段并明确切换规则：

```markdown
# 修改模块：第 5.2 节请求参数表

新增参数：
| cursor | string | 否 | 游标值（上一页最后一条的 encoded key），有 cursor 时忽略 page |

响应新增字段：
| next_cursor | string | 下一页游标，null 表示已是最后页 |

切换规则：cursor 参数存在时使用 Keyset 分页；否则降级为 OFFSET（仅限 page ≤ 20）
```

---

## 维度二：数据模型合理性 — 7.0 分

**改进点 1：`supplier` 表的复合索引引用了不存在的字段**

第 7.3 节有这行 SQL：

```sql
-- 当前（错误）：health_level_cache 在 supplier 表 DDL 中根本不存在
CREATE INDEX idx_supplier_composite ON supplier(cooperation_status, health_level_cache, listed_status);
```

`health_level` 存在于 `supplier_health_snapshot` 表，不在 `supplier` 主表。这个索引会直接建失败。有两种修复路径，选其一：

```sql
-- 方案 A：在 supplier 表新增冗余缓存字段（以空间换查询便利）
ALTER TABLE supplier ADD COLUMN health_level_cache VARCHAR(20);
ALTER TABLE supplier ADD COLUMN health_score_cache DECIMAL(5,2);
-- 由每日批量计算完成后回写，并加注明"非规范化冗余字段，来源为最新快照"

-- 方案 B：删除该复合索引，列表查询改为 JOIN snapshot 子查询 + 各字段独立索引
-- 适合数据量 < 5 万的 MVP 阶段
```

**改进点 2：`alert_plan` 表的 `indicator_weights` 应独立成关联表**

当前设计把权重配置全压进 JSONB：

```json
indicator_weights: [{"indicator_id": 1, "weight": 0.30}]
```

这意味着：无法在数据库层约束 `SUM(weight) = 1.0`；无法通过 FK 保证 `indicator_id` 合法；无法直接 SQL 查询"某个指标被哪些方案引用"。修改：

```sql
-- 修改模块：第 4.2 节数据模型，新增关联表

CREATE TABLE alert_plan_indicator (
    id           BIGSERIAL PRIMARY KEY,
    plan_id      BIGINT        NOT NULL REFERENCES alert_plan(id) ON DELETE CASCADE,
    indicator_id BIGINT        NOT NULL REFERENCES indicator(id),
    weight       DECIMAL(5,4)  NOT NULL CHECK (weight > 0 AND weight <= 1),
    is_redline   BOOLEAN       NOT NULL DEFAULT FALSE,
    UNIQUE (plan_id, indicator_id)
);

-- DB 层触发器或应用层校验 SUM(weight) = 1.0 per plan_id
-- alert_plan 表删除 indicator_weights 和 redline_indicators 两个 JSONB 字段
```

**改进点 3：`risk_event` 缺少状态流转字段**

产品方案要求风险管控闭环，但 `risk_event` 表只有 `is_notified` 布尔字段，没有处理状态。无法支持"已确认/处理中/已关闭"的闭环流程：

```sql
-- 修改模块：第 4.2 节 risk_event 表，新增字段

ALTER TABLE risk_event ADD COLUMN status VARCHAR(20) NOT NULL DEFAULT 'open';
-- 枚举值: open（待处理）/ confirmed（已确认）/ processing（处理中）/ closed（已关闭）/ dismissed（已忽略）

ALTER TABLE risk_event ADD COLUMN assignee_id BIGINT;       -- 负责人
ALTER TABLE risk_event ADD COLUMN closed_at TIMESTAMPTZ;    -- 关闭时间
ALTER TABLE risk_event ADD COLUMN close_note TEXT;          -- 处理备注

CREATE INDEX idx_risk_event_status ON risk_event(status, triggered_at DESC);
```

---

## 维度三：安全性 — 7.5 分

**改进点 1：`report_url` 直接暴露 OSS URL，存在未授权访问风险**

第 5.3 节响应中 `report_url` 返回的是 MinIO 直链：

```json
"report_url": "https://oss.example.com/reports/1001_20260320.pdf"
```

这条 URL 一旦泄露（日志、浏览器历史、分享粘贴），任何人都能访问。两种解法：

```markdown
# 修改模块：第 5.3 节和第 6.3 节安全设计

方案 A（推荐）：预签名 URL（Presigned URL），由后端按需生成，TTL 15 分钟

- 接口不直接返回 report_url
- 新增接口：GET /suppliers/{id}/reports/latest/download-url
  → 返回 { "url": "https://oss.../...?X-Amz-Signature=...&Expires=...", "expires_at": "..." }
- 前端每次下载前调此接口获取临时 URL

方案 B：代理下载，后端鉴权后转发流

- GET /suppliers/{id}/reports/latest/download（需 RISK_ANALYST 角色）
- 后端从 MinIO 读取后以 application/octet-stream 流式响应
- 优点：完全受控；缺点：占用 API 服务带宽
```

**改进点 2：补充 SQL 注入防护的具体实现说明**

第 6.3 节仅提到"使用 MyBatis/JPA 参数化查询"，但供应商列表接口有大量动态筛选条件，风险更高。需在技术方案中明确：

```markdown
# 修改模块：第 6.3 节安全设计，新增"动态查询安全"小节

动态 SQL 安全规范：

1. MyBatis 动态 SQL 只允许使用 #{param}（预编译），禁止 ${param}（字符串拼接）
2. sort_by 参数不允许直接拼入 ORDER BY，必须使用白名单映射：
   允许值: health_score, name, created_at → 对应实际列名的 Map
   其他值: 直接返回 400，不执行查询
3. supply_items 数组筛选使用 JSONB 操作符 @>，不拼 IN 子句
4. 关键字搜索使用 pg_trgm + GIN 索引，禁止前缀通配 LIKE '%keyword%'
```

**改进点 3：API 限流补充用户级别的细粒度控制**

第 6.3 节仅提到 Nginx 全局 200 req/s 和单用户 20 req/s，但对关键写操作没有专门保护：

```markdown
# 修改模块：第 6.3 节安全设计，限流配置补充

| 接口类型                                 | 限流规则                                 | 实现层                 |
| ---------------------------------------- | ---------------------------------------- | ---------------------- |
| 全局 API                                 | 200 req/s（IP 级）                       | Nginx                  |
| 普通查询接口                             | 20 req/s / 用户                          | Spring（Token Bucket） |
| POST /alert-plans（方案创建）            | 5 req/min / 用户                         | Spring                 |
| POST /suppliers/{id}/reports（报告触发） | 1 req/5min / supplier_id                 | Redis + Lua 原子计数   |
| POST /auth/token（登录）                 | 10 req/min / IP，连续失败 5 次锁定 15min | Nginx + Redis          |
```

---

## 维度四：性能设计 — 7.0 分

**改进点 1：画像详情接口一次返回所有数据，应改为 Tab 懒加载**

第 5.3 节 `GET /suppliers/{id}/profile` 的响应包含基础信息 + 健康评分 + 风险事项，但 Tab 内容（司法、信用、税务等）实际来自 5 个不同外部数据源，合并在一个接口里意味着**最慢的那个 Tab 决定整个接口的响应时间**：

```markdown
# 修改模块：第 5.3 节接口设计，拆分为主接口 + Tab 懒加载

主接口（首屏必需数据，P95 ≤ 500ms）：
GET /suppliers/{id}/profile
返回：basic + health（评分卡） + risk_events（前 5 条）

Tab 懒加载接口（用户切 Tab 时触发，各自独立超时）：
GET /suppliers/{id}/tabs/basic-info → ERP 基本信息
GET /suppliers/{id}/tabs/business-info → 工商经营信息
GET /suppliers/{id}/tabs/judicial → 司法诉讼
GET /suppliers/{id}/tabs/credit → 信用数据
GET /suppliers/{id}/tabs/tax → 税务信息

每个 Tab 接口：

- 有独立的缓存策略（TTL 与该数据源刷新频率对齐）
- 有独立的降级策略（该数据源不可用时返回上次成功数据 + 数据时效标签）
- 超时设置：连接 3s + 读取 10s，超时返回 503 而不阻塞主页面
```

**改进点 2：补充线程池和数据库连接池的具体参数**

第 7.4 节只说"固定线程池（核心线程数 = CPU 核数 × 2）"，没有其他参数。这在生产环境中不够：

```markdown
# 修改模块：第 7.4 节性能设计，批量计算配置补充

# 批量评分专用线程池（与 API 线程池隔离，防止计算任务抢占 API 请求资源）

scoring-executor:
core-pool-size: ${CPU_CORES _ 2} # 假设 4 核 = 8
max-pool-size: ${CPU_CORES _ 4} # 最大 16，防止 OOM
queue-capacity: 200 # 超出时 CallerRunsPolicy（背压）
thread-name-prefix: scoring-worker-
keep-alive-seconds: 60

# HikariCP 连接池（与 API 服务共用时需要隔离配置）

datasource:
hikari:
maximum-pool-size: 20 # API 服务连接数上限
minimum-idle: 5
connection-timeout: 3000 # 3s 获取不到连接直接报错（不排队）
idle-timeout: 600000 # 10min 空闲连接回收

# 批量引擎使用独立数据源，maximum-pool-size: 10（写主库）
```

**改进点 3：`week_trend` 字段每次查询都需要聚合计算，应预计算**

第 5.2 节列表接口返回 `week_trend`（近 7 天健康分变化量），但这个字段需要从 `supplier_health_snapshot` 中查近 7 条记录再计算差值。对 10,000 供应商的列表来说，这是一个 N+1 查询隐患：

```markdown
# 修改模块：第 4.2 节 supplier 表 DDL + 第 7.3 节数据库优化

# 方案：将 week_trend 与 health_level_cache 一起作为冗余字段写回 supplier 表

# 由每日批量计算任务在写完 snapshot 后顺带回写

ALTER TABLE supplier ADD COLUMN health_score_cache DECIMAL(5,2);
ALTER TABLE supplier ADD COLUMN health_level_cache VARCHAR(20);
ALTER TABLE supplier ADD COLUMN week_trend_cache DECIMAL(5,2);
ALTER TABLE supplier ADD COLUMN cache_updated_at TIMESTAMPTZ;

-- 列表查询直接读 supplier 表，无需 JOIN snapshot 表
-- 代价：冗余字段，更新时需事务保证一致性（在批量计算的最后 commit 阶段写入）
```

---

**优先处理顺序建议（按风险高低）：**

1. 数据模型 → 修复复合索引引用不存在字段（会导致 Flyway 迁移直接失败）
2. 安全 → `report_url` 改为预签名 URL（上线前必须）
3. 数据模型 → `alert_plan_indicator` 关联表替换 JSONB（影响方案配置核心逻辑的正确性）
4. 性能 → 画像详情 Tab 懒加载拆分（影响首屏体验）
5. 其余改进点可在 P4–P6 阶段迭代处理
