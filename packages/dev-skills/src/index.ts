/**
 * @scrm/dev-skills — 供应链风险管理平台 Dev Skills SDK
 *
 * 提供日志查询、数据库查询、Token 获取、服务重启、批量评分任务触发等运维开发能力。
 * 所有函数返回统一的 DevSkillResult 结构。
 *
 * @example
 * ```ts
 * import { loadConfig, queryLog, queryDb, getToken, restartService, triggerScoreJob } from '@scrm/dev-skills';
 *
 * const config = loadConfig();
 * const logs = await queryLog({ startTime: '2026-03-20T00:00:00Z', endTime: '2026-03-20T23:59:59Z', level: 'ERROR' }, config);
 * ```
 */

// 配置
export { loadConfig } from './config.js';

// 命令
export { queryLog } from './commands/queryLog.js';
export { queryDb } from './commands/queryDb.js';
export { getToken } from './commands/getToken.js';
export { restartService } from './commands/restartService.js';
export { triggerScoreJob } from './commands/triggerScoreJob.js';

// 工具函数
export { maskSensitive, maskSql, withTimeout, withRetry } from './utils.js';

// 类型
export type {
  DevSkillResult,
  DevSkillsConfig,
  LogLevel,
  LogEntry,
  QueryLogParams,
  DbType,
  QueryDbParams,
  TokenRole,
  TokenResult,
  ServiceEnv,
  RestartServiceParams,
  RestartResult,
  TriggerScoreJobParams,
  ScoreJobResult,
} from './types.js';
