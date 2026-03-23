/**
 * 测试 Mock 数据，对齐 TECH_SPEC 数据模型定义。
 * 供应商统一信用代码使用 91440300TEST 格式（CLAUDE.md 7.4 节）。
 */
import type {
  SupplierListItem,
  SupplierProfile,
  SupplierTabData,
  RiskEventBrief,
  BasicInfoContent,
  BusinessInfoContent,
  JudicialContent,
  CreditContent,
  TaxContent,
} from '@/types/supplier.types';
import type { PaginatedData } from '@/types/api.types';
import type {
  DashboardData,
  DashboardStats,
  HealthDistItem,
  RiskDimensionStat,
  RiskTrendPoint,
  TopRiskSupplier,
  DashboardRiskEvent,
} from '@/types/dashboard.types';
import type { RiskAlert, RiskAlertListResponse, RiskAlertStats } from '@/types/alertCenter.types';

// ==================== 供应商列表 ====================

export const mockSupplierListItem: SupplierListItem = {
  id: 1001,
  name: '深圳芯科半导体有限公司',
  health_level: 'high_risk',
  health_score: 32.5,
  week_trend: -3.2,
  region: '广东省 深圳市',
  cooperation_status: 'cooperating',
  listed_status: 'listed',
  is_followed: true,
  cache_updated_at: '2026-03-23T08:00:00+08:00',
};

export const mockAttentionSupplier: SupplierListItem = {
  id: 1002,
  name: '上海精工机械股份有限公司',
  health_level: 'attention',
  health_score: 45.0,
  week_trend: 1.5,
  region: '上海市 浦东新区',
  cooperation_status: 'cooperating',
  listed_status: 'listed',
  is_followed: false,
  cache_updated_at: '2026-03-23T08:00:00+08:00',
};

export const mockLowRiskSupplier: SupplierListItem = {
  id: 1005,
  name: '广州恒力电子有限公司',
  health_level: 'low_risk',
  health_score: 85.0,
  week_trend: 0.5,
  region: '广东省 广州市',
  cooperation_status: 'cooperating',
  listed_status: 'unlisted',
  is_followed: true,
  cache_updated_at: '2026-03-23T08:00:00+08:00',
};

export const mockUnscoredSupplier: SupplierListItem = {
  id: 1006,
  name: '成都天成新材料有限公司',
  health_level: null,
  health_score: null,
  week_trend: null,
  region: '四川省 成都市',
  cooperation_status: 'potential',
  listed_status: null,
  is_followed: false,
  cache_updated_at: null,
};

export const mockSupplierListResponse: PaginatedData<SupplierListItem> = {
  total: 10,
  page: 1,
  page_size: 20,
  next_cursor: null,
  items: [mockSupplierListItem, mockAttentionSupplier, mockLowRiskSupplier, mockUnscoredSupplier],
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
    description: '存在未结清执行案件，涉案金额 300 万',
    status: 'open',
    triggered_at: '2026-03-22T10:00:00+08:00',
    source_url: 'https://wenshu.court.gov.cn/example1',
  },
  {
    id: 102,
    risk_dimension: 'legal',
    description: '近期新增民事诉讼 2 起，涉案金额 150 万',
    status: 'confirmed',
    triggered_at: '2026-03-20T10:00:00+08:00',
    source_url: 'https://wenshu.court.gov.cn/example2',
  },
  {
    id: 103,
    risk_dimension: 'operation',
    description: '被列入经营异常名录',
    status: 'open',
    triggered_at: '2026-03-18T08:00:00+08:00',
    source_url: null,
  },
  {
    id: 104,
    risk_dimension: 'finance',
    description: '最近一期资产负债率达 82%，超出阈值',
    status: 'processing',
    triggered_at: '2026-03-15T10:00:00+08:00',
    source_url: null,
  },
  {
    id: 105,
    risk_dimension: 'tax',
    description: '增值税申报连续异常，已触发预警',
    status: 'open',
    triggered_at: '2026-03-10T08:00:00+08:00',
    source_url: null,
  },
];

