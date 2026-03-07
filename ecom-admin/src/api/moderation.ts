/**
 * 审核系统 API
 */

import request from '@/utils/request';
import type {
  ModerationResult,
  ModerationLog,
  ModerationStats,
  SensitiveWord,
  ModerationRule,
  CheckContentRequest,
  ReviewRequest,
  CreateSensitiveWordRequest,
  UpdateSensitiveWordRequest,
  BatchImportSensitiveWordsRequest,
  CreateModerationRuleRequest,
  UpdateModerationRuleRequest,
  ModerationQueryParams,
  SensitiveWordQueryParams,
  ModerationRuleQueryParams,
} from '@/types/moderation';

/**
 * 审核 API
 */
export const moderationApi = {
  /**
   * 检查内容
   */
  checkContent(data: CheckContentRequest): Promise<ModerationResult> {
    return request.post('/api/moderation/check', data);
  },

  /**
   * 获取待审核列表
   */
  getPendingList(params: ModerationQueryParams): Promise<{
    items: ModerationLog[];
    total: number;
    page: number;
    page_size: number;
  }> {
    return request.get('/api/moderation/pending', { params });
  },

  /**
   * 通过审核
   */
  approve(id: number, data: ReviewRequest): Promise<void> {
    return request.post(`/api/moderation/approve/${id}`, data);
  },

  /**
   * 拒绝审核
   */
  reject(id: number, data: ReviewRequest): Promise<void> {
    return request.post(`/api/moderation/reject/${id}`, data);
  },

  /**
   * 获取审核统计
   */
  getStats(params?: { start_date?: string; end_date?: string }): Promise<ModerationStats> {
    return request.get('/api/moderation/stats', { params });
  },

  /**
   * 获取审核趋势数据
   */
  getTrend(params?: { start_date?: string; end_date?: string; days?: number }): Promise<Array<{
    date: string;
    approved: number;
    rejected: number;
    pending: number;
  }>> {
    return request.get('/api/moderation/stats/trend', { params });
  },

  /**
   * 获取敏感词命中统计
   */
  getSensitiveWordStats(params?: { start_date?: string; end_date?: string; limit?: number }): Promise<Array<{
    word: string;
    category: string;
    hit_count: number;
    level: number;
  }>> {
    return request.get('/api/moderation/stats/sensitive-words', { params });
  },

  /**
   * 获取敏感词分类统计
   */
  getCategoryStats(params?: { start_date?: string; end_date?: string }): Promise<Array<{
    category: string;
    count: number;
  }>> {
    return request.get('/api/moderation/stats/categories', { params });
  },

  /**
   * 获取用户违规统计
   */
  getUserViolationStats(params?: { start_date?: string; end_date?: string; limit?: number }): Promise<Array<{
    user_id: number;
    violation_count: number;
    credit_score: number;
    status: string;
    last_violation_at: string;
  }>> {
    return request.get('/api/moderation/stats/user-violations', { params });
  },

  /**
   * 获取审核效率统计
   */
  getEfficiencyStats(params?: { start_date?: string; end_date?: string }): Promise<{
    avg_review_time: number;
    auto_process_rate: number;
    manual_review_rate: number;
    reject_rate: number;
    total_processed: number;
    auto_approved: number;
    auto_rejected: number;
    manual_approved: number;
    manual_rejected: number;
  }> {
    return request.get('/api/moderation/stats/efficiency', { params });
  },

  /**
   * 获取审核方式分布
   */
  getActionDistribution(params?: { start_date?: string; end_date?: string }): Promise<Array<{
    action: string;
    count: number;
  }>> {
    return request.get('/api/moderation/stats/actions', { params });
  },

  /**
   * 获取审核记录列表
   */
  getLogList(params: ModerationQueryParams): Promise<{
    items: ModerationLog[];
    total: number;
    page: number;
    page_size: number;
  }> {
    return request.get('/api/moderation/logs', { params });
  },

  /**
   * 获取审核记录详情
   */
  getLogDetail(id: number): Promise<ModerationLog> {
    return request.get(`/api/moderation/logs/${id}`);
  },
};

/**
 * 敏感词 API
 */
export const sensitiveWordApi = {
  /**
   * 获取敏感词列表
   */
  getList(params: SensitiveWordQueryParams): Promise<{
    items: SensitiveWord[];
    total: number;
    page: number;
    page_size: number;
  }> {
    return request.get('/api/moderation/sensitive-words', { params });
  },

  /**
   * 创建敏感词
   */
  create(data: CreateSensitiveWordRequest): Promise<SensitiveWord> {
    return request.post('/api/moderation/sensitive-words', data);
  },

  /**
   * 更新敏感词
   */
  update(id: number, data: UpdateSensitiveWordRequest): Promise<void> {
    return request.put(`/api/moderation/sensitive-words/${id}`, data);
  },

  /**
   * 删除敏感词
   */
  delete(id: number): Promise<void> {
    return request.delete(`/api/moderation/sensitive-words/${id}`);
  },

  /**
   * 批量导入敏感词
   */
  batchImport(data: BatchImportSensitiveWordsRequest): Promise<{ count: number }> {
    return request.post('/api/moderation/sensitive-words/batch-import', data);
  },

  /**
   * 导出敏感词
   */
  export(params?: SensitiveWordQueryParams): Promise<Blob> {
    return request.get('/api/moderation/sensitive-words/export', {
      params,
      responseType: 'blob',
    });
  },
};

/**
 * 审核规则 API
 */
export const moderationRuleApi = {
  /**
   * 获取审核规则列表
   */
  getList(params: ModerationRuleQueryParams): Promise<{
    items: ModerationRule[];
    total: number;
    page: number;
    page_size: number;
  }> {
    return request.get('/api/moderation/rules', { params });
  },

  /**
   * 创建审核规则
   */
  create(data: CreateModerationRuleRequest): Promise<ModerationRule> {
    return request.post('/api/moderation/rules', data);
  },

  /**
   * 更新审核规则
   */
  update(id: number, data: UpdateModerationRuleRequest): Promise<void> {
    return request.put(`/api/moderation/rules/${id}`, data);
  },

  /**
   * 删除审核规则
   */
  delete(id: number): Promise<void> {
    return request.delete(`/api/moderation/rules/${id}`);
  },

  /**
   * 启用/禁用审核规则
   */
  toggleStatus(id: number, status: number): Promise<void> {
    return request.put(`/api/moderation/rules/${id}/status`, { status });
  },
};
