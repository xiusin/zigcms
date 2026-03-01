/**
 * 自动化测试系统 API 封装
 * 包含测试任务、测试用例、Bug分析、测试执行、报告等功能
 */
import request from './request';
import type {
  HttpResponse,
  TestTask,
  TestCase,
  BugAnalysis,
  TestExecution,
  TestReport,
  TestTaskListParams,
  TestCaseListParams,
  BugAnalysisListParams,
  TestExecutionListParams,
  CreateTestTaskParams,
  UpdateTestTaskParams,
  CreateTestCaseParams,
  AIBugAnalysisParams,
  AIAutoFixParams,
  AIGenerateTestCaseParams,
  AIExecuteTaskParams,
  RunTestCaseParams,
  TestTaskListResponse,
  TestCaseListResponse,
  BugAnalysisListResponse,
  TestExecutionListResponse,
  TestReportListResponse,
  AIBugAnalysisResponse,
  AIAutoFixResponse,
  AIGenerateCaseResponse,
  ExecutionLog,
  TestResult,
  TestSuite,
} from '@/types/auto-test';

// ==================== 测试任务管理 API ====================

/**
 * 获取测试任务列表
 */
export function getTestTaskList(
  params: TestTaskListParams
): Promise<HttpResponse<TestTaskListResponse>> {
  return request.get('/api/auto-test/task/list', { params });
}

/**
 * 获取测试任务详情
 */
export function getTestTaskDetail(id: number): Promise<HttpResponse<TestTask>> {
  return request.get('/api/auto-test/task/detail', { params: { id } });
}

/**
 * 创建测试任务
 */
export function createTestTask(
  data: CreateTestTaskParams
): Promise<HttpResponse<TestTask>> {
  return request.post('/api/auto-test/task/create', data);
}

/**
 * 更新测试任务
 */
export function updateTestTask(
  data: UpdateTestTaskParams
): Promise<HttpResponse<TestTask>> {
  return request.post('/api/auto-test/task/update', data);
}

/**
 * 删除测试任务
 */
export function deleteTestTask(id: number): Promise<HttpResponse<null>> {
  return request.delete('/api/auto-test/task/delete', { params: { id } });
}

/**
 * 执行测试任务
 */
export function executeTestTask(
  id: number,
  options?: { parallel?: boolean; retry_failed?: boolean }
): Promise<HttpResponse<TestExecution>> {
  return request.post('/api/auto-test/task/execute', { id, ...options });
}

/**
 * 停止测试任务执行
 */
export function stopTestTask(id: number): Promise<HttpResponse<null>> {
  return request.post('/api/auto-test/task/stop', { id });
}

/**
 * 克隆测试任务
 */
export function cloneTestTask(id: number): Promise<HttpResponse<TestTask>> {
  return request.post('/api/auto-test/task/clone', { id });
}

/**
 * 获取测试任务执行历史
 */
export function getTestTaskExecutionHistory(
  id: number,
  params?: { page?: number; pageSize?: number }
): Promise<HttpResponse<TestExecutionListResponse>> {
  return request.get(`/api/auto-test/task/${id}/executions`, { params });
}

// ==================== 测试用例管理 API ====================

/**
 * 获取测试用例列表
 */
export function getTestCaseList(
  params: TestCaseListParams
): Promise<HttpResponse<TestCaseListResponse>> {
  return request.get('/api/auto-test/case/list', { params });
}

/**
 * 获取测试用例详情
 */
export function getTestCaseDetail(id: number): Promise<HttpResponse<TestCase>> {
  return request.get('/api/auto-test/case/detail', { params: { id } });
}

/**
 * 创建测试用例
 */
export function createTestCase(
  data: CreateTestCaseParams
): Promise<HttpResponse<TestCase>> {
  return request.post('/api/auto-test/case/create', data);
}

/**
 * 批量创建测试用例
 */
export function batchCreateTestCase(
  cases: CreateTestCaseParams[]
): Promise<HttpResponse<TestCase[]>> {
  return request.post('/api/auto-test/case/batch-create', { cases });
}

/**
 * 更新测试用例
 */
export function updateTestCase(
  id: number,
  data: Partial<CreateTestCaseParams>
): Promise<HttpResponse<TestCase>> {
  return request.post('/api/auto-test/case/update', { id, ...data });
}

/**
 * 删除测试用例
 */
export function deleteTestCase(id: number): Promise<HttpResponse<null>> {
  return request.delete('/api/auto-test/case/delete', { params: { id } });
}

/**
 * 运行单个测试用例
 */
export function runTestCase(
  params: RunTestCaseParams
): Promise<HttpResponse<TestCaseResult>> {
  return request.post('/api/auto-test/case/run', params);
}

/**
 * 批量运行测试用例
 */
