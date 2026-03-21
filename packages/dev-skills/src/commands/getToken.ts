import axios from 'axios';
import type { DevSkillsConfig } from '../config.js';
import type { DevSkillResult, TokenResult, TokenRole } from '../types.js';
import { fail, maskSensitive, ok, withRetry, withTimeout } from '../utils.js';

/** 合法角色集合 */
const VALID_ROLES: ReadonlySet<TokenRole> = new Set([
  'RISK_ADMIN',
  'RISK_ANALYST',
  'READER',
]);

/** 各角色对应的测试账号映射 */
const ROLE_CREDENTIALS: Record<TokenRole, { username: string; password: string }> = {
  RISK_ADMIN: { username: 'admin@scrm.test', password: 'test_admin_pwd' },
  RISK_ANALYST: { username: 'analyst@scrm.test', password: 'test_analyst_pwd' },
  READER: { username: 'reader@scrm.test', password: 'test_reader_pwd' },
};

/**
 * 获取指定角色的访问 Token
 *
 * 根据角色名从后端鉴权接口获取 Access Token 和 Refresh Token，
 * 用于后续 API 调用的鉴权。仅适用于 dev/test 环境。
 *
 * @param role - 目标角色（RISK_ADMIN / RISK_ANALYST / READER）
 * @param config - SDK 配置
 * @returns 结构化结果，data 包含 accessToken（已脱敏显示）、expiresIn 等
 *
 * @example
 * ```ts
 * const result = await getToken('RISK_ADMIN', config);
 * if (result.success) {
 *   console.log('Token:', result.data.accessToken);
 * }
 * ```
 */
export async function getToken(
  role: TokenRole,
  config: DevSkillsConfig
): Promise<DevSkillResult<TokenResult>> {
  const start = Date.now();

  try {
    if (!VALID_ROLES.has(role)) {
      return fail(
        `无效角色: ${String(role)}，允许值: ${[...VALID_ROLES].join(', ')}`
      );
    }

    const credentials = ROLE_CREDENTIALS[role];

    const response = await withRetry(
      () =>
        withTimeout(
          axios.post<{ code: number; data: TokenResult }>(
            `${config.apiHost}/api/v1/auth/login`,
            {
              username: credentials.username,
              password: credentials.password,
            },
            { timeout: config.requestTimeoutMs }
          ),
          config.requestTimeoutMs,
          'Token 获取'
        ),
      config.maxRetries,
      1000,
      'Token 获取'
    );

    const tokenData = response.data.data;

    console.info(
      `[dev-skills] 获取 ${role} Token 成功，` +
      `accessToken: ${maskSensitive(tokenData.accessToken)}, ` +
      `expiresIn: ${tokenData.expiresIn}s`
    );

    return ok(tokenData, `${role} Token 获取成功`, Date.now() - start);
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return fail('Token 获取失败', msg, Date.now() - start);
  }
}
