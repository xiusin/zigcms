/**
 * 反馈系统 API 封装
 * 包含反馈管理、评论管理、标签管理、指派/订阅、统计报表等功能
 */
import request from './request';
import type { HttpResponse } from './request';

// ========== 枚举类型定义 ==========

/** 反馈状态枚举 */
export enum FeedbackStatus {
  /** 待处理 */
  PENDING = 0,
  /** 处理中 */
  PROCESSING = 1,
  /** 已解决 */
  RESOLVED = 2,
  /** 已关闭 */
  CLOSED = 3,
  /** 已拒绝 */
  REJECTED = 4,
}

/** 反馈优先级枚举 */
export enum FeedbackPriority {
  /** 紧急 */
  URGENT = 0,
  /** 高 */
  HIGH = 1,
  /** 中 */
  MEDIUM = 2,
  /** 低 */
  LOW = 3,
}

/** 反馈类型枚举 */
export enum FeedbackType {
  /** 功能建议 */
  FEATURE = 0,
  /** Bug 反馈 */
  BUG = 1,
  /** 性能问题 */
  PERFORMANCE = 2,
  /** 用户体验 */
  UX = 3,
  /** 其他 */
  OTHER = 4,
}

/** 评论类型枚举 */
export enum CommentType {
  /** 普通评论 */
  NORMAL = 0,
  /** 内部备注 */
  INTERNAL = 1,
  /** 系统通知 */
  SYSTEM = 2,
}

// ========== 基础类型接口 ==========

/** 标签对象 */
export interface Tag {
  /** 标签 ID */
  id: number;
  /** 标签名称 */
  name: string;
  /** 标签颜色 */
  color: string;
  /** 标签描述 */
  description?: string;
  /** 使用次数 */
  usage_count?: number;
  /** 创建时间 */
  created_at: string;
  /** 更新时间 */
  updated_at?: string;
}

/** 评论对象 */
export interface Comment {
  /** 评论 ID */
  id: number;
  /** 反馈 ID */
  feedback_id: number;
  /** 父评论 ID（用于回复） */
  parent_id?: number;
  /** 评论类型 */
  type: CommentType;
  /** 评论内容 */
  content: string;
  /** 评论者 ID */
  user_id: number;
  /** 评论者名称 */
  user_name: string;
  /** 评论者头像 */
  user_avatar?: string;
  /** 是否已编辑 */
  is_edited: boolean;
  /** 创建时间 */
  created_at: string;
  /** 更新时间 */
  updated_at?: string;
  /** 子评论列表 */
  children?: Comment[];
}

/** 处理人信息 */
export interface Handler {
  /** 用户 ID */
  id: number;
  /** 用户名称 */
  name: string;
  /** 用户头像 */
  avatar?: string;
  /** 处理数量 */
  count?: number;
}

/** 反馈对象 */
export interface Feedback {
  /** 反馈 ID */
  id: number;
  /** 反馈标题 */
  title: string;
  /** 反馈内容 */
  content: string;
  /** 反馈类型 */
  type: FeedbackType;
  /** 反馈状态 */
  status: FeedbackStatus;
  /** 优先级 */
  priority: FeedbackPriority;
  /** 提交者 ID */
  creator_id: number;
  /** 提交者名称 */
  creator_name: string;
  /** 提交者头像 */
  creator_avatar?: string;
  /** 指派处理人 ID */
  handler_id?: number;
  /** 指派处理人名称 */
  handler_name?: string;
  /** 指派处理人头像 */
  handler_avatar?: string;
  /** 关联标签 ID 列表 */
  tag_ids?: number[];
  /** 关联标签列表 */
  tags?: Tag[];
  /** 评论数量 */
  comment_count: number;
  /** 订阅者数量 */
  subscriber_count: number;
  /** 是否已订阅 */
  is_subscribed: boolean;
  /** 附件列表 */
  attachments?: string[];
  /** 创建时间 */
  created_at: string;
  /** 更新时间 */
  updated_at?: string;
  /** 解决时间 */
  resolved_at?: string;
  /** 关闭时间 */
  closed_at?: string;
}

