import type {
  FeedbackNotification,
  NotificationSettings,
  NotificationType,
} from '@/api/feedback-notification';

/**
 * 反馈通知模块状态类型
 */
export interface FeedbackNotificationState {
  /** 通知列表 */
  notifications: FeedbackNotification[];
  /** 未读通知数量 */
  unreadCount: number;
  /** 各类型未读数量统计 */
  unreadByType: Record<NotificationType, number>;
  /** 通知设置 */
  settings: NotificationSettings | null;
  /** 列表加载状态 */
  loading: boolean;
  /** 操作加载状态 */
  actionLoading: boolean;
  /** 轮询定时器 ID */
  pollTimer: number | null;
  /** 最后获取的通知 ID */
  lastNotificationId: number | null;
  /** 错误信息 */
  error: string | null;
  /** 分页信息 */
  pagination: {
    /** 当前页码 */
    page: number;
    /** 每页条数 */
    pageSize: number;
    /** 总数 */
    total: number;
  };
}
