package com.supply.risk.mapper;

import org.apache.ibatis.annotations.Mapper;

import java.util.List;
import java.util.Map;

/**
 * 风险看板聚合查询 Mapper。
 *
 * <p>所有方法均为只读聚合查询，不涉及写操作。
 */
@Mapper
public interface DashboardMapper {

  /**
   * 查询看板汇总统计指标（供应商总数、合作中数量、各健康等级数量、待处理事项数、近7天新增事项数）。
   *
   * @return 包含 total/cooperating/highRisk/attention/lowRisk/unscored/pending/new7d 键的统计 Map
   */
  Map<String, Object> selectStats();

  /**
   * 按健康等级分组统计供应商数量及占比。
   *
   * @return 包含 level/count/percentage 键的列表
   */
  List<Map<String, Object>> selectHealthDistribution();

  /**
   * 按风险维度统计待处理事项数和关联供应商的平均健康分。
   *
   * @return 包含 dimension/openCount/avgScore 键的列表
   */
  List<Map<String, Object>> selectRiskDimensionStats();

  /**
   * 查询最近14天每天的高风险供应商数和新增事项数。
   *
   * @return 包含 date/highRiskCount/newEvents 键的列表，按日期升序排列
   */
  List<Map<String, Object>> selectRiskTrend();

  /**
   * 查询健康分最低的10家合作中供应商及其关键风险信息。
   *
   * @return 包含 id/name/healthScore/healthLevel/region/weekTrend/topDimension/openEvents 键的列表
   */
  List<Map<String, Object>> selectTopRiskSuppliers();

  /**
   * 查询最近触发的10条风险事项（含供应商名称）。
   *
   * @return 包含 id/supplierId/supplierName/riskDimension/description/status/triggeredAt 键的列表
   */
  List<Map<String, Object>> selectRecentEvents();
}
