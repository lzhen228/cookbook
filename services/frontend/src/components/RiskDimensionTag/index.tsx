import { Tag } from 'antd';
import { RISK_DIMENSION_CONFIG } from '@/constants/healthLevel';
import type { RiskDimension } from '@/types/supplier.types';

interface RiskDimensionTagProps {
  dimension: RiskDimension;
}

/** 风险维度标签组件 */
export function RiskDimensionTag({ dimension }: RiskDimensionTagProps) {
  const config = RISK_DIMENSION_CONFIG[dimension];
  if (!config) {
    return <Tag>{dimension}</Tag>;
  }
  return <Tag color={config.color}>{config.label}</Tag>;
}
