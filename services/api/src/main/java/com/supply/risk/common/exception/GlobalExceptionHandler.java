package com.supply.risk.common.exception;

import com.supply.risk.common.response.ApiResponse;
import com.supply.risk.common.response.ResultCode;
import jakarta.validation.ConstraintViolation;
import jakarta.validation.ConstraintViolationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.http.HttpStatus;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.AuthenticationException;
import org.springframework.validation.FieldError;
import org.springframework.web.HttpRequestMethodNotSupportedException;
import org.springframework.web.bind.MethodArgumentNotValidException;
import org.springframework.web.bind.MissingServletRequestParameterException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestControllerAdvice;
import org.springframework.web.method.annotation.MethodArgumentTypeMismatchException;
import org.springframework.web.servlet.resource.NoResourceFoundException;

import java.util.stream.Collectors;

/**
 * 全局异常处理器，将各类异常统一转换为 ApiResponse 响应。
 */
@RestControllerAdvice
public class GlobalExceptionHandler {

    private static final Logger log = LoggerFactory.getLogger(GlobalExceptionHandler.class);

    /**
     * 处理业务异常。
     *
     * @param e 业务异常
     * @return 统一响应
     */
    @ExceptionHandler(ApiException.class)
    @ResponseStatus(HttpStatus.OK)
    public ApiResponse<Void> handleApiException(ApiException e) {
        log.warn("业务异常: code={}, msg={}", e.getCode(), e.getMessage());
        return ApiResponse.fail(e.getCode(), e.getMessage());
    }

    /**
     * 处理 @Valid 参数校验失败。
     *
     * @param e 参数校验异常
     * @return 统一响应
     */
    @ExceptionHandler(MethodArgumentNotValidException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleValidationException(MethodArgumentNotValidException e) {
        String message = e.getBindingResult().getFieldErrors().stream()
                .map(FieldError::getDefaultMessage)
                .collect(Collectors.joining("; "));
        log.warn("参数校验失败: {}", message);
        return ApiResponse.fail(ResultCode.PARAM_INVALID, message);
    }

    /**
     * 处理 @Validated 约束违反。
     *
     * @param e 约束违反异常
     * @return 统一响应
     */
    @ExceptionHandler(ConstraintViolationException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleConstraintViolation(ConstraintViolationException e) {
        String message = e.getConstraintViolations().stream()
                .map(ConstraintViolation::getMessage)
                .collect(Collectors.joining("; "));
        log.warn("约束违反: {}", message);
        return ApiResponse.fail(ResultCode.PARAM_INVALID, message);
    }

    /**
     * 处理请求参数类型不匹配。
     *
     * @param e 类型不匹配异常
     * @return 统一响应
     */
    @ExceptionHandler(MethodArgumentTypeMismatchException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleTypeMismatch(MethodArgumentTypeMismatchException e) {
        String message = "参数 '" + e.getName() + "' 类型不正确";
        log.warn("参数类型不匹配: {}", message);
        return ApiResponse.fail(ResultCode.PARAM_INVALID, message);
    }

    /**
     * 处理缺少必填参数。
     *
     * @param e 缺少参数异常
     * @return 统一响应
     */
    @ExceptionHandler(MissingServletRequestParameterException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleMissingParam(MissingServletRequestParameterException e) {
        log.warn("缺少必填参数: {}", e.getParameterName());
        return ApiResponse.fail(ResultCode.PARAM_INVALID, "缺少必填参数: " + e.getParameterName());
    }

    /**
     * 处理请求体解析失败。
     *
     * @param e 解析异常
     * @return 统一响应
     */
    @ExceptionHandler(HttpMessageNotReadableException.class)
    @ResponseStatus(HttpStatus.BAD_REQUEST)
    public ApiResponse<Void> handleMessageNotReadable(HttpMessageNotReadableException e) {
        log.warn("请求体解析失败: {}", e.getMessage());
        return ApiResponse.fail(ResultCode.PARAM_INVALID, "请求体格式错误");
    }

    /**
     * 处理不支持的 HTTP 方法。
     *
     * @param e 方法不支持异常
     * @return 统一响应
     */
    @ExceptionHandler(HttpRequestMethodNotSupportedException.class)
    @ResponseStatus(HttpStatus.METHOD_NOT_ALLOWED)
    public ApiResponse<Void> handleMethodNotSupported(HttpRequestMethodNotSupportedException e) {
        return ApiResponse.fail(400001, "不支持的请求方法: " + e.getMethod());
    }

    /**
     * 处理资源未找到。
     *
     * @param e 资源未找到异常
     * @return 统一响应
     */
    @ExceptionHandler(NoResourceFoundException.class)
    @ResponseStatus(HttpStatus.NOT_FOUND)
    public ApiResponse<Void> handleNoResourceFound(NoResourceFoundException e) {
        return ApiResponse.fail(ResultCode.NOT_FOUND);
    }

    /**
     * 处理认证失败。
     *
     * @param e 认证异常
     * @return 统一响应
     */
    @ExceptionHandler(AuthenticationException.class)
    @ResponseStatus(HttpStatus.UNAUTHORIZED)
    public ApiResponse<Void> handleAuthentication(AuthenticationException e) {
        return ApiResponse.fail(ResultCode.UNAUTHORIZED);
    }

    /**
     * 处理授权失败。
     *
     * @param e 授权异常
     * @return 统一响应
     */
    @ExceptionHandler(AccessDeniedException.class)
    @ResponseStatus(HttpStatus.FORBIDDEN)
    public ApiResponse<Void> handleAccessDenied(AccessDeniedException e) {
        return ApiResponse.fail(ResultCode.FORBIDDEN);
    }

    /**
     * 兜底处理未知异常。
     *
     * @param e 未知异常
     * @return 统一响应
     */
    @ExceptionHandler(Exception.class)
    @ResponseStatus(HttpStatus.INTERNAL_SERVER_ERROR)
    public ApiResponse<Void> handleUnknownException(Exception e) {
        log.error("未捕获异常", e);
        return ApiResponse.fail(ResultCode.INTERNAL_ERROR);
    }
}
