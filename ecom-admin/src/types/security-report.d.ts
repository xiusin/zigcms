/**
 * 安全报告类型定义
 */

/**
 * 报告类型
 */
export type ReportType = 'daily' | 'weekly' | 'monthly' | 'custom';

/**
 * 报告格式
 */
export type ReportFormat = 'html' | 'pdf' | 'excel' | 'json';

/**
 * 报告参数
 */
export interface ReportParams {
  report_type: ReportType;
  start_date: string;
  end_date: string;
  format?: ReportFormat;
  include_charts?: boolean;
  include_details?: boolean;
}

/**
 * 趋势点
 */
export interface TrendPoint {
  date: string;
  count: number;
}

/**
 * 分布项
 */
export interface DistributionItem {
  name: string;
  value: number;
}

/**
 * 攻击类型项
 */
export interface AttackTypeItem {
  type: string;
  count: number;
  percentage: number;
}

/**
 * IP项
 */
export interface IPItem {
  ip: string;
  count: number;
  last_seen: string;
}

/**
 * 告警摘要
 */
export interface AlertSummary {
  id: number;
  level: string;
  type: string;
  message: string;
  created_at: string;
}

/**
 * 事件摘要
 */
export interface EventSummary {
  id: number;
  type: string;
  severity: string;
  description: string;
  created_at: string;
}

/**
 * 报告数据
 */
export interface ReportData {
  title: string;
  period: string;
  generated_at: number;
  
  // 统计数据
  total_alerts: number;
  critical_alerts: number;
  high_alerts: number;
  medium_alerts: number;
  low_alerts: number;
  
  total_events: number;
  blocked_ips: number;
  affected_users: number;
  
  // 趋势数据
  alert_trend: TrendPoint[];
  event_distribution: DistributionItem[];
  top_attack_types: AttackTypeItem[];
  top_attack_ips: IPItem[];
  
  // 详细数据
  recent_alerts: AlertSummary[];
  recent_events: EventSummary[];
}

/**
 * 报告生成请求
 */
export interface GenerateReportRequest {
  report_type: ReportType;
  start_date: string;
  end_date: string;
  format?: ReportFormat;
  include_charts?: boolean;
  include_details?: boolean;
}

/**
 * 报告导出请求
 */
export interface ExportReportRequest {
  start_date: string;
  end_date: string;
  format: ReportFormat;
}
