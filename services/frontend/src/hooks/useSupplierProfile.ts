import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import {
  fetchSupplierProfile,
  fetchSupplierTab,
  fetchReportDownloadUrl,
  toggleSupplierFollow,
} from '@/api/supplier';
import type { TabName } from '@/types/supplier.types';

/** 供应商画像主接口 Hook（首屏核心数据） */
export function useSupplierProfile(supplierId: number) {
  return useQuery({
    queryKey: ['supplierProfile', supplierId],
    queryFn: () => fetchSupplierProfile(supplierId),
    enabled: supplierId > 0,
  });
}

/** 供应商画像 Tab 懒加载 Hook，切换 Tab 时触发 */
export function useSupplierTab(supplierId: number, tabName: TabName, enabled: boolean) {
  return useQuery({
    queryKey: ['supplierTab', supplierId, tabName],
    queryFn: () => fetchSupplierTab(supplierId, tabName),
    enabled: enabled && supplierId > 0,
    staleTime: 24 * 60 * 60 * 1000,
  });
}

/** 报告预签名下载 URL Hook */
export function useReportDownloadUrl(supplierId: number, enabled: boolean) {
  return useQuery({
    queryKey: ['reportDownloadUrl', supplierId],
    queryFn: () => fetchReportDownloadUrl(supplierId),
    enabled: enabled && supplierId > 0,
    staleTime: 10 * 60 * 1000,
  });
}

/** 供应商画像页关注/取关 Hook（成功后刷新画像缓存） */
export function useProfileFollow(supplierId: number) {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: (isFollowed: boolean) => toggleSupplierFollow(supplierId, isFollowed),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['supplierProfile', supplierId] });
    },
  });
}
