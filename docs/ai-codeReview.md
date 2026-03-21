Now I have all the information. Let me generate the structured code review report.

---

# CodeReview 报告 — 供应链风险管理平台 (SCRM)

> 审查范围：后端 Java 17 + Spring Boot 3.2.1 | 前端 React 18 + TypeScript 5.x
> 对标文档：TECH_SPEC.md v2.0 + CLAUDE.md v1.0
> 审查日期：2026-03-21

---

## 一、安全维度

### SEC-01 | 严重 | RBAC 权限体系未实现

- **位置**: `SecurityConfig.java:48`
- **描述**: `anyRequest().permitAll()` 放行全部接口，TECH_SPEC 6.1 节要求三角色 RBAC（Super Admin / Risk Analyst / Read-Only）。当前所有接口（包括关注切换 `PATCH /follow`、报告下载）完全无鉴权。
- **修复建议**:
  1. 实现 `JwtAuthenticationFilter extends OncePerRequestFilter`，从 Authorization Header 解析 JWT，注入 `SecurityContext`
  2. 将 `.anyRequest().permitAll()` 改为 `.anyRequest().authenticated()`
  3. Controller 方法加 `@PreAuthorize("hasRole('RISK_ANALYST')")` 等注解
  4. 补充角色枚举 `RoleEnum { SUPER_ADMIN, RISK_ANALYST, READ_ONLY }`

### SEC-02 | 严重 | 接口限流缺失

- **位置**: 全局（无 RateLimiter 实现）
- **描述**: TECH_SPEC 6.4 节要求接口限流（如列表查询 30 req/min/user），当前无任何限流机制，遭遇爬虫或恶意调用时可导致数据库压力过大。
- **修复建议**: 引入 `spring-boot-starter-data-redis` 的 `RedisTemplate` 实现滑动窗口限流 Filter，或使用 `resilience4j-ratelimiter`；在 `WebMvcConfig` 注册限流 Filter，关键接口（列表/Tab/评分触发）单独配置阈值。

### SEC-03 | 中等 | CursorUtil.decode 异常未转换为业务异常

- **位置**: `CursorUtil.java:59` → `SupplierServiceImpl.java:255`
- **描述**: `CursorUtil.decode()` 抛出 `IllegalArgumentException`，但 `GlobalExceptionHandler` 无此异常的处理器。恶意传入非法 cursor 值将触发 500 错误，暴露服务端堆栈信息。
- **修复建议**: 在 `buildListParams` 中 catch `IllegalArgumentException` 并转为 `ApiException(ResultCode.PARAM_INVALID, "游标格式错误")`，或在 `GlobalExceptionHandler` 增加 `IllegalArgumentException` 处理。

### SEC-04 | 中等 | toggleFollow 接口 RequestBody 使用 Map 类型

- **位置**: `SupplierController.java:130`
- **描述**: `@RequestBody @Valid Map<String, Boolean> body` 无法有效做 `@Valid` 校验（Map 上的 Bean Validation 无意义），且接受任意 key-value，不符合 TECH_SPEC 接口定义。`@Valid` 注解在 `Map` 上不生效。
- **修复建议**: 定义 `ToggleFollowRequest` record：
  ```java
  public record ToggleFollowRequest(
      @NotNull(message = "is_followed 不能为空")
      @JsonProperty("is_followed")
      Boolean isFollowed
  ) {}
  ```

### SEC-05 | 低 | 报告下载 URL 预签名安全未实现

- **位置**: TECH_SPEC 5.10 节 vs 当前代码
- **描述**: TECH_SPEC 要求 MinIO presigned URL（TTL 15 分钟），当前仅有前端 `fetchReportDownloadUrl` API 函数，后端缺少对应 Controller/Service 实现。一旦补全需确保 presigned URL 的 TTL 和权限校验。
- **修复建议**: 实现 `ReportController.getDownloadUrl()`，调用 MinIO SDK `presignedGetObject(bucket, objectName, 15*60)` 生成短期 URL。

### SEC-06 | 低 | RequestLogFilter 未脱敏 query string

- **位置**: `RequestLogFilter.java`（探索报告中提到记录 query string）
- **描述**: TECH_SPEC 6.3 节和 CLAUDE.md 8.5 节要求对外 HTTP 接口的请求日志中敏感字段脱敏。当前 RequestLogFilter 直接打印 URI + query string，若后续接口含 token/password 参数会泄露敏感信息。
- **修复建议**: 添加敏感参数名黑名单（password, token, secret, key），对匹配参数值做掩码处理（如 `***`）。

