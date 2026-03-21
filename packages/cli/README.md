# @scrm/cli — 供应链风险管理平台 CLI 测试工具

用于在终端中快速调用供应链风险管理平台 API 的命令行工具，支持多环境切换和多种输出格式。

## 安装

```bash
# 安装依赖
cd packages/cli
pnpm install

# 构建
pnpm build

# 本地全局链接（之后可直接使用 risk-supplier 命令）
pnpm link --global
```

## 环境变量配置

在使用前需设置认证凭据：

```bash
export SCRM_CLI_USERNAME=your_username
export SCRM_CLI_PASSWORD=your_password

# 可选：覆盖默认 API 地址
export SCRM_CLI_BASE_URL=http://localhost:8080/api/v1
```

Token 会自动缓存到 `~/.scrm-cli/auth.json`，过期时自动刷新。

## 全局选项

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-e, --env <env>` | 目标环境：`dev` / `test` / `prod` | `dev` |
| `-l, --log-level <level>` | 日志级别：`debug` / `info` / `warn` / `error` | `info` |
| `-f, --format <format>` | 输出格式：`json` / `table` | `table` |
| `-V, --version` | 显示版本号 | - |
| `-h, --help` | 显示帮助信息 | - |

## 命令

### 查询供应商画像

```bash
risk-supplier profile <supplierId>

# 示例
risk-supplier profile 1001
risk-supplier profile 1001 --env=test --format=json
risk-supplier -e prod -l debug profile 1001
```

### 触发供应商评分

```bash
risk-supplier score <supplierId> [--plan-id <planId>]

# 示例
risk-supplier score 1001
risk-supplier score 1001 --plan-id 3
risk-supplier score 1001 -p 2 --format=json
```

### 生成健康报告

```bash
risk-supplier report generate <supplierId> [--plan-id <planId>]

# 示例
risk-supplier report generate 1001
risk-supplier report generate 1001 --plan-id 2
```

### 查询预警列表

```bash
risk-supplier alert list [选项]

选项：
  --page <page>              页码（默认 1）
  --size <size>              每页条数，最大 100（默认 20）
  --level <level>            按预警等级筛选：high / medium / low
  --status <status>          按状态筛选：pending / resolved / ignored
  --supplier-id <supplierId> 按供应商 ID 筛选

# 示例
risk-supplier alert list
risk-supplier alert list --page 2 --size 10
risk-supplier alert list --level high --status pending
risk-supplier alert list --supplier-id 1001 --format=json
risk-supplier -e test alert list --page 1 --size 50
```

## 环境地址

| 环境 | API 地址 |
|------|----------|
| dev | `http://localhost:8080/api/v1` |
| test | `https://test-api.scrm.company.com/api/v1` |
| prod | `https://api.scrm.company.com/api/v1` |

可通过 `SCRM_CLI_BASE_URL` 环境变量覆盖。

## 项目结构

```
packages/cli/
├── bin/
│   └── index.js           # CLI 入口
├── src/
│   ├── index.ts           # Commander 主程序
│   ├── commands/
│   │   ├── profile.ts     # profile 命令
│   │   ├── score.ts       # score 命令
│   │   ├── report.ts      # report 命令组
│   │   └── alert.ts       # alert 命令组
│   ├── utils/
│   │   ├── request.ts     # HTTP 客户端（认证/traceId/错误处理）
│   │   ├── auth.ts        # Token 获取/刷新/缓存
│   │   └── format.ts      # 输出格式化（JSON/表格/日志）
│   └── types/
│       └── index.ts       # TypeScript 类型定义
├── package.json
├── tsconfig.json
└── README.md
```
