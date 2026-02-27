/**
 * 反馈系统通知 Mock 数据
 * 包含通知列表、未读统计、通知设置等功能
 */

import Mock from 'mockjs';
import { feedbacks, mockUsers } from './feedback';

// ==================== 类型定义 ====================

/**
 * 通知类型
 */
export type NotificationType =
  | 'assigned'
  | 'status_changed'
  | 'new_comment'
  | 'mentioned'
  | 'feedback_closed'
  | 'feedback_resolved';

/**
 * 通知对象
 */
export interface FeedbackNotification {
  id: number;
  type: NotificationType;
  title: string;
  content: string;
  feedback_id: number;
  feedback_title: string;
  trigger_user_id: number;
  trigger_user_name: string;
  trigger_user_avatar?: string;
  is_read: boolean;
  priority: number;
  created_at: string;
  read_at?: string;
  extra_data?: Record<string, any>;
}

/**
 * 通知设置
 */
export interface NotificationSettings {
  user_id: number;
  notify_assigned: boolean;
  notify_status_changed: boolean;
  notify_new_comment: boolean;
  notify_mentioned: boolean;
  notify_feedback_closed: boolean;
  email_notification: boolean;
  browser_notification: boolean;
  do_not_disturb: boolean;
  do_not_disturb_start?: string;
  do_not_disturb_end?: string;
  updated_at?: string;
}

// ==================== 响应格式化工具 ====================

const responseSuccess = (data: any, msg = 'success') => ({
  code: 0,
  msg,
  data,
});

const responseError = (msg: string, code = 400) => ({
  code,
  msg,
  data: null,
});

// ==================== 数据存储 ====================

// 通知数据存储
let notifications: FeedbackNotification[] = [];

// 通知设置存储
let notificationSettings: NotificationSettings = {
  user_id: 1,
  notify_assigned: true,
  notify_status_changed: true,
  notify_new_comment: true,
  notify_mentioned: true,
  notify_feedback_closed: true,
  email_notification: false,
  browser_notification: false,
  do_not_disturb: false,
  do_not_disturb_start: '22:00',
  do_not_disturb_end: '08:00',
  updated_at: new Date().toISOString(),
};

// ==================== 数据生成函数 ====================

/**
 * 生成随机通知数据
 */
const generateMockNotifications = () => {
  const notificationList: FeedbackNotification[] = [];

  const notificationTemplates: Record<
    NotificationType,
    { title: string; content: string }
  > = {
    assigned: {
      title: '反馈被指派',
      content: '将反馈指派给您处理',
    },
    status_changed: {
      title: '状态变更',
      content: '将反馈状态变更为',
    },
    new_comment: {
      title: '新评论',
      content: '在反馈中添加了新评论',
    },
    mentioned: {
      title: '被@提及',
      content: '在评论中@了您',
    },
    feedback_closed: {
      title: '反馈已关闭',
      content: '关闭了该反馈',
    },
    feedback_resolved: {
      title: '反馈已解决',
      content: '将该反馈标记为已解决',
    },
  };

  const types: NotificationType[] = [
    'assigned',
    'status_changed',
    'new_comment',
    'mentioned',
    'feedback_closed',
    'feedback_resolved',
  ];

  // 为每个反馈生成 0-3 条通知
  feedbacks.forEach((feedback, index) => {
    const notificationCount = Math.floor(Math.random() * 4);

    for (let i = 0; i < notificationCount; i++) {
      const type = types[Math.floor(Math.random() * types.length)];
      const template = notificationTemplates[type];
      const triggerUser =
        mockUsers[Math.floor(Math.random() * mockUsers.length)];
      const isRead = Math.random() > 0.4; // 60% 已读
      const createdAt = new Date(
        Date.now() - Math.random() * 7 * 24 * 60 * 60 * 1000
      );

      notificationList.push({
        id: notificationList.length + 1,
        type,
        title: template.title,
        content: `${triggerUser.name}${template.content}`,
        feedback_id: feedback.id,
        feedback_title: feedback.title,
        trigger_user_id: triggerUser.id,
        trigger_user_name: triggerUser.name,
        trigger_user_avatar: triggerUser.avatar,
        is_read: isRead,
        priority: Math.floor(Math.random() * 4),
        created_at: createdAt.toISOString(),
        read_at: isRead ? new Date(createdAt.getTime() + 3600000).toISOString() : undefined,
        extra_data: {
          old_status:
            type === 'status_changed'
              ? ['pending', 'processing', 'waiting_verify'][
                  Math.floor(Math.random() * 3)
                ]
              : undefined,
          new_status:
            type === 'status_changed'
              ? ['processing', 'waiting_verify', 'resolved'][
                  Math.floor(Math.random() * 3)
                ]
              : undefined,
        },
      });
    }
  });

  // 按时间倒序排列
  notificationList.sort(
    (a, b) =>
      new Date(b.created_at).getTime() - new Date(a.created_at).getTime()
  );

  return notificationList;
};

