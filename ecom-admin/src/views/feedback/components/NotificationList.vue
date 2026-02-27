<template>
  <div class="notification-list-container">
    <a-spin :loading="loading" style="display: block">
      <a-scrollbar style="height: 360px; overflow-y: auto">
        <div v-if="notifications.length === 0" class="empty-state">
          <a-empty description="暂无通知" />
        </div>
        <div v-else class="notification-list">
          <div
            v-for="notification in notifications"
            :key="notification.id"
            class="notification-item"
            :class="{ unread: !notification.is_read }"
            @click="handleItemClick(notification)"
          >
            <!-- 左侧图标 -->
            <div class="item-icon" :class="`type-${notification.type}`">
              <icon-user-add v-if="notification.type === 'assigned'" />
              <icon-swap v-else-if="notification.type === 'status_changed'" />
              <icon-message v-else-if="notification.type === 'new_comment'" />
              <icon-at v-else-if="notification.type === 'mentioned'" />
              <icon-close-circle v-else-if="notification.type === 'feedback_closed'" />
              <icon-check-circle v-else-if="notification.type === 'feedback_resolved'" />
              <icon-info-circle v-else />
            </div>

            <!-- 中间内容 -->
            <div class="item-content">
              <div class="content-header">
                <span class="title">{{ notification.title }}</span>
                <a-tag
                  v-if="!notification.is_read"
                  size="small"
                  color="red"
                  class="unread-tag"
                >
                  未读
                </a-tag>
              </div>
              <div class="content-body">
                <p class="feedback-title">{{ notification.feedback_title }}</p>
                <p class="content-text">{{ notification.content }}</p>
              </div>
              <div class="content-footer">
                <a-avatar
                  v-if="notification.trigger_user_avatar"
                  :size="16"
                  :src="notification.trigger_user_avatar"
                />
                <a-avatar v-else :size="16">
                  <icon-user />
                </a-avatar>
                <span class="trigger-user">{{ notification.trigger_user_name }}</span>
                <span class="time">{{ formatTime(notification.created_at) }}</span>
              </div>
            </div>

            <!-- 右侧操作 -->
            <div class="item-actions" @click.stop>
              <a-tooltip v-if="!notification.is_read" content="标记为已读">
                <a-button
                  type="text"
                  size="mini"
                  @click="handleMarkRead(notification)"
                >
                  <template #icon><icon-check /></template>
                </a-button>
              </a-tooltip>
              <a-tooltip content="删除">
                <a-button
                  type="text"
                  size="mini"
                  status="danger"
                  @click="handleDelete(notification)"
                >
                  <template #icon><icon-delete /></template>
                </a-button>
              </a-tooltip>
            </div>
          </div>
        </div>
      </a-scrollbar>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import type { FeedbackNotification } from '@/api/feedback-notification';

interface Props {
  notifications: FeedbackNotification[];
  loading?: boolean;
}

withDefaults(defineProps<Props>(), {
  loading: false,
});

const emit = defineEmits<{
  (e: 'item-click', notification: FeedbackNotification): void;
  (e: 'mark-read', notification: FeedbackNotification): void;
  (e: 'delete', notification: FeedbackNotification): void;
}>();

const handleItemClick = (notification: FeedbackNotification) => {
  emit('item-click', notification);
};

const handleMarkRead = (notification: FeedbackNotification) => {
  emit('mark-read', notification);
};

const handleDelete = (notification: FeedbackNotification) => {
  emit('delete', notification);
};

const formatTime = (time: string): string => {
  const now = Date.now();
  const diff = now - new Date(time).getTime();
  const minutes = Math.floor(diff / 60000);
  const hours = Math.floor(diff / 3600000);
  const days = Math.floor(diff / 86400000);

  if (minutes < 1) return '刚刚';
  if (minutes < 60) return `${minutes} 分钟前`;
  if (hours < 24) return `${hours} 小时前`;
  if (days < 7) return `${days} 天前`;
  return new Date(time).toLocaleDateString();
};
</script>

<style scoped lang="less">
.notification-list-container {
  .empty-state {
    padding: 40px 0;
  }
}

.notification-list {
  .notification-item {
    display: flex;
    gap: 12px;
    padding: 12px 16px;
    cursor: pointer;
    transition: background 0.2s;
    border-bottom: 1px solid var(--color-border-1);

    &:hover {
      background: var(--color-fill-2);

      .item-actions {
        opacity: 1;
      }
    }

    &.unread {
      background: var(--color-primary-light-1);

      &:hover {
        background: var(--color-primary-light-2);
      }
    }

    &:last-child {
      border-bottom: none;
    }
  }
}

.item-icon {
  flex-shrink: 0;
  width: 36px;
  height: 36px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  font-size: 18px;

  &.type-assigned {
    background: var(--color-primary-light-2);
    color: var(--color-primary);
  }

  &.type-status_changed {
    background: var(--color-warning-light-2);
    color: var(--color-warning);
  }

  &.type-new_comment,
  &.type-mentioned {
    background: var(--color-success-light-2);
    color: var(--color-success);
  }

  &.type-feedback_closed {
    background: var(--color-danger-light-2);
    color: var(--color-danger);
  }

  &.type-feedback_resolved {
    background: var(--color-success-light-2);
    color: var(--color-success);
  }
}

.item-content {
  flex: 1;
  min-width: 0;

  .content-header {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 4px;

    .title {
      font-size: 13px;
      font-weight: 500;
      color: var(--color-text-1);
    }

    .unread-tag {
      flex-shrink: 0;
    }
  }

  .content-body {
    margin-bottom: 6px;

    .feedback-title {
      font-size: 12px;
      color: var(--color-primary);
      margin: 0 0 2px 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }

    .content-text {
      font-size: 12px;
      color: var(--color-text-2);
      margin: 0;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }

  .content-footer {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 11px;
    color: var(--color-text-3);

    .trigger-user {
      color: var(--color-text-2);
    }

    .time {
      margin-left: auto;
    }
  }
}

.item-actions {
  flex-shrink: 0;
  display: flex;
  flex-direction: column;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.2s;

  :deep(.arco-btn) {
    padding: 4px;
    height: auto;
  }
}
</style>
