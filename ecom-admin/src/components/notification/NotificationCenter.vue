<template>
  <a-badge :count="unreadCount" :offset="[-5, 5]">
    <a-button type="text" @click="handleOpen">
      <template #icon>
        <icon-notification />
      </template>
    </a-button>
  </a-badge>

  <a-drawer
    v-model:visible="visible"
    title="通知中心"
    width="400px"
    :footer="false"
  >
    <div class="notification-list">
      <a-empty v-if="notifications.length === 0" description="暂无通知" />

      <div
        v-for="notification in notifications"
        :key="notification.id"
        class="notification-item"
        :class="{ unread: !notification.read }"
        @click="handleNotificationClick(notification)"
      >
        <div class="notification-header">
          <span class="notification-type">
            <a-tag :color="getTypeColor(notification.type)">
              {{ getTypeText(notification.type) }}
            </a-tag>
          </span>
          <span class="notification-time">
            {{ formatRelativeTime(notification.timestamp) }}
          </span>
        </div>

        <div class="notification-content">
          {{ notification.content }}
        </div>

        <div v-if="!notification.read" class="unread-indicator"></div>
      </div>
    </div>

    <template #footer>
      <a-space>
        <a-button @click="handleMarkAllRead">全部已读</a-button>
        <a-button @click="handleClearAll">清空</a-button>
      </a-space>
    </template>
  </a-drawer>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import { websocketService, type WebSocketMessage } from '@/services/websocket';
import { formatRelativeTime } from '@/utils/date';

interface Notification {
  id: string;
  type: string;
  content: string;
  timestamp: number;
  read: boolean;
  data?: any;
}

const router = useRouter();

const visible = ref(false);
const notifications = ref<Notification[]>([]);

// 未读数量
const unreadCount = computed(() => {
  return notifications.value.filter((n) => !n.read).length;
});

// 打开通知中心
const handleOpen = () => {
  visible.value = true;
};

// 点击通知
const handleNotificationClick = (notification: Notification) => {
  // 标记为已读
  notification.read = true;

  // 根据通知类型跳转
  if (notification.type === 'feedback_update' && notification.data?.feedback_id) {
    router.push(`/quality-center/feedback/${notification.data.feedback_id}`);
    visible.value = false;
  }
};

// 标记全部已读
const handleMarkAllRead = () => {
  notifications.value.forEach((n) => {
    n.read = true;
  });
  Message.success('已全部标记为已读');
};

// 清空通知
const handleClearAll = () => {
  notifications.value = [];
  Message.success('已清空所有通知');
};

// 获取类型文本
const getTypeText = (type: string) => {
  const map: Record<string, string> = {
    feedback_update: '反馈更新',
    feedback_assign: '反馈指派',
    feedback_follow_up: '反馈跟进',
  };
  return map[type] || type;
};

// 获取类型颜色
const getTypeColor = (type: string) => {
  const map: Record<string, string> = {
    feedback_update: 'blue',
    feedback_assign: 'orange',
    feedback_follow_up: 'green',
  };
  return map[type] || 'gray';
};

// 处理 WebSocket 消息
const handleWebSocketMessage = (message: WebSocketMessage) => {
  const notification: Notification = {
    id: `${Date.now()}-${Math.random()}`,
    type: message.type,
    content: formatNotificationContent(message),
    timestamp: message.timestamp,
    read: false,
    data: message.data,
  };

  notifications.value.unshift(notification);

  // 限制通知数量
  if (notifications.value.length > 50) {
    notifications.value = notifications.value.slice(0, 50);
  }

  // 显示桌面通知
  showDesktopNotification(notification);
};

// 格式化通知内容
const formatNotificationContent = (message: WebSocketMessage): string => {
  switch (message.type) {
    case 'feedback_update':
      return `反馈"${message.data.title}"状态已更新为"${message.data.status}"`;
    case 'feedback_assign':
      return `反馈"${message.data.title}"已指派给您`;
    case 'feedback_follow_up':
      return `反馈"${message.data.title}"有新的跟进记录`;
    default:
      return '您有新的通知';
  }
};

// 显示桌面通知
const showDesktopNotification = (notification: Notification) => {
  if ('Notification' in window && Notification.permission === 'granted') {
    new Notification('质量中心通知', {
      body: notification.content,
      icon: '/favicon.ico',
    });
  }
};

// 请求桌面通知权限
const requestNotificationPermission = () => {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }
};

// 生命周期
let unsubscribe: (() => void) | null = null;

onMounted(() => {
  // 连接 WebSocket
  websocketService.connect();

  // 订阅消息
  unsubscribe = websocketService.subscribe(handleWebSocketMessage);

  // 请求桌面通知权限
  requestNotificationPermission();
});

onBeforeUnmount(() => {
  // 取消订阅
  if (unsubscribe) {
    unsubscribe();
  }
});
</script>

<style scoped lang="less">
.notification-list {
  .notification-item {
    position: relative;
    padding: 16px;
    border-bottom: 1px solid var(--color-border-2);
    cursor: pointer;
    transition: background-color 0.2s;

    &:hover {
      background-color: var(--color-fill-2);
    }

    &.unread {
      background-color: var(--color-primary-light-1);
    }

    .notification-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 8px;

      .notification-time {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }

    .notification-content {
      font-size: 14px;
      color: var(--color-text-2);
      line-height: 1.6;
    }

    .unread-indicator {
      position: absolute;
      top: 20px;
      right: 16px;
      width: 8px;
      height: 8px;
      background-color: var(--color-primary);
      border-radius: 50%;
    }
  }
}
</style>
