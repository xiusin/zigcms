/**
 * 实时告警 Composable
 * 集成 WebSocket 实时推送，自动更新告警列表
 */

import { ref, onMounted, onUnmounted, computed } from 'vue';
import { Message, Notification } from '@arco-design/web-vue';
import { useWebSocket } from '@/utils/websocket';
import { useSecurityStore } from '@/store/modules/security';
import type { Alert } from '@/types/security';

export interface UseRealTimeAlertsOptions {
  /**
   * 是否启用实时更新
   */
  enabled?: boolean;
  
  /**
   * 是否显示桌面通知
   */
  showNotification?: boolean;
  
  /**
   * 是否播放提示音
   */
  playSound?: boolean;
  
  /**
   * 自动刷新间隔（毫秒），0 表示不自动刷新
   */
  autoRefreshInterval?: number;
  
  /**
   * 新告警回调
   */
  onNewAlert?: (alert: Alert) => void;
  
  /**
   * 告警更新回调
   */
  onAlertUpdate?: (alert: Alert) => void;
}

export function useRealTimeAlerts(options: UseRealTimeAlertsOptions = {}) {
  const {
    enabled = true,
    showNotification = true,
    playSound = true,
    autoRefreshInterval = 0,
    onNewAlert,
    onAlertUpdate,
  } = options;
  
  const securityStore = useSecurityStore();
  const ws = useWebSocket();
  
  // 连接状态
  const isConnected = ref(false);
  const reconnectAttempts = ref(0);
  const maxReconnectAttempts = 10;
  
  // 统计信息
  const stats = ref({
    newAlertsCount: 0,
    updatedAlertsCount: 0,
    lastUpdateTime: null as Date | null,
  });
  
  // 自动刷新定时器
  let refreshTimer: number | null = null;
  
  /**
   * 播放提示音
   */
  const playAlertSound = () => {
    if (!playSound) return;
    
    try {
      const audio = new Audio('/sounds/alert.mp3');
      audio.volume = 0.5;
      audio.play().catch(() => {
        // 忽略播放失败
      });
    } catch (error) {
      console.warn('Failed to play alert sound:', error);
    }
  };
  
  /**
   * 显示桌面通知
   */
  const showDesktopNotification = (alert: Alert) => {
    if (!showNotification) return;
    
    // 检查通知权限
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification('新的安全告警', {
        body: alert.message,
        icon: '/logo.png',
        tag: `alert-${alert.id}`,
        requireInteraction: alert.level === 'critical',
      });
    }
    
    // 应用内通知
    Notification.warning({
      title: `${getLevelText(alert.level)}告警`,
      content: alert.message,
      duration: alert.level === 'critical' ? 0 : 5000,
    });
  };
  
  /**
   * 处理新告警
   */
  const handleNewAlert = (alert: Alert) => {
    console.log('[RealTime] New alert received:', alert);
    
    // 更新统计
    stats.value.newAlertsCount++;
    stats.value.lastUpdateTime = new Date();
    
    // 添加到 Store
    securityStore.addAlert(alert);
    
    // 显示通知
    showDesktopNotification(alert);
    
    // 播放提示音
    playAlertSound();
    
    // 触发回调
    onNewAlert?.(alert);
  };
  
  /**
   * 处理告警更新
   */
  const handleAlertUpdate = (alert: Alert) => {
    console.log('[RealTime] Alert updated:', alert);
    
    // 更新统计
    stats.value.updatedAlertsCount++;
    stats.value.lastUpdateTime = new Date();
    
    // 更新 Store
    securityStore.updateAlert(alert);
    
    // 触发回调
    onAlertUpdate?.(alert);
  };
  
  /**
   * 连接 WebSocket
   */
  const connect = () => {
    if (!enabled) return;
    
    console.log('[RealTime] Connecting to WebSocket...');
    
    // 监听连接状态
    ws.on('connected', () => {
      console.log('[RealTime] WebSocket connected');
      isConnected.value = true;
      reconnectAttempts.value = 0;
      Message.success('实时推送已连接');
    });
    
    ws.on('disconnected', () => {
      console.log('[RealTime] WebSocket disconnected');
      isConnected.value = false;
      
      // 尝试重连
      if (reconnectAttempts.value < maxReconnectAttempts) {
        reconnectAttempts.value++;
        Message.warning(`连接断开，正在重连（${reconnectAttempts.value}/${maxReconnectAttempts}）...`);
      } else {
        Message.error('实时推送连接失败，请刷新页面重试');
      }
    });
    
    ws.on('error', (error) => {
      console.error('[RealTime] WebSocket error:', error);
      Message.error('实时推送出错');
    });
    
    // 监听告警事件
    ws.on('alert:new', handleNewAlert);
    ws.on('alert:update', handleAlertUpdate);
    
    // 连接
    ws.connect();
  };
  
  /**
   * 断开连接
   */
  const disconnect = () => {
    console.log('[RealTime] Disconnecting from WebSocket...');
    
    // 移除事件监听
    ws.off('connected');
    ws.off('disconnected');
    ws.off('error');
    ws.off('alert:new', handleNewAlert);
    ws.off('alert:update', handleAlertUpdate);
    
    // 断开连接
    ws.disconnect();
    
    isConnected.value = false;
  };
  
  /**
   * 启动自动刷新
   */
  const startAutoRefresh = () => {
    if (autoRefreshInterval <= 0) return;
    
    console.log(`[RealTime] Starting auto refresh (interval: ${autoRefreshInterval}ms)`);
    
    refreshTimer = window.setInterval(() => {
      console.log('[RealTime] Auto refreshing alerts...');
      securityStore.fetchAlerts();
    }, autoRefreshInterval);
  };
  
  /**
   * 停止自动刷新
   */
  const stopAutoRefresh = () => {
    if (refreshTimer) {
      console.log('[RealTime] Stopping auto refresh');
      clearInterval(refreshTimer);
      refreshTimer = null;
    }
  };
  
  /**
   * 请求通知权限
   */
  const requestNotificationPermission = async () => {
    if ('Notification' in window && Notification.permission === 'default') {
      const permission = await Notification.requestPermission();
      if (permission === 'granted') {
        Message.success('已开启桌面通知');
      }
    }
  };
  
  /**
   * 获取级别文本
   */
  const getLevelText = (level: string) => {
    const labels: Record<string, string> = {
      info: '信息',
      warning: '警告',
      error: '错误',
      critical: '严重',
    };
    return labels[level] || level;
  };
  
  // 生命周期
  onMounted(() => {
    connect();
    startAutoRefresh();
    requestNotificationPermission();
  });
  
  onUnmounted(() => {
    disconnect();
    stopAutoRefresh();
  });
  
  return {
    // 状态
    isConnected: computed(() => isConnected.value),
    reconnectAttempts: computed(() => reconnectAttempts.value),
    stats: computed(() => stats.value),
    
    // 方法
    connect,
    disconnect,
    playAlertSound,
    showDesktopNotification,
    requestNotificationPermission,
  };
}

