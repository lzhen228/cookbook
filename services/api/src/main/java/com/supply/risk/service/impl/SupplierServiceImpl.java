package com.supply.risk.service.impl;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.supply.risk.common.exception.ApiException;
import com.supply.risk.common.response.ResultCode;
import com.supply.risk.common.util.CursorUtil;
import com.supply.risk.mapper.RiskEventMapper;
import com.supply.risk.mapper.SupplierHealthSnapshotMapper;
import com.supply.risk.mapper.SupplierMapper;
import com.supply.risk.model.dto.SupplierListItemDto;
import com.supply.risk.model.dto.SupplierListQuery;
import com.supply.risk.model.dto.SupplierListResponse;
import com.supply.risk.model.dto.SupplierProfileResponse;
import com.supply.risk.model.dto.SupplierProfileResponse.BasicInfo;
import com.supply.risk.model.dto.SupplierProfileResponse.HealthInfo;
import com.supply.risk.model.dto.SupplierProfileResponse.RiskEventBrief;
import com.supply.risk.model.dto.SupplierTabResponse;
import com.supply.risk.model.entity.RiskEvent;
import com.supply.risk.model.entity.Supplier;
import com.supply.risk.model.entity.SupplierHealthSnapshot;
import com.supply.risk.service.SupplierService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import java.math.BigDecimal;
import java.time.OffsetDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.concurrent.TimeUnit;

/**
 * 供应商服务实现。
 */
@Service
public class SupplierServiceImpl implements SupplierService {

    private static final Logger log = LoggerFactory.getLogger(SupplierServiceImpl.class);

    private static final int PROFILE_RISK_EVENT_LIMIT = 5;
    private static final long TAB_CACHE_TTL_HOURS = 24;
    private static final String TAB_CACHE_KEY_PREFIX = "supplier:tab:";

    /**
     * sort_by 白名单映射，防止 SQL 注入。
     * key: 前端传入值, value: 实际 SQL 列名
     */
    private static final Map<String, String> SORT_FIELD_MAP = Map.of(
            "health_score", "s.health_score_cache",
            "name", "s.name",
            "created_at", "s.created_at"
    );

    private static final Set<String> VALID_HEALTH_LEVELS = Set.of("high_risk", "attention", "low_risk");
    private static final Set<String> VALID_TAB_NAMES = Set.of(
            "basic-info", "business-info", "judicial", "credit", "tax"
    );

    private final SupplierMapper supplierMapper;
    private final SupplierHealthSnapshotMapper snapshotMapper;
    private final RiskEventMapper riskEventMapper;
    private final RedisTemplate<String, Object> redisTemplate;
    private final ObjectMapper objectMapper;

    public SupplierServiceImpl(SupplierMapper supplierMapper,
                               SupplierHealthSnapshotMapper snapshotMapper,
                               RiskEventMapper riskEventMapper,
                               RedisTemplate<String, Object> redisTemplate,
                               ObjectMapper objectMapper) {
        this.supplierMapper = supplierMapper;
        this.snapshotMapper = snapshotMapper;
        this.riskEventMapper = riskEventMapper;
        this.redisTemplate = redisTemplate;
        this.objectMapper = objectMapper;
    }

    /**
     * 分页查询供应商列表，支持游标分页和多条件筛选。
     *
     * @param query 查询参数
     * @return 分页供应商列表
     */
    @Override
    @Transactional(readOnly = true)
    public SupplierListResponse listSuppliers(SupplierListQuery query) {
        validateListQuery(query);
        Map<String, Object> params = buildListParams(query);

        long total = supplierMapper.countSupplierList(params);
        List<Supplier> suppliers = supplierMapper.selectSupplierList(params);

        List<SupplierListItemDto> items = suppliers.stream()
                .map(this::toListItemDto)
                .toList();

        String nextCursor = null;
        if (!suppliers.isEmpty() && suppliers.size() == query.pageSize()) {
            Supplier last = suppliers.get(suppliers.size() - 1);
            BigDecimal score = last.getHealthScoreCache() != null ? last.getHealthScoreCache() : BigDecimal.ZERO;
            nextCursor = CursorUtil.encode(score, last.getId());
        }

        return new SupplierListResponse(total, query.page(), query.pageSize(), nextCursor, items);
    }

