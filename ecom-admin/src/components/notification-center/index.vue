<template>
  <a-dropdown trigger="click" @select="handleSelect">
    <a-badge :count="unreadCount" dot>
      <a-button size="small" shape="circle">
        <template #icon><icon-notification /></template>
      </a-button>
    </a-badge>
    <template #content>
      <div class="notification-dropdown">
        <div class="notification-header">
          <span>通知中心</span>
          <a-link @click="markAllRead">全部已读</a-link>
        </div>
        <a-tabs v-model:active-key="activeTab" size="small">
          <a-tab-pane key="all" title="全部">
            <div class="notification-list">
              <div
                v-for="item in filteredNotifications"
                :key="item.id"
                class="notification-item"
                :class="{ unread: !item.read }"
                @click="handleNotificationClick(item)"
              >
                <div class="notification-icon" :class="`type-${item.type}`">
                  <icon-info-circle v-if="item.type === 'info'" />
                  <icon-check-circle v-if="item.type === 'success'" />
                  <icon-exclamation-circle v-if="item.type === 'warning'" />
                  <icon-close-circle v-if="item.type === 'error'" />
                </div>
                <div class="notification-content">
                  <div class="notification-title">{{ item.title }}</div>
                  <div class="notification-desc">{{ item.content }}</div>
                  <div class="notification-time">{{
                    formatTime(item.created_at)
                  }}</div>
                </div>
              </div>
              <a-empty
                v-if="filteredNotifications.length === 0"
                description="暂无通知"
              />
            </div>
          </a-tab-pane>
          <a-tab-pane key="unread" :title="`未读 (${unreadCount})`">
            <div class="notification-list">
              <div
                v-for="item in unreadNotifications"
                :key="item.id"
                class="notification-item unread"
                @click="handleNotificationClick(item)"
              >
                <div class="notification-icon" :class="`type-${item.type}`">
                  <icon-info-circle v-if="item.type === 'info'" />
                  <icon-check-circle v-if="item.type === 'success'" />
                  <icon-exclamation-circle v-if="item.type === 'warning'" />
                  <icon-close-circle v-if="item.type === 'error'" />
                </div>
                <div class="notification-content">
                  <div class="notification-title">{{ item.title }}</div>
                  <div class="notification-desc">{{ item.content }}</div>
                  <div class="notification-time">{{
                    formatTime(item.created_at)
                  }}</div>
                </div>
              </div>
              <a-empty
                v-if="unreadNotifications.length === 0"
                description="暂无未读通知"
              />
            </div>
          </a-tab-pane>
        </a-tabs>
        <div class="notification-footer">
          <a-link @click="viewAll">查看全部</a-link>
        </div>
      </div>
    </template>
  </a-dropdown>
</template>

<script setup lang="ts">
  import { ref, computed } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';

  interface Notification {
    id: number;
    type: 'info' | 'success' | 'warning' | 'error';
    title: string;
    content: string;
    read: boolean;
    link?: string;
    created_at: string;
  }

  const router = useRouter();
  const activeTab = ref('all');

  const notifications = ref<Notification[]>([
    {
      id: 1,
      type: 'info',
      title: '系统更新',
      content: '系统将于今晚 22:00 进行维护升级',
      read: false,
      created_at: new Date().toISOString(),
    },
    {
      id: 2,
      type: 'success',
      title: '订单提醒',
      content: '您有 5 个新订单待处理',
      read: false,
      link: '/business/order',
      created_at: new Date(Date.now() - 3600000).toISOString(),
    },
    {
      id: 3,
      type: 'warning',
      title: '库存预警',
      content: '商品 "iPhone 15 Pro" 库存不足',
      read: true,
      link: '/business/warehouse',
      created_at: new Date(Date.now() - 7200000).toISOString(),
    },
  ]);

  const unreadCount = computed(
    () => notifications.value.filter((n) => !n.read).length
  );

  const filteredNotifications = computed(() => {
    if (activeTab.value === 'unread') {
      return notifications.value.filter((n) => !n.read);
    }
    return notifications.value;
  });

  const unreadNotifications = computed(() =>
    notifications.value.filter((n) => !n.read)
  );

  const formatTime = (time: string) => {
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

  const handleNotificationClick = (item: Notification) => {
    item.read = true;
    if (item.link) {
      router.push(item.link);
    }
  };

  const markAllRead = () => {
    notifications.value.forEach((n) => {
      n.read = true;
    });
    Message.success('已全部标记为已读');
  };

  const viewAll = () => {
    router.push('/system/notifications');
  };

  const handleSelect = () => {};
</script>

<style scoped lang="less">
  .notification-dropdown {
    width: 360px;
    max-height: 500px;
    display: flex;
    flex-direction: column;
  }

  .notification-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 12px 16px;
    border-bottom: 1px solid var(--color-border);
    font-weight: 500;
  }

  .notification-list {
    max-height: 400px;
    overflow-y: auto;
  }

  .notification-item {
    display: flex;
    gap: 12px;
    padding: 12px 16px;
    cursor: pointer;
    transition: background 0.2s;
    border-bottom: 1px solid var(--color-border-1);

    &:hover {
      background: var(--color-fill-2);
    }

    &.unread {
      background: var(--color-primary-light-1);
    }
  }

  .notification-icon {
    flex-shrink: 0;
    width: 32px;
    height: 32px;
    display: flex;
    align-items: center;
    justify-content: center;
    border-radius: 50%;
    font-size: 16px;

    &.type-info {
      background: var(--color-info-light-2);
      color: var(--color-info);
    }

    &.type-success {
      background: var(--color-success-light-2);
      color: var(--color-success);
    }

    &.type-warning {
      background: var(--color-warning-light-2);
      color: var(--color-warning);
    }

    &.type-error {
      background: var(--color-danger-light-2);
      color: var(--color-danger);
    }
  }

  .notification-content {
    flex: 1;
    min-width: 0;
  }

  .notification-title {
    font-size: 12px;
    font-weight: 500;
    margin-bottom: 4px;
  }

  .notification-desc {
    font-size: 12px;
    color: var(--color-text-2);
    margin-bottom: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .notification-time {
    font-size: 11px;
    color: var(--color-text-3);
  }

  .notification-footer {
    padding: 12px 16px;
    text-align: center;
    border-top: 1px solid var(--color-border);
  }
</style>
