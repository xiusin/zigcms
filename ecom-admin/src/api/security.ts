/**
 * 安全管理 API 客户端
 * 
 * 功能：
 * - 安全告警管理
 * - 安全事件查询
 * - 审计日志管理
 * - 安全统计分析
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import type {
  // 实体类型
  Alert,
  SecurityEvent,
  AuditLog,
  
  // DTO 类型
  HandleAlertDto,
  BatchHandleAlertsDto,
  
  // 查询参数类型
  SearchAlertsQuery,
  SearchEventsQuery,
  SearchAuditLogsQuery,
  StatisticsQuery,
  
  // 响应类型
  PageResult,
  SecurityStatistics,
  AlertTrendPoint,
  EventDistribution,
} from '@/types/security';

// ==================== 配置 ====================

const BASE_URL = '/api/security';

// 重试配置
const RETRY_CONFIG = {
  maxRetries: 3,
  retryDelay: 1000,
  retryableStatuses: [408, 429, 500, 502, 503, 504],
};

// ==================== 工具函数 ====================

/**
 * 延迟函数
 */
const delay = (ms: number) => new Promise(resolve => setTimeout(resolve, ms));

/**
 * 判断错误是否可重试
 */
const isRetryableError = (error: AxiosError): boolean => {
  if (!error.response) {
    return true;
  }
  
  const status = error.response.status;
  return RETRY_CONFIG.retryableStatuses.includes(status);
};

/**
 * 带重试的请求包装器
 */
const requestWithRetry = async <T>(
  requestFn: () => Promise<T>,
  retries = RETRY_CONFIG.maxRetries
): Promise<T> => {
  try {
    return await requestFn();
  } catch (error) {
    if (retries > 0 && error instanceof Error && isRetryableError(error as AxiosError)) {
      await delay(RETRY_CONFIG.retryDelay);
      return requestWithRetry(requestFn, retries - 1);
    }
    throw error;
  }
};

// ==================== API 客户端类 ====================

class SecurityAPI {
  public client: AxiosInstance;

  constructor(baseURL: string = BASE_URL) {
    this.client = axios.create({
      baseURL,
      timeout: 30000,
      headers: {
        'Content-Type': 'application/json',
      },
    });

    // 请求拦截器
    this.client.interceptors.request.use(
      (config) => {
        const token = localStorage.getItem('token');
        if (token && config.headers) {
          config.headers.Authorization = `Bearer ${token}`;
        }
        return config;
      },
      (error) => {
        return Promise.reject(error);
      }
    );

    // 响应拦截器
    this.client.interceptors.response.use(
      (response) => {
        return response.data;
      },
      (error: AxiosError) => {
        if (error.response) {
          const { status, data } = error.response;
          
          switch (status) {
            case 401:
              window.location.href = '/login';
              break;
            case 403:
              console.error('无权限访问');
              break;
            case 404:
              console.error('资源不存在');
              break;
            case 500:
              console.error('服务器内部错误');
              break;
          }
          
          return Promise.reject(data || error.message);
        }
        
        return Promise.reject(error.message || '网络错误');
      }
    );
  }

  // ==================== 安全告警管理 ====================

