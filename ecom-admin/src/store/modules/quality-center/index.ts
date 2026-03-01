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
} from '@/types/quality-center';

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
  },
});
