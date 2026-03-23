package com.supply.risk.controller;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.supply.risk.common.exception.ApiException;
import com.supply.risk.common.exception.GlobalExceptionHandler;
import com.supply.risk.common.response.ResultCode;
import com.supply.risk.model.dto.SupplierListItemDto;
import com.supply.risk.model.dto.SupplierListResponse;
import com.supply.risk.model.dto.SupplierProfileResponse;
import com.supply.risk.model.dto.SupplierProfileResponse.BasicInfo;
import com.supply.risk.model.dto.SupplierProfileResponse.HealthInfo;
import com.supply.risk.model.dto.SupplierProfileResponse.RiskEventBrief;
import com.supply.risk.model.dto.SupplierTabResponse;
import com.supply.risk.service.SupplierService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.autoconfigure.web.servlet.WebMvcTest;
import org.springframework.boot.test.mock.mockito.MockBean;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;

import java.math.BigDecimal;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.Collections;
import java.util.List;
import java.util.Map;

import static org.hamcrest.Matchers.hasSize;
import static org.hamcrest.Matchers.is;
import static org.hamcrest.Matchers.notNullValue;
import static org.hamcrest.Matchers.nullValue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.BDDMockito.given;
import static org.mockito.BDDMockito.willDoNothing;
import static org.mockito.BDDMockito.willThrow;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/**
 * SupplierController MockMvc 接口测试。
 *
 * <p>验证 HTTP 状态码、响应结构、错误码、参数校验。
 * 对齐 TECH_SPEC 5.2~5.5 节接口规范和 CLAUDE.md 7.2 节接口测试规范。
 */
