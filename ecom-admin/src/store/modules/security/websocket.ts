/**
 * Security Store WebSocket 集成
 */
import { initGlobalWebSocketClient, getGlobalWebSocketClient, WebSocketClient } from '@/utils/websocket';
import { Message } from '@arco-design/web-vue';
import type { Alert, SecurityEvent } from '@/types/security';

let wsClient: WebSocketClient | null = null;

/**
 * 初始化 WebSocket 连接
 */
export function initWebSocket(callbacks: {
  onAlert?: (alert: Alert) => void;
  onEvent?: (event: SecurityEvent) => void;
  onNotification?: (notification: any) => void;
}) {
  // 获取 WebSocket URL
  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const host = window.location.host;
  const url = `${protocol}//${host}/ws`;

  // 创建 WebSocket 客户端
  wsClient = initGlobalWebSocketClient({
    url,
    reconnectInterval: 5000,
    heartbeatInterval: 30000,
    maxReconnectAttempts: 10,
    debug: import.meta.env.DEV,
  });

  // 注册消息处理器
  wsClient.on('alert', (message) => {
    console.log('[WebSocket] Received alert:', message.data);
    if (callbacks.onAlert) {
      callbacks.onAlert(message.data as Alert);
    }
    // 显示通知
    Message.warning({
      content: `新告警: ${message.data.message}`,
      duration: 5000,
    });
  });

  wsClient.on('event', (message) => {
    console.log('[WebSocket] Received event:', message.data);
    if (callbacks.onEvent) {
      callbacks.onEvent(message.data as SecurityEvent);
    }
  });

  wsClient.on('notification', (message) => {
    console.log('[WebSocket] Received notification:', message.data);
    if (callbacks.onNotification) {
      callbacks.onNotification(message.data);
    }
    // 显示通知
    Message.info({
      content: message.data.message || '新通知',
      duration: 3000,
    });
  });

  wsClient.on('auth', (message) => {
    console.log('[WebSocket] Auth response:', message.data);
    Message.success('WebSocket 连接已建立');
  });

  wsClient.on('heartbeat', (message) => {
    console.log('[WebSocket] Heartbeat response:', message.data);
  });

  // 注册事件处理器
  wsClient.addEventListener('open', () => {
    console.log('[WebSocket] Connection opened');
  });

  wsClient.addEventListener('close', () => {
    console.log('[WebSocket] Connection closed');
    Message.warning('WebSocket 连接已断开，正在重连...');
  });

  wsClient.addEventListener('error', (event) => {
    console.error('[WebSocket] Connection error:', event);
    Message.error('WebSocket 连接错误');
  });

  // 连接
  wsClient.connect().catch((error) => {
    console.error('[WebSocket] Failed to connect:', error);
    Message.error('WebSocket 连接失败');
  });

  return wsClient;
}

/**
 * 断开 WebSocket 连接
 */
export function disconnectWebSocket() {
  if (wsClient) {
    wsClient.disconnect();
    wsClient = null;
  }
}

/**
 * 获取 WebSocket 客户端
 */
export function getWebSocketClient(): WebSocketClient | null {
  return wsClient || getGlobalWebSocketClient();
}

/**
 * 检查 WebSocket 连接状态
 */
export function isWebSocketConnected(): boolean {
  const client = getWebSocketClient();
  return client ? client.isConnected() : false;
}

/**
 * 发送 WebSocket 消息
 */
export function sendWebSocketMessage(type: string, data: any) {
  const client = getWebSocketClient();
  if (client) {
    client.send({ type, data });
  } else {
    console.warn('[WebSocket] Client not initialized');
  }
}
