/**
 * 质量中心报表类型定义
 */

/** 报表类型 */
export type ReportType = 'test_case' | 'feedback' | 'requirement' | 'project_quality';

/** 报表参数 */
export interface ReportParams {
  report_type: ReportType;
  project_id?: number;
  start_date: string;
  end_date: string;
  module_ids?: number[];
}

/** 模块统计 */
export interface ModuleStats {
  module_name: string;
  total: number;
  passed: number;
  failed: number;
  pass_rate: number;
}

/** 类型统计 */
export interface TypeStats {
  type_name: string;
  count: number;
  percentage: number;
}

/** 趋势点 */
export interface TrendPoint {
  date: string;
  value: number;
}

/** 执行摘要 */
export interface ExecutionSummary {
  test_case_id: number;
  test_case_title: string;
  result: string;
  executed_by: string;
  executed_at: string;
}

/** 反馈摘要 */
export interface FeedbackSummary {
  id: number;
  title: string;
  type: string;
  status: string;
  priority: string;
  created_at: string;
}

/** 需求摘要 */
export interface RequirementSummary {
  id: number;
  title: string;
  status: string;
  priority: string;
  created_at: string;
}

/** 风险因素 */
export interface RiskFactor {
  factor: string;
  level: 'low' | 'medium' | 'high';
  description: string;
}

/** 测试用例统计数据 */
export interface TestCaseStats {
  total: number;
  passed: number;
  failed: number;
  blocked: number;
  skipped: number;
  pass_rate: number;
  
  // 按优先级分布
  priority_high: number;
  priority_medium: number;
  priority_low: number;
  
  // 按模块分布
  module_distribution: ModuleStats[];
  
  // 执行趋势
  execution_trend: TrendPoint[];
  
  // 最近执行
  recent_executions: ExecutionSummary[];
}

/** 反馈统计数据 */
export interface FeedbackStats {
  total: number;
  open: number;
  in_progress: number;
  resolved: number;
  closed: number;
  resolution_rate: number;
  avg_resolution_time: number; // 小时
  
  // 按类型分布
  type_distribution: TypeStats[];
  
  // 按优先级分布
  priority_high: number;
  priority_medium: number;
  priority_low: number;
  
  // 处理趋势
  resolution_trend: TrendPoint[];
  
  // 最近反馈
  recent_feedbacks: FeedbackSummary[];
}

/** 需求统计数据 */
export interface RequirementStats {
  total: number;
  draft: number;
  reviewing: number;
  approved: number;
  in_development: number;
  completed: number;
  completion_rate: number;
  
  // 按优先级分布
  priority_high: number;
  priority_medium: number;
  priority_low: number;
  
  // 变更统计
  total_changes: number;
  avg_changes_per_requirement: number;
  
  // 完成趋势
  completion_trend: TrendPoint[];
  
  // 最近需求
  recent_requirements: RequirementSummary[];
}

/** 项目质量数据 */
export interface ProjectQualityStats {
  project_name: string;
  
  // 测试覆盖率
  test_coverage: number;
  
  // 缺陷密度
  defect_density: number;
  
  // 质量指标
  quality_score: number;
  
  // 风险评估
  risk_level: string;
  risk_factors: RiskFactor[];
  
  // 进度
  progress: number;
  
  // 各维度统计
  test_case_stats: TestCaseStats;
  feedback_stats: FeedbackStats;
  requirement_stats: RequirementStats;
}
