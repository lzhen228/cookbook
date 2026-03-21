/**
 * MSW 请求处理器，拦截所有 API 请求并返回 Mock 数据。
 * 对齐 TECH_SPEC 5.2~5.5 节接口定义。
 */
import { http, HttpResponse } from 'msw';
import {
  mockSupplierListResponse,
  mockSupplierProfile,
  mockTabData,
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
    return HttpResponse.json({
      code: 0,
      msg: 'ok',
      data: { ...mockTabData, tab: tabName },
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
        expires_at: '2026-03-20T11:00:00+08:00',
        filename: 'supplier_1001_report.pdf',
      },
      traceId: 'test-trace-005',
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
