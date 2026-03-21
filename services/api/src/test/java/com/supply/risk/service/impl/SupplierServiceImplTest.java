package com.supply.risk.service.impl;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.supply.risk.common.exception.ApiException;
import com.supply.risk.mapper.RiskEventMapper;
import com.supply.risk.mapper.SupplierHealthSnapshotMapper;
import com.supply.risk.mapper.SupplierMapper;
import com.supply.risk.model.dto.SupplierListQuery;
import com.supply.risk.model.dto.SupplierListResponse;
import com.supply.risk.model.dto.SupplierProfileResponse;
import com.supply.risk.model.dto.SupplierTabResponse;
import com.supply.risk.model.entity.RiskEvent;
import com.supply.risk.model.entity.Supplier;
import com.supply.risk.model.entity.SupplierHealthSnapshot;
import com.supply.risk.testutil.TestDataFactory;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.data.redis.core.ValueOperations;

import java.math.BigDecimal;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

/**
 * SupplierServiceImpl 单元测试。
 *
 * <p>Mock 所有依赖（Mapper + Redis），验证业务逻辑、参数校验、异常场景。
 * 对齐 TECH_SPEC 5.2~5.5 节接口定义和 CLAUDE.md 7.2 节测试规范。
 */
@ExtendWith(MockitoExtension.class)
@DisplayName("SupplierServiceImpl 单元测试")
class SupplierServiceImplTest {

    @Mock
    private SupplierMapper supplierMapper;

    @Mock
    private SupplierHealthSnapshotMapper snapshotMapper;

    @Mock
    private RiskEventMapper riskEventMapper;

    @Mock
    private RedisTemplate<String, Object> redisTemplate;

    @Mock
    private ValueOperations<String, Object> valueOperations;

    @InjectMocks
    private SupplierServiceImpl supplierService;

    private final ObjectMapper objectMapper = new ObjectMapper();

    /**
     * 通过反射注入 ObjectMapper（InjectMocks 不会自动注入非 Mock 对象）。
     */
    @org.junit.jupiter.api.BeforeEach
    void setUp() throws Exception {
        var field = SupplierServiceImpl.class.getDeclaredField("objectMapper");
        field.setAccessible(true);
        field.set(supplierService, objectMapper);
    }

    // ============================================================
    // listSuppliers — 供应商列表查询
    // ============================================================
    @Nested
    @DisplayName("listSuppliers - 供应商列表查询")
    class ListSuppliers {

        @Test
        @DisplayName("正常查询：返回分页数据，含 next_cursor")
        void listSuppliers_withDefaultParams_shouldReturnPaginatedResult() {
            // Arrange — 默认排序 health_score asc, page=1, pageSize=20
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", null, 1, 20
            );
            List<Supplier> mockSuppliers = List.of(
                    TestDataFactory.createHighRiskSupplier(),
                    TestDataFactory.createLowRiskSupplier()
            );
            // 返回 2 条但 pageSize=20，不生成 next_cursor
            given(supplierMapper.countSupplierList(any())).willReturn(2L);
            given(supplierMapper.selectSupplierList(any())).willReturn(mockSuppliers);

            // Act
            SupplierListResponse response = supplierService.listSuppliers(query);

            // Assert
            assertThat(response.total()).isEqualTo(2L);
            assertThat(response.page()).isEqualTo(1);
            assertThat(response.pageSize()).isEqualTo(20);
            assertThat(response.nextCursor()).isNull(); // 不满一页，无 next_cursor
            assertThat(response.items()).hasSize(2);
            assertThat(response.items().get(0).name()).isEqualTo("测试供应商B");
        }

        @Test
        @DisplayName("满页查询：返回 next_cursor")
        void listSuppliers_whenFullPage_shouldReturnNextCursor() {
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", null, 1, 2
            );
            List<Supplier> mockSuppliers = List.of(
                    TestDataFactory.createHighRiskSupplier(),
                    TestDataFactory.createLowRiskSupplier()
            );
            given(supplierMapper.countSupplierList(any())).willReturn(10L);
            given(supplierMapper.selectSupplierList(any())).willReturn(mockSuppliers);

