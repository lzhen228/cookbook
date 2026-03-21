package com.supply.risk.model.entity;

import com.baomidou.mybatisplus.annotation.IdType;
import com.baomidou.mybatisplus.annotation.TableField;
import com.baomidou.mybatisplus.annotation.TableId;
import com.baomidou.mybatisplus.annotation.TableName;
import com.baomidou.mybatisplus.extension.handlers.JacksonTypeHandler;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.List;

/**
 * 供应商主表实体。
 */
@TableName(value = "supplier", autoResultMap = true)
public class Supplier {

    @TableId(type = IdType.AUTO)
    private Long id;

    private String name;

    private String unifiedCode;

    private String cooperationStatus;

    private String regionProvince;

    private String regionCity;

    private String listedStatus;

    private Boolean isChinaTop500;

    private Boolean isWorldTop500;

    private String supplierType;

    private String nature;

    @TableField(typeHandler = JacksonTypeHandler.class)
    private List<String> supplyItems;

    private Boolean isFollowed;

    @TableField(typeHandler = JacksonTypeHandler.class)
    private Object extData;

    private BigDecimal healthScoreCache;

    private String healthLevelCache;

    private BigDecimal weekTrendCache;

    private OffsetDateTime cacheUpdatedAt;

    private OffsetDateTime createdAt;

    private OffsetDateTime updatedAt;

    public Long getId() {
        return id;
    }

    public void setId(Long id) {
        this.id = id;
    }

    public String getName() {
        return name;
    }

    public void setName(String name) {
        this.name = name;
    }

    public String getUnifiedCode() {
        return unifiedCode;
    }

    public void setUnifiedCode(String unifiedCode) {
        this.unifiedCode = unifiedCode;
    }

    public String getCooperationStatus() {
        return cooperationStatus;
    }

    public void setCooperationStatus(String cooperationStatus) {
        this.cooperationStatus = cooperationStatus;
    }

    public String getRegionProvince() {
        return regionProvince;
    }

    public void setRegionProvince(String regionProvince) {
        this.regionProvince = regionProvince;
    }

    public String getRegionCity() {
        return regionCity;
    }

    public void setRegionCity(String regionCity) {
        this.regionCity = regionCity;
    }

    public String getListedStatus() {
        return listedStatus;
    }

    public void setListedStatus(String listedStatus) {
        this.listedStatus = listedStatus;
    }

    public Boolean getIsChinaTop500() {
        return isChinaTop500;
    }

    public void setIsChinaTop500(Boolean isChinaTop500) {
        this.isChinaTop500 = isChinaTop500;
    }

    public Boolean getIsWorldTop500() {
        return isWorldTop500;
    }

    public void setIsWorldTop500(Boolean isWorldTop500) {
        this.isWorldTop500 = isWorldTop500;
    }

    public String getSupplierType() {
        return supplierType;
    }

    public void setSupplierType(String supplierType) {
        this.supplierType = supplierType;
    }

    public String getNature() {
        return nature;
    }

    public void setNature(String nature) {
        this.nature = nature;
    }

    public List<String> getSupplyItems() {
        return supplyItems;
    }

    public void setSupplyItems(List<String> supplyItems) {
        this.supplyItems = supplyItems;
    }

    public Boolean getIsFollowed() {
        return isFollowed;
    }

    public void setIsFollowed(Boolean isFollowed) {
        this.isFollowed = isFollowed;
    }

    public Object getExtData() {
        return extData;
    }

    public void setExtData(Object extData) {
        this.extData = extData;
    }

    public BigDecimal getHealthScoreCache() {
        return healthScoreCache;
    }

    public void setHealthScoreCache(BigDecimal healthScoreCache) {
        this.healthScoreCache = healthScoreCache;
    }

    public String getHealthLevelCache() {
        return healthLevelCache;
    }

    public void setHealthLevelCache(String healthLevelCache) {
        this.healthLevelCache = healthLevelCache;
    }

    public BigDecimal getWeekTrendCache() {
        return weekTrendCache;
    }

    public void setWeekTrendCache(BigDecimal weekTrendCache) {
        this.weekTrendCache = weekTrendCache;
    }

    public OffsetDateTime getCacheUpdatedAt() {
        return cacheUpdatedAt;
    }

    public void setCacheUpdatedAt(OffsetDateTime cacheUpdatedAt) {
        this.cacheUpdatedAt = cacheUpdatedAt;
    }

    public OffsetDateTime getCreatedAt() {
        return createdAt;
    }

    public void setCreatedAt(OffsetDateTime createdAt) {
        this.createdAt = createdAt;
    }

    public OffsetDateTime getUpdatedAt() {
        return updatedAt;
    }

    public void setUpdatedAt(OffsetDateTime updatedAt) {
        this.updatedAt = updatedAt;
    }
}
