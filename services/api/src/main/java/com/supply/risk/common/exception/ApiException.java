package com.supply.risk.common.exception;

import com.supply.risk.common.response.ResultCode;

/**
 * 业务异常，携带统一错误码，由全局异常处理器捕获并转换为 ApiResponse。
 */
public class ApiException extends RuntimeException {

    private final int code;

    /**
     * 通过 ResultCode 枚举创建业务异常。
     *
     * @param resultCode 错误码枚举
     */
    public ApiException(ResultCode resultCode) {
        super(resultCode.msg());
        this.code = resultCode.code();
    }

    /**
     * 通过 ResultCode 枚举和自定义消息创建业务异常。
     *
     * @param resultCode 错误码枚举
     * @param message    自定义错误消息
     */
    public ApiException(ResultCode resultCode, String message) {
        super(message);
        this.code = resultCode.code();
    }

    /**
     * 通过自定义错误码和消息创建业务异常。
     *
     * @param code    错误码
     * @param message 错误消息
     */
    public ApiException(int code, String message) {
        super(message);
        this.code = code;
    }

    /**
     * 获取业务错误码。
     *
     * @return 错误码
     */
    public int getCode() {
        return code;
    }
}
