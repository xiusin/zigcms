/**
 * 质量中心类型定义
 * 融合自动化测试系统与反馈系统的统一数据模型
 */

// ==================== 质量中心Dashboard统计 ====================

/** 质量概览统计 */
export interface QualityOverview {
  /** 测试通过率 */
  pass_rate: number;
  /** 总测试任务数 */
  total_tasks: number;
  /** 活跃Bug数 */
  active_bugs: number;
  /** 待处理反馈数 */
  pending_feedbacks: number;
  /** AI修复成功率 */
  ai_fix_rate: number;
  /** 本周测试执行次数 */
  weekly_executions: number;
  /** 反馈转测试任务数 */
  feedback_to_task_count: number;
  /** 平均Bug修复时长(小时) */
  avg_bug_fix_hours: number;
}

/** 趋势数据点 */
export interface TrendDataPoint {
  date: string;
  pass_rate: number;
  bug_count: number;
  feedback_count: number;
  execution_count: number;
}

/** 质量趋势 */
export interface QualityTrend {
  trend_data: TrendDataPoint[];
  period: 'week' | 'month' | 'quarter';
}

/** 模块质量分布 */
export interface ModuleQualityItem {
  module_name: string;
  pass_rate: number;
  bug_count: number;
  case_count: number;
  feedback_count: number;
}

/** Bug类型分布 */
export interface BugTypeDistribution {
  type: string;
  type_name: string;
  count: number;
  percentage: number;
}

/** 反馈状态分布 */
export interface FeedbackStatusDistribution {
  status: number;
  status_name: string;
  count: number;
  percentage: number;
}

// ==================== 反馈与测试联动 ====================

/** 反馈转测试任务参数 */
export interface FeedbackToTestTaskParams {
  feedback_id: number;
  task_name: string;
  task_type: string;
  priority: number;
  description?: string;
  auto_generate_cases?: boolean;
  case_count?: number;
  assign_to?: number;
}

/** 反馈转测试任务响应 */
export interface FeedbackToTestTaskResponse {
  task_id: number;
  task_name: string;
  generated_cases: number;
  status: string;
}

/** Bug同步到反馈参数 */
export interface BugToFeedbackParams {
  bug_analysis_id: number;
  feedback_title?: string;
  feedback_type?: number;
  priority?: number;
  assign_to?: number;
}

/** Bug同步到反馈响应 */
export interface BugToFeedbackResponse {
  feedback_id: number;
  feedback_title: string;
  status: string;
}

/** 关联记录 */
export interface LinkRecord {
  id: number;
  source_type: 'feedback' | 'bug' | 'task' | 'case';
  source_id: number;
  source_title: string;
  target_type: 'feedback' | 'bug' | 'task' | 'case';
  target_id: number;
  target_title: string;
  link_type: 'feedback_to_task' | 'bug_to_feedback' | 'task_to_bug' | 'case_to_bug';
  created_at: string;
  created_by: string;
}

// ==================== 活动流 ====================

/** 活动记录 */
export interface ActivityRecord {
  id: number;
  type: 'test_pass' | 'test_fail' | 'bug_found' | 'bug_fixed' | 'feedback_created' | 'feedback_resolved' | 'ai_analysis' | 'ai_fix';
  title: string;
  description: string;
  module: string;
  user_name: string;
  user_avatar?: string;
  related_id?: number;
  related_type?: string;
  created_at: string;
}

// ==================== AI洞察 ====================

/** AI质量洞察 */
export interface AIQualityInsight {
  id: number;
  type: 'risk' | 'suggestion' | 'anomaly' | 'trend';
  severity: 'high' | 'medium' | 'low';
  title: string;
  description: string;
  module?: string;
  action_url?: string;
  action_text?: string;
  created_at: string;
}

// ==================== 定时报表 ====================

/** 定时报表任务 */
export interface ScheduledReport {
  id: number;
  name: string;
  description: string;
  /** 报表类型 */
  report_type: 'daily' | 'weekly' | 'monthly' | 'custom';
  /** cron表达式或简单周期 */
  schedule: string;
  /** 包含模块 */
  modules: string[];
  /** 收件人邮箱列表 */
  recipients: string[];
  /** 报表格式 */
  format: 'pdf' | 'excel' | 'both';
  /** 是否启用水印 */
  watermark_enabled: boolean;
  /** 是否启用 */
  enabled: boolean;
  /** 上次执行时间 */
  last_run_at?: string;
  /** 下次执行时间 */
  next_run_at?: string;
  /** 上次执行状态 */
  last_status?: 'success' | 'failed' | 'running';
  /** 创建人 */
  created_by: string;
  created_at: string;
  updated_at?: string;
}

