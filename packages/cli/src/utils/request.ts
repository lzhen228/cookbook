import axios from 'axios';
import type { AxiosInstance, InternalAxiosRequestConfig } from 'axios';
import { v4 as uuidv4 } from 'uuid';
import type { ApiResponse, EnvConfig } from '../types/index.js';
import { getAccessToken } from './auth.js';
import { logger } from './format.js';

const ENV_CONFIGS: Record<string, EnvConfig> = {
  dev: {
    baseUrl: 'http://localhost:8080/api/v1',
    authUrl: 'http://localhost:8080/api/v1',
  },
  test: {
    baseUrl: 'https://test-api.scrm.company.com/api/v1',
    authUrl: 'https://test-api.scrm.company.com/api/v1',
  },
  prod: {
    baseUrl: 'https://api.scrm.company.com/api/v1',
    authUrl: 'https://api.scrm.company.com/api/v1',
  },
};

/** 获取指定环境的配置 */
export function getEnvConfig(env: string): EnvConfig {
  const config = ENV_CONFIGS[env];
  if (!config) {
    throw new Error(
      `未知环境: ${env}，可选值: ${Object.keys(ENV_CONFIGS).join(', ')}`
    );
  }

  // 允许通过环境变量覆盖 baseUrl
  const overrideUrl = process.env['SCRM_CLI_BASE_URL'];
  if (overrideUrl) {
    logger.debug(`使用自定义 Base URL: ${overrideUrl}`);
    return { ...config, baseUrl: overrideUrl };
  }

  return config;
}

let httpClient: AxiosInstance | null = null;
let currentEnv = 'dev';

/** 初始化或获取 HTTP 客户端实例 */
export function getHttpClient(env: string): AxiosInstance {
  if (httpClient && currentEnv === env) {
    return httpClient;
  }

  const envConfig = getEnvConfig(env);
  currentEnv = env;

  httpClient = axios.create({
    baseURL: envConfig.baseUrl,
    timeout: 10_000,
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  });

  // 请求拦截器：注入 Token 和 TraceId
  httpClient.interceptors.request.use(
    async (config: InternalAxiosRequestConfig) => {
      const traceId = uuidv4();
      config.headers.set('X-Trace-Id', traceId);

      try {
        const token = await getAccessToken(env);
        config.headers.set('Authorization', `Bearer ${token}`);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        logger.warn(`获取 Token 失败: ${message}`);
      }

      logger.debug(
        `${config.method?.toUpperCase()} ${config.baseURL}${config.url} [traceId=${traceId}]`
      );
      return config;
    }
  );

  // 响应拦截器：统一错误处理
  httpClient.interceptors.response.use(
    (response) => {
      const traceId = response.config.headers?.['X-Trace-Id'] ?? 'unknown';
      logger.debug(
        `响应 ${response.status} [traceId=${traceId}]`
      );
      return response;
    },
    (error: unknown) => {
      if (axios.isAxiosError(error)) {
        const status = error.response?.status;
        const traceId =
          error.config?.headers?.['X-Trace-Id'] ?? 'unknown';
        const responseData = error.response?.data as
          | { msg?: string; code?: number }
          | undefined;

        if (status === 401) {
          logger.error(`认证失败 [traceId=${traceId}]，请检查凭据或重新登录`);
        } else if (status === 403) {
          logger.error(`权限不足 [traceId=${traceId}]`);
        } else if (status === 404) {
          logger.error(`资源不存在 [traceId=${traceId}]`);
        } else if (status && status >= 500) {
          logger.error(
            `服务端错误 ${status} [traceId=${traceId}]: ${responseData?.msg ?? '未知错误'}`
          );
        } else {
          logger.error(
            `请求失败 ${status ?? 'NETWORK_ERROR'} [traceId=${traceId}]: ${error.message}`
          );
        }
      } else {
        const message =
          error instanceof Error ? error.message : String(error);
        logger.error(`请求异常: ${message}`);
      }

      return Promise.reject(error);
    }
  );

  return httpClient;
}

/** 发起 GET 请求并提取 ApiResponse.data */
export async function apiGet<T>(
  env: string,
  path: string,
  params?: Record<string, unknown>
): Promise<T> {
  const client = getHttpClient(env);
  const response = await client.get<ApiResponse<T>>(path, { params });
  return response.data.data;
}

/** 发起 POST 请求并提取 ApiResponse.data */
export async function apiPost<T>(
  env: string,
  path: string,
  body?: Record<string, unknown>
): Promise<T> {
  const client = getHttpClient(env);
  const response = await client.post<ApiResponse<T>>(path, body);
  return response.data.data;
}
