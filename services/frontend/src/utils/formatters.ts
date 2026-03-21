import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/zh-cn';

dayjs.extend(relativeTime);
dayjs.locale('zh-cn');

/** 格式化日期时间 */
export function formatDateTime(value: string | null | undefined): string {
  if (!value) return '-';
  return dayjs(value).format('YYYY-MM-DD HH:mm');
}

/** 格式化日期 */
export function formatDate(value: string | null | undefined): string {
  if (!value) return '-';
  return dayjs(value).format('YYYY-MM-DD');
}

/** 格式化相对时间（如"2小时前"） */
export function formatRelativeTime(value: string | null | undefined): string {
  if (!value) return '-';
  return dayjs(value).fromNow();
}

/** 格式化健康分趋势（正值显示 +，负值显示 -） */
export function formatTrend(value: number | null | undefined): string {
  if (value == null) return '-';
  const sign = value > 0 ? '+' : '';
  return `${sign}${value.toFixed(1)}`;
}

/** 格式化健康分 */
export function formatScore(value: number | null | undefined): string {
  if (value == null) return '-';
  return value.toFixed(1);
}
