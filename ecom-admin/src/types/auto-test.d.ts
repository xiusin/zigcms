/**
 * 自动化测试系统类型定义
 * 包含测试任务、测试用例、Bug分析、执行记录等核心类型
 */

// ==================== 枚举类型 ====================

/** 测试任务类型 */
export enum TestTaskType {
  /** 功能测试 */
  FUNCTIONAL = 'functional',
  /** 集成测试 */
  INTEGRATION = 'integration',
  /** 回归测试 */
  REGRESSION = 'regression',
  /** 性能测试 */
  PERFORMANCE = 'performance',
  /** 安全测试 */
  SECURITY = 'security',
  /** AI生成测试 */
  AI_GENERATED = 'ai_generated',
}

/** 测试任务状态 */
export enum TestTaskStatus {
  /** 待执行 */
  PENDING = 'pending',
  /** 排队中 */
  QUEUED = 'queued',
  /** 执行中 */
  RUNNING = 'running',
  /** 已完成 */
  COMPLETED = 'completed',
  /** 失败 */
  FAILED = 'failed',
  /** 已取消 */
  CANCELLED = 'cancelled',
  /** 已暂停 */
  PAUSED = 'paused',
}

/** 触发类型 */
export enum TriggerType {
  /** 手动触发 */
  MANUAL = 'manual',
  /** 定时触发 */
  SCHEDULED = 'scheduled',
  /** Webhook触发 */
  WEBHOOK = 'webhook',
  /** CI/CD触发 */
  CI_CD = 'ci_cd',
  /** AI自动触发 */
  AI_AUTO = 'ai_auto',
}

/** 优先级 */
export enum TaskPriority {
  /** 紧急 */
  URGENT = 0,
  /** 高 */
  HIGH = 1,
  /** 中 */
  MEDIUM = 2,
  /** 低 */
  LOW = 3,
}

/** 测试用例类型 */
export enum TestCaseType {
  /** API测试 */
  API = 'api',
  /** UI测试 */
  UI = 'ui',
  /** 单元测试 */
  UNIT = 'unit',
  /** 端到端测试 */
  E2E = 'e2e',
}

/** 测试用例状态 */
export enum TestCaseStatus {
  /** 草稿 */
  DRAFT = 'draft',
  /** 有效 */
  ACTIVE = 'active',
  /** 禁用 */
  DISABLED = 'disabled',
  /** 废弃 */
  DEPRECATED = 'deprecated',
}

/** 测试用例来源 */
export enum TestCaseSource {
  /** 手动创建 */
  MANUAL = 'manual',
  /** AI自动生成 */
  AI_GENERATED = 'ai_generated',
  /** 导入 */
  IMPORTED = 'imported',
  /** 录制 */
  RECORDED = 'recorded',
  /** 转换 */
  CONVERTED = 'converted',
}

/** Bug类型 */
export enum BugType {
  /** 功能错误 */
  FUNCTIONAL = 'functional',
  /** 界面问题 */
  UI = 'ui',
  /** 性能问题 */
  PERFORMANCE = 'performance',
  /** 安全问题 */
  SECURITY = 'security',
  /** 数据问题 */
  DATA = 'data',
  /** 兼容性问题 */
  COMPATIBILITY = 'compatibility',
  /** 逻辑错误 */
  LOGIC = 'logic',
  /** 配置错误 */
  CONFIGURATION = 'configuration',
  /** 网络问题 */
  NETWORK = 'network',
  /** 未知问题 */
  UNKNOWN = 'unknown',
}

/** 问题位置 */
export enum IssueLocation {
  /** 前端问题 */
  FRONTEND = 'frontend',
  /** 后端问题 */
  BACKEND = 'backend',
  /** 数据库问题 */
  DATABASE = 'database',
  /** 基础设施问题 */
  INFRASTRUCTURE = 'infrastructure',
  /** 第三方服务问题 */
  THIRD_PARTY = 'third_party',
  /** 未知 */
  UNKNOWN = 'unknown',
}

/** Bug严重程度 */
export enum BugSeverity {
  /** 致命 - P0 */
  CRITICAL = 0,
  /** 严重 - P1 */
  HIGH = 1,
  /** 一般 - P2 */
  MEDIUM = 2,
  /** 轻微 - P3 */
  LOW = 3,
  /** 建议 - P4 */
  TRIVIAL = 4,
}