    /**
     * 查询供应商画像主接口（首屏核心数据）。
     *
     * @param supplierId 供应商 ID
     * @return 画像响应
     */
    @Override
    @Transactional(readOnly = true)
    public SupplierProfileResponse getProfile(Long supplierId) {
        Supplier supplier = supplierMapper.selectProfileById(supplierId);
        if (supplier == null) {
            throw new ApiException(ResultCode.NOT_FOUND, "供应商不存在: " + supplierId);
        }

        BasicInfo basic = buildBasicInfo(supplier);
        HealthInfo health = buildHealthInfo(supplierId);
        List<RiskEventBrief> riskEvents = buildRiskEventBriefs(supplierId);
        int riskEventsTotal = riskEventMapper.countBySupplier(supplierId);

        return new SupplierProfileResponse(basic, health, riskEvents, riskEventsTotal);
    }

    /**
     * 查询供应商画像 Tab 数据（懒加载），优先读取 Redis 缓存。
     *
     * @param supplierId 供应商 ID
     * @param tabName    Tab 标识
     * @return Tab 数据响应
     */
    @Override
    @Transactional(readOnly = true)
    public SupplierTabResponse getTabData(Long supplierId, String tabName) {
        if (!VALID_TAB_NAMES.contains(tabName)) {
            throw new ApiException(ResultCode.PARAM_INVALID, "不支持的 Tab: " + tabName);
        }

        Supplier supplier = supplierMapper.selectProfileById(supplierId);
        if (supplier == null) {
            throw new ApiException(ResultCode.NOT_FOUND, "供应商不存在: " + supplierId);
        }

        String cacheKey = TAB_CACHE_KEY_PREFIX + supplierId + ":" + tabName;
        Map<String, Object> cached = null;
        try {
            @SuppressWarnings("unchecked")
            Map<String, Object> raw = (Map<String, Object>) redisTemplate.opsForValue().get(cacheKey);
            cached = raw;
        } catch (Exception e) {
            log.warn("Tab 缓存反序列化失败，自动清除缓存 key={}: {}", cacheKey, e.getMessage());
            redisTemplate.delete(cacheKey);
        }

        if (cached != null) {
            log.info("Tab 缓存命中: supplierId={}, tab={}", supplierId, tabName);
            return new SupplierTabResponse(
                    supplierId, tabName,
                    (String) cached.get("dataSource"),
                    OffsetDateTime.now(),
                    false,
                    cached.get("content")
            );
        }

        // 缓存未命中，从数据源拉取（MVP 阶段返回 ext_data 中对应字段）
        Object content = extractTabContent(supplier, tabName);
        String dataSource = resolveDataSource(tabName);

        // 写入 Redis 缓存，TTL 24h ± 30min 随机抖动
        long jitterMinutes = (long) (Math.random() * 60) - 30;
        long ttlMinutes = TAB_CACHE_TTL_HOURS * 60 + jitterMinutes;
        Map<String, Object> cacheValue = new HashMap<>();
        cacheValue.put("dataSource", dataSource);
        cacheValue.put("content", content != null ? content : new HashMap<>());
        redisTemplate.opsForValue().set(cacheKey, cacheValue, ttlMinutes, TimeUnit.MINUTES);

        return new SupplierTabResponse(
                supplierId, tabName, dataSource,
                OffsetDateTime.now(), false,
                content != null ? content : Map.of()
        );
    }

    /**
     * 切换供应商关注状态。
     *
     * @param supplierId 供应商 ID
     * @param followed   是否关注
     */
    @Override
    @Transactional
    public void toggleFollow(Long supplierId, boolean followed) {
        Supplier supplier = supplierMapper.selectById(supplierId);
        if (supplier == null) {
            throw new ApiException(ResultCode.NOT_FOUND, "供应商不存在: " + supplierId);
        }
        supplier.setIsFollowed(followed);
        supplierMapper.updateById(supplier);
    }

    private void validateListQuery(SupplierListQuery query) {
        // sort_by 白名单校验
        if (!SORT_FIELD_MAP.containsKey(query.sortBy())) {
            throw new ApiException(ResultCode.SORT_FIELD_INVALID);
        }

        // health_level 枚举校验
        if (query.healthLevel() != null) {
            for (String level : query.healthLevel()) {
                if (!VALID_HEALTH_LEVELS.contains(level)) {
                    throw new ApiException(ResultCode.HEALTH_LEVEL_INVALID, "非法健康等级: " + level);
                }
            }
        }

        // 无游标时校验 page 上限
        if (query.cursor() == null && query.page() > 20) {
            throw new ApiException(ResultCode.PAGE_OFFSET_EXCEED);
        }
    }

