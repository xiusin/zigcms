/**
 * 质量中心状态管理
 * 融合自动化测试与反馈系统的统一Store
 */
import { defineStore } from 'pinia';
import {
  getQualityOverview,
  getQualityTrend,
  getModuleQuality,
  getBugTypeDistribution,
  getFeedbackStatusDistribution,
  feedbackToTestTask,
  bugToFeedback,
  getLinkRecords,
  getRecentActivities,
  getAIInsights,
  getScheduledReports,
  createScheduledReport,
  updateScheduledReport,
  deleteScheduledReport,
  toggleScheduledReport,
  triggerScheduledReport,
  getReportHistory,
  getBugLinkData,
  getFeedbackClassification,
  getReportTemplates,
  createReportTemplate,
  updateReportTemplate,
  deleteReportTemplate,
  getEmailTemplates,
  createEmailTemplate,
  updateEmailTemplate,
  deleteEmailTemplate,
  previewEmailTemplate,
  requestAIAnalysis,
  getAIAnalysisHistory,
} from '@/api/quality-center';
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
import { cachedFetch, dataCache, STALE_TIMES } from '@/utils/data-cache';
import { useWebSocket, type ReportStatusPayload, type NotificationPayload } from '@/utils/websocket';

/** 质量中心Dashboard Store */
export const useQualityCenterStore = defineStore('qualityCenter', {
  state: () => ({
    /** 质量概览数据 */
    overview: null as QualityOverview | null,
    /** 质量趋势数据 */
    trend: null as QualityTrend | null,
    /** 模块质量分布 */
    moduleQuality: [] as ModuleQualityItem[],
    /** Bug类型分布 */
    bugDistribution: [] as BugTypeDistribution[],
    /** 反馈状态分布 */
    feedbackDistribution: [] as FeedbackStatusDistribution[],
    /** 关联记录 */
    linkRecords: [] as LinkRecord[],
    linkRecordsTotal: 0,
    /** 活动流 */
    activities: [] as ActivityRecord[],
    /** AI洞察 */
    aiInsights: [] as AIQualityInsight[],
    /** 定时报表 */
    scheduledReports: [] as ScheduledReport[],
    scheduledReportsTotal: 0,
    /** 报表执行历史 */
    reportHistory: [] as ReportHistory[],
    reportHistoryTotal: 0,
    /** Bug关联数据 */
    bugLinks: [] as BugLinkData[],
    /** 反馈分类数据 */
    feedbackClassification: [] as FeedbackClassification[],
    /** 报表模板 */
    reportTemplates: [] as ReportTemplate[],
    /** 邮件模板 */
    emailTemplates: [] as EmailTemplate[],
    /** 邮件模板预览HTML */
    emailPreviewHtml: '',
    /** AI分析结果 */
    aiAnalysisResult: null as AIAnalysisResponse | null,
    /** AI分析历史 */
    aiAnalysisHistory: [] as AIAnalysisResponse[],
    /** WebSocket连接状态 */
    wsConnected: false,
    /** 实时报表状态 */
    wsReportStatus: null as ReportStatusPayload | null,
    /** 实时通知列表 */
    wsNotifications: [] as NotificationPayload[],
    /** 加载状态 */
    loading: {
      overview: false,
      trend: false,
      moduleQuality: false,
      bugDistribution: false,
      feedbackDistribution: false,
      linkRecords: false,
      activities: false,
      aiInsights: false,
      scheduledReports: false,
      reportHistory: false,
      bugLinks: false,
      feedbackClassification: false,
      reportTemplates: false,
      emailTemplates: false,
      aiAnalysis: false,
    },
    /** 操作中状态 */
    submitting: false,
  }),

  getters: {
    /** 高风险洞察 */
    highRiskInsights: (state) =>
      state.aiInsights.filter((i) => i.severity === 'high'),
    /** 今日活动数 */
    todayActivityCount: (state) => {
      const today = new Date().toISOString().slice(0, 10);
      return state.activities.filter((a) => a.created_at.startsWith(today)).length;
    },
    /** 是否有未处理的高风险洞察 */
    hasHighRiskAlerts: (state) =>
      state.aiInsights.some((i) => i.severity === 'high' && i.type === 'risk'),
  },

  actions: {
    /** 获取质量概览 */
    async fetchOverview() {
      this.loading.overview = true;
      try {
        const res = await getQualityOverview();
        this.overview = res.data;
        console.log('[质量中心][fetchOverview][成功]', res.data);
      } catch (error) {
        console.error('[质量中心][fetchOverview][失败]', error);
        throw error;
      } finally {
        this.loading.overview = false;
      }
    },

    /** 获取质量趋势 */
    async fetchTrend(period: 'week' | 'month' | 'quarter' = 'week') {
      this.loading.trend = true;
      try {
        const res = await getQualityTrend({ period });
        this.trend = res.data;
      } catch (error) {
        console.error('[质量中心][fetchTrend][失败]', error);
        throw error;
      } finally {
        this.loading.trend = false;
      }
    },

    /** 获取模块质量分布 */
    async fetchModuleQuality() {
      this.loading.moduleQuality = true;
      try {
        const res = await getModuleQuality();
        this.moduleQuality = res.data.list;
      } catch (error) {
        console.error('[质量中心][fetchModuleQuality][失败]', error);
        throw error;
      } finally {
        this.loading.moduleQuality = false;
      }
    },

    /** 获取Bug类型分布 */
    async fetchBugDistribution() {
      this.loading.bugDistribution = true;
      try {
        const res = await getBugTypeDistribution();
        this.bugDistribution = res.data.list;
      } catch (error) {
        console.error('[质量中心][fetchBugDistribution][失败]', error);
        throw error;
      } finally {
        this.loading.bugDistribution = false;
      }
    },

    /** 获取反馈状态分布 */
    async fetchFeedbackDistribution() {
      this.loading.feedbackDistribution = true;
      try {
        const res = await getFeedbackStatusDistribution();
        this.feedbackDistribution = res.data.list;
      } catch (error) {
        console.error('[质量中心][fetchFeedbackDistribution][失败]', error);
        throw error;
      } finally {
        this.loading.feedbackDistribution = false;
      }
    },

    /** 反馈转测试任务 */
    async convertFeedbackToTask(
      params: FeedbackToTestTaskParams
    ): Promise<FeedbackToTestTaskResponse> {
      this.submitting = true;
      try {
        const res = await feedbackToTestTask(params);
        console.log('[质量中心][feedbackToTask][成功]', {
          feedback_id: params.feedback_id,
          task_id: res.data.task_id,
        });
        return res.data;
      } catch (error) {
        console.error('[质量中心][feedbackToTask][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** Bug同步到反馈 */
    async convertBugToFeedback(
      params: BugToFeedbackParams
    ): Promise<BugToFeedbackResponse> {
      this.submitting = true;
      try {
        const res = await bugToFeedback(params);
        console.log('[质量中心][bugToFeedback][成功]', {
          bug_id: params.bug_analysis_id,
          feedback_id: res.data.feedback_id,
        });
        return res.data;
      } catch (error) {
        console.error('[质量中心][bugToFeedback][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 获取关联记录 */
    async fetchLinkRecords(params?: {
      source_type?: string;
      source_id?: number;
      page?: number;
      pageSize?: number;
    }) {
      this.loading.linkRecords = true;
      try {
        const res = await getLinkRecords(params);
        this.linkRecords = res.data.list;
        this.linkRecordsTotal = res.data.total;
      } catch (error) {
        console.error('[质量中心][fetchLinkRecords][失败]', error);
        throw error;
      } finally {
        this.loading.linkRecords = false;
      }
    },

    /** 获取最近活动 */
    async fetchActivities(params?: { limit?: number; type?: string }) {
      this.loading.activities = true;
      try {
        const res = await getRecentActivities(params);
        this.activities = res.data.list;
      } catch (error) {
        console.error('[质量中心][fetchActivities][失败]', error);
        throw error;
      } finally {
        this.loading.activities = false;
      }
    },

    /** 获取AI洞察 */
    async fetchAIInsights() {
      this.loading.aiInsights = true;
      try {
        const res = await getAIInsights();
        this.aiInsights = res.data.list;
      } catch (error) {
        console.error('[质量中心][fetchAIInsights][失败]', error);
        throw error;
      } finally {
        this.loading.aiInsights = false;
      }
    },

    /** 一键加载全部Dashboard数据 */
    async fetchDashboardAll() {
      await Promise.allSettled([
        this.fetchOverview(),
        this.fetchTrend('week'),
        this.fetchModuleQuality(),
        this.fetchBugDistribution(),
        this.fetchFeedbackDistribution(),
        this.fetchActivities({ limit: 10 }),
        this.fetchAIInsights(),
        this.fetchLinkRecords(),
      ]);
    },

    // ==================== 定时报表 ====================

    /** 获取定时报表列表 */
    async fetchScheduledReports() {
      this.loading.scheduledReports = true;
      try {
        const res = await getScheduledReports();
        this.scheduledReports = res.data.list;
        this.scheduledReportsTotal = res.data.total;
        console.log('[质量中心][fetchScheduledReports][成功]', res.data.total);
      } catch (error) {
        console.error('[质量中心][fetchScheduledReports][失败]', error);
        throw error;
      } finally {
        this.loading.scheduledReports = false;
      }
    },

    /** 创建定时报表 */
    async addScheduledReport(params: ScheduledReportParams): Promise<ScheduledReport> {
      this.submitting = true;
      try {
        const res = await createScheduledReport(params);
        await this.fetchScheduledReports();
        console.log('[质量中心][createScheduledReport][成功]', res.data.id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][createScheduledReport][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 更新定时报表 */
    async editScheduledReport(id: number, params: Partial<ScheduledReportParams>): Promise<ScheduledReport> {
      this.submitting = true;
      try {
        const res = await updateScheduledReport(id, params);
        await this.fetchScheduledReports();
        console.log('[质量中心][updateScheduledReport][成功]', id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][updateScheduledReport][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 删除定时报表 */
    async removeScheduledReport(id: number) {
      this.submitting = true;
      try {
        await deleteScheduledReport(id);
        await this.fetchScheduledReports();
        console.log('[质量中心][deleteScheduledReport][成功]', id);
      } catch (error) {
        console.error('[质量中心][deleteScheduledReport][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 切换报表启用状态 */
    async toggleReport(id: number, enabled: boolean) {
      try {
        await toggleScheduledReport(id, enabled);
        const target = this.scheduledReports.find(r => r.id === id);
        if (target) target.enabled = enabled;
        console.log('[质量中心][toggleScheduledReport][成功]', { id, enabled });
      } catch (error) {
        console.error('[质量中心][toggleScheduledReport][失败]', error);
        throw error;
      }
    },

    /** 手动触发报表 */
    async triggerReport(id: number): Promise<ReportHistory> {
      this.submitting = true;
      try {
        const res = await triggerScheduledReport(id);
        console.log('[质量中心][triggerScheduledReport][成功]', id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][triggerScheduledReport][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 获取报表执行历史 */
    async fetchReportHistory(params?: { report_id?: number; page?: number; pageSize?: number }) {
      this.loading.reportHistory = true;
      try {
        const res = await getReportHistory(params);
        this.reportHistory = res.data.list;
        this.reportHistoryTotal = res.data.total;
      } catch (error) {
        console.error('[质量中心][fetchReportHistory][失败]', error);
        throw error;
      } finally {
        this.loading.reportHistory = false;
      }
    },

    // ==================== 脑图数据 ====================

    /** 获取Bug关联数据 */
    async fetchBugLinks() {
      this.loading.bugLinks = true;
      try {
        const res = await getBugLinkData();
        this.bugLinks = res.data.list;
        console.log('[质量中心][fetchBugLinks][成功]', res.data.list.length);
      } catch (error) {
        console.error('[质量中心][fetchBugLinks][失败]', error);
        throw error;
      } finally {
        this.loading.bugLinks = false;
      }
    },

    /** 获取反馈分类数据 */
    async fetchFeedbackClassification() {
      this.loading.feedbackClassification = true;
      try {
        const res = await getFeedbackClassification();
        this.feedbackClassification = res.data.list;
        console.log('[质量中心][fetchFeedbackClassification][成功]', res.data.list.length);
      } catch (error) {
        console.error('[质量中心][fetchFeedbackClassification][失败]', error);
        throw error;
      } finally {
        this.loading.feedbackClassification = false;
      }
    },

    // ==================== 报表模板 ====================

    /** 获取报表模板列表（带缓存） */
    async fetchReportTemplates(forceRefresh = false) {
      this.loading.reportTemplates = true;
      try {
        const data = await cachedFetch(
          'qc:report-templates',
          async () => { const res = await getReportTemplates(); return res.data.list; },
          STALE_TIMES.REPORT_TEMPLATE,
          forceRefresh
        );
        this.reportTemplates = data;
        console.log('[质量中心][fetchReportTemplates][成功]', data.length);
      } catch (error) {
        console.error('[质量中心][fetchReportTemplates][失败]', error);
        throw error;
      } finally {
        this.loading.reportTemplates = false;
      }
    },

    /** 创建报表模板 */
    async addReportTemplate(params: ReportTemplateParams): Promise<ReportTemplate> {
      this.submitting = true;
      try {
        const res = await createReportTemplate(params);
        dataCache.invalidate('qc:report-templates');
        await this.fetchReportTemplates(true);
        console.log('[质量中心][createReportTemplate][成功]', res.data.id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][createReportTemplate][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 更新报表模板 */
    async editReportTemplate(id: number, params: Partial<ReportTemplateParams>): Promise<ReportTemplate> {
      this.submitting = true;
      try {
        const res = await updateReportTemplate(id, params);
        dataCache.invalidate('qc:report-templates');
        await this.fetchReportTemplates(true);
        console.log('[质量中心][updateReportTemplate][成功]', id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][updateReportTemplate][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 删除报表模板 */
    async removeReportTemplate(id: number) {
      this.submitting = true;
      try {
        await deleteReportTemplate(id);
        dataCache.invalidate('qc:report-templates');
        await this.fetchReportTemplates(true);
        console.log('[质量中心][deleteReportTemplate][成功]', id);
      } catch (error) {
        console.error('[质量中心][deleteReportTemplate][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    // ==================== 邮件模板 ====================

    /** 获取邮件模板列表（带缓存） */
    async fetchEmailTemplates(forceRefresh = false) {
      this.loading.emailTemplates = true;
      try {
        const data = await cachedFetch(
          'qc:email-templates',
          async () => { const res = await getEmailTemplates(); return res.data.list; },
          STALE_TIMES.EMAIL_TEMPLATE,
          forceRefresh
        );
        this.emailTemplates = data;
        console.log('[质量中心][fetchEmailTemplates][成功]', data.length);
      } catch (error) {
        console.error('[质量中心][fetchEmailTemplates][失败]', error);
        throw error;
      } finally {
        this.loading.emailTemplates = false;
      }
    },

    /** 创建邮件模板 */
    async addEmailTemplate(params: EmailTemplateParams): Promise<EmailTemplate> {
      this.submitting = true;
      try {
        const res = await createEmailTemplate(params);
        dataCache.invalidate('qc:email-templates');
        await this.fetchEmailTemplates(true);
        console.log('[质量中心][createEmailTemplate][成功]', res.data.id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][createEmailTemplate][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 更新邮件模板 */
    async editEmailTemplate(id: number, params: Partial<EmailTemplateParams>): Promise<EmailTemplate> {
      this.submitting = true;
      try {
        const res = await updateEmailTemplate(id, params);
        dataCache.invalidate('qc:email-templates');
        await this.fetchEmailTemplates(true);
        console.log('[质量中心][updateEmailTemplate][成功]', id);
        return res.data;
      } catch (error) {
        console.error('[质量中心][updateEmailTemplate][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 删除邮件模板 */
    async removeEmailTemplate(id: number) {
      this.submitting = true;
      try {
        await deleteEmailTemplate(id);
        dataCache.invalidate('qc:email-templates');
        await this.fetchEmailTemplates(true);
        console.log('[质量中心][deleteEmailTemplate][成功]', id);
      } catch (error) {
        console.error('[质量中心][deleteEmailTemplate][失败]', error);
        throw error;
      } finally {
        this.submitting = false;
      }
    },

    /** 预览邮件模板 */
    async previewEmail(id: number) {
      try {
        const res = await previewEmailTemplate(id);
        this.emailPreviewHtml = res.data.html;
        console.log('[质量中心][previewEmailTemplate][成功]', id);
      } catch (error) {
        console.error('[质量中心][previewEmailTemplate][失败]', error);
        throw error;
      }
    },

    // ==================== AI分析 ====================

    /** 发起AI分析 */
    async runAIAnalysis(params: AIAnalysisRequest): Promise<AIAnalysisResponse> {
      this.loading.aiAnalysis = true;
      this.aiAnalysisResult = null;
      try {
        const res = await requestAIAnalysis(params);
        this.aiAnalysisResult = res.data;
        console.log('[质量中心][AI分析][成功]', { task_id: res.data.task_id, type: params.type });
        return res.data;
      } catch (error) {
        console.error('[质量中心][AI分析][失败]', error);
        throw error;
      } finally {
        this.loading.aiAnalysis = false;
      }
    },

    /** 获取AI分析历史 */
    async fetchAIAnalysisHistory(params?: { type?: string; page?: number; pageSize?: number }) {
      try {
        const res = await getAIAnalysisHistory(params);
        this.aiAnalysisHistory = res.data.list;
        console.log('[质量中心][AI分析历史][成功]', res.data.total);
      } catch (error) {
        console.error('[质量中心][AI分析历史][失败]', error);
        throw error;
      }
    },

    // ==================== WebSocket ====================

    /** 初始WebSocket连接 */
    initWebSocket() {
      const ws = useWebSocket({ mock: true });
      ws.on<ReportStatusPayload>('report_status', (msg) => {
        this.wsReportStatus = msg.payload as ReportStatusPayload;
        console.log('[质量中心][WS][报表状态]', msg.payload);
      });
      ws.on<NotificationPayload>('notification', (msg) => {
        const payload = msg.payload as NotificationPayload;
        this.wsNotifications.unshift(payload);
        if (this.wsNotifications.length > 50) this.wsNotifications.pop();
        console.log('[质量中心][WS][通知]', payload.title);
      });
      ws.connect();
      this.wsConnected = ws.connected;
      console.log('[质量中心][WS][已初始化]');
    },

    /** 断开WebSocket */
    disconnectWebSocket() {
      const ws = useWebSocket();
      ws.disconnect();
      this.wsConnected = false;
      console.log('[质量中心][WS][已断开]');
    },

    /** 清除实时通知 */
    clearNotifications() {
      this.wsNotifications = [];
    },

    // ==================== 缓存缓存 ====================

    /** 带缓存获取脑图数据（Bug关联） */
    async fetchBugLinksCached(forceRefresh = false) {
      this.loading.bugLinks = true;
      try {
        const data = await cachedFetch(
          'qc:bug-links',
          async () => { const res = await getBugLinkData(); return res.data.list; },
          STALE_TIMES.MINDMAP,
          forceRefresh
        );
        this.bugLinks = data;
      } catch (error) {
        console.error('[质量中心][fetchBugLinksCached][失败]', error);
        throw error;
      } finally {
        this.loading.bugLinks = false;
      }
    },

    /** 带缓存获取脑图数据（反馈分类） */
    async fetchFeedbackClassificationCached(forceRefresh = false) {
      this.loading.feedbackClassification = true;
      try {
        const data = await cachedFetch(
          'qc:feedback-classification',
          async () => { const res = await getFeedbackClassification(); return res.data.list; },
          STALE_TIMES.MINDMAP,
          forceRefresh
        );
        this.feedbackClassification = data;
      } catch (error) {
        console.error('[质量中心][fetchFeedbackClassificationCached][失败]', error);
        throw error;
      } finally {
        this.loading.feedbackClassification = false;
      }
    },

    /** 清除所有缓存 */
    clearAllCache() {
      dataCache.clear();
      console.log('[质量中心][缓存已清除]');
    },
  },
});
