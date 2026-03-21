import { Tag } from 'antd';
import { HEALTH_LEVEL_CONFIG } from '@/constants/healthLevel';
import type { HealthLevel } from '@/types/supplier.types';

interface HealthBadgeProps {
  level: HealthLevel | null;
}

/** 健康等级标签组件 */
export function HealthBadge({ level }: HealthBadgeProps) {
  if (!level) {
    return <Tag>未评分</Tag>;
  }

  const config = HEALTH_LEVEL_CONFIG[level];
  return (
    <Tag data-testid="health-badge" color={config.color}>
      {config.label}
    </Tag>
  );
}
