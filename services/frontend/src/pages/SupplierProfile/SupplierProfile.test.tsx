import { describe, it, expect } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { SupplierProfile } from './index';

/**
 * SupplierProfile 页面组件测试。
 *
 * 对齐 TECH_SPEC 5.3~5.6 节：
 * - 公司标题卡渲染（名称、标签、关注/报告按钮）
 * - 健康评分卡渲染（ECharts 已 Mock、维度评分）
 * - 风险事项表格渲染
 * - Tab 懒加载区域
 * - 加载骨架屏与错误状态
 *
 * 使用 MSW 拦截 API 请求，ECharts 通过 vite.config alias Mock。
 */

function renderWithRoute(supplierId: number) {
  const queryClient = new QueryClient({
    defaultOptions: {
      queries: { retry: false, gcTime: 0 },
    },
  });

  return render(
    <QueryClientProvider client={queryClient}>
      <MemoryRouter initialEntries={[`/suppliers/${supplierId}`]}>
        <Routes>
          <Route path="/suppliers/:id" element={<SupplierProfile />} />
        </Routes>
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

describe('SupplierProfile Page', () => {
  // ==================== 公司标题卡 ====================

  it('should render supplier name in header', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('深圳芯科半导体有限公司')).toBeInTheDocument();
    });
  });

  it('should display unified credit code', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('91440300TEST00001')).toBeInTheDocument();
    });
  });

  it('should display cooperation status tag', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      // 标题卡和基础信息卡各有一个"合作中"Tag
      const tags = screen.getAllByText('合作中');
      expect(tags.length).toBeGreaterThanOrEqual(1);
    });
  });

  it('should display listed status tag', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('上市企业')).toBeInTheDocument();
    });
  });

  it('should display supply items as tags', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('半导体')).toBeInTheDocument();
      expect(screen.getByText('芯片')).toBeInTheDocument();
    });
  });

  it('should render follow button', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('已关注')).toBeInTheDocument();
    });
  });

  it('should render download report button when report is ready', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('下载报告')).toBeInTheDocument();
    });
  });

  // ==================== 健康评分卡 ====================

  it('should display health score card title', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('健康评分')).toBeInTheDocument();
    });
  });

  it('should render ECharts gauge (mocked)', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(document.querySelector('[data-testid="echarts-mock"]')).toBeInTheDocument();
    });
  });

  it('should display health level badge', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('高风险')).toBeInTheDocument();
    });
  });

  it('should display dimension score labels', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      // '司法风险' appears in both DimensionScores bars and RiskDimensionTag cells
      expect(screen.getAllByText('司法风险').length).toBeGreaterThanOrEqual(1);
      expect(screen.getAllByText('财务风险').length).toBeGreaterThanOrEqual(1);
    });
  });

  it('should display snapshot date', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('2026-03-23')).toBeInTheDocument();
    });
  });

  // ==================== 风险事项 ====================

  it('should display risk events total badge', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('7 条')).toBeInTheDocument();
    });
  });

  it('should display risk event descriptions', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('存在未结清执行案件，涉案金额 300 万')).toBeInTheDocument();
    });
  });

  it('should display risk event status tags', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getAllByText('待处理').length).toBeGreaterThanOrEqual(1);
    });
  });

  it('should display risk dimension tags in table', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      // RiskDimensionTag renders inside RiskEventTable
      expect(screen.getAllByText('司法风险').length).toBeGreaterThanOrEqual(1);
    });
  });

  // ==================== Tab 区域 ====================

  it('should render all 5 tab labels', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('深圳芯科半导体有限公司')).toBeInTheDocument();
    });

    expect(screen.getByRole('tab', { name: '基本信息' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: '经营信息' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: '司法诉讼' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: '信用数据' })).toBeInTheDocument();
    expect(screen.getByRole('tab', { name: '税务信息' })).toBeInTheDocument();
  });

  // ==================== 返回按钮 ====================

  it('should render back to list button', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('返回供应商列表')).toBeInTheDocument();
    });
  });

  // ==================== 骨架屏 ====================

  it('should show loading skeleton before data arrives', () => {
    renderWithRoute(1001);

    const skeleton = document.querySelector('.ant-skeleton');
    expect(skeleton).toBeInTheDocument();
  });

  // ==================== 错误状态 ====================

  it('should display error alert when supplier is not found', async () => {
    const { http, HttpResponse } = await import('msw');
    const { server } = await import('@/test/mocks/server');

    server.use(
      http.get('/api/v1/suppliers/:id/profile', () =>
        HttpResponse.json({ code: 404001, msg: '供应商不存在', data: null, traceId: 'test' }),
      ),
    );

    renderWithRoute(9999);

    await waitFor(() => {
      expect(screen.getByText('加载失败')).toBeInTheDocument();
    });
  });

  // ==================== 未评分供应商 ====================

  it('should show unscored supplier without health badge', async () => {
    renderWithRoute(1006);

    await waitFor(() => {
      expect(screen.getByText('成都天成新材料有限公司')).toBeInTheDocument();
    });

    expect(screen.queryByText('高风险')).not.toBeInTheDocument();
    expect(screen.queryByText('低风险')).not.toBeInTheDocument();
  });
});
