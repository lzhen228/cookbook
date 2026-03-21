全部完成。以下是生成的完整 CI/CD 配置总览：

---

## 文件清单

| 文件                               | 用途                                                       |
| ---------------------------------- | ---------------------------------------------------------- |
| `.gitlab-ci.yml`                   | GitLab CI 流水线（3 Stage，6 Job）                         |
| `.github/workflows/ci.yml`         | GitHub Actions 流水线（3 Stage，6 Job）                    |
| `ci/check-backend-coverage.sh`     | 后端覆盖率校验脚本（解析 JaCoCo XML）                      |
| `ci/check-frontend-coverage.sh`    | 前端覆盖率校验脚本（解析 coverage-summary.json）           |
| `services/api/pom.xml`             | 新增 JaCoCo `check` goal + Checkstyle 插件                 |
| `services/frontend/vite.config.ts` | 新增 `coverage.reporter: ['text', 'json-summary', 'lcov']` |

## 流水线架构

```
lint ──────────────────► test ──────────────────► coverage
│                        │                        │
├─ lint:backend          ├─ test:backend          ├─ coverage:backend
│  (Checkstyle)          │  (JUnit5+Mockito       │  (JaCoCo XML 解析)
│                        │   +JaCoCo report)      │
├─ lint:frontend         ├─ test:frontend         ├─ coverage:frontend
│  (ESLint+tsc)          │  (Vitest+MSW+RTL       │  (json-summary 解析)
│                        │   +v8 coverage)        │

任一 Stage 失败 → 拦截 PR/MR ❌
```

## 覆盖率阈值

| 模块                 | 后端阈值 | 前端阈值 |
| -------------------- | -------- | -------- |
| **service / hooks**  | ≥ 80%    | ≥ 80%    |
| **controller / api** | ≥ 70%    | ≥ 70%    |
| **common / utils**   | ≥ 70%    | ≥ 70%    |
| **components**       | —        | ≥ 60%    |
| **pages**            | —        | ≥ 60%    |
| **整体**             | ≥ 70%    | ≥ 70%    |

## Runner 环境要求

| 平台         | 后端 Job                                       | 前端 Job                                                        |
| ------------ | ---------------------------------------------- | --------------------------------------------------------------- |
| **GitLab**   | Docker executor, `eclipse-temurin:17-jdk`      | Docker executor, `node:20-slim`                                 |
| **GitHub**   | `ubuntu-latest` + `setup-java@v4 (temurin 17)` | `ubuntu-latest` + `setup-node@v4 (20)` + `pnpm/action-setup@v4` |
| **依赖工具** | Python 3（coverage 脚本）                      | jq（coverage 脚本，ubuntu-latest 自带）                         |

## 关键设计决策

- **双平台通用**：GitLab CI 和 GitHub Actions 共用同一对覆盖率校验脚本（`ci/` 目录）
- **JaCoCo 双重校验**：Maven `jacoco:check` goal（pom.xml 内置阈值）+ 自定义 Python 脚本（细粒度包级别报告）
- **前端 json-summary**：`@vitest/coverage-v8` 生成 `coverage-summary.json`，jq 按目录聚合计算
- **PR 拦截**：所有 Job 设置 `allow_failure: false`（GitLab）/ Stage 串行依赖（GitHub），任一失败阻断合并
- **并发控制**：GitHub Actions 使用 `concurrency` 取消同分支旧运行，GitLab 通过默认 pipeline 策略处理
- **缓存优化**：Maven `.m2/repository` + pnpm store 按分支缓存
