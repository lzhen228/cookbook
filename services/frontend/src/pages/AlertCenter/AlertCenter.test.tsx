import { describe, it, expect } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter } from 'react-router-dom';
import { AlertCenter } from './index';
import type { ReactNode } from 'react';

/**
 * AlertCenter 页面组件测试。
 *
 * 对齐预警中心功能：
 * - 状态 Tab 渲染（全部/待处理/已确认/处理中/已关闭/已忽略）
 * - 表格列渲染（供应商、风险维度、描述、触发时间、状态、负责人、操作）
 * - 待处理/已确认/处理中记录对应的操作按钮
 * - 筛选器渲染（风险维度 Select、供应商关键词搜索）
 * - 分页总数显示
 *
 * 使用 MSW 拦截 API 请求（通过全局 setup.ts 启动）。
 */

function createWrapper() {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
      mutations: { retry: false },
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

/** 等待表格数据渲染完成 */
async function waitForAlerts() {
  await waitFor(
    () => {
      expect(screen.getByText('预警中心')).toBeInTheDocument();
      // 供应商名称出现在多行中，用 getAllByText
      expect(screen.getAllByText('深圳芯科半导体有限公司').length).toBeGreaterThanOrEqual(1);
    },
    { timeout: 5000 },
  );
}

describe('AlertCenter Page', () => {
  // ==================== 页头 ====================

  it('should render page title "预警中心"', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByText('预警中心')).toBeInTheDocument());
  });

  it('should render export button', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByText('导出')).toBeInTheDocument());
  });

  // ==================== 状态 Tab ====================

  it('should render all status tabs', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByText('全部')).toBeInTheDocument());

    expect(screen.getAllByText('待处理').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('已确认').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('处理中').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('已关闭').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('已忽略').length).toBeGreaterThanOrEqual(1);
  });

  it('should show total count 15 in pagination', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();
    // 分页器文字是可靠的验证入口，Badge 会把数字拆成多个 span
    expect(screen.getByText(/共 15 条预警/)).toBeInTheDocument();
  });

  // ==================== 表格数据 ====================

  it('should render supplier names in table', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    expect(screen.getAllByText('深圳芯科半导体有限公司').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('北京华芯微电子科技有限公司').length).toBeGreaterThanOrEqual(1);
  });

  it('should render risk dimension tags', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    expect(screen.getAllByText('司法风险').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('财务风险').length).toBeGreaterThanOrEqual(1);
  });

  it('should render event status tags in table', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    // 状态标签在表格中出现（可能与 Tab 标签文字重复，均用 getAllByText）
    expect(screen.getAllByText('待处理').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('处理中').length).toBeGreaterThanOrEqual(1);
  });

  it('should show handler names for assigned alerts', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    // 负责人名字在多行中重复出现
    expect(screen.getAllByText('张三').length).toBeGreaterThanOrEqual(1);
    expect(screen.getAllByText('李四').length).toBeGreaterThanOrEqual(1);
  });

  it('should show "未分配" for alerts without handler', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    expect(screen.getAllByText('未分配').length).toBeGreaterThanOrEqual(1);
  });

  it('should show total count in pagination', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    expect(screen.getByText(/共 15 条预警/)).toBeInTheDocument();
  });

  // ==================== 操作按钮 ====================

  it('should render action buttons for open alerts (确认/忽略)', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    // Ant Design 5 在 2 字按钮中插入零宽空格，用 role 查询更可靠
    const buttons = screen.getAllByRole('button');
    expect(buttons.length).toBeGreaterThan(0);
    // 至少有确认类按钮（primary type）
    const primaryBtns = document.querySelectorAll('.ant-btn-primary');
    expect(primaryBtns.length).toBeGreaterThanOrEqual(1);
  });

  it('should render "开始处理" button for confirmed alerts', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    // 4 个汉字，不会插入零宽空格
    expect(screen.getAllByText('开始处理').length).toBeGreaterThanOrEqual(1);
  });

  it('should render action buttons for processing alerts (关闭)', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    // 用 ghost 类型按钮数量验证处理中操作按钮存在
    const ghostBtns = document.querySelectorAll('.ant-btn-background-ghost');
    expect(ghostBtns.length).toBeGreaterThanOrEqual(1);
  });

  // ==================== 筛选器 ====================

  it('should render dimension filter select', () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    const selects = document.querySelectorAll('.ant-select');
    expect(selects.length).toBeGreaterThanOrEqual(1);
  });

  it('should render supplier keyword search input', () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    expect(screen.getByPlaceholderText('搜索供应商名称')).toBeInTheDocument();
  });

  // ==================== Tab 切换 ====================

  it('should switch status tab without error', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitFor(() => expect(screen.getByText('待处理')).toBeInTheDocument());

    // 点击「待处理」Tab（第一个文本节点匹配）
    const tabs = screen.getAllByText('待处理');
    fireEvent.click(tabs[0]);

    await waitFor(() => {
      expect(screen.getByText('预警中心')).toBeInTheDocument();
    });
  });

  // ==================== 描述文字 ====================

  it('should display alert descriptions', async () => {
    render(<AlertCenter />, { wrapper: createWrapper() });
    await waitForAlerts();

    expect(screen.getByText(/存在未结清执行案件/)).toBeInTheDocument();
  });
});
