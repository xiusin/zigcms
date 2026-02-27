/**
 * 反馈系统 Mock 数据
 * 包含反馈管理、评论系统、标签管理等功能
 */

import Mock from 'mockjs';

// ==================== 类型定义 ====================

/**
 * 反馈状态类型
 */
export interface FeedbackStatusType {
  id: string;
  name: string;
  color: string;
  description: string;
  sort: number;
}

/**
 * 反馈优先级类型
 */
export interface FeedbackPriorityType {
  id: string;
  name: string;
  color: string;
  level: number;
  description: string;
}

/**
 * 反馈标签
 */
export interface FeedbackTag {
  id: number;
  name: string;
  color: string;
  description: string;
  count: number;
  status: number;
  created_at: string;
  updated_at?: string;
}

/**
 * 反馈对象
 */
export interface Feedback {
  id: number;
  title: string;
  description: string;
  type: string;
  status: string;
  status_name: string;
  status_color: string;
  priority: string;
  priority_name: string;
  priority_color: string;
  tags: FeedbackTag[];
  tag_ids: number[];
  creator_id: number;
  creator_name: string;
  creator_avatar: string;
  assignee_id?: number;
  assignee_name?: string;
  assignee_avatar?: string;
  subscribers: number[];
  view_count: number;
  comment_count: number;
  attachment_count: number;
  attachments?: string[];
  created_at: string;
  updated_at: string;
  resolved_at?: string;
  closed_at?: string;
}

/**
 * 评论对象
 */
export interface FeedbackComment {
  id: number;
  feedback_id: number;
  content: string;
  author_id: number;
  author_name: string;
  author_avatar: string;
  parent_id?: number;
  reply_to?: string;
  is_internal: boolean;
  attachments?: string[];
  created_at: string;
  updated_at?: string;
  children?: FeedbackComment[];
}

/**
 * 处理人排行
 */
export interface HandlerRanking {
  user_id: number;
  user_name: string;
  user_avatar: string;
  resolved_count: number;
  avg_resolve_time: number;
  satisfaction_rate: number;
}

// ==================== 预设数据 ====================

/**
 * 7种反馈状态
 */
export const feedbackStatuses: FeedbackStatusType[] = [
  { id: 'pending', name: '待处理', color: '#86909c', description: '反馈已提交，等待处理', sort: 1 },
  { id: 'confirmed', name: '已确认', color: '#165dff', description: '反馈已确认，准备处理', sort: 2 },
  { id: 'processing', name: '处理中', color: '#ff7d00', description: '正在处理中', sort: 3 },
  { id: 'waiting_verify', name: '待验证', color: '#722ed1', description: '处理完成，等待验证', sort: 4 },
  { id: 'resolved', name: '已解决', color: '#00b42a', description: '问题已解决', sort: 5 },
  { id: 'closed', name: '已关闭', color: '#86909c', description: '反馈已关闭', sort: 6 },
  { id: 'rejected', name: '已拒绝', color: '#f53f3f', description: '反馈被拒绝', sort: 7 },
];

/**
 * 4种优先级
 */
export const feedbackPriorities: FeedbackPriorityType[] = [
  { id: 'urgent', name: '紧急', color: '#f53f3f', level: 1, description: '需要立即处理' },
  { id: 'high', name: '高', color: '#ff7d00', level: 2, description: '需要优先处理' },
  { id: 'medium', name: '中', color: '#f7ba1e', level: 3, description: '正常处理' },
  { id: 'low', name: '低', color: '#00b42a', level: 4, description: '可以延后处理' },
];

/**
 * 6种预设标签
 */
export const defaultTags: FeedbackTag[] = [
  { id: 1, name: '功能建议', color: '#165dff', description: '新功能或改进建议', count: 0, status: 1, created_at: '2024-01-01 10:00:00' },
  { id: 2, name: 'Bug报告', color: '#f53f3f', description: '系统缺陷或错误报告', count: 0, status: 1, created_at: '2024-01-01 10:00:00' },
  { id: 3, name: '性能优化', color: '#722ed1', description: '性能相关问题', count: 0, status: 1, created_at: '2024-01-01 10:00:00' },
  { id: 4, name: 'UI/UX改进', color: '#0fc6c2', description: '界面或体验改进', count: 0, status: 1, created_at: '2024-01-01 10:00:00' },
  { id: 5, name: '文档改进', color: '#14c9c9', description: '文档相关问题', count: 0, status: 1, created_at: '2024-01-01 10:00:00' },
  { id: 6, name: '安全问题', color: '#f53f3f', description: '安全漏洞或风险', count: 0, status: 1, created_at: '2024-01-01 10:00:00' },
];

