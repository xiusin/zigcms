/**
 * 质量中心 API 客户端
 * 
 * 功能：
 * - 测试用例管理
 * - AI 自动生成
 * - 项目管理
 * - 模块管理
 * - 需求管理
 * - 反馈管理
 * - 数据可视化
 */

import axios, { AxiosInstance, AxiosError } from 'axios';
import type {
  // 实体类型
  TestCase,
  TestExecution,
  Project,
  Module,
  Requirement,
  Feedback,
  
  // DTO 类型
  CreateTestCaseDto,
  UpdateTestCaseDto,
  ExecuteTestCaseDto,
  BatchUpdateStatusDto,
  BatchUpdateAssigneeDto,
  CreateProjectDto,
  UpdateProjectDto,
  CreateModuleDto,
  UpdateModuleDto,
  MoveModuleDto,
  CreateRequirementDto,
  UpdateRequirementDto,
  LinkTestCaseDto,
  CreateFeedbackDto,
  UpdateFeedbackDto,
  AddFollowUpDto,
  AIGenerateTestCasesDto,
  AIGenerateRequirementDto,
  AIAnalyzeFeedbackDto,
  
  // 查询参数类型
  SearchTestCasesQuery,
  SearchRequirementsQuery,
  SearchFeedbacksQuery,
  StatisticsQuery,
  
  // 响应类型
  PageResult,
  ProjectStatistics,
  ModuleStatistics,
  ModuleDistribution,
  BugDistribution,
  FeedbackDistribution,
  QualityTrendPoint,
  AIGenerateResponse,
  GeneratedRequirement,
  FeedbackAnalysis,
  ModuleTreeNode,
} from '@/types/quality-center';

// ==================== 配置 ====================

const BASE_URL = '/api/quality';

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
    // 网络错误，可重试
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

class QualityCenterAPI {
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
        // 添加认证 token
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
        // 统一错误处理
        if (error.response) {
          const { status, data } = error.response;
          
          switch (status) {
            case 401:
              // 未登录，跳转到登录页
              window.location.href = '/login';
              break;
            case 403:
              // 无权限
              console.error('无权限访问');
              break;
            case 404:
              // 资源不存在
              console.error('资源不存在');
              break;
            case 500:
              // 服务器错误
              console.error('服务器内部错误');
              break;
          }
          
          return Promise.reject(data || error.message);
        }
        
