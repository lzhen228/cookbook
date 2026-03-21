import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { HealthBadge } from './index';

/**
 * HealthBadge 组件测试。
 *
 * 对齐 TECH_SPEC 健康等级枚举：high_risk / attention / low_risk
 * 对齐 constants/healthLevel.ts 配置的 label 映射。
 */
describe('HealthBadge Component', () => {
  // ==================== 正常场景 ====================

  it('should render high_risk badge with label "高风险"', () => {
    render(<HealthBadge level="high_risk" />);
    expect(screen.getByText('高风险')).toBeInTheDocument();
    expect(screen.getByTestId('health-badge')).toBeInTheDocument();
  });

  it('should render attention badge with label "需关注"', () => {
    render(<HealthBadge level="attention" />);
    expect(screen.getByText('需关注')).toBeInTheDocument();
    expect(screen.getByTestId('health-badge')).toBeInTheDocument();
  });

  it('should render low_risk badge with label "低风险"', () => {
    render(<HealthBadge level="low_risk" />);
    expect(screen.getByText('低风险')).toBeInTheDocument();
    expect(screen.getByTestId('health-badge')).toBeInTheDocument();
  });

  // ==================== 边界场景 ====================

  it('should render "未评分" when level is null', () => {
    render(<HealthBadge level={null} />);
    expect(screen.getByText('未评分')).toBeInTheDocument();
  });

  // ==================== data-testid ====================

  it('should have data-testid="health-badge" for styled badges', () => {
    render(<HealthBadge level="high_risk" />);
    const badge = screen.getByTestId('health-badge');
    expect(badge).toBeInTheDocument();
  });

  it('should NOT have data-testid when level is null (plain Tag)', () => {
    render(<HealthBadge level={null} />);
    expect(screen.queryByTestId('health-badge')).not.toBeInTheDocument();
  });
});
