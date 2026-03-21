import type { DevSkillResult } from './types.js';

/**
 * 构造成功结果
 *
 * @param data 返回数据
 * @param message 描述信息
 * @param duration 耗时（毫秒）
 */
export function ok<T>(data: T, message: string, duration?: number): DevSkillResult<T> {
  return {
    success: true,
    data,
    message,
    timestamp: new Date().toISOString(),
    duration,
  };
}

/**
 * 构造失败结果
 *
 * @param message 错误描述
 * @param error 原始错误信息
 * @param duration 耗时（毫秒）
 */
export function fail<T = unknown>(message: string, error?: string, duration?: number): DevSkillResult<T> {
  return {
    success: false,
    data: null,
    message,
    error,
    timestamp: new Date().toISOString(),
    duration,
  };
}

/**
 * 敏感信息脱敏：对密码、Token、密钥等关键字段进行遮蔽
 *
 * @param value 原始字符串
 * @param visibleChars 前后各保留的字符数，默认 3
 */
export function maskSensitive(value: string, visibleChars: number = 3): string {
  if (value.length <= visibleChars * 2) {
    return '*'.repeat(value.length);
  }
  const prefix = value.slice(0, visibleChars);
  const suffix = value.slice(-visibleChars);
  return `${prefix}${'*'.repeat(value.length - visibleChars * 2)}${suffix}`;
}

/**
 * 对 SQL 语句中的敏感参数进行脱敏处理
 *
 * @param sql 原始 SQL
 */
export function maskSql(sql: string): string {
  return sql
    .replace(/password\s*=\s*'[^']*'/gi, "password='***'")
    .replace(/secret\s*=\s*'[^']*'/gi, "secret='***'")
    .replace(/token\s*=\s*'[^']*'/gi, "token='***'");
}

/**
 * 带超时控制的 Promise 包装
 *
 * @param promise 原始 Promise
 * @param timeoutMs 超时时间（毫秒）
 * @param label 操作标签，用于错误提示
 */
export function withTimeout<T>(
  promise: Promise<T>,
  timeoutMs: number,
  label: string = 'operation'
): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const timer = setTimeout(() => {
      reject(new Error(`${label} 超时（${timeoutMs}ms）`));
    }, timeoutMs);

    promise
      .then((result) => {
        clearTimeout(timer);
        resolve(result);
      })
      .catch((err) => {
        clearTimeout(timer);
        reject(err);
      });
  });
}

/**
 * 带指数退避的重试机制
 *
 * @param fn 待重试的异步函数
 * @param maxRetries 最大重试次数
 * @param baseDelayMs 基础延迟时间（毫秒）
 * @param label 操作标签，用于日志
 */
export async function withRetry<T>(
  fn: () => Promise<T>,
  maxRetries: number = 3,
  baseDelayMs: number = 1000,
  label: string = 'operation'
): Promise<T> {
  let lastError: Error | undefined;

  for (let attempt = 0; attempt <= maxRetries; attempt++) {
    try {
      return await fn();
    } catch (err) {
      lastError = err instanceof Error ? err : new Error(String(err));
      if (attempt < maxRetries) {
        const delay = baseDelayMs * Math.pow(2, attempt);
        console.warn(`[dev-skills] ${label} 第 ${attempt + 1} 次重试，${delay}ms 后重试...`);
        await new Promise((r) => setTimeout(r, delay));
      }
    }
  }

  throw lastError;
}

/** 校验字符串参数非空 */
export function requireString(value: unknown, name: string): string {
  if (typeof value !== 'string' || value.trim().length === 0) {
    throw new Error(`参数 ${name} 不能为空`);
  }
  return value.trim();
}

/** 校验正整数 */
export function requirePositiveInt(value: unknown, name: string): number {
  const num = Number(value);
  if (!Number.isInteger(num) || num <= 0) {
    throw new Error(`参数 ${name} 必须是正整数，当前值: ${String(value)}`);
  }
  return num;
}
