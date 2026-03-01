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

// ==================== 定时报表 API ====================

/** 获取定时报表列表 */
export function getScheduledReports(): Promise<ApiResponse<{ list: ScheduledReport[]; total: number }>> {
  return request.get('/api/quality-center/scheduled-reports');
}

/** 创建定时报表 */
export function createScheduledReport(
  data: ScheduledReportParams
): Promise<ApiResponse<ScheduledReport>> {
  return request.post('/api/quality-center/scheduled-reports', data);
}

/** 更新定时报表 */
export function updateScheduledReport(
  id: number,
  data: Partial<ScheduledReportParams>
): Promise<ApiResponse<ScheduledReport>> {
  return request.put(`/api/quality-center/scheduled-reports/${id}`, data);
}

/** 删除定时报表 */
export function deleteScheduledReport(id: number): Promise<ApiResponse<null>> {
  return request.delete(`/api/quality-center/scheduled-reports/${id}`);
}

/** 切换报表启用状态 */
export function toggleScheduledReport(id: number, enabled: boolean): Promise<ApiResponse<null>> {
  return request.put(`/api/quality-center/scheduled-reports/${id}/toggle`, { enabled });
}

/** 手动触发一次报表 */
export function triggerScheduledReport(id: number): Promise<ApiResponse<ReportHistory>> {
  return request.post(`/api/quality-center/scheduled-reports/${id}/trigger`);
}

/** 获取报表执行历史 */
export function getReportHistory(
  params?: { report_id?: number; page?: number; pageSize?: number }
): Promise<ApiResponse<{ list: ReportHistory[]; total: number }>> {
  return request.get('/api/quality-center/report-history', { params });
}

// ==================== Bug关联分析 API ====================

/** 获取Bug关联数据（脑图用） */
export function getBugLinkData(): Promise<ApiResponse<{ list: BugLinkData[] }>> {
  return request.get('/api/quality-center/bug-links');
}

// ==================== 反馈分类分析 API ====================

/** 获取反馈分类数据（脑图用） */
export function getFeedbackClassification(): Promise<ApiResponse<{ list: FeedbackClassification[] }>> {
  return request.get('/api/quality-center/feedback-classification');
}

// ==================== 报表模板 API ====================

/** 获取报表模板列表 */
export function getReportTemplates(): Promise<ApiResponse<{ list: ReportTemplate[] }>> {
  return request.get('/api/quality-center/report-templates');
}

/** 创建报表模板 */
export function createReportTemplate(data: ReportTemplateParams): Promise<ApiResponse<ReportTemplate>> {
  return request.post('/api/quality-center/report-templates', data);
}

/** 更新报表模板 */
export function updateReportTemplate(id: number, data: Partial<ReportTemplateParams>): Promise<ApiResponse<ReportTemplate>> {
  return request.put(`/api/quality-center/report-templates/${id}`, data);
}

/** 删除报表模板 */
export function deleteReportTemplate(id: number): Promise<ApiResponse<null>> {
  return request.delete(`/api/quality-center/report-templates/${id}`);
}

// ==================== 邮件模板 API ====================

/** 获取邮件模板列表 */
export function getEmailTemplates(): Promise<ApiResponse<{ list: EmailTemplate[] }>> {
  return request.get('/api/quality-center/email-templates');
}

/** 创建邮件模板 */
export function createEmailTemplate(data: EmailTemplateParams): Promise<ApiResponse<EmailTemplate>> {
  return request.post('/api/quality-center/email-templates', data);
}

/** 更新邮件模板 */
export function updateEmailTemplate(id: number, data: Partial<EmailTemplateParams>): Promise<ApiResponse<EmailTemplate>> {
  return request.put(`/api/quality-center/email-templates/${id}`, data);
}

/** 删除邮件模板 */
export function deleteEmailTemplate(id: number): Promise<ApiResponse<null>> {
  return request.delete(`/api/quality-center/email-templates/${id}`);
}

/** 预览邮件模板 */
export function previewEmailTemplate(id: number): Promise<ApiResponse<{ html: string }>> {
  return request.get(`/api/quality-center/email-templates/${id}/preview`);
}

// ==================== AI分析 API ====================

/** 发起AI分析 */
export function requestAIAnalysis(data: AIAnalysisRequest): Promise<ApiResponse<AIAnalysisResponse>> {
  return request.post('/api/quality-center/ai-analysis', data);
}

/** 获取AI分析历史 */
export function getAIAnalysisHistory(params?: { type?: string; page?: number; pageSize?: number }): Promise<ApiResponse<{ list: AIAnalysisResponse[]; total: number }>> {
  return request.get('/api/quality-center/ai-analysis/history', { params });
}
