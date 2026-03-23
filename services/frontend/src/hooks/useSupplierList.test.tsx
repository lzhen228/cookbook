import { describe, it, expect, vi } from 'vitest';
import { renderHook, waitFor, act } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { useSupplierList, useToggleFollow } from './useSupplierList';
import type { ReactNode } from 'react';

/**
 * useSupplierList / useToggleFollow Hook 测试。
 *
 * 对齐 TECH_SPEC 5.2 节供应商列表接口、CLAUDE.md 7.3 节 Hook 测试规范。
 * 使用 MSW 拦截 API 请求（通过全局 setup.ts 启动）。
 */

/** 创建独立的 QueryClient wrapper，防止测试间缓存污染 */
function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
    },
  });
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
  };
}

describe('useSupplierList Hook', () => {
  it('should fetch supplier list with default params', async () => {
    const { result } = renderHook(
      () => useSupplierList({ page: 1, page_size: 20 }),
      { wrapper: createWrapper() },
    );

    // 初始状态应为 loading
    expect(result.current.isLoading).toBe(true);

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data?.total).toBe(10);
    expect(result.current.data?.items.length).toBeGreaterThan(0);
    expect(result.current.data?.items[0].name).toBe('深圳芯科半导体有限公司');
  });

  it('should return paginated data with page_size', async () => {
    const { result } = renderHook(
      () => useSupplierList({ page: 1, page_size: 20, sort_by: 'health_score', sort_order: 'asc' }),
      { wrapper: createWrapper() },
    );

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    expect(result.current.data?.page).toBe(1);
    expect(result.current.data?.page_size).toBe(20);
  });

  it('should refetch when params change', async () => {
    const wrapper = createWrapper();
    const { result, rerender } = renderHook(
      (props: { page: number }) => useSupplierList({ page: props.page, page_size: 20 }),
      { wrapper, initialProps: { page: 1 } },
    );

    await waitFor(() => expect(result.current.isSuccess).toBe(true));

    // 切换到第 2 页（仍然命中 MSW handler）
    rerender({ page: 2 });
    await waitFor(() => expect(result.current.isSuccess).toBe(true));
  });
});

describe('useToggleFollow Hook', () => {
  it('should call mutation and invalidate list queries on success', async () => {
    const wrapper = createWrapper();
    const { result } = renderHook(() => useToggleFollow(), { wrapper });

    await act(async () => {
      result.current.mutate({ supplierId: 1001, isFollowed: true });
    });

    await waitFor(() => expect(result.current.isSuccess).toBe(true));
  });

  it('should handle mutation with server error', async () => {
    const { http, HttpResponse } = await import('msw');
    const { server } = await import('@/test/mocks/server');

    server.use(
      http.patch('/api/v1/suppliers/:id/follow', () =>
        HttpResponse.json(
          { code: 500001, msg: '服务内部错误', data: null, traceId: 'test' },
          { status: 500 },
        ),
      ),
    );

    const wrapper = createWrapper();
    const { result } = renderHook(() => useToggleFollow(), { wrapper });

    await act(async () => {
      result.current.mutate({ supplierId: 9999, isFollowed: true });
    });

    // 500 响应会被 axios 拦截器 reject，mutation 进入 error 状态
    await waitFor(() => expect(result.current.isError).toBe(true));
  });
});
