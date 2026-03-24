package com.supply.risk.service.impl;

import com.supply.risk.common.exception.ApiException;
import com.supply.risk.common.response.ResultCode;
import com.supply.risk.mapper.RiskEventMapper;
import com.supply.risk.model.dto.RiskAlertItem;
import com.supply.risk.model.dto.RiskAlertListResponse;
import com.supply.risk.model.dto.RiskAlertQuery;
import com.supply.risk.model.dto.RiskAlertRow;
import com.supply.risk.model.dto.RiskAlertStats;
import com.supply.risk.model.entity.RiskEvent;
import com.supply.risk.service.RiskEventService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

/**
 * 风险预警事项服务实现。
 */
@Service
public class RiskEventServiceImpl implements RiskEventService {

  private static final Logger log = LoggerFactory.getLogger(RiskEventServiceImpl.class);

  /** 合法状态集合。 */
  private static final Set<String> VALID_STATUSES =
      Set.of("open", "confirmed", "processing", "closed", "dismissed");

  /** 合法状态流转映射：当前状态 → 允许的目标状态集合。 */
  private static final Map<String, Set<String>> TRANSITIONS = Map.of(
      "open",       Set.of("confirmed", "dismissed"),
      "confirmed",  Set.of("processing", "dismissed"),
      "processing", Set.of("closed", "dismissed"),
      "closed",     Set.of(),
      "dismissed",  Set.of()
  );

  private final RiskEventMapper riskEventMapper;

  /**
   * 构造函数注入。
   *
   * @param riskEventMapper 风险事项 Mapper
   */
  public RiskEventServiceImpl(RiskEventMapper riskEventMapper) {
    this.riskEventMapper = riskEventMapper;
  }

  /**
   * {@inheritDoc}
   */
  @Override
  public RiskAlertListResponse listAlerts(RiskAlertQuery query) {
    log.info("查询风险预警事项列表: status={}, riskDimension={}, page={}, pageSize={}",
        query.status(), query.riskDimension(), query.page(), query.pageSize());

    List<RiskAlertRow> rows = riskEventMapper.listAlerts(query);
    long total = riskEventMapper.countAlerts(query);
    Map<String, Object> statsMap = riskEventMapper.statsGroupByStatus();

    List<RiskAlertItem> items = rows.stream()
        .map(row -> new RiskAlertItem(
            row.getId(),
            row.getSupplierId(),
            row.getSupplierName(),
            row.getRiskDimension(),
            row.getDescription(),
            row.getStatus(),
            row.getTriggeredAt(),
            row.getUpdatedAt(),
            row.getSourceUrl(),
            null,
            row.getCloseNote()
        ))
        .collect(Collectors.toList());

    RiskAlertStats stats = buildStats(statsMap);

    return new RiskAlertListResponse(stats, items, total, query.page(), query.pageSize());
  }

  /**
   * {@inheritDoc}
   */
  @Override
  @Transactional
  public void updateStatus(Long id, String status, Long assigneeId, String comment) {
    log.info("更新风险预警事项状态: id={}, targetStatus={}", id, status);

    if (!VALID_STATUSES.contains(status)) {
      throw new ApiException(ResultCode.PARAM_INVALID, "status 不合法: " + status);
    }

    RiskEvent event = riskEventMapper.selectById(id);
    if (event == null) {
      throw new ApiException(ResultCode.NOT_FOUND);
    }

    String currentStatus = event.getStatus();
    Set<String> allowed = TRANSITIONS.getOrDefault(currentStatus, Set.of());
    if (!allowed.contains(status)) {
      log.warn("状态流转不合法: id={}, from={}, to={}", id, currentStatus, status);
      throw new ApiException(ResultCode.STATUS_TRANSITION_INVALID);
    }

    if ("processing".equals(status) && assigneeId == null) {
      throw new ApiException(ResultCode.ASSIGNEE_REQUIRED);
    }

    if (("closed".equals(status) || "dismissed".equals(status))
        && (comment == null || comment.isBlank())) {
      throw new ApiException(ResultCode.CLOSE_NOTE_REQUIRED);
    }

    RiskEvent update = buildUpdateEntity(id, status, assigneeId, comment);
    riskEventMapper.updateById(update);

    log.info("风险预警事项状态更新完成: id={}, from={}, to={}", id, currentStatus, status);
  }

  /**
   * 从数据库统计 map 构建 RiskAlertStats DTO。
   *
   * @param statsMap statsGroupByStatus 查询结果
   * @return 统计汇总 DTO
   */
  private RiskAlertStats buildStats(Map<String, Object> statsMap) {
    long total     = toLong(statsMap.getOrDefault("total", 0L));
    long open      = toLong(statsMap.getOrDefault("open", 0L));
    long confirmed = toLong(statsMap.getOrDefault("confirmed", 0L));
    long processing = toLong(statsMap.getOrDefault("processing", 0L));
    long closed    = toLong(statsMap.getOrDefault("closed", 0L));
    long dismissed = toLong(statsMap.getOrDefault("dismissed", 0L));
    return new RiskAlertStats(total, open, confirmed, processing, closed, dismissed);
  }

  /**
   * 将 Object 安全转换为 long，兼容 Integer / Long / BigDecimal 等类型。
   *
   * @param value 原始值
   * @return long 值
   */
  private long toLong(Object value) {
    if (value instanceof Number num) {
      return num.longValue();
    }
    return 0L;
  }

  /**
   * 构建用于 updateById 的 RiskEvent 实体（只设置需要更新的字段）。
   *
   * @param id         事项 ID
   * @param status     目标状态
   * @param assigneeId 处理人 ID
   * @param comment    处理备注
   * @return 待更新实体
   */
  private RiskEvent buildUpdateEntity(Long id, String status, Long assigneeId, String comment) {
    RiskEvent update = new RiskEvent();
    update.setId(id);
    update.setStatus(status);
    if (assigneeId != null) {
      update.setAssigneeId(assigneeId);
    }
    if (comment != null && !comment.isBlank()) {
      update.setCloseNote(comment);
    }
    if ("closed".equals(status) || "dismissed".equals(status)) {
      update.setClosedAt(OffsetDateTime.now());
    }
    return update;
  }
}
