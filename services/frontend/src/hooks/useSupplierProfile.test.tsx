import { describe, it, expect } from 'vitest';
import { renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useSupplierProfile, useSupplierTab, useReportDownloadUrl } from './useSupplierProfile';
import type { ReactNode } from 'react';

/**
 * useSupplierProfile / useSupplierTab / useReportDownloadUrl Hook 测试。
 *
 * 对齐 TECH_SPEC 5.3~5.6 节接口定义。
 * 使用 MSW 拦截 API 请求（通过全局 setup.ts 启动）。
 */

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
    },
  });
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
  };
}

describe('useSupplierProfile Hook', () => {
  it('should fetch profile when supplierId > 0', async () => {
    const { result } = renderHook(
      () => useSupplierProfile(1001),
      { wrapper: createWrapper() },
    );

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data?.basic.id).toBe(1001);
    expect(result.current.data?.basic.name).toBe('深圳芯科半导体有限公司');
    expect(result.current.data?.health.score).toBe(32.5);
    expect(result.current.data?.health.level).toBe('high_risk');
    expect(result.current.data?.risk_events.length).toBeGreaterThan(0);
    expect(result.current.data?.risk_events_total).toBe(7);
  });

  it('should NOT fetch when supplierId <= 0 (enabled: false)', async () => {
    const { result } = renderHook(
      () => useSupplierProfile(0),
      { wrapper: createWrapper() },
    );

    // 应保持 idle 状态，不触发请求
    expect(result.current.fetchStatus).toBe('idle');
    expect(result.current.data).toBeUndefined();
  });

  it('should handle supplier not found error', async () => {
    const { result } = renderHook(
      () => useSupplierProfile(9999),
      { wrapper: createWrapper() },
    );

    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

describe('useSupplierTab Hook', () => {
  it('should fetch tab data when enabled is true', async () => {
    const { result } = renderHook(
      () => useSupplierTab(1001, 'basic-info', true),
      { wrapper: createWrapper() },
    );

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data?.tab).toBe('basic-info');
    expect(result.current.data?.is_stale).toBe(false);
  });

  it('should NOT fetch when enabled is false', async () => {
    const { result } = renderHook(
      () => useSupplierTab(1001, 'judicial', false),
      { wrapper: createWrapper() },
    );

    expect(result.current.fetchStatus).toBe('idle');
    expect(result.current.data).toBeUndefined();
  });

  it('should NOT fetch when supplierId <= 0', async () => {
    const { result } = renderHook(
      () => useSupplierTab(0, 'basic-info', true),
      { wrapper: createWrapper() },
    );

    expect(result.current.fetchStatus).toBe('idle');
  });

  it('should handle error for invalid tab name', async () => {
    const { result } = renderHook(
      () => useSupplierTab(1001, 'invalid-tab' as 'basic-info', true),
      { wrapper: createWrapper() },
    );

    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});

describe('useReportDownloadUrl Hook', () => {
  it('should fetch download URL when enabled', async () => {
    const { result } = renderHook(
      () => useReportDownloadUrl(1001, true),
      { wrapper: createWrapper() },
    );

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data?.url).toContain('minio.example.com');
    expect(result.current.data?.filename).toBe('supplier_1001_health_report.pdf');
  });

  it('should NOT fetch when enabled is false', async () => {
    const { result } = renderHook(
      () => useReportDownloadUrl(1001, false),
      { wrapper: createWrapper() },
    );

    expect(result.current.fetchStatus).toBe('idle');
  });
});
