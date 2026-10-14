/**
 * 日期时间工具函数
 */

import dayjs from 'dayjs';
import relativeTime from 'dayjs/plugin/relativeTime';
import 'dayjs/locale/zh-cn';

// 配置 dayjs
dayjs.extend(relativeTime);
dayjs.locale('zh-cn');

/**
 * 格式化日期时间
 * @param date 日期（时间戳或字符串）
 * @param format 格式（默认：YYYY-MM-DD HH:mm:ss）
 */
export const formatDateTime = (
  date?: number | string | null,
  format: string = 'YYYY-MM-DD HH:mm:ss'
): string => {
  if (!date) return '-';
  return dayjs(date).format(format);
};

/**
 * 格式化日期
 * @param date 日期（时间戳或字符串）
 * @param format 格式（默认：YYYY-MM-DD）
 */
export const formatDate = (
  date?: number | string | null,
  format: string = 'YYYY-MM-DD'
): string => {
  if (!date) return '-';
  return dayjs(date).format(format);
};

/**
 * 格式化时间
 * @param date 日期（时间戳或字符串）
 * @param format 格式（默认：HH:mm:ss）
 */
export const formatTime = (
  date?: number | string | null,
  format: string = 'HH:mm:ss'
): string => {
  if (!date) return '-';
  return dayjs(date).format(format);
};

/**
 * 格式化相对时间
 * @param date 日期（时间戳或字符串）
 */
export const formatRelativeTime = (date?: number | string | null): string => {
  if (!date) return '-';
  return dayjs(date).fromNow();
};

/**
 * 获取当前时间戳（秒）
 */
export const getCurrentTimestamp = (): number => {
  return Math.floor(Date.now() / 1000);
};

/**
 * 获取当前时间戳（毫秒）
 */
export const getCurrentTimestampMs = (): number => {
  return Date.now();
};

/**
 * 判断日期是否在范围内
 * @param date 日期
 * @param start 开始日期
 * @param end 结束日期
 */
export const isDateInRange = (
  date: number | string,
  start: number | string,
  end: number | string
): boolean => {
  const d = dayjs(date);
  return d.isAfter(dayjs(start)) && d.isBefore(dayjs(end));
};

/**
 * 获取日期范围
 * @param type 类型（week/month/quarter）
 */
export const getDateRange = (
  type: 'week' | 'month' | 'quarter'
): [string, string] => {
  const now = dayjs();
  let start: dayjs.Dayjs;
  let end: dayjs.Dayjs = now;

  switch (type) {
    case 'week':
      start = now.subtract(7, 'day');
      break;
    case 'month':
      start = now.subtract(30, 'day');
      break;
    case 'quarter':
      start = now.subtract(90, 'day');
      break;
  }

  return [start.format('YYYY-MM-DD'), end.format('YYYY-MM-DD')];
};
