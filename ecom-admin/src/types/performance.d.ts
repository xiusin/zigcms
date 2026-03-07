/**
 * 性能监控类型定义
 */

/**
 * 指标类型
 */
export type MetricType = 'counter' | 'gauge' | 'histogram' | 'summary';

/**
 * 指标数据点
 */
export interface MetricPoint {
  timestamp: number;
  value: number;
  labels?: Record<string, string>;
}

/**
 * 指标
 */
export interface Metric {
  name: string;
  type: MetricType;
  description: string;
  unit: string;
  current: number | null;
  points: number;
}

/**
 * 指标统计
 */
export interface MetricStats {
  name: string;
  type: MetricType;
  current: number;
  average: number;
  max: number;
  min: number;
  count: number;
}

/**
 * 健康状态
 */
export type HealthStatus = 'healthy' | 'warning' | 'unhealthy';

/**
 * 健康检查响应
 */
export interface HealthCheckResponse {
  status: HealthStatus;
  timestamp: number;
  issues: string[];
}

/**
 * 系统概览
 */
export interface SystemOverview {
  http: {
    total_requests: number | null;
    avg_duration: number | null;
  };
  database: {
    total_queries: number | null;
    avg_duration: number | null;
  };
  cache: {
    hit_rate: number | null;
  };
  system: {
    memory_usage: number | null;
    cpu_usage: number | null;
  };
  business: {
    active_users: number | null;
  };
}

/**
 * 指标查询参数
 */
export interface MetricQueryParams {
  name: string;
  duration?: number; // 秒
}