// 标签数据存储（可动态修改）
let tags: FeedbackTag[] = [...defaultTags];

// 反馈数据存储
let feedbacks: Feedback[] = [];

// 评论数据存储
let comments: FeedbackComment[] = [];

// 用户数据（用于模拟）
const mockUsers = [
  { id: 1, name: '张三', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 2, name: '李四', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 3, name: '王五', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 4, name: '赵六', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 5, name: '钱七', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 6, name: '孙八', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 7, name: '周九', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
  { id: 8, name: '吴十', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png' },
];

// 反馈类型
const feedbackTypes = ['feature', 'bug', 'improvement', 'question', 'other'];
const feedbackTypeNames: Record<string, string> = {
  feature: '功能需求',
  bug: '缺陷报告',
  improvement: '改进建议',
  question: '问题咨询',
  other: '其他',
};

// ==================== 响应格式化工具 ====================

const responseSuccess = (data: any, msg = 'success') => ({
  code: 200,
  msg,
  data,
});

const responseError = (msg: string, code = 400) => ({
  code,
  msg,
  data: null,
});

const responsePage = (list: any[], page = 1, pageSize = 10, total?: number) => ({
  code: 200,
  msg: 'success',
  data: {
    list,
    pagination: {
      page: Number(page),
      pageSize: Number(pageSize),
      total: total ?? list.length,
    },
  },
});

// ==================== 数据生成函数 ====================

/**
 * 生成随机反馈数据
 */
const generateMockFeedbacks = () => {
  const feedbackList: Feedback[] = [];
  const titles = [
    '登录页面加载缓慢',
    '订单导出功能报错',
    '建议增加批量操作功能',
    '用户头像上传失败',
    '报表统计页面显示异常',
    '希望增加暗黑模式',
    '移动端适配问题',
    '数据导入功能优化建议',
    '权限管理功能缺陷',
    '系统通知无法接收',
    '搜索功能不够精确',
    '建议增加数据备份功能',
    '页面样式错乱',
    '导出Excel格式错误',
    '希望增加多语言支持',
    '密码重置邮件收不到',
    '商品图片显示问题',
    '订单状态更新延迟',
    '建议增加操作日志',
    '库存同步异常',
    '用户注册验证码问题',
    '支付接口调用失败',
    '建议增加数据筛选功能',
    '页面刷新后数据丢失',
    '菜单权限配置不生效',
    '希望增加快捷键支持',
    '表格列宽无法调整',
    '文件上传大小限制问题',
    '建议增加数据可视化',
    '系统响应速度优化',
  ];

  const descriptions = [
    '在使用系统时遇到了这个问题，希望能尽快解决。',
    '这个问题影响了我们的日常工作，请优先处理。',
    '建议增加这个功能，可以提高工作效率。',
    '这是一个比较紧急的问题，请尽快修复。',
    '希望能优化这个功能，提升用户体验。',
    '这个问题已经存在一段时间了，希望能得到解决。',
    '建议参考其他系统的实现方式，增加这个功能。',
    '这个问题在特定情况下才会出现，需要排查。',
    '希望能增加更多的自定义选项。',
    '这个功能对业务很重要，请尽快实现。',
  ];

  for (let i = 1; i <= 30; i++) {
    const status = feedbackStatuses[Math.floor(Math.random() * feedbackStatuses.length)];
    const priority = feedbackPriorities[Math.floor(Math.random() * feedbackPriorities.length)];
    const creator = mockUsers[Math.floor(Math.random() * mockUsers.length)];
    const hasAssignee = Math.random() > 0.3;
    const assignee = hasAssignee ? mockUsers[Math.floor(Math.random() * mockUsers.length)] : undefined;
    const type = feedbackTypes[Math.floor(Math.random() * feedbackTypes.length)];
    
    // 随机选择1-3个标签
    const tagCount = Math.floor(Math.random() * 3) + 1;
    const selectedTags: FeedbackTag[] = [];
    const selectedTagIds: number[] = [];
    for (let j = 0; j < tagCount; j++) {
      const tag = tags[Math.floor(Math.random() * tags.length)];
      if (!selectedTagIds.includes(tag.id)) {
        selectedTags.push(tag);
        selectedTagIds.push(tag.id);
      }
    }

    const createdAt = new Date(Date.now() - Math.random() * 90 * 24 * 60 * 60 * 1000);
    const updatedAt = new Date(createdAt.getTime() + Math.random() * 7 * 24 * 60 * 60 * 1000);

    feedbackList.push({
      id: i,
      title: titles[i - 1] || `反馈标题 ${i}`,
      description: descriptions[Math.floor(Math.random() * descriptions.length)],
      type,
      status: status.id,
      status_name: status.name,
      status_color: status.color,
      priority: priority.id,
      priority_name: priority.name,
      priority_color: priority.color,
      tags: selectedTags,
      tag_ids: selectedTagIds,
      creator_id: creator.id,
      creator_name: creator.name,
      creator_avatar: creator.avatar,
      assignee_id: assignee?.id,
      assignee_name: assignee?.name,
      assignee_avatar: assignee?.avatar,
      subscribers: [],
      view_count: Math.floor(Math.random() * 1000),
      comment_count: 0,
      attachment_count: Math.floor(Math.random() * 3),
      attachments: [],
      created_at: createdAt.toISOString().slice(0, 19).replace('T', ' '),
      updated_at: updatedAt.toISOString().slice(0, 19).replace('T', ' '),
      resolved_at: status.id === 'resolved' ? updatedAt.toISOString().slice(0, 19).replace('T', ' ') : undefined,
      closed_at: ['closed', 'rejected'].includes(status.id) ? updatedAt.toISOString().slice(0, 19).replace('T', ' ') : undefined,
    });
  }

  return feedbackList;
};

/**
 * 生成随机评论数据
 */
const generateMockComments = () => {
  const commentList: FeedbackComment[] = [];
  const contents = [
    '收到，我们会尽快处理这个问题。',
    '这个问题已经修复，请验证一下。',
    '能否提供更多详细信息？',
    '这个问题我们已经记录下来了。',
    '建议很好，我们会考虑在后续版本中加入。',
    '这个问题需要进一步排查，请耐心等待。',
    '已经安排开发人员处理。',
    '这个问题暂时无法复现，能否提供操作步骤？',
    '感谢反馈，这个问题已经解决。',
    '这个功能已经在开发计划中。',
    '请检查网络连接是否正常。',
    '建议清理浏览器缓存后重试。',
    '这个问题需要后端配合处理。',
    '已经修复，请更新到最新版本。',
    '感谢建议，我们会评估可行性。',
    '这个问题是已知问题，正在修复中。',
    '请提供截图或录屏，方便我们定位问题。',
    '这个功能目前不支持，建议使用替代方案。',
    '已经优先处理，预计今天完成。',
    '感谢耐心等待，问题已解决。',
  ];

  let commentId = 1;

  // 为每个反馈生成1-5条评论
  feedbacks.forEach((feedback) => {
    const commentCount = Math.floor(Math.random() * 5) + 1;
    const feedbackComments: FeedbackComment[] = [];

    for (let i = 0; i < commentCount; i++) {
      const author = mockUsers[Math.floor(Math.random() * mockUsers.length)];
      const isInternal = Math.random() > 0.8;
      const hasParent = i > 0 && Math.random() > 0.5;
      const parentId = hasParent ? feedbackComments[Math.floor(Math.random() * feedbackComments.length)]?.id : undefined;

      const comment: FeedbackComment = {
        id: commentId++,
        feedback_id: feedback.id,
        content: contents[Math.floor(Math.random() * contents.length)],
        author_id: author.id,
        author_name: author.name,
        author_avatar: author.avatar,
        parent_id: parentId,
        reply_to: parentId ? feedbackComments.find(c => c.id === parentId)?.author_name : undefined,
        is_internal: isInternal,
        created_at: new Date(Date.now() - Math.random() * 30 * 24 * 60 * 60 * 1000).toISOString().slice(0, 19).replace('T', ' '),
      };

      feedbackComments.push(comment);
      commentList.push(comment);
    }

    // 更新反馈的评论数
    feedback.comment_count = feedbackComments.length;
  });

  return commentList;
};

// 初始化数据
feedbacks = generateMockFeedbacks();
comments = generateMockComments();

// ==================== Mock 接口实现 ====================

export default [
  // ==================== 反馈状态与优先级 ====================
  
  // 获取反馈状态列表
  {
    url: '/api/feedback/statuses',
    method: 'get',
    response: () => responseSuccess(feedbackStatuses),
  },

  // 获取反馈优先级列表
  {
    url: '/api/feedback/priorities',
    method: 'get',
    response: () => responseSuccess(feedbackPriorities),
  },

  // ==================== 反馈管理 ====================

  // 获取反馈列表（支持分页、筛选、搜索）- 支持 GET 和 POST
  {
    url: /\/api\/feedback\/list/,
    method: 'get',
    response: (config: any) => {
      const url = new URL(config.url, 'http://localhost');
      const page = Number(url.searchParams.get('page')) || 1;
      const pageSize = Number(url.searchParams.get('pageSize')) || 10;
      const keyword = url.searchParams.get('keyword') || '';
      const status = url.searchParams.get('status');
      const priority = url.searchParams.get('priority');
      const type = url.searchParams.get('type');
      const tagId = url.searchParams.get('tag_id');
      const assigneeId = url.searchParams.get('assignee_id');
      const creatorId = url.searchParams.get('creator_id');
      const startDate = url.searchParams.get('start_date');
      const endDate = url.searchParams.get('end_date');

      let filteredList = [...feedbacks];

      // 关键词搜索
      if (keyword) {
        filteredList = filteredList.filter(
          (item) =>
            item.title.toLowerCase().includes(keyword.toLowerCase()) ||
            item.description.toLowerCase().includes(keyword.toLowerCase())
        );
      }

      // 状态筛选
      if (status) {
        filteredList = filteredList.filter((item) => item.status === status);
      }

      // 优先级筛选
      if (priority) {
        filteredList = filteredList.filter((item) => item.priority === priority);
      }

      // 类型筛选
      if (type) {
        filteredList = filteredList.filter((item) => item.type === type);
      }

      // 标签筛选
      if (tagId) {
        filteredList = filteredList.filter((item) =>
          item.tag_ids.includes(Number(tagId))
        );
      }

      // 指派人筛选
      if (assigneeId) {
        filteredList = filteredList.filter(
          (item) => item.assignee_id === Number(assigneeId)
        );
      }

      // 创建人筛选
      if (creatorId) {
        filteredList = filteredList.filter(
          (item) => item.creator_id === Number(creatorId)
        );
      }

      // 日期范围筛选
      if (startDate) {
        filteredList = filteredList.filter(
          (item) => item.created_at >= startDate
        );
      }
      if (endDate) {
        filteredList = filteredList.filter(
          (item) => item.created_at <= `${endDate} 23:59:59`
        );
      }

      // 按创建时间倒序
      filteredList.sort(
        (a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );

      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pageList = filteredList.slice(start, end);

      return responsePage(pageList, page, pageSize, filteredList.length);
    },
  },

  // 获取反馈列表（POST 版本，兼容 AMIS CRUD）
  {
    url: /\/api\/feedback\/list/,
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body || '{}');
      const page = data.page || 1;
      const pageSize = data.pageSize || 20;
      const keyword = data.keyword || '';
      const status = data.status;
      const priority = data.priority;
      const type = data.type;

      let filteredList = [...feedbacks];

      // 关键词搜索
      if (keyword) {
        filteredList = filteredList.filter(
          (item) =>
            item.title.toLowerCase().includes(keyword.toLowerCase()) ||
            item.description.toLowerCase().includes(keyword.toLowerCase())
        );
      }

      // 状态筛选
      if (status !== undefined && status !== null && status !== '') {
        const statusMap: Record<number, string> = {
          0: 'pending',
          1: 'processing',
          2: 'resolved',
          3: 'closed',
          4: 'rejected',
        };
        const statusStr = statusMap[Number(status)];
        if (statusStr) {
          filteredList = filteredList.filter((item) => item.status === statusStr);
        }
      }

      // 优先级筛选
      if (priority !== undefined && priority !== null && priority !== '') {
        const priorityMap: Record<number, string> = {
          0: 'urgent',
          1: 'high',
          2: 'medium',
          3: 'low',
        };
        const priorityStr = priorityMap[Number(priority)];
        if (priorityStr) {
          filteredList = filteredList.filter((item) => item.priority === priorityStr);
        }
      }

      // 类型筛选
      if (type !== undefined && type !== null && type !== '') {
        const typeMap: Record<number, string> = {
          0: 'feature',
          1: 'bug',
          2: 'performance',
          3: 'ux',
          4: 'other',
        };
        const typeStr = typeMap[Number(type)];
        if (typeStr) {
          filteredList = filteredList.filter((item) => item.type === typeStr);
        }
      }

      // 按创建时间倒序
      filteredList.sort(
        (a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );

      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pageList = filteredList.slice(start, end);

      return responsePage(pageList, page, pageSize, filteredList.length);
    },
  },

  // 获取反馈详情
  {
    url: /\/api\/feedback\/detail\/\d+/,
    method: 'get',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/detail\/(\d+)/)[1]);
      const feedback = feedbacks.find((f) => f.id === id);

      if (!feedback) {
        return responseError('反馈不存在', 404);
      }

      // 增加浏览次数
      feedback.view_count++;

      return responseSuccess(feedback);
    },
  },

  // 创建反馈
  {
    url: '/api/feedback/create',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);
      const creator = mockUsers[0]; // 默认当前用户
      const priority = feedbackPriorities.find((p) => p.id === data.priority) || feedbackPriorities[2];
      const status = feedbackStatuses[0];

      const selectedTags = tags.filter((t) => data.tag_ids?.includes(t.id));

      const newFeedback: Feedback = {
        id: feedbacks.length + 1,
        title: data.title,
        description: data.description,
        type: data.type || 'other',
        status: status.id,
        status_name: status.name,
        status_color: status.color,
        priority: priority.id,
        priority_name: priority.name,
        priority_color: priority.color,
        tags: selectedTags,
        tag_ids: data.tag_ids || [],
        creator_id: creator.id,
        creator_name: creator.name,
        creator_avatar: creator.avatar,
        subscribers: [creator.id],
        view_count: 0,
        comment_count: 0,
        attachment_count: data.attachments?.length || 0,
        attachments: data.attachments || [],
        created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
        updated_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      };

      feedbacks.unshift(newFeedback);

      return responseSuccess(newFeedback, '创建成功');
    },
  },

  // 更新反馈
  {
    url: /\/api\/feedback\/update\/\d+/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/update\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = feedbacks.findIndex((f) => f.id === id);

      if (index === -1) {
        return responseError('反馈不存在', 404);
      }

      const priority = feedbackPriorities.find((p) => p.id === data.priority);
      const selectedTags = tags.filter((t) => data.tag_ids?.includes(t.id));

      feedbacks[index] = {
        ...feedbacks[index],
        title: data.title ?? feedbacks[index].title,
        description: data.description ?? feedbacks[index].description,
        type: data.type ?? feedbacks[index].type,
        priority: priority?.id ?? feedbacks[index].priority,
        priority_name: priority?.name ?? feedbacks[index].priority_name,
        priority_color: priority?.color ?? feedbacks[index].priority_color,
        tags: data.tag_ids ? selectedTags : feedbacks[index].tags,
        tag_ids: data.tag_ids ?? feedbacks[index].tag_ids,
        attachments: data.attachments ?? feedbacks[index].attachments,
        attachment_count: data.attachments?.length ?? feedbacks[index].attachment_count,
        updated_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      };

      return responseSuccess(feedbacks[index], '更新成功');
    },
  },

  // 删除反馈
  {
    url: /\/api\/feedback\/delete\/\d+/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/delete\/(\d+)$/)[1]);
      const index = feedbacks.findIndex((f) => f.id === id);

      if (index === -1) {
        return responseError('反馈不存在', 404);
      }

      // 删除相关评论
      comments = comments.filter((c) => c.feedback_id !== id);

      // 删除反馈
      feedbacks.splice(index, 1);

      return responseSuccess(null, '删除成功');
    },
  },

  // 更新反馈状态
  {
    url: /\/api\/feedback\/status\/\d+/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/status\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = feedbacks.findIndex((f) => f.id === id);

      if (index === -1) {
        return responseError('反馈不存在', 404);
      }

      const status = feedbackStatuses.find((s) => s.id === data.status);
      if (!status) {
        return responseError('状态不存在', 400);
      }

      feedbacks[index].status = status.id;
      feedbacks[index].status_name = status.name;
      feedbacks[index].status_color = status.color;
      feedbacks[index].updated_at = new Date().toISOString().slice(0, 19).replace('T', ' ');

      if (status.id === 'resolved') {
        feedbacks[index].resolved_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
      }
      if (['closed', 'rejected'].includes(status.id)) {
        feedbacks[index].closed_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
      }

      return responseSuccess(feedbacks[index], '状态更新成功');
    },
  },

  // 指派反馈
  {
    url: /\/api\/feedback\/assign\/\d+/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/assign\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = feedbacks.findIndex((f) => f.id === id);

      if (index === -1) {
        return responseError('反馈不存在', 404);
      }

      const assignee = mockUsers.find((u) => u.id === data.assignee_id);

      feedbacks[index].assignee_id = data.assignee_id;
      feedbacks[index].assignee_name = assignee?.name;
      feedbacks[index].assignee_avatar = assignee?.avatar;
      feedbacks[index].updated_at = new Date().toISOString().slice(0, 19).replace('T', ' ');

      return responseSuccess(feedbacks[index], '指派成功');
    },
  },

  // 订阅/取消订阅反馈
  {
    url: /\/api\/feedback\/subscribe\/\d+/,
    method: 'post',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/subscribe\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = feedbacks.findIndex((f) => f.id === id);

      if (index === -1) {
        return responseError('反馈不存在', 404);
      }

      const userId = data.user_id || 1;
      const isSubscribe = data.subscribe !== false;

      if (isSubscribe) {
        if (!feedbacks[index].subscribers.includes(userId)) {
          feedbacks[index].subscribers.push(userId);
        }
        return responseSuccess(null, '订阅成功');
      } else {
        feedbacks[index].subscribers = feedbacks[index].subscribers.filter(
          (id) => id !== userId
        );
        return responseSuccess(null, '取消订阅成功');
      }
    },
  },

  // ==================== 评论管理 ====================

  // 获取评论列表
  {
    url: /\/api\/feedback\/comments\/\d+/,
    method: 'get',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/comments\/(\d+)/)[1]);
      const urlObj = new URL(config.url, 'http://localhost');
      const includeInternal = urlObj.searchParams.get('include_internal') === 'true';

      let feedbackComments = comments.filter((c) => c.feedback_id === id);

      // 如果不包含内部评论，则过滤掉
      if (!includeInternal) {
        feedbackComments = feedbackComments.filter((c) => !c.is_internal);
      }

      // 构建评论树
      const buildCommentTree = (list: FeedbackComment[], parentId?: number): FeedbackComment[] => {
        return list
          .filter((item) => item.parent_id === parentId)
          .map((item) => ({
            ...item,
            children: buildCommentTree(list, item.id),
          }));
      };

      const commentTree = buildCommentTree(feedbackComments);

      // 按时间倒序排列顶级评论
      commentTree.sort(
        (a, b) =>
          new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
      );

      return responseSuccess(commentTree);
    },
  },

  // 创建评论
  {
    url: '/api/feedback/comment',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);
      const author = mockUsers[Math.floor(Math.random() * mockUsers.length)];

      const newComment: FeedbackComment = {
        id: comments.length + 1,
        feedback_id: data.feedback_id,
        content: data.content,
        author_id: author.id,
        author_name: author.name,
        author_avatar: author.avatar,
        parent_id: data.parent_id,
        reply_to: data.reply_to,
        is_internal: data.is_internal || false,
        attachments: data.attachments,
        created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      };

      comments.push(newComment);

      // 更新反馈评论数
      const feedback = feedbacks.find((f) => f.id === data.feedback_id);
      if (feedback) {
        feedback.comment_count++;
        feedback.updated_at = newComment.created_at;
      }

      return responseSuccess(newComment, '评论成功');
    },
  },

  // 更新评论
  {
    url: /\/api\/feedback\/comment\/\d+/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/comment\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = comments.findIndex((c) => c.id === id);

      if (index === -1) {
        return responseError('评论不存在', 404);
      }

      comments[index] = {
        ...comments[index],
        content: data.content ?? comments[index].content,
        attachments: data.attachments ?? comments[index].attachments,
        updated_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      };

      return responseSuccess(comments[index], '更新成功');
    },
  },

  // 删除评论
  {
    url: /\/api\/feedback\/comment\/\d+/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/comment\/(\d+)$/)[1]);
      const index = comments.findIndex((c) => c.id === id);

      if (index === -1) {
        return responseError('评论不存在', 404);
      }

      const feedbackId = comments[index].feedback_id;

      // 删除该评论及其子评论
      const deleteIds = [id];
      const findChildren = (parentId: number) => {
        comments
          .filter((c) => c.parent_id === parentId)
          .forEach((c) => {
            deleteIds.push(c.id);
            findChildren(c.id);
          });
      };
      findChildren(id);

      comments = comments.filter((c) => !deleteIds.includes(c.id));

      // 更新反馈评论数
      const feedback = feedbacks.find((f) => f.id === feedbackId);
      if (feedback) {
        feedback.comment_count = comments.filter((c) => c.feedback_id === feedbackId).length;
      }

      return responseSuccess(null, '删除成功');
    },
  },

  // ==================== 标签管理 ====================

  // 获取标签列表
  {
    url: '/api/feedback/tags',
    method: 'get',
    response: (config: any) => {
      const url = new URL(config.url, 'http://localhost');
      const keyword = url.searchParams.get('keyword') || '';

      let filteredTags = [...tags];

      if (keyword) {
        filteredTags = filteredTags.filter((t) =>
          t.name.toLowerCase().includes(keyword.toLowerCase())
        );
      }

      return responseSuccess(filteredTags);
    },
  },

  // 创建标签
  {
    url: '/api/feedback/tag',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body);

      // 检查名称是否重复
      if (tags.some((t) => t.name === data.name)) {
        return responseError('标签名称已存在', 400);
      }

      const newTag: FeedbackTag = {
        id: tags.length + 1,
        name: data.name,
        color: data.color || '#165dff',
        description: data.description || '',
        count: 0,
        status: 1,
        created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      };

      tags.push(newTag);

      return responseSuccess(newTag, '创建成功');
    },
  },

  // 更新标签
  {
    url: /\/api\/feedback\/tag\/\d+/,
    method: 'put',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/tag\/(\d+)$/)[1]);
      const data = JSON.parse(config.body);
      const index = tags.findIndex((t) => t.id === id);

      if (index === -1) {
        return responseError('标签不存在', 404);
      }

      // 检查名称是否重复（排除自身）
      if (data.name && tags.some((t) => t.name === data.name && t.id !== id)) {
        return responseError('标签名称已存在', 400);
      }

      tags[index] = {
        ...tags[index],
        name: data.name ?? tags[index].name,
        color: data.color ?? tags[index].color,
        description: data.description ?? tags[index].description,
        status: data.status ?? tags[index].status,
        updated_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      };

      // 更新所有反馈中的标签信息
      feedbacks.forEach((feedback) => {
        const tagIndex = feedback.tags.findIndex((t) => t.id === id);
        if (tagIndex !== -1) {
          feedback.tags[tagIndex] = { ...tags[index] };
        }
      });

      return responseSuccess(tags[index], '更新成功');
    },
  },

  // 删除标签
  {
    url: /\/api\/feedback\/tag\/\d+/,
    method: 'delete',
    response: (config: any) => {
      const id = parseInt(config.url.match(/\/api\/feedback\/tag\/(\d+)$/)[1]);
      const index = tags.findIndex((t) => t.id === id);

      if (index === -1) {
        return responseError('标签不存在', 404);
      }

      // 检查是否有反馈使用该标签
      const usedCount = feedbacks.filter((f) => f.tag_ids.includes(id)).length;
      if (usedCount > 0) {
        return responseError(`该标签已被 ${usedCount} 个反馈使用，无法删除`, 400);
      }

      tags.splice(index, 1);

      return responseSuccess(null, '删除成功');
    },
  },

  // ==================== 统计与排行 ====================

  // 获取统计数据
  {
    url: '/api/feedback/statistics',
    method: 'get',
    response: () => {
      const total = feedbacks.length;
      const pending = feedbacks.filter((f) => f.status === 'pending').length;
      const processing = feedbacks.filter((f) => f.status === 'processing').length;
      const resolved = feedbacks.filter((f) => f.status === 'resolved').length;
      const closed = feedbacks.filter((f) => ['closed', 'rejected'].includes(f.status)).length;

      const urgent = feedbacks.filter((f) => f.priority === 'urgent').length;
      const high = feedbacks.filter((f) => f.priority === 'high').length;

      // 按类型统计
      const typeStats: Record<string, number> = {};
      feedbackTypes.forEach((type) => {
        typeStats[type] = feedbacks.filter((f) => f.type === type).length;
      });

      // 按状态统计
      const statusStats = feedbackStatuses.map((s) => ({
        id: s.id,
        name: s.name,
        color: s.color,
        count: feedbacks.filter((f) => f.status === s.id).length,
      }));

      return responseSuccess({
        total,
        pending,
        processing,
        resolved,
        closed,
        urgent,
        high,
        type_stats: typeStats,
        status_stats: statusStats,
        today_new: Math.floor(Math.random() * 10),
        week_new: Math.floor(Math.random() * 50),
        avg_resolve_time: Math.floor(Math.random() * 72) + 24, // 平均解决时间（小时）
        satisfaction_rate: 85 + Math.floor(Math.random() * 15), // 满意度（%）
      });
    },
  },

  // 获取趋势数据
  {
    url: '/api/feedback/trend',
    method: 'get',
    response: (config: any) => {
      const url = new URL(config.url, 'http://localhost');
      const days = Number(url.searchParams.get('days')) || 7;

      const trendData = [];
      for (let i = days - 1; i >= 0; i--) {
        const date = new Date();
        date.setDate(date.getDate() - i);
        const dateStr = date.toISOString().slice(0, 10);

        trendData.push({
          date: dateStr,
          new: Math.floor(Math.random() * 10),
          resolved: Math.floor(Math.random() * 8),
          pending: Math.floor(Math.random() * 5),
        });
      }

      return responseSuccess(trendData);
    },
  },

  // 获取处理人排行
  {
    url: '/api/feedback/ranking',
    method: 'get',
    response: () => {
      const rankings: HandlerRanking[] = mockUsers.map((user) => ({
        user_id: user.id,
        user_name: user.name,
        user_avatar: user.avatar,
        resolved_count: Math.floor(Math.random() * 50) + 10,
        avg_resolve_time: Math.floor(Math.random() * 48) + 12,
        satisfaction_rate: 80 + Math.floor(Math.random() * 20),
      }));

      // 按解决数量排序
      rankings.sort((a, b) => b.resolved_count - a.resolved_count);

      return responseSuccess(rankings);
    },
  },

  // ==================== 批量操作 ====================

  // 批量更新状态
  {
    url: '/api/feedback/batch/status',
    method: 'put',
    response: (config: any) => {
      const data = JSON.parse(config.body);
      const { ids, status } = data;

      const statusInfo = feedbackStatuses.find((s) => s.id === status);
      if (!statusInfo) {
        return responseError('状态不存在', 400);
      }

      let updatedCount = 0;
      ids.forEach((id: number) => {
        const feedback = feedbacks.find((f) => f.id === id);
        if (feedback) {
          feedback.status = status;
          feedback.status_name = statusInfo.name;
          feedback.status_color = statusInfo.color;
          feedback.updated_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
          updatedCount++;
        }
      });

      return responseSuccess({ updated_count: updatedCount }, `成功更新 ${updatedCount} 条反馈`);
    },
  },

  // 批量指派
  {
    url: '/api/feedback/batch/assign',
    method: 'put',
    response: (config: any) => {
      const data = JSON.parse(config.body);
      const { ids, assignee_id } = data;

      const assignee = mockUsers.find((u) => u.id === assignee_id);

      let updatedCount = 0;
      ids.forEach((id: number) => {
        const feedback = feedbacks.find((f) => f.id === id);
        if (feedback) {
          feedback.assignee_id = assignee_id;
          feedback.assignee_name = assignee?.name;
          feedback.assignee_avatar = assignee?.avatar;
          feedback.updated_at = new Date().toISOString().slice(0, 19).replace('T', ' ');
          updatedCount++;
        }
      });

      return responseSuccess({ updated_count: updatedCount }, `成功指派 ${updatedCount} 条反馈`);
    },
  },

  // 批量删除
  {
    url: '/api/feedback/batch/delete',
    method: 'delete',
    response: (config: any) => {
      const data = JSON.parse(config.body);
      const { ids } = data;

      let deletedCount = 0;
      ids.forEach((id: number) => {
        const index = feedbacks.findIndex((f) => f.id === id);
        if (index !== -1) {
          // 删除相关评论
          comments = comments.filter((c) => c.feedback_id !== id);
          // 删除反馈
          feedbacks.splice(index, 1);
          deletedCount++;
        }
      });

      return responseSuccess({ deleted_count: deletedCount }, `成功删除 ${deletedCount} 条反馈`);
    },
  },

  // ==================== 其他接口 ====================

  // 获取反馈类型列表
  {
    url: '/api/feedback/types',
    method: 'get',
    response: () => {
      return responseSuccess(
        feedbackTypes.map((type) => ({
          id: type,
          name: feedbackTypeNames[type],
        }))
      );
    },
  },

  // 导出反馈数据
  {
    url: '/api/feedback/export',
    method: 'post',
    response: () => {
      return responseSuccess(
        { url: '/downloads/feedback_export.xlsx' },
        '导出成功'
      );
    },
  },
];

// 导出数据供其他模块使用
export {
  feedbacks,
  comments,
  tags,
  mockUsers,
};
