package com.supply.risk.common.util;

import org.slf4j.MDC;

import java.util.UUID;

/**
 * 链路追踪工具类，管理 traceId 的生成与获取。
 *
 * <p>traceId 存储在 SLF4J MDC 中，日志模板通过 %X{traceId} 输出。
 */
public final class TraceUtil {

    public static final String TRACE_ID_KEY = "traceId";

    private TraceUtil() {
    }

    /**
     * 生成并设置 traceId 到 MDC。
     *
     * @return 生成的 traceId
     */
    public static String generateTraceId() {
        String traceId = UUID.randomUUID().toString().replace("-", "").substring(0, 16);
        MDC.put(TRACE_ID_KEY, traceId);
        return traceId;
    }

    /**
     * 获取当前线程的 traceId。
     *
     * @return traceId，若不存在则返回 "unknown"
     */
    public static String getTraceId() {
        String traceId = MDC.get(TRACE_ID_KEY);
        return traceId != null ? traceId : "unknown";
    }

    /**
     * 清除当前线程的 traceId。
     */
    public static void clear() {
        MDC.remove(TRACE_ID_KEY);
    }
}
