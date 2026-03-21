/** 统一返回结构 */
export type DevSkillResult<T = unknown> =
  | { success: true; data: T; message: string; error?: undefined; timestamp: string; duration?: number }
  | { success: false; data: null; message: string; error?: string; timestamp: string; duration?: number };

/** 日志级别枚举 */
export type LogLevel = 'ERROR' | 'WARN' | 'INFO' | 'DEBUG';

/** 日志查询参数 */
export interface QueryLogParams {
  startTime: string;
  endTime: string;
  keyword?: string;
  level?: LogLevel;
}

/** 日志条目 */
export interface LogEntry {
  time: string;
  level: LogLevel;
  service: string;
  traceId: string;
  msg: string;
}

/** 数据库类型 */
export type DbType = 'pg' | 'redis';

/** 数据库查询参数 */
export interface QueryDbParams {
  sql: string;
  params?: unknown[];
  dbType?: DbType;
  timeoutMs?: number;
}

/** 角色枚举 */
export type TokenRole = 'RISK_ADMIN' | 'RISK_ANALYST' | 'READER';

/** Token 结果 */
export interface TokenResult {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  role: TokenRole;
}

/** 环境枚举 */
export type ServiceEnv = 'dev' | 'test' | 'staging';

/** 服务重启参数 */
export interface RestartServiceParams {
  serviceName: string;
  env: ServiceEnv;
}

/** 服务重启结果 */
export interface RestartResult {
  serviceName: string;
  env: ServiceEnv;
  status: 'restarted' | 'failed';
  containerId?: string;
}

/** 批量评分任务参数 */
export interface TriggerScoreJobParams {
  batchSize: number;
  startId: number;
  endId: number;
}

/** 评分任务结果 */
export interface ScoreJobResult {
  jobId: string;
  batchSize: number;
  totalSuppliers: number;
  estimatedDurationSec: number;
  status: 'triggered' | 'queued';
}

/** SDK 配置 */
export interface DevSkillsConfig {
  apiHost: string;
  dbUrl: string;
  dbUsername: string;
  dbPassword: string;
  redisHost: string;
  redisPort: number;
  redisPassword: string;
  requestTimeoutMs: number;
  maxRetries: number;
}