// ========== 请求/响应参数类型 ==========

/** 分页参数 */
export interface PaginationParams {
  /** 页码 */
  page?: number;
  /** 每页数量 */
  pageSize?: number;
}

/** 反馈列表查询参数 */
export interface FeedbackListParams extends PaginationParams {
  /** 关键词搜索（标题/内容） */
  keyword?: string;
  /** 反馈类型 */
  type?: FeedbackType | number;
  /** 反馈状态 */
  status?: FeedbackStatus | number;
  /** 优先级 */
  priority?: FeedbackPriority | number;
  /** 提交者 ID */
  creator_id?: number;
  /** 处理人 ID */
  handler_id?: number;
  /** 标签 ID */
  tag_id?: number;
  /** 开始时间 */
  start_time?: string;
  /** 结束时间 */
  end_time?: string;
}

/** 创建反馈参数 */
export interface CreateFeedbackParams {
  /** 反馈标题 */
  title: string;
  /** 反馈内容 */
  content: string;
  /** 反馈类型 */
  type: FeedbackType | number;
  /** 优先级 */
  priority?: FeedbackPriority | number;
  /** 关联标签 ID 列表 */
  tag_ids?: number[];
  /** 附件列表 */
  attachments?: string[];
}

/** 更新反馈参数 */
export interface UpdateFeedbackParams {
  /** 反馈 ID */
  id: number;
  /** 反馈标题 */
  title?: string;
  /** 反馈内容 */
  content?: string;
  /** 反馈类型 */
  type?: FeedbackType | number;
  /** 优先级 */
  priority?: FeedbackPriority | number;
  /** 关联标签 ID 列表 */
  tag_ids?: number[];
  /** 附件列表 */
  attachments?: string[];
}

/** 更新反馈状态参数 */
export interface UpdateFeedbackStatusParams {
  /** 反馈 ID */
  id: number;
  /** 新状态 */
  status: FeedbackStatus | number;
  /** 状态变更备注 */
  remark?: string;
}

/** 评论列表查询参数 */
export interface CommentListParams extends PaginationParams {
  /** 反馈 ID */
  feedback_id: number;
  /** 评论类型 */
  type?: CommentType | number;
}

/** 创建评论参数 */
export interface CreateCommentParams {
  /** 反馈 ID */
  feedback_id: number;
  /** 父评论 ID（用于回复） */
  parent_id?: number;
  /** 评论类型 */
  type?: CommentType | number;
  /** 评论内容 */
  content: string;
}

/** 更新评论参数 */
export interface UpdateCommentParams {
  /** 评论 ID */
  id: number;
  /** 评论内容 */
  content: string;
}

/** 回复评论参数 */
export interface ReplyCommentParams {
  /** 反馈 ID */
  feedback_id: number;
  /** 父评论 ID */
  parent_id: number;
  /** 评论内容 */
  content: string;
  /** 评论类型 */
  type?: CommentType | number;
}

/** 标签列表查询参数 */
export interface TagListParams extends PaginationParams {
  /** 关键词搜索 */
  keyword?: string;
}

/** 创建标签参数 */
export interface CreateTagParams {
  /** 标签名称 */
  name: string;
  /** 标签颜色 */
  color: string;
  /** 标签描述 */
  description?: string;
}

/** 更新标签参数 */
export interface UpdateTagParams {
  /** 标签 ID */
  id: number;
  /** 标签名称 */
  name?: string;
  /** 标签颜色 */
  color?: string;
  /** 标签描述 */
  description?: string;
}

/** 指派反馈参数 */
export interface AssignFeedbackParams {
  /** 反馈 ID */
  id: number;
  /** 指派处理人 ID */
  handler_id: number;
  /** 指派备注 */
  remark?: string;
}

/** 订阅反馈参数 */
export interface SubscribeFeedbackParams {
  /** 反馈 ID */
  id: number;
}

/** 统计查询参数 */
export interface StatisticsParams {
  /** 开始时间 */
  start_time?: string;
  /** 结束时间 */
  end_time?: string;
}

