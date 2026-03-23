import type { RiskDimension, RiskEventStatus } from './supplier.types';

/** 预警事项完整记录（含供应商名称） */
export interface RiskAlert {
  id: number;
  supplier_id: number;
  supplier_name: string;
  risk_dimension: RiskDimension;
  description: string;
  status: RiskEventStatus;
  triggered_at: string;
  updated_at: string;
  source_url: string | null;
  handler: string | null;
  comment: string | null;
}

/** 预警列表查询参数 */
export interface RiskAlertQuery {
  status?: RiskEventStatus;
  risk_dimension?: RiskDimension;
  keyword?: string;
  page?: number;
  page_size?: number;
}

/** 预警状态分布统计 */
export interface RiskAlertStats {
  total: number;
  open: number;
  confirmed: number;
  processing: number;
  closed: number;
  dismissed: number;
}

/** 预警列表响应（含统计） */
export interface RiskAlertListResponse {
  stats: RiskAlertStats;
  items: RiskAlert[];
  total: number;
  page: number;
  page_size: number;
}
