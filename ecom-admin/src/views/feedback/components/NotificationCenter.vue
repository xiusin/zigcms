<template>
  <div class="feedback-notification-center">
    <a-popover
      trigger="click"
      position="br"
      :popup-visible="visible"
      @popup-visible-change="handleVisibleChange"
    >
      <a-badge :count="unreadCount" :max-count="99">
        <a-button type="secondary" shape="circle" size="small">
          <template #icon>
            <icon-notification />
          </template>
        </a-button>
      </a-badge>
      <template #content>
        <div class="notification-dropdown">
          <!-- 头部 -->
          <div class="notification-header">
            <div class="header-title">
              <span>反馈通知</span>
              <a-tag v-if="unreadCount > 0" color="red" size="small">
                {{ unreadCount }} 条未读
              </a-tag>
            </div>
            <div class="header-actions">
              <a-link
                v-if="unreadCount > 0"
                size="small"
                :loading="notificationStore.isActionLoading"
                @click="handleMarkAllRead"
              >
                全部已读
              </a-link>
              <a-divider direction="vertical" />
              <a-link size="small" @click="goToSettings">
                <template #icon><icon-settings /></template>
                设置
              </a-link>
            </div>
          </div>

          <!-- 标签页 -->
          <a-tabs v-model:active-key="activeTab" type="rounded" size="small">
            <a-tab-pane key="all" title="全部">
              <NotificationList
                :notifications="filteredNotifications"
                :loading="notificationStore.isLoading"
                @item-click="handleNotificationClick"
                @mark-read="handleMarkRead"
                @delete="handleDelete"
              />
            </a-tab-pane>
            <a-tab-pane key="unread" :title="`未读 (${unreadCount})`">
              <NotificationList
                :notifications="unreadNotifications"
                :loading="notificationStore.isLoading"
                @item-click="handleNotificationClick"
                @mark-read="handleMarkRead"
                @delete="handleDelete"
              />
            </a-tab-pane>
            <a-tab-pane
              v-for="type in notificationTypes"
              :key="type.value"
              :title="`${type.label} (${getTypeUnreadCount(type.value)})`"
            >
              <NotificationList
                :notifications="getNotificationsByType(type.value)"
                :loading="notificationStore.isLoading"
                @item-click="handleNotificationClick"
                @mark-read="handleMarkRead"
                @delete="handleDelete"
              />
            </a-tab-pane>
          </a-tabs>

          <!-- 底部 -->
          <div class="notification-footer">
            <a-link size="small" @click="goToNotificationList">
              查看全部通知
              <icon-right />
            </a-link>
          </div>
        </div>
      </template>
    </a-popover>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import useFeedbackNotificationStore from '@/store/modules/feedback-notification';
import {
  NotificationType,
  type FeedbackNotification,
} from '@/api/feedback-notification';
import NotificationList from './NotificationList.vue';

const router = useRouter();
const notificationStore = useFeedbackNotificationStore();

// ========== 状态定义 ==========
const visible = ref(false);
const activeTab = ref('all');

// ========== 通知类型配置 ==========
const notificationTypes = [
  { value: NotificationType.ASSIGNED, label: '指派' },
  { value: NotificationType.STATUS_CHANGED, label: '状态变更' },
  { value: NotificationType.NEW_COMMENT, label: '评论' },
  { value: NotificationType.MENTIONED, label: '@提及' },
  { value: NotificationType.FEEDBACK_CLOSED, label: '关闭' },
  { value: NotificationType.FEEDBACK_RESOLVED, label: '已解决' },
];

// ========== 计算属性 ==========
const unreadCount = computed(() => notificationStore.getUnreadCount);

const filteredNotifications = computed(() => {
  if (activeTab.value === 'unread') {
    return notificationStore.getUnreadNotifications;
  }
  if (activeTab.value === 'all') {
    return notificationStore.getAllNotifications;
  }
  return notificationStore.getNotificationsByType(
    activeTab.value as NotificationType
  );
});

const unreadNotifications = computed(
  () => notificationStore.getUnreadNotifications
);

const getNotificationsByType = (type: NotificationType) => {
  return notificationStore.getNotificationsByType(type);
};

const getTypeUnreadCount = (type: NotificationType): number => {
  return notificationStore.unreadByType[type] || 0;
};

// ========== 方法 ==========
const handleVisibleChange = (val: boolean) => {
  visible.value = val;
  if (val) {
    // 打开时刷新通知列表
    notificationStore.fetchNotifications();
  }
};

const handleMarkAllRead = async () => {
  try {
    await notificationStore.markAllAsRead();
    Message.success('已全部标记为已读');
  } catch (error) {
    Message.error('标记已读失败');
  }
};

const handleMarkRead = async (notification: FeedbackNotification) => {
  try {
    await notificationStore.markAsRead({ ids: [notification.id] });
  } catch (error) {
    Message.error('标记已读失败');
  }
};

const handleDelete = async (notification: FeedbackNotification) => {
  try {
    await notificationStore.deleteNotifications({ ids: [notification.id] });
    Message.success('删除成功');
  } catch (error) {
    Message.error('删除失败');
  }
};

const handleNotificationClick = (notification: FeedbackNotification) => {
  // 标记为已读
  if (!notification.is_read) {
    notificationStore.markAsRead({ ids: [notification.id] });
  }
  // 关闭弹窗
  visible.value = false;
  // 跳转到反馈详情
  router.push({
    name: 'feedback-detail',
    params: { id: notification.feedback_id },
  });
};

const goToSettings = () => {
  visible.value = false;
  router.push({ name: 'feedback-notification-settings' });
};

const goToNotificationList = () => {
  visible.value = false;
  router.push({ name: 'feedback-notifications' });
};

// ========== 生命周期 ==========
onMounted(() => {
  // 初始化通知模块
  notificationStore.init();
});

onUnmounted(() => {
  // 停止轮询
  notificationStore.stopPolling();
});
</script>

<style scoped lang="less">
.feedback-notification-center {
  display: inline-flex;
}

.notification-dropdown {
  width: 420px;
  max-height: 600px;
  display: flex;
  flex-direction: column;

  :deep(.arco-tabs-content) {
    padding-top: 0;
  }
}

.notification-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  border-bottom: 1px solid var(--color-border);

  .header-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-weight: 500;
    font-size: 14px;
  }

  .header-actions {
    display: flex;
    align-items: center;
  }
}

.notification-footer {
  padding: 12px 16px;
  text-align: center;
  border-top: 1px solid var(--color-border);

  :deep(.arco-link) {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
}
</style>