/** 趋势查询参数 */
export interface TrendParams extends StatisticsParams {
  /** 时间粒度：day/week/month */
  granularity?: 'day' | 'week' | 'month';
}

// ========== 响应数据类型 ==========

/** 分页响应 */
export interface PaginatedResponse<T> {
  /** 数据列表 */
  list: T[];
  /** 总数 */
  total: number;
  /** 当前页码 */
  page: number;
  /** 每页数量 */
  pageSize: number;
}

/** 反馈详情响应 */
export interface FeedbackDetailResponse {
  /** 反馈信息 */
  feedback: Feedback;
  /** 评论列表 */
  comments?: Comment[];
  /** 相关反馈 */
  related_feedbacks?: Feedback[];
}

/** 统计概览响应 */
export interface FeedbackStatisticsResponse {
  /** 总反馈数 */
  total_count: number;
  /** 待处理数 */
  pending_count: number;
  /** 处理中数 */
  processing_count: number;
  /** 已解决数 */
  resolved_count: number;
  /** 今日新增 */
  today_count: number;
  /** 本周新增 */
  week_count: number;
  /** 本月新增 */
  month_count: number;
  /** 平均处理时长（小时） */
  avg_handle_time: number;
  /** 解决率 */
  resolve_rate: number;
}

/** 趋势数据项 */
export interface TrendDataItem {
  /** 时间标签 */
  date: string;
  /** 新增数量 */
  created: number;
  /** 解决数量 */
  resolved: number;
  /** 关闭数量 */
  closed: number;
}

/** 趋势数据响应 */
export interface FeedbackTrendResponse {
  /** 趋势数据列表 */
  list: TrendDataItem[];
}

/** 处理人排行项 */
export interface HandlerRankingItem {
  /** 用户 ID */
  id: number;
  /** 用户名称 */
  name: string;
  /** 用户头像 */
  avatar?: string;
  /** 处理数量 */
  handle_count: number;
  /** 解决数量 */
  resolve_count: number;
  /** 平均处理时长 */
  avg_handle_time: number;
  /** 满意度评分 */
  satisfaction_score: number;
}

/** 处理人排行响应 */
export interface HandlerRankingResponse {
  /** 排行列表 */
  list: HandlerRankingItem[];
}

// ========== 反馈相关 API ==========

/**
 * 获取反馈列表
 * @param params 查询参数
 * @returns 反馈列表分页数据
 */
export function getFeedbackList(
  params: FeedbackListParams
): Promise<HttpResponse> {
  return request('/api/feedback/list', params);
}

/**
 * 获取反馈详情
 * @param id 反馈 ID
 * @returns 反馈详情数据
 */
export function getFeedbackDetail(id: number): Promise<HttpResponse> {
  return request('/api/feedback/detail', { id });
}

/**
 * 创建反馈
 * @param params 创建参数
 * @returns 创建的反馈信息
 */
export function createFeedback(
  params: CreateFeedbackParams
): Promise<HttpResponse> {
  return request('/api/feedback/create', params);
}

/**
 * 更新反馈
 * @param params 更新参数
 * @returns 更新后的反馈信息
 */
export function updateFeedback(
  params: UpdateFeedbackParams
): Promise<HttpResponse> {
  return request('/api/feedback/update', params);
}

/**
 * 删除反馈
 * @param id 反馈 ID
 * @returns 删除结果
 */
export function deleteFeedback(id: number): Promise<HttpResponse> {
  return request('/api/feedback/delete', { id });
}

/**
 * 更新反馈状态
 * @param params 状态更新参数
 * @returns 更新结果
 */
export function updateFeedbackStatus(
  params: UpdateFeedbackStatusParams
): Promise<HttpResponse> {
  return request('/api/feedback/updateStatus', params);
}

// ========== 评论相关 API ==========

/**
 * 获取评论列表
 * @param params 查询参数
 * @returns 评论列表分页数据
 */
export function getCommentList(
  params: CommentListParams
): Promise<HttpResponse> {
  return request('/api/feedback/comment/list', params);
}

/**
 * 创建评论
 * @param params 创建参数
 * @returns 创建的评论信息
 */
