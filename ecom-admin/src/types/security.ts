/**
 * 安全管理常量定义
 * 注意：这是 .ts 文件，用于导出实际的值
 * 类型定义在 security.d.ts 中
 */

/**
 * 告警级别枚举
 */
export enum AlertLevel {
  LOW = 'low',
  MEDIUM = 'medium',
  HIGH = 'high',
  CRITICAL = 'critical',
}

/**
 * 告警级别标签
 */
export const AlertLevelLabels: Record<string, string> = {
  low: '低',
  medium: '中',
  high: '高',
  critical: '严重',
};

// 兼容旧的命名
export const ALERT_LEVEL_LABELS = AlertLevelLabels;

/**
 * 告警级别颜色
 */
export const AlertLevelColors: Record<string, string> = {
  low: '#52c41a',
  medium: '#faad14',
  high: '#ff7a45',
  critical: '#f5222d',
};

// 兼容旧的命名
export const ALERT_LEVEL_COLORS = AlertLevelColors;

/**
 * 告警状态枚举
 */
export enum AlertStatus {
  PENDING = 'pending',
  HANDLING = 'handling',
  RESOLVED = 'resolved',
  IGNORED = 'ignored',
}

/**
 * 告警状态标签
 */
export const AlertStatusLabels: Record<string, string> = {
  pending: '待处理',
  handling: '处理中',
  resolved: '已解决',
  ignored: '已忽略',
};

// 兼容旧的命名
export const ALERT_STATUS_LABELS = AlertStatusLabels;

/**
 * 告警状态颜色
 */
export const AlertStatusColors: Record<string, string> = {
  pending: 'orange',
  handling: 'blue',
  resolved: 'green',
  ignored: 'gray',
};

// 兼容旧的命名
export const ALERT_STATUS_COLORS = AlertStatusColors;

/**
 * 告警类型标签
 */
export const AlertTypeLabels: Record<string, string> = {
  rate_limit: '频率限制',
  suspicious_activity: '可疑活动',
  brute_force: '暴力破解',
  sql_injection: 'SQL注入',
  xss: 'XSS攻击',
  csrf: 'CSRF攻击',
  unauthorized_access: '未授权访问',
  data_breach: '数据泄露',
  malware: '恶意软件',
  ddos: 'DDoS攻击',
};

// 兼容旧的命名
export const ALERT_TYPE_LABELS = AlertTypeLabels;



/**
 * 事件级别标签
 */
export const EventLevelLabels: Record<string, string> = {
  info: '信息',
  warning: '警告',
  error: '错误',
  critical: '严重',
};
