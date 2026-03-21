package com.supply.risk.testutil;

import com.supply.risk.model.entity.RiskEvent;
import com.supply.risk.model.entity.Supplier;
import com.supply.risk.model.entity.SupplierHealthSnapshot;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;

/**
 * 测试数据工厂，集中管理测试 fixture，避免各测试类重复创建。
 *
 * <p>所有供应商统一信用代码使用 91440300TEST00001 格式（TEST 标识），
 * 遵循 CLAUDE.md 7.4 节测试数据规范。
 */
public final class TestDataFactory {

    private TestDataFactory() {
    }

    // ========== 供应商 ==========

    /**
     * 创建一个合作中的低风险供应商。
     */
    public static Supplier createLowRiskSupplier() {
        Supplier s = new Supplier();
        s.setId(1001L);
        s.setName("测试供应商A");
        s.setUnifiedCode("91440300TEST00001");
        s.setCooperationStatus("cooperating");
        s.setRegionProvince("广东");
        s.setRegionCity("深圳");
        s.setListedStatus("listed");
        s.setIsChinaTop500(true);
        s.setIsWorldTop500(false);
        s.setSupplierType("原材料");
        s.setNature("民营企业");
        s.setSupplyItems(List.of("钢材", "铝材"));
        s.setIsFollowed(true);
        s.setExtData(Map.of(
                "basic-info", Map.of("legal_rep", "张三", "reg_capital", "5000万"),
                "judicial", Map.of("cases", List.of())
        ));
        s.setHealthScoreCache(new BigDecimal("85.5"));
        s.setHealthLevelCache("low_risk");
        s.setWeekTrendCache(new BigDecimal("2.3"));
        s.setCacheUpdatedAt(OffsetDateTime.now());
        s.setCreatedAt(OffsetDateTime.now().minusDays(30));
        s.setUpdatedAt(OffsetDateTime.now());
        return s;
    }

    /**
     * 创建一个高风险供应商。
     */
    public static Supplier createHighRiskSupplier() {
        Supplier s = new Supplier();
        s.setId(1002L);
        s.setName("测试供应商B");
        s.setUnifiedCode("91440300TEST00002");
        s.setCooperationStatus("restricted");
        s.setRegionProvince("北京");
        s.setRegionCity(null);
        s.setListedStatus("unlisted");
        s.setIsChinaTop500(false);
        s.setIsWorldTop500(false);
        s.setSupplierType("服务");
        s.setNature("国有企业");
        s.setSupplyItems(List.of("IT服务"));
        s.setIsFollowed(false);
        s.setExtData(null);
        s.setHealthScoreCache(new BigDecimal("25.0"));
        s.setHealthLevelCache("high_risk");
        s.setWeekTrendCache(new BigDecimal("-5.2"));
        s.setCacheUpdatedAt(OffsetDateTime.now());
        s.setCreatedAt(OffsetDateTime.now().minusDays(60));
        s.setUpdatedAt(OffsetDateTime.now());
        return s;
    }

    /**
     * 创建一个未评分（无快照）的供应商。
     */
    public static Supplier createUnscoredSupplier() {
        Supplier s = new Supplier();
        s.setId(1003L);
        s.setName("测试供应商C");
        s.setUnifiedCode("91440300TEST00003");
        s.setCooperationStatus("potential");
        s.setRegionProvince("上海");
        s.setRegionCity("浦东");
        s.setListedStatus(null);
        s.setIsChinaTop500(false);
        s.setIsWorldTop500(false);
        s.setSupplierType(null);
        s.setNature(null);
        s.setSupplyItems(null);
        s.setIsFollowed(false);
        s.setExtData(null);
        s.setHealthScoreCache(null);
        s.setHealthLevelCache(null);
        s.setWeekTrendCache(null);
        s.setCacheUpdatedAt(null);
        s.setCreatedAt(OffsetDateTime.now().minusDays(10));
        s.setUpdatedAt(OffsetDateTime.now());
        return s;
    }

    // ========== 健康评分快照 ==========

    /**
     * 创建一个正常的健康评分快照。
     */
    public static SupplierHealthSnapshot createHealthSnapshot(Long supplierId) {
        SupplierHealthSnapshot snapshot = new SupplierHealthSnapshot();
        snapshot.setId(1L);
        snapshot.setSupplierId(supplierId);
        snapshot.setPlanId(1L);
        snapshot.setHealthScore(new BigDecimal("85.5"));
        snapshot.setHealthLevel("low_risk");
        snapshot.setDimensionScores(Map.of(
                "legal", new BigDecimal("90.0"),
                "finance", new BigDecimal("80.0"),
                "credit", new BigDecimal("88.0"),
                "tax", new BigDecimal("85.0"),
                "operation", new BigDecimal("84.0")
        ));
        snapshot.setSnapshotDate(LocalDate.now());
        snapshot.setCreatedAt(OffsetDateTime.now());
        return snapshot;
    }

