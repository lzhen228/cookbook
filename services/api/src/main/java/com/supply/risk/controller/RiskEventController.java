package com.supply.risk.controller;

import com.supply.risk.common.response.ApiResponse;
import com.supply.risk.model.dto.RiskAlertListResponse;
import com.supply.risk.model.dto.RiskAlertQuery;
import com.supply.risk.model.dto.UpdateAlertStatusRequest;
import com.supply.risk.service.RiskEventService;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

/**
 * 风险预警事项模块 REST 控制器。
 *
 * <p>职责：参数校验 + 调用 Service + 组装统一响应。不包含任何业务逻辑。
 *
 * <p>提供以下接口：
 * <ul>
 *   <li>GET  /risk-events         — 分页查询风险预警事项列表</li>
 *   <li>PATCH /risk-events/{id}/status — 更新风险预警事项状态</li>
 * </ul>
 */
@RestController
@RequestMapping("/risk-events")
@Validated
public class RiskEventController {

  private final RiskEventService riskEventService;

  /**
   * 构造函数注入。
   *
   * @param riskEventService 风险预警事项服务
   */
  public RiskEventController(RiskEventService riskEventService) {
    this.riskEventService = riskEventService;
  }

  /**
   * 分页查询风险预警事项列表，支持状态、风险维度、关键词筛选。
   *
   * @param status        状态筛选（open / confirmed / processing / closed / dismissed），可选
   * @param riskDimension 风险维度筛选，可选
   * @param keyword       关键词搜索，可选
   * @param page          页码，默认 1
   * @param pageSize      每页条数，默认 20
   * @return 含统计数据、事项列表及分页信息的响应
   */
  @GetMapping
  public ApiResponse<RiskAlertListResponse> listAlerts(
      @RequestParam(required = false) String status,
      @RequestParam(name = "risk_dimension", required = false) String riskDimension,
      @RequestParam(required = false) String keyword,
      @RequestParam(defaultValue = "1") int page,
      @RequestParam(name = "page_size", defaultValue = "20") int pageSize) {

    RiskAlertQuery query = new RiskAlertQuery(status, riskDimension, keyword, page, pageSize);
    RiskAlertListResponse response = riskEventService.listAlerts(query);
    return ApiResponse.ok(response);
  }

  /**
   * 更新风险预警事项状态，并校验状态流转合法性。
   *
   * @param id      风险事项 ID
   * @param request 请求体，包含目标状态、处理人 ID 和处理备注
   * @return 操作成功响应（无数据）
   */
  @PatchMapping("/{id}/status")
  public ApiResponse<Void> updateStatus(
      @PathVariable Long id,
      @RequestBody UpdateAlertStatusRequest request) {

    riskEventService.updateStatus(id, request.status(), request.assigneeId(), request.comment());
    return ApiResponse.ok();
  }
}
