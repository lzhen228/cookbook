import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fetchRiskAlerts, updateAlertStatus } from '@/api/alertCenter';
import type { RiskAlertQuery } from '@/types/alertCenter.types';
import type { RiskEventStatus } from '@/types/supplier.types';

/** 预警事项列表（含统计），30 秒内不重新请求 */
export function useRiskAlerts(params: RiskAlertQuery) {
  return useQuery({
    queryKey: ['riskAlerts', params],
    queryFn: () => fetchRiskAlerts(params),
    staleTime: 30 * 1000,
    placeholderData: (prev) => prev,
  });
}

/** 更新预警状态，成功后刷新列表 */
export function useUpdateAlertStatus() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: ({
      alertId,
      status,
      comment,
    }: {
      alertId: number;
      status: RiskEventStatus;
      comment?: string;
    }) => updateAlertStatus(alertId, status, comment),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['riskAlerts'] });
    },
  });
}
