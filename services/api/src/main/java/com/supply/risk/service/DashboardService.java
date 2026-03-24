package com.supply.risk.service;

import com.supply.risk.model.dto.DashboardResponse;

/**
 * 风险看板服务接口。
 */
public interface DashboardService {

  /**
   * 获取风险看板全量数据，包含汇总统计、健康分布、维度统计、趋势、高风险供应商和近期事项。
   *
   * @return 风险看板响应 DTO
   */
  DashboardResponse getDashboard();
}