  /**
   * 获取告警列表
   */
  async getAlerts(query?: SearchAlertsQuery): Promise<PageResult<Alert>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<Alert>>('/alerts', { params: query })
    );
  }

  /**
   * 获取告警详情
   */
  async getAlert(id: number): Promise<Alert> {
    return requestWithRetry(() =>
      this.client.get<any, Alert>(`/alerts/${id}`)
    );
  }

  /**
   * 处理告警
   */
  async handleAlert(id: number, dto: HandleAlertDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>(`/alerts/${id}/handle`, dto)
    );
  }

  /**
   * 批量处理告警
   */
  async batchHandleAlerts(dto: BatchHandleAlertsDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>('/alerts/batch-handle', dto)
    );
  }

  /**
   * 删除告警
   */
  async deleteAlert(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/alerts/${id}`)
    );
  }

  // ==================== 安全事件查询 ====================

  /**
   * 获取安全事件列表
   */
  async getEvents(query?: SearchEventsQuery): Promise<PageResult<SecurityEvent>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<SecurityEvent>>('/events', { params: query })
    );
  }

  /**
   * 获取安全事件详情
   */
  async getEvent(id: number): Promise<SecurityEvent> {
    return requestWithRetry(() =>
      this.client.get<any, SecurityEvent>(`/events/${id}`)
    );
  }

  /**
   * 导出安全事件
   */
  async exportEvents(query?: SearchEventsQuery): Promise<Blob> {
    return requestWithRetry(() =>
      this.client.get<any, Blob>('/events/export', {
        params: query,
        responseType: 'blob',
      })
    );
  }

  // ==================== 审计日志管理 ====================

  /**
   * 获取审计日志列表
   */
  async getAuditLogs(query?: SearchAuditLogsQuery): Promise<PageResult<AuditLog>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<AuditLog>>('/audit-logs', { params: query })
    );
  }

  /**
   * 获取审计日志详情
   */
  async getAuditLog(id: number): Promise<AuditLog> {
    return requestWithRetry(() =>
      this.client.get<any, AuditLog>(`/audit-logs/${id}`)
    );
  }

  /**
   * 导出审计日志
   */
  async exportAuditLogs(query?: SearchAuditLogsQuery): Promise<Blob> {
    return requestWithRetry(() =>
      this.client.get<any, Blob>('/audit-logs/export', {
        params: query,
        responseType: 'blob',
      })
    );
  }

  // ==================== 安全统计分析 ====================

  /**
   * 获取安全统计数据
   */
  async getStatistics(query?: StatisticsQuery): Promise<SecurityStatistics> {
    return requestWithRetry(() =>
      this.client.get<any, SecurityStatistics>('/statistics', { params: query })
    );
  }

  /**
   * 获取告警趋势
   */
  async getAlertTrend(query?: StatisticsQuery): Promise<{ data: AlertTrendPoint[] }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: AlertTrendPoint[] }>('/statistics/alert-trend', {
        params: query,
      })
    );
  }

  /**
   * 获取事件分布
   */
  async getEventDistribution(query?: StatisticsQuery): Promise<{ data: EventDistribution[] }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: EventDistribution[] }>('/statistics/event-distribution', {
        params: query,
      })
    );
  }

  /**
   * 获取实时告警（轮询）
   */
  async getRealtimeAlerts(lastId?: number): Promise<Alert[]> {
    return requestWithRetry(() =>
      this.client.get<any, Alert[]>('/alerts/realtime', {
        params: { last_id: lastId },
      })
    );
  }
}

// ==================== 导出单例 ====================

export const securityApi = new SecurityAPI();

export default securityApi;

// ==================== 导出便捷函数 ====================

// 安全告警
export const getAlerts = securityApi.getAlerts.bind(securityApi);
export const getAlert = securityApi.getAlert.bind(securityApi);
export const handleAlert = securityApi.handleAlert.bind(securityApi);
export const batchHandleAlerts = securityApi.batchHandleAlerts.bind(securityApi);
export const deleteAlert = securityApi.deleteAlert.bind(securityApi);

// 安全事件
export const getEvents = securityApi.getEvents.bind(securityApi);
export const getEvent = securityApi.getEvent.bind(securityApi);
export const exportEvents = securityApi.exportEvents.bind(securityApi);

// 审计日志
export const getAuditLogs = securityApi.getAuditLogs.bind(securityApi);
export const getAuditLog = securityApi.getAuditLog.bind(securityApi);
export const exportAuditLogs = securityApi.exportAuditLogs.bind(securityApi);

// 安全统计
export const getStatistics = securityApi.getStatistics.bind(securityApi);
export const getAlertTrend = securityApi.getAlertTrend.bind(securityApi);
export const getEventDistribution = securityApi.getEventDistribution.bind(securityApi);
export const getRealtimeAlerts = securityApi.getRealtimeAlerts.bind(securityApi);
