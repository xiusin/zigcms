/**
 * WebSocket 通知服务
 * 
 * 功能：
 * - 实时接收反馈状态变更通知
 * - 自动重连
 * - 心跳检测
 */

export interface WebSocketMessage {
  type: 'feedback_update' | 'feedback_assign' | 'feedback_follow_up' | 'heartbeat';
  data: any;
  timestamp: number;
}

export type MessageHandler = (message: WebSocketMessage) => void;

class WebSocketService {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectAttempts = 0;
  private maxReconnectAttempts = 5;
  private reconnectDelay = 3000;
  private heartbeatInterval: number | null = null;
  private heartbeatTimeout = 30000;
  private messageHandlers: Set<MessageHandler> = new Set();
  private isManualClose = false;

  constructor(url: string) {
    this.url = url;
  }

  /**
   * 连接 WebSocket
   */
  connect(): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      console.log('WebSocket already connected');
      return;
    }

    this.isManualClose = false;

    try {
      this.ws = new WebSocket(this.url);

      this.ws.onopen = this.handleOpen.bind(this);
      this.ws.onmessage = this.handleMessage.bind(this);
      this.ws.onerror = this.handleError.bind(this);
      this.ws.onclose = this.handleClose.bind(this);
    } catch (error) {
      console.error('WebSocket connection error:', error);
      this.scheduleReconnect();
    }
  }

  /**
   * 断开连接
   */
  disconnect(): void {
    this.isManualClose = true;
    this.stopHeartbeat();

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  /**
   * 发送消息
   */
  send(message: WebSocketMessage): void {
    if (this.ws?.readyState === WebSocket.OPEN) {
      this.ws.send(JSON.stringify(message));
    } else {
      console.warn('WebSocket is not connected');
    }
  }

  /**
   * 订阅消息
   */
  subscribe(handler: MessageHandler): () => void {
    this.messageHandlers.add(handler);

    // 返回取消订阅函数
    return () => {
      this.messageHandlers.delete(handler);
    };
  }

  /**
   * 处理连接打开
   */
  private handleOpen(): void {
    console.log('WebSocket connected');
    this.reconnectAttempts = 0;
    this.startHeartbeat();
  }

  /**
   * 处理消息接收
   */
  private handleMessage(event: MessageEvent): void {
    try {
      const message: WebSocketMessage = JSON.parse(event.data);

      // 处理心跳响应
      if (message.type === 'heartbeat') {
        return;
      }

      // 通知所有订阅者
      this.messageHandlers.forEach((handler) => {
        try {
          handler(message);
        } catch (error) {
          console.error('Message handler error:', error);
        }
      });
    } catch (error) {
      console.error('Failed to parse WebSocket message:', error);
    }
  }

  /**
   * 处理错误
   */
  private handleError(event: Event): void {
    console.error('WebSocket error:', event);
  }

  /**
   * 处理连接关闭
   */
  private handleClose(): void {
    console.log('WebSocket disconnected');
    this.stopHeartbeat();

    // 如果不是手动关闭，尝试重连
    if (!this.isManualClose) {
      this.scheduleReconnect();
    }
  }

  /**
   * 计划重连
   */
  private scheduleReconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      console.error('Max reconnect attempts reached');
      return;
    }

    this.reconnectAttempts++;
    const delay = this.reconnectDelay * this.reconnectAttempts;

    console.log(`Reconnecting in ${delay}ms (attempt ${this.reconnectAttempts})`);

    setTimeout(() => {
      this.connect();
    }, delay);
  }

  /**
   * 启动心跳
   */
  private startHeartbeat(): void {
    this.stopHeartbeat();

    this.heartbeatInterval = window.setInterval(() => {
      this.send({
        type: 'heartbeat',
        data: null,
        timestamp: Date.now(),
      });
    }, this.heartbeatTimeout);
  }

  /**
   * 停止心跳
   */
  private stopHeartbeat(): void {
    if (this.heartbeatInterval) {
      clearInterval(this.heartbeatInterval);
      this.heartbeatInterval = null;
    }
  }
}

// 创建单例
const wsUrl = import.meta.env.VITE_WS_URL || 'ws://localhost:3000/ws';
export const websocketService = new WebSocketService(wsUrl);

export default websocketService;
