package com.supply.risk.common.util;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Nested;
import org.junit.jupiter.api.Test;

import java.math.BigDecimal;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

/**
 * CursorUtil 单元测试，覆盖游标编解码的正常/异常/边界场景。
 */
@DisplayName("CursorUtil 游标分页工具类")
class CursorUtilTest {

    @Nested
    @DisplayName("encode - 编码")
    class Encode {

        @Test
        @DisplayName("正常值编码后可解码还原")
        void encode_withNormalValues_shouldBeDecodable() {
            // Arrange
            BigDecimal score = new BigDecimal("85.5");
            Long id = 1001L;

            // Act
            String cursor = CursorUtil.encode(score, id);

            // Assert
            assertThat(cursor).isNotBlank();
            CursorUtil.CursorValue decoded = CursorUtil.decode(cursor);
            assertThat(decoded.score()).isEqualByComparingTo(score);
            assertThat(decoded.id()).isEqualTo(id);
        }

        @Test
        @DisplayName("零值编码")
        void encode_withZeroScore_shouldWork() {
            String cursor = CursorUtil.encode(BigDecimal.ZERO, 1L);

            CursorUtil.CursorValue decoded = CursorUtil.decode(cursor);
            assertThat(decoded.score()).isEqualByComparingTo(BigDecimal.ZERO);
            assertThat(decoded.id()).isEqualTo(1L);
        }

        @Test
        @DisplayName("满分 100 编码")
        void encode_withMaxScore_shouldWork() {
            BigDecimal maxScore = new BigDecimal("100.0");
            String cursor = CursorUtil.encode(maxScore, Long.MAX_VALUE);

            CursorUtil.CursorValue decoded = CursorUtil.decode(cursor);
            assertThat(decoded.score()).isEqualByComparingTo(maxScore);
            assertThat(decoded.id()).isEqualTo(Long.MAX_VALUE);
        }

        @Test
        @DisplayName("高精度小数编码")
        void encode_withHighPrecision_shouldPreservePrecision() {
            BigDecimal preciseScore = new BigDecimal("72.123456");
            String cursor = CursorUtil.encode(preciseScore, 999L);

            CursorUtil.CursorValue decoded = CursorUtil.decode(cursor);
            assertThat(decoded.score()).isEqualByComparingTo(preciseScore);
        }
    }

    @Nested
    @DisplayName("decode - 解码")
    class Decode {

        @Test
        @DisplayName("非法 Base64 字符串应抛出 IllegalArgumentException")
        void decode_withInvalidBase64_shouldThrow() {
            assertThatThrownBy(() -> CursorUtil.decode("!!!not-base64!!!"))
                    .isInstanceOf(IllegalArgumentException.class)
                    .hasMessageContaining("游标格式错误");
        }

        @Test
        @DisplayName("合法 Base64 但 JSON 缺少字段应抛出异常")
        void decode_withMissingFields_shouldThrow() {
            // Base64 编码的 {"foo": "bar"}
            String invalidCursor = java.util.Base64.getUrlEncoder().withoutPadding()
                    .encodeToString("{\"foo\":\"bar\"}".getBytes());

            assertThatThrownBy(() -> CursorUtil.decode(invalidCursor))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("空字符串应抛出异常")
        void decode_withEmptyString_shouldThrow() {
            assertThatThrownBy(() -> CursorUtil.decode(""))
                    .isInstanceOf(IllegalArgumentException.class);
        }

        @Test
        @DisplayName("null 应抛出异常")
        void decode_withNull_shouldThrow() {
            assertThatThrownBy(() -> CursorUtil.decode(null))
                    .isInstanceOf(IllegalArgumentException.class);
        }
    }

    @Nested
    @DisplayName("encode + decode 往返")
    class RoundTrip {

        @Test
        @DisplayName("负分值（边界条件）应可往返")
        void roundTrip_withNegativeScore_shouldWork() {
            BigDecimal negativeScore = new BigDecimal("-10.5");
            String cursor = CursorUtil.encode(negativeScore, 42L);

            CursorUtil.CursorValue decoded = CursorUtil.decode(cursor);
            assertThat(decoded.score()).isEqualByComparingTo(negativeScore);
            assertThat(decoded.id()).isEqualTo(42L);
        }
    }
}
