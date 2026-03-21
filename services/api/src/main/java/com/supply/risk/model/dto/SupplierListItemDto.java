package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.time.OffsetDateTime;

/**
 * 供应商列表单项响应，对齐 TECH_SPEC 5.2 节响应 items。
 *
 * @param id                供应商 ID
 * @param name              供应商名称
 * @param healthLevel       健康等级
 * @param healthScore       健康分
 * @param weekTrend         近 7 天变化量
 * @param region            地区（省 + 市）
 * @param cooperationStatus 合作状态
 * @param listedStatus      上市状态
 * @param isFollowed        是否已关注
 * @param cacheUpdatedAt    缓存更新时间
 */
public record SupplierListItemDto(
        Long id,
        String name,
        @JsonProperty("health_level") String healthLevel,
        @JsonProperty("health_score") BigDecimal healthScore,
        @JsonProperty("week_trend") BigDecimal weekTrend,
        String region,
        @JsonProperty("cooperation_status") String cooperationStatus,
        @JsonProperty("listed_status") String listedStatus,
        @JsonProperty("is_followed") Boolean isFollowed,
        @JsonProperty("cache_updated_at") OffsetDateTime cacheUpdatedAt
) {
}
