/**
 * MSW 请求处理器，拦截所有 API 请求并返回 Mock 数据。
 * 对齐 TECH_SPEC 5.2~5.5 节接口定义。
 */
import { http, HttpResponse } from 'msw';
import {
  mockSupplierListResponse,
  mockSupplierProfile,
  mockUnscoredProfile,
  mockTabDataMap,
  mockDashboardData,
  mockRiskAlerts,
  mockRiskAlertListResponse,
} from './data';

const BASE_URL = '/api/v1';

export const handlers = [
  // GET /suppliers — 供应商列表
  http.get(`${BASE_URL}/suppliers`, () => {
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: mockSupplierListResponse,
      traceId: 'test-trace-001',
    });
  }),

  // GET /suppliers/:id/profile — 供应商画像
  http.get(`${BASE_URL}/suppliers/:id/profile`, ({ params }) => {
    const id = Number(params.id);
    if (id === 9999) {
      return HttpResponse.json({
        code: 404001,
        msg: '供应商不存在: 9999',
        data: null,
        traceId: 'test-trace-404',
      });
    }
    // 未评分供应商
    if (id === 1006) {
      return HttpResponse.json({
        code: 0,
        msg: 'ok',
        data: mockUnscoredProfile,
        traceId: 'test-trace-002b',
      });
    }
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: mockSupplierProfile,
      traceId: 'test-trace-002',
    });
  }),

  // GET /suppliers/:id/tabs/:tabName — Tab 懒加载
  http.get(`${BASE_URL}/suppliers/:id/tabs/:tabName`, ({ params }) => {
    const tabName = params.tabName as string;
    const validTabs = ['basic-info', 'business-info', 'judicial', 'credit', 'tax'];
    if (!validTabs.includes(tabName)) {
      return HttpResponse.json({
        code: 400001,
        msg: `不支持的 Tab: ${tabName}`,
        data: null,
        traceId: 'test-trace-400',
      });
    }
    const tabData = mockTabDataMap[tabName];
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: tabData,
      traceId: 'test-trace-003',
    });
  }),

  // PATCH /suppliers/:id/follow — 切换关注
  http.patch(`${BASE_URL}/suppliers/:id/follow`, () => {
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: null,
      traceId: 'test-trace-004',
    });
  }),

  // GET /suppliers/:id/reports/latest/download-url — 报告下载
  http.get(`${BASE_URL}/suppliers/:id/reports/latest/download-url`, () => {
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: {
        url: 'https://minio.example.com/reports/test.pdf?signed=1',
        expires_at: '2026-03-23T18:00:00+08:00',
        filename: 'supplier_1001_health_report.pdf',
      },
      traceId: 'test-trace-005',
    });
  }),

  // GET /dashboard — 风险看板
  http.get(`${BASE_URL}/dashboard`, () => {
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: mockDashboardData,
      traceId: 'test-trace-dashboard',
    });
  }),

  // GET /risk-events — 预警事项列表
  http.get(`${BASE_URL}/risk-events`, ({ request }) => {
    const url = new URL(request.url);
    const status = url.searchParams.get('status');
    const dimension = url.searchParams.get('risk_dimension');
    const keyword = url.searchParams.get('keyword');

    let items = [...mockRiskAlerts];
    if (status) items = items.filter((a) => a.status === status);
    if (dimension) items = items.filter((a) => a.risk_dimension === dimension);
    if (keyword) items = items.filter((a) => a.supplier_name.includes(keyword));

    const stats = {
      total: mockRiskAlerts.length,
      open: mockRiskAlerts.filter((a) => a.status === 'open').length,
      confirmed: mockRiskAlerts.filter((a) => a.status === 'confirmed').length,
      processing: mockRiskAlerts.filter((a) => a.status === 'processing').length,
      closed: mockRiskAlerts.filter((a) => a.status === 'closed').length,
      dismissed: mockRiskAlerts.filter((a) => a.status === 'dismissed').length,
    };

    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: { ...mockRiskAlertListResponse, stats, items, total: items.length },
      traceId: 'test-trace-risk-events',
    });
  }),

  // PATCH /risk-events/:id/status — 更新预警状态
  http.patch(`${BASE_URL}/risk-events/:id/status`, () => {
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: null,
      traceId: 'test-trace-risk-events-update',
    });
  }),

  // POST /suppliers/:id/reports — 触发报告生成
  http.post(`${BASE_URL}/suppliers/:id/reports`, () => {
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: {
        report_id: 'rpt-001',
        status: 'generating',
        estimated_seconds: 30,
      },
      traceId: 'test-trace-006',
    });
  }),
];