        // 网络错误
        return Promise.reject(error.message || '网络错误');
      }
    );
  }

  // ==================== 测试用例管理 ====================

  /**
   * 创建测试用例
   */
  async createTestCase(dto: CreateTestCaseDto): Promise<TestCase> {
    return requestWithRetry(() =>
      this.client.post<any, TestCase>('/test-cases', dto)
    );
  }

  /**
   * 获取测试用例详情
   */
  async getTestCase(id: number): Promise<TestCase> {
    return requestWithRetry(() =>
      this.client.get<any, TestCase>(`/test-cases/${id}`)
    );
  }

  /**
   * 更新测试用例
   */
  async updateTestCase(id: number, dto: UpdateTestCaseDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.put<any, void>(`/test-cases/${id}`, dto)
    );
  }

  /**
   * 删除测试用例
   */
  async deleteTestCase(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/test-cases/${id}`)
    );
  }

  /**
   * 搜索测试用例
   */
  async searchTestCases(query: SearchTestCasesQuery): Promise<PageResult<TestCase>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<TestCase>>('/test-cases', { params: query })
    );
  }

  /**
   * 批量删除测试用例
   */
  async batchDeleteTestCases(ids: number[]): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>('/test-cases/batch-delete', { ids })
    );
  }

  /**
   * 批量更新测试用例状态
   */
  async batchUpdateTestCaseStatus(dto: BatchUpdateStatusDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>('/test-cases/batch-update-status', dto)
    );
  }

  /**
   * 批量分配测试用例负责人
   */
  async batchUpdateTestCaseAssignee(dto: BatchUpdateAssigneeDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>('/test-cases/batch-update-assignee', dto)
    );
  }

  /**
   * 执行测试用例
   */
  async executeTestCase(id: number, dto: ExecuteTestCaseDto): Promise<TestExecution> {
    return requestWithRetry(() =>
      this.client.post<any, TestExecution>(`/test-cases/${id}/execute`, dto)
    );
  }

  /**
   * 获取测试用例执行历史
   */
  async getTestCaseExecutions(id: number): Promise<TestExecution[]> {
    return requestWithRetry(() =>
      this.client.get<any, TestExecution[]>(`/test-cases/${id}/executions`)
    );
  }

  // ==================== AI 生成 ====================

  /**
   * AI 生成测试用例
   */
  async generateTestCases(dto: AIGenerateTestCasesDto): Promise<AIGenerateResponse> {
    return requestWithRetry(() =>
      this.client.post<any, AIGenerateResponse>('/ai/generate-test-cases', dto)
    );
  }

  /**
   * AI 生成需求
   */
  async generateRequirement(dto: AIGenerateRequirementDto): Promise<GeneratedRequirement> {
    return requestWithRetry(() =>
      this.client.post<any, GeneratedRequirement>('/ai/generate-requirement', dto)
    );
  }

  /**
   * AI 分析反馈
   */
  async analyzeFeedback(dto: AIAnalyzeFeedbackDto): Promise<FeedbackAnalysis> {
    return requestWithRetry(() =>
      this.client.post<any, FeedbackAnalysis>('/ai/analyze-feedback', dto)
    );
  }

  // ==================== 项目管理 ====================

  /**
   * 创建项目
   */
  async createProject(dto: CreateProjectDto): Promise<Project> {
    return requestWithRetry(() =>
      this.client.post<any, Project>('/projects', dto)
    );
  }

  /**
   * 获取项目详情
   */
  async getProject(id: number): Promise<Project> {
    return requestWithRetry(() =>
      this.client.get<any, Project>(`/projects/${id}`)
    );
  }

  /**
   * 更新项目
   */
  async updateProject(id: number, dto: UpdateProjectDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.put<any, void>(`/projects/${id}`, dto)
    );
  }

  /**
   * 删除项目
   */
  async deleteProject(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/projects/${id}`)
    );
  }

  /**
   * 获取项目列表
   */
  async getProjects(): Promise<PageResult<Project>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<Project>>('/projects')
    );
  }

  /**
   * 归档项目
   */
  async archiveProject(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>(`/projects/${id}/archive`)
    );
  }

  /**
   * 恢复项目
   */
  async restoreProject(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>(`/projects/${id}/restore`)
    );
  }

  /**
   * 获取项目统计数据
   */
  async getProjectStatistics(id: number): Promise<ProjectStatistics> {
    return requestWithRetry(() =>
      this.client.get<any, ProjectStatistics>(`/projects/${id}/statistics`)
    );
  }

  // ==================== 模块管理 ====================

  /**
   * 创建模块
   */
  async createModule(dto: CreateModuleDto): Promise<Module> {
    return requestWithRetry(() =>
      this.client.post<any, Module>('/modules', dto)
    );
  }

  /**
   * 获取模块详情
   */
  async getModule(id: number): Promise<Module> {
    return requestWithRetry(() =>
      this.client.get<any, Module>(`/modules/${id}`)
    );
  }

  /**
   * 更新模块
   */
  async updateModule(id: number, dto: UpdateModuleDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.put<any, void>(`/modules/${id}`, dto)
    );
  }

  /**
   * 删除模块
   */
  async deleteModule(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/modules/${id}`)
    );
  }

  /**
   * 获取模块树
   */
  async getModuleTree(projectId: number): Promise<ModuleTreeNode[]> {
    return requestWithRetry(() =>
      this.client.get<any, ModuleTreeNode[]>('/modules/tree', {
        params: { project_id: projectId },
      })
    );
  }

  /**
   * 移动模块
   */
  async moveModule(id: number, dto: MoveModuleDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>(`/modules/${id}/move`, dto)
    );
  }

  /**
   * 获取模块统计数据
   */
  async getModuleStatistics(id: number): Promise<ModuleStatistics> {
    return requestWithRetry(() =>
      this.client.get<any, ModuleStatistics>(`/modules/${id}/statistics`)
    );
  }

  // ==================== 需求管理 ====================

  /**
   * 创建需求
   */
  async createRequirement(dto: CreateRequirementDto): Promise<Requirement> {
    return requestWithRetry(() =>
      this.client.post<any, Requirement>('/requirements', dto)
    );
  }

  /**
   * 获取需求详情
   */
  async getRequirement(id: number): Promise<Requirement> {
    return requestWithRetry(() =>
      this.client.get<any, Requirement>(`/requirements/${id}`)
    );
  }

  /**
   * 更新需求
   */
  async updateRequirement(id: number, dto: UpdateRequirementDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.put<any, void>(`/requirements/${id}`, dto)
    );
  }

  /**
   * 删除需求
   */
  async deleteRequirement(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/requirements/${id}`)
    );
  }

  /**
   * 搜索需求
   */
  async searchRequirements(query: SearchRequirementsQuery): Promise<PageResult<Requirement>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<Requirement>>('/requirements', { params: query })
    );
  }

  /**
   * 关联测试用例
   */
  async linkTestCase(id: number, dto: LinkTestCaseDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>(`/requirements/${id}/link-test-case`, dto)
    );
  }

  /**
   * 取消关联测试用例
   */
  async unlinkTestCase(id: number, caseId: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/requirements/${id}/unlink-test-case/${caseId}`)
    );
  }

  /**
   * 导入需求
   */
  async importRequirements(file: File): Promise<void> {
    const formData = new FormData();
    formData.append('file', file);
    
    return requestWithRetry(() =>
      this.client.post<any, void>('/requirements/import', formData, {
        headers: {
          'Content-Type': 'multipart/form-data',
        },
      })
    );
  }

  /**
   * 导出需求
   */
  async exportRequirements(projectId?: number): Promise<Blob> {
    return requestWithRetry(() =>
      this.client.get<any, Blob>('/requirements/export', {
        params: { project_id: projectId },
        responseType: 'blob',
      })
    );
  }

  // ==================== 反馈管理 ====================

  /**
   * 创建反馈
   */
  async createFeedback(dto: CreateFeedbackDto): Promise<Feedback> {
    return requestWithRetry(() =>
      this.client.post<any, Feedback>('/feedbacks', dto)
    );
  }

  /**
   * 获取反馈详情
   */
  async getFeedback(id: number): Promise<Feedback> {
    return requestWithRetry(() =>
      this.client.get<any, Feedback>(`/feedbacks/${id}`)
    );
  }

  /**
   * 更新反馈
   */
  async updateFeedback(id: number, dto: UpdateFeedbackDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.put<any, void>(`/feedbacks/${id}`, dto)
    );
  }

  /**
   * 删除反馈
   */
  async deleteFeedback(id: number): Promise<void> {
    return requestWithRetry(() =>
      this.client.delete<any, void>(`/feedbacks/${id}`)
    );
  }

  /**
   * 搜索反馈
   */
  async searchFeedbacks(query: SearchFeedbacksQuery): Promise<PageResult<Feedback>> {
    return requestWithRetry(() =>
      this.client.get<any, PageResult<Feedback>>('/feedbacks', { params: query })
    );
  }

  /**
   * 添加跟进记录
   */
  async addFollowUp(id: number, dto: AddFollowUpDto): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>(`/feedbacks/${id}/follow-up`, dto)
    );
  }

  /**
   * 批量指派反馈
   */
  async batchAssignFeedbacks(ids: number[], assignee: string): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>('/feedbacks/batch-assign', { ids, assignee })
    );
  }

  /**
   * 批量更新反馈状态
   */
  async batchUpdateFeedbackStatus(ids: number[], status: string): Promise<void> {
    return requestWithRetry(() =>
      this.client.post<any, void>('/feedbacks/batch-update-status', { ids, status })
    );
  }

  /**
   * 导出反馈
   */
  async exportFeedbacks(query?: SearchFeedbacksQuery): Promise<Blob> {
    return requestWithRetry(() =>
      this.client.get<any, Blob>('/feedbacks/export', {
        params: query,
        responseType: 'blob',
      })
    );
  }

  // ==================== 数据可视化 ====================

  /**
   * 获取总体统计数据
   */
  async getStatistics(query: StatisticsQuery): Promise<{ data: any }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: any }>('/statistics/overview', {
        params: query,
      })
    );
  }

  /**
   * 获取模块质量分布
   */
  async getModuleDistribution(query: StatisticsQuery): Promise<{ data: ModuleDistribution[] }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: ModuleDistribution[] }>('/statistics/module-distribution', {
        params: query,
      })
    );
  }

  /**
   * 获取 Bug 质量分布
   */
  async getBugDistribution(query: StatisticsQuery): Promise<{ data: BugDistribution[] }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: BugDistribution[] }>('/statistics/bug-distribution', {
        params: query,
      })
    );
  }

  /**
   * 获取反馈状态分布
   */
  async getFeedbackDistribution(query: StatisticsQuery): Promise<{ data: FeedbackDistribution[] }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: FeedbackDistribution[] }>('/statistics/feedback-distribution', {
        params: query,
      })
    );
  }

  /**
   * 获取质量趋势
   */
  async getQualityTrend(query: StatisticsQuery): Promise<{ data: QualityTrendPoint[] }> {
    return requestWithRetry(() =>
      this.client.get<any, { data: QualityTrendPoint[] }>('/statistics/quality-trend', {
        params: query,
      })
    );
  }

  /**
   * 导出图表
   */
  async exportChart(
    chartType: string,
    format: 'png' | 'svg' | 'pdf',
    query?: StatisticsQuery
  ): Promise<Blob> {
    return requestWithRetry(() =>
      this.client.get<any, Blob>('/statistics/export', {
        params: { chart_type: chartType, format, ...query },
        responseType: 'blob',
      })
    );
  }
}

// ==================== 导出单例 ====================

export const qualityCenterApi = new QualityCenterAPI();

export default qualityCenterApi;

// ==================== 导出便捷函数 ====================

// 测试用例
export const createTestCase = qualityCenterApi.createTestCase.bind(qualityCenterApi);
export const getTestCase = qualityCenterApi.getTestCase.bind(qualityCenterApi);
export const updateTestCase = qualityCenterApi.updateTestCase.bind(qualityCenterApi);
export const deleteTestCase = qualityCenterApi.deleteTestCase.bind(qualityCenterApi);
export const searchTestCases = qualityCenterApi.searchTestCases.bind(qualityCenterApi);
export const batchDeleteTestCases = qualityCenterApi.batchDeleteTestCases.bind(qualityCenterApi);
export const batchUpdateTestCaseStatus = qualityCenterApi.batchUpdateTestCaseStatus.bind(qualityCenterApi);
export const batchUpdateTestCaseAssignee = qualityCenterApi.batchUpdateTestCaseAssignee.bind(qualityCenterApi);
export const executeTestCase = qualityCenterApi.executeTestCase.bind(qualityCenterApi);
export const getTestCaseExecutions = qualityCenterApi.getTestCaseExecutions.bind(qualityCenterApi);

// AI 生成
export const generateTestCases = qualityCenterApi.generateTestCases.bind(qualityCenterApi);
export const generateRequirement = qualityCenterApi.generateRequirement.bind(qualityCenterApi);
export const analyzeFeedback = qualityCenterApi.analyzeFeedback.bind(qualityCenterApi);

// 项目管理
export const createProject = qualityCenterApi.createProject.bind(qualityCenterApi);
export const getProject = qualityCenterApi.getProject.bind(qualityCenterApi);
export const updateProject = qualityCenterApi.updateProject.bind(qualityCenterApi);
export const deleteProject = qualityCenterApi.deleteProject.bind(qualityCenterApi);
export const getProjects = qualityCenterApi.getProjects.bind(qualityCenterApi);
export const archiveProject = qualityCenterApi.archiveProject.bind(qualityCenterApi);
export const restoreProject = qualityCenterApi.restoreProject.bind(qualityCenterApi);
export const getProjectStatistics = qualityCenterApi.getProjectStatistics.bind(qualityCenterApi);

// 模块管理
export const createModule = qualityCenterApi.createModule.bind(qualityCenterApi);
export const getModule = qualityCenterApi.getModule.bind(qualityCenterApi);
export const updateModule = qualityCenterApi.updateModule.bind(qualityCenterApi);
export const deleteModule = qualityCenterApi.deleteModule.bind(qualityCenterApi);
export const getModuleTree = qualityCenterApi.getModuleTree.bind(qualityCenterApi);
export const moveModule = qualityCenterApi.moveModule.bind(qualityCenterApi);
export const getModuleStatistics = qualityCenterApi.getModuleStatistics.bind(qualityCenterApi);

// 需求管理
export const createRequirement = qualityCenterApi.createRequirement.bind(qualityCenterApi);
export const getRequirement = qualityCenterApi.getRequirement.bind(qualityCenterApi);
export const updateRequirement = qualityCenterApi.updateRequirement.bind(qualityCenterApi);
export const deleteRequirement = qualityCenterApi.deleteRequirement.bind(qualityCenterApi);
export const searchRequirements = qualityCenterApi.searchRequirements.bind(qualityCenterApi);
export const linkTestCase = qualityCenterApi.linkTestCase.bind(qualityCenterApi);
export const unlinkTestCase = qualityCenterApi.unlinkTestCase.bind(qualityCenterApi);
export const importRequirements = qualityCenterApi.importRequirements.bind(qualityCenterApi);
export const exportRequirements = qualityCenterApi.exportRequirements.bind(qualityCenterApi);

// 反馈管理
export const createFeedback = qualityCenterApi.createFeedback.bind(qualityCenterApi);
export const getFeedbackById = qualityCenterApi.getFeedback.bind(qualityCenterApi);
export const updateFeedback = qualityCenterApi.updateFeedback.bind(qualityCenterApi);
export const deleteFeedback = qualityCenterApi.deleteFeedback.bind(qualityCenterApi);
export const searchFeedbacks = qualityCenterApi.searchFeedbacks.bind(qualityCenterApi);
export const addFeedbackFollowUp = qualityCenterApi.addFollowUp.bind(qualityCenterApi);
export const batchAssignFeedbacks = qualityCenterApi.batchAssignFeedbacks.bind(qualityCenterApi);
export const batchUpdateFeedbackStatus = qualityCenterApi.batchUpdateFeedbackStatus.bind(qualityCenterApi);
export const exportFeedbacks = qualityCenterApi.exportFeedbacks.bind(qualityCenterApi);

// 数据可视化
export const getStatistics = qualityCenterApi.getStatistics.bind(qualityCenterApi);
export const getModuleDistribution = qualityCenterApi.getModuleDistribution.bind(qualityCenterApi);
export const getBugDistribution = qualityCenterApi.getBugDistribution.bind(qualityCenterApi);
export const getFeedbackDistribution = qualityCenterApi.getFeedbackDistribution.bind(qualityCenterApi);
export const getQualityTrend = qualityCenterApi.getQualityTrend.bind(qualityCenterApi);
export const exportChart = qualityCenterApi.exportChart.bind(qualityCenterApi);

// ==================== 额外的便捷函数（别名和扩展） ====================

/**
 * 获取质量总览（别名）
 */
export const getQualityOverview = getStatistics;

/**
 * 获取模块质量（别名）
 */
export const getModuleQuality = getModuleDistribution;

/**
 * 获取 Bug 类型分布（别名）
 */
export const getBugTypeDistribution = getBugDistribution;

/**
 * 获取反馈状态分布（别名）
 */
export const getFeedbackStatusDistribution = getFeedbackDistribution;

/**
 * 批量删除反馈
 */
export async function batchDeleteFeedbacks(ids: number[]): Promise<void> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/feedbacks/batch-delete', { ids })
  );
}

/**
 * 更新反馈状态
 */
export async function updateFeedbackStatus(id: number, status: string): Promise<void> {
  return requestWithRetry(() =>
    qualityCenterApi.client.put(`/feedbacks/${id}/status`, { status })
  );
}

/**
 * 添加反馈评论
 */
export async function addFeedbackComment(
  feedbackId: number,
  comment: { content: string; attachments: any[] }
): Promise<void> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post(`/feedbacks/${feedbackId}/comments`, comment)
  );
}

/**
 * 回复反馈评论
 */
export async function replyFeedbackComment(
  feedbackId: number,
  commentId: number,
  reply: { content: string; reply_to?: string }
): Promise<void> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post(`/feedbacks/${feedbackId}/comments/${commentId}/reply`, reply)
  );
}

/**
 * 编辑反馈评论
 */
export async function editFeedbackComment(
  feedbackId: number,
  commentId: number,
  content: string
): Promise<void> {
  return requestWithRetry(() =>
    qualityCenterApi.client.put(`/feedbacks/${feedbackId}/comments/${commentId}`, { content })
  );
}

/**
 * 删除反馈评论
 */
export async function deleteFeedbackComment(
  feedbackId: number,
  commentId: number
): Promise<void> {
  return requestWithRetry(() =>
    qualityCenterApi.client.delete(`/feedbacks/${feedbackId}/comments/${commentId}`)
  );
}

/**
 * 反馈转测试任务
 */
export async function feedbackToTestTask(params: { feedback_id: number; [key: string]: any }): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/feedbacks/to-task', params)
  );
}

/**
 * Bug 同步到反馈
 */
export async function bugToFeedback(params: { bug_analysis_id: number; [key: string]: any }): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/bugs/to-feedback', params)
  );
}

/**
 * 获取关联记录
 */
export async function getLinkRecords(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/links', { params })
  );
}

/**
 * 获取最近活动
 */
export async function getRecentActivities(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/activities/recent', { params })
  );
}

/**
 * 获取 AI 洞察
 */
export async function getAIInsights(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/ai/insights', { params })
  );
}

/**
 * 获取定时报告列表
 */
export async function getScheduledReports(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/reports/scheduled', { params })
  );
}

/**
 * 创建定时报告
 */
export async function createScheduledReport(data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/reports/scheduled', data)
  );
}

/**
 * 更新定时报告
 */
export async function updateScheduledReport(id: number, data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.put(`/reports/scheduled/${id}`, data)
  );
}

/**
 * 删除定时报告
 */
export async function deleteScheduledReport(id: number): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.delete(`/reports/scheduled/${id}`)
  );
}

/**
 * 切换定时报告状态
 */
export async function toggleScheduledReport(id: number): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post(`/reports/scheduled/${id}/toggle`)
  );
}

/**
 * 触发定时报告
 */
export async function triggerScheduledReport(id: number): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post(`/reports/scheduled/${id}/trigger`)
  );
}

/**
 * 获取报告历史
 */
export async function getReportHistory(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/reports/history', { params })
  );
}

/**
 * 获取 Bug 关联数据
 */
export async function getBugLinkData(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/bugs/links', { params })
  );
}

/**
 * 获取反馈分类
 */
export async function getFeedbackClassification(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/feedbacks/classification', { params })
  );
}

/**
 * 获取报告模板列表
 */
export async function getReportTemplates(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/reports/templates', { params })
  );
}

/**
 * 创建报告模板
 */
export async function createReportTemplate(data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/reports/templates', data)
  );
}

/**
 * 更新报告模板
 */
export async function updateReportTemplate(id: number, data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.put(`/reports/templates/${id}`, data)
  );
}

/**
 * 删除报告模板
 */
export async function deleteReportTemplate(id: number): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.delete(`/reports/templates/${id}`)
  );
}

/**
 * 获取邮件模板列表
 */
export async function getEmailTemplates(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/email/templates', { params })
  );
}

/**
 * 创建邮件模板
 */
export async function createEmailTemplate(data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/email/templates', data)
  );
}

/**
 * 更新邮件模板
 */
export async function updateEmailTemplate(id: number, data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.put(`/email/templates/${id}`, data)
  );
}

/**
 * 删除邮件模板
 */
export async function deleteEmailTemplate(id: number): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.delete(`/email/templates/${id}`)
  );
}

/**
 * 预览邮件模板
 */
export async function previewEmailTemplate(id: number, data?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post(`/email/templates/${id}/preview`, data)
  );
}

/**
 * 请求 AI 分析
 */
export async function requestAIAnalysis(data: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.post('/ai/analysis', data)
  );
}

/**
 * 获取 AI 分析历史
 */
export async function getAIAnalysisHistory(params?: any): Promise<any> {
  return requestWithRetry(() =>
    qualityCenterApi.client.get('/ai/analysis/history', { params })
  );
}

// ==================== 报表相关 API ====================

/**
 * 生成测试用例报表
 */
export async function generateTestCaseReport(params: {
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<{ data: import('@/types/quality-report').TestCaseStats }> {
  return axios.get('/api/quality-center/reports/test-case', { params });
}

/**
 * 生成反馈报表
 */
export async function generateFeedbackReport(params: {
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<{ data: import('@/types/quality-report').FeedbackStats }> {
  return axios.get('/api/quality-center/reports/feedback', { params });
}

/**
 * 生成需求报表
 */
export async function generateRequirementReport(params: {
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<{ data: import('@/types/quality-report').RequirementStats }> {
  return axios.get('/api/quality-center/reports/requirement', { params });
}

/**
 * 生成项目质量报表
 */
export async function generateProjectQualityReport(params: {
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<{ data: import('@/types/quality-report').ProjectQualityStats }> {
  return axios.get('/api/quality-center/reports/project-quality', { params });
}

/**
 * 导出报表（HTML）
 */
export async function exportReportHTML(params: {
  report_type: string;
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<Blob> {
  const response = await axios.get('/api/quality-center/reports/export/html', {
    params,
    responseType: 'blob',
  });
  return response.data;
}

/**
 * 导出报表（PDF）
 */
export async function exportReportPDF(params: {
  report_type: string;
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<Blob> {
  const response = await axios.get('/api/quality-center/reports/export/pdf', {
    params,
    responseType: 'blob',
  });
  return response.data;
}

/**
 * 导出报表（Excel）
 */
export async function exportReportExcel(params: {
  report_type: string;
  start_date: string;
  end_date: string;
  project_id?: number;
}): Promise<Blob> {
  const response = await axios.get('/api/quality-center/reports/export/excel', {
    params,
    responseType: 'blob',
  });
  return response.data;
}

/**
 * 下载报表文件
 */
export function downloadReport(blob: Blob, filename: string) {
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  window.URL.revokeObjectURL(url);
}