/** Bug分析状态 */
export enum BugAnalysisStatus {
  /** 待分析 */
  PENDING = 'pending',
  /** 分析中 */
  ANALYZING = 'analyzing',
  /** 已分析 */
  ANALYZED = 'analyzed',
  /** 自动修复中 */
  AUTO_FIXING = 'auto_fixing',
  /** 已自动修复 */
  AUTO_FIXED = 'auto_fixed',
  /** 验证中 */
  VERIFICATION = 'verification',
  /** 已解决 */
  RESOLVED = 'resolved',
  /** 已重新打开 */
  REOPENED = 'reopened',
  /** 已关闭 */
  CLOSED = 'closed',
  /** 失败 */
  FAILED = 'failed',
}

/** 执行类型 */
export enum ExecutionType {
  /** 任务执行 */
  TASK = 'task',
  /** 单用例执行 */
  SINGLE_CASE = 'single_case',
  /** 批量执行 */
  BATCH = 'batch',
  /** 调试执行 */
  DEBUG = 'debug',
}

/** 执行状态 */
export enum ExecutionStatus {
  /** 待执行 */
  PENDING = 'pending',
  /** 初始化 */
  INITIALIZING = 'initializing',
  /** 执行中 */
  RUNNING = 'running',
  /** 收集结果 */
  COLLECTING = 'collecting',
  /** 已完成 */
  COMPLETED = 'completed',
  /** 失败 */
  FAILED = 'failed',
  /** 已终止 */
  TERMINATED = 'terminated',
  /** 已暂停 */
  PAUSED = 'paused',
}

/** 报告类型 */
export enum ReportType {
  /** 执行报告 */
  EXECUTION = 'execution',
  /** 趋势报告 */
  TREND = 'trend',
  /** 质量报告 */
  QUALITY = 'quality',
  /** 覆盖率报告 */
  COVERAGE = 'coverage',
}

/** 报告格式 */
export enum ReportFormat {
  /** HTML */
  HTML = 'html',
  /** PDF */
  PDF = 'pdf',
  /** JSON */
  JSON = 'json',
  /** Excel */
  EXCEL = 'excel',
}

/** HTTP方法 */
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';

// ==================== 基础类型接口 ====================

/** 测试任务 */
export interface TestTask {
  id: number;
  name: string;
  description: string;
  type: TestTaskType;
  status: TestTaskStatus;
  priority: TaskPriority;
  trigger_type: TriggerType;
  schedule?: string;
  webhook_url?: string;
  test_suite_id?: number;
  related_feedback_id?: number;
  created_by: number;
  assigned_to?: number;
  total_runs: number;
  success_count: number;
  fail_count: number;
  last_run_at?: string;
  last_run_result?: TestResult;
  created_at: string;
  updated_at?: string;
  started_at?: string;
  completed_at?: string;
}

/** 测试结果 */
export interface TestResult {
  passed: number;
  failed: number;
  skipped: number;
  total: number;
  pass_rate: number;
  duration: number;
  details?: TestCaseResult[];
}

/** 测试用例 */
export interface TestCase {
  id: number;
  name: string;
  description: string;
  type: TestCaseType;
  status: TestCaseStatus;
  test_type: 'api' | 'ui' | 'unit' | 'e2e';
  method: HttpMethod;
  endpoint: string;
  headers?: Record<string, string>;
  params?: Record<string, any>;
  body?: any;
  expected_status: number;
  expected_response?: any;
  validation_rules?: ValidationRule[];
  module_id?: number;
  test_suite_id?: number;
  tags?: string[];
  related_bug_id?: number;
  source: TestCaseSource;
  generated_by_ai?: boolean;
  ai_prompt?: string;
  run_count: number;
  pass_count: number;
  fail_count: number;
  avg_duration?: number;
  created_at: string;
  updated_at?: string;
}

/** 验证规则 */
export interface ValidationRule {
  field: string;
  type: 'equals' | 'contains' | 'regex' | 'schema' | 'custom';
  expected: any;
  message?: string;
}

/** 测试套件 */
export interface TestSuite {
  id: number;
  name: string;
  description: string;
  module_id?: number;
  case_count: number;
  created_by: number;
  created_at: string;
  updated_at?: string;
}

/** Bug分析 */
export interface BugAnalysis {
  id: number;
  title: string;
  description: string;
  type: BugType;
  severity: BugSeverity;
  priority: TaskPriority;
  issue_location: IssueLocation;
  frontend_issue?: FrontendIssue;
  backend_issue?: BackendIssue;
  reproduction: ReproductionInfo;
  steps: ReproductionStep[];
  environment: TestEnvironment;
  test_data?: any;
  root_cause?: string;
  analysis_report?: string;
  suggested_fix?: string;
  confidence_score?: number;
  status: BugAnalysisStatus;
  auto_fix_attempted: boolean;
  auto_fix_result?: AutoFixResult;
  test_task_id?: number;
  test_case_id?: number;
  feedback_id?: number;
  ai_model?: string;
  analysis_tokens?: number;
  created_at: string;
}