---

## 二、性能维度

### PERF-01 | 严重 | Caffeine 二级缓存未在 Service 层使用

- **位置**: `CaffeineConfig.java` vs `SupplierServiceImpl.java`
- **描述**: TECH_SPEC 7.2 节要求 Caffeine + Redis 二级缓存策略。`CaffeineConfig` 已配置（30min TTL, 500 entries），但 `SupplierServiceImpl` 仅使用 Redis 缓存 Tab 数据，未使用 `@Cacheable` 注解或手动 Caffeine 缓存任何热数据（如指标配置、预警方案）。
- **修复建议**: 对高频读取的供应商 Profile 和 Tab 数据添加本地缓存层。示例：
  ```java
  @Cacheable(value = "supplierTab", key = "#supplierId + ':' + #tabName")
  public SupplierTabResponse getTabData(Long supplierId, String tabName) { ... }
  ```
  或者手动在 Redis 之前先查 Caffeine，形成 L1(Caffeine) → L2(Redis) → DB 三级查询链路。

### PERF-02 | 中等 | 列表查询同时执行 COUNT + SELECT

- **位置**: `SupplierServiceImpl.java:93-95`
- **描述**: 每次列表查询都执行 `countSupplierList` + `selectSupplierList` 两次 SQL。当使用游标分页时，total 值对用户意义有限（数据实时变化），且 COUNT 在大表上开销显著。
- **修复建议**: 游标分页模式下可跳过 COUNT 查询，仅在第一页（offset 分页）时返回 total。或异步缓存 total 值（Redis TTL 5min）。

### PERF-03 | 中等 | Tab 缓存未做缓存穿透保护

- **位置**: `SupplierServiceImpl.java:154-175`
- **描述**: 当 `ext_data` 为 null 时，每次请求都会穿透 Redis 到数据库查询，再写入空 `Map.of()` 到 Redis。虽然写入了缓存，但 `Map.of()` 作为 value 序列化后可能在反序列化时与 null 判断逻辑不一致。
- **修复建议**: 对空值结果使用特殊标记缓存（如 `{"_empty": true}`），或使用布隆过滤器防止不存在的 supplierId 穿透。

### PERF-04 | 低 | `selectProfileById` 缺少覆盖索引

- **位置**: `SupplierMapper.xml:102-126` + `V1__init_schema.sql`
- **描述**: 画像查询 `selectProfileById` 需要全字段返回（含 `ext_data` JSONB），通过主键查询效率可接受。但 `ext_data` 字段可能很大，每次 Tab 查询也加载全部供应商字段（`selectProfileById`）。
- **修复建议**: 为 Tab 场景新增一个只查 `ext_data` 的 SQL：`SELECT ext_data FROM supplier WHERE id = #{id}`，减少 IO 开销。

### PERF-05 | 低 | ORDER BY 使用 `${}` 拼接存在性能隐患

- **位置**: `SupplierMapper.xml:87`
- **描述**: `ORDER BY ${params.sortColumn} ${params.sortDirection}` 使用 `${}` 直接拼接。虽然通过白名单保证了安全性，但 `${}` 会导致 MyBatis 为每种 sortColumn + sortDirection 组合生成不同的 PreparedStatement，降低语句缓存命中率。
- **修复建议**: 由于 ORDER BY 列名和方向无法参数化，当前做法已是 MyBatis 下的最佳实践。可通过限制排序组合数量（当前 3×2=6 种）确保 PS 缓存可控。标记为可接受。

---

## 三、规范维度

### STD-01 | 中等 | 包结构不符合 CLAUDE.md 规范

- **位置**: `com.supply.risk.*` vs CLAUDE.md 2.1 节要求 `com.company.scrm.*`
- **描述**: CLAUDE.md 定义包名为 `com.company.scrm.supplier.controller` 等，实际代码使用 `com.supply.risk.controller`。缺少按业务域划分的子包（如 `supplier/`、`alertplan/`），所有 Controller/Service/Mapper 平铺在 `controller/`、`service/`、`mapper/` 下。
- **修复建议**: 如团队已确认使用 `com.supply.risk` 包名，需更新 CLAUDE.md 保持一致。但建议按模块划分子包：`com.supply.risk.supplier.controller`、`com.supply.risk.supplier.service` 等。

### STD-02 | 中等 | ApiException HTTP 状态码统一返回 200

