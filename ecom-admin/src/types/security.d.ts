/**
 * 安全管理类型定义
 */

// ==================== 实体类型 ====================

/**
 * 安全告警
 */
export interface Alert {
  id: number;
  level: 'low' | 'medium' | 'high' | 'critical';
  type: string;
  title: string;
  description: string;
  source: string;
  status: 'pending' | 'handling' | 'resolved' | 'ignored';
  handled_by?: string;
  handled_at?: string;
  handler_remark?: string;
  created_at: string;
  updated_at?: string;
}

/**
 * 安全事件
 */
export interface SecurityEvent {
  id: number;
  type: string;
  level: string;
  user_id?: number;
  username?: string;
  ip: string;
  user_agent: string;
  request_path: string;
  request_method: string;
  response_status: number;
  details: string;
  risk_score?: number;
  blocked: boolean;
  created_at: string;
}

/**
 * 审计日志
 */
export interface AuditLog {
  id: number;
  user_id: number;
  username: string;
  action: string;
  resource_type: string;
  resource_id?: number;
  resource_name?: string;
  details: string;
  ip: string;
  user_agent: string;
  status: 'success' | 'failed';
  error_message?: string;
  created_at: string;
}

// ==================== DTO 类型 ====================

/**
 * 处理告警 DTO
 */
export interface HandleAlertDto {
  status: 'handling' | 'resolved' | 'ignored';
  remark?: string;
}

/**
 * 批量处理告警 DTO
 */
export interface BatchHandleAlertsDto {
  ids: number[];
  status: 'handling' | 'resolved' | 'ignored';
  remark?: string;
}

// ==================== 查询参数类型 ====================

/**
 * 搜索告警查询参数
 */
export interface SearchAlertsQuery {
  page?: number;
  pageSize?: number;
  level?: string;
  type?: string;
  status?: string;
  source?: string;
  start_time?: string;
  end_time?: string;
  keyword?: string;
}

/**
 * 搜索事件查询参数
 */
export interface SearchEventsQuery {
  page?: number;
  pageSize?: number;
  type?: string;
  level?: string;
  username?: string;
  ip?: string;
  request_path?: string;
  request_method?: string;
  blocked?: boolean;
  start_time?: string;
  end_time?: string;
  keyword?: string;
}

/**
 * 搜索审计日志查询参数
 */
export interface SearchAuditLogsQuery {
  page?: number;
  pageSize?: number;
  user_id?: number;
  username?: string;
  action?: string;
  resource_type?: string;
  resource_id?: number;
  status?: string;
  start_time?: string;
  end_time?: string;
  keyword?: string;
}

/**
 * 统计查询参数
 */
export interface StatisticsQuery {
  start_time?: string;
  end_time?: string;
  period?: 'day' | 'week' | 'month' | 'quarter' | 'year';
}

// ==================== 响应类型 ====================

/**
 * 分页结果
 */
export interface PageResult<T> {
  list: T[];
  total: number;
  page: number;
  pageSize: number;
}

/**
 * 安全统计数据
 */
export interface SecurityStatistics {
  total_alerts: number;
  pending_alerts: number;
  critical_alerts: number;
  high_alerts: number;
  medium_alerts: number;
  low_alerts: number;
  total_events: number;
  high_risk_events: number;
  blocked_requests: number;
  total_audit_logs: number;
  failed_operations: number;
  alert_resolve_rate: number;
}

/**
 * 告警趋势点
 */
export interface AlertTrendPoint {
  date: string;
  total: number;
  critical: number;
  high: number;
  medium: number;
  low: number;
  resolved: number;
}

/**
 * 事件分布
 */
export interface EventDistribution {
  type: string;
  type_name: string;
  count: number;
  percentage: number;
  high_risk_count: number;
  blocked_count: number;
}

/**
 * 告警级别分布
 */
export interface AlertLevelDistribution {
  level: string;
  level_name: string;
  count: number;
  percentage: number;
}

/**
 * 告警类型分布
 */
export interface AlertTypeDistribution {
  type: string;
  type_name: string;
  count: number;
  percentage: number;
}

// ==================== 枚举类型 ====================

/**
 * 告警级别类型
 */
export type AlertLevel = 'low' | 'medium' | 'high' | 'critical';

/**
 * 告警状态类型
 */
export type AlertStatus = 'pending' | 'handling' | 'resolved' | 'ignored';


/**
 * 告警状态标签
 */
export const AlertStatusLabels: Record<AlertStatus, string> = {
  [AlertStatus.PENDING]: '待处理',
  [AlertStatus.HANDLING]: '处理中',
  [AlertStatus.RESOLVED]: '已解决',
  [AlertStatus.IGNORED]: '已忽略',
};

/**
 * 告警状态颜色
 */
export const AlertStatusColors: Record<AlertStatus, string> = {
  [AlertStatus.PENDING]: '#faad14',
  [AlertStatus.HANDLING]: '#1890ff',
  [AlertStatus.RESOLVED]: '#52c41a',
  [AlertStatus.IGNORED]: '#d9d9d9',
};

/**
 * 事件级别
 */
export enum EventLevel {
  INFO = 'info',
  WARNING = 'warning',
  ERROR = 'error',
  CRITICAL = 'critical',
}

/**
 * 事件级别标签
 */
export const EventLevelLabels: Record<EventLevel, string> = {
  [EventLevel.INFO]: '信息',
  [EventLevel.WARNING]: '警告',
  [EventLevel.ERROR]: '错误',
  [EventLevel.CRITICAL]: '严重',
};

/**
 * 审计日志状态
 */
export enum AuditLogStatus {
  SUCCESS = 'success',
  FAILED = 'failed',
}

/**
 * 审计日志状态标签
 */
export const AuditLogStatusLabels: Record<AuditLogStatus, string> = {
  [AuditLogStatus.SUCCESS]: '成功',
  [AuditLogStatus.FAILED]: '失败',
};

// ==================== 通知相关类型 ====================

/**
 * 告警通知配置
 */
export interface AlertNotificationConfig {
  enabled: boolean;
  sound: boolean;
  desktop: boolean;
  minLevel: AlertLevel;
  types: string[];
}

/**
 * 告警通知项
 */
export interface AlertNotificationItem {
  id: number;
  alert: Alert;
  read: boolean;
  timestamp: number;
}
