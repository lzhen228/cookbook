/**
 * 测试 Mock 数据，对齐 TECH_SPEC 数据模型定义。
 * 供应商统一信用代码使用 91440300TEST 格式（CLAUDE.md 7.4 节）。
 */
import type {
  SupplierListItem,
  SupplierProfile,
  SupplierTabData,
  RiskEventBrief,
} from '@/types/supplier.types';
import type { PaginatedData } from '@/types/api.types';

// ==================== 供应商列表 ====================

export const mockSupplierListItem: SupplierListItem = {
  id: 1001,
  name: '测试供应商A',
  health_level: 'low_risk',
  health_score: 85.5,
  week_trend: 2.3,
  region: '广东 深圳',
  cooperation_status: 'cooperating',
  listed_status: 'listed',
  is_followed: true,
  cache_updated_at: '2026-03-20T10:00:00+08:00',
};

export const mockHighRiskSupplier: SupplierListItem = {
  id: 1002,
  name: '测试供应商B',
  health_level: 'high_risk',
  health_score: 25.0,
  week_trend: -5.2,
  region: '北京',
  cooperation_status: 'restricted',
  listed_status: 'unlisted',
  is_followed: false,
  cache_updated_at: '2026-03-20T08:00:00+08:00',
};

export const mockUnscoredSupplier: SupplierListItem = {
  id: 1003,
  name: '测试供应商C',
  health_level: null,
  health_score: null,
  week_trend: null,
  region: '上海 浦东',
  cooperation_status: 'potential',
  listed_status: null,
  is_followed: false,
  cache_updated_at: null,
};

export const mockSupplierListResponse: PaginatedData<SupplierListItem> = {
  total: 3,
  page: 1,
  page_size: 20,
  next_cursor: null,
  items: [mockSupplierListItem, mockHighRiskSupplier, mockUnscoredSupplier],
};

export const mockEmptyListResponse: PaginatedData<SupplierListItem> = {
  total: 0,
  page: 1,
  page_size: 20,
  next_cursor: null,
  items: [],
};

// ==================== 风险事项 ====================

export const mockRiskEvents: RiskEventBrief[] = [
  {
    id: 101,
    risk_dimension: 'legal',
    description: '被列为失信被执行人',
    status: 'open',
    triggered_at: '2026-03-20T08:00:00+08:00',
    source_url: 'https://example.com/case/12345',
  },
  {
    id: 102,
    risk_dimension: 'finance',
    description: '年度审计报告出具保留意见',
    status: 'processing',
    triggered_at: '2026-03-19T10:00:00+08:00',
    source_url: null,
  },
  {
    id: 103,
    risk_dimension: 'tax',
    description: '税务行政处罚',
    status: 'closed',
    triggered_at: '2026-03-13T08:00:00+08:00',
    source_url: 'https://example.com/tax/penalty',
  },
];

// ==================== 供应商画像 ====================

export const mockSupplierProfile: SupplierProfile = {
  basic: {
    id: 1001,
    name: '测试供应商A',
    unified_code: '91440300TEST00001',
    cooperation_status: 'cooperating',
    region: '广东 深圳',
    listed_status: 'listed',
    is_china_top500: true,
    is_world_top500: false,
    supplier_type: '原材料',
    nature: '民营企业',
    supply_items: ['钢材', '铝材'],
    is_followed: true,
  },
  health: {
    score: 85.5,
    level: 'low_risk',
    snapshot_date: '2026-03-20',
    dimension_scores: {
      legal: 90.0,
      finance: 80.0,
      credit: 88.0,
      tax: 85.0,
      operation: 84.0,
    },
    report_status: 'ready',
    report_generated_at: '2026-03-20T06:00:00+08:00',
  },
  risk_events: mockRiskEvents.slice(0, 2),
  risk_events_total: 10,
};

export const mockUnscoredProfile: SupplierProfile = {
  basic: {
    id: 1003,
    name: '测试供应商C',
    unified_code: '91440300TEST00003',
    cooperation_status: 'potential',
    region: '上海 浦东',
    listed_status: null,
    is_china_top500: false,
    is_world_top500: false,
    supplier_type: null,
    nature: null,
    supply_items: [],
    is_followed: false,
  },
  health: {
    score: null,
    level: null,
    snapshot_date: null,
    dimension_scores: null,
    report_status: 'not_generated',
    report_generated_at: null,
  },
  risk_events: [],
  risk_events_total: 0,
};

// ==================== Tab 懒加载 ====================

export const mockTabData: SupplierTabData = {
  supplier_id: 1001,
  tab: 'basic-info',
  data_source: 'erp',
  data_as_of: '2026-03-20T10:00:00+08:00',
  is_stale: false,
  content: {
    legal_rep: '张三',
    reg_capital: '5000万',
    establishment_date: '2010-01-15',
  },
};

export const mockStaleTabData: SupplierTabData = {
  supplier_id: 1001,
  tab: 'judicial',
  data_source: 'tianyancha',
  data_as_of: '2026-03-18T10:00:00+08:00',
  is_stale: true,
  content: {
    cases: [{ title: '合同纠纷', court: '深圳中院' }],
  },
};
