import axios from 'axios';
import type { DevSkillsConfig } from '../config.js';
import type { DevSkillResult, RestartResult, RestartServiceParams, ServiceEnv } from '../types.js';
import { fail, ok, requireString, withRetry, withTimeout } from '../utils.js';

/** 允许操作的环境列表 — 禁止操作生产环境 */
const ALLOWED_ENVS: ReadonlySet<ServiceEnv> = new Set(['dev', 'test', 'staging']);

/** 已知的服务名列表 */
const KNOWN_SERVICES: ReadonlySet<string> = new Set([
  'scrm-api',
  'scrm-frontend',
  'scrm-engine',
  'scrm-notification',
  'scrm-scheduler',
]);

/**
 * 重启指定服务
 *
 * 向运维管理接口发送服务重启指令（模拟 docker-compose restart）。
 * 安全限制：仅允许 dev/test/staging 环境操作，禁止对 prod 执行重启。
 *
 * @param params - 重启参数
 * @param params.serviceName - 服务名称（如 scrm-api、scrm-engine 等）
 * @param params.env - 目标环境（dev / test / staging）
 * @param config - SDK 配置
 * @returns 结构化结果，data 包含重启状态和容器 ID
 *
 * @example
 * ```ts
 * const result = await restartService({
 *   serviceName: 'scrm-api',
 *   env: 'dev',
 * }, config);
 * ```
 */
export async function restartService(
  params: RestartServiceParams,
  config: DevSkillsConfig
): Promise<DevSkillResult<RestartResult>> {
  const start = Date.now();

  try {
    const serviceName = requireString(params.serviceName, 'serviceName');
    const env = requireString(params.env, 'env') as ServiceEnv;

    if (!ALLOWED_ENVS.has(env)) {
      return fail(
        `禁止在 ${env} 环境执行重启操作，仅允许: ${[...ALLOWED_ENVS].join(', ')}`
      );
    }

    if (!KNOWN_SERVICES.has(serviceName)) {
      return fail(
        `未知服务: ${serviceName}，已知服务: ${[...KNOWN_SERVICES].join(', ')}`
      );
    }

    console.info(`[dev-skills] 正在重启 ${env}/${serviceName} ...`);

    const response = await withRetry(
      () =>
        withTimeout(
          axios.post<{ code: number; data: RestartResult }>(
            `${config.apiHost}/api/v1/ops/services/restart`,
            { service_name: serviceName, env },
            { timeout: 30000 }
          ),
          30000,
          '服务重启'
        ),
      2,
      2000,
      '服务重启'
    );

    const result = response.data.data;
    return ok(result, `${serviceName} 在 ${env} 环境重启成功`, Date.now() - start);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return fail('服务重启失败', msg, Date.now() - start);
  }
}
