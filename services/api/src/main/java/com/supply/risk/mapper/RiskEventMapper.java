package com.supply.risk.mapper;

import com.baomidou.mybatisplus.core.mapper.BaseMapper;
import com.supply.risk.model.dto.RiskAlertQuery;
import com.supply.risk.model.dto.RiskAlertRow;
import com.supply.risk.model.entity.RiskEvent;
import org.apache.ibatis.annotations.Mapper;
import org.apache.ibatis.annotations.Param;

import java.util.List;
import java.util.Map;

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

    /**
     * 分页查询风险预警事项列表（JOIN 供应商表获取供应商名称）。
     *
     * @param query 查询参数（状态/维度/关键词/分页）
     * @return 风险事项行列表
     */
    List<RiskAlertRow> listAlerts(@Param("query") RiskAlertQuery query);

    /**
     * 统计符合筛选条件的风险预警事项总数。
     *
     * @param query 查询参数（状态/维度/关键词）
     * @return 总数
     */
    long countAlerts(@Param("query") RiskAlertQuery query);

    /**
     * 按状态分组统计风险预警事项数量（全量统计，不受分页/筛选条件影响）。
     *
     * @return 包含 total/open/confirmed/processing/closed/dismissed 键的统计 Map
     */
    Map<String, Object> statsGroupByStatus();
}
