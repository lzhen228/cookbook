package com.supply.risk.service.impl;

import com.supply.risk.mapper.DashboardMapper;
import com.supply.risk.model.dto.DashboardResponse;
import com.supply.risk.model.dto.DashboardResponse.DashboardRiskEvent;
import com.supply.risk.model.dto.DashboardResponse.DashboardStats;
import com.supply.risk.model.dto.DashboardResponse.HealthDistItem;
import com.supply.risk.model.dto.DashboardResponse.RiskDimensionStat;
import com.supply.risk.model.dto.DashboardResponse.RiskTrendPoint;
import com.supply.risk.model.dto.DashboardResponse.TopRiskSupplier;
import com.supply.risk.service.DashboardService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;

import java.math.BigDecimal;
import java.sql.Timestamp;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.util.List;
import java.util.Map;
import java.util.stream.Collectors;

/**
 * 风险看板服务实现。
 */
@Service
public class DashboardServiceImpl implements DashboardService {

  private static final Logger log = LoggerFactory.getLogger(DashboardServiceImpl.class);
  private static final DateTimeFormatter DATE_FORMATTER = DateTimeFormatter.ofPattern("yyyy-MM-dd");

  private final DashboardMapper dashboardMapper;

  /**
   * 构造函数注入。
   *
   * @param dashboardMapper 看板聚合查询 Mapper
   */
  public DashboardServiceImpl(DashboardMapper dashboardMapper) {
    this.dashboardMapper = dashboardMapper;
  }

  /**
   * {@inheritDoc}
   */
  @Override
  public DashboardResponse getDashboard() {
    log.info("查询风险看板数据");

    Map<String, Object> statsMap = dashboardMapper.selectStats();
    List<Map<String, Object>> distList = dashboardMapper.selectHealthDistribution();
    List<Map<String, Object>> dimStatsList = dashboardMapper.selectRiskDimensionStats();
    List<Map<String, Object>> trendList = dashboardMapper.selectRiskTrend();
    List<Map<String, Object>> topSupplierList = dashboardMapper.selectTopRiskSuppliers();
    List<Map<String, Object>> recentEventList = dashboardMapper.selectRecentEvents();

    DashboardStats stats = buildStats(statsMap);
    List<HealthDistItem> healthDistribution = buildHealthDist(distList);
    List<RiskDimensionStat> riskDimensionStats = buildRiskDimensionStats(dimStatsList);
    List<RiskTrendPoint> riskTrend = buildRiskTrend(trendList);
    List<TopRiskSupplier> topRiskSuppliers = buildTopRiskSuppliers(topSupplierList);
    List<DashboardRiskEvent> recentEvents = buildRecentEvents(recentEventList);

    log.info("风险看板数据查询完成: totalSuppliers={}, pendingRiskEvents={}",
        stats.totalSuppliers(), stats.pendingRiskEvents());

    return new DashboardResponse(stats, healthDistribution, riskDimensionStats,
        riskTrend, topRiskSuppliers, recentEvents);
  }

  /**
   * 从 Map 构建汇总统计 DTO。
   *
   * @param m selectStats 查询结果
   * @return 汇总统计 DTO
   */
  private DashboardStats buildStats(Map<String, Object> m) {
    return new DashboardStats(
        toLong(m.get("total")),
        toLong(m.get("cooperating")),
        toLong(m.get("highRisk")),
        toLong(m.get("attention")),
        toLong(m.get("lowRisk")),
        toLong(m.get("unscored")),
        toLong(m.get("pending")),
        toLong(m.get("new7d"))
    );
  }

  /**
   * 从 Map 列表构建健康分布 DTO 列表。
   *
   * @param list selectHealthDistribution 查询结果
   * @return 健康分布 DTO 列表
   */
  private List<HealthDistItem> buildHealthDist(List<Map<String, Object>> list) {
    return list.stream()
        .map(m -> new HealthDistItem(
            (String) m.get("level"),
            toLong(m.get("count")),
            toDouble(m.get("percentage"))
        ))
        .collect(Collectors.toList());
  }

  /**
   * 从 Map 列表构建风险维度统计 DTO 列表。
   *
   * @param list selectRiskDimensionStats 查询结果
   * @return 风险维度统计 DTO 列表
   */
  private List<RiskDimensionStat> buildRiskDimensionStats(List<Map<String, Object>> list) {
    return list.stream()
        .map(m -> new RiskDimensionStat(
            (String) m.get("dimension"),
            toLong(m.get("openCount")),
            toBigDecimal(m.get("avgScore"))
        ))
        .collect(Collectors.toList());
  }

