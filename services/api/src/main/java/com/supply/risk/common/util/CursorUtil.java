package com.supply.risk.common.util;

import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.math.BigDecimal;
import java.nio.charset.StandardCharsets;
import java.util.Base64;
import java.util.Map;

/**
 * 游标分页工具类，编码/解码游标值。
 *
 * <p>游标格式为 Base64 编码的 JSON：{"s":32.5,"id":1001}
 * <ul>
 *   <li>s — 排序字段值（health_score_cache）</li>
 *   <li>id — 主键 ID（用于同分值时的稳定排序）</li>
 * </ul>
 */
public final class CursorUtil {

    private static final ObjectMapper MAPPER = new ObjectMapper();

    private CursorUtil() {
    }

    /**
     * 编码游标值。
     *
     * @param score 排序字段值
     * @param id    主键 ID
     * @return Base64 编码的游标字符串
     */
    public static String encode(BigDecimal score, Long id) {
        try {
            String json = MAPPER.writeValueAsString(Map.of("s", score, "id", id));
            return Base64.getUrlEncoder().withoutPadding().encodeToString(json.getBytes(StandardCharsets.UTF_8));
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("游标编码失败", e);
        }
    }

    /**
     * 解码游标值。
     *
     * @param cursor Base64 编码的游标字符串
     * @return 解码后的游标对象
     * @throws IllegalArgumentException 游标格式错误
     */
    public static CursorValue decode(String cursor) {
        try {
            byte[] bytes = Base64.getUrlDecoder().decode(cursor);
            String json = new String(bytes, StandardCharsets.UTF_8);
            @SuppressWarnings("unchecked")
            Map<String, Object> map = MAPPER.readValue(json, Map.class);
            BigDecimal score = new BigDecimal(map.get("s").toString());
            Long id = Long.valueOf(map.get("id").toString());
            return new CursorValue(score, id);
        } catch (Exception e) {
            throw new IllegalArgumentException("游标格式错误: " + cursor, e);
        }
    }

    /**
     * 游标解码结果。
     *
     * @param score 排序字段值
     * @param id    主键 ID
     */
    public record CursorValue(BigDecimal score, Long id) {
    }
}
