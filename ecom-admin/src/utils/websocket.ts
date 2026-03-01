/**
 * WebSocket 实时推送服务
 * 【功能】报表执行状态、AI分析进度、系统通知的实时推送
 * 【高级特性】自动重连、心跳检测、事件订阅、Mock模拟
 */

/** WebSocket消息类型 */
export interface WSMessage<T = unknown> {
  type: 'report_status' | 'ai_progress' | 'notification' | 'heartbeat';
  payload: T;
  timestamp: number;
}

/** 报表执行状态推送 */
export interface ReportStatusPayload {
  report_id: number;
  report_name: string;
  status: 'running' | 'success' | 'failed';
  progress: number;
  message?: string;
  file_url?: string;
  duration_ms?: number;
}

/** AI分析进度推送 */
export interface AIProgressPayload {
  task_id: string;
  type: 'analyzing' | 'generating' | 'completed' | 'error';
  progress: number;
  message: string;
  result?: unknown;
}

/** 系统通知推送 */
export interface NotificationPayload {
  id: number;
  title: string;
  content: string;
  level: 'info' | 'warning' | 'error' | 'success';
  module: string;
  action_url?: string;
}

type MessageHandler<T = unknown> = (data: WSMessage<T>) => void;

/** WebSocket配置 */
interface WSConfig {
  url: string;
  /** 自动重连 */
  autoReconnect: boolean;
  /** 重连间隔(ms) */
  reconnectInterval: number;
  /** 最大重连次数 */
  maxReconnects: number;
  /** 心跳间隔(ms) */
  heartbeatInterval: number;
  /** 是否启用Mock模拟 */
  mock: boolean;
}

const DEFAULT_CONFIG: WSConfig = {
  url: `ws://${window.location.host}/ws/quality-center`,
  autoReconnect: true,
  reconnectInterval: 3000,
  maxReconnects: 10,
  heartbeatInterval: 30000,
  mock: true,
};

class QualityWebSocket {
  private ws: WebSocket | null = null;
  private config: WSConfig;
  private handlers = new Map<string, Set<MessageHandler>>();
  private reconnectCount = 0;
  private heartbeatTimer: ReturnType<typeof setInterval> | null = null;
  private reconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private mockTimer: ReturnType<typeof setInterval> | null = null;
  private _connected = false;

  constructor(config?: Partial<WSConfig>) {
    this.config = { ...DEFAULT_CONFIG, ...config };
  }

  get connected(): boolean {
    return this._connected;
  }

  /** 连接WebSocket（生产模式连真实ws，开发模式启用Mock） */
  connect(): void {
    if (this.config.mock) {
      this.startMock();
      return;
    }

    try {
      this.ws = new WebSocket(this.config.url);
      this.ws.onopen = () => {
        this._connected = true;
        this.reconnectCount = 0;
        this.startHeartbeat();
        console.log('[WebSocket][已连接]', this.config.url);
      };
      this.ws.onmessage = (event) => {
        try {
          const msg: WSMessage = JSON.parse(event.data);
          this.dispatch(msg);
        } catch (e) {
          console.error('[WebSocket][消息解析失败]', e);
        }
      };
      this.ws.onclose = () => {
        this._connected = false;
        this.stopHeartbeat();
        console.log('[WebSocket][已断开]');
        if (this.config.autoReconnect && this.reconnectCount < this.config.maxReconnects) {
          this.scheduleReconnect();
        }
      };
      this.ws.onerror = (err) => {
        console.error('[WebSocket][错误]', err);
      };
    } catch (err) {
      console.error('[WebSocket][连接失败]', err);
      if (this.config.autoReconnect) this.scheduleReconnect();
    }
  }

  /** 断开连接 */
  disconnect(): void {
    this.stopHeartbeat();
    this.stopMock();
    if (this.reconnectTimer) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = null;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this._connected = false;
    console.log('[WebSocket][主动断开]');
  }

