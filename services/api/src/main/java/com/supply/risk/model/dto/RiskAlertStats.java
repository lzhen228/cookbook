package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

/**
 * 风险预警事项状态统计汇总 DTO。
 *
 * @param total      总计
 * @param open       待确认
 * @param confirmed  已确认
 * @param processing 处理中
 * @param closed     已关闭
 * @param dismissed  已忽略
 */
public record RiskAlertStats(
    @JsonProperty("total") long total,
    @JsonProperty("open") long open,
    @JsonProperty("confirmed") long confirmed,
    @JsonProperty("processing") long processing,
    @JsonProperty("closed") long closed,
    @JsonProperty("dismissed") long dismissed
) {}
