/**
 * 反馈系统通知 API 封装
 * 包含通知获取、标记已读、通知设置等功能
 */
import request from './request';
import type { HttpResponse } from './request';

// ========== 枚举类型定义 ==========

/** 通知类型枚举 */
export enum NotificationType {
  /** 反馈被指派 */
  ASSIGNED = 'assigned',
  /** 反馈状态变更 */
  STATUS_CHANGED = 'status_changed',
  /** 有新评论 */
  NEW_COMMENT = 'new_comment',
  /** 被@提及 */
  MENTIONED = 'mentioned',
  /** 反馈被关闭 */
  FEEDBACK_CLOSED = 'feedback_closed',
  /** 反馈已解决 */
  FEEDBACK_RESOLVED = 'feedback_resolved',
}

/** 通知优先级枚举 */
export enum NotificationPriority {
  /** 紧急 */
  URGENT = 0,
  /** 高 */
  HIGH = 1,
  /** 普通 */
  NORMAL = 2,
  /** 低 */
  LOW = 3,
}

// ========== 基础类型接口 ==========

/** 通知对象 */
export interface FeedbackNotification {
  /** 通知 ID */
  id: number;
  /** 通知类型 */
  type: NotificationType;
  /** 通知标题 */
  title: string;
  /** 通知内容 */
  content: string;
  /** 关联反馈 ID */
  feedback_id: number;
  /** 关联反馈标题 */
  feedback_title: string;
  /** 触发用户 ID */
  trigger_user_id: number;
  /** 触发用户名称 */
  trigger_user_name: string;
  /** 触发用户头像 */
  trigger_user_avatar?: string;
  /** 是否已读 */
  is_read: boolean;
  /** 优先级 */
  priority: NotificationPriority;
  /** 创建时间 */
  created_at: string;
  /** 阅读时间 */
  read_at?: string;
  /** 额外数据 */
  extra_data?: Record<string, any>;
}

/** 通知设置对象 */
export interface NotificationSettings {
  /** 用户 ID */
  user_id: number;
  /** 反馈被指派通知 */
  notify_assigned: boolean;
  /** 状态变更通知 */
  notify_status_changed: boolean;
  /** 新评论通知 */
  notify_new_comment: boolean;
  /** 被@提及通知 */
  notify_mentioned: boolean;
  /** 反馈关闭/解决通知 */
  notify_feedback_closed: boolean;
  /** 邮件通知开关 */
  email_notification: boolean;
  /** 浏览器推送开关 */
  browser_notification: boolean;
  /** 免打扰开关 */
  do_not_disturb: boolean;
  /** 免打扰开始时间 */
  do_not_disturb_start?: string;
  /** 免打扰结束时间 */
  do_not_disturb_end?: string;
  /** 更新时间 */
  updated_at?: string;
}

// ========== 请求/响应参数类型 ==========

/** 分页参数 */
export interface PaginationParams {
  /** 页码 */
  page?: number;
  /** 每页数量 */
  pageSize?: number;
}

/** 通知列表查询参数 */
export interface NotificationListParams extends PaginationParams {
  /** 是否只获取未读 */
  unread_only?: boolean;
  /** 通知类型筛选 */
  type?: NotificationType;
  /** 开始时间 */
  start_time?: string;
  /** 结束时间 */
  end_time?: string;
}

/** 标记已读参数 */
export interface MarkAsReadParams {
  /** 通知 ID 列表，为空则标记全部 */
  ids?: number[];
}

/** 删除通知参数 */
export interface DeleteNotificationParams {
  /** 通知 ID 列表 */
  ids: number[];
}

/** 更新通知设置参数 */
export interface UpdateNotificationSettingsParams {
  /** 反馈被指派通知 */
  notify_assigned?: boolean;
  /** 状态变更通知 */
  notify_status_changed?: boolean;
  /** 新评论通知 */
  notify_new_comment?: boolean;
  /** 被@提及通知 */
  notify_mentioned?: boolean;
  /** 反馈关闭/解决通知 */
  notify_feedback_closed?: boolean;
  /** 邮件通知开关 */
  email_notification?: boolean;
  /** 浏览器推送开关 */
  browser_notification?: boolean;
  /** 免打扰开关 */
  do_not_disturb?: boolean;
  /** 免打扰开始时间 */
  do_not_disturb_start?: string;
  /** 免打扰结束时间 */
  do_not_disturb_end?: string;
}

// ========== 响应数据类型 ==========

/** 分页响应 */
export interface PaginatedResponse<T> {
  /** 数据列表 */
  list: T[];
  /** 总数 */
  total: number;
  /** 当前页码 */
  page: number;
  /** 每页数量 */
  pageSize: number;
}

/** 未读数量响应 */
export interface UnreadCountResponse {
  /** 未读总数 */
  total: number;
  /** 各类型未读数量 */
  by_type: Record<NotificationType, number>;
}

// ========== 通知相关 API ==========

/**
 * 获取通知列表
 * @param params 查询参数
 * @returns 通知列表分页数据
 */
export function getNotificationList(
  params?: NotificationListParams
): Promise<HttpResponse> {
  return request('/api/feedback/notification/list', params || {});
}

/**
 * 获取未读通知数量
 * @returns 未读数量统计
 */
export function getUnreadCount(): Promise<HttpResponse> {
  return request('/api/feedback/notification/unread-count', {});
}

/**
 * 标记通知为已读
 * @param params 标记参数
 * @returns 操作结果
 */
export function markAsRead(params?: MarkAsReadParams): Promise<HttpResponse> {
  return request('/api/feedback/notification/mark-read', params || {});
}

/**
 * 标记所有通知为已读
 * @returns 操作结果
 */
export function markAllAsRead(): Promise<HttpResponse> {
  return request('/api/feedback/notification/mark-all-read', {});
}

/**
 * 删除通知
 * @param params 删除参数
 * @returns 操作结果
 */
export function deleteNotifications(
  params: DeleteNotificationParams
): Promise<HttpResponse> {
  return request('/api/feedback/notification/delete', params);
}

/**
 * 获取通知设置
 * @returns 通知设置数据
 */
export function getNotificationSettings(): Promise<HttpResponse> {
  return request('/api/feedback/notification/settings', {});
}

/**
 * 更新通知设置
 * @param params 更新参数
 * @returns 更新后的设置
 */
export function updateNotificationSettings(
  params: UpdateNotificationSettingsParams
): Promise<HttpResponse> {
  return request('/api/feedback/notification/settings/update', params);
}

/**
 * 获取最新通知（用于轮询）
 * @param lastId 最后获取的通知ID
 * @returns 新通知列表
 */
export function getLatestNotifications(lastId?: number): Promise<HttpResponse> {
  return request('/api/feedback/notification/latest', { last_id: lastId });
}

// ========== 导出所有 API ==========
export default {
  getNotificationList,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteNotifications,
  getNotificationSettings,
  updateNotificationSettings,
  getLatestNotifications,
};
