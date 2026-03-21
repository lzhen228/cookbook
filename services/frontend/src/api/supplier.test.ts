import { describe, it, expect, beforeEach } from 'vitest';
import { http, HttpResponse } from 'msw';
import { server } from '@/test/mocks/server';
import {
  fetchSupplierList,
  fetchSupplierProfile,
  fetchSupplierTab,
  toggleSupplierFollow,
  fetchReportDownloadUrl,
  triggerReportGeneration,
} from './supplier';
import { mockSupplierListResponse, mockSupplierProfile, mockTabData } from '@/test/mocks/data';

/**
 * 供应商 API 函数测试。
 *
 * 使用 MSW 拦截 HTTP 请求，验证请求参数和响应解析。
 * 对齐 TECH_SPEC 5.2~5.6 节接口定义。
 */
describe('supplier API', () => {
  // ==================== fetchSupplierList ====================
  describe('fetchSupplierList', () => {
    it('should fetch supplier list with default params', async () => {
      const data = await fetchSupplierList({ page: 1, page_size: 20 });

      expect(data.total).toBe(3);
      expect(data.items).toHaveLength(3);
      expect(data.items[0].name).toBe('测试供应商A');
      expect(data.page_size).toBe(20);
    });

    it('should return empty list when no results', async () => {
      server.use(
        http.get('/api/v1/suppliers', () =>
          HttpResponse.json({
            code: 0,
            msg: 'ok',
            data: { total: 0, page: 1, page_size: 20, next_cursor: null, items: [] },
            traceId: 'test',
          }),
        ),
      );

      const data = await fetchSupplierList({ keyword: '不存在' });
      expect(data.total).toBe(0);
      expect(data.items).toHaveLength(0);
    });

    it('should reject on business error code', async () => {
      server.use(
        http.get('/api/v1/suppliers', () =>
          HttpResponse.json({
            code: 400003,
            msg: 'sort_by 包含非白名单字段',
            data: null,
            traceId: 'test',
          }),
        ),
      );

      await expect(
        fetchSupplierList({ sort_by: 'invalid' as 'health_score' }),
      ).rejects.toThrow();
    });
  });

  // ==================== fetchSupplierProfile ====================
  describe('fetchSupplierProfile', () => {
    it('should fetch supplier profile successfully', async () => {
      const profile = await fetchSupplierProfile(1001);

      expect(profile.basic.id).toBe(1001);
      expect(profile.basic.name).toBe('测试供应商A');
      expect(profile.basic.unified_code).toBe('91440300TEST00001');
      expect(profile.health.score).toBe(85.5);
      expect(profile.health.level).toBe('low_risk');
      expect(profile.risk_events_total).toBe(10);
    });

    it('should reject when supplier not found (404001)', async () => {
      await expect(fetchSupplierProfile(9999)).rejects.toThrow();
    });
  });

  // ==================== fetchSupplierTab ====================
  describe('fetchSupplierTab', () => {
    it('should fetch tab data for basic-info', async () => {
      const tab = await fetchSupplierTab(1001, 'basic-info');

      expect(tab.tab).toBe('basic-info');
      expect(tab.is_stale).toBe(false);
      expect(tab.content).toBeDefined();
    });

    it('should reject for invalid tab name', async () => {
      await expect(
        fetchSupplierTab(1001, 'invalid-tab' as 'basic-info'),
      ).rejects.toThrow();
    });
  });

  // ==================== toggleSupplierFollow ====================
  describe('toggleSupplierFollow', () => {
    it('should send PATCH request to toggle follow', async () => {
      // 不应抛异常
      await expect(toggleSupplierFollow(1001, true)).resolves.toBeUndefined();
    });

    it('should handle server error gracefully', async () => {
      server.use(
        http.patch('/api/v1/suppliers/:id/follow', () =>
          HttpResponse.json(
            { code: 500001, msg: '服务内部错误', data: null, traceId: 'test' },
            { status: 500 },
          ),
        ),
      );

      await expect(toggleSupplierFollow(1001, true)).rejects.toThrow();
    });
  });

  // ==================== fetchReportDownloadUrl ====================
  describe('fetchReportDownloadUrl', () => {
    it('should return presigned download URL', async () => {
      const result = await fetchReportDownloadUrl(1001);

      expect(result.url).toContain('minio.example.com');
      expect(result.filename).toBe('supplier_1001_report.pdf');
      expect(result.expires_at).toBeDefined();
    });
  });

  // ==================== triggerReportGeneration ====================
  describe('triggerReportGeneration', () => {
    it('should trigger report generation', async () => {
      const result = await triggerReportGeneration(1001);

      expect(result.report_id).toBe('rpt-001');
      expect(result.status).toBe('generating');
      expect(result.estimated_seconds).toBe(30);
    });
  });
});
