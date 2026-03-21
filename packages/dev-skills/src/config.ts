import { config as loadEnv } from 'dotenv';
import { resolve } from 'node:path';
import type { DevSkillsConfig } from './types.js';
export type { DevSkillsConfig } from './types.js';

/** 从 .env 文件和环境变量加载配置 */
export function loadConfig(envPath?: string): DevSkillsConfig {
  loadEnv({ path: envPath ?? resolve(process.cwd(), '.env.local') });

  const apiHost = process.env['API_HOST'];
  if (!apiHost) {
    throw new Error('缺少必需环境变量 API_HOST，请检查 .env.local 配置');
  }

  return {
    apiHost,
    dbUrl: process.env['DB_URL'] ??
      `postgresql://${process.env['DB_HOST'] ?? 'localhost'}:${process.env['DB_PORT'] ?? '5432'}/${process.env['DB_NAME'] ?? 'scrm'}`,
    dbUsername: process.env['DB_USERNAME'] ?? 'scrm_user',
    dbPassword: process.env['DB_PASSWORD'] ?? '',
    redisHost: process.env['REDIS_HOST'] ?? 'localhost',
    redisPort: Number(process.env['REDIS_PORT'] ?? '6379'),
    redisPassword: process.env['REDIS_PASSWORD'] ?? '',
    requestTimeoutMs: Number(process.env['REQUEST_TIMEOUT_MS'] ?? '10000'),
    maxRetries: Number(process.env['MAX_RETRIES'] ?? '3'),
  };
}
