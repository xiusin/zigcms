/**
 * WebSocket 客户端
 * 提供自动重连、心跳检测、消息队列等功能
 */

export interface WebSocketMessage {
  type: string;
  data: any;
}

export interface WebSocketOptions {
  url: string;
  reconnectInterval?: number;
  heartbeatInterval?: number;
  maxReconnectAttempts?: number;
  debug?: boolean;
}

export type MessageHandler = (message: WebSocketMessage) => void;
export type EventHandler = (event: Event) => void;

export class WebSocketClient {
  private ws: WebSocket | null = null;
  private url: string;
  private reconnectInterval: number;
  private heartbeatInterval: number;
  private maxReconnectAttempts: number;
  private debug: boolean;

  private reconnectTimer: number | null = null;
  private heartbeatTimer: number | null = null;
  private reconnectAttempts = 0;
  private isManualClose = false;

  private messageHandlers: Map<string, Set<MessageHandler>> = new Map();
  private eventHandlers: Map<string, Set<EventHandler>> = new Map();
  private messageQueue: WebSocketMessage[] = [];

  constructor(options: WebSocketOptions) {
    this.url = options.url;
    this.reconnectInterval = options.reconnectInterval || 5000;
    this.heartbeatInterval = options.heartbeatInterval || 30000;
    this.maxReconnectAttempts = options.maxReconnectAttempts || 10;
    this.debug = options.debug || false;
  }

  /**
   * 连接 WebSocket
   */
  connect(): Promise<void> {
    return new Promise((resolve, reject) => {
      try {
        this.log('Connecting to WebSocket...', this.url);
        this.ws = new WebSocket(this.url);

        this.ws.onopen = (event) => {
          this.log('WebSocket connected');
          this.reconnectAttempts = 0;
          this.isManualClose = false;

          // 启动心跳
          this.startHeartbeat();

          // 发送认证消息
          this.authenticate();

          // 发送队列中的消息
          this.flushMessageQueue();

          // 触发 open 事件
          this.triggerEvent('open', event);

          resolve();
        };

        this.ws.onmessage = (event) => {
          try {
            const message: WebSocketMessage = JSON.parse(event.data);
            this.log('Received message:', message);

            // 触发消息处理器
            this.triggerMessage(message);

            // 触发 message 事件
            this.triggerEvent('message', event);
          } catch (error) {
            this.log('Failed to parse message:', error);
          }
        };

        this.ws.onerror = (event) => {
          this.log('WebSocket error:', event);
          this.triggerEvent('error', event);
          reject(new Error('WebSocket connection failed'));
        };

        this.ws.onclose = (event) => {
          this.log('WebSocket closed:', event.code, event.reason);
          this.stopHeartbeat();
          this.triggerEvent('close', event);

          // 自动重连
          if (!this.isManualClose) {
            this.reconnect();
          }
        };
      } catch (error) {
        this.log('Failed to create WebSocket:', error);
        reject(error);
      }
    });
  }

  /**
   * 断开连接
   */
  disconnect(): void {
    this.log('Disconnecting WebSocket...');
    this.isManualClose = true;
    this.stopHeartbeat();
    this.stopReconnect();

    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
  }

  /**
   * 发送消息
   */
  send(message: WebSocketMessage): void {
    if (this.isConnected()) {
      const data = JSON.stringify(message);
      this.ws!.send(data);
      this.log('Sent message:', message);
    } else {
      // 连接未建立，加入队列
      this.messageQueue.push(message);
      this.log('Message queued:', message);
    }
  }

  /**
   * 注册消息处理器
   */
  on(type: string, handler: MessageHandler): void {
    if (!this.messageHandlers.has(type)) {
      this.messageHandlers.set(type, new Set());
    }
    this.messageHandlers.get(type)!.add(handler);
  }

  /**
   * 移除消息处理器
   */
  off(type: string, handler: MessageHandler): void {
    const handlers = this.messageHandlers.get(type);
    if (handlers) {
      handlers.delete(handler);
    }
  }

