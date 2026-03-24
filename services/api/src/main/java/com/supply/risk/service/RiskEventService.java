package com.supply.risk.service;

import com.supply.risk.model.dto.RiskAlertListResponse;
import com.supply.risk.model.dto.RiskAlertQuery;

/**
 * 风险预警事项服务接口，定义事项列表查询和状态流转业务方法。
 */
public interface RiskEventService {

  /**
   * 分页查询风险预警事项列表，支持状态、风险维度、关键词筛选。
   *
   * @param query 查询参数（状态/维度/关键词/分页）
   * @return 含统计数据、事项列表及分页信息的响应 DTO
   */
  RiskAlertListResponse listAlerts(RiskAlertQuery query);

  /**
   * 更新风险预警事项状态，并校验状态流转合法性。
   *
   * <p>合法流转路径：
   * <ul>
   *   <li>open → confirmed / dismissed</li>
   *   <li>confirmed → processing / dismissed</li>
   *   <li>processing → closed / dismissed</li>
   *   <li>closed / dismissed → 无合法目标（不可再流转）</li>
   * </ul>
   *
   * @param id         风险事项 ID
   * @param status     目标状态
   * @param assigneeId 处理人 ID，processing 状态时必填
   * @param comment    处理备注，closed / dismissed 状态时必填
   * @throws com.supply.risk.common.exception.ApiException NOT_FOUND 事项不存在；
   *         STATUS_TRANSITION_INVALID 流转不合法；
   *         ASSIGNEE_REQUIRED 缺少处理人；
   *         CLOSE_NOTE_REQUIRED 缺少关闭备注
   */
  void updateStatus(Long id, String status, Long assigneeId, String comment);
}
