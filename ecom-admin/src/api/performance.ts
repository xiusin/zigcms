import request from '@/utils/request';
import type {
  Metric,
  MetricStats,
  HealthCheckResponse,
  SystemOverview,
  MetricQueryParams,
} from '@/types/performance';

/**
 * 获取所有指标
 */
export function getAllMetrics() {
  return request<Metric[]>({
    url: '/api/monitoring/metrics',
    method: 'get',
  });
}

/**
 * 获取指定指标
 */
export function getMetric(name: string) {
  return request<Metric>({
    url: `/api/monitoring/metrics/${name}`,
    method: 'get',
  });
}

/**
 * 获取指标统计
 */
export function getMetricStats(params: MetricQueryParams) {
  return request<MetricStats>({
    url: `/api/monitoring/metrics/${params.name}/stats`,
    method: 'get',
    params: {
      duration: params.duration || 3600,
    },
  });
}

/**
 * 健康检查
 */
export function healthCheck() {
  return request<HealthCheckResponse>({
    url: '/api/monitoring/health',
    method: 'get',
  });
}

/**
 * 获取系统概览
 */
export function getSystemOverview() {
  return request<SystemOverview>({
    url: '/api/monitoring/overview',
    method: 'get',
  });
}