// ==================== 供应商画像 ====================

export const mockSupplierProfile: SupplierProfile = {
  basic: {
    id: 1001,
    name: '深圳芯科半导体有限公司',
    unified_code: '91440300TEST00001',
    cooperation_status: 'cooperating',
    region: '广东省 深圳市',
    listed_status: 'listed',
    is_china_top500: false,
    is_world_top500: false,
    supplier_type: '供应商',
    nature: '民营企业',
    supply_items: ['半导体', '芯片'],
    is_followed: true,
  },
  health: {
    score: 32.5,
    level: 'high_risk',
    snapshot_date: '2026-03-23',
    dimension_scores: {
      legal: 10.0,
      finance: 45.0,
      credit: 60.0,
      tax: 80.0,
      operation: 30.0,
    },
    report_status: 'ready',
    report_generated_at: '2026-03-23T06:00:00+08:00',
  },
  risk_events: mockRiskEvents,
  risk_events_total: 7,
};

export const mockUnscoredProfile: SupplierProfile = {
  basic: {
    id: 1006,
    name: '成都天成新材料有限公司',
    unified_code: '91510100TEST00006',
    cooperation_status: 'potential',
    region: '四川省 成都市',
    listed_status: null,
    is_china_top500: false,
    is_world_top500: false,
    supplier_type: null,
    nature: '合资企业',
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

// ==================== Tab Mock 数据（各 Tab 独立内容） ====================

const mockBasicInfoContent: BasicInfoContent = {
  legal_rep: '陈志远',
  reg_capital: '5000 万元',
  establishment_date: '2012-03-15',
  registered_address: '广东省深圳市南山区科技园南区 A 栋 501 室',
  employees_count: 280,
  contact_phone: '0755-8888****',
};

const mockBusinessInfoContent: BusinessInfoContent = {
  main_business: '半导体芯片设计、封装、测试及销售',
  annual_revenue: '约 3.2 亿元（2025 年报）',
  shareholders: [
    { name: '陈志远', share_ratio: '35%', contribution: '1750 万元' },
    { name: '深圳科投集团有限公司', share_ratio: '20%', contribution: '1000 万元' },
    { name: '浦发硅谷银行股权投资基金', share_ratio: '15%', contribution: '750 万元' },
    { name: '其他自然人股东', share_ratio: '30%', contribution: '1500 万元' },
  ],
  branches: [
    { name: '上海芯科研发中心', address: '上海市浦东新区张江高科技园区', status: '正常' },
    { name: '北京芯科销售中心', address: '北京市海淀区中关村科技园', status: '正常' },
  ],
};

const mockJudicialContent: JudicialContent = {
  dishonest_count: 0,
  execution_count: 2,
  executions: [
    {
      case_no: '(2025)粤 0305 执 1234 号',
      court: '深圳市南山区人民法院',
      amount: '300 万元',
      status: '未结清',
      date: '2025-10-15',
    },
    {
      case_no: '(2025)粤 0305 执 2345 号',
      court: '深圳市南山区人民法院',
      amount: '150 万元',
      status: '未结清',
      date: '2025-11-20',
    },
  ],
  litigations: [
    {
      title: '买卖合同纠纷',
      court: '深圳市南山区人民法院',
      role: '被告',
      amount: '450 万元',
      status: '一审中',
      date: '2025-09-01',
    },
    {
      title: '货款追讨纠纷',
      court: '深圳市福田区人民法院',
      role: '原告',
      amount: '80 万元',
      status: '已调解',
      date: '2025-06-10',
    },
  ],
};

const mockCreditContent: CreditContent = {
  credit_score: 58,
  rating: 'A-',
  rating_agency: '联合信用评级有限公司',
  rating_date: '2025-06-15',
  rating_outlook: '负面',
  rating_history: [
    { rating: 'A+', agency: '联合信用评级有限公司', date: '2022-06-18', change: 'maintain' },
    { rating: 'AA-', agency: '联合信用评级有限公司', date: '2023-06-20', change: 'upgrade' },
    { rating: 'AA-', agency: '联合信用评级有限公司', date: '2024-06-10', change: 'maintain' },
    { rating: 'A-', agency: '联合信用评级有限公司', date: '2025-06-15', change: 'downgrade' },
  ],
};

const mockTaxContent: TaxContent = {
  tax_payer_type: '一般纳税人',
  tax_credit_level: 'B级',
  tax_credit_date: '2026-01-15',
  owed_tax: undefined,
  penalties: [],
  abnormal_records: [
    {
      type: '增值税申报异常',
      date: '2025-08-10',
      reason: '连续 3 个月零申报，与实际经营情况不符',
      status: '已处理',
    },
  ],
};

export const mockTabDataMap: Record<string, SupplierTabData> = {
  'basic-info': {
    supplier_id: 1001,
    tab: 'basic-info',
    data_source: 'erp',
    data_as_of: '2026-03-23T08:00:00+08:00',
    is_stale: false,
    content: mockBasicInfoContent as unknown as Record<string, unknown>,
  },
  'business-info': {
    supplier_id: 1001,
    tab: 'business-info',
    data_source: 'qcc',
    data_as_of: '2026-03-23T06:00:00+08:00',
    is_stale: false,
    content: mockBusinessInfoContent as unknown as Record<string, unknown>,
  },
  judicial: {
    supplier_id: 1001,
    tab: 'judicial',
    data_source: 'tianyancha',
    data_as_of: '2026-03-21T10:00:00+08:00',
    is_stale: true,
    content: mockJudicialContent as unknown as Record<string, unknown>,
  },
  credit: {
    supplier_id: 1001,
    tab: 'credit',
    data_source: 'pboc',
    data_as_of: '2026-03-23T06:00:00+08:00',
    is_stale: false,
    content: mockCreditContent as unknown as Record<string, unknown>,
  },
  tax: {
    supplier_id: 1001,
    tab: 'tax',
    data_source: 'tax_bureau',
    data_as_of: '2026-03-23T06:00:00+08:00',
    is_stale: false,
    content: mockTaxContent as unknown as Record<string, unknown>,
  },
};

// 保留旧名称以兼容已有测试
export const mockTabData = mockTabDataMap['basic-info'];
export const mockStaleTabData = mockTabDataMap['judicial'];

// 旧列表 mock 别名
export const mockSupplierListItem_legacy = mockSupplierListItem;
export const mockHighRiskSupplier = mockSupplierListItem;

// ==================== 风险看板 ====================

const mockDashboardStats: DashboardStats = {
  total_suppliers: 10,
  cooperating_count: 7,
  high_risk_count: 3,
  attention_count: 2,
  low_risk_count: 4,
  unscored_count: 1,
  pending_risk_events: 8,
  new_events_7d: 5,
};

const mockHealthDistribution: HealthDistItem[] = [
  { level: 'high_risk', count: 3, percentage: 30 },
  { level: 'attention', count: 2, percentage: 20 },
  { level: 'low_risk', count: 4, percentage: 40 },
  { level: 'unscored', count: 1, percentage: 10 },
];

const mockRiskDimensionStats: RiskDimensionStat[] = [
  { dimension: 'legal', open_count: 3, avg_score: 20.0 },
  { dimension: 'finance', open_count: 2, avg_score: 45.0 },
  { dimension: 'operation', open_count: 1, avg_score: 35.0 },
  { dimension: 'credit', open_count: 1, avg_score: 58.0 },
  { dimension: 'tax', open_count: 1, avg_score: 70.0 },
];

const mockRiskTrend: RiskTrendPoint[] = [
  { date: '03-10', high_risk_count: 2, new_events: 1 },
  { date: '03-11', high_risk_count: 2, new_events: 0 },
  { date: '03-12', high_risk_count: 2, new_events: 2 },
  { date: '03-13', high_risk_count: 3, new_events: 1 },
  { date: '03-14', high_risk_count: 3, new_events: 0 },
  { date: '03-15', high_risk_count: 3, new_events: 1 },
  { date: '03-16', high_risk_count: 3, new_events: 0 },
  { date: '03-17', high_risk_count: 3, new_events: 0 },
  { date: '03-18', high_risk_count: 3, new_events: 1 },
  { date: '03-19', high_risk_count: 3, new_events: 2 },
  { date: '03-20', high_risk_count: 3, new_events: 1 },
  { date: '03-21', high_risk_count: 3, new_events: 0 },
  { date: '03-22', high_risk_count: 3, new_events: 1 },
  { date: '03-23', high_risk_count: 3, new_events: 0 },
];

const mockTopRiskSuppliers: TopRiskSupplier[] = [
  {
    id: 1001,
    name: '深圳芯科半导体有限公司',
    health_score: 32.5,
    health_level: 'high_risk',
    region: '广东省 深圳市',
    week_trend: -3.2,
    top_dimension: 'legal',
    open_events: 5,
  },
  {
    id: 1003,
    name: '北京华芯微电子科技有限公司',
    health_score: 38.0,
    health_level: 'high_risk',
    region: '北京市 海淀区',
    week_trend: -1.5,
    top_dimension: 'finance',
    open_events: 3,
  },
  {
    id: 1004,
    name: '苏州纳图光电科技有限公司',
    health_score: 41.5,
    health_level: 'high_risk',
    region: '江苏省 苏州市',
    week_trend: 0,
    top_dimension: 'operation',
    open_events: 2,
  },
  {
    id: 1002,
    name: '上海精工机械股份有限公司',
    health_score: 45.0,
    health_level: 'attention',
    region: '上海市 浦东新区',
    week_trend: 1.5,
    top_dimension: 'credit',
    open_events: 1,
  },
  {
    id: 1007,
    name: '武汉智晟材料科技有限公司',
    health_score: 48.0,
    health_level: 'attention',
    region: '湖北省 武汉市',
    week_trend: -0.5,
    top_dimension: 'tax',
    open_events: 2,
  },
];

const mockRecentEvents: DashboardRiskEvent[] = [
  {
    id: 101,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'legal',
    description: '存在未结清执行案件，涉案金额 300 万',
    status: 'open',
    triggered_at: '2026-03-22T10:00:00+08:00',
  },
  {
    id: 102,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'legal',
    description: '近期新增民事诉讼 2 起，涉案金额 150 万',
    status: 'confirmed',
    triggered_at: '2026-03-20T10:00:00+08:00',
  },
  {
    id: 106,
    supplier_id: 1003,
    supplier_name: '北京华芯微电子科技有限公司',
    risk_dimension: 'finance',
    description: '资产负债率超过预警阈值 80%，当前值 84.3%',
    status: 'open',
    triggered_at: '2026-03-20T08:00:00+08:00',
  },
  {
    id: 103,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'operation',
    description: '被列入经营异常名录',
    status: 'open',
    triggered_at: '2026-03-18T08:00:00+08:00',
  },
  {
    id: 107,
    supplier_id: 1004,
    supplier_name: '苏州纳图光电科技有限公司',
    risk_dimension: 'operation',
    description: '主要客户流失超 30%，经营风险升级',
    status: 'confirmed',
    triggered_at: '2026-03-17T14:00:00+08:00',
  },
  {
    id: 104,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'finance',
    description: '最近一期资产负债率达 82%，超出阈值',
    status: 'processing',
    triggered_at: '2026-03-15T10:00:00+08:00',
  },
  {
    id: 108,
    supplier_id: 1007,
    supplier_name: '武汉智晟材料科技有限公司',
    risk_dimension: 'tax',
    description: '增值税申报连续 3 个月异常，已触发税务预警',
    status: 'open',
    triggered_at: '2026-03-12T09:00:00+08:00',
  },
  {
    id: 105,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'tax',
    description: '增值税申报连续异常，已触发预警',
    status: 'open',
    triggered_at: '2026-03-10T08:00:00+08:00',
  },
];

export const mockDashboardData: DashboardData = {
  stats: mockDashboardStats,
  health_distribution: mockHealthDistribution,
  risk_dimension_stats: mockRiskDimensionStats,
  risk_trend: mockRiskTrend,
  top_risk_suppliers: mockTopRiskSuppliers,
  recent_events: mockRecentEvents,
};

// ==================== 预警中心 ====================

export const mockRiskAlerts: RiskAlert[] = [
  {
    id: 201,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'legal',
    description: '存在未结清执行案件，涉案金额 300 万元，案号 (2025)粤 0305 执 1234 号',
    status: 'open',
    triggered_at: '2026-03-22T10:00:00+08:00',
    updated_at: '2026-03-22T10:00:00+08:00',
    source_url: 'https://wenshu.court.gov.cn/example1',
    handler: null,
    comment: null,
  },
  {
    id: 202,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'legal',
    description: '新增民事诉讼 2 起，涉案总金额 150 万元，均为买卖合同纠纷',
    status: 'confirmed',
    triggered_at: '2026-03-20T10:00:00+08:00',
    updated_at: '2026-03-21T09:00:00+08:00',
    source_url: 'https://wenshu.court.gov.cn/example2',
    handler: '张三',
    comment: null,
  },
  {
    id: 203,
    supplier_id: 1003,
    supplier_name: '北京华芯微电子科技有限公司',
    risk_dimension: 'finance',
    description: '资产负债率达 84.3%，超过预警阈值 80%，流动性风险上升',
    status: 'open',
    triggered_at: '2026-03-20T08:00:00+08:00',
    updated_at: '2026-03-20T08:00:00+08:00',
    source_url: null,
    handler: null,
    comment: null,
  },
  {
    id: 204,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'operation',
    description: '被列入经营异常名录，原因：未按规定期限公示年度报告',
    status: 'processing',
    triggered_at: '2026-03-18T08:00:00+08:00',
    updated_at: '2026-03-19T14:00:00+08:00',
    source_url: null,
    handler: '李四',
    comment: '已联系供应商，对方承诺本月内完成整改',
  },
  {
    id: 205,
    supplier_id: 1004,
    supplier_name: '苏州纳图光电科技有限公司',
    risk_dimension: 'operation',
    description: '主要客户华为采购份额下降 35%，经营收入受影响',
    status: 'confirmed',
    triggered_at: '2026-03-17T14:00:00+08:00',
    updated_at: '2026-03-18T10:00:00+08:00',
    source_url: null,
    handler: '张三',
    comment: null,
  },
  {
    id: 206,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'finance',
    description: '最近一期资产负债率达 82%，较上期增加 5 个百分点，超出预警阈值',
    status: 'processing',
    triggered_at: '2026-03-15T10:00:00+08:00',
    updated_at: '2026-03-16T11:00:00+08:00',
    source_url: null,
    handler: '李四',
    comment: '要求供应商提供财务说明报告',
  },
  {
    id: 207,
    supplier_id: 1007,
    supplier_name: '武汉智晟材料科技有限公司',
    risk_dimension: 'tax',
    description: '增值税申报连续 3 个月异常，已被税务局标记为重点核查对象',
    status: 'open',
    triggered_at: '2026-03-12T09:00:00+08:00',
    updated_at: '2026-03-12T09:00:00+08:00',
    source_url: null,
    handler: null,
    comment: null,
  },
  {
    id: 208,
    supplier_id: 1001,
    supplier_name: '深圳芯科半导体有限公司',
    risk_dimension: 'tax',
    description: '增值税申报连续异常，零申报持续 3 月，与实际出货量不符',
    status: 'open',
    triggered_at: '2026-03-10T08:00:00+08:00',
    updated_at: '2026-03-10T08:00:00+08:00',
    source_url: null,
    handler: null,
    comment: null,
  },
  {
    id: 209,
    supplier_id: 1002,
    supplier_name: '上海精工机械股份有限公司',
    risk_dimension: 'credit',
    description: '信用评级由 AA- 下调至 A-，评级展望为负面，下调原因：订单萎缩、盈利下降',
    status: 'confirmed',
    triggered_at: '2026-03-08T10:00:00+08:00',
    updated_at: '2026-03-09T08:00:00+08:00',
    source_url: null,
    handler: '王五',
    comment: null,
  },
  {
    id: 210,
    supplier_id: 1003,
    supplier_name: '北京华芯微电子科技有限公司',
    risk_dimension: 'legal',
    description: '新增行政处罚记录：因违反进出口管理规定被罚款 50 万元',
    status: 'processing',
    triggered_at: '2026-03-05T14:00:00+08:00',
    updated_at: '2026-03-06T09:00:00+08:00',
    source_url: 'https://gsxt.samr.gov.cn/example',
    handler: '张三',
    comment: '处罚已缴纳，等待整改报告',
  },
  {
    id: 211,
    supplier_id: 1004,
    supplier_name: '苏州纳图光电科技有限公司',
    risk_dimension: 'finance',
    description: '应收账款周转率下降至 3.2 次/年，较行业均值低 40%',
    status: 'open',
    triggered_at: '2026-03-03T09:00:00+08:00',
    updated_at: '2026-03-03T09:00:00+08:00',
    source_url: null,
    handler: null,
    comment: null,
  },
  {
    id: 212,
    supplier_id: 1005,
    supplier_name: '广州恒力电子有限公司',
    risk_dimension: 'operation',
    description: '关键管理人员变动：技术总监离职，短期内可能影响产品交付能力',
    status: 'dismissed',
    triggered_at: '2026-02-28T10:00:00+08:00',
    updated_at: '2026-03-01T11:00:00+08:00',
    source_url: null,
    handler: '王五',
    comment: '已与供应商确认，已有候补人员接任，风险可控，忽略此预警',
  },
  {
    id: 213,
    supplier_id: 1002,
    supplier_name: '上海精工机械股份有限公司',
    risk_dimension: 'operation',
    description: '主要生产设备出现故障，预计影响未来 2 周交货计划',
    status: 'closed',
    triggered_at: '2026-02-20T08:00:00+08:00',
    updated_at: '2026-03-02T16:00:00+08:00',
    source_url: null,
    handler: '李四',
    comment: '设备已修复，供应商恢复正常生产，关闭此预警',
  },
  {
    id: 214,
    supplier_id: 1007,
    supplier_name: '武汉智晟材料科技有限公司',
    risk_dimension: 'credit',
    description: '企业征信报告出现逾期还款记录，涉及金额 120 万元，已逾期 90 天',
    status: 'closed',
    triggered_at: '2026-02-15T10:00:00+08:00',
    updated_at: '2026-02-28T15:00:00+08:00',
    source_url: null,
    handler: '张三',
    comment: '供应商已完成还款，征信记录已更新，关闭预警',
  },
  {
    id: 215,
    supplier_id: 1005,
    supplier_name: '广州恒力电子有限公司',
    risk_dimension: 'legal',
    description: '被客户提起劳动仲裁，涉及 12 名员工，要求支付加班费约 30 万元',
    status: 'dismissed',
    triggered_at: '2026-02-10T09:00:00+08:00',
    updated_at: '2026-02-12T14:00:00+08:00',
    source_url: null,
    handler: '王五',
    comment: '金额较小且已与员工达成调解协议，风险评估为低，忽略',
  },
];

const mockAlertStats: RiskAlertStats = {
  total: mockRiskAlerts.length,
  open: mockRiskAlerts.filter((a) => a.status === 'open').length,
  confirmed: mockRiskAlerts.filter((a) => a.status === 'confirmed').length,
  processing: mockRiskAlerts.filter((a) => a.status === 'processing').length,
  closed: mockRiskAlerts.filter((a) => a.status === 'closed').length,
  dismissed: mockRiskAlerts.filter((a) => a.status === 'dismissed').length,
};

export const mockRiskAlertListResponse: RiskAlertListResponse = {
  stats: mockAlertStats,
  items: mockRiskAlerts,
  total: mockRiskAlerts.length,
  page: 1,
  page_size: 20,
};
