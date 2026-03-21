import axios from 'axios';
import type { DevSkillsConfig } from '../config.js';
import type { DevSkillResult, ScoreJobResult, TriggerScoreJobParams } from '../types.js';
import { fail, ok, requirePositiveInt, withRetry, withTimeout } from '../utils.js';

/** 单批次大小上限 */
const MAX_BATCH_SIZE = 5000;

/** 单次任务处理 ID 范围上限 */
const MAX_RANGE = 100000;

/**
 * 触发批量供应商评分任务
 *
 * 向评分引擎发起批量健康分计算任务，按指定的 ID 范围和批次大小分批执行。
 * 任务提交后异步执行，返回 jobId 可用于后续状态查询。
 *
 * @param params - 任务参数
 * @param params.batchSize - 每批处理的供应商数量（1 ~ 5000）
 * @param params.startId - 供应商 ID 范围起始值（含）
 * @param params.endId - 供应商 ID 范围结束值（含）
 * @param config - SDK 配置
 * @returns 结构化结果，data 包含 jobId、预估耗时等
 *
 * @example
 * ```ts
 * const result = await triggerScoreJob({
 *   batchSize: 500,
 *   startId: 1,
 *   endId: 10000,
 * }, config);
 * if (result.success) {
 *   console.log('Job ID:', result.data.jobId);
 * }
 * ```
 */
export async function triggerScoreJob(
  params: TriggerScoreJobParams,
  config: DevSkillsConfig
): Promise<DevSkillResult<ScoreJobResult>> {
  const start = Date.now();

  try {
    const batchSize = requirePositiveInt(params.batchSize, 'batchSize');
    const startId = requirePositiveInt(params.startId, 'startId');
    const endId = requirePositiveInt(params.endId, 'endId');

    if (batchSize > MAX_BATCH_SIZE) {
      return fail(`batchSize 不能超过 ${MAX_BATCH_SIZE}，当前值: ${batchSize}`);
    }

    if (startId >= endId) {
      return fail(`startId (${startId}) 必须小于 endId (${endId})`);
    }

    const range = endId - startId + 1;
    if (range > MAX_RANGE) {
      return fail(
        `ID 范围过大（${range}），单次任务上限 ${MAX_RANGE}，请分多次提交`
      );
    }

    const totalSuppliers = range;
    const estimatedBatches = Math.ceil(totalSuppliers / batchSize);

    console.info(
      `[dev-skills] 触发评分任务: ID ${startId}-${endId}, ` +
      `共 ${totalSuppliers} 个供应商, ${estimatedBatches} 批`
    );

    const response = await withRetry(
      () =>
        withTimeout(
          axios.post<{ code: number; data: ScoreJobResult }>(
            `${config.apiHost}/api/v1/engine/score-jobs`,
            {
              batch_size: batchSize,
              start_id: startId,
              end_id: endId,
            },
            { timeout: config.requestTimeoutMs }
          ),
          config.requestTimeoutMs,
          '评分任务触发'
        ),
      config.maxRetries,
      1000,
      '评分任务触发'
    );

    const result = response.data.data;
    return ok(result, `评分任务已提交，jobId: ${result.jobId}`, Date.now() - start);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return fail('评分任务触发失败', msg, Date.now() - start);
  }
}
