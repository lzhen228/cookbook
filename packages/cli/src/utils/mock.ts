import type {
  SupplierProfile,
  HealthSnapshot,
  HealthReport,
  AlertItem,
  PageResult,
} from '../types/index.js';

export function mockSupplierProfile(supplierId: number): SupplierProfile {
  return {
    id: supplierId,
    name: '深圳市测试供应链有限公司',
    unifiedCreditCode: '91440300TEST00001',
    cooperationStatus: 'cooperating',
    healthScore: 72.5,
    healthLevel: 'medium_risk',
    industryCategory: '电子元器件',
    registeredCapital: '5000万人民币',
    contactPerson: '张三',
    contactPhone: '13800138000',
    createdAt: '2025-06-15T10:30:00Z',
    updatedAt: '2026-03-20T14:22:00Z',
  };
}

export function mockHealthSnapshot(supplierId: number): HealthSnapshot {
  return {
    supplierId,
    supplierName: '深圳市测试供应链有限公司',
    healthScore: 72.5,
    healthLevel: 'medium_risk',
    snapshotDate: '2026-03-21',
    planId: 1,
    planName: '默认预警方案',
    indicators: [
      {
        indicatorId: 1,
        indicatorName: '工商变更频率',
        category: '经营风险',
        score: 60,
        weight: 0.2,
        isRedline: false,
        triggered: false,
        detail: '近6个月变更2次',
      },
      {
        indicatorId: 2,
        indicatorName: '法律诉讼数量',
        category: '法律风险',
        score: 45,
        weight: 0.15,
        isRedline: false,
        triggered: true,
        detail: '存在3起未结诉讼',
      },
      {
        indicatorId: 3,
        indicatorName: '严重违法记录',
        category: '合规风险',
        score: 100,
        weight: 0.25,
        isRedline: true,
        triggered: false,
        detail: '无严重违法记录',
      },
      {
        indicatorId: 4,
        indicatorName: '财务评级',
        category: '财务风险',
        score: 80,
        weight: 0.2,
        isRedline: false,
        triggered: false,
        detail: '最近评级 BBB+',
      },
      {
        indicatorId: 5,
        indicatorName: '交付及时率',
        category: '履约风险',
        score: 85,
        weight: 0.2,
        isRedline: false,
        triggered: false,
        detail: '近12个月及时率 92%',
      },
    ],
  };
}

export function mockHealthReport(supplierId: number): HealthReport {
  return {
    reportId: 'RPT-20260321-001',
    supplierId,
    supplierName: '深圳市测试供应链有限公司',
    status: 'generating',
    generatedAt: '',
    downloadUrl: '',
  };
}

export function mockAlertList(
  page: number,
  size: number
): PageResult<AlertItem> {
  const allItems: AlertItem[] = [
    {
      id: 1001,
      supplierId: 1001,
      supplierName: '深圳市测试供应链有限公司',
      alertLevel: 'high',
      alertType: '指标触发',
      indicatorName: '法律诉讼数量',
      message: '供应商未结诉讼数量超过阈值（3起），请关注法律风险',
      status: 'pending',
      triggeredAt: '2026-03-20T09:15:00Z',
      resolvedAt: null,
    },
    {
      id: 1002,
      supplierId: 1002,
      supplierName: '上海优质材料科技有限公司',
      alertLevel: 'medium',
      alertType: '评分下降',
      indicatorName: '财务评级',
      message: '供应商健康分较上月下降15分，当前得分58',
      status: 'pending',
      triggeredAt: '2026-03-19T16:42:00Z',
      resolvedAt: null,
    },
    {
      id: 1003,
      supplierId: 1003,
      supplierName: '北京精密零部件制造有限公司',
      alertLevel: 'low',
      alertType: '工商变更',
      indicatorName: '工商变更频率',
      message: '供应商发生法定代表人变更',
      status: 'resolved',
      triggeredAt: '2026-03-18T11:20:00Z',
      resolvedAt: '2026-03-19T08:00:00Z',
    },
    {
      id: 1004,
      supplierId: 1001,
      supplierName: '深圳市测试供应链有限公司',
      alertLevel: 'high',
      alertType: '红线触发',
      indicatorName: '严重违法记录',
      message: '供应商被列入经营异常名录，触发红线指标',
      status: 'pending',
      triggeredAt: '2026-03-17T14:05:00Z',
      resolvedAt: null,
    },
    {
      id: 1005,
      supplierId: 1004,
      supplierName: '广州通用设备有限公司',
      alertLevel: 'medium',
      alertType: '指标触发',
      indicatorName: '交付及时率',
      message: '近3个月交付及时率降至78%，低于85%阈值',
      status: 'ignored',
      triggeredAt: '2026-03-16T10:30:00Z',
      resolvedAt: null,
    },
  ];

  const start = (page - 1) * size;
  const items = allItems.slice(start, start + size);

  return {
    items,
    total: allItems.length,
    page,
    size,
  };
}
