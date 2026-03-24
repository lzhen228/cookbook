package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.OffsetDateTime;

/**
 * 风险预警事项列表单条记录 DTO，用于 JSON 序列化返回前端。
 *
 * @param id            风险事项 ID
 * @param supplierId    供应商 ID
 * @param supplierName  供应商名称
 * @param riskDimension 风险维度
 * @param description   风险描述
 * @param status        处理状态
 * @param triggeredAt   触发时间
 * @param updatedAt     更新时间
 * @param sourceUrl     来源 URL
 * @param handler       处理人（当前版本返回 null）
 * @param comment       处理备注
 */
public record RiskAlertItem(
    Long id,
    @JsonProperty("supplier_id") Long supplierId,
    @JsonProperty("supplier_name") String supplierName,
    @JsonProperty("risk_dimension") String riskDimension,
    String description,
    String status,
    @JsonProperty("triggered_at") OffsetDateTime triggeredAt,
    @JsonProperty("updated_at") OffsetDateTime updatedAt,
    @JsonProperty("source_url") String sourceUrl,
    String handler,
    String comment
) {}
