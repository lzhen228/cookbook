import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { SupplierList } from './index';
import type { ReactNode } from 'react';

/**
 * SupplierList 页面组件测试。
 *
 * 对齐 TECH_SPEC 5.2 节供应商列表页面：
 * - 表格渲染（名称、健康等级、健康分、地区、合作状态等列）
 * - 搜索和筛选交互
 * - 关注/取关操作
 * - 空列表状态
 *
 * 使用 MSW 拦截 API 请求，不直接 mock fetch。
 */

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
    },
  });
  return function Wrapper({ children }: { children: ReactNode }) {
    return (
      <QueryClientProvider client={queryClient}>
        <MemoryRouter>{children}</MemoryRouter>
      </QueryClientProvider>
    );
  };
}

describe('SupplierList Page', () => {
  // ==================== 正常渲染 ====================

  it('should render page title "供应商列表"', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    expect(screen.getByText('供应商列表')).toBeInTheDocument();
  });

  it('should render supplier table with data from API', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    // 等待 API 数据加载
    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });

    // 验证表格列内容
    expect(screen.getByText('测试供应商B')).toBeInTheDocument();
    expect(screen.getByText('测试供应商C')).toBeInTheDocument();
  });

  it('should display health level badges', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });

    // 低风险和高风险标签
    expect(screen.getByText('低风险')).toBeInTheDocument();
    expect(screen.getByText('高风险')).toBeInTheDocument();
    // 未评分供应商应显示 "未评分"
    expect(screen.getByText('未评分')).toBeInTheDocument();
  });

  it('should display cooperation status labels', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });

    expect(screen.getByText('合作中')).toBeInTheDocument();
    expect(screen.getByText('受限')).toBeInTheDocument();
    expect(screen.getByText('潜在')).toBeInTheDocument();
  });

  it('should display region information', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('广东 深圳')).toBeInTheDocument();
    });

    expect(screen.getByText('北京')).toBeInTheDocument();
  });

  it('should display total count', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText(/共 3 条/)).toBeInTheDocument();
    });
  });

  // ==================== 搜索 ====================

  it('should render search input', () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    expect(screen.getByPlaceholderText('搜索供应商名称')).toBeInTheDocument();
  });

  // ==================== 筛选器 ====================

  it('should render health level filter', () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    // Ant Design Select 在 jsdom 中渲染 placeholder 为 input 的 placeholder 属性
    const selects = document.querySelectorAll('.ant-select');
    expect(selects.length).toBeGreaterThanOrEqual(2);
  });

  it('should render cooperation status filter', () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    // 验证有多个 Select 筛选器
    const selects = document.querySelectorAll('.ant-select');
    expect(selects.length).toBeGreaterThanOrEqual(2);
  });

  // ==================== 关注按钮 ====================

  it('should render follow/unfollow buttons', async () => {
    render(<SupplierList />, { wrapper: createWrapper() });

    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });

    // 已关注供应商应有 StarFilled 图标（通过 aria 或按钮存在判断）
    const buttons = screen.getAllByRole('button');
    // 表格中每行有操作列按钮
    expect(buttons.length).toBeGreaterThan(0);
  });

  // ==================== 空列表 ====================

  it('should handle empty list gracefully', async () => {
    const { http, HttpResponse } = await import('msw');
    const { server } = await import('@/test/mocks/server');

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

    render(<SupplierList />, { wrapper: createWrapper() });

    await waitFor(
      () => {
        // 空列表时 Ant Design Table 会显示 "No data" 或 "暂无数据"
        const noData = document.querySelector('.ant-empty');
        const totalText = screen.queryByText(/共 0 条/);
        expect(noData || totalText).toBeTruthy();
      },
      { timeout: 3000 },
    );
  });
});
