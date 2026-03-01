/**
 * 质量中心 API 封装
 * 融合自动化测试与反馈系统的统一接口层
 */
import request from './request';
import type {
  QualityOverview,
  QualityTrend,
  ModuleQualityItem,
  BugTypeDistribution,
  FeedbackStatusDistribution,
  FeedbackToTestTaskParams,
  FeedbackToTestTaskResponse,
  BugToFeedbackParams,
  BugToFeedbackResponse,
  LinkRecord,
  ActivityRecord,
  AIQualityInsight,
} from '@/types/quality-center';

/** 通用响应类型 */
interface ApiResponse<T> {
  code: number;
  msg: string;
  data: T;
}

// ==================== Dashboard 统计 API ====================

/** 获取质量概览统计 */
export function getQualityOverview(): Promise<ApiResponse<QualityOverview>> {
  return request.get('/api/quality-center/overview');
}

/** 获取质量趋势数据 */
export function getQualityTrend(
  params?: { period?: 'week' | 'month' | 'quarter' }
): Promise<ApiResponse<QualityTrend>> {
  return request.get('/api/quality-center/trend', { params });
}

/** 获取模块质量分布 */
export function getModuleQuality(): Promise<ApiResponse<{ list: ModuleQualityItem[] }>> {
  return request.get('/api/quality-center/module-quality');
}

/** 获取Bug类型分布 */
export function getBugTypeDistribution(): Promise<ApiResponse<{ list: BugTypeDistribution[] }>> {
  return request.get('/api/quality-center/bug-distribution');
}

/** 获取反馈状态分布 */
export function getFeedbackStatusDistribution(): Promise<ApiResponse<{ list: FeedbackStatusDistribution[] }>> {
  return request.get('/api/quality-center/feedback-distribution');
}

// ==================== 反馈与测试联动 API ====================

/** 反馈转测试任务 */
export function feedbackToTestTask(
  data: FeedbackToTestTaskParams
): Promise<ApiResponse<FeedbackToTestTaskResponse>> {
  return request.post('/api/quality-center/feedback-to-task', data);
}

/** Bug同步到反馈 */
export function bugToFeedback(
  data: BugToFeedbackParams
): Promise<ApiResponse<BugToFeedbackResponse>> {
  return request.post('/api/quality-center/bug-to-feedback', data);
}

/** 获取关联记录列表 */
export function getLinkRecords(
  params?: { source_type?: string; source_id?: number; page?: number; pageSize?: number }
): Promise<ApiResponse<{ list: LinkRecord[]; total: number }>> {
  return request.get('/api/quality-center/link-records', { params });
}

// ==================== 活动流 API ====================

/** 获取最近活动记录 */
export function getRecentActivities(
  params?: { limit?: number; type?: string }
): Promise<ApiResponse<{ list: ActivityRecord[] }>> {
  return request.get('/api/quality-center/activities', { params });
}

// ==================== AI 洞察 API ====================

/** 获取AI质量洞察 */
export function getAIInsights(): Promise<ApiResponse<{ list: AIQualityInsight[] }>> {
  return request.get('/api/quality-center/ai-insights');
}