  /**
   * 从 Map 列表构建风险趋势 DTO 列表。
   *
   * @param list selectRiskTrend 查询结果
   * @return 风险趋势 DTO 列表
   */
  private List<RiskTrendPoint> buildRiskTrend(List<Map<String, Object>> list) {
    return list.stream()
        .map(m -> new RiskTrendPoint(
            toDateString(m.get("date")),
            toLong(m.get("highRiskCount")),
            toLong(m.get("newEvents"))
        ))
        .collect(Collectors.toList());
  }

  /**
   * 从 Map 列表构建高风险供应商 DTO 列表。
   *
   * @param list selectTopRiskSuppliers 查询结果
   * @return 高风险供应商 DTO 列表
   */
  private List<TopRiskSupplier> buildTopRiskSuppliers(List<Map<String, Object>> list) {
    return list.stream()
        .map(m -> new TopRiskSupplier(
            toLong(m.get("id")),
            (String) m.get("name"),
            toBigDecimal(m.get("healthScore")),
            (String) m.get("healthLevel"),
            (String) m.get("region"),
            toBigDecimal(m.get("weekTrend")),
            (String) m.get("topDimension"),
            toLong(m.get("openEvents"))
        ))
        .collect(Collectors.toList());
  }

  /**
   * 从 Map 列表构建近期风险事项 DTO 列表。
   *
   * @param list selectRecentEvents 查询结果
   * @return 近期风险事项 DTO 列表
   */
  private List<DashboardRiskEvent> buildRecentEvents(List<Map<String, Object>> list) {
    return list.stream()
        .map(m -> new DashboardRiskEvent(
            toLong(m.get("id")),
            toLong(m.get("supplierId")),
            (String) m.get("supplierName"),
            (String) m.get("riskDimension"),
            (String) m.get("description"),
            (String) m.get("status"),
            toTimestampString(m.get("triggeredAt"))
        ))
        .collect(Collectors.toList());
  }

  /**
   * 将 Object 安全转换为 long，兼容 Integer / Long / BigDecimal 等类型。
   *
   * @param value 原始值
   * @return long 值，null 或无法转换时返回 0
   */
  private long toLong(Object value) {
    if (value instanceof Number num) {
      return num.longValue();
    }
    return 0L;
  }

  /**
   * 将 Object 安全转换为 double，兼容 Float / Double / BigDecimal 等类型。
   *
   * @param value 原始值
   * @return double 值，null 或无法转换时返回 0.0
   */
  private double toDouble(Object value) {
    if (value instanceof Number num) {
      return num.doubleValue();
    }
    return 0.0;
  }

  /**
   * 将 Object 安全转换为 BigDecimal，兼容 BigDecimal / Double / Float / Long / Integer 等类型。
   *
   * @param value 原始值
   * @return BigDecimal 值，null 时返回 null
   */
  private BigDecimal toBigDecimal(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof BigDecimal bd) {
      return bd;
    }
    if (value instanceof Number num) {
      return BigDecimal.valueOf(num.doubleValue());
    }
    return null;
  }

  /**
   * 将日期对象转换为 yyyy-MM-dd 格式字符串，兼容 java.sql.Date / LocalDate / String。
   *
   * @param value 原始日期值
   * @return 日期字符串，null 时返回空字符串
   */
  private String toDateString(Object value) {
    if (value == null) {
      return "";
    }
    if (value instanceof java.sql.Date sqlDate) {
      return sqlDate.toLocalDate().format(DATE_FORMATTER);
    }
    if (value instanceof LocalDate ld) {
      return ld.format(DATE_FORMATTER);
    }
    return value.toString();
  }

  /**
   * 将时间戳对象转换为 ISO-8601 字符串，兼容 Timestamp / OffsetDateTime / String。
   *
   * @param value 原始时间戳值
   * @return ISO-8601 时间字符串，null 时返回 null（由 Jackson NON_NULL 策略省略该字段）
   */
  private String toTimestampString(Object value) {
    if (value == null) {
      return null;
    }
    if (value instanceof Timestamp ts) {
      return ts.toInstant().atZone(ZoneId.systemDefault()).toOffsetDateTime().toString();
    }
    if (value instanceof OffsetDateTime odt) {
      return odt.toString();
    }
    return value.toString();
  }
}