/** 报表执行历史 */
export interface ReportHistory {
  id: number;
  report_id: number;
  report_name: string;
  status: 'success' | 'failed' | 'running';
  format: 'pdf' | 'excel' | 'both';
  file_url?: string;
  file_size?: number;
  recipients: string[];
  sent_count: number;
  error_message?: string;
  started_at: string;
  finished_at?: string;
  duration_ms?: number;
}

/** 创建/编辑定时报表参数 */
export interface ScheduledReportParams {
  name: string;
  description?: string;
  report_type: 'daily' | 'weekly' | 'monthly' | 'custom';
  schedule: string;
  modules: string[];
  recipients: string[];
  format: 'pdf' | 'excel' | 'both';
  watermark_enabled?: boolean;
  enabled?: boolean;
}

// ==================== Bug关联分析 ====================

/** Bug关联数据（脑图用） */
export interface BugLinkData {
  id: number;
  title: string;
  severity: 'critical' | 'high' | 'medium' | 'low';
  module: string;
  status: string;
  related_cases: Array<{ id: number; name: string; status: string }>;
  related_feedbacks: Array<{ id: number; title: string; status: string }>;
}

// ==================== 反馈分类分析 ====================

/** 反馈分类数据（脑图用） */
export interface FeedbackClassification {
  id: number;
  title: string;
  type: string;
  type_name: string;
  status: number;
  status_name: string;
  priority: string;
  module?: string;
  created_at: string;
}

// ==================== 报表模板 ====================

/** 报表模板区块 */
export interface ReportTemplateBlock {
  id: string;
  type: 'stat_cards' | 'trend_chart' | 'module_table' | 'bug_pie' | 'feedback_pie' | 'ai_insights' | 'custom_text' | 'divider';
  title: string;
  enabled: boolean;
  order: number;
  config?: Record<string, unknown>;
}

/** 报表模板 */
export interface ReportTemplate {
  id: number;
  name: string;
  description: string;
  /** 模板区块列表 */
  blocks: ReportTemplateBlock[];
  /** 页面方向 */
  orientation: 'portrait' | 'landscape';
  /** 是否含水印 */
  watermark: boolean;
  /** 页眉文字 */
  header_text?: string;
  /** 页脚文字 */
  footer_text?: string;
  /** 是否为默认模板 */
  is_default: boolean;
  created_by: string;
  created_at: string;
  updated_at?: string;
}

/** 报表模板创建/编辑参数 */
export interface ReportTemplateParams {
  name: string;
  description?: string;
  blocks: ReportTemplateBlock[];
  orientation?: 'portrait' | 'landscape';
  watermark?: boolean;
  header_text?: string;
  footer_text?: string;
  is_default?: boolean;
}

// ==================== 邮件模板 ====================

/** 邮件模板 */
export interface EmailTemplate {
  id: number;
  name: string;
  subject: string;
  /** HTML正文 */
  body_html: string;
  /** 变量列表 */
  variables: string[];
  /** 是否为默认模板 */
  is_default: boolean;
  /** 使用场景 */
  scene: 'daily_report' | 'weekly_report' | 'monthly_report' | 'alert' | 'custom';
  created_by: string;
  created_at: string;
  updated_at?: string;
}

/** 邮件模板创建/编辑参数 */
export interface EmailTemplateParams {
  name: string;
  subject: string;
  body_html: string;
  variables?: string[];
  is_default?: boolean;
  scene: EmailTemplate['scene'];
}

// ==================== AI分析 ====================

/** AI分析请求参数 */
export interface AIAnalysisRequest {
  /** 分析类型 */
  type: 'quality_overview' | 'bug_analysis' | 'feedback_analysis' | 'trend_prediction' | 'risk_assessment' | 'custom';
  /** 分析上下文 */
  context: Record<string, unknown>;
  /** 自定义问题（custom类型时使用） */
  question?: string;
  /** 关联模块 */
  module?: string;
}

/** AI分析响应 */
export interface AIAnalysisResponse {
  task_id: string;
  status: 'pending' | 'analyzing' | 'completed' | 'error';
  /** 分析结果摘要 */
  summary: string;
  /** 详细分析 */
  details: AIAnalysisDetail[];
  /** 建议列表 */
  suggestions: AIAnalysisSuggestion[];
  /** 风险评分 0-100 */
  risk_score?: number;
  /** 分析耗时(ms) */
  duration_ms?: number;
  created_at: string;
}

/** AI分析详细项 */
export interface AIAnalysisDetail {
  title: string;
  content: string;
  type: 'text' | 'chart_data' | 'table_data' | 'code';
  data?: unknown;
}

/** AI分析建议 */
export interface AIAnalysisSuggestion {
  id: number;
  priority: 'high' | 'medium' | 'low';
  title: string;
  description: string;
  action_type?: 'navigate' | 'api_call' | 'info';
  action_url?: string;
}
