import { defineStore } from 'pinia';
import type { FeedbackNotificationState } from './types';
import type { HttpResponse } from '@/api/request';
import {
  getNotificationList,
  getUnreadCount,
  markAsRead,
  markAllAsRead,
  deleteNotifications,
  getNotificationSettings,
  updateNotificationSettings,
  getLatestNotifications,
  type FeedbackNotification,
  type NotificationSettings,
  type NotificationListParams,
  type MarkAsReadParams,
  type DeleteNotificationParams,
  type UpdateNotificationSettingsParams,
  NotificationType,
} from '@/api/feedback-notification';

const POLLING_INTERVAL = 30000; // 30秒轮询间隔

const useFeedbackNotificationStore = defineStore('feedbackNotification', {
  state: (): FeedbackNotificationState => ({
    notifications: [],
    unreadCount: 0,
    unreadByType: {
      [NotificationType.ASSIGNED]: 0,
      [NotificationType.STATUS_CHANGED]: 0,
      [NotificationType.NEW_COMMENT]: 0,
      [NotificationType.MENTIONED]: 0,
      [NotificationType.FEEDBACK_CLOSED]: 0,
      [NotificationType.FEEDBACK_RESOLVED]: 0,
    },
    settings: null,
    loading: false,
    actionLoading: false,
    pollTimer: null,
    lastNotificationId: null,
    error: null,
    pagination: {
      page: 1,
      pageSize: 20,
      total: 0,
    },
  }),

  getters: {
    /** 获取所有通知 */
    getAllNotifications: (state): FeedbackNotification[] => state.notifications,
    /** 获取未读通知 */
    getUnreadNotifications: (state): FeedbackNotification[] =>
      state.notifications.filter((n) => !n.is_read),
    /** 获取已读通知 */
    getReadNotifications: (state): FeedbackNotification[] =>
      state.notifications.filter((n) => n.is_read),
    /** 按类型筛选通知 */
    getNotificationsByType:
      (state) =>
      (type: NotificationType): FeedbackNotification[] =>
        state.notifications.filter((n) => n.type === type),
    /** 获取未读数量 */
    getUnreadCount: (state): number => state.unreadCount,
    /** 获取通知设置 */
    getSettings: (state): NotificationSettings | null => state.settings,
    /** 是否正在加载 */
    isLoading: (state): boolean => state.loading,
    /** 是否正在执行操作 */
    isActionLoading: (state): boolean => state.actionLoading,
    /** 获取分页信息 */
    getPagination: (state) => state.pagination,
  },

  actions: {
    // ========== 状态设置 ==========

    /** 设置通知列表 */
    setNotifications(notifications: FeedbackNotification[]) {
      this.notifications = notifications;
      // 更新最后获取的通知 ID
      if (notifications.length > 0) {
        this.lastNotificationId = Math.max(
          ...notifications.map((n) => n.id)
        );
      }
    },

    /** 追加通知（用于轮询获取新通知） */
    appendNotifications(newNotifications: FeedbackNotification[]) {
      // 去重后追加到列表头部
      const existingIds = new Set(this.notifications.map((n) => n.id));
      const uniqueNew = newNotifications.filter(
        (n) => !existingIds.has(n.id)
      );
      this.notifications.unshift(...uniqueNew);
      // 更新最后获取的通知 ID
      if (uniqueNew.length > 0) {
        this.lastNotificationId = Math.max(
          ...uniqueNew.map((n) => n.id),
          this.lastNotificationId || 0
        );
      }
      return uniqueNew.length; // 返回新增数量
    },

    /** 设置未读数量 */
    setUnreadCount(count: number, byType?: Record<NotificationType, number>) {
      this.unreadCount = count;
      if (byType) {
        this.unreadByType = byType;
      }
    },

    /** 设置通知设置 */
    setSettings(settings: NotificationSettings) {
      this.settings = settings;
    },

    /** 设置加载状态 */
    setLoading(loading: boolean) {
      this.loading = loading;
    },

    /** 设置操作加载状态 */
    setActionLoading(loading: boolean) {
      this.actionLoading = loading;
    },

    /** 设置错误信息 */
    setError(error: string | null) {
      this.error = error;
    },

    /** 设置分页信息 */
    setPagination(pagination: Partial<FeedbackNotificationState['pagination']>) {
      Object.assign(this.pagination, pagination);
    },

    /** 标记单个通知为已读（本地更新） */
    markNotificationAsReadLocal(notificationId: number) {
      const notification = this.notifications.find((n) => n.id === notificationId);
      if (notification && !notification.is_read) {
        notification.is_read = true;
        notification.read_at = new Date().toISOString();
        this.unreadCount = Math.max(0, this.unreadCount - 1);
        // 更新类型统计
        if (this.unreadByType[notification.type] > 0) {
          this.unreadByType[notification.type]--;
        }
      }
    },

    /** 标记所有通知为已读（本地更新） */
    markAllAsReadLocal() {
      this.notifications.forEach((n) => {
        if (!n.is_read) {
          n.is_read = true;
          n.read_at = new Date().toISOString();
        }
      });
      this.unreadCount = 0;
      Object.keys(this.unreadByType).forEach((key) => {
        this.unreadByType[key as NotificationType] = 0;
      });
    },

    /** 删除通知（本地更新） */
    deleteNotificationsLocal(ids: number[]) {
      const deletedNotifications = this.notifications.filter((n) =>
        ids.includes(n.id)
      );
      this.notifications = this.notifications.filter((n) => !ids.includes(n.id));
      // 更新未读数量
      const deletedUnread = deletedNotifications.filter((n) => !n.is_read);
      this.unreadCount = Math.max(0, this.unreadCount - deletedUnread.length);
      // 更新类型统计
      deletedUnread.forEach((n) => {
        if (this.unreadByType[n.type] > 0) {
          this.unreadByType[n.type]--;
        }
      });
    },

    // ========== API 操作 ==========

    /**
     * 获取通知列表
     * @param params 查询参数
     */
    async fetchNotifications(
      params?: NotificationListParams
    ): Promise<HttpResponse> {
      this.setLoading(true);
      this.setError(null);
      try {
        const res = await getNotificationList({
          page: this.pagination.page,
          pageSize: this.pagination.pageSize,
          ...params,
        });
        if (res.code === 0) {
          this.setNotifications(res.data.list || []);
          this.setPagination({
            page: res.data.page || 1,
            pageSize: res.data.pageSize || 20,
            total: res.data.total || 0,
          });
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '获取通知列表失败');
        throw error;
      } finally {
        this.setLoading(false);
      }
    },

    /**
     * 获取未读通知数量
     */
    async fetchUnreadCount(): Promise<HttpResponse> {
      try {
        const res = await getUnreadCount();
        if (res.code === 0) {
          this.setUnreadCount(res.data.total, res.data.by_type);
        }
        return res;
      } catch (error: any) {
        console.error('获取未读数量失败:', error);
        throw error;
      }
    },

    /**
     * 标记通知为已读
     * @param params 标记参数
     */
    async markAsRead(params?: MarkAsReadParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await markAsRead(params);
        if (res.code === 0) {
          if (params?.ids && params.ids.length > 0) {
            // 标记指定通知为已读
            params.ids.forEach((id) => this.markNotificationAsReadLocal(id));
          } else {
            // 标记全部已读
            this.markAllAsReadLocal();
          }
          // 重新获取未读数量
          await this.fetchUnreadCount();
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '标记已读失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    /**
     * 标记所有通知为已读
     */
    async markAllAsRead(): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await markAllAsRead();
        if (res.code === 0) {
          this.markAllAsReadLocal();
          this.setUnreadCount(0);
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '标记全部已读失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    /**
     * 删除通知
     * @param params 删除参数
     */
    async deleteNotifications(params: DeleteNotificationParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await deleteNotifications(params);
        if (res.code === 0) {
          this.deleteNotificationsLocal(params.ids);
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '删除通知失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    /**
     * 获取通知设置
     */
    async fetchSettings(): Promise<HttpResponse> {
      this.setLoading(true);
      try {
        const res = await getNotificationSettings();
        if (res.code === 0) {
          this.setSettings(res.data);
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '获取通知设置失败');
        throw error;
      } finally {
        this.setLoading(false);
      }
    },

    /**
     * 更新通知设置
     * @param params 更新参数
     */
    async updateSettings(params: UpdateNotificationSettingsParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await updateNotificationSettings(params);
        if (res.code === 0 && this.settings) {
          // 本地更新设置
          Object.assign(this.settings, params);
          this.settings.updated_at = new Date().toISOString();
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '更新通知设置失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    /**
     * 轮询获取最新通知
     * @returns 新增通知数量
     */
    async pollLatestNotifications(): Promise<number> {
      try {
        const res = await getLatestNotifications(
          this.lastNotificationId || undefined
        );
        if (res.code === 0 && res.data.list && res.data.list.length > 0) {
          const newCount = this.appendNotifications(res.data.list);
          // 更新未读数量
          await this.fetchUnreadCount();
          return newCount;
        }
        return 0;
      } catch (error: any) {
        console.error('轮询通知失败:', error);
        return 0;
      }
    },

    // ========== 轮询控制 ==========

    /**
     * 启动轮询
     */
    startPolling() {
      // 先停止现有轮询
      this.stopPolling();
      // 立即执行一次
      this.pollLatestNotifications();
      // 设置定时器
      this.pollTimer = window.setInterval(() => {
        this.pollLatestNotifications();
      }, POLLING_INTERVAL);
    },

    /**
     * 停止轮询
     */
    stopPolling() {
      if (this.pollTimer) {
        clearInterval(this.pollTimer);
        this.pollTimer = null;
      }
    },

    /**
     * 重启轮询
     */
    restartPolling() {
      this.startPolling();
    },

    // ========== 初始化 ==========

    /**
     * 初始化通知模块
     */
    async init() {
      await Promise.all([this.fetchNotifications(), this.fetchUnreadCount()]);
      this.startPolling();
    },

    // ========== 重置 ==========

    /**
     * 重置状态
     */
    reset() {
      this.stopPolling();
      this.notifications = [];
      this.unreadCount = 0;
      this.unreadByType = {
        [NotificationType.ASSIGNED]: 0,
        [NotificationType.STATUS_CHANGED]: 0,
        [NotificationType.NEW_COMMENT]: 0,
        [NotificationType.MENTIONED]: 0,
        [NotificationType.FEEDBACK_CLOSED]: 0,
        [NotificationType.FEEDBACK_RESOLVED]: 0,
      };
      this.settings = null;
      this.loading = false;
      this.actionLoading = false;
      this.pollTimer = null;
      this.lastNotificationId = null;
      this.error = null;
      this.pagination = {
        page: 1,
        pageSize: 20,
        total: 0,
      };
    },
  },
});

export { useFeedbackNotificationStore };
export default useFeedbackNotificationStore;