  /** 订阅消息 */
  on<T = unknown>(type: string, handler: MessageHandler<T>): () => void {
    if (!this.handlers.has(type)) {
      this.handlers.set(type, new Set());
    }
    this.handlers.get(type)!.add(handler as MessageHandler);
    return () => {
      this.handlers.get(type)?.delete(handler as MessageHandler);
    };
  }

  /** 取消所有订阅 */
  offAll(): void {
    this.handlers.clear();
  }

  /** 分发消息给订阅者 */
  private dispatch(msg: WSMessage): void {
    const typeHandlers = this.handlers.get(msg.type);
    if (typeHandlers) {
      typeHandlers.forEach((h) => h(msg));
    }
    // 同时通知 * 监听者
    const allHandlers = this.handlers.get('*');
    if (allHandlers) {
      allHandlers.forEach((h) => h(msg));
    }
  }

  private scheduleReconnect(): void {
    this.reconnectCount++;
    console.log(`[WebSocket][重连][第${this.reconnectCount}次][${this.config.reconnectInterval}ms后]`);
    this.reconnectTimer = setTimeout(() => this.connect(), this.config.reconnectInterval);
  }

  private startHeartbeat(): void {
    this.heartbeatTimer = setInterval(() => {
      if (this.ws?.readyState === WebSocket.OPEN) {
        this.ws.send(JSON.stringify({ type: 'heartbeat', timestamp: Date.now() }));
      }
    }, this.config.heartbeatInterval);
  }

  private stopHeartbeat(): void {
    if (this.heartbeatTimer) {
      clearInterval(this.heartbeatTimer);
      this.heartbeatTimer = null;
    }
  }

  // ==================== Mock 模式 ====================

  private startMock(): void {
    this._connected = true;
    console.log('[WebSocket][Mock模式已启动]');
    let step = 0;

    this.mockTimer = setInterval(() => {
      step++;
      // 模拟报表执行进度
      if (step <= 10) {
        const progress = step * 10;
        const status: ReportStatusPayload['status'] = progress >= 100 ? 'success' : 'running';
        this.dispatch({
          type: 'report_status',
          payload: {
            report_id: 1,
            report_name: '每日质量日报',
            status,
            progress: Math.min(progress, 100),
            message: progress >= 100 ? '报表生成完成' : `正在生成报表... ${progress}%`,
            file_url: progress >= 100 ? '/files/report_daily.pdf' : undefined,
            duration_ms: progress >= 100 ? 12500 : undefined,
          } satisfies ReportStatusPayload,
          timestamp: Date.now(),
        });
      }

      // 模拟系统通知（每30s一条）
      if (step % 6 === 0) {
        const notifications: NotificationPayload[] = [
          { id: step, title: '新Bug已提交', content: '订单模块发现新的高优先级Bug', level: 'warning', module: '订单系统', action_url: '/auto-test/bug' },
          { id: step, title: '测试通过率提升', content: '支付模块测试通过率已达95%', level: 'success', module: '支付模块' },
          { id: step, title: '反馈已处理', content: '用户反馈#207已由张三处理完成', level: 'info', module: '反馈系统', action_url: '/feedback/list' },
        ];
        this.dispatch({
          type: 'notification',
          payload: notifications[step % notifications.length],
          timestamp: Date.now(),
        });
      }
    }, 5000);
  }

  private stopMock(): void {
    if (this.mockTimer) {
      clearInterval(this.mockTimer);
      this.mockTimer = null;
    }
    this._connected = false;
  }
}

/** 全局单例 */
let instance: QualityWebSocket | null = null;

export function useWebSocket(config?: Partial<WSConfig>): QualityWebSocket {
  if (!instance) {
    instance = new QualityWebSocket(config);
  }
  return instance;
}

export function destroyWebSocket(): void {
  if (instance) {
    instance.disconnect();
    instance.offAll();
    instance = null;
  }
}
