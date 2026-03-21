import apiClient from './client';
import type { ApiResponse, PaginatedData } from '@/types/api.types';
import type {
  SupplierListQuery,
  SupplierListItem,
  SupplierProfile,
  SupplierTabData,
  TabName,
} from '@/types/supplier.types';

/** 供应商列表查询 */
export async function fetchSupplierList(
  params: SupplierListQuery,
): Promise<PaginatedData<SupplierListItem>> {
  const response = await apiClient.get<ApiResponse<PaginatedData<SupplierListItem>>>(
    '/suppliers',
    { params },
  );
  return response.data.data;
}

/** 供应商画像主接口（首屏数据） */
export async function fetchSupplierProfile(supplierId: number): Promise<SupplierProfile> {
  const response = await apiClient.get<ApiResponse<SupplierProfile>>(
    `/suppliers/${supplierId}/profile`,
  );
  return response.data.data;
}

/** 供应商画像 Tab 懒加载 */
export async function fetchSupplierTab(
  supplierId: number,
  tabName: TabName,
): Promise<SupplierTabData> {
  const response = await apiClient.get<ApiResponse<SupplierTabData>>(
    `/suppliers/${supplierId}/tabs/${tabName}`,
  );
  return response.data.data;
}

/** 切换供应商关注状态 */
export async function toggleSupplierFollow(
  supplierId: number,
  isFollowed: boolean,
): Promise<void> {
  await apiClient.patch(`/suppliers/${supplierId}/follow`, { is_followed: isFollowed });
}

/** 获取报告预签名下载 URL */
export async function fetchReportDownloadUrl(
  supplierId: number,
): Promise<{ url: string; expires_at: string; filename: string }> {
  const response = await apiClient.get<
    ApiResponse<{ url: string; expires_at: string; filename: string }>
  >(`/suppliers/${supplierId}/reports/latest/download-url`);
  return response.data.data;
}

/** 触发健康报告生成 */
export async function triggerReportGeneration(
  supplierId: number,
): Promise<{ report_id: string; status: string; estimated_seconds: number }> {
  const response = await apiClient.post<
    ApiResponse<{ report_id: string; status: string; estimated_seconds: number }>
  >(`/suppliers/${supplierId}/reports`);
  return response.data.data;
}
