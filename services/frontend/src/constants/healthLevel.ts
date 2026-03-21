import type { HealthLevel, CooperationStatus, RiskDimension, RiskEventStatus } from '@/types/supplier.types';

/** 健康等级配置 */
export const HEALTH_LEVEL_CONFIG: Record<HealthLevel, { label: string; color: string }> = {
  high_risk: { label: '高风险', color: '#f5222d' },
  attention: { label: '需关注', color: '#fa8c16' },
  low_risk: { label: '低风险', color: '#52c41a' },
};

/** 合作状态配置 */
export const COOPERATION_STATUS_CONFIG: Record<CooperationStatus, { label: string }> = {
  cooperating: { label: '合作中' },
  potential: { label: '潜在' },
  qualified: { label: '合格' },
  blacklist: { label: '黑名单' },
  restricted: { label: '受限' },
};

/** 风险维度配置 */
export const RISK_DIMENSION_CONFIG: Record<RiskDimension, { label: string; color: string }> = {
  legal: { label: '司法风险', color: '#f5222d' },
  finance: { label: '财务风险', color: '#fa541c' },
  credit: { label: '信用风险', color: '#fa8c16' },
  tax: { label: '税务风险', color: '#faad14' },
  operation: { label: '经营风险', color: '#1890ff' },
};

/** 风险事项状态配置 */
export const RISK_EVENT_STATUS_CONFIG: Record<RiskEventStatus, { label: string; color: string }> = {
  open: { label: '待处理', color: '#f5222d' },
  confirmed: { label: '已确认', color: '#fa8c16' },
  processing: { label: '处理中', color: '#1890ff' },
  closed: { label: '已关闭', color: '#52c41a' },
  dismissed: { label: '已忽略', color: '#d9d9d9' },
};
