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
  ScheduledReport,
  ScheduledReportParams,
  ReportHistory,
  BugLinkData,
  FeedbackClassification,
  ReportTemplate,
  ReportTemplateParams,
  EmailTemplate,
  EmailTemplateParams,
  AIAnalysisRequest,
  AIAnalysisResponse,
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
  return request('/api/quality-center/overview', {}, undefined, 'get');
}

/** 获取质量趋势数据 */
export function getQualityTrend(
  params?: { period?: 'week' | 'month' | 'quarter' }
): Promise<ApiResponse<QualityTrend>> {
  return request('/api/quality-center/trend', params, undefined, 'get');
}

/** 获取模块质量分布 */
export function getModuleQuality(): Promise<ApiResponse<{ list: ModuleQualityItem[] }>> {
  return request('/api/quality-center/module-quality', {}, undefined, 'get');
}

/** 获取Bug类型分布 */
export function getBugTypeDistribution(): Promise<ApiResponse<{ list: BugTypeDistribution[] }>> {
  return request('/api/quality-center/bug-distribution', {}, undefined, 'get');
}

/** 获取反馈状态分布 */
export function getFeedbackStatusDistribution(): Promise<ApiResponse<{ list: FeedbackStatusDistribution[] }>> {
  return request('/api/quality-center/feedback-distribution', {}, undefined, 'get');
}

// ==================== 反馈与测试联动 API ====================

/** 反馈转测试任务 */
export function feedbackToTestTask(
  data: FeedbackToTestTaskParams
): Promise<ApiResponse<FeedbackToTestTaskResponse>> {
  return request('/api/quality-center/feedback-to-task', data, undefined, 'post');
}

/** Bug同步到反馈 */
export function bugToFeedback(
  data: BugToFeedbackParams
): Promise<ApiResponse<BugToFeedbackResponse>> {
  return request('/api/quality-center/bug-to-feedback', data, undefined, 'post');
}

/** 获取关联记录列表 */
export function getLinkRecords(
  params?: { source_type?: string; source_id?: number; page?: number; pageSize?: number }
): Promise<ApiResponse<{ list: LinkRecord[]; total: number }>> {
  return request('/api/quality-center/link-records', params, undefined, 'get');
}

// ==================== 活动流 API ====================

/** 获取最近活动记录 */
export function getRecentActivities(
  params?: { limit?: number; type?: string }
): Promise<ApiResponse<{ list: ActivityRecord[] }>> {
  return request('/api/quality-center/activities', params, undefined, 'get');
}

// ==================== AI 洞察 API ====================

/** 获取AI质量洞察 */
export function getAIInsights(): Promise<ApiResponse<{ list: AIQualityInsight[] }>> {
  return request('/api/quality-center/ai-insights', {}, undefined, 'get');
}

// ==================== 定时报表 API ====================

/** 获取定时报表列表 */
export function getScheduledReports(): Promise<ApiResponse<{ list: ScheduledReport[]; total: number }>> {
  return request('/api/quality-center/scheduled-reports', {}, undefined, 'get');
}

/** 创建定时报表 */
export function createScheduledReport(
  data: ScheduledReportParams
): Promise<ApiResponse<ScheduledReport>> {
  return request('/api/quality-center/scheduled-reports', data, undefined, 'post');
}

/** 更新定时报表 */
export function updateScheduledReport(
  id: number,
  data: Partial<ScheduledReportParams>
): Promise<ApiResponse<ScheduledReport>> {
  return request(`/api/quality-center/scheduled-reports/${id}`, data, undefined, 'post');
}

/** 删除定时报表 */
export function deleteScheduledReport(id: number): Promise<ApiResponse<null>> {
  return request(`/api/quality-center/scheduled-reports/${id}`, {}, undefined, 'post');
}

/** 切换报表启用状态 */
export function toggleScheduledReport(id: number, enabled: boolean): Promise<ApiResponse<null>> {
  return request(`/api/quality-center/scheduled-reports/${id}/toggle`, { enabled }, undefined, 'post');
}

