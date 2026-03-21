package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.time.OffsetDateTime;

/**
 * 供应商画像 Tab 懒加载统一响应，对齐 TECH_SPEC 5.4 节。
 *
 * @param supplierId 供应商 ID
 * @param tab        Tab 标识
 * @param dataSource 数据来源
 * @param dataAsOf   数据实际来源时间
 * @param isStale    是否为历史缓存数据
 * @param content    Tab 内容（各 Tab 结构不同）
 */
public record SupplierTabResponse(
        @JsonProperty("supplier_id") Long supplierId,
        String tab,
        @JsonProperty("data_source") String dataSource,
        @JsonProperty("data_as_of") OffsetDateTime dataAsOf,
        @JsonProperty("is_stale") boolean isStale,
        Object content
) {
}
