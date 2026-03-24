package com.supply.risk.controller;

import com.supply.risk.common.response.ApiResponse;
import com.supply.risk.model.dto.DashboardResponse;
import com.supply.risk.service.DashboardService;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * 风险看板模块 REST 控制器。
 *
 * <p>职责：调用 Service 获取看板数据并组装统一响应。不包含任何业务逻辑。
 *
 * <p>提供以下接口：
 * <ul>
 *   <li>GET /dashboard — 获取风险看板全量数据</li>
 * </ul>
 */
@RestController
@RequestMapping("/dashboard")
public class DashboardController {

  private final DashboardService dashboardService;

  /**
   * 构造函数注入。
   *
   * @param dashboardService 风险看板服务
   */
  public DashboardController(DashboardService dashboardService) {
    this.dashboardService = dashboardService;
  }

  /**
   * 获取风险看板全量数据，包含汇总统计、健康分布、维度统计、趋势、高风险供应商和近期事项。
   *
   * @return 风险看板响应数据
   */
  @GetMapping
  public ApiResponse<DashboardResponse> getDashboard() {
    DashboardResponse response = dashboardService.getDashboard();
    return ApiResponse.ok(response);
  }
}
