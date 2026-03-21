package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.util.List;

/**
 * 供应商列表分页响应，对齐 TECH_SPEC 5.2 节。
 *
 * @param total      总记录数
 * @param page       当前页码
 * @param pageSize   每页条数
 * @param nextCursor 下一页游标，null 表示已是最后页
 * @param items      供应商列表项
 */
public record SupplierListResponse(
        long total,
        int page,
        @JsonProperty("page_size") int pageSize,
        @JsonProperty("next_cursor") String nextCursor,
        List<SupplierListItemDto> items
) {
}
