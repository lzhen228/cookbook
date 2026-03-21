package com.supply.risk.controller;

import com.supply.risk.common.response.ApiResponse;
import com.supply.risk.model.dto.SupplierListQuery;
import com.supply.risk.model.dto.SupplierListResponse;
import com.supply.risk.model.dto.SupplierProfileResponse;
import com.supply.risk.model.dto.SupplierTabResponse;
import com.supply.risk.service.SupplierService;
import jakarta.validation.Valid;
import jakarta.validation.constraints.Max;
import jakarta.validation.constraints.Min;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Map;

/**
 * 供应商模块 REST 控制器。
 *
 * <p>职责：参数校验 + 调用 Service + 组装统一响应。不包含任何业务逻辑。
 */
@RestController
@RequestMapping("/suppliers")
@Validated
public class SupplierController {

    private final SupplierService supplierService;

    public SupplierController(SupplierService supplierService) {
        this.supplierService = supplierService;
    }

    /**
     * 供应商列表查询（游标分页 + 多条件筛选）。
     *
     * @param keyword            名称关键词
     * @param healthLevel        健康等级筛选（逗号分隔）
     * @param cooperationStatus  合作状态筛选（逗号分隔）
     * @param regionProvince     注册省份
     * @param listedStatus       上市状态
     * @param isChinaTop500      中国 500 强
     * @param isWorldTop500      世界 500 强
     * @param supplierType       供应商类型（逗号分隔）
     * @param nature             企业性质（逗号分隔）
     * @param supplyItems        供应物（逗号分隔）
     * @param isFollowed         是否已关注
     * @param sortBy             排序字段
     * @param sortOrder          排序方向
     * @param cursor             游标值
     * @param page               页码
     * @param pageSize           每页条数
     * @return 分页供应商列表
     */
    @GetMapping
    public ApiResponse<SupplierListResponse> listSuppliers(
            @RequestParam(required = false) String keyword,
            @RequestParam(name = "health_level", required = false) List<String> healthLevel,
            @RequestParam(name = "cooperation_status", required = false) List<String> cooperationStatus,
            @RequestParam(name = "region_province", required = false) String regionProvince,
            @RequestParam(name = "listed_status", required = false) String listedStatus,
            @RequestParam(name = "is_china_top500", required = false) Boolean isChinaTop500,
            @RequestParam(name = "is_world_top500", required = false) Boolean isWorldTop500,
            @RequestParam(name = "supplier_type", required = false) List<String> supplierType,
            @RequestParam(required = false) List<String> nature,
            @RequestParam(name = "supply_items", required = false) List<String> supplyItems,
            @RequestParam(name = "is_followed", required = false) Boolean isFollowed,
            @RequestParam(name = "sort_by", required = false) String sortBy,
            @RequestParam(name = "sort_order", required = false) String sortOrder,
            @RequestParam(required = false) String cursor,
            @RequestParam(required = false) @Min(1) Integer page,
            @RequestParam(name = "page_size", required = false) @Min(1) @Max(100) Integer pageSize) {

        SupplierListQuery query = new SupplierListQuery(
                keyword, healthLevel, cooperationStatus, regionProvince,
                listedStatus, isChinaTop500, isWorldTop500, supplierType,
                nature, supplyItems, isFollowed, sortBy, sortOrder,
                cursor, page, pageSize
        );

        SupplierListResponse response = supplierService.listSuppliers(query);
        return ApiResponse.ok(response);
    }

    /**
     * 供应商画像主接口（首屏核心数据：基础信息 + 健康评分卡 + 前 5 条风险事项）。
     *
     * @param supplierId 供应商 ID
     * @return 供应商画像响应
     */
    @GetMapping("/{supplierId}/profile")
    public ApiResponse<SupplierProfileResponse> getProfile(@PathVariable Long supplierId) {
        SupplierProfileResponse response = supplierService.getProfile(supplierId);
        return ApiResponse.ok(response);
    }

    /**
     * 供应商画像 Tab 懒加载接口。
     *
     * <p>支持的 Tab：basic-info / business-info / judicial / credit / tax
     *
     * @param supplierId 供应商 ID
     * @param tabName    Tab 标识
     * @return Tab 数据响应
     */
    @GetMapping("/{supplierId}/tabs/{tabName}")
    public ApiResponse<SupplierTabResponse> getTabData(
            @PathVariable Long supplierId,
            @PathVariable String tabName) {
        SupplierTabResponse response = supplierService.getTabData(supplierId, tabName);
        return ApiResponse.ok(response);
    }

    /**
     * 切换供应商关注状态。
     *
     * @param supplierId 供应商 ID
     * @param body       请求体，包含 is_followed 字段
     * @return 操作结果
     */
    @PatchMapping("/{supplierId}/follow")
    public ApiResponse<Void> toggleFollow(
            @PathVariable Long supplierId,
            @RequestBody @Valid Map<String, Boolean> body) {
        Boolean followed = body.get("is_followed");
        if (followed == null) {
            followed = false;
        }
        supplierService.toggleFollow(supplierId, followed);
        return ApiResponse.ok();
    }
}
