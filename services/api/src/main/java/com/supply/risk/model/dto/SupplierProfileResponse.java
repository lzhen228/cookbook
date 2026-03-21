package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * 供应商画像主接口响应，对齐 TECH_SPEC 5.3 节。
 *
 * @param basic           基础信息
 * @param health          健康评分卡
 * @param riskEvents      前 5 条风险事项
 * @param riskEventsTotal 风险事项总数
 */
public record SupplierProfileResponse(
        BasicInfo basic,
        HealthInfo health,
        @JsonProperty("risk_events") List<RiskEventBrief> riskEvents,
        @JsonProperty("risk_events_total") int riskEventsTotal
) {

    /**
     * 供应商基础信息。
     */
    public record BasicInfo(
            Long id,
            String name,
            @JsonProperty("unified_code") String unifiedCode,
            @JsonProperty("cooperation_status") String cooperationStatus,
            String region,
            @JsonProperty("listed_status") String listedStatus,
            @JsonProperty("is_china_top500") Boolean isChinaTop500,
            @JsonProperty("is_world_top500") Boolean isWorldTop500,
            @JsonProperty("supplier_type") String supplierType,
            String nature,
            @JsonProperty("supply_items") List<String> supplyItems,
            @JsonProperty("is_followed") Boolean isFollowed
    ) {
    }

    /**
     * 健康评分卡。
     */
    public record HealthInfo(
            BigDecimal score,
            String level,
            @JsonProperty("snapshot_date") LocalDate snapshotDate,
            @JsonProperty("dimension_scores") Map<String, BigDecimal> dimensionScores,
            @JsonProperty("report_status") String reportStatus,
            @JsonProperty("report_generated_at") OffsetDateTime reportGeneratedAt
    ) {
    }

    /**
     * 风险事项摘要。
     */
    public record RiskEventBrief(
            Long id,
            @JsonProperty("risk_dimension") String riskDimension,
            String description,
            String status,
            @JsonProperty("triggered_at") OffsetDateTime triggeredAt,
            @JsonProperty("source_url") String sourceUrl
    ) {
    }
}
