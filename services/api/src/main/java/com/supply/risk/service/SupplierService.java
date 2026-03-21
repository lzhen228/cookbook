package com.supply.risk.service;

import com.supply.risk.model.dto.SupplierListQuery;
import com.supply.risk.model.dto.SupplierListResponse;
import com.supply.risk.model.dto.SupplierProfileResponse;
import com.supply.risk.model.dto.SupplierTabResponse;

/**
 * 供应商服务接口，定义供应商列表查询、画像详情、Tab 懒加载等业务方法。
 */
public interface SupplierService {

    /**
     * 分页查询供应商列表，支持游标分页和多条件筛选。
     *
     * @param query 查询参数
     * @return 分页供应商列表
     */
    SupplierListResponse listSuppliers(SupplierListQuery query);

    /**
     * 查询供应商画像主接口（首屏核心数据）。
     *
     * @param supplierId 供应商 ID
     * @return 画像响应（基础信息 + 健康评分卡 + 前 5 条风险事项）
     */
    SupplierProfileResponse getProfile(Long supplierId);

    /**
     * 查询供应商画像 Tab 数据（懒加载）。
     *
     * @param supplierId 供应商 ID
     * @param tabName    Tab 标识（basic-info/business-info/judicial/credit/tax）
     * @return Tab 数据响应
     */
    SupplierTabResponse getTabData(Long supplierId, String tabName);

    /**
     * 切换供应商关注状态。
     *
     * @param supplierId 供应商 ID
     * @param followed   是否关注
     */
    void toggleFollow(Long supplierId, boolean followed);
}
