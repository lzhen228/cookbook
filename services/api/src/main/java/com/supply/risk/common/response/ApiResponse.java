package com.supply.risk.common.response;

import com.supply.risk.common.util.TraceUtil;

/**
 * 统一响应体，所有 REST 接口返回此结构。
 *
 * @param code    业务状态码，0 表示成功，非 0 为错误码
 * @param msg     状态描述
 * @param data    响应数据
 * @param traceId 链路追踪 ID
 * @param <T>     数据类型
 */
public record ApiResponse<T>(int code, String msg, T data, String traceId) {

    /**
     * 成功响应（带数据）。
     *
     * @param data 响应数据
     * @param <T>  数据类型
     * @return ApiResponse
     */
    public static <T> ApiResponse<T> ok(T data) {
        return new ApiResponse<>(ResultCode.SUCCESS.code(), ResultCode.SUCCESS.msg(), data, TraceUtil.getTraceId());
    }

    /**
     * 成功响应（无数据）。
     *
     * @return ApiResponse
     */
    public static <Void> ApiResponse<Void> ok() {
        return new ApiResponse<>(ResultCode.SUCCESS.code(), ResultCode.SUCCESS.msg(), null, TraceUtil.getTraceId());
    }

    /**
     * 失败响应。
     *
     * @param resultCode 错误码枚举
     * @return ApiResponse
     */
    public static <T> ApiResponse<T> fail(ResultCode resultCode) {
        return new ApiResponse<>(resultCode.code(), resultCode.msg(), null, TraceUtil.getTraceId());
    }

    /**
     * 失败响应（自定义消息）。
     *
     * @param resultCode 错误码枚举
     * @param message    自定义错误消息
     * @return ApiResponse
     */
    public static <T> ApiResponse<T> fail(ResultCode resultCode, String message) {
        return new ApiResponse<>(resultCode.code(), message, null, TraceUtil.getTraceId());
    }

    /**
     * 失败响应（自定义错误码）。
     *
     * @param code    错误码
     * @param message 错误消息
     * @return ApiResponse
     */
    public static <T> ApiResponse<T> fail(int code, String message) {
        return new ApiResponse<>(code, message, null, TraceUtil.getTraceId());
    }
}
