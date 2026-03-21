package com.supply.risk.model.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.extension.handlers.JacksonTypeHandler;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Map;

/**
 * 健康评分快照实体。
 */
@TableName(value = "supplier_health_snapshot", autoResultMap = true)
public class SupplierHealthSnapshot {

    @TableId(type = IdType.AUTO)
    private Long id;

    private Long supplierId;

    private Long planId;

    private BigDecimal healthScore;

    private String healthLevel;

    @TableField(typeHandler = JacksonTypeHandler.class)
    private Map<String, BigDecimal> dimensionScores;

    private LocalDate snapshotDate;

    private OffsetDateTime createdAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public Long getSupplierId() {
        return supplierId;
    }

    public void setSupplierId(Long supplierId) {
        this.supplierId = supplierId;
    }

    public Long getPlanId() {
        return planId;
    }

    public void setPlanId(Long planId) {
        this.planId = planId;
    }

    public BigDecimal getHealthScore() {
        return healthScore;
    }

    public void setHealthScore(BigDecimal healthScore) {
        this.healthScore = healthScore;
    }

    public String getHealthLevel() {
        return healthLevel;
    }

    public void setHealthLevel(String healthLevel) {
        this.healthLevel = healthLevel;
    }

    public Map<String, BigDecimal> getDimensionScores() {
        return dimensionScores;
    }

    public void setDimensionScores(Map<String, BigDecimal> dimensionScores) {
        this.dimensionScores = dimensionScores;
    }

    public LocalDate getSnapshotDate() {
        return snapshotDate;
    }

    public void setSnapshotDate(LocalDate snapshotDate) {
        this.snapshotDate = snapshotDate;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }
}