export function batchRunTestCase(
  caseIds: number[],
  options?: { parallel?: boolean }
): Promise<HttpResponse<TestExecution>> {
  return request.post('/api/auto-test/case/batch-run', { caseIds, ...options });
}

/**
 * 导入测试用例
 */
export function importTestCases(
  file: File,
  options?: { test_suite_id?: number }
): Promise<HttpResponse<{ success_count: number; fail_count: number }>> {
  const formData = new FormData();
  formData.append('file', file);
  if (options?.test_suite_id) {
    formData.append('test_suite_id', String(options.test_suite_id));
  }
  return request.post('/api/auto-test/case/import', formData, {
    headers: { 'Content-Type': 'multipart/form-data' },
  });
}

/**
 * 导出测试用例
 */
export function exportTestCases(
  params: { ids?: number[]; test_suite_id?: number; format?: 'json' | 'excel' }
): Promise<HttpResponse<Blob>> {
  return request.get('/api/auto-test/case/export', {
    params,
    responseType: 'blob',
  });
}

// ==================== 测试套件管理 API ====================

/**
 * 获取测试套件列表
 */
export function getTestSuiteList(): Promise<
  HttpResponse<{ list: TestSuite[]; total: number }>
> {
  return request.get('/api/auto-test/suite/list');
}

/**
 * 获取测试套件详情
 */
export function getTestSuiteDetail(
  id: number
): Promise<HttpResponse<TestSuite & { cases: TestCase[] }>> {
  return request.get('/api/auto-test/suite/detail', { params: { id } });
}

/**
 * 创建测试套件
 */
export function createTestSuite(
  data: { name: string; description?: string; module_id?: number }
): Promise<HttpResponse<TestSuite>> {
  return request.post('/api/auto-test/suite/create', data);
}

/**
 * 更新测试套件
 */
export function updateTestSuite(
  id: number,
  data: Partial<{ name: string; description: string; module_id: number }>
): Promise<HttpResponse<TestSuite>> {
  return request.post('/api/auto-test/suite/update', { id, ...data });
}

/**
 * 删除测试套件
 */
export function deleteTestSuite(id: number): Promise<HttpResponse<null>> {
  return request.delete('/api/auto-test/suite/delete', { params: { id } });
}

/**
 * 向测试套件添加用例
 */
export function addCasesToSuite(
  suiteId: number,
  caseIds: number[]
): Promise<HttpResponse<null>> {
  return request.post('/api/auto-test/suite/add-cases', { suiteId, caseIds });
}

/**
 * 从测试套件移除用例
 */
export function removeCasesFromSuite(
  suiteId: number,
  caseIds: number[]
): Promise<HttpResponse<null>> {
  return request.post('/api/auto-test/suite/remove-cases', {
    suiteId,
    caseIds,
  });
}

// ==================== Bug分析 API (核心AI接口) ====================

/**
 * AI分析Bug
 */
export function analyzeBug(
  data: AIBugAnalysisParams
): Promise<HttpResponse<AIBugAnalysisResponse>> {
  return request.post('/api/auto-test/bug/analyze', data);
}

/**
 * 获取Bug分析列表
 */
export function getBugAnalysisList(
  params: BugAnalysisListParams
): Promise<HttpResponse<BugAnalysisListResponse>> {
  return request.get('/api/auto-test/bug/list', { params });
}

/**
 * 获取Bug分析详情
 */
export function getBugAnalysisDetail(
  id: number
): Promise<HttpResponse<BugAnalysis>> {
  return request.get('/api/auto-test/bug/detail', { params: { id } });
}

/**
 * AI自动修复Bug
 */
export function autoFixBug(
  data: AIAutoFixParams
): Promise<HttpResponse<AIAutoFixResponse>> {
  return request.post('/api/auto-test/bug/auto-fix', data);
}

/**
 * AI验证修复结果
 */
export function verifyBugFix(
  bugAnalysisId: number,
  testExecutionId?: number
): Promise<HttpResponse<{ passed: boolean; details: string }>> {
  return request.post('/api/auto-test/bug/verify-fix', {
    bug_analysis_id: bugAnalysisId,
    test_execution_id: testExecutionId,
  });
}

/**
 * 更新Bug状态
 */
export function updateBugStatus(
  id: number,
  status: string,
  remark?: string
): Promise<HttpResponse<null>> {
  return request.post('/api/auto-test/bug/update-status', { id, status, remark });
}

/**
 * 同步Bug到Feedback系统
 */
export function syncBugToFeedback(
  bugAnalysisId: number,
  options?: {
    create_as?: 'bug' | 'issue';
    assign_to?: number;
  }
): Promise<HttpResponse<{ feedback_id: number }>> {
  return request.post('/api/auto-test/bug/create-feedback', {
    bug_analysis_id: bugAnalysisId,
    ...options,
  });
}

// ==================== 测试执行 API ====================

/**
 * 获取执行记录列表
 */
