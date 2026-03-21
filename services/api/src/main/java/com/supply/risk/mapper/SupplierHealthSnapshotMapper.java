package com.supply.risk.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.supply.risk.model.entity.SupplierHealthSnapshot;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

/**
 * 健康评分快照 Mapper。
 */
@Mapper
public interface SupplierHealthSnapshotMapper extends BaseMapper<SupplierHealthSnapshot> {

    /**
     * 查询供应商最新的健康评分快照。
     *
     * @param supplierId 供应商 ID
     * @return 最新快照，不存在返回 null
     */
    SupplierHealthSnapshot selectLatestBySupplier(@Param("supplierId") Long supplierId);
}