@WebMvcTest(controllers = SupplierController.class)
@Import(GlobalExceptionHandler.class)
@AutoConfigureMockMvc(addFilters = false) // 跳过 Security Filter（MVP 阶段）
@DisplayName("SupplierController 接口测试")
class SupplierControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @Autowired
    private ObjectMapper objectMapper;

    @MockBean
    private SupplierService supplierService;

    // ============================================================
    // GET /suppliers — 供应商列表
    // ============================================================
    @Nested
    @DisplayName("GET /suppliers - 供应商列表")
    class ListSuppliers {

        @Test
        @DisplayName("无参数默认查询：返回 200 + 统一响应体")
        void listSuppliers_withDefaults_shouldReturn200() throws Exception {
            SupplierListResponse response = new SupplierListResponse(
                    1L, 1, 20, null,
                    List.of(new SupplierListItemDto(
                            1001L, "测试供应商A", "low_risk",
                            new BigDecimal("85.5"), new BigDecimal("2.3"),
                            "广东 深圳", "cooperating", "listed", true,
                            OffsetDateTime.now()
                    ))
            );
            given(supplierService.listSuppliers(any())).willReturn(response);

            mockMvc.perform(get("/suppliers"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)))
                    .andExpect(jsonPath("$.msg", is("ok")))
                    .andExpect(jsonPath("$.data.total", is(1)))
                    .andExpect(jsonPath("$.data.page", is(1)))
                    .andExpect(jsonPath("$.data.page_size", is(20)))
                    .andExpect(jsonPath("$.data.next_cursor").value(nullValue()))
                    .andExpect(jsonPath("$.data.items", hasSize(1)))
                    .andExpect(jsonPath("$.data.items[0].name", is("测试供应商A")))
                    .andExpect(jsonPath("$.data.items[0].health_level", is("low_risk")))
                    .andExpect(jsonPath("$.data.items[0].health_score", is(85.5)))
                    .andExpect(jsonPath("$.data.items[0].is_followed", is(true)));
        }

        @Test
        @DisplayName("多条件筛选：health_level + cooperation_status")
        void listSuppliers_withFilters_shouldReturn200() throws Exception {
            SupplierListResponse response = new SupplierListResponse(
                    0L, 1, 20, null, Collections.emptyList()
            );
            given(supplierService.listSuppliers(any())).willReturn(response);

            mockMvc.perform(get("/suppliers")
                            .param("health_level", "high_risk", "attention")
                            .param("cooperation_status", "cooperating")
                            .param("sort_by", "health_score")
                            .param("sort_order", "asc"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)))
                    .andExpect(jsonPath("$.data.items", hasSize(0)));
        }

        @Test
        @DisplayName("page_size 超过 100：返回 400 参数校验失败")
        void listSuppliers_withPageSizeOver100_shouldReturn400() throws Exception {
            mockMvc.perform(get("/suppliers")
                            .param("page_size", "200"))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("page_size 为 0：返回 400")
        void listSuppliers_withPageSizeZero_shouldReturn400() throws Exception {
            mockMvc.perform(get("/suppliers")
                            .param("page_size", "0"))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("page 为负数：返回 400")
        void listSuppliers_withNegativePage_shouldReturn400() throws Exception {
            mockMvc.perform(get("/suppliers")
                            .param("page", "-1"))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("非法 sort_by 由 Service 层校验：返回业务错误码 400003")
        void listSuppliers_withInvalidSortBy_shouldReturnSortFieldInvalid() throws Exception {
            given(supplierService.listSuppliers(any()))
                    .willThrow(new ApiException(ResultCode.SORT_FIELD_INVALID));

            mockMvc.perform(get("/suppliers")
                            .param("sort_by", "DROP TABLE supplier"))
                    .andExpect(status().isOk()) // ApiException 返回 200 + 业务错误码
                    .andExpect(jsonPath("$.code", is(400003)));
        }

        @Test
        @DisplayName("游标分页：传入 cursor 参数")
        void listSuppliers_withCursor_shouldReturn200() throws Exception {
            SupplierListResponse response = new SupplierListResponse(
                    10L, 2, 20, "nextCursorValue", Collections.emptyList()
            );
            given(supplierService.listSuppliers(any())).willReturn(response);

            mockMvc.perform(get("/suppliers")
                            .param("cursor", "someCursorValue"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.data.next_cursor", is("nextCursorValue")));
        }
    }

    // ============================================================
    // GET /suppliers/{id}/profile — 供应商画像
    // ============================================================
    @Nested
    @DisplayName("GET /suppliers/{id}/profile - 供应商画像")
    class GetProfile {

        @Test
        @DisplayName("正常查询：返回完整画像")
        void getProfile_withValidId_shouldReturn200() throws Exception {
            SupplierProfileResponse response = new SupplierProfileResponse(
                    new BasicInfo(1001L, "测试供应商A", "91440300TEST00001",
                            "cooperating", "广东 深圳", "listed",
                            true, false, "原材料", "民营企业",
                            List.of("钢材"), true),
                    new HealthInfo(new BigDecimal("85.5"), "low_risk",
                            LocalDate.now(),
                            Map.of("legal", new BigDecimal("90.0")),
                            "ready", OffsetDateTime.now()),
                    List.of(new RiskEventBrief(101L, "legal", "被列为失信被执行人",
                            "open", OffsetDateTime.now(), "https://example.com")),
                    5
            );
            given(supplierService.getProfile(1001L)).willReturn(response);

            mockMvc.perform(get("/suppliers/1001/profile"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)))
                    .andExpect(jsonPath("$.data.basic.id", is(1001)))
                    .andExpect(jsonPath("$.data.basic.name", is("测试供应商A")))
                    .andExpect(jsonPath("$.data.basic.unified_code", is("91440300TEST00001")))
                    .andExpect(jsonPath("$.data.basic.is_china_top500", is(true)))
                    .andExpect(jsonPath("$.data.health.score", is(85.5)))
                    .andExpect(jsonPath("$.data.health.level", is("low_risk")))
                    .andExpect(jsonPath("$.data.health.report_status", is("ready")))
                    .andExpect(jsonPath("$.data.risk_events", hasSize(1)))
                    .andExpect(jsonPath("$.data.risk_events[0].status", is("open")))
                    .andExpect(jsonPath("$.data.risk_events_total", is(5)));
        }

        @Test
        @DisplayName("供应商不存在：返回 404001")
        void getProfile_whenNotFound_shouldReturnNotFoundCode() throws Exception {
            given(supplierService.getProfile(9999L))
                    .willThrow(new ApiException(ResultCode.NOT_FOUND, "供应商不存在: 9999"));

            mockMvc.perform(get("/suppliers/9999/profile"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(404001)));
        }

        @Test
        @DisplayName("ID 非数字：返回 400 类型不匹配")
        void getProfile_withNonNumericId_shouldReturn400() throws Exception {
            mockMvc.perform(get("/suppliers/abc/profile"))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code", is(400001)));
        }
    }

    // ============================================================
    // GET /suppliers/{id}/tabs/{tabName} — Tab 懒加载
    // ============================================================
    @Nested
    @DisplayName("GET /suppliers/{id}/tabs/{tabName} - Tab 懒加载")
    class GetTabData {

        @Test
        @DisplayName("正常查询 basic-info Tab")
        void getTabData_withValidTab_shouldReturn200() throws Exception {
            SupplierTabResponse response = new SupplierTabResponse(
                    1001L, "basic-info", "erp",
                    OffsetDateTime.now(), false,
                    Map.of("legal_rep", "张三")
            );
            given(supplierService.getTabData(1001L, "basic-info")).willReturn(response);

            mockMvc.perform(get("/suppliers/1001/tabs/basic-info"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)))
                    .andExpect(jsonPath("$.data.supplier_id", is(1001)))
                    .andExpect(jsonPath("$.data.tab", is("basic-info")))
                    .andExpect(jsonPath("$.data.data_source", is("erp")))
                    .andExpect(jsonPath("$.data.is_stale", is(false)))
                    .andExpect(jsonPath("$.data.content.legal_rep", is("张三")));
        }

        @Test
        @DisplayName("不支持的 Tab：返回 400001")
        void getTabData_withInvalidTab_shouldReturnParamInvalid() throws Exception {
            given(supplierService.getTabData(1001L, "invalid-tab"))
                    .willThrow(new ApiException(ResultCode.PARAM_INVALID, "不支持的 Tab: invalid-tab"));

            mockMvc.perform(get("/suppliers/1001/tabs/invalid-tab"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(400001)));
        }
    }

    // ============================================================
    // PATCH /suppliers/{id}/follow — 切换关注状态
    // ============================================================
    @Nested
    @DisplayName("PATCH /suppliers/{id}/follow - 切换关注状态")
    class ToggleFollow {

        @Test
        @DisplayName("正常关注：返回 200 + code=0")
        void toggleFollow_withValidBody_shouldReturn200() throws Exception {
            willDoNothing().given(supplierService).toggleFollow(eq(1001L), eq(true));

            mockMvc.perform(patch("/suppliers/1001/follow")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"is_followed\": true}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)));
        }

        @Test
        @DisplayName("取消关注：返回 200 + code=0")
        void toggleFollow_withUnfollow_shouldReturn200() throws Exception {
            willDoNothing().given(supplierService).toggleFollow(eq(1001L), eq(false));

            mockMvc.perform(patch("/suppliers/1001/follow")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"is_followed\": false}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)));
        }

        @Test
        @DisplayName("请求体缺少 is_followed：默认为 false")
        void toggleFollow_withoutIsFollowed_shouldDefaultToFalse() throws Exception {
            willDoNothing().given(supplierService).toggleFollow(eq(1001L), eq(false));

            mockMvc.perform(patch("/suppliers/1001/follow")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(0)));
        }

        @Test
        @DisplayName("空请求体：返回 400")
        void toggleFollow_withEmptyBody_shouldReturn400() throws Exception {
            mockMvc.perform(patch("/suppliers/1001/follow")
                            .contentType(MediaType.APPLICATION_JSON))
                    .andExpect(status().isBadRequest());
        }

        @Test
        @DisplayName("供应商不存在：返回 404001")
        void toggleFollow_whenNotFound_shouldReturnNotFoundCode() throws Exception {
            willThrow(new ApiException(ResultCode.NOT_FOUND, "供应商不存在: 9999"))
                    .given(supplierService).toggleFollow(eq(9999L), anyBoolean());

            mockMvc.perform(patch("/suppliers/9999/follow")
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"is_followed\": true}"))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.code", is(404001)));
        }
    }
}