  /**
   * 注册事件处理器
   */
  addEventListener(event: string, handler: EventHandler): void {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, new Set());
    }
    this.eventHandlers.get(event)!.add(handler);
  }

  /**
   * 移除事件处理器
   */
  removeEventListener(event: string, handler: EventHandler): void {
    const handlers = this.eventHandlers.get(event);
    if (handlers) {
      handlers.delete(handler);
    }
  }

  /**
   * 检查连接状态
   */
  isConnected(): boolean {
    return this.ws !== null && this.ws.readyState === WebSocket.OPEN;
  }

  /**
   * 获取连接状态
   */
  getReadyState(): number {
    return this.ws?.readyState ?? WebSocket.CLOSED;
  }

  /**
   * 认证
   */
  private authenticate(): void {
    // 从 localStorage 获取 token
    const token = localStorage.getItem('token');
    if (token) {
      this.send({
        type: 'auth',
        data: { token },
      });
    }
  }

  /**
   * 启动心跳
   */
  private startHeartbeat(): void {
    this.stopHeartbeat();
    this.heartbeatTimer = window.setInterval(() => {
      if (this.isConnected()) {
        this.send({
          type: 'heartbeat',
          data: { timestamp: Date.now() },
        });
      }
    }, this.heartbeatInterval);
  }

  /**
   * 停止心跳
   */
  private stopHeartbeat(): void {
    if (this.heartbeatTimer !== null) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  /**
   * 重连
   */
  private reconnect(): void {
    if (this.reconnectAttempts >= this.maxReconnectAttempts) {
      this.log('Max reconnect attempts reached');
      return;
    }

    this.reconnectAttempts++;
    this.log(`Reconnecting... (${this.reconnectAttempts}/${this.maxReconnectAttempts})`);

    this.stopReconnect();
    this.reconnectTimer = window.setTimeout(() => {
      this.connect().catch((error) => {
        this.log('Reconnect failed:', error);
      });
    }, this.reconnectInterval);
  }

  /**
   * 停止重连
   */
  private stopReconnect(): void {
    if (this.reconnectTimer !== null) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
  }

  /**
   * 触发消息处理器
   */
  private triggerMessage(message: WebSocketMessage): void {
    const handlers = this.messageHandlers.get(message.type);
    if (handlers) {
      handlers.forEach((handler) => {
        try {
          handler(message);
        } catch (error) {
          this.log('Message handler error:', error);
        }
      });
    }
  }

  /**
   * 触发事件处理器
   */
  private triggerEvent(event: string, data: Event): void {
    const handlers = this.eventHandlers.get(event);
    if (handlers) {
      handlers.forEach((handler) => {
        try {
          handler(data);
        } catch (error) {
          this.log('Event handler error:', error);
        }
      });
    }
  }

  /**
   * 发送队列中的消息
   */
  private flushMessageQueue(): void {
    while (this.messageQueue.length > 0) {
      const message = this.messageQueue.shift()!;
      this.send(message);
    }
  }

  /**
   * 日志输出
   */
  private log(...args: any[]): void {
    if (this.debug) {
      console.log('[WebSocket]', ...args);
    }
  }
}

/**
 * 创建 WebSocket 客户端
 */
export function createWebSocketClient(options: WebSocketOptions): WebSocketClient {
  return new WebSocketClient(options);
}

/**
 * 全局 WebSocket 客户端实例
 */
let globalClient: WebSocketClient | null = null;

/**
 * 获取全局 WebSocket 客户端
 */
export function getGlobalWebSocketClient(): WebSocketClient | null {
  return globalClient;
}

/**
 * 设置全局 WebSocket 客户端
 */
export function setGlobalWebSocketClient(client: WebSocketClient): void {
  globalClient = client;
}

/**
 * 初始化全局 WebSocket 客户端
 */
export function initGlobalWebSocketClient(options: WebSocketOptions): WebSocketClient {
  if (globalClient) {
    globalClient.disconnect();
  }
  globalClient = new WebSocketClient(options);
  return globalClient;
}