// 初始化数据
notifications = generateMockNotifications();

// ==================== Mock 接口实现 ====================

export default [
  // ==================== 通知列表 ====================

  // 获取通知列表
  {
    url: '/api/feedback/notification/list',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body || '{}');
      const page = data.page || 1;
      const pageSize = data.pageSize || 20;
      const unreadOnly = data.unread_only || false;
      const type = data.type as NotificationType | undefined;

      let filteredList = [...notifications];

      // 只显示未读
      if (unreadOnly) {
        filteredList = filteredList.filter((n) => !n.is_read);
      }

      // 按类型筛选
      if (type) {
        filteredList = filteredList.filter((n) => n.type === type);
      }

      const total = filteredList.length;
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      const pageList = filteredList.slice(start, end);

      return responseSuccess({
        list: pageList,
        total,
        page,
        pageSize,
      });
    },
  },

  // 获取未读通知数量
  {
    url: '/api/feedback/notification/unread-count',
    method: 'post',
    response: () => {
      const unreadNotifications = notifications.filter((n) => !n.is_read);
      const byType: Record<NotificationType, number> = {
        assigned: 0,
        status_changed: 0,
        new_comment: 0,
        mentioned: 0,
        feedback_closed: 0,
        feedback_resolved: 0,
      };

      unreadNotifications.forEach((n) => {
        byType[n.type]++;
      });

      return responseSuccess({
        total: unreadNotifications.length,
        by_type: byType,
      });
    },
  },

  // 获取最新通知（用于轮询）
  {
    url: '/api/feedback/notification/latest',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body || '{}');
      const lastId = data.last_id || 0;

      // 获取比 lastId 更新的通知
      const newNotifications = notifications.filter((n) => n.id > lastId);

      return responseSuccess({
        list: newNotifications,
        count: newNotifications.length,
      });
    },
  },

  // ==================== 通知操作 ====================

  // 标记通知为已读
  {
    url: '/api/feedback/notification/mark-read',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body || '{}');
      const ids = data.ids as number[] | undefined;

      if (ids && ids.length > 0) {
        // 标记指定通知为已读
        ids.forEach((id) => {
          const notification = notifications.find((n) => n.id === id);
          if (notification && !notification.is_read) {
            notification.is_read = true;
            notification.read_at = new Date().toISOString();
          }
        });
        return responseSuccess(null, `已标记 ${ids.length} 条通知为已读`);
      } else {
        // 标记所有未读通知为已读
        let count = 0;
        notifications.forEach((n) => {
          if (!n.is_read) {
            n.is_read = true;
            n.read_at = new Date().toISOString();
            count++;
          }
        });
        return responseSuccess(null, `已标记 ${count} 条通知为已读`);
      }
    },
  },

  // 标记所有通知为已读
  {
    url: '/api/feedback/notification/mark-all-read',
    method: 'post',
    response: () => {
      let count = 0;
      notifications.forEach((n) => {
        if (!n.is_read) {
          n.is_read = true;
          n.read_at = new Date().toISOString();
          count++;
        }
      });
      return responseSuccess(null, `已标记 ${count} 条通知为已读`);
    },
  },

  // 删除通知
  {
    url: '/api/feedback/notification/delete',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body || '{}');
      const ids = data.ids as number[];

      if (!ids || ids.length === 0) {
        return responseError('请选择要删除的通知');
      }

      notifications = notifications.filter((n) => !ids.includes(n.id));
      return responseSuccess(null, `已删除 ${ids.length} 条通知`);
    },
  },

  // ==================== 通知设置 ====================

  // 获取通知设置
  {
    url: '/api/feedback/notification/settings',
    method: 'post',
    response: () => {
      return responseSuccess(notificationSettings);
    },
  },

  // 更新通知设置
  {
    url: '/api/feedback/notification/settings/update',
    method: 'post',
    response: (config: any) => {
      const data = JSON.parse(config.body || '{}');

      notificationSettings = {
        ...notificationSettings,
        ...data,
        updated_at: new Date().toISOString(),
      };

      return responseSuccess(notificationSettings, '设置已保存');
    },
  },
];

// 导出数据供其他模块使用
export { notifications, notificationSettings };
