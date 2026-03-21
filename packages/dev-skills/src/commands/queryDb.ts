import pg from 'pg';
import { Redis as RedisClient } from 'ioredis';
import type { DevSkillsConfig } from '../config.js';
import type { DbType, DevSkillResult, QueryDbParams } from '../types.js';
import { fail, maskSql, ok, requireString, withTimeout } from '../utils.js';

const { Pool } = pg;

/** 禁止执行的危险 SQL 关键字 */
const FORBIDDEN_PATTERNS = [
  /\bDROP\s+(TABLE|DATABASE|SCHEMA|INDEX)\b/i,
  /\bTRUNCATE\b/i,
  /\bDELETE\s+FROM\b(?!.*\bWHERE\b)/i,
  /\bALTER\s+TABLE\b.*\bDROP\b/i,
];

/** 危险命令检查白名单（Redis） */
const REDIS_BLOCKED_COMMANDS = new Set([
  'FLUSHALL', 'FLUSHDB', 'DEBUG', 'SHUTDOWN', 'CONFIG',
  'SLAVEOF', 'REPLICAOF', 'CLUSTER',
]);

/**
 * 查询数据库（PostgreSQL 或 Redis）
 *
 * 对 PostgreSQL 执行只读 SQL 查询，对 Redis 执行只读命令。
 * 内置危险操作拦截、超时控制和敏感信息脱敏。
 *
 * @param params - 查询参数
 * @param params.sql - SQL 语句（PG）或 Redis 命令字符串（如 "GET supplier:health:1001"）
 * @param params.params - SQL 参数化查询的参数数组
 * @param params.dbType - 数据库类型，默认 'pg'
 * @param params.timeoutMs - 单次查询超时（毫秒），默认使用全局配置
 * @param config - SDK 配置
 * @returns 结构化查询结果
 *
 * @example
 * ```ts
 * // PostgreSQL 查询
 * const result = await queryDb({
 *   sql: 'SELECT id, name, health_score FROM supplier WHERE id = $1',
 *   params: [1001],
 *   dbType: 'pg',
 * }, config);
 *
 * // Redis 查询
 * const result = await queryDb({
 *   sql: 'GET supplier:health:1001',
 *   dbType: 'redis',
 * }, config);
 * ```
 */
export async function queryDb(
  params: QueryDbParams,
  config: DevSkillsConfig
): Promise<DevSkillResult<unknown>> {
  const start = Date.now();
  const dbType: DbType = params.dbType ?? 'pg';
  const timeout = params.timeoutMs ?? config.requestTimeoutMs;

  try {
    const sql = requireString(params.sql, 'sql');

    if (dbType === 'pg') {
      return await queryPostgres(sql, params.params ?? [], timeout, config, start);
    } else if (dbType === 'redis') {
      return await queryRedis(sql, timeout, config, start);
    } else {
      return fail(`不支持的数据库类型: ${String(dbType)}，允许值: pg, redis`);
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return fail('数据库查询失败', msg, Date.now() - start);
  }
}

/**
 * 执行 PostgreSQL 查询
 */
async function queryPostgres(
  sql: string,
  params: unknown[],
  timeout: number,
  config: DevSkillsConfig,
  start: number
): Promise<DevSkillResult<unknown>> {
  for (const pattern of FORBIDDEN_PATTERNS) {
    if (pattern.test(sql)) {
      return fail(
        '检测到危险 SQL 操作，已拦截',
        `SQL (已脱敏): ${maskSql(sql)}`
      );
    }
  }

  const pool = new Pool({
    connectionString: config.dbUrl,
    user: config.dbUsername,
    password: config.dbPassword,
    max: 2,
    idleTimeoutMillis: 5000,
    connectionTimeoutMillis: 3000,
    statement_timeout: timeout,
  });

  try {
    const result = await withTimeout(
      pool.query(sql, params),
      timeout,
      'PostgreSQL 查询'
    );

    return ok(
      { rows: result.rows, rowCount: result.rowCount },
      `查询成功，返回 ${result.rowCount ?? 0} 行`,
      Date.now() - start
    );
  } finally {
    await pool.end();
  }
}

/**
 * 执行 Redis 查询
 */
async function queryRedis(
  command: string,
  timeout: number,
  config: DevSkillsConfig,
  start: number
): Promise<DevSkillResult<unknown>> {
  const parts = command.trim().split(/\s+/);
  const cmd = (parts[0] ?? '').toUpperCase();
  const args = parts.slice(1);

  if (REDIS_BLOCKED_COMMANDS.has(cmd)) {
    return fail(`Redis 命令 ${cmd} 已被禁止执行`);
  }

  const redis = new RedisClient({
    host: config.redisHost,
    port: config.redisPort,
    password: config.redisPassword || undefined,
    connectTimeout: 3000,
    commandTimeout: timeout,
    maxRetriesPerRequest: 1,
  });

  try {
    const result = await withTimeout(
      redis.call(cmd, ...args) as Promise<unknown>,
      timeout,
      'Redis 查询'
    );

    return ok(result, `Redis ${cmd} 执行成功`, Date.now() - start);
  } finally {
    redis.disconnect();
  }
}