            SupplierListResponse response = supplierService.listSuppliers(query);

            assertThat(response.nextCursor()).isNotNull();
            assertThat(response.nextCursor()).isNotBlank();
        }

        @Test
        @DisplayName("空结果：返回空列表，无 next_cursor")
        void listSuppliers_whenEmpty_shouldReturnEmptyList() {
            SupplierListQuery query = new SupplierListQuery(
                    "不存在的供应商", null, null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", null, 1, 20
            );
            given(supplierMapper.countSupplierList(any())).willReturn(0L);
            given(supplierMapper.selectSupplierList(any())).willReturn(Collections.emptyList());

            SupplierListResponse response = supplierService.listSuppliers(query);

            assertThat(response.total()).isZero();
            assertThat(response.items()).isEmpty();
            assertThat(response.nextCursor()).isNull();
        }

        @Test
        @DisplayName("非法 sort_by：抛出 ApiException(400003)")
        void listSuppliers_withInvalidSortBy_shouldThrowSortFieldInvalid() {
            // Arrange — sort_by 不在白名单 (health_score/name/created_at)
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, null, null,
                    "DROP TABLE supplier", "asc", null, 1, 20
            );

            // Act & Assert — 验证 SQL 注入防护
            assertThatThrownBy(() -> supplierService.listSuppliers(query))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(400003);
        }

        @Test
        @DisplayName("非法 health_level：抛出 ApiException(400002)")
        void listSuppliers_withInvalidHealthLevel_shouldThrowHealthLevelInvalid() {
            SupplierListQuery query = new SupplierListQuery(
                    null, List.of("invalid_level"), null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", null, 1, 20
            );

            assertThatThrownBy(() -> supplierService.listSuppliers(query))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(400002);
        }

        @Test
        @DisplayName("health_level 包含合法枚举值应正常通过")
        void listSuppliers_withValidHealthLevels_shouldPass() {
            SupplierListQuery query = new SupplierListQuery(
                    null, List.of("high_risk", "attention", "low_risk"), null, null,
                    null, null, null, null, null, null, null,
                    "health_score", "asc", null, 1, 20
            );
            given(supplierMapper.countSupplierList(any())).willReturn(0L);
            given(supplierMapper.selectSupplierList(any())).willReturn(Collections.emptyList());

            SupplierListResponse response = supplierService.listSuppliers(query);

            assertThat(response).isNotNull();
        }

        @Test
        @DisplayName("OFFSET 分页页码超过 20：抛出 ApiException(400004)")
        void listSuppliers_whenPageExceedsLimit_shouldThrowPageOffsetExceed() {
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", null, 21, 20
            );

            assertThatThrownBy(() -> supplierService.listSuppliers(query))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(400004);
        }

        @Test
        @DisplayName("有游标时页码超过 20 不报错（游标分页无 OFFSET 限制）")
        void listSuppliers_withCursorAndHighPage_shouldNotThrow() {
            // 编码一个合法的游标
            String cursor = com.supply.risk.common.util.CursorUtil.encode(
                    new BigDecimal("50.0"), 500L
            );
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", cursor, 21, 20
            );
            given(supplierMapper.countSupplierList(any())).willReturn(0L);
            given(supplierMapper.selectSupplierList(any())).willReturn(Collections.emptyList());

            // 不应抛异常
            SupplierListResponse response = supplierService.listSuppliers(query);
            assertThat(response).isNotNull();
        }

        @Test
        @DisplayName("supplyItems JSONB 筛选应正确序列化")
        void listSuppliers_withSupplyItems_shouldSerializeToJson() {
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, List.of("钢材", "铝材"), null,
                    "health_score", "asc", null, 1, 20
            );
            given(supplierMapper.countSupplierList(any())).willReturn(0L);
            given(supplierMapper.selectSupplierList(any())).willReturn(Collections.emptyList());

            supplierService.listSuppliers(query);

            // 验证 mapper 被调用（参数中包含 supplyItemsJson）
            verify(supplierMapper).selectSupplierList(any());
        }

        @Test
        @DisplayName("健康分缓存为 null 时 next_cursor 使用 BigDecimal.ZERO")
        void listSuppliers_whenHealthScoreCacheNull_shouldUsZeroForCursor() {
            Supplier unscoredSupplier = TestDataFactory.createUnscoredSupplier();
            SupplierListQuery query = new SupplierListQuery(
                    null, null, null, null, null, null, null,
                    null, null, null, null,
                    "health_score", "asc", null, 1, 1  // pageSize=1, 刚好满页
            );
            given(supplierMapper.countSupplierList(any())).willReturn(5L);
            given(supplierMapper.selectSupplierList(any())).willReturn(List.of(unscoredSupplier));

            SupplierListResponse response = supplierService.listSuppliers(query);

            // 应生成游标（使用 ZERO 替代 null）
            assertThat(response.nextCursor()).isNotNull();
        }
    }

    // ============================================================
    // getProfile — 供应商画像
    // ============================================================
    @Nested
    @DisplayName("getProfile - 供应商画像主接口")
    class GetProfile {

        @Test
        @DisplayName("正常查询：返回完整画像数据")
        void getProfile_withExistingSupplier_shouldReturnFullProfile() {
            Long supplierId = 1001L;
            Supplier supplier = TestDataFactory.createLowRiskSupplier();
            SupplierHealthSnapshot snapshot = TestDataFactory.createHealthSnapshot(supplierId);
            List<RiskEvent> events = List.of(
                    TestDataFactory.createOpenRiskEvent(supplierId),
                    TestDataFactory.createProcessingRiskEvent(supplierId)
            );

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(snapshotMapper.selectLatestBySupplier(supplierId)).willReturn(snapshot);
            given(riskEventMapper.selectRecentBySupplier(eq(supplierId), eq(5))).willReturn(events);
            given(riskEventMapper.countBySupplier(supplierId)).willReturn(10);

            SupplierProfileResponse response = supplierService.getProfile(supplierId);

            // 基础信息
            assertThat(response.basic().id()).isEqualTo(1001L);
            assertThat(response.basic().name()).isEqualTo("测试供应商A");
            assertThat(response.basic().region()).isEqualTo("广东 深圳");
            assertThat(response.basic().isChinaTop500()).isTrue();

            // 健康评分卡
            assertThat(response.health().score()).isEqualByComparingTo(new BigDecimal("85.5"));
            assertThat(response.health().level()).isEqualTo("low_risk");
            assertThat(response.health().reportStatus()).isEqualTo("ready");
            assertThat(response.health().dimensionScores()).containsKey("legal");

            // 风险事项
            assertThat(response.riskEvents()).hasSize(2);
            assertThat(response.riskEventsTotal()).isEqualTo(10);
            assertThat(response.riskEvents().get(0).riskDimension()).isEqualTo("legal");
            assertThat(response.riskEvents().get(0).status()).isEqualTo("open");
        }

        @Test
        @DisplayName("供应商不存在：抛出 ApiException(404001)")
        void getProfile_whenSupplierNotFound_shouldThrowNotFound() {
            given(supplierMapper.selectProfileById(9999L)).willReturn(null);

            assertThatThrownBy(() -> supplierService.getProfile(9999L))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(404001);
        }

        @Test
        @DisplayName("无健康评分快照：reportStatus 为 not_generated")
        void getProfile_whenNoSnapshot_shouldReturnNotGenerated() {
            Long supplierId = 1003L;
            Supplier supplier = TestDataFactory.createUnscoredSupplier();

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(snapshotMapper.selectLatestBySupplier(supplierId)).willReturn(null);
            given(riskEventMapper.selectRecentBySupplier(eq(supplierId), eq(5)))
                    .willReturn(Collections.emptyList());
            given(riskEventMapper.countBySupplier(supplierId)).willReturn(0);

            SupplierProfileResponse response = supplierService.getProfile(supplierId);

            assertThat(response.health().score()).isNull();
            assertThat(response.health().level()).isNull();
            assertThat(response.health().reportStatus()).isEqualTo("not_generated");
        }

        @Test
        @DisplayName("无风险事项：返回空列表，total 为 0")
        void getProfile_whenNoRiskEvents_shouldReturnEmptyList() {
            Long supplierId = 1001L;
            Supplier supplier = TestDataFactory.createLowRiskSupplier();
            SupplierHealthSnapshot snapshot = TestDataFactory.createHealthSnapshot(supplierId);

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(snapshotMapper.selectLatestBySupplier(supplierId)).willReturn(snapshot);
            given(riskEventMapper.selectRecentBySupplier(eq(supplierId), eq(5)))
                    .willReturn(Collections.emptyList());
            given(riskEventMapper.countBySupplier(supplierId)).willReturn(0);

            SupplierProfileResponse response = supplierService.getProfile(supplierId);

            assertThat(response.riskEvents()).isEmpty();
            assertThat(response.riskEventsTotal()).isZero();
        }

        @Test
        @DisplayName("省份有值但城市为 null：region 仅返回省份")
        void getProfile_whenCityNull_shouldReturnProvinceOnly() {
            Long supplierId = 1002L;
            Supplier supplier = TestDataFactory.createHighRiskSupplier(); // city = null

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(snapshotMapper.selectLatestBySupplier(supplierId)).willReturn(null);
            given(riskEventMapper.selectRecentBySupplier(eq(supplierId), anyInt()))
                    .willReturn(Collections.emptyList());
            given(riskEventMapper.countBySupplier(supplierId)).willReturn(0);

            SupplierProfileResponse response = supplierService.getProfile(supplierId);

            assertThat(response.basic().region()).isEqualTo("北京");
        }
    }

    // ============================================================
    // getTabData — Tab 懒加载
    // ============================================================
    @Nested
    @DisplayName("getTabData - Tab 懒加载")
    class GetTabData {

        @Test
        @DisplayName("缓存命中：直接返回缓存内容")
        void getTabData_whenCacheHit_shouldReturnCachedData() {
            Long supplierId = 1001L;
            String tabName = "basic-info";
            Supplier supplier = TestDataFactory.createLowRiskSupplier();

            Map<String, Object> cachedValue = Map.of(
                    "dataSource", "erp",
                    "content", Map.of("legal_rep", "张三")
            );

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(redisTemplate.opsForValue()).willReturn(valueOperations);
            given(valueOperations.get("supplier:tab:" + supplierId + ":" + tabName))
                    .willReturn(cachedValue);

            SupplierTabResponse response = supplierService.getTabData(supplierId, tabName);

            assertThat(response.supplierId()).isEqualTo(supplierId);
            assertThat(response.tab()).isEqualTo("basic-info");
            assertThat(response.dataSource()).isEqualTo("erp");
            assertThat(response.isStale()).isFalse();
        }

        @Test
        @DisplayName("缓存未命中：从 ext_data 提取并写入缓存")
        void getTabData_whenCacheMiss_shouldFetchAndCache() {
            Long supplierId = 1001L;
            String tabName = "basic-info";
            Supplier supplier = TestDataFactory.createLowRiskSupplier();

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(redisTemplate.opsForValue()).willReturn(valueOperations);
            given(valueOperations.get(anyString())).willReturn(null);

            SupplierTabResponse response = supplierService.getTabData(supplierId, tabName);

            assertThat(response.tab()).isEqualTo("basic-info");
            assertThat(response.dataSource()).isEqualTo("erp");
            // 验证缓存写入被调用
            verify(valueOperations).set(anyString(), any(), anyLong(), any());
        }

        @Test
        @DisplayName("不支持的 Tab 名称：抛出 ApiException(400001)")
        void getTabData_withInvalidTabName_shouldThrowParamInvalid() {
            assertThatThrownBy(() -> supplierService.getTabData(1001L, "invalid-tab"))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(400001);
        }

        @Test
        @DisplayName("供应商不存在：抛出 ApiException(404001)")
        void getTabData_whenSupplierNotFound_shouldThrowNotFound() {
            given(supplierMapper.selectProfileById(9999L)).willReturn(null);

            assertThatThrownBy(() -> supplierService.getTabData(9999L, "basic-info"))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(404001);
        }

        @Test
        @DisplayName("ext_data 为 null：返回空 Map 内容")
        void getTabData_whenExtDataNull_shouldReturnEmptyContent() {
            Long supplierId = 1002L;
            Supplier supplier = TestDataFactory.createHighRiskSupplier(); // extData = null

            given(supplierMapper.selectProfileById(supplierId)).willReturn(supplier);
            given(redisTemplate.opsForValue()).willReturn(valueOperations);
            given(valueOperations.get(anyString())).willReturn(null);

            SupplierTabResponse response = supplierService.getTabData(supplierId, "judicial");

            assertThat(response.content()).isEqualTo(Map.of());
            assertThat(response.dataSource()).isEqualTo("tianyancha");
        }

        @Test
        @DisplayName("各 Tab 对应正确的 dataSource")
        void getTabData_shouldResolveCorrectDataSource() {
            Supplier supplier = TestDataFactory.createLowRiskSupplier();
            given(supplierMapper.selectProfileById(anyLong())).willReturn(supplier);
            given(redisTemplate.opsForValue()).willReturn(valueOperations);
            given(valueOperations.get(anyString())).willReturn(null);

            // basic-info → erp
            assertThat(supplierService.getTabData(1L, "basic-info").dataSource()).isEqualTo("erp");
            // business-info → qcc
            assertThat(supplierService.getTabData(1L, "business-info").dataSource()).isEqualTo("qcc");
            // judicial → tianyancha
            assertThat(supplierService.getTabData(1L, "judicial").dataSource()).isEqualTo("tianyancha");
            // credit → pboc
            assertThat(supplierService.getTabData(1L, "credit").dataSource()).isEqualTo("pboc");
            // tax → tax_bureau
            assertThat(supplierService.getTabData(1L, "tax").dataSource()).isEqualTo("tax_bureau");
        }
    }

    // ============================================================
    // toggleFollow — 切换关注状态
    // ============================================================
    @Nested
    @DisplayName("toggleFollow - 切换关注状态")
    class ToggleFollow {

        @Test
        @DisplayName("正常关注：更新 isFollowed 为 true")
        void toggleFollow_whenFollow_shouldUpdateToTrue() {
            Supplier supplier = TestDataFactory.createLowRiskSupplier();
            supplier.setIsFollowed(false);
            given(supplierMapper.selectById(1001L)).willReturn(supplier);

            supplierService.toggleFollow(1001L, true);

            assertThat(supplier.getIsFollowed()).isTrue();
            verify(supplierMapper).updateById(supplier);
        }

        @Test
        @DisplayName("取消关注：更新 isFollowed 为 false")
        void toggleFollow_whenUnfollow_shouldUpdateToFalse() {
            Supplier supplier = TestDataFactory.createLowRiskSupplier();
            supplier.setIsFollowed(true);
            given(supplierMapper.selectById(1001L)).willReturn(supplier);

            supplierService.toggleFollow(1001L, false);

            assertThat(supplier.getIsFollowed()).isFalse();
            verify(supplierMapper).updateById(supplier);
        }

        @Test
        @DisplayName("供应商不存在：抛出 ApiException(404001)")
        void toggleFollow_whenSupplierNotFound_shouldThrowNotFound() {
            given(supplierMapper.selectById(9999L)).willReturn(null);

            assertThatThrownBy(() -> supplierService.toggleFollow(9999L, true))
                    .isInstanceOf(ApiException.class)
                    .extracting("code")
                    .isEqualTo(404001);

            verify(supplierMapper, never()).updateById(any());
        }
    }
}
