/**
 * 质量中心类型定义
 */

// ==================== 枚举类型 ====================

export type Priority = 'low' | 'medium' | 'high' | 'critical';

export type TestCaseStatus = 'pending' | 'in_progress' | 'passed' | 'failed' | 'blocked';

export type ExecutionStatus = 'passed' | 'failed' | 'blocked';

export type ProjectStatus = 'active' | 'archived' | 'closed';

export type RequirementStatus = 
  | 'pending' 
  | 'reviewed' 
  | 'developing' 
  | 'testing' 
  | 'in_test' 
  | 'completed' 
  | 'closed';

export type FeedbackType = 'bug' | 'feature' | 'improvement' | 'question';

export type FeedbackSeverity = 'low' | 'medium' | 'high' | 'critical';

export type FeedbackStatus = 'pending' | 'in_progress' | 'resolved' | 'closed' | 'rejected';

// ==================== 实体类型 ====================

export interface TestCase {
  id?: number;
  title: string;
  project_id: number;
  module_id: number;
  requirement_id?: number | null;
  priority: Priority;
  status: TestCaseStatus;
  precondition: string;
  steps: string;
  expected_result: string;
  actual_result: string;
  assignee?: string | null;
  tags: string;
  created_by: string;
  created_at?: number | null;
  updated_at?: number | null;
  
  // 关联数据
  executions?: TestExecution[];
  requirement?: Requirement;
  bugs?: Bug[];
}

export interface TestExecution {
  id?: number;
  test_case_id: number;
  executor: string;
  status: ExecutionStatus;
  actual_result: string;
  remark: string;
  duration_ms: number;
  executed_at: number;
}

export interface Project {
  id?: number;
  name: string;
  description: string;
  status: ProjectStatus;
  owner: string;
  members: string;
  settings: string;
  archived: boolean;
  created_by: string;
  created_at?: number | null;
  updated_at?: number | null;
  
  // 关联数据
  modules?: Module[];
  test_cases?: TestCase[];
  requirements?: Requirement[];
}

export interface Module {
  id?: number;
  project_id: number;
  parent_id?: number | null;
  name: string;
  description: string;
  level: number;
  sort_order: number;
  created_by: string;
  created_at?: number | null;
  updated_at?: number | null;
  
  // 关联数据
  children?: Module[];
  test_cases?: TestCase[];
}

export interface Requirement {
  id?: number;
  project_id: number;
  title: string;
  description: string;
  priority: Priority;
  status: RequirementStatus;
  assignee?: string | null;
  estimated_cases: number;
  actual_cases: number;
  coverage_rate: number;
  created_by: string;
  created_at?: number | null;
  updated_at?: number | null;
  
  // 关联数据
  test_cases?: TestCase[];
}

export interface Feedback {
  id?: number;
  title: string;
  content: string;
  type: FeedbackType;
  severity: FeedbackSeverity;
  status: FeedbackStatus;
  assignee?: string | null;
  submitter: string;
  follow_ups: string;
  follow_count: number;
  last_follow_at?: number | null;
  created_at?: number | null;
  updated_at?: number | null;
}

export interface Bug {
  id?: number;
  title: string;
  description: string;
  severity: FeedbackSeverity;
  status: string;
  assignee?: string | null;
  created_by: string;
  created_at?: number | null;
  updated_at?: number | null;
}

// ==================== DTO 类型 ====================

export interface CreateTestCaseDto {
  title: string;
  project_id: number;
  module_id: number;
  requirement_id?: number | null;
  priority?: Priority;
  precondition?: string;
  steps?: string;
  expected_result?: string;
  assignee?: string | null;
  tags?: string;
  created_by: string;
}

export interface UpdateTestCaseDto {
  title?: string;
  module_id?: number;
  requirement_id?: number | null;
  priority?: Priority;
  status?: TestCaseStatus;
  precondition?: string;
  steps?: string;
  expected_result?: string;
  actual_result?: string;
  assignee?: string | null;
  tags?: string;
}

export interface ExecuteTestCaseDto {
  executor: string;
  status: ExecutionStatus;
  actual_result?: string;
  remark?: string;
  duration_ms?: number;
}

export interface BatchDeleteDto {
  ids: number[];
}

export interface BatchUpdateStatusDto {
  ids: number[];
  status: TestCaseStatus;
}

export interface BatchUpdateAssigneeDto {
  ids: number[];
  assignee: string;
}

export interface CreateProjectDto {
  name: string;
  description: string;
  owner?: string;
  members?: string;
  settings?: string;
  created_by: string;
}

