import apiClient from './client';
import type { ApiResponse } from '@/types/api.types';
import type { DashboardData } from '@/types/dashboard.types';

/** 获取风险看板数据 */
export async function fetchDashboard(): Promise<DashboardData> {
  const response = await apiClient.get<ApiResponse<DashboardData>>('/dashboard');
  return response.data.data;
}
