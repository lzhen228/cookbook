package com.supply.risk.common.response;

/**
 * 统一错误码枚举，对齐 TECH_SPEC 5.1 节定义。
 *
 * <p>编码规则：
 * <ul>
 *   <li>0 — 成功</li>
 *   <li>4xxxxx — 客户端错误</li>
 *   <li>5xxxxx — 服务端错误</li>
 * </ul>
 *
 * @param code 业务错误码
 * @param msg  错误描述
 */
public enum ResultCode {

    // 通用
    SUCCESS(0, "ok"),
    PARAM_INVALID(400001, "参数校验失败"),
    UNAUTHORIZED(401001, "Token 未携带或已过期"),
    FORBIDDEN(403001, "权限不足"),
    NOT_FOUND(404001, "资源不存在"),
    CONFLICT(409001, "资源冲突"),
    TOO_MANY_REQUESTS(429001, "请求频率超限"),
    INTERNAL_ERROR(500001, "服务内部错误"),
    UPSTREAM_UNAVAILABLE(503001, "上游依赖不可用"),

    // 供应商列表（5.2 节）
    PAGE_SIZE_EXCEED(400001, "page_size 超过 100"),
    HEALTH_LEVEL_INVALID(400002, "health_level 包含非法枚举值"),
    SORT_FIELD_INVALID(400003, "sort_by 包含非白名单字段"),
    PAGE_OFFSET_EXCEED(400004, "OFFSET 分页超过页码限制，请改用游标分页"),

    // 预警方案（5.10 节）
    WEIGHT_SUM_INVALID(400010, "指标权重总和不等于 100%"),
    THRESHOLD_INVALID(400011, "健康等级阈值区间不连续或重叠"),
    INDICATOR_NOT_FOUND(400012, "indicators 包含不存在或已停用的指标 ID"),
    PLAN_ACTIVE_READONLY(400013, "激活状态的方案不允许直接修改，请先停用"),

    // 风险事项（5.9 节）
    STATUS_TRANSITION_INVALID(400020, "状态流转不合法"),
    ASSIGNEE_REQUIRED(400021, "processing 状态缺少 assignee_id"),
    CLOSE_NOTE_REQUIRED(400022, "关闭/忽略缺少 close_note");

    private final int code;
    private final String msg;

    ResultCode(int code, String msg) {
        this.code = code;
        this.msg = msg;
    }

    /**
     * 获取业务错误码。
     *
     * @return 错误码
     */
    public int code() {
        return code;
    }

    /**
     * 获取错误描述。
     *
     * @return 错误描述
     */
    public String msg() {
        return msg;
    }
}