- **位置**: `GlobalExceptionHandler.java:40-41`
- **描述**: `handleApiException` 使用 `@ResponseStatus(HttpStatus.OK)` — 所有业务异常（包括 404 NOT_FOUND、403 FORBIDDEN）HTTP 状态码均为 200，仅通过 body 中的 code 字段区分。这不符合 RESTful 最佳实践，也使前端 axios 拦截器需额外判断。
- **修复建议**: 根据 `ApiException.getCode()` 映射到对应 HTTP 状态码。建议在 `ResultCode` 中增加 `httpStatus` 字段：
  ```java
  NOT_FOUND(404001, "资源不存在", HttpStatus.NOT_FOUND)
  ```
  然后在 `handleApiException` 中动态设置 `response.setStatus()`。

### STD-03 | 中等 | SupplierListQuery record 上的 @Min/@Max 注解未生效

- **位置**: `SupplierListQuery.java:43-48` + `SupplierController.java:77-78`
- **描述**: record 参数上的 `@Min`/`@Max` 注解需要在 Controller 层通过 `@Valid` 触发。但 `listSuppliers` 方法中 `SupplierListQuery` 是手动 new 出来的（非 `@RequestBody` 也非 `@Valid` 参数），这些注解实际不会生效。Controller 层的 `@Min(1) @Max(100)` 在 `@RequestParam` 上生效（通过 `@Validated`），但 record 内部的冗余注解可能误导。
- **修复建议**: 移除 `SupplierListQuery` record 上的 `@Min`/`@Max` 注解（验证在 Controller 的 `@RequestParam` 上已完成），或改为在 `validateListQuery` 中显式校验。

### STD-04 | 低 | Service 接口未按 CLAUDE.md 使用 I 前缀

- **位置**: `SupplierService.java`
- **描述**: CLAUDE.md 1.2 节要求接口名使用 `I` 前缀（如 `ISupplierService`），但实际命名为 `SupplierService`。
- **修复建议**: 如团队采用 Spring 生态惯例（不加 I 前缀），需更新 CLAUDE.md。否则重命名接口。

### STD-05 | 低 | 缺少 OpenAPI 注解

- **位置**: `SupplierController.java` 全部方法
- **描述**: CLAUDE.md 6.2 条第 8 项要求所有新增 API 接口必须有 `@Operation`、`@ApiResponse` 注解。当前 Controller 仅有 Javadoc，无 Swagger/OpenAPI 注解，且 `pom.xml` 未引入 `springdoc-openapi` 依赖。
- **修复建议**: 添加 `springdoc-openapi-starter-webmvc-ui` 依赖，在 Controller 方法上补充 `@Operation(summary="...")` 和 `@ApiResponse(responseCode="200", ...)` 注解。

### STD-06 | 低 | 前端缺少 store/ 目录和 authStore

- **位置**: `services/frontend/src/` vs CLAUDE.md 2.2 节
- **描述**: CLAUDE.md 2.2 节定义 `store/authStore.ts` 使用 Zustand 管理全局状态，实际代码中无 `store/` 目录，认证 token 直接挂在 `window.__ACCESS_TOKEN__` 上。
- **修复建议**: 实现 `authStore.ts` 管理 token 刷新逻辑和用户信息，使用 Zustand 替代 `window` 全局变量。

---

## 四、业务维度

### BIZ-01 | 严重 | 健康分计算引擎未实现

- **位置**: 全局（缺少 `HealthScoringService`）
- **描述**: TECH_SPEC 5.7-5.8 节定义的核心业务——健康分计算公式 `100 - Σ(指标得分 × 权重)` + 红线归零规则，当前代码中完全缺失。仅有 `SupplierHealthSnapshot` 实体和读取逻辑，无评分写入逻辑。`ThreadPoolConfig` 配置了 `scoringExecutor` 线程池，但无任何评分 Service 使用它。
- **修复建议**: 实现 `HealthScoringService`，核心逻辑：
  1. 加载方案指标配置（含红线标记）
  2. 遍历指标计算得分
  3. 如任一红线指标触发 → 总分归零，健康等级 `high_risk`
  4. 否则 `score = 100 - Σ(indicator_score × weight)`
  5. 按阈值划分等级：[0,40)→high_risk, [40,70)→attention, [70,100]→low_risk
  6. 持久化 `SupplierHealthSnapshot`，更新 supplier 缓存字段

### BIZ-02 | 严重 | 风险事项状态机未实现

