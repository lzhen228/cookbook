import { describe, it, expect, vi } from 'vitest';
import { render, screen, waitFor, fireEvent } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { MemoryRouter, Route, Routes } from 'react-router-dom';
import { SupplierProfile } from './index';
import type { ReactNode } from 'react';

/**
 * SupplierProfile 页面组件测试。
 *
 * 对齐 TECH_SPEC 5.3~5.6 节：
 * - 基础信息卡片渲染
 * - 健康评分卡渲染（分数、等级、维度得分）
 * - 风险事项表格渲染
 * - Tab 懒加载区域
 * - 报告下载按钮状态
 * - 加载状态和错误状态
 *
 * 使用 MSW 拦截 API 请求。
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
  // ==================== 基础信息 ====================

  it('should render supplier name as card title', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });
  });

  it('should display unified credit code', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('91440300TEST00001')).toBeInTheDocument();
    });
  });

  it('should display cooperation status', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('合作中')).toBeInTheDocument();
    });
  });

  it('should display region', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('广东 深圳')).toBeInTheDocument();
    });
  });

  it('should display listed status', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('上市')).toBeInTheDocument();
    });
  });

  it('should display supply items as tags', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('钢材')).toBeInTheDocument();
    });

    expect(screen.getByText('铝材')).toBeInTheDocument();
  });

  // ==================== 健康评分卡 ====================

  it('should display health score section title', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('健康评分')).toBeInTheDocument();
    });
  });

  it('should display health score value', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      // Ant Design Statistic renders value in .ant-statistic-content-value
      // formatScore(85.5) → "85.5"
      const statValues = document.querySelectorAll('.ant-statistic-content-value');
      const texts = Array.from(statValues).map((el) => el.textContent);
      expect(texts.some((t) => t?.includes('85.5'))).toBe(true);
    });
  });

  it('should display health level badge', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('低风险')).toBeInTheDocument();
    });
  });

  it('should display dimension scores', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });

    // 维度名称来自 health.dimension_scores 的 key
    expect(screen.getByText('legal')).toBeInTheDocument();
    expect(screen.getByText('finance')).toBeInTheDocument();
  });

  // ==================== 风险事项 ====================

  it('should display risk events total count', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText(/风险事项（共 10 条）/)).toBeInTheDocument();
    });
  });

  it('should display risk event descriptions', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('被列为失信被执行人')).toBeInTheDocument();
    });

    expect(screen.getByText('年度审计报告出具保留意见')).toBeInTheDocument();
  });

  it('should display risk event status tags', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('待处理')).toBeInTheDocument();
    });

    expect(screen.getByText('处理中')).toBeInTheDocument();
  });

  it('should display risk dimension tags', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('司法风险')).toBeInTheDocument();
    });

    expect(screen.getByText('财务风险')).toBeInTheDocument();
  });

  it('should render source URL as link', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('查看')).toBeInTheDocument();
    });
  });

  // ==================== 报告下载 ====================

  it('should display download button when report is ready', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('下载报告')).toBeInTheDocument();
    });
  });

  // ==================== Tab 懒加载 ====================

  it('should render all 5 tabs', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('测试供应商A')).toBeInTheDocument();
    });

    expect(screen.getByText('基本信息')).toBeInTheDocument();
    expect(screen.getByText('经营信息')).toBeInTheDocument();
    expect(screen.getByText('司法诉讼')).toBeInTheDocument();
    expect(screen.getByText('信用数据')).toBeInTheDocument();
    expect(screen.getByText('税务信息')).toBeInTheDocument();
  });

  // ==================== 返回列表 ====================

  it('should render back button', async () => {
    renderWithRoute(1001);

    await waitFor(() => {
      expect(screen.getByText('返回列表')).toBeInTheDocument();
    });
  });

  // ==================== 错误状态 ====================

  it('should display error alert when profile fetch fails', async () => {
    const { http, HttpResponse } = await import('msw');
    const { server } = await import('@/test/mocks/server');

    server.use(
      http.get('/api/v1/suppliers/:id/profile', () =>
        HttpResponse.json(
          { code: 404001, msg: '供应商不存在', data: null, traceId: 'test' },
        ),
      ),
    );

    renderWithRoute(9999);

    await waitFor(() => {
      expect(screen.getByText('加载供应商画像失败')).toBeInTheDocument();
    });
  });

  // ==================== 加载状态 ====================

  it('should show loading skeleton initially', () => {
    renderWithRoute(1001);

    // Ant Design Skeleton 在数据加载前显示
    const skeleton = document.querySelector('.ant-skeleton');
    expect(skeleton).toBeInTheDocument();
  });
});