/** 前端问题详情 */
export interface FrontendIssue {
  component?: string;
  file_path?: string;
  line_number?: number;
  error_type?: string;
  error_message?: string;
  stack_trace?: string;
  browser?: string;
  viewport?: string;
}

/** 后端问题详情 */
export interface BackendIssue {
  api_endpoint?: string;
  http_method?: string;
  error_code?: string;
  error_message?: string;
  stack_trace?: string;
  server_log?: string;
  database_query?: string;
}

/** 复现信息 */
export interface ReproductionInfo {
  is_reproducible: boolean;
  reproducibility_rate?: number;
  first_occurrence?: string;
  last_occurrence?: string;
  occurrence_count?: number;
}

/** 复现步骤 */
export interface ReproductionStep {
  step_number: number;
  action: string;
  expected: string;
  actual: string;
  screenshot?: string;
  timestamp?: string;
}

/** 测试环境 */
export interface TestEnvironment {
  platform: string;
  os?: string;
  browser?: string;
  browser_version?: string;
  device?: string;
  screen_resolution?: string;
  network?: string;
  location?: string;
}

/** 自动修复结果 */
export interface AutoFixResult {
  success: boolean;
  fix_applied?: boolean;
  fix_code?: string;
  fix_description?: string;
  files_modified?: string[];
  tests_passed?: boolean;
  error?: string;
}

/** 测试执行记录 */
export interface TestExecution {
  id: number;
  test_task_id: number;
  test_case_id?: number;
  name: string;
  type: ExecutionType;
  status: ExecutionStatus;
  progress: number;
  triggered_by: number;
  trigger_type: TriggerType;
  trigger_params?: any;
  environment: TestEnvironment;
  iteration?: number;
  total_cases: number;
  passed_cases: number;
  failed_cases: number;
  skipped_cases: number;
  duration?: number;
  results?: TestCaseResult[];
  summary?: ExecutionSummary;
  logs: ExecutionLog[];
  created_at: string;
  started_at?: string;
  completed_at?: string;
}

/** 测试用例结果 */
export interface TestCaseResult {
  test_case_id: number;
  test_case_name: string;
  status: 'passed' | 'failed' | 'skipped' | 'error';
  duration: number;
  error_message?: string;
  stack_trace?: string;
  screenshot?: string;
  request?: any;
  response?: any;
}

/** 执行摘要 */
export interface ExecutionSummary {
  total: number;
  passed: number;
  failed: number;
  skipped: number;
  pass_rate: number;
  avg_duration: number;
}

/** 执行日志 */
export interface ExecutionLog {
  id: number;
  timestamp: string;
  level: 'debug' | 'info' | 'warn' | 'error';
  source: string;
  message: string;
  data?: any;
  step?: string;
}

/** 测试报告 */
export interface TestReport {
  id: number;
  name: string;
  type: ReportType;
  format: ReportFormat;
  test_task_id?: number;
  test_execution_id?: number;
  test_suite_id?: number;
  summary: ReportSummary;
  charts?: ReportChart[];
  details?: ReportDetail[];
  recommendations?: string[];
  quality_metrics?: QualityMetrics;
  generated_by: number;
  generated_at: string;
  file_path?: string;
  file_size?: number;
}

/** 报告摘要 */
export interface ReportSummary {
  total_cases: number;
  passed: number;
  failed: number;
  skipped: number;
  pass_rate: number;
  avg_duration: number;
  start_time: string;
  end_time: string;
}

/** 报告图表 */
export interface ReportChart {
  type: 'pie' | 'bar' | 'line' | 'table';
  title: string;
  data: any;
}

/** 报告详情 */
export interface ReportDetail {
  category: string;
  items: any[];
}

/** 质量指标 */
export interface QualityMetrics {
  code_coverage?: number;
  new_bugs_found: number;
  regression_bugs: number;
  performance_issues: number;
  security_issues: number;
}

// ==================== 请求/响应类型 ====================

/** 分页参数 */
export interface PaginationParams {
  page?: number;
  pageSize?: number;
}

/** 测试任务列表查询参数 */
export interface TestTaskListParams extends PaginationParams {
  keyword?: string;
  type?: TestTaskType;
  status?: TestTaskStatus;
  priority?: TaskPriority;
  trigger_type?: TriggerType;
  created_by?: number;
  start_time?: string;
  end_time?: string;
}

/** 测试用例列表查询参数 */
export interface TestCaseListParams extends PaginationParams {
  keyword?: string;
  type?: TestCaseType;
  status?: TestCaseStatus;
  test_type?: string;
  module_id?: number;
  test_suite_id?: number;
  tags?: string[];
  source?: TestCaseSource;
}