export interface UpdateProjectDto {
  name?: string;
  description?: string;
  status?: ProjectStatus;
  owner?: string;
  members?: string;
  settings?: string;
}

export interface CreateModuleDto {
  project_id: number;
  parent_id?: number | null;
  name: string;
  description?: string;
  created_by: string;
}

export interface UpdateModuleDto {
  name?: string;
  description?: string;
  sort_order?: number;
}

export interface MoveModuleDto {
  parent_id?: number | null;
  sort_order: number;
}

export interface CreateRequirementDto {
  project_id: number;
  title: string;
  description: string;
  priority?: Priority;
  assignee?: string | null;
  estimated_cases?: number;
  created_by: string;
}

export interface UpdateRequirementDto {
  title?: string;
  description?: string;
  priority?: Priority;
  status?: RequirementStatus;
  assignee?: string | null;
  estimated_cases?: number;
}

export interface LinkTestCaseDto {
  test_case_id: number;
}

export interface CreateFeedbackDto {
  title: string;
  content: string;
  type?: FeedbackType;
  severity?: FeedbackSeverity;
  assignee?: string | null;
  submitter: string;
}

export interface UpdateFeedbackDto {
  title?: string;
  content?: string;
  type?: FeedbackType;
  severity?: FeedbackSeverity;
  status?: FeedbackStatus;
  assignee?: string | null;
}

export interface AddFollowUpDto {
  content: string;
  follower: string;
}

export interface AIGenerateTestCasesDto {
  requirement_id: number;
  max_cases?: number;
  include_edge_cases?: boolean;
  include_performance?: boolean;
  language?: string;
}

export interface AIGenerateRequirementDto {
  project_description: string;
  max_requirements?: number;
  language?: string;
}

export interface AIAnalyzeFeedbackDto {
  feedback_id: number;
}

// ==================== 查询参数类型 ====================

export interface SearchTestCasesQuery {
  project_id?: number;
  module_id?: number;
  status?: TestCaseStatus;
  assignee?: string;
  keyword?: string;
  page?: number;
  page_size?: number;
}

export interface SearchRequirementsQuery {
  project_id?: number;
  status?: RequirementStatus;
  priority?: Priority;
  assignee?: string;
  keyword?: string;
  page?: number;
  page_size?: number;
}

export interface SearchFeedbacksQuery {
  status?: FeedbackStatus;
  assignee?: string;
  severity?: FeedbackSeverity;
  type?: FeedbackType;
  category?: string;
  keyword?: string;
  start_date?: string;
  end_date?: string;
  page?: number;
  page_size?: number;
}

export interface StatisticsQuery {
  project_id?: number;
  start_date?: string;
  end_date?: string;
  time_range?: 'week' | 'month' | 'quarter' | 'custom';
}

// ==================== 响应类型 ====================

export interface PageResult<T> {
  items: T[];
  total: number;
  page: number;
  page_size: number;
}

export interface ProjectStatistics {
  total_cases: number;
  execution_count: number;
  pass_rate: number;
  bug_count: number;
  requirement_coverage: number;
}

export interface ModuleStatistics {
  total_cases: number;
  pass_rate: number;
  bug_count: number;
  coverage_rate: number;
}

export interface ModuleDistribution {
  moduleId: number;
  moduleName: string;
  testCaseCount: number;
  passRate: number;
  bugCount: number;
}

export interface BugDistribution {
  moduleName: string;
  functionalBugs: number;
  performanceBugs: number;
  uiBugs: number;
  compatibilityBugs: number;
}

export interface FeedbackDistribution {
  status: FeedbackStatus;
  count: number;
}

export interface QualityTrendPoint {
  date: string;
  passRate: number;
  bugCount: number;
  executionCount: number;
}

export interface GeneratedTestCase {
  title: string;
  precondition: string;
  steps: string;
  expected_result: string;
  priority: Priority;
  tags: string[];
  selected?: boolean;
}

export interface GeneratedRequirement {
  title: string;
  description: string;
  priority: Priority;
  estimated_cases: number;
}

export interface FeedbackAnalysis {
  bug_type: string;
  severity: FeedbackSeverity;
  affected_modules: string[];
  suggested_actions: string[];
}

export interface AIGenerateResponse {
  test_cases: GeneratedTestCase[];
  progress?: number;
  message?: string;
}

export interface ModuleTreeNode extends Module {
  children?: ModuleTreeNode[];
}
