package com.supply.risk.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.supply.risk.model.entity.Supplier;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.math.BigDecimal;
import java.util.List;
import java.util.Map;

/**
 * 供应商 Mapper，复杂查询通过 XML 定义。
 */
@Mapper
public interface SupplierMapper extends BaseMapper<Supplier> {

    /**
     * 游标分页查询供应商列表。
     *
     * @param params 动态筛选条件
     * @return 供应商列表
     */
    List<Supplier> selectSupplierList(@Param("params") Map<String, Object> params);

    /**
     * 统计筛选条件下的供应商总数。
     *
     * @param params 动态筛选条件
     * @return 总数
     */
    long countSupplierList(@Param("params") Map<String, Object> params);

    /**
     * 查询指定供应商的完整信息（画像用）。
     *
     * @param supplierId 供应商 ID
     * @return 供应商实体，不存在返回 null
     */
    Supplier selectProfileById(@Param("supplierId") Long supplierId);
}
