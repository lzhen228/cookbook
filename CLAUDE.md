# CLAUDE.md — 供应链风险管理平台项目规约

> 本文件是所有开发行为和 AI 辅助生成代码的约束基础。
> **所有人（含 AI）在修改代码前必须先读本文件。**
> 如需变更规约，须经 Tech Lead 审批并更新本文件。

---

## 目录

1. [代码规范](#1-代码规范)
2. [目录结构规范](#2-目录结构规范)
3. [Git 工作流与提交规范](#3-git-工作流与提交规范)
4. [环境变量与配置管理](#4-环境变量与配置管理)
5. [依赖管理规则](#5-依赖管理规则)
6. [架构约束](#6-架构约束)
7. [测试规范](#7-测试规范)
8. [部署规范](#8-部署规范)

---

## 1. 代码规范

### 1.1 语言与版本

| 层 | 语言 | 版本 | 备注 |
|----|------|------|------|
| 后端 | Java | 17 LTS | 不允许使用 Java 8/11 特性外的 deprecated API |
| 前端 | TypeScript | 5.x | 禁止使用 `any`，使用 `unknown` 替代 |
| 脚本 | Shell / Python | bash / 3.11+ | 仅用于 CI/CD 和运维脚本 |
| 数据库迁移 | SQL | PostgreSQL 15 方言 | 通过 Flyway 管理，不允许手写 DDL 直接执行 |

### 1.2 后端命名规范

```
类名:          PascalCase          SupplierHealthService
接口名:        PascalCase + I 前缀  IExternalDataAdapter
方法名:        camelCase           calculateHealthScore()
变量名:        camelCase           healthScore
常量名:        UPPER_SNAKE_CASE    MAX_BATCH_SIZE
包名:          全小写，点分隔       com.company.scrm.supplier
数据库表名:    snake_case          supplier_health_snapshot
数据库字段名:  snake_case          health_score
Kafka Topic:   kebab-case          supplier.data.updated
Redis Key:     冒号分隔层级        supplier:health:{id}
```

### 1.3 前端命名规范

```
组件文件名:    PascalCase          SupplierProfile.tsx
Hook 文件名:   use 前缀            useSupplierList.ts
工具函数文件:  camelCase           formatHealthScore.ts
样式文件:      与组件同名          SupplierProfile.module.css
常量文件:      UPPER_SNAKE_CASE    API_ENDPOINTS.ts
类型文件:      types.ts 或内联     supplier.types.ts
Props 类型名:  组件名 + Props      SupplierProfileProps
```

### 1.4 后端代码格式

- 使用 **Google Java Style Guide**，通过 `google-java-format` 强制格式化
- 缩进：**2 空格**（不使用 Tab）
- 单行最大字符数：**120 字符**
- 每个类最多 **300 行**；超过须拆分
- 每个方法最多 **50 行**；超过须重构
- 方法圈复杂度不超过 **10**
- 所有 `public` 方法必须有 Javadoc 注释，描述功能、参数、返回值、异常
- 禁止注释掉的代码存在于主干分支（用 git 管理历史，不留僵尸代码）

```java
// ✅ 正确：方法级 Javadoc
/**
 * 计算指定供应商的综合健康分。
 *
 * @param supplierId 供应商 ID
 * @param planId     使用的预警方案 ID
 * @return 健康分快照，若供应商不存在则抛出 SupplierNotFoundException
 */
public HealthSnapshot calculateScore(Long supplierId, Long planId) { ... }

// ❌ 错误：无注释的 public 方法
public HealthSnapshot calculateScore(Long supplierId, Long planId) { ... }
```

### 1.5 前端代码格式

- 使用 **ESLint + Prettier**，配置文件已入仓，不允许个人覆盖
- 缩进：**2 空格**
- 单行最大字符数：**100 字符**
- 所有组件使用**函数式组件 + Hooks**，禁止 Class Component
- Props 必须声明类型，禁止 `React.FC<any>`
- 异步操作统一使用 **React Query**，禁止在组件内直接裸 `fetch`/`axios`

```typescript
// ✅ 正确
interface SupplierCardProps {
  supplierId: number;
  onSelect: (id: number) => void;
}
export function SupplierCard({ supplierId, onSelect }: SupplierCardProps) { ... }

// ❌ 错误
export const SupplierCard: React.FC<any> = (props) => { ... }
```

### 1.6 SQL 规范

- 所有 SQL 关键字**大写**：`SELECT`, `FROM`, `WHERE`, `JOIN`
- 表别名必须有意义：`supplier s`，不允许 `a`, `b`, `t1`
- 禁止 `SELECT *`，必须显式列出字段
- 多表 JOIN 超过 3 张时必须加注释说明业务含义
- 所有查询必须有 `LIMIT` 或分页，防止全表扫描返回前端

```sql
-- ✅ 正确
SELECT
    s.id,
    s.name,
    shs.health_score,
    shs.health_level
FROM supplier s
INNER JOIN supplier_health_snapshot shs
    ON shs.supplier_id = s.id
    AND shs.snapshot_date = CURRENT_DATE
WHERE s.cooperation_status = 'cooperating'
ORDER BY shs.health_score ASC
LIMIT :pageSize OFFSET :offset;
```

---

## 2. 目录结构规范

### 2.1 后端目录结构

```
services/api/
├── src/
│   ├── main/
│   │   ├── java/com/company/scrm/
│   │   │   ├── ScrApplication.java          # 启动类，无业务逻辑
│   │   │   ├── common/                      # 跨模块公共代码
│   │   │   │   ├── config/                  # Spring 配置类
│   │   │   │   ├── exception/               # 全局异常定义与处理
│   │   │   │   ├── response/                # 统一响应体 ApiResponse<T>
│   │   │   │   └── util/                    # 纯工具类（无 Spring 依赖）
│   │   │   ├── supplier/                    # 供应商模块（按业务域划分）
│   │   │   │   ├── controller/              # REST 控制器，只做参数校验和响应组装
│   │   │   │   ├── service/                 # 业务逻辑，接口 + 实现分离
│   │   │   │   │   ├── SupplierService.java
│   │   │   │   │   └── impl/
│   │   │   │   ├── repository/              # 数据访问层（MyBatis Mapper / JPA Repository）
│   │   │   │   ├── domain/                  # 实体类 (Entity) 和值对象 (VO)
│   │   │   │   ├── dto/                     # 请求/响应 DTO，不与 Entity 共用
│   │   │   │   └── event/                   # 领域事件定义
│   │   │   ├── alertplan/                   # 预警方案模块
│   │   │   ├── indicator/                   # 指标模块
│   │   │   ├── dashboard/                   # 看板模块
│   │   │   └── notification/                # 通知模块
│   │   └── resources/
│   │       ├── application.yml              # 基础配置（不含密钥）
│   │       ├── application-dev.yml
│   │       ├── application-test.yml
│   │       ├── application-prod.yml
│   │       ├── mapper/                      # MyBatis XML（若使用）
│   │       └── db/migration/                # Flyway 迁移脚本
│   │           ├── V1__init_schema.sql
│   │           └── V2__add_audit_log.sql
│   └── test/
│       └── java/com/company/scrm/
│           ├── supplier/                    # 与 main 结构镜像
│           └── integration/                 # 集成测试单独目录
├── pom.xml
└── Dockerfile
```

**禁止行为：**
- 禁止在 `controller` 层写业务逻辑
- 禁止在 `domain/entity` 中引用 `dto`
- 禁止在 `repository` 层调用其他模块的 `service`
- 禁止在 `util` 类中注入 Spring Bean（工具类必须是静态方法）

### 2.2 前端目录结构

```
services/frontend/
├── src/
│   ├── main.tsx                             # 入口，只做挂载
│   ├── App.tsx                              # 路由根组件
│   ├── api/                                 # 所有 API 请求函数
│   │   ├── supplier.ts                      # 供应商相关接口
│   │   ├── alertPlan.ts
│   │   └── client.ts                        # axios 实例配置（拦截器等）
│   ├── components/                          # 纯 UI 组件（无业务逻辑，可复用）
│   │   ├── HealthBadge/
│   │   │   ├── index.tsx
│   │   │   └── HealthBadge.test.tsx
│   │   └── PageLayout/
│   ├── pages/                               # 页面级组件（对应路由）
│   │   ├── SupplierList/
│   │   │   ├── index.tsx
│   │   │   ├── SupplierList.test.tsx
│   │   │   └── components/                  # 页面私有子组件
│   │   └── Dashboard/
│   ├── hooks/                               # 自定义 Hook
│   │   ├── useSupplierList.ts
│   │   └── useHealthScore.ts
│   ├── store/                               # Zustand store
│   │   └── authStore.ts
│   ├── types/                               # 全局 TypeScript 类型
│   │   ├── supplier.types.ts
│   │   └── api.types.ts
│   ├── constants/                           # 常量（枚举值、配置项）
│   │   └── healthLevel.ts
│   └── utils/                               # 纯函数工具
│       └── formatters.ts
├── public/
├── index.html
├── vite.config.ts
├── tsconfig.json
├── .eslintrc.json
└── Dockerfile
```

**禁止行为：**
- 禁止在 `components/` 下的组件直接调用 API（通过 Props 或 Hook 传入）
- 禁止在 `pages/` 下的组件在其他 `pages/` 中复用（抽到 `components/`）
- 禁止将密钥、Token、URL 硬编码在源码中

### 2.3 数据库迁移脚本命名

```
V{版本号}__{描述}.sql

示例：
V1__init_schema.sql
V2__add_supplier_ext_data_column.sql
V3__create_audit_log_table.sql
V10__add_index_snapshot_date.sql
```

**规则：**
- 版本号为单调递增整数，不允许跳号
- 描述使用 snake_case，20 字符以内
- 每个文件只做一件事（单一职责）
- 已合并主干的迁移脚本**禁止修改**，只能新增修复脚本

---

## 3. Git 工作流与提交规范

### 3.1 分支模型

```
main          # 生产分支，只接受 MR，禁止直接 push
├── develop   # 集成分支，功能开发完成后合并至此
├── feature/SCR-{issue-id}-{kebab-desc}   # 功能分支
├── fix/SCR-{issue-id}-{kebab-desc}       # Bug 修复分支
├── hotfix/SCR-{issue-id}-{kebab-desc}    # 生产紧急修复
└── release/v{major}.{minor}.{patch}      # 发布分支
```

**分支规则：**
- `main` 和 `develop` 设置保护分支，禁止 force push
- 功能分支从 `develop` 切出，合并回 `develop`
- `hotfix` 从 `main` 切出，同时合并回 `main` 和 `develop`
- 分支名中的 `{issue-id}` 必须对应真实 Issue，如 `SCR-142`

### 3.2 提交信息规范（Conventional Commits）

```
{type}({scope}): {subject}

[可选 body：说明 why，不是 what]

[可选 footer：关联 Issue 或 Breaking Change]
```

**type 枚举：**

| type | 用途 |
|------|------|
| `feat` | 新功能 |
| `fix` | Bug 修复 |
| `perf` | 性能优化 |
| `refactor` | 重构（不改功能） |
| `test` | 增加或修改测试 |
| `docs` | 文档变更 |
| `chore` | 构建/依赖/CI 配置 |
| `revert` | 回滚提交 |

**scope 枚举：**`supplier` `alertplan` `indicator` `dashboard` `auth` `engine` `infra` `db`

**subject 规则：**
- 使用现在时祈使句，中文或英文均可，但单个 repo 内统一
- 不超过 72 字符
- 结尾不加句号

```bash
# ✅ 正确示例
feat(supplier): 添加供应商列表健康分趋势字段
fix(engine): 修复红线指标触发时权重仍计入总分的问题
perf(dashboard): 增加风险看板统计 Redis 缓存，TTL 10min
chore(infra): 升级 Spring Boot 至 3.2.1

# ❌ 错误示例
fix: bug
update supplier
修改了一些东西。
```

### 3.3 Merge Request 规范

- MR 标题与 commit 规范一致
- 必须关联 Issue：`Closes SCR-142`
- 必须通过 CI 所有 Stage（lint + test + build）才可合并
- 至少 **1 位** 其他开发者 Code Review 通过
- MR 描述模板（强制填写）：

```markdown
## 变更内容
<!-- 简述做了什么 -->

## 变更原因
<!-- 为什么要做这个改动 -->

## 测试方式
<!-- 如何验证这个改动是正确的 -->

## 影响范围
<!-- 涉及哪些模块，是否有破坏性变更 -->

Closes #SCR-XXX
```

---

## 4. 环境变量与配置管理

### 4.1 密钥与敏感信息管理

**铁律：以下内容禁止出现在任何代码文件、配置文件、注释或日志中：**
- 数据库密码
- 第三方 API Key / Secret
- JWT 签名密钥
- MinIO Access Key / Secret Key
- 任何 Bearer Token

**管理方式：**

| 环境 | 管理方式 |
|------|----------|
| 本地开发 | `.env.local` 文件（已加入 `.gitignore`，永不提交） |
| Dev / Test | GitLab CI/CD Variables（Masked） |
| Staging / Prod | Vault 或运维配置中心，通过环境变量注入容器 |

### 4.2 环境变量命名规范

```bash
# 格式：{SERVICE}_{CATEGORY}_{NAME}
# 全大写，下划线分隔

# 数据库
DB_HOST=localhost
DB_PORT=5432
DB_NAME=scrm
DB_USERNAME=scrm_user
DB_PASSWORD=<从 Vault 注入>

# Redis
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=<从 Vault 注入>

# Kafka
KAFKA_BOOTSTRAP_SERVERS=localhost:9092

# 第三方 API
EXT_QICHA_API_KEY=<从 Vault 注入>
EXT_QICHA_BASE_URL=https://api.qichacha.com

# JWT
JWT_SECRET=<从 Vault 注入>
JWT_ACCESS_TOKEN_TTL_SECONDS=7200
JWT_REFRESH_TOKEN_TTL_SECONDS=604800

# 通知
NOTIFY_WXBOT_WEBHOOK_URL=<从 Vault 注入>
NOTIFY_SMTP_PASSWORD=<从 Vault 注入>

# 应用
APP_ENV=dev
APP_LOG_LEVEL=INFO
```

### 4.3 application.yml 规范

```yaml
# application.yml 只放非敏感的默认值和结构
spring:
  datasource:
    url: jdbc:postgresql://${DB_HOST:localhost}:${DB_PORT:5432}/${DB_NAME:scrm}
    username: ${DB_USERNAME}
    password: ${DB_PASSWORD}   # 必须从环境变量读取，无默认值
```

**规则：**
- 敏感字段的占位符**不允许设置默认值**（如 `${DB_PASSWORD:}` 中的冒号后不跟内容）
- `application-prod.yml` 中禁止出现任何具体值，只允许引用环境变量
- 配置项变更必须同步更新本节文档和 `.env.example` 文件

### 4.4 .env.example 文件（必须维护）

项目根目录维护 `.env.example`，包含所有环境变量的键名和说明，**值为占位符**：

```bash
# .env.example — 本文件提交至 git，.env.local 不提交

# 数据库配置
DB_HOST=localhost
DB_PORT=5432
DB_NAME=scrm
DB_USERNAME=scrm_user
DB_PASSWORD=REPLACE_ME

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=REPLACE_ME
```

新增环境变量时，必须同时更新 `.env.example` 和本文档 4.2 节。

---

## 5. 依赖管理规则

### 5.1 后端依赖规则

**引入新依赖前必须确认：**
1. 该功能是否已有现有依赖可满足？（禁止重复引入功能相近的库）
2. 最近 6 个月是否有维护记录（GitHub 提交 / Release）？
3. License 是否兼容（允许：Apache 2.0, MIT, BSD；禁止：GPL, AGPL）？
4. 是否存在已知高危 CVE？

**版本管理：**
- 所有版本号在 `pom.xml` 的 `<properties>` 统一声明，子模块只引用变量
- 禁止在子模块 `pom.xml` 中硬编码版本号
- 禁止使用 `SNAPSHOT` 版本进入 `develop` 和 `main` 分支

```xml
<!-- ✅ 正确：在根 pom.xml 统一管理版本 -->
<properties>
    <spring-boot.version>3.2.1</spring-boot.version>
    <kafka.version>3.6.1</kafka.version>
</properties>

<!-- ❌ 错误：子模块硬编码版本 -->
<dependency>
    <groupId>org.springframework.kafka</groupId>
    <artifactId>spring-kafka</artifactId>
    <version>3.6.1</version>
</dependency>
```

**禁止引入的依赖（已有替代方案）：**

| 禁止 | 原因 | 替代 |
|------|------|------|
| Guava Cache | 已有 Caffeine | Caffeine |
| Apache Commons Lang3 单独引入 | Spring Boot 已传递依赖 | 直接使用 |
| fastjson / fastjson2 | 历史 CVE 多 | Jackson（已包含） |
| Lombok（新代码） | 隐式生成代码难以 Debug | Java Record / 手写 |

### 5.2 前端依赖规则

- 使用 `pnpm` 管理依赖，禁止使用 `npm` 和 `yarn`（lockfile 不兼容）
- 生产依赖 (`dependencies`) 只放运行时必需的包
- 开发工具放 `devDependencies`
- 禁止安装功能重叠的 UI 库（已选 Ant Design，禁止同时引入 MUI / Chakra）
- 引入新的前端依赖，bundle size 增量不允许超过 **50KB gzipped**（需用 `vite-bundle-analyzer` 验证）

```bash
# 安装依赖（统一使用 pnpm）
pnpm add axios                     # 生产依赖
pnpm add -D @types/node            # 开发依赖
pnpm add --filter frontend dayjs   # 指定 workspace
```

### 5.3 依赖安全扫描

- CI 流水线集成 **OWASP Dependency-Check**（后端）和 **npm audit**（前端）
- 高危（CVSS ≥ 7.0）漏洞：**阻断 CI，必须修复后才能合并**
- 中危（CVSS 4.0–6.9）漏洞：创建 Issue，**7 天内**修复
- 依赖扫描报告保存至 CI artifacts，保留 30 天

---

## 6. 架构约束

### 6.1 禁止的设计决策

| # | 禁止 | 原因 |
|---|------|------|
| 1 | 跨模块直接调用 Repository | 破坏模块边界；必须通过 Service 接口调用 |
| 2 | 在 Controller 中写业务逻辑 | Controller 只做：参数校验 + 调用 Service + 组装响应 |
| 3 | 在 Entity 中写业务方法 | Entity 是数据载体，业务逻辑属于 Service |
| 4 | 使用 `@Transactional` 注解 Controller 方法 | 事务边界应在 Service 层 |
| 5 | 前端直接调用第三方 API | 所有外部调用经后端代理，避免密钥暴露 |
| 6 | 硬编码 `Thread.sleep()` 做延迟 | 使用 `ScheduledExecutorService` 或 XXL-Job |
| 7 | 在 Kafka Consumer 中做耗时操作（> 5s） | 耗时操作提交至独立线程池异步处理 |
| 8 | `SELECT *` 查询 | 指定字段，防止字段增加后隐性影响性能 |
| 9 | 前端 `localStorage` 存储 Token | Token 存内存（Access Token）或 HttpOnly Cookie（Refresh Token） |
| 10 | 在组件内直接裸 `fetch` | 统一通过 `api/` 目录的函数 + React Query |
| 11 | 使用 `System.out.println` 打日志 | 使用 SLF4J + `log.info/warn/error` |
| 12 | `catch (Exception e) {}` 空吞异常 | 必须记录日志或向上抛出 |

### 6.2 必须遵守的设计决策

| # | 必须 |
|---|------|
| 1 | 所有 REST 接口返回统一响应体 `ApiResponse<T>`，包含 `code`、`msg`、`data`、`traceId` |
| 2 | 所有数据库变更通过 Flyway 迁移脚本管理，禁止手动执行 DDL |
| 3 | 所有对外 HTTP 接口必须有请求/响应日志（通过 Filter 统一打印，敏感字段脱敏） |
| 4 | Service 接口必须定义为 Java Interface，实现类在 `impl/` 包下 |
| 5 | 分页查询必须使用游标分页（Keyset），禁止 OFFSET > 1000 的深分页 |
| 6 | 所有外部 HTTP 调用必须设置超时：连接超时 3s，读取超时 10s |
| 7 | Kafka 消息消费失败必须有重试机制（最多 3 次，指数退避）和死信队列（DLQ） |
| 8 | 新增 API 接口必须同步更新 OpenAPI 文档注解 (`@Operation`, `@ApiResponse`) |
| 9 | 前端所有页面路由对应的组件必须实现 `ErrorBoundary` |
| 10 | Redis Key 必须设置 TTL，禁止永不过期的 Key |

### 6.3 推荐的设计决策

| # | 推荐 | 说明 |
|---|------|------|
| 1 | 使用 `record` 声明 DTO/VO | Java 17 record 不可变，更安全 |
| 2 | 使用 `Optional` 替代 null 返回 | 明确表达可能为空，强制调用方处理 |
| 3 | 枚举值定义在独立的 `enums` 包 | 避免字符串魔法值散落各处 |
| 4 | 复杂查询写在 `_README.md` 中说明业务背景 | 降低后续维护理解成本 |
| 5 | 前端复杂表单使用 Ant Design Form + `useForm` | 统一校验逻辑，避免手写 state 管理 |
| 6 | 批量操作使用 JDBC `batchUpdate` | 避免 N+1 次数据库调用 |

### 6.4 模块间通信规则

```
允许的依赖方向（单向，禁止反向）：

Controller → Service → Repository → Database
     ↓
   DTO/VO（不依赖任何层）
     ↓
  Domain/Entity（只依赖 JPA/MyBatis 注解）

跨模块通信：
  模块 A Service → 模块 B Service（通过 Spring 注入接口）
  禁止：模块 A Repository → 模块 B Repository
  禁止：模块 A Controller → 模块 B Controller
```

---

## 7. 测试规范

### 7.1 测试覆盖率要求

| 层 | 覆盖率要求 | 测试类型 |
|----|-----------|----------|
| Service 层 | **≥ 80%** 行覆盖 | 单元测试（Mock 所有依赖） |
| Repository 层 | **≥ 70%** | 集成测试（测试容器 Testcontainers） |
| Controller 层 | 核心接口 100% | MockMvc 接口测试 |
| 前端组件 | **≥ 60%** | Vitest + React Testing Library |
| 前端 Hook | **≥ 80%** | Vitest |

CI 流水线中覆盖率低于以上阈值时**阻断合并**。

### 7.2 后端测试规范

**单元测试（Service 层）：**

```java
// 测试类命名：{被测类名}Test
// 测试方法命名：{方法名}_when{条件}_should{期望结果}

@ExtendWith(MockitoExtension.class)
class SupplierHealthServiceTest {

    @Mock
    private SupplierRepository supplierRepository;

    @InjectMocks
    private SupplierHealthServiceImpl supplierHealthService;

    @Test
    void calculateScore_whenRedlineIndicatorTriggered_shouldReturnZero() {
        // Arrange
        given(supplierRepository.findById(1001L)).willReturn(Optional.of(mockSupplier()));

        // Act
        HealthSnapshot result = supplierHealthService.calculateScore(1001L, 1L);

        // Assert
        assertThat(result.getHealthScore()).isEqualTo(BigDecimal.ZERO);
        assertThat(result.getHealthLevel()).isEqualTo(HealthLevel.HIGH_RISK);
    }
}
```

**集成测试（Repository 层）：**

```java
// 使用 Testcontainers 启动真实 PostgreSQL
@DataJpaTest
@AutoConfigureTestDatabase(replace = AutoConfigureTestDatabase.Replace.NONE)
@Testcontainers
class SupplierRepositoryTest {

    @Container
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:15")
            .withDatabaseName("scrm_test");
    // ...
}
```

**接口测试（Controller 层）：**

```java
// 使用 MockMvc，验证 HTTP 状态码、响应结构、错误码
@WebMvcTest(SupplierController.class)
class SupplierControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void getSupplierList_withInvalidPageSize_shouldReturn400() throws Exception {
        mockMvc.perform(get("/api/v1/suppliers?page_size=200"))
               .andExpect(status().isBadRequest())
               .andExpect(jsonPath("$.code").value(400001));
    }
}
```

### 7.3 前端测试规范

```typescript
// 组件测试：验证渲染和用户交互，不测试实现细节
describe('HealthBadge', () => {
  it('should render HIGH_RISK badge in red', () => {
    render(<HealthBadge level="high_risk" />);
    expect(screen.getByText('高风险')).toBeInTheDocument();
    expect(screen.getByTestId('health-badge')).toHaveClass('badge--red');
  });
});

// Hook 测试
describe('useSupplierList', () => {
  it('should return sorted suppliers by health score ascending', async () => {
    // 使用 msw mock API 响应
  });
});
```

**禁止在测试中：**
- 测试实现细节（如内部 state 变量名）
- 断言 CSS 类名（除非类名本身是业务含义）
- 使用 `setTimeout` 等待异步（使用 `waitFor`）

### 7.4 测试数据规范

- 单元测试数据在测试类内用 `private static` 方法生成，禁止硬编码长字符串
- 集成测试数据使用 `@Sql` 注解加载固定 fixture 文件，位于 `src/test/resources/fixtures/`
- 测试数据中的供应商统一信用代码使用 `91440300TEST00001` 格式（TEST 标识）
- 禁止测试依赖外部网络（所有外部 HTTP 用 WireMock 或 msw 拦截）

---

## 8. 部署规范

### 8.1 镜像构建规范

- 所有服务必须提供 `Dockerfile`，使用**多阶段构建**
- 基础镜像固定小版本：`eclipse-temurin:17.0.9-jre-alpine`（不允许 `latest`）
- 镜像标签格式：`{service}:{git-short-sha}-{yyyyMMdd}`，示例：`scrm-api:a1b2c3d4-20260320`
- `latest` 标签只在 `main` 分支合并后由 CI 打，开发人员禁止手动打 `latest`
- 镜像构建完成后必须通过 **Trivy** 扫描，高危漏洞阻断发布

### 8.2 发布流程

```
1. 在 develop 分支打 Release Tag: v1.2.0
2. CI 自动触发：构建 → 测试 → 镜像扫描 → 推送镜像仓库
3. 自动部署至 Staging 环境
4. QA 执行回归测试（≥ 30 分钟浸泡测试）
5. Tech Lead 在 GitLab 手动审批 Production 部署
6. 生产环境滚动更新（不停机）
7. 部署完成后 10 分钟观察期：监控错误率和响应时间
8. 观察期正常 → 关闭发布 Issue；异常 → 立即执行回滚
```

### 8.3 回滚规范

- 任何生产环境问题，**优先回滚，不在生产紧急修复**
- 回滚命令（Docker Compose 方式）：

```bash
# 回滚至上一版本镜像
docker-compose -f docker-compose.prod.yml up -d \
  --no-deps api=scrm-api:{上一版本 tag}

# 数据库回滚（仅在必要时执行 Flyway repair）
flyway -url=${DB_URL} -user=${DB_USER} -password=${DB_PASS} repair
```

- 数据库迁移脚本设计时必须考虑**向后兼容**（新增列允许 NULL 或有默认值；删除列分两步：先废弃代码引用，再下个版本删除列）

### 8.4 健康检查与就绪检查

每个服务必须实现：

```yaml
# Spring Boot Actuator 配置
management:
  endpoints:
    web:
      exposure:
        include: health,info,metrics
  endpoint:
    health:
      show-details: when-authorized

# Docker Compose 健康检查配置示例
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/actuator/health/liveness"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

- `/actuator/health/liveness`：进程是否存活（不检查依赖）
- `/actuator/health/readiness`：是否可接收流量（检查 DB、Redis 连通性）

### 8.5 日志规范

```yaml
# 日志格式（JSON，便于 ELK 解析）
logging:
  pattern:
    console: '{"time":"%d{ISO8601}","level":"%p","service":"scrm-api","traceId":"%X{traceId}","msg":"%m"}%n'
```

**日志级别使用规范：**

| 级别 | 使用场景 |
|------|----------|
| `ERROR` | 需要立即处理的异常（影响业务功能） |
| `WARN` | 潜在问题（外部 API 超时重试、缓存未命中） |
| `INFO` | 关键业务操作（评分计算开始/完成、预警触发、用户登录） |
| `DEBUG` | 开发调试（生产环境禁止 DEBUG） |

**禁止在日志中打印：** 密码、Token、完整手机号、完整身份证号、第三方 API Key

**日志保留策略：** 本地文件滚动（单文件最大 100MB，保留 7 天）；生产日志推送至集中日志平台，保留 30 天。

---

## 附：快速检查清单

在提交 MR 前，逐项确认：

```
代码质量
[ ] 无 Lint 错误（./mvnw checkstyle:check 或 pnpm lint 通过）
[ ] 无 TODO/FIXME 遗留在本次改动的新增代码中
[ ] 无注释掉的代码块
[ ] 无 System.out.println / console.log（调试代码已清理）

安全
[ ] 无硬编码密钥或 Token
[ ] 新增接口已加鉴权注解
[ ] 用户输入已做校验（@Valid / Zod）

测试
[ ] 新增功能有对应测试
[ ] 本地测试全部通过（./mvnw test 或 pnpm test）
[ ] 覆盖率不低于当前水位

文档
[ ] 新增接口已更新 OpenAPI 注解
[ ] 新增环境变量已更新 .env.example
[ ] 破坏性变更已在 MR 描述中标注
```

---

*最后更新：2026-03-20 | 版本：v1.0 | 变更须经 Tech Lead 审批*
