import { useQuery } from '@tanstack/react-query';
import { fetchDashboard } from '@/api/dashboard';

/** 风险看板数据，5 分钟内不重新请求 */
export function useDashboard() {
  return useQuery({
    queryKey: ['dashboard'],
    queryFn: fetchDashboard,
    staleTime: 5 * 60 * 1000,
    refetchOnWindowFocus: false,
  });
}
