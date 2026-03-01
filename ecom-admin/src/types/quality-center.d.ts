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
