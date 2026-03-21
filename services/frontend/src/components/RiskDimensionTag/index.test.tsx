import { describe, it, expect } from 'vitest';
import { render, screen } from '@testing-library/react';
import { RiskDimensionTag } from './index';
import type { RiskDimension } from '@/types/supplier.types';

/**
 * RiskDimensionTag 组件测试。
 *
 * 对齐 TECH_SPEC 风险维度枚举：legal / finance / credit / tax / operation
 * 对齐 constants/healthLevel.ts 的 RISK_DIMENSION_CONFIG 配置。
 */
describe('RiskDimensionTag Component', () => {
  // ==================== 所有枚举值 ====================

  const dimensionLabels: Record<RiskDimension, string> = {
    legal: '司法风险',
    finance: '财务风险',
    credit: '信用风险',
    tax: '税务风险',
    operation: '经营风险',
  };

  Object.entries(dimensionLabels).forEach(([dimension, label]) => {
    it(`should render "${label}" for dimension "${dimension}"`, () => {
      render(<RiskDimensionTag dimension={dimension as RiskDimension} />);
      expect(screen.getByText(label)).toBeInTheDocument();
    });
  });

  // ==================== 边界场景 ====================

  it('should render dimension string as-is when config not found', () => {
    // 使用类型断言模拟未知维度
    render(<RiskDimensionTag dimension={'unknown_dim' as RiskDimension} />);
    expect(screen.getByText('unknown_dim')).toBeInTheDocument();
  });
});
