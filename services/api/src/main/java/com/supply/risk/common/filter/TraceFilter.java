package com.supply.risk.common.filter;

import com.supply.risk.common.util.TraceUtil;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;

/**
 * 链路追踪 Filter，为每个请求生成 traceId 并写入 MDC 和响应头。
 */
public class TraceFilter extends OncePerRequestFilter {

    private static final String TRACE_HEADER = "X-Trace-Id";

    @Override
    protected void doFilterInternal(HttpServletRequest request,
                                    HttpServletResponse response,
                                    FilterChain filterChain) throws ServletException, IOException {
        try {
            String traceId = request.getHeader(TRACE_HEADER);
            if (traceId == null || traceId.isBlank()) {
                traceId = TraceUtil.generateTraceId();
            } else {
                org.slf4j.MDC.put(TraceUtil.TRACE_ID_KEY, traceId);
            }
            response.setHeader(TRACE_HEADER, traceId);
            filterChain.doFilter(request, response);
        } finally {
            TraceUtil.clear();
        }
    }
}