- **位置**: 全局（缺少 `RiskEventService`）
- **描述**: TECH_SPEC 5.5 节定义的风险事项状态机（open → confirmed → processing → closed/dismissed）完全缺失。当前仅有 `RiskEvent` 实体和读取 Mapper，无状态流转接口。
- **修复建议**: 实现 `RiskEventService` 含 `transitionStatus(eventId, targetStatus)` 方法，内含状态流转校验：
  ```
  ALLOWED_TRANSITIONS = {
      open -> [confirmed, dismissed],
      confirmed -> [processing, dismissed],
      processing -> [closed, dismissed],
  }
  ```
  非法转换抛出 `ApiException(ResultCode.STATUS_TRANSITION_INVALID)`。

### BIZ-03 | 中等 | 预警方案模块完全缺失

- **位置**: 全局
- **描述**: TECH_SPEC 5.6 节定义了预警方案 CRUD 接口（创建/编辑/激活/停用），含指标权重配置和权重总和校验（必须 = 100%）。当前仅有数据库表和种子数据，无 Controller/Service/Mapper 实现。
- **修复建议**: 按 TECH_SPEC 实现 `AlertPlanController` + `AlertPlanService`，重点实现权重总和校验逻辑（`WEIGHT_SUM_INVALID(400010)`）。

### BIZ-04 | 中等 | 游标分页仅支持 health_score 排序

- **位置**: `SupplierMapper.xml:55-67` + `SupplierServiceImpl.java:253-262`
- **描述**: 游标条件硬编码为 `health_score_cache` 字段（`cursorScore`/`cursorScoreDesc`），但 `SORT_FIELD_MAP` 支持 3 种排序（health_score/name/created_at）。当用户选择 `sort_by=name` 或 `sort_by=created_at` 时使用游标分页，游标条件仍基于 score 比较，将返回错误结果。
- **修复建议**: 游标编码需包含当前排序字段的值，游标 SQL 条件也需动态适配排序字段。或者简化为：仅在 `sort_by=health_score` 时支持游标分页，其他排序仅支持 offset 分页。

### BIZ-05 | 中等 | 看板（Dashboard）模块缺失

- **位置**: 全局
- **描述**: TECH_SPEC 5.11 节定义的风险看板接口（统计各等级供应商数、趋势、Top N 高风险供应商）完全缺失。前端路由中也无 Dashboard 页面组件。CLAUDE.md 2.1 节列出了 `dashboard/` 目录。
- **修复建议**: 按 TECH_SPEC 实现 Dashboard 统计接口，建议使用 Redis 缓存统计数据（TTL 10min），避免实时聚合查询。

### BIZ-06 | 低 | Tab 数据 dataAsOf 始终为当前时间

- **位置**: `SupplierServiceImpl.java:161, 178`
- **描述**: `SupplierTabResponse` 中的 `dataAsOf` 字段始终使用 `OffsetDateTime.now()`，无论数据来自缓存还是数据库。TECH_SPEC 要求该字段反映数据的实际采集时间。
- **修复建议**: 在缓存 value 中存入 `fetchedAt` 时间戳，缓存命中时从缓存中取出。数据库查询时使用供应商的 `cache_updated_at` 字段。

### BIZ-07 | 低 | 前端 source_url 未做 XSS 防护

- **位置**: `SupplierProfile/index.tsx:147`
- **描述**: `<a href={url} target="_blank">` 直接渲染后端返回的 `source_url`。如果攻击者在 `source_url` 中注入 `javascript:` 协议 URL，可触发 XSS。
- **修复建议**: 添加 URL 协议白名单校验：
  ```typescript
  const isSafeUrl = (url: string) => /^https?:\/\//i.test(url);
  {isSafeUrl(url) ? <a href={url} ...>查看</a> : '-'}
  ```

---

## 汇总统计

| 维度     | 严重  | 中等   | 低    |
| -------- | ----- | ------ | ----- |
| 安全     | 2     | 2      | 2     |
| 性能     | 1     | 2      | 2     |
| 规范     | 0     | 3      | 3     |
| 业务     | 2     | 3      | 2     |
| **合计** | **5** | **10** | **9** |

## 优先修复路径

1. **P0（阻断上线）**: SEC-01 RBAC 权限 → BIZ-01 健康分引擎 → BIZ-02 状态机 → SEC-02 限流
2. **P1（Sprint 内）**: SEC-03 游标异常 → SEC-04 DTO 类型化 → PERF-01 二级缓存 → BIZ-04 游标多排序 → STD-02 HTTP 状态码
3. **P2（后续迭代）**: BIZ-03 预警方案 → BIZ-05 看板 → STD-05 OpenAPI → 其余低等级项
