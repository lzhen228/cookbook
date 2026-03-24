package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * 风险预警事项列表接口响应 DTO。
 *
 * @param stats    各状态统计数据
 * @param items    当前页事项列表
 * @param total    总记录数
 * @param page     当前页码
 * @param pageSize 每页条数
 */
public record RiskAlertListResponse(
    RiskAlertStats stats,
    List<RiskAlertItem> items,
    long total,
    int page,
    @JsonProperty("page_size") int pageSize
) {}
