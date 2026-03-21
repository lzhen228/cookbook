/**
 * @scrm/dev-skills 使用示例
 *
 * 运行前确保 .env.local 已配置，参考项目根目录 .env.example
 *
 * 执行方式：
 *   npx tsx examples/usage.ts
 */

import {
  loadConfig,
  queryLog,
  queryDb,
  getToken,
  restartService,
  triggerScoreJob,
} from '../src/index.js';

async function main(): Promise<void> {
  // 1. 加载配置
  const config = loadConfig();
  console.log('配置加载完成，API Host:', config.apiHost);

  // 2. 日志查询 —— 查询最近一天的 ERROR 日志
  console.log('\n--- 日志查询 ---');
  const logResult = await queryLog(
    {
      startTime: '2026-03-20T00:00:00Z',
      endTime: '2026-03-20T23:59:59Z',
      keyword: 'SupplierHealth',
      level: 'ERROR',
    },
    config
  );
  console.log(JSON.stringify(logResult, null, 2));

  // 3. 数据库查询（PostgreSQL）—— 查询供应商健康分
  console.log('\n--- PostgreSQL 查询 ---');
  const pgResult = await queryDb(
    {
      sql: `SELECT s.id, s.name, shs.health_score, shs.health_level
            FROM supplier s
            INNER JOIN supplier_health_snapshot shs
              ON shs.supplier_id = s.id
              AND shs.snapshot_date = CURRENT_DATE
            WHERE shs.health_level = $1
            ORDER BY shs.health_score ASC
            LIMIT 10`,
      params: ['high_risk'],
      dbType: 'pg',
    },
    config
  );
  console.log(JSON.stringify(pgResult, null, 2));

  // 4. 数据库查询（Redis）—— 查询供应商健康分缓存
  console.log('\n--- Redis 查询 ---');
  const redisResult = await queryDb(
    {
      sql: 'GET supplier:health:1001',
      dbType: 'redis',
    },
    config
  );
  console.log(JSON.stringify(redisResult, null, 2));

  // 5. 获取 Token
  console.log('\n--- Token 获取 ---');
  const tokenResult = await getToken('RISK_ADMIN', config);
  console.log(JSON.stringify(tokenResult, null, 2));

  // 6. 服务重启（仅 dev/test/staging）
  console.log('\n--- 服务重启 ---');
  const restartResult = await restartService(
    { serviceName: 'scrm-api', env: 'dev' },
    config
  );
  console.log(JSON.stringify(restartResult, null, 2));

  // 7. 批量评分任务触发
  console.log('\n--- 评分任务 ---');
  const jobResult = await triggerScoreJob(
    { batchSize: 500, startId: 1, endId: 10000 },
    config
  );
  console.log(JSON.stringify(jobResult, null, 2));
}

main().catch(console.error);
