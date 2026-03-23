/** 供应商列表查询参数，对齐 TECH_SPEC 5.2 节 */
export interface SupplierListQuery {
  keyword?: string;
  health_level?: string;
  cooperation_status?: string;
  region_province?: string;
  listed_status?: string;
  is_china_top500?: boolean;
  is_world_top500?: boolean;
  supplier_type?: string;
  nature?: string;
  supply_items?: string;
  is_followed?: boolean;
  sort_by?: 'health_score' | 'name' | 'created_at';
  sort_order?: 'asc' | 'desc';
  cursor?: string;
  page?: number;
  page_size?: number;
}

/** 供应商列表单项，对齐 TECH_SPEC 5.2 节 items */
export interface SupplierListItem {
  id: number;
  name: string;
  health_level: HealthLevel | null;
  health_score: number | null;
  week_trend: number | null;
  region: string;
  cooperation_status: CooperationStatus;
  listed_status: string | null;
  is_followed: boolean;
  cache_updated_at: string | null;
}

/** 供应商画像主接口响应，对齐 TECH_SPEC 5.3 节 */
export interface SupplierProfile {
  basic: SupplierBasicInfo;
  health: SupplierHealthInfo;
  risk_events: RiskEventBrief[];
  risk_events_total: number;
}

/** 供应商基础信息 */
export interface SupplierBasicInfo {
  id: number;
  name: string;
  unified_code: string;
  cooperation_status: CooperationStatus;
  region: string;
  listed_status: string | null;
  is_china_top500: boolean;
  is_world_top500: boolean;
  supplier_type: string | null;
  nature: string | null;
  supply_items: string[];
  is_followed: boolean;
}

/** 健康评分卡 */
export interface SupplierHealthInfo {
  score: number | null;
  level: HealthLevel | null;
  snapshot_date: string | null;
  dimension_scores: Record<string, number> | null;
  report_status: ReportStatus;
  report_generated_at: string | null;
}

/** 风险事项摘要 */
export interface RiskEventBrief {
  id: number;
  risk_dimension: RiskDimension;
  description: string;
  status: RiskEventStatus;
  triggered_at: string;
  source_url: string | null;
}

/** Tab 懒加载响应，对齐 TECH_SPEC 5.4 节 */
export interface SupplierTabData {
  supplier_id: number;
  tab: TabName;
  data_source: string;
  data_as_of: string;
  is_stale: boolean;
  content: Record<string, unknown>;
}

/** 健康等级枚举 */
export type HealthLevel = 'high_risk' | 'attention' | 'low_risk';

/** 合作状态枚举 */
export type CooperationStatus =
  | 'cooperating'
  | 'potential'
  | 'qualified'
  | 'blacklist'
  | 'restricted';

/** 报告状态枚举 */
export type ReportStatus = 'not_generated' | 'generating' | 'ready' | 'failed';

/** 风险维度枚举 */
export type RiskDimension = 'legal' | 'finance' | 'credit' | 'tax' | 'operation';

/** 风险事项状态枚举 */
export type RiskEventStatus = 'open' | 'confirmed' | 'processing' | 'closed' | 'dismissed';

/** Tab 标识枚举 */
export type TabName = 'basic-info' | 'business-info' | 'judicial' | 'credit' | 'tax';

/** 基本信息 Tab 内容 */
export interface BasicInfoContent {
  legal_rep?: string;
  reg_capital?: string;
  establishment_date?: string;
  registered_address?: string;
  employees_count?: number;
  contact_phone?: string;
}

/** 经营信息 Tab 内容 */
export interface BusinessInfoContent {
  main_business?: string;
  annual_revenue?: string;
  shareholders?: Array<{
    name: string;
    share_ratio: string;
    contribution?: string;
  }>;
  branches?: Array<{
    name: string;
    address: string;
    status: string;
  }>;
}

/** 司法诉讼 Tab 内容 */
export interface JudicialContent {
  dishonest_count?: number;
  execution_count?: number;
  executions?: Array<{
    case_no: string;
    court: string;
    amount: string;
    status: string;
    date: string;
  }>;
  litigations?: Array<{
    title: string;
    court: string;
    role: string;
    amount?: string;
    status: string;
    date: string;
  }>;
}

/** 信用数据 Tab 内容 */
export interface CreditContent {
  credit_score?: number;
  rating?: string;
  rating_agency?: string;
  rating_date?: string;
  rating_outlook?: string;
  rating_history?: Array<{
    rating: string;
    agency: string;
    date: string;
    change: 'upgrade' | 'downgrade' | 'maintain';
  }>;
}

/** 税务信息 Tab 内容 */
export interface TaxContent {
  tax_payer_type?: string;
  tax_credit_level?: string;
  tax_credit_date?: string;
  owed_tax?: string;
  penalties?: Array<{
    type: string;
    amount: string;
    date: string;
    status: string;
    reason?: string;
  }>;
  abnormal_records?: Array<{
    type: string;
    date: string;
    reason: string;
    status: string;
  }>;
}
