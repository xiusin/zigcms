import type { Feedback, Comment } from '@/api/feedback';

/**
 * 反馈模块状态类型
 */
export interface FeedbackState {
  // 列表状态
  listState: {
    /** 数据列表 */
    list: Feedback[];
    /** 总数 */
    total: number;
    /** 当前页码 */
    page: number;
    /** 每页条数 */
    pageSize: number;
    /** 加载状态 */
    loading: boolean;
  };
  // 筛选条件
  filterState: {
    /** 关键词 */
    keyword: string;
    /** 状态筛选 */
    status: number[];
    /** 优先级筛选 */
    priority: number[];
    /** 类型筛选 */
    type: number[];
  };
  // 看板数据
  kanbanState: {
    /** 待处理 */
    pending: Feedback[];
    /** 处理中 */
    processing: Feedback[];
    /** 已解决 */
    resolved: Feedback[];
    /** 已关闭 */
    closed: Feedback[];
  };
  // 统计数据
  statisticsState: {
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
    /** 平均处理时长 */
    avg_handle_time: number;
    /** 解决率 */
    resolve_rate: number;
  } | null;
  /** 当前反馈详情 */
  currentFeedback: Feedback | null;
  /** 评论列表 */
  comments: Comment[];
  /** 标签列表 */
  tagList: Array<{ id: number; name: string; color: string }>;
  /** 处理人列表 */
  handlerList: Array<{ id: number; name: string; avatar?: string }>;
  /** 加载状态 */
  loading: boolean;
  /** 评论加载状态 */
  commentsLoading: boolean;
  /** 操作加载状态 */
  actionLoading: boolean;
  /** 错误信息 */
  error: string | null;
}
