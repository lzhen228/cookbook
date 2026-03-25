# 供应链风险管理平台 (SCRM)

## 技术栈

| 层 | 技术 |
|---|---|
| 后端 | Java 17 · Spring Boot 3 · MyBatis-Plus · Flyway |
| 前端 | TypeScript · React · Ant Design · Vite |
| 数据库 | PostgreSQL 15 |
| 缓存 | Redis 7 |

---

## 本地启动

### 前置条件

- JDK 17+
- Maven 3.9+
- Node.js 18+ · pnpm 9+
- Docker & Docker Compose（仅使用本地 Docker 数据库时需要）

---

### 方式一：使用本地 Docker 数据库和 Redis

#### 第一步：启动基础设施

```bash
docker compose up -d
```

启动 PostgreSQL（5432）和 Redis（6379），dev 密码均为 `scrm_dev_123`。

#### 第二步：配置环境变量

```bash
cp .env.example .env.local
```

编辑 `.env.local`：

```bash
DB_HOST=localhost
DB_PORT=5432
DB_NAME=scrm
DB_USERNAME=scrm_user
DB_PASSWORD=scrm_dev_123

REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_PASSWORD=scrm_dev_123

JWT_SECRET=any-local-dev-secret
```

---

### 方式二：连接指定服务器的数据库和 Redis

#### 第一步：配置环境变量

```bash
cp .env.example .env.local
```

编辑 `.env.local`，填入服务器连接信息：

```bash
DB_HOST=<服务器 IP 或域名>
DB_PORT=5432
DB_NAME=scrm
DB_USERNAME=<数据库用户名>
DB_PASSWORD=<数据库密码>

REDIS_HOST=<服务器 IP 或域名>
REDIS_PORT=6379
REDIS_PASSWORD=<Redis 密码>

JWT_SECRET=any-local-dev-secret
```

> 数据库和 Redis 在同一台服务器时，两处 HOST 填同一个地址即可。

---

### 启动后端

**macOS / Linux**

```bash
cd services/api
export $(cat ../../.env.local | grep -v '^#' | xargs)
mvn spring-boot:run
```

**Windows（PowerShell）**

```powershell
.\run-dev.ps1
```

Flyway 会在启动时自动执行 `db/migration/` 下的迁移脚本并写入测试数据。

后端地址：`http://localhost:8080/api/v1`

### 启动前端

```bash
cd services/frontend
pnpm install
pnpm dev
```

前端地址：`http://localhost:3000`（已配置代理，`/api` 转发到 8080）

---

## 常用命令

```bash
# 后端测试
cd services/api && mvn test

# 前端测试
cd services/frontend && pnpm test

# 前端覆盖率报告
cd services/frontend && pnpm coverage

# 停止本地 Docker 基础设施
docker compose down

# 清除数据库卷（重置测试数据，仅 Docker 方式）
docker compose down -v
```