export function getTestExecutionList(
  params: TestExecutionListParams
): Promise<HttpResponse<TestExecutionListResponse>> {
  return request.get('/api/auto-test/execution/list', { params });
}

/**
 * 获取执行记录详情
 */
export function getTestExecutionDetail(
  id: number
): Promise<HttpResponse<TestExecution>> {
  return request.get('/api/auto-test/execution/detail', { params: { id } });
}

/**
 * 获取执行日志
 */
export function getExecutionLogs(
  executionId: number,
  params?: { cursor?: string; limit?: number }
): Promise<HttpResponse<{ logs: ExecutionLog[]; next_cursor?: string }>> {
  return request.get(`/api/auto-test/execution/${executionId}/logs`, { params });
}

/**
 * 获取执行结果统计
 */
export function getExecutionStats(
  executionId: number
): Promise<HttpResponse<TestResult>> {
  return request.get(`/api/auto-test/execution/${executionId}/stats`);
}

// ==================== 测试报告 API ====================

/**
 * 获取报告列表
 */
export function getTestReportList(
  params?: {
    type?: string;
    test_task_id?: number;
    page?: number;
    pageSize?: number;
  }
): Promise<HttpResponse<TestReportListResponse>> {
  return request.get('/api/auto-test/report/list', { params });
}

/**
 * 获取报告详情
 */
export function getTestReportDetail(id: number): Promise<HttpResponse<TestReport>> {
  return request.get('/api/auto-test/report/detail', { params: { id } });
}

/**
 * 生成报告
 */
export function generateTestReport(
  data: {
    test_execution_id?: number;
    test_task_id?: number;
    type: string;
    format: string;
  }
): Promise<HttpResponse<TestReport>> {
  return request.post('/api/auto-test/report/generate', data);
}

/**
 * 下载报告
 */
export function downloadTestReport(
  id: number,
  format?: 'pdf' | 'html' | 'excel'
): Promise<HttpResponse<Blob>> {
  return request.get('/api/auto-test/report/download', {
    params: { id, format },
    responseType: 'blob',
  });
}

/**
 * 获取趋势数据
 */
export function getTestTrendData(
  params?: {
    start_date?: string;
    end_date?: string;
    test_task_id?: number;
    metric_type?: 'pass_rate' | 'execution_count' | 'avg_duration';
  }
): Promise<
  HttpResponse<{
    trend_data: Array<{ date: string; value: number }>;
    summary: { total: number; avg: number; max: number; min: number };
  }>
> {
  return request.get('/api/auto-test/report/trend', { params });
}

// ==================== AI Agent 接口 (核心) ====================

/**
 * AI执行测试任务
 */
export function aiExecuteTestTask(
  data: AIExecuteTaskParams
): Promise<HttpResponse<{ execution_id: number; status: string }>> {
  return request.post('/api/auto-test/ai/execute-task', data);
}

/**
 * AI生成测试用例
 */
export function aiGenerateTestCases(
  data: AIGenerateTestCaseParams
): Promise<HttpResponse<AIGenerateCaseResponse>> {
  return request.post('/api/auto-test/ai/generate-cases', data);
}

/**
 * AI分析Bug
 */
export function aiAnalyzeBug(
  data: AIBugAnalysisParams
): Promise<HttpResponse<AIBugAnalysisResponse>> {
  return request.post('/api/auto-test/ai/analyze-bug', data);
}

/**
 * AI自动修复
 */
export function aiAutoFix(
  data: AIAutoFixParams
): Promise<HttpResponse<AIAutoFixResponse>> {
  return request.post('/api/auto-test/ai/auto-fix', data);
}

/**
 * AI验证修复
 */
export function aiVerifyFix(
  data: { bug_analysis_id: number }
): Promise<HttpResponse<{ passed: boolean; details: string }>> {
  return request.post('/api/auto-test/ai/verify-fix', data);
}

/**
 * AI服务健康检查
 */
export function aiHealthCheck(): Promise<
  HttpResponse<{
    status: 'healthy' | 'degraded' | 'unhealthy';
    latency_ms: number;
    queue_size: number;
  }>
> {
  return request.get('/api/auto-test/ai/health-check');
}

// ==================== 测试模块管理 API ====================

/**
 * 获取模块列表
 */
export function getTestModuleList(): Promise<
  HttpResponse<{ list: Array<{ id: number; name: string; parent_id?: number }> }>
> {
  return request.get('/api/auto-test/module/list');
}

/**
 * 创建测试模块
 */
export function createTestModule(
  data: { name: string; parent_id?: number }
): Promise<HttpResponse<{ id: number }>> {
  return request.post('/api/auto-test/module/create', data);
}

/**
 * 删除测试模块
 */
export function deleteTestModule(id: number): Promise<HttpResponse<null>> {
  return request.delete('/api/auto-test/module/delete', { params: { id } });
}
