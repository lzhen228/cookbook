import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { fetchSupplierList, toggleSupplierFollow } from '@/api/supplier';
import type { SupplierListQuery } from '@/types/supplier.types';

const SUPPLIER_LIST_KEY = 'supplierList';

/** 供应商列表查询 Hook，封装 React Query 分页逻辑 */
export function useSupplierList(params: SupplierListQuery) {
  return useQuery({
    queryKey: [SUPPLIER_LIST_KEY, params],
    queryFn: () => fetchSupplierList(params),
    staleTime: 5 * 60 * 1000,
    placeholderData: (previousData) => previousData,
  });
}

/** 供应商关注/取关 Hook */
export function useToggleFollow() {
  const queryClient = useQueryClient();

  return useMutation({
    mutationFn: ({ supplierId, isFollowed }: { supplierId: number; isFollowed: boolean }) =>
      toggleSupplierFollow(supplierId, isFollowed),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: [SUPPLIER_LIST_KEY] });
    },
  });
}
