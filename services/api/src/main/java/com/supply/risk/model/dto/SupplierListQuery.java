package com.supply.risk.model.dto;

import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;

import java.util.List;

/**
 * 供应商列表查询参数，对齐 TECH_SPEC 5.2 节。
 *
 * @param keyword            名称关键词（pg_trgm 索引）
 * @param healthLevel        健康等级筛选（逗号分隔）
 * @param cooperationStatus  合作状态筛选（逗号分隔）
 * @param regionProvince     注册省份
 * @param listedStatus       上市状态
 * @param isChinaTop500      中国 500 强
 * @param isWorldTop500      世界 500 强
 * @param supplierType       供应商类型（逗号分隔）
 * @param nature             企业性质（逗号分隔）
 * @param supplyItems        供应物（JSONB @> 匹配）
 * @param isFollowed         是否已关注
 * @param sortBy             排序字段，白名单：health_score/name/created_at
 * @param sortOrder          排序方向：asc/desc
 * @param cursor             游标值（Base64 编码），有此参数时忽略 page
 * @param page               页码，默认 1，仅无 cursor 时生效，限制 <= 20
 * @param pageSize           每页条数，默认 20，最大 100
 */
public record SupplierListQuery(
        String keyword,
        List<String> healthLevel,
        List<String> cooperationStatus,
        String regionProvince,
        String listedStatus,
        Boolean isChinaTop500,
        Boolean isWorldTop500,
        List<String> supplierType,
        List<String> nature,
        List<String> supplyItems,
        Boolean isFollowed,
        String sortBy,
        String sortOrder,
        String cursor,
        @Min(value = 1, message = "page 最小值为 1")
        @Max(value = 20, message = "OFFSET 分页超过页码限制，请改用游标分页")
        Integer page,
        @Min(value = 1, message = "page_size 最小值为 1")
        @Max(value = 100, message = "page_size 超过 100")
        Integer pageSize
) {
    /**
     * 提供默认值的规范化构造。
     */
    public SupplierListQuery {
        if (sortBy == null || sortBy.isBlank()) sortBy = "health_score";
        if (sortOrder == null || sortOrder.isBlank()) sortOrder = "asc";
        if (page == null) page = 1;
        if (pageSize == null) pageSize = 20;
    }
}
