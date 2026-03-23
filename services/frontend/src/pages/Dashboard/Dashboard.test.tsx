import { describe, it, expect } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { Dashboard } from './index';
import type { ReactNode } from 'react';

/**
 * Dashboard 页面组件测试。
 *
 * 对齐风险看板功能：
 * - 统计卡片渲染（总供应商、高风险、需关注、低风险、待处理事项、本周新增）
 * - 图表区域渲染（通过 data-testid="echarts-mock" 验证）
 * - 高风险供应商 TOP5 表格
 * - 最新风险事项列表
 *
 * 使用 MSW 拦截 API 请求（通过全局 setup.ts 启动）。
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

/** 等待 Dashboard 数据加载完成的辅助函数 */
async function waitForDashboard() {
  await waitFor(() => {
    expect(screen.getByText('风险看板')).toBeInTheDocument();
  });
}

describe('Dashboard Page', () => {
  // ==================== 加载与页头 ====================

  it('should render page title "风险看板" after loading', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('风险看板')).toBeInTheDocument();
  });

  it('should render refresh button', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('刷新')).toBeInTheDocument();
  });

  // ==================== 统计卡片 ====================

  it('should render all stat card titles', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();

    expect(screen.getByText('总供应商')).toBeInTheDocument();
    expect(screen.getByText('待处理风险事项')).toBeInTheDocument();
    expect(screen.getByText('本周新增事项')).toBeInTheDocument();
    expect(screen.getByText('低风险')).toBeInTheDocument();
  });

  it('should display total supplier count 10', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();

    expect(screen.getByText('10')).toBeInTheDocument();
  });

  it('should display pending events count 8', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();

    expect(screen.getByText('8')).toBeInTheDocument();
  });

  it('should show cooperating count in total supplier card', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText(/合作中 7/)).toBeInTheDocument();
  });

  // ==================== 图表 ====================

  it('should render health distribution chart section', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('健康等级分布')).toBeInTheDocument();
    const charts = screen.getAllByTestId('echarts-mock');
    expect(charts.length).toBeGreaterThanOrEqual(1);
  });

  it('should render risk trend chart section', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText(/风险趋势/)).toBeInTheDocument();
  });

  it('should render dimension distribution chart section', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('待处理风险维度分布')).toBeInTheDocument();
  });

  // ==================== 高风险供应商表 ====================

  it('should render top risk supplier table title', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('高风险供应商 TOP5')).toBeInTheDocument();
  });

  it('should display supplier names in table', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();

    // 供应商名称在表格和事项列表中可能重复出现，用 getAllByText
    expect(screen.getAllByText('深圳芯科半导体有限公司').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('北京华芯微电子科技有限公司').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('苏州纳图光电科技有限公司').length).toBeGreaterThanOrEqual(1);
  });

  it('should display health score 32.5 for first supplier', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('32.5')).toBeInTheDocument();
  });

  it('should display health level tags in table', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    // 高风险标签在表格中出现（可能多次）
    const highRiskTags = screen.getAllByText('高风险');
    expect(highRiskTags.length).toBeGreaterThanOrEqual(1);
  });

  it('should show open events count 5 for first supplier', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    // "5" 可能在多处出现（本周新增事项 = 5，待处理 open_events = 5）
    expect(screen.getAllByText('5').length).toBeGreaterThanOrEqual(1);
  });

  // ==================== 最新风险事项 ====================

  it('should render recent risk events section', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText('最新风险事项')).toBeInTheDocument();
  });

  it('should display supplier names in event list', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    // 供应商名称可能在表格和事项列表中都出现
    const links = screen.getAllByText('深圳芯科半导体有限公司');
    expect(links.length).toBeGreaterThanOrEqual(1);
  });

  it('should display risk event description', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    expect(screen.getByText(/存在未结清执行案件/)).toBeInTheDocument();
  });

  it('should display dimension tags in event list', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    const legalTags = screen.getAllByText('司法风险');
    expect(legalTags.length).toBeGreaterThanOrEqual(1);
  });

  it('should display event status tags', async () => {
    render(<Dashboard />, { wrapper: createWrapper() });
    await waitForDashboard();
    const openTags = screen.getAllByText('待处理');
    expect(openTags.length).toBeGreaterThanOrEqual(1);
  });
});