export function createComment(
  params: CreateCommentParams
): Promise<HttpResponse> {
  return request('/api/feedback/comment/create', params);
}

/**
 * 更新评论
 * @param params 更新参数
 * @returns 更新后的评论信息
 */
export function updateComment(
  params: UpdateCommentParams
): Promise<HttpResponse> {
  return request('/api/feedback/comment/update', params);
}

/**
 * 删除评论
 * @param id 评论 ID
 * @returns 删除结果
 */
export function deleteComment(id: number): Promise<HttpResponse> {
  return request('/api/feedback/comment/delete', { id });
}

/**
 * 回复评论
 * @param params 回复参数
 * @returns 创建的回复信息
 */
export function replyComment(
  params: ReplyCommentParams
): Promise<HttpResponse> {
  return request('/api/feedback/comment/reply', params);
}

// ========== 标签管理 API ==========

/**
 * 获取标签列表
 * @param params 查询参数
 * @returns 标签列表分页数据
 */
export function getTagList(params: TagListParams): Promise<HttpResponse> {
  return request('/api/feedback/tag/list', params);
}

/**
 * 创建标签
 * @param params 创建参数
 * @returns 创建的标签信息
 */
export function createTag(params: CreateTagParams): Promise<HttpResponse> {
  return request('/api/feedback/tag/create', params);
}

/**
 * 更新标签
 * @param params 更新参数
 * @returns 更新后的标签信息
 */
export function updateTag(params: UpdateTagParams): Promise<HttpResponse> {
  return request('/api/feedback/tag/update', params);
}

/**
 * 删除标签
 * @param id 标签 ID
 * @returns 删除结果
 */
export function deleteTag(id: number): Promise<HttpResponse> {
  return request('/api/feedback/tag/delete', { id });
}

// ========== 指派/订阅 API ==========

/**
 * 指派反馈
 * @param params 指派参数
 * @returns 指派结果
 */
export function assignFeedback(
  params: AssignFeedbackParams
): Promise<HttpResponse> {
  return request('/api/feedback/assign', params);
}

/**
 * 订阅反馈
 * @param params 订阅参数
 * @returns 订阅结果
 */
export function subscribeFeedback(
  params: SubscribeFeedbackParams
): Promise<HttpResponse> {
  return request('/api/feedback/subscribe', params);
}

/**
 * 取消订阅反馈
 * @param params 取消订阅参数
 * @returns 取消订阅结果
 */
export function unsubscribeFeedback(
  params: SubscribeFeedbackParams
): Promise<HttpResponse> {
  return request('/api/feedback/unsubscribe', params);
}

// ========== 统计报表 API ==========

/**
 * 获取反馈统计概览
 * @param params 查询参数
 * @returns 统计数据
 */
export function getFeedbackStatistics(
  params?: StatisticsParams
): Promise<HttpResponse> {
  return request('/api/feedback/statistics', params || {});
}

/**
 * 获取反馈趋势数据
 * @param params 查询参数
 * @returns 趋势数据
 */
export function getFeedbackTrend(params?: TrendParams): Promise<HttpResponse> {
  return request('/api/feedback/trend', params || {});
}

/**
 * 获取处理人排行
 * @param params 查询参数
 * @returns 排行数据
 */
export function getHandlerRanking(
  params?: StatisticsParams
): Promise<HttpResponse> {
  return request('/api/feedback/handlerRanking', params || {});
}

// ========== 导出所有 API ==========
export default {
  // 反馈相关
  getFeedbackList,
  getFeedbackDetail,
  createFeedback,
  updateFeedback,
  deleteFeedback,
  updateFeedbackStatus,
  // 评论相关
  getCommentList,
  createComment,
  updateComment,
  deleteComment,
  replyComment,
  // 标签管理
  getTagList,
  createTag,
  updateTag,
  deleteTag,
  // 指派/订阅
  assignFeedback,
  subscribeFeedback,
  unsubscribeFeedback,
  // 统计报表
  getFeedbackStatistics,
  getFeedbackTrend,
  getHandlerRanking,
};