/** Bug分析列表查询参数 */
export interface BugAnalysisListParams extends PaginationParams {
  keyword?: string;
  type?: BugType;
  severity?: BugSeverity;
  status?: BugAnalysisStatus;
  issue_location?: IssueLocation;
  test_task_id?: number;
  feedback_id?: number;
  start_time?: string;
  end_time?: string;
}

/** 执行记录列表查询参数 */
export interface TestExecutionListParams extends PaginationParams {
  test_task_id?: number;
  status?: ExecutionStatus;
  triggered_by?: number;
  trigger_type?: TriggerType;
  start_time?: string;
  end_time?: string;
}

/** 创建测试任务参数 */
export interface CreateTestTaskParams {
  name: string;
  description?: string;
  type: TestTaskType;
  priority?: TaskPriority;
  trigger_type: TriggerType;
  schedule?: string;
  webhook_url?: string;
  test_suite_id?: number;
  related_feedback_id?: number;
}

/** 更新测试任务参数 */
export interface UpdateTestTaskParams extends Partial<CreateTestTaskParams> {
  id: number;
}

/** 创建测试用例参数 */
export interface CreateTestCaseParams {
  name: string;
  description?: string;
  type: TestCaseType;
  test_type: 'api' | 'ui' | 'unit' | 'e2e';
  method: HttpMethod;
  endpoint: string;
  headers?: Record<string, string>;
  params?: Record<string, any>;
  body?: any;
  expected_status: number;
  expected_response?: any;
  validation_rules?: ValidationRule[];
  module_id?: number;
  test_suite_id?: number;
  tags?: string[];
}

/** AI分析Bug参数 */
export interface AIBugAnalysisParams {
  title: string;
  description: string;
  error_message?: string;
  stack_trace?: string;
  screenshots?: string[];
  environment?: TestEnvironment;
  test_data?: any;
  related_feedback_id?: number;
  test_task_id?: number;
  test_case_id?: number;
}

/** AI自动修复参数 */
export interface AIAutoFixParams {
  bug_analysis_id: number;
  auto_verify?: boolean;
}

/** AI生成测试用例参数 */
export interface AIGenerateTestCaseParams {
  target: string;
  type: 'api' | 'ui' | 'unit';
  module_id?: number;
  test_suite_id?: number;
  count?: number;
  context?: {
    api_spec?: any;
    existing_cases?: number[];
    code_diff?: string;
  };
}

/** AI执行测试任务参数 */
export interface AIExecuteTaskParams {
  test_task_id: number;
  execute_options?: {
    parallel?: boolean;
    retry_failed?: boolean;
    timeout?: number;
  };
}

/** 执行测试用例参数 */
export interface RunTestCaseParams {
  test_case_id: number;
  environment?: TestEnvironment;
  test_data?: any;
}

// ==================== API响应类型 ====================

/** 通用API响应 */
export interface TestApiResponse<T = any> {
  code: number;
  msg: string;
  data: T;
}

/** 测试任务列表响应 */
export interface TestTaskListResponse {
  list: TestTask[];
  total: number;
  page: number;
  pageSize: number;
}

/** 测试用例列表响应 */
export interface TestCaseListResponse {
  list: TestCase[];
  total: number;
  page: number;
  pageSize: number;
}

/** Bug分析列表响应 */
export interface BugAnalysisListResponse {
  list: BugAnalysis[];
  total: number;
  page: number;
  pageSize: number;
}

/** 执行记录列表响应 */
export interface TestExecutionListResponse {
  list: TestExecution[];
  total: number;
  page: number;
  pageSize: number;
}

/** 测试报告列表响应 */
export interface TestReportListResponse {
  list: TestReport[];
  total: number;
  page: number;
  pageSize: number;
}

/** AI分析响应 */
export interface AIBugAnalysisResponse {
  bug_analysis: BugAnalysis;
  processing_time: number;
  tokens_used: number;
}

/** AI修复响应 */
export interface AIAutoFixResponse {
  success: boolean;
  bug_analysis: BugAnalysis;
  fix_result?: AutoFixResult;
  verification_passed?: boolean;
  processing_time: number;
}

/** AI生成用例响应 */
export interface AIGenerateCaseResponse {
  test_cases: TestCase[];
  generation_time: number;
  tokens_used: number;
  coverage_improvement?: number;
}

/** 执行日志流响应 */
export interface ExecutionLogStreamResponse {
  logs: ExecutionLog[];
  has_more: boolean;
  next_cursor?: string;
}
