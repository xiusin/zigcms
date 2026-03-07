/**
 * 安全管理状态管理
 */
import { defineStore } from 'pinia';
import {
  getAlerts,
  getAlert,
  handleAlert,
  batchHandleAlerts,
  deleteAlert,
  getEvents,
  getEvent,
  getAuditLogs,
  getAuditLog,
  getStatistics,
  getAlertTrend,
  getEventDistribution,
  getRealtimeAlerts,
} from '@/api/security';
import type {
  Alert,
  SecurityEvent,
  AuditLog,
  HandleAlertDto,
  BatchHandleAlertsDto,
  SearchAlertsQuery,
  SearchEventsQuery,
  SearchAuditLogsQuery,
  StatisticsQuery,
  SecurityStatistics,
  AlertTrendPoint,
  EventDistribution,
  AlertNotificationConfig,
  AlertNotificationItem,
  AlertLevel,
} from '@/types/security';

interface SecurityState {
  // 告警相关
  alerts: Alert[];
  alertsTotal: number;
  alertsLoading: boolean;
  currentAlert: Alert | null;
  
  // 事件相关
  events: SecurityEvent[];
  eventsTotal: number;
  eventsLoading: boolean;
  currentEvent: SecurityEvent | null;
  
  // 审计日志相关
  auditLogs: AuditLog[];
  auditLogsTotal: number;
  auditLogsLoading: boolean;
  currentAuditLog: AuditLog | null;
  
  // 统计相关
  statistics: SecurityStatistics | null;
  alertTrend: AlertTrendPoint[];
  eventDistribution: EventDistribution[];
  statisticsLoading: boolean;
  
  // 通知相关
  notifications: AlertNotificationItem[];
  notificationConfig: AlertNotificationConfig;
  lastAlertId: number;
  pollingInterval: number | null;
  
  // 操作状态
  submitting: boolean;
}

