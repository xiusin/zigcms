import { defineStore } from 'pinia';
import type { FeedbackState } from './types';
import type { HttpResponse } from '@/api/request';
import {
  getFeedbackList,
  getFeedbackDetail,
  getCommentList,
  createFeedback,
  updateFeedback,
  deleteFeedback,
  updateFeedbackStatus,
  assignFeedback,
  subscribeFeedback,
  unsubscribeFeedback,
  createComment,
  deleteComment,
  getTagList,
  getFeedbackStatistics,
  getFeedbackTrend,
  getHandlerRanking,
  type Feedback,
  type Comment,
  type FeedbackListParams,
  type CreateFeedbackParams,
  type UpdateFeedbackParams,
  type UpdateFeedbackStatusParams,
  type AssignFeedbackParams,
  type CreateCommentParams,
  type StatisticsParams,
  type TrendParams,
} from '@/api/feedback';

const useFeedbackStore = defineStore('feedback', {
  state: (): FeedbackState => ({
    // 列表状态
    listState: {
      list: [],
      total: 0,
      page: 1,
      pageSize: 20,
      loading: false,
    },
    // 筛选条件
    filterState: {
      keyword: '',
      status: [],
      priority: [],
      type: [],
    },
    // 看板数据
    kanbanState: {
      pending: [],
      processing: [],
      resolved: [],
      closed: [],
    },
    // 统计数据
    statisticsState: null,
    // 当前反馈详情
    currentFeedback: null,
    // 评论列表
    comments: [],
    // 标签列表
    tagList: [],
    // 处理人列表
    handlerList: [],
    // 加载状态
    loading: false,
    // 评论加载状态
    commentsLoading: false,
    // 操作加载状态
    actionLoading: false,
    // 错误信息
    error: null,
  }),

  getters: {
    // 获取列表数据
    feedbackList: (state) => state.listState.list,
    // 获取总数
    totalCount: (state) => state.listState.total,
    // 获取列表加载状态
    isListLoading: (state) => state.listState.loading,
    // 获取当前反馈
    getCurrentFeedback: (state): Feedback | null => state.currentFeedback,
    // 获取评论列表
    getComments: (state): Comment[] => state.comments,
    // 是否正在加载
    isLoading: (state): boolean => state.loading,
    // 是否正在加载评论
    isCommentsLoading: (state): boolean => state.commentsLoading,
    // 是否正在执行操作
    isActionLoading: (state): boolean => state.actionLoading,
    // 获取评论数量
    getCommentCount: (state): number => state.comments.length,
    // 获取反馈ID
    getFeedbackId: (state): number | null => state.currentFeedback?.id || null,
    // 获取筛选条件
    currentFilters: (state) => state.filterState,
    // 获取看板数据
    kanbanData: (state) => state.kanbanState,
  },

  actions: {
    // ========== 列表相关 ==========

    // 设置列表状态
    setListState(listState: Partial<FeedbackState['listState']>) {
      Object.assign(this.listState, listState);
    },

    // 设置筛选条件
    setFilters(filters: Partial<FeedbackState['filterState']>) {
      Object.assign(this.filterState, filters);
    },

    // 重置筛选条件
    resetFilters() {
      this.filterState = {
        keyword: '',
        status: [],
        priority: [],
        type: [],
      };
    },

    // 组织看板数据
    organizeKanbanData(list: Feedback[]) {
      const { FeedbackStatus } = require('@/api/feedback');
      this.kanbanState = {
        pending: list.filter((item) => item.status === FeedbackStatus.PENDING),
        processing: list.filter((item) => item.status === FeedbackStatus.PROCESSING),
        resolved: list.filter((item) => item.status === FeedbackStatus.RESOLVED),
        closed: list.filter(
          (item) =>
            item.status === FeedbackStatus.CLOSED || item.status === FeedbackStatus.REJECTED
        ),
      };
    },

    // 获取反馈列表
    async fetchFeedbackList(params?: FeedbackListParams): Promise<HttpResponse> {
      this.listState.loading = true;
      try {
        const res = await getFeedbackList(params || {});
        if (res.code === 0) {
          this.listState.list = res.data.list || [];
          this.listState.total = res.data.total || 0;
          this.listState.page = params?.page || 1;
          this.listState.pageSize = params?.pageSize || 20;

          // 同步更新看板数据
          this.organizeKanbanData(this.listState.list);
        }
        return res;
      } finally {
        this.listState.loading = false;
      }
    },

    // ========== 详情相关 ==========

    // 设置当前反馈
    setCurrentFeedback(feedback: Feedback | null) {
      this.currentFeedback = feedback;
    },

    // 设置评论列表
    setComments(comments: Comment[]) {
      this.comments = comments;
    },

    // 设置加载状态
    setLoading(loading: boolean) {
      this.loading = loading;
    },

    // 设置评论加载状态
    setCommentsLoading(loading: boolean) {
      this.commentsLoading = loading;
    },

    // 设置操作加载状态
    setActionLoading(loading: boolean) {
      this.actionLoading = loading;
    },

    // 设置错误信息
    setError(error: string | null) {
      this.error = error;
    },

    // 加载反馈详情
    async fetchFeedbackDetail(id: number): Promise<HttpResponse> {
      this.setLoading(true);
      this.setError(null);
      try {
        const res = await getFeedbackDetail(id);
        if (res.code === 0) {
          this.currentFeedback = res.data.feedback;
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '加载反馈详情失败');
        throw error;
      } finally {
        this.setLoading(false);
      }
    },

    // 加载评论列表
    async loadComments(feedbackId: number) {
      this.setCommentsLoading(true);
      try {
        const res = await getCommentList({ feedback_id: feedbackId });
        const comments = res.data.data?.list || [];
        this.setComments(comments);
        return comments;
      } catch (error: any) {
        this.setError(error.message || '加载评论失败');
        throw error;
      } finally {
        this.setCommentsLoading(false);
      }
    },

    // ========== CRUD 操作 ==========

    // 创建反馈
    async createFeedback(params: CreateFeedbackParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await createFeedback(params);
        if (res.code === 0) {
          // 创建成功后刷新列表
          await this.fetchFeedbackList({
            page: this.listState.page,
            pageSize: this.listState.pageSize,
          });
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '创建反馈失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 更新反馈
    async updateFeedback(params: UpdateFeedbackParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await updateFeedback(params);
        // 更新本地状态
        if (this.currentFeedback && this.currentFeedback.id === params.id) {
          this.currentFeedback = { ...this.currentFeedback, ...params };
        }
        // 刷新列表
        await this.fetchFeedbackList({
          page: this.listState.page,
          pageSize: this.listState.pageSize,
        });
        return res;
      } catch (error: any) {
        this.setError(error.message || '更新反馈失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 删除反馈
    async deleteFeedback(id: number): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await deleteFeedback(id);
        if (res.code === 0) {
          // 从列表中移除
          const index = this.listState.list.findIndex((item) => item.id === id);
          if (index > -1) {
            this.listState.list.splice(index, 1);
            this.listState.total -= 1;
          }
          // 清除当前反馈
          if (this.currentFeedback?.id === id) {
            this.setCurrentFeedback(null);
          }
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '删除反馈失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 更新反馈状态
    async updateFeedbackStatus(params: UpdateFeedbackStatusParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await updateFeedbackStatus(params);
        if (res.code === 0) {
          // 更新本地状态
          if (this.currentFeedback && this.currentFeedback.id === params.id) {
            this.currentFeedback.status = params.status;
          }
          // 更新列表中的数据
          const item = this.listState.list.find((item) => item.id === params.id);
          if (item) {
            item.status = params.status;
          }
          // 重新组织看板数据
          this.organizeKanbanData(this.listState.list);
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '更新状态失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 指派反馈
    async assignFeedback(params: AssignFeedbackParams): Promise<HttpResponse> {
      this.setActionLoading(true);
      try {
        const res = await assignFeedback(params);
        if (res.code === 0) {
          // 更新本地状态
          if (this.currentFeedback && this.currentFeedback.id === params.id) {
            this.currentFeedback.handler_id = params.handler_id;
          }
          // 刷新列表
          await this.fetchFeedbackList({
            page: this.listState.page,
            pageSize: this.listState.pageSize,
          });
        }
        return res;
      } catch (error: any) {
        this.setError(error.message || '指派失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 订阅反馈
    async subscribe(id: number) {
      this.setActionLoading(true);
      try {
        await subscribeFeedback({ id });
        // 更新本地状态
        if (this.currentFeedback && this.currentFeedback.id === id) {
          this.currentFeedback.is_subscribed = true;
          this.currentFeedback.subscriber_count++;
        }
      } catch (error: any) {
        this.setError(error.message || '订阅失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 取消订阅反馈
    async unsubscribe(id: number) {
      this.setActionLoading(true);
      try {
        await unsubscribeFeedback({ id });
        // 更新本地状态
        if (this.currentFeedback && this.currentFeedback.id === id) {
          this.currentFeedback.is_subscribed = false;
          this.currentFeedback.subscriber_count--;
        }
      } catch (error: any) {
        this.setError(error.message || '取消订阅失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 创建评论
    async createComment(params: CreateCommentParams) {
      this.setActionLoading(true);
      try {
        const res = await createComment(params);
        // 重新加载评论列表
        await this.loadComments(params.feedback_id);
        // 更新反馈的评论数
        if (this.currentFeedback && this.currentFeedback.id === params.feedback_id) {
          this.currentFeedback.comment_count++;
        }
        return res.data.data;
      } catch (error: any) {
        this.setError(error.message || '创建评论失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // 删除评论
    async deleteComment(commentId: number, feedbackId: number) {
      this.setActionLoading(true);
      try {
        await deleteComment(commentId);
        // 重新加载评论列表
        await this.loadComments(feedbackId);
        // 更新反馈的评论数
        if (this.currentFeedback && this.currentFeedback.id === feedbackId) {
          this.currentFeedback.comment_count--;
        }
      } catch (error: any) {
        this.setError(error.message || '删除评论失败');
        throw error;
      } finally {
        this.setActionLoading(false);
      }
    },

    // ========== 标签相关 ==========

    // 获取标签列表
    async fetchTagList(): Promise<HttpResponse> {
      const res = await getTagList({ page: 1, pageSize: 100 });
      if (res.code === 0) {
        this.tagList = res.data.list.map((item: any) => ({
          id: item.id,
          name: item.name,
          color: item.color,
        }));
      }
      return res;
    },

    // ========== 统计相关 ==========

    // 获取统计概览
    async fetchStatistics(params?: StatisticsParams): Promise<HttpResponse> {
      const res = await getFeedbackStatistics(params);
      if (res.code === 0) {
        this.statisticsState = res.data;
      }
      return res;
    },

    // 获取趋势数据
    async fetchTrend(params?: TrendParams): Promise<HttpResponse> {
      return await getFeedbackTrend(params);
    },

    // 获取处理人排行
    async fetchHandlerRanking(params?: StatisticsParams): Promise<HttpResponse> {
      const res = await getHandlerRanking(params);
      if (res.code === 0) {
        this.handlerList = res.data.list.map((item: any) => ({
          id: item.id,
          name: item.name,
          avatar: item.avatar,
        }));
      }
      return res;
    },

    // ========== 导出相关 ==========

    // 导出反馈数据
    async exportFeedback(params?: FeedbackListParams): Promise<void> {
      // 构建导出 URL
      const queryParams = new URLSearchParams();
      if (params?.keyword) queryParams.append('keyword', params.keyword);
      if (params?.status !== undefined) queryParams.append('status', String(params.status));
      if (params?.priority !== undefined) queryParams.append('priority', String(params.priority));
      if (params?.type !== undefined) queryParams.append('type', String(params.type));
      if (params?.handler_id !== undefined)
        queryParams.append('handler_id', String(params.handler_id));
      if (params?.start_time) queryParams.append('start_time', params.start_time);
      if (params?.end_time) queryParams.append('end_time', params.end_time);

      const exportUrl = `/api/feedback/export?${queryParams.toString()}`;

      // 创建临时链接下载
      const link = document.createElement('a');
      link.href = exportUrl;
      link.download = `feedback_export_${Date.now()}.xlsx`;
      document.body.appendChild(link);
      link.click();
      document.body.removeChild(link);
    },

    // 重置状态
    reset() {
      this.currentFeedback = null;
      this.comments = [];
      this.loading = false;
      this.commentsLoading = false;
      this.actionLoading = false;
      this.error = null;
      this.listState = {
        list: [],
        total: 0,
        page: 1,
        pageSize: 20,
        loading: false,
      };
      this.filterState = {
        keyword: '',
        status: [],
        priority: [],
        type: [],
      };
      this.kanbanState = {
        pending: [],
        processing: [],
        resolved: [],
        closed: [],
      };
      this.statisticsState = null;
      this.tagList = [];
      this.handlerList = [];
    },
  },
});

export { useFeedbackStore };
export default useFeedbackStore;
