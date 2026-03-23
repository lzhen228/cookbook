import apiClient from './client';
import type { ApiResponse } from '@/types/api.types';
import type { RiskAlertQuery, RiskAlertListResponse } from '@/types/alertCenter.types';
import type { RiskEventStatus } from '@/types/supplier.types';

/** 查询预警事项列表 */
export async function fetchRiskAlerts(params: RiskAlertQuery): Promise<RiskAlertListResponse> {
  const response = await apiClient.get<ApiResponse<RiskAlertListResponse>>('/risk-events', { params });
  return response.data.data;
}

/** 更新预警状态 */
export async function updateAlertStatus(
  alertId: number,
  status: RiskEventStatus,
  comment?: string,
): Promise<void> {
  await apiClient.patch(`/risk-events/${alertId}/status`, { status, comment });
}