/** 手动触发一次报表 */
export function triggerScheduledReport(id: number): Promise<ApiResponse<ReportHistory>> {
  return request(`/api/quality-center/scheduled-reports/${id}/trigger`, {}, undefined, 'post');
}

/** 获取报表执行历史 */
export function getReportHistory(
  params?: { report_id?: number; page?: number; pageSize?: number }
): Promise<ApiResponse<{ list: ReportHistory[]; total: number }>> {
  return request('/api/quality-center/report-history', params, undefined, 'get');
}

// ==================== Bug关联分析 API ====================

/** 获取Bug关联数据（脑图用） */
export function getBugLinkData(): Promise<ApiResponse<{ list: BugLinkData[] }>> {
  return request('/api/quality-center/bug-links', {}, undefined, 'get');
}

// ==================== 反馈分类分析 API ====================

/** 获取反馈分类数据（脑图用） */
export function getFeedbackClassification(): Promise<ApiResponse<{ list: FeedbackClassification[] }>> {
  return request('/api/quality-center/feedback-classification', {}, undefined, 'get');
}

// ==================== 报表模板 API ====================

/** 获取报表模板列表 */
export function getReportTemplates(): Promise<ApiResponse<{ list: ReportTemplate[] }>> {
  return request('/api/quality-center/report-templates', {}, undefined, 'get');
}

/** 创建报表模板 */
export function createReportTemplate(data: ReportTemplateParams): Promise<ApiResponse<ReportTemplate>> {
  return request('/api/quality-center/report-templates', data, undefined, 'post');
}

/** 更新报表模板 */
export function updateReportTemplate(id: number, data: Partial<ReportTemplateParams>): Promise<ApiResponse<ReportTemplate>> {
  return request(`/api/quality-center/report-templates/${id}`, data, undefined, 'post');
}

/** 删除报表模板 */
export function deleteReportTemplate(id: number): Promise<ApiResponse<null>> {
  return request(`/api/quality-center/report-templates/${id}`, {}, undefined, 'post');
}

// ==================== 邮件模板 API ====================

/** 获取邮件模板列表 */
export function getEmailTemplates(): Promise<ApiResponse<{ list: EmailTemplate[] }>> {
  return request('/api/quality-center/email-templates', {}, undefined, 'get');
}

/** 创建邮件模板 */
export function createEmailTemplate(data: EmailTemplateParams): Promise<ApiResponse<EmailTemplate>> {
  return request('/api/quality-center/email-templates', data, undefined, 'post');
}

/** 更新邮件模板 */
export function updateEmailTemplate(id: number, data: Partial<EmailTemplateParams>): Promise<ApiResponse<EmailTemplate>> {
  return request(`/api/quality-center/email-templates/${id}`, data, undefined, 'post');
}

/** 删除邮件模板 */
export function deleteEmailTemplate(id: number): Promise<ApiResponse<null>> {
  return request(`/api/quality-center/email-templates/${id}`, {}, undefined, 'post');
}

/** 预览邮件模板 */
export function previewEmailTemplate(id: number): Promise<ApiResponse<{ html: string }>> {
  return request(`/api/quality-center/email-templates/${id}/preview`, {}, undefined, 'get');
}

// ==================== AI分析 API ====================

/** 发起AI分析 */
export function requestAIAnalysis(data: AIAnalysisRequest): Promise<ApiResponse<AIAnalysisResponse>> {
  return request('/api/quality-center/ai-analysis', data, undefined, 'post');
}

/** 获取AI分析历史 */
export function getAIAnalysisHistory(params?: { type?: string; page?: number; pageSize?: number }): Promise<ApiResponse<{ list: AIAnalysisResponse[]; total: number }>> {
  return request('/api/quality-center/ai-analysis/history', params, undefined, 'get');
}
