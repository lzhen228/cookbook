import axios from 'axios';
import type { ApiResponse } from '@/types/api.types';

const apiClient = axios.create({
  baseURL: '/api/v1',
  timeout: 10000,
  headers: {
    'Content-Type': 'application/json',
  },
});

/** 请求拦截器：注入 Access Token */
apiClient.interceptors.request.use((config) => {
  const token = window.__ACCESS_TOKEN__;
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

/** 响应拦截器：统一处理错误码 */
apiClient.interceptors.response.use(
  (response) => {
    const data = response.data as ApiResponse<unknown>;
    if (data.code !== 0) {
      return Promise.reject(new ApiError(data.code, data.msg, data.traceId));
    }
    return response;
  },
  (error) => {
    if (error.response?.status === 401) {
      window.location.href = '/login';
      return Promise.reject(error);
    }
    const data = error.response?.data as ApiResponse<unknown> | undefined;
    if (data) {
      return Promise.reject(new ApiError(data.code, data.msg, data.traceId));
    }
    return Promise.reject(error);
  },
);

/** 业务异常类 */
export class ApiError extends Error {
  code: number;
  traceId: string;

  constructor(code: number, message: string, traceId: string) {
    super(message);
    this.name = 'ApiError';
    this.code = code;
    this.traceId = traceId;
  }
}

/** Access Token 存储在内存中（禁止 localStorage），通过全局变量传递 */
declare global {
  interface Window {
    __ACCESS_TOKEN__?: string;
  }
}

export default apiClient;