    /**
     * 创建一个高风险健康评分快照（红线指标触发，得分为 0）。
     */
    public static SupplierHealthSnapshot createHighRiskSnapshot(Long supplierId) {
        SupplierHealthSnapshot snapshot = new SupplierHealthSnapshot();
        snapshot.setId(2L);
        snapshot.setSupplierId(supplierId);
        snapshot.setPlanId(1L);
        snapshot.setHealthScore(BigDecimal.ZERO);
        snapshot.setHealthLevel("high_risk");
        snapshot.setDimensionScores(Map.of(
                "legal", BigDecimal.ZERO,
                "finance", new BigDecimal("60.0"),
                "credit", new BigDecimal("50.0"),
                "tax", new BigDecimal("40.0"),
                "operation", new BigDecimal("30.0")
        ));
        snapshot.setSnapshotDate(LocalDate.now());
        snapshot.setCreatedAt(OffsetDateTime.now());
        return snapshot;
    }

    // ========== 风险事项 ==========

    /**
     * 创建一个待处理（open）状态的风险事项。
     */
    public static RiskEvent createOpenRiskEvent(Long supplierId) {
        RiskEvent event = new RiskEvent();
        event.setId(101L);
        event.setSupplierId(supplierId);
        event.setIndicatorId(1L);
        event.setRiskDimension("legal");
        event.setDescription("被列为失信被执行人");
        event.setSourceUrl("https://example.com/case/12345");
        event.setStatus("open");
        event.setAssigneeId(null);
        event.setCloseNote(null);
        event.setClosedAt(null);
        event.setIsNotified(false);
        event.setTriggeredAt(OffsetDateTime.now().minusHours(2));
        event.setCreatedAt(OffsetDateTime.now().minusHours(2));
        return event;
    }

    /**
     * 创建一个处理中（processing）状态的风险事项。
     */
    public static RiskEvent createProcessingRiskEvent(Long supplierId) {
        RiskEvent event = new RiskEvent();
        event.setId(102L);
        event.setSupplierId(supplierId);
        event.setIndicatorId(2L);
        event.setRiskDimension("finance");
        event.setDescription("年度审计报告出具保留意见");
        event.setSourceUrl(null);
        event.setStatus("processing");
        event.setAssigneeId(10L);
        event.setCloseNote(null);
        event.setClosedAt(null);
        event.setIsNotified(true);
        event.setTriggeredAt(OffsetDateTime.now().minusDays(1));
        event.setCreatedAt(OffsetDateTime.now().minusDays(1));
        return event;
    }

    /**
     * 创建一个已关闭（closed）状态的风险事项。
     */
    public static RiskEvent createClosedRiskEvent(Long supplierId) {
        RiskEvent event = new RiskEvent();
        event.setId(103L);
        event.setSupplierId(supplierId);
        event.setIndicatorId(3L);
        event.setRiskDimension("tax");
        event.setDescription("税务行政处罚");
        event.setSourceUrl("https://example.com/tax/penalty");
        event.setStatus("closed");
        event.setAssigneeId(10L);
        event.setCloseNote("已缴纳罚款并整改完成");
        event.setClosedAt(OffsetDateTime.now().minusHours(6));
        event.setIsNotified(true);
        event.setTriggeredAt(OffsetDateTime.now().minusDays(7));
        event.setCreatedAt(OffsetDateTime.now().minusDays(7));
        return event;
    }

    /**
     * 创建指定数量的风险事项列表。
     */
    public static List<RiskEvent> createRiskEventList(Long supplierId, int count) {
        return java.util.stream.IntStream.rangeClosed(1, count)
                .mapToObj(i -> {
                    RiskEvent e = new RiskEvent();
                    e.setId((long) (100 + i));
                    e.setSupplierId(supplierId);
                    e.setIndicatorId((long) i);
                    e.setRiskDimension(i % 2 == 0 ? "finance" : "legal");
                    e.setDescription("风险事项 #" + i);
                    e.setSourceUrl(null);
                    e.setStatus("open");
                    e.setTriggeredAt(OffsetDateTime.now().minusHours(i));
                    e.setCreatedAt(OffsetDateTime.now().minusHours(i));
                    return e;
                })
                .toList();
    }
}