    private Map<String, Object> buildListParams(SupplierListQuery query) {
        Map<String, Object> params = new HashMap<>();

        // 筛选条件
        params.put("keyword", query.keyword());
        params.put("healthLevels", query.healthLevel());
        params.put("cooperationStatuses", query.cooperationStatus());
        params.put("regionProvince", query.regionProvince());
        params.put("listedStatus", query.listedStatus());
        params.put("isChinaTop500", query.isChinaTop500());
        params.put("isWorldTop500", query.isWorldTop500());
        params.put("supplierTypes", query.supplierType());
        params.put("natures", query.nature());
        params.put("isFollowed", query.isFollowed());

        // supply_items JSONB @> 操作符
        if (query.supplyItems() != null && !query.supplyItems().isEmpty()) {
            try {
                params.put("supplyItemsJson", objectMapper.writeValueAsString(query.supplyItems()));
            } catch (JsonProcessingException e) {
                throw new ApiException(ResultCode.PARAM_INVALID, "supplyItems 格式错误");
            }
        }

        // 排序：白名单映射后的安全列名
        String sortColumn = SORT_FIELD_MAP.get(query.sortBy());
        String sortDirection = "desc".equalsIgnoreCase(query.sortOrder()) ? "DESC" : "ASC";
        params.put("sortColumn", sortColumn);
        params.put("sortDirection", sortDirection);
        params.put("pageSize", query.pageSize());

        // 游标分页 vs OFFSET 分页
        if (query.cursor() != null && !query.cursor().isBlank()) {
            CursorUtil.CursorValue cursorValue = CursorUtil.decode(query.cursor());
            if ("DESC".equals(sortDirection)) {
                params.put("cursorScoreDesc", cursorValue.score());
                params.put("cursorIdDesc", cursorValue.id());
            } else {
                params.put("cursorScore", cursorValue.score());
                params.put("cursorId", cursorValue.id());
            }
        } else {
            int offset = (query.page() - 1) * query.pageSize();
            params.put("offset", offset);
        }

        return params;
    }

    private SupplierListItemDto toListItemDto(Supplier supplier) {
        String region = buildRegion(supplier.getRegionProvince(), supplier.getRegionCity());
        return new SupplierListItemDto(
                supplier.getId(),
                supplier.getName(),
                supplier.getHealthLevelCache(),
                supplier.getHealthScoreCache(),
                supplier.getWeekTrendCache(),
                region,
                supplier.getCooperationStatus(),
                supplier.getListedStatus(),
                supplier.getIsFollowed(),
                supplier.getCacheUpdatedAt()
        );
    }

    private BasicInfo buildBasicInfo(Supplier supplier) {
        String region = buildRegion(supplier.getRegionProvince(), supplier.getRegionCity());
        return new BasicInfo(
                supplier.getId(),
                supplier.getName(),
                supplier.getUnifiedCode(),
                supplier.getCooperationStatus(),
                region,
                supplier.getListedStatus(),
                supplier.getIsChinaTop500(),
                supplier.getIsWorldTop500(),
                supplier.getSupplierType(),
                supplier.getNature(),
                supplier.getSupplyItems(),
                supplier.getIsFollowed()
        );
    }

    private HealthInfo buildHealthInfo(Long supplierId) {
        SupplierHealthSnapshot snapshot = snapshotMapper.selectLatestBySupplier(supplierId);
        if (snapshot == null) {
            return new HealthInfo(null, null, null, null, "not_generated", null);
        }
        return new HealthInfo(
                snapshot.getHealthScore(),
                snapshot.getHealthLevel(),
                snapshot.getSnapshotDate(),
                snapshot.getDimensionScores(),
                "ready",
                snapshot.getCreatedAt()
        );
    }

    private List<RiskEventBrief> buildRiskEventBriefs(Long supplierId) {
        List<RiskEvent> events = riskEventMapper.selectRecentBySupplier(supplierId, PROFILE_RISK_EVENT_LIMIT);
        return events.stream()
                .map(e -> new RiskEventBrief(
                        e.getId(),
                        e.getRiskDimension(),
                        e.getDescription(),
                        e.getStatus(),
                        e.getTriggeredAt(),
                        e.getSourceUrl()
                ))
                .toList();
    }

    private Object extractTabContent(Supplier supplier, String tabName) {
        if (supplier.getExtData() == null) {
            return new HashMap<>();
        }
        if (supplier.getExtData() instanceof Map<?, ?> extMap) {
            Object tabContent = extMap.get(tabName);
            return tabContent != null ? tabContent : new HashMap<>();
        }
        return new HashMap<>();
    }

    private String resolveDataSource(String tabName) {
        return switch (tabName) {
            case "basic-info" -> "erp";
            case "business-info" -> "qcc";
            case "judicial" -> "tianyancha";
            case "credit" -> "pboc";
            case "tax" -> "tax_bureau";
            default -> "unknown";
        };
    }

    private String buildRegion(String province, String city) {
        if (province == null) return "";
        if (city == null) return province;
        return province + " " + city;
    }
}
