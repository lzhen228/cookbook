package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 更新风险预警事项状态的请求体 DTO。
 *
 * @param status     目标状态（confirmed / processing / closed / dismissed）
 * @param assigneeId 处理人 ID，processing 状态时必填
 * @param comment    处理备注，closed / dismissed 状态时必填
 */
public record UpdateAlertStatusRequest(
    String status,
    @JsonProperty("assignee_id") Long assigneeId,
    String comment
) {}
