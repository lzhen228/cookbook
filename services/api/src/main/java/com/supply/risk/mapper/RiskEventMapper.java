package com.supply.risk.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.supply.risk.model.entity.RiskEvent;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;

/**
 * 风险事项 Mapper。
 */
@Mapper
public interface RiskEventMapper extends BaseMapper<RiskEvent> {

    /**
     * 查询供应商最近的风险事项（按触发时间倒序）。
     *
     * @param supplierId 供应商 ID
     * @param limit      返回条数
     * @return 风险事项列表
     */
    List<RiskEvent> selectRecentBySupplier(@Param("supplierId") Long supplierId,
                                           @Param("limit") int limit);

    /**
     * 统计供应商的风险事项总数。
     *
     * @param supplierId 供应商 ID
     * @return 总数
     */
    int countBySupplier(@Param("supplierId") Long supplierId);
}
