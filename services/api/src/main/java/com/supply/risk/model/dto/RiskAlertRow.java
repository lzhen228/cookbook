package com.supply.risk.model.dto;

import java.time.OffsetDateTime;

/**
 * MyBatis JOIN 查询结果行，用于风险预警事项列表查询的 resultType。
 *
 * <p>非 record，使用普通 POJO，与 MyBatis 的自动 setter 注入兼容。
 */
public class RiskAlertRow {

  private Long id;
  private Long supplierId;
  private String supplierName;
  private String riskDimension;
  private String description;
  private String status;
  private OffsetDateTime triggeredAt;
  private OffsetDateTime updatedAt;
  private String sourceUrl;
  private String closeNote;

  /**
   * 获取风险事项 ID。
   *
   * @return ID
   */
  public Long getId() {
    return id;
  }

  /**
   * 设置风险事项 ID。
   *
   * @param id ID
   */
  public void setId(Long id) {
    this.id = id;
  }

  /**
   * 获取供应商 ID。
   *
   * @return 供应商 ID
   */
  public Long getSupplierId() {
    return supplierId;
  }

  /**
   * 设置供应商 ID。
   *
   * @param supplierId 供应商 ID
   */
  public void setSupplierId(Long supplierId) {
    this.supplierId = supplierId;
  }

  /**
   * 获取供应商名称。
   *
   * @return 供应商名称
   */
  public String getSupplierName() {
    return supplierName;
  }

  /**
   * 设置供应商名称。
   *
   * @param supplierName 供应商名称
   */
  public void setSupplierName(String supplierName) {
    this.supplierName = supplierName;
  }

  /**
   * 获取风险维度。
   *
   * @return 风险维度
   */
  public String getRiskDimension() {
    return riskDimension;
  }

  /**
   * 设置风险维度。
   *
   * @param riskDimension 风险维度
   */
  public void setRiskDimension(String riskDimension) {
    this.riskDimension = riskDimension;
  }

  /**
   * 获取风险描述。
   *
   * @return 风险描述
   */
  public String getDescription() {
    return description;
  }

  /**
   * 设置风险描述。
   *
   * @param description 风险描述
   */
  public void setDescription(String description) {
    this.description = description;
  }

  /**
   * 获取处理状态。
   *
   * @return 状态
   */
  public String getStatus() {
    return status;
  }

  /**
   * 设置处理状态。
   *
   * @param status 状态
   */
  public void setStatus(String status) {
    this.status = status;
  }

  /**
   * 获取触发时间。
   *
   * @return 触发时间
   */
  public OffsetDateTime getTriggeredAt() {
    return triggeredAt;
  }

  /**
   * 设置触发时间。
   *
   * @param triggeredAt 触发时间
   */
  public void setTriggeredAt(OffsetDateTime triggeredAt) {
    this.triggeredAt = triggeredAt;
  }

  /**
   * 获取更新时间（关闭时为 closed_at，否则为 triggered_at）。
   *
   * @return 更新时间
   */
  public OffsetDateTime getUpdatedAt() {
    return updatedAt;
  }

  /**
   * 设置更新时间。
   *
   * @param updatedAt 更新时间
   */
  public void setUpdatedAt(OffsetDateTime updatedAt) {
    this.updatedAt = updatedAt;
  }

  /**
   * 获取来源 URL。
   *
   * @return 来源 URL
   */
  public String getSourceUrl() {
    return sourceUrl;
  }

  /**
   * 设置来源 URL。
   *
   * @param sourceUrl 来源 URL
   */
  public void setSourceUrl(String sourceUrl) {
    this.sourceUrl = sourceUrl;
  }

  /**
   * 获取关闭备注。
   *
   * @return 关闭备注
   */
  public String getCloseNote() {
    return closeNote;
  }

  /**
   * 设置关闭备注。
   *
   * @param closeNote 关闭备注
   */
  public void setCloseNote(String closeNote) {
    this.closeNote = closeNote;
  }
}
