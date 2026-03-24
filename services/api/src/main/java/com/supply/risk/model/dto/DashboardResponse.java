package com.supply.risk.model.dto;

import com.fasterxml.jackson.annotation.JsonProperty;

import java.math.BigDecimal;
import java.util.List;

/**
 * 风险看板主接口响应 DTO。
 *
 * @param stats              汇总统计指标
 * @param healthDistribution 健康等级分布
 * @param riskDimensionStats 风险维度统计
 * @param riskTrend          最近14天风险趋势
 * @param topRiskSuppliers   风险最高的10家供应商
 * @param recentEvents       最近10条风险事项
 */
public record DashboardResponse(
    DashboardStats stats,
    @JsonProperty("health_distribution") List<HealthDistItem> healthDistribution,
    @JsonProperty("risk_dimension_stats") List<RiskDimensionStat> riskDimensionStats,
    @JsonProperty("risk_trend") List<RiskTrendPoint> riskTrend,
    @JsonProperty("top_risk_suppliers") List<TopRiskSupplier> topRiskSuppliers,
    @JsonProperty("recent_events") List<DashboardRiskEvent> recentEvents
) {

  /**
   * 看板汇总统计指标。
   */
  public record DashboardStats(
      @JsonProperty("total_suppliers") long totalSuppliers,
      @JsonProperty("cooperating_count") long cooperatingCount,
      @JsonProperty("high_risk_count") long highRiskCount,
      @JsonProperty("attention_count") long attentionCount,
      @JsonProperty("low_risk_count") long lowRiskCount,
      @JsonProperty("unscored_count") long unscoredCount,
      @JsonProperty("pending_risk_events") long pendingRiskEvents,
      @JsonProperty("new_events_7d") long newEvents7d
  ) {
  }

  /**
   * 健康等级分布条目。
   */
  public record HealthDistItem(
      String level,
      long count,
      double percentage
  ) {
  }

  /**
   * 风险维度统计条目。
   */
  public record RiskDimensionStat(
      String dimension,
      @JsonProperty("open_count") long openCount,
      @JsonProperty("avg_score") BigDecimal avgScore
  ) {
  }

  /**
   * 风险趋势时间点（最近14天，每天一条）。
   */
  public record RiskTrendPoint(
      String date,
      @JsonProperty("high_risk_count") long highRiskCount,
      @JsonProperty("new_events") long newEvents
  ) {
  }

  /**
   * 风险最高供应商列表条目。
   */
  public record TopRiskSupplier(
      long id,
      String name,
      @JsonProperty("health_score") BigDecimal healthScore,
      @JsonProperty("health_level") String healthLevel,
      String region,
      @JsonProperty("week_trend") BigDecimal weekTrend,
      @JsonProperty("top_dimension") String topDimension,
      @JsonProperty("open_events") long openEvents
  ) {
  }

  /**
   * 看板风险事项摘要条目。
   */
  public record DashboardRiskEvent(
      long id,
      @JsonProperty("supplier_id") long supplierId,
      @JsonProperty("supplier_name") String supplierName,
      @JsonProperty("risk_dimension") String riskDimension,
      String description,
      String status,
      @JsonProperty("triggered_at") String triggeredAt
  ) {
  }
}
