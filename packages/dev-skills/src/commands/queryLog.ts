import axios from 'axios';
import type { DevSkillsConfig } from '../config.js';
import type { DevSkillResult, LogEntry, LogLevel, QueryLogParams } from '../types.js';
import { fail, ok, requireString, withRetry, withTimeout } from '../utils.js';

/** 合法日志级别 */
const VALID_LEVELS: ReadonlySet<LogLevel> = new Set(['ERROR', 'WARN', 'INFO', 'DEBUG']);

/**
 * 查询平台日志
 *
 * 通过后端日志查询接口检索指定时间范围内的日志条目，
 * 支持按关键字和日志级别过滤。
 *
 * @param params - 查询参数
 * @param params.startTime - 开始时间（ISO 8601 格式，如 2026-03-20T00:00:00Z）
 * @param params.endTime - 结束时间（ISO 8601 格式）
 * @param params.keyword - 可选，日志内容关键字
 * @param params.level - 可选，日志级别过滤（ERROR/WARN/INFO/DEBUG）
 * @param config - SDK 配置
 * @returns 结构化查询结果，data 为日志条目数组
 *
 * @example
 * ```ts
 * const result = await queryLog({
 *   startTime: '2026-03-20T00:00:00Z',
 *   endTime: '2026-03-20T23:59:59Z',
 *   keyword: 'SupplierHealth',
 *   level: 'ERROR',
 * }, config);
 * ```
 */
export async function queryLog(
  params: QueryLogParams,
  config: DevSkillsConfig
): Promise<DevSkillResult<LogEntry[]>> {
  const start = Date.now();

  try {
    const startTime = requireString(params.startTime, 'startTime');
    const endTime = requireString(params.endTime, 'endTime');

    if (new Date(startTime).getTime() >= new Date(endTime).getTime()) {
      return fail('startTime 必须早于 endTime');
    }

    if (params.level && !VALID_LEVELS.has(params.level)) {
      return fail(`无效的日志级别: ${params.level}，允许值: ${[...VALID_LEVELS].join(', ')}`);
    }

    const response = await withRetry(
      () =>
        withTimeout(
          axios.get<{ code: number; data: LogEntry[] }>(
            `${config.apiHost}/api/v1/ops/logs`,
            {
              params: {
                start_time: startTime,
                end_time: endTime,
                keyword: params.keyword ?? undefined,
                level: params.level ?? undefined,
              },
              timeout: config.requestTimeoutMs,
            }
          ),
          config.requestTimeoutMs,
          '日志查询'
        ),
      config.maxRetries,
      1000,
      '日志查询'
    );

    const entries = response.data.data ?? [];
    return ok(entries, `查询到 ${entries.length} 条日志`, Date.now() - start);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return fail('日志查询失败', msg, Date.now() - start);
  }
}
