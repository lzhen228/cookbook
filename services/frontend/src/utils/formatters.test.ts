import { describe, it, expect } from 'vitest';
import { formatDateTime, formatDate, formatRelativeTime, formatTrend, formatScore } from './formatters';

/**
 * 格式化工具函数测试。
 *
 * 覆盖正常值、null、undefined、边界值。
 */
describe('formatters', () => {
  // ==================== formatDateTime ====================
  describe('formatDateTime', () => {
    it('should format ISO datetime to YYYY-MM-DD HH:mm', () => {
      const result = formatDateTime('2026-03-20T10:30:00+08:00');
      expect(result).toBe('2026-03-20 10:30');
    });

    it('should return "-" for null', () => {
      expect(formatDateTime(null)).toBe('-');
    });

    it('should return "-" for undefined', () => {
      expect(formatDateTime(undefined)).toBe('-');
    });

    it('should return "-" for empty string', () => {
      expect(formatDateTime('')).toBe('-');
    });
  });

  // ==================== formatDate ====================
  describe('formatDate', () => {
    it('should format date string to YYYY-MM-DD', () => {
      const result = formatDate('2026-03-20');
      expect(result).toBe('2026-03-20');
    });

    it('should format datetime string to date only', () => {
      const result = formatDate('2026-03-20T10:30:00+08:00');
      expect(result).toBe('2026-03-20');
    });

    it('should return "-" for null', () => {
      expect(formatDate(null)).toBe('-');
    });

    it('should return "-" for undefined', () => {
      expect(formatDate(undefined)).toBe('-');
    });
  });

  // ==================== formatRelativeTime ====================
  describe('formatRelativeTime', () => {
    it('should return "-" for null', () => {
      expect(formatRelativeTime(null)).toBe('-');
    });

    it('should return "-" for undefined', () => {
      expect(formatRelativeTime(undefined)).toBe('-');
    });

    it('should return a relative time string for valid input', () => {
      // 使用一个较早的日期，应返回如 "X天前" 的字符串
      const result = formatRelativeTime('2020-01-01T00:00:00+08:00');
      expect(result).toBeTruthy();
      expect(result).not.toBe('-');
    });
  });

  // ==================== formatTrend ====================
  describe('formatTrend', () => {
    it('should format positive trend with + sign', () => {
      expect(formatTrend(2.3)).toBe('+2.3');
    });

    it('should format negative trend with - sign', () => {
      expect(formatTrend(-5.2)).toBe('-5.2');
    });

    it('should format zero trend without sign', () => {
      expect(formatTrend(0)).toBe('0.0');
    });

    it('should return "-" for null', () => {
      expect(formatTrend(null)).toBe('-');
    });

    it('should return "-" for undefined', () => {
      expect(formatTrend(undefined)).toBe('-');
    });

    // 边界：很小的正数
    it('should format very small positive number with + sign', () => {
      expect(formatTrend(0.1)).toBe('+0.1');
    });

    // 边界：很大的负数
    it('should format large negative number', () => {
      expect(formatTrend(-99.9)).toBe('-99.9');
    });
  });

  // ==================== formatScore ====================
  describe('formatScore', () => {
    it('should format score with one decimal', () => {
      expect(formatScore(85.5)).toBe('85.5');
    });

    it('should format integer score with one decimal', () => {
      expect(formatScore(100)).toBe('100.0');
    });

    it('should format zero', () => {
      expect(formatScore(0)).toBe('0.0');
    });

    it('should return "-" for null', () => {
      expect(formatScore(null)).toBe('-');
    });

    it('should return "-" for undefined', () => {
      expect(formatScore(undefined)).toBe('-');
    });
  });
});
