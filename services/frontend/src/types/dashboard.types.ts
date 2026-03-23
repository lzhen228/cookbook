import type { HealthLevel, RiskDimension, RiskEventStatus } from './supplier.types';

/** 看板核心统计指标 */
export interface DashboardStats {
  total_suppliers: number;
  cooperating_count: number;
  high_risk_count: number;
  attention_count: number;
  low_risk_count: number;
  unscored_count: number;
  pending_risk_events: number;
  new_events_7d: number;
}

/** 健康等级分布项 */
export interface HealthDistItem {
  level: HealthLevel | 'unscored';
  count: number;
  percentage: number;
}

/** 风险维度统计 */
export interface RiskDimensionStat {
  dimension: RiskDimension;
  open_count: number;
  avg_score: number;
}

/** 风险趋势数据点（按日） */
export interface RiskTrendPoint {
  date: string;
  high_risk_count: number;
  new_events: number;
}

/** 高风险供应商排行项 */
export interface TopRiskSupplier {
  id: number;
  name: string;
  health_score: number;
  health_level: HealthLevel;
  region: string;
  week_trend: number | null;
  top_dimension: RiskDimension;
  open_events: number;
}

/** 看板用风险事项（含供应商名称） */
export interface DashboardRiskEvent {
  id: number;
  supplier_id: number;
  supplier_name: string;
  risk_dimension: RiskDimension;
  description: string;
  status: RiskEventStatus;
  triggered_at: string;
}

/** 风险看板完整响应 */
export interface DashboardData {
  stats: DashboardStats;
  health_distribution: HealthDistItem[];
  risk_dimension_stats: RiskDimensionStat[];
  risk_trend: RiskTrendPoint[];
  top_risk_suppliers: TopRiskSupplier[];
  recent_events: DashboardRiskEvent[];
}