export const useSecurityStore = defineStore('security', {
  state: (): SecurityState => ({
    // 告警相关
    alerts: [],
    alertsTotal: 0,
    alertsLoading: false,
    currentAlert: null,
    
    // 事件相关
    events: [],
    eventsTotal: 0,
    eventsLoading: false,
    currentEvent: null,
    
    // 审计日志相关
    auditLogs: [],
    auditLogsTotal: 0,
    auditLogsLoading: false,
    currentAuditLog: null,
    
    // 统计相关
    statistics: null,
    alertTrend: [],
    eventDistribution: [],
    statisticsLoading: false,
    
    // 通知相关
    notifications: [],
    notificationConfig: {
      enabled: true,
      sound: true,
      desktop: true,
      minLevel: 'medium' as AlertLevel,
      types: [],
    },
    lastAlertId: 0,
    pollingInterval: null,
    
    // 操作状态
    submitting: false,
  }),

  getters: {
    /**
     * 未读通知数量
     */
    unreadCount: (state) => {
      return state.notifications.filter(n => !n.read).length;
    },

    /**
     * 待处理告警数量
     */
    pendingAlertsCount: (state) => {
      return state.alerts.filter(a => a.status === 'pending').length;
    },

    /**
     * 严重告警数量
     */
    criticalAlertsCount: (state) => {
      return state.alerts.filter(a => a.level === 'critical').length;
    },
  },

  actions: {
    // ==================== 告警管理 ====================

    /**
     * 获取告警列表
     */
    async fetchAlerts(query?: SearchAlertsQuery) {
      this.alertsLoading = true;
      try {
        const res = await getAlerts(query);
        this.alerts = res.list;
        this.alertsTotal = res.total;
        
        // 更新最后的告警 ID
        if (res.list.length > 0) {
          this.lastAlertId = Math.max(...res.list.map(a => a.id));
        }
        
        console.log('[安全管理][fetchAlerts][成功]', {
          total: res.total,
          count: res.list.length,
        });
      } catch (error) {
        console.error('[安全管理][fetchAlerts][失败]', error);
        throw error;
      } finally {
        this.alertsLoading = false;
      }
    },

    /**
     * 获取告警详情
     */
    async fetchAlert(id: number) {
      try {
        const alert = await getAlert(id);
        this.currentAlert = alert;
        console.log('[安全管理][fetchAlert][成功]', { id });
        return alert;
      } catch (error) {
        console.error('[安全管理][fetchAlert][失败]', error);
        throw error;
      }
    },

    /**
     * 处理告警
     */
    async handleAlert(id: number, dto: HandleAlertDto) {
      this.submitting = true;
      try {
        await handleAlert(id, dto);
        
        // 更新本地状态
        const index = this.alerts.findIndex(a => a.id === id);
        if (index !== -1) {
          this.alerts[index].status = dto.status;
          this.alerts[index].handler_remark = dto.remark;
        }
        
        if (this.currentAlert && this.currentAlert.id === id) {
          this.currentAlert.status = dto.status;
          this.currentAlert.handler_remark = dto.remark;
        }
        
        console.log('[安全管理][handleAlert][成功]', { id, status: dto.status });
      } catch (error) {
        console.error('[安全管理][handleAlert][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /**
     * 批量处理告警
     */
    async batchHandleAlerts(dto: BatchHandleAlertsDto) {
      this.submitting = true;
      try {
        await batchHandleAlerts(dto);
        
        // 更新本地状态
        dto.ids.forEach(id => {
          const index = this.alerts.findIndex(a => a.id === id);
          if (index !== -1) {
            this.alerts[index].status = dto.status;
            this.alerts[index].handler_remark = dto.remark;
          }
        });
        
        console.log('[安全管理][batchHandleAlerts][成功]', {
          count: dto.ids.length,
          status: dto.status,
        });
      } catch (error) {
        console.error('[安全管理][batchHandleAlerts][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /**
     * 删除告警
     */
    async deleteAlert(id: number) {
      this.submitting = true;
      try {
        await deleteAlert(id);
        
        // 从列表中移除
        const index = this.alerts.findIndex(a => a.id === id);
        if (index !== -1) {
          this.alerts.splice(index, 1);
          this.alertsTotal--;
        }
        
        console.log('[安全管理][deleteAlert][成功]', { id });
      } catch (error) {
        console.error('[安全管理][deleteAlert][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    // ==================== 安全事件 ====================

    /**
     * 获取安全事件列表
     */
    async fetchEvents(query?: SearchEventsQuery) {
      this.eventsLoading = true;
      try {
        const res = await getEvents(query);
        this.events = res.list;
        this.eventsTotal = res.total;
        console.log('[安全管理][fetchEvents][成功]', {
          total: res.total,
          count: res.list.length,
        });
      } catch (error) {
        console.error('[安全管理][fetchEvents][失败]', error);
        throw error;
      } finally {
        this.eventsLoading = false;
      }
    },

    /**
     * 获取安全事件详情
     */
    async fetchEvent(id: number) {
      try {
        const event = await getEvent(id);
        this.currentEvent = event;
        console.log('[安全管理][fetchEvent][成功]', { id });
        return event;
      } catch (error) {
        console.error('[安全管理][fetchEvent][失败]', error);
        throw error;
      }
    },

    // ==================== 审计日志 ====================

    /**
     * 获取审计日志列表
     */
    async fetchAuditLogs(query?: SearchAuditLogsQuery) {
      this.auditLogsLoading = true;
      try {
        const res = await getAuditLogs(query);
        this.auditLogs = res.list;
        this.auditLogsTotal = res.total;
        console.log('[安全管理][fetchAuditLogs][成功]', {
          total: res.total,
          count: res.list.length,
        });
      } catch (error) {
        console.error('[安全管理][fetchAuditLogs][失败]', error);
        throw error;
      } finally {
        this.auditLogsLoading = false;
      }
    },

    /**
     * 获取审计日志详情
     */
    async fetchAuditLog(id: number) {
      try {
        const log = await getAuditLog(id);
        this.currentAuditLog = log;
        console.log('[安全管理][fetchAuditLog][成功]', { id });
        return log;
      } catch (error) {
        console.error('[安全管理][fetchAuditLog][失败]', error);
        throw error;
      }
    },

    // ==================== 统计分析 ====================

    /**
     * 获取安全统计数据
     */
    async fetchStatistics(query?: StatisticsQuery) {
      this.statisticsLoading = true;
      try {
        const stats = await getStatistics(query);
        this.statistics = stats;
        console.log('[安全管理][fetchStatistics][成功]', stats);
      } catch (error) {
        console.error('[安全管理][fetchStatistics][失败]', error);
        throw error;
      } finally {
        this.statisticsLoading = false;
      }
    },

    /**
     * 获取告警趋势
     */
    async fetchAlertTrend(query?: StatisticsQuery) {
      try {
        const res = await getAlertTrend(query);
        this.alertTrend = res.data;
        console.log('[安全管理][fetchAlertTrend][成功]', {
          count: res.data.length,
        });
      } catch (error) {
        console.error('[安全管理][fetchAlertTrend][失败]', error);
        throw error;
      }
    },

    /**
     * 获取事件分布
     */
    async fetchEventDistribution(query?: StatisticsQuery) {
      try {
        const res = await getEventDistribution(query);
        this.eventDistribution = res.data;
        console.log('[安全管理][fetchEventDistribution][成功]', {
          count: res.data.length,
        });
      } catch (error) {
        console.error('[安全管理][fetchEventDistribution][失败]', error);
        throw error;
      }
    },

    // ==================== 实时通知 ====================

    /**
     * 启动实时告警轮询
     */
    startRealtimePolling(interval: number = 30000) {
      if (this.pollingInterval) {
        return;
      }

      console.log('[安全管理][startRealtimePolling]', { interval });

      this.pollingInterval = window.setInterval(async () => {
        try {
          const newAlerts = await getRealtimeAlerts(this.lastAlertId);
          
          if (newAlerts.length > 0) {
            console.log('[安全管理][realtimePolling][新告警]', {
              count: newAlerts.length,
            });

            // 添加到通知列表
            newAlerts.forEach(alert => {
              this.addNotification(alert);
            });

            // 更新最后的告警 ID
            this.lastAlertId = Math.max(...newAlerts.map(a => a.id));
          }
        } catch (error) {
          console.error('[安全管理][realtimePolling][失败]', error);
        }
      }, interval);
    },

    /**
     * 停止实时告警轮询
     */
    stopRealtimePolling() {
      if (this.pollingInterval) {
        clearInterval(this.pollingInterval);
        this.pollingInterval = null;
        console.log('[安全管理][stopRealtimePolling]');
      }
    },

    /**
     * 添加通知
     */
    addNotification(alert: Alert) {
      // 检查是否符合通知条件
      if (!this.shouldNotify(alert)) {
        return;
      }

      const notification: AlertNotificationItem = {
        id: alert.id,
        alert,
        read: false,
        timestamp: Date.now(),
      };

      this.notifications.unshift(notification);

      // 限制通知数量
      if (this.notifications.length > 100) {
        this.notifications = this.notifications.slice(0, 100);
      }

      // 播放声音
      if (this.notificationConfig.sound) {
        this.playNotificationSound();
      }

      // 显示桌面通知
      if (this.notificationConfig.desktop) {
        this.showDesktopNotification(alert);
      }
    },

    /**
     * 判断是否应该通知
     */
    shouldNotify(alert: Alert): boolean {
      if (!this.notificationConfig.enabled) {
        return false;
      }

      // 检查级别
      const levelPriority = {
        low: 1,
        medium: 2,
        high: 3,
        critical: 4,
      };

      const alertPriority = levelPriority[alert.level];
      const minPriority = levelPriority[this.notificationConfig.minLevel];

      if (alertPriority < minPriority) {
        return false;
      }

      // 检查类型
      if (
        this.notificationConfig.types.length > 0 &&
        !this.notificationConfig.types.includes(alert.type)
      ) {
        return false;
      }

      return true;
    },

    /**
     * 播放通知声音
     */
    playNotificationSound() {
      try {
        const audio = new Audio('/sounds/alert.mp3');
        audio.play().catch(err => {
          console.warn('[安全管理][playNotificationSound][失败]', err);
        });
      } catch (error) {
        console.warn('[安全管理][playNotificationSound][失败]', error);
      }
    },

    /**
     * 显示桌面通知
     */
    async showDesktopNotification(alert: Alert) {
      if (!('Notification' in window)) {
        return;
      }

      try {
        let permission = Notification.permission;

        if (permission === 'default') {
          permission = await Notification.requestPermission();
        }

        if (permission === 'granted') {
          new Notification('安全告警', {
            body: alert.title,
            icon: '/logo.png',
            tag: `alert-${alert.id}`,
            requireInteraction: alert.level === 'critical',
          });
        }
      } catch (error) {
        console.warn('[安全管理][showDesktopNotification][失败]', error);
      }
    },

    /**
     * 标记通知为已读
     */
    markNotificationAsRead(id: number) {
      const notification = this.notifications.find(n => n.id === id);
      if (notification) {
        notification.read = true;
      }
    },

    /**
     * 标记所有通知为已读
     */
    markAllNotificationsAsRead() {
      this.notifications.forEach(n => {
        n.read = true;
      });
    },

    /**
     * 清除通知
     */
    clearNotification(id: number) {
      const index = this.notifications.findIndex(n => n.id === id);
      if (index !== -1) {
        this.notifications.splice(index, 1);
      }
    },

    /**
     * 清除所有通知
     */
    clearAllNotifications() {
      this.notifications = [];
    },

    /**
     * 更新通知配置
     */
    updateNotificationConfig(config: Partial<AlertNotificationConfig>) {
      this.notificationConfig = {
        ...this.notificationConfig,
        ...config,
      };

      // 保存到本地存储
      localStorage.setItem(
        'security_notification_config',
        JSON.stringify(this.notificationConfig)
      );

      console.log('[安全管理][updateNotificationConfig]', this.notificationConfig);
    },

    /**
     * 加载通知配置
     */
    loadNotificationConfig() {
      try {
        const saved = localStorage.getItem('security_notification_config');
        if (saved) {
          this.notificationConfig = JSON.parse(saved);
          console.log('[安全管理][loadNotificationConfig]', this.notificationConfig);
        }
      } catch (error) {
        console.warn('[安全管理][loadNotificationConfig][失败]', error);
      }
    },
  },
});
