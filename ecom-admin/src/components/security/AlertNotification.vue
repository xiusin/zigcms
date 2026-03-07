<template>
  <div class="alert-notification">
    <!-- 通知图标和徽章 -->
    <a-badge :count="unreadCount" :offset="[-5, 5]">
      <a-button
        type="text"
        size="large"
        @click="togglePanel"
      >
        <template #icon>
          <icon-notification :style="{ fontSize: '20px' }" />
        </template>
      </a-button>
    </a-badge>

    <!-- 通知面板 -->
    <a-drawer
      v-model:visible="panelVisible"
      title="安全告警通知"
      placement="right"
      :width="400"
      :footer="false"
    >
      <!-- 工具栏 -->
      <div class="notification-toolbar">
        <a-space>
          <a-button
            size="small"
            @click="handleMarkAllRead"
            :disabled="unreadCount === 0"
          >
            全部已读
          </a-button>
          <a-button
            size="small"
            @click="handleClearAll"
            :disabled="notifications.length === 0"
          >
            清空
          </a-button>
          <a-button
            size="small"
            type="text"
            @click="showSettings = true"
          >
            <template #icon>
              <icon-settings />
            </template>
          </a-button>
        </a-space>
      </div>

      <!-- 通知列表 -->
      <div class="notification-list">
        <a-empty v-if="notifications.length === 0" description="暂无通知" />
        
        <div
          v-for="item in notifications"
          :key="item.id"
          class="notification-item"
          :class="{ 'notification-item-unread': !item.read }"
          @click="handleNotificationClick(item)"
        >
          <!-- 告警级别标签 -->
          <a-tag
            :color="getLevelColor(item.alert.level)"
            class="notification-level"
          >
            {{ getLevelLabel(item.alert.level) }}
          </a-tag>

          <!-- 告警信息 -->
          <div class="notification-content">
            <div class="notification-title">{{ item.alert.title }}</div>
            <div class="notification-desc">{{ item.alert.description }}</div>
            <div class="notification-time">
              {{ formatTime(item.timestamp) }}
            </div>
          </div>

          <!-- 操作按钮 -->
          <div class="notification-actions">
            <a-button
              size="mini"
              type="text"
              @click.stop="handleMarkRead(item)"
              v-if="!item.read"
            >
              <template #icon>
                <icon-check />
              </template>
            </a-button>
            <a-button
              size="mini"
              type="text"
              @click.stop="handleClear(item)"
            >
              <template #icon>
                <icon-close />
              </template>
            </a-button>
          </div>
        </div>
      </div>

      <!-- 查看更多 -->
      <div class="notification-footer">
        <a-button type="text" long @click="goToAlerts">
          查看所有告警
        </a-button>
      </div>
    </a-drawer>

    <!-- 通知设置弹窗 -->
    <a-modal
      v-model:visible="showSettings"
      title="通知设置"
      @ok="handleSaveSettings"
      @cancel="showSettings = false"
    >
      <a-form :model="settingsForm" layout="vertical">
        <a-form-item label="启用通知">
          <a-switch v-model="settingsForm.enabled" />
        </a-form-item>

        <a-form-item label="声音提醒">
          <a-switch v-model="settingsForm.sound" />
        </a-form-item>

        <a-form-item label="桌面通知">
          <a-switch v-model="settingsForm.desktop" />
          <template #extra>
            <a-space>
              <span v-if="notificationPermission === 'granted'" style="color: #52c41a">
                已授权
              </span>
              <span v-else-if="notificationPermission === 'denied'" style="color: #f5222d">
                已拒绝
              </span>
              <a-button
                v-if="notificationPermission !== 'granted'"
                size="mini"
                type="text"
                @click="requestNotificationPermission"
              >
                请求权限
              </a-button>
            </a-space>
          </template>
        </a-form-item>

        <a-form-item label="最低通知级别">
          <a-select v-model="settingsForm.minLevel">
            <a-option value="low">低</a-option>
            <a-option value="medium">中</a-option>
            <a-option value="high">高</a-option>
            <a-option value="critical">严重</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="通知类型">
          <a-checkbox-group v-model="settingsForm.types">
            <a-checkbox value="rate_limit">频率限制</a-checkbox>
            <a-checkbox value="suspicious_activity">可疑活动</a-checkbox>
            <a-checkbox value="brute_force">暴力破解</a-checkbox>
            <a-checkbox value="sql_injection">SQL注入</a-checkbox>
            <a-checkbox value="xss">XSS攻击</a-checkbox>
            <a-checkbox value="csrf">CSRF攻击</a-checkbox>
          </a-checkbox-group>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { useSecurityStore } from '@/store/modules/security';
import { AlertLevelLabels, AlertLevelColors } from '@/types/security';
import type { AlertNotificationItem, AlertNotificationConfig } from '@/types/security';
import {
  IconNotification,
  IconSettings,
  IconCheck,
  IconClose,
} from '@arco-design/web-vue/es/icon';
import { Message } from '@arco-design/web-vue';

const router = useRouter();
const securityStore = useSecurityStore();

// 状态
const panelVisible = ref(false);
const showSettings = ref(false);
const notificationPermission = ref<NotificationPermission>('default');

// 计算属性
const notifications = computed(() => securityStore.notifications);
const unreadCount = computed(() => securityStore.unreadCount);

// 设置表单
const settingsForm = ref<AlertNotificationConfig>({
  enabled: true,
  sound: true,
  desktop: true,
  minLevel: 'medium',
  types: [],
});

// 方法
const togglePanel = () => {
  panelVisible.value = !panelVisible.value;
};

const getLevelLabel = (level: string) => {
  return AlertLevelLabels[level as keyof typeof AlertLevelLabels] || level;
};

const getLevelColor = (level: string) => {
  return AlertLevelColors[level as keyof typeof AlertLevelColors] || '#d9d9d9';
};

const formatTime = (timestamp: number) => {
  const now = Date.now();
  const diff = now - timestamp;
  
  if (diff < 60000) {
    return '刚刚';
  } else if (diff < 3600000) {
    return `${Math.floor(diff / 60000)}分钟前`;
  } else if (diff < 86400000) {
    return `${Math.floor(diff / 3600000)}小时前`;
  } else {
    return new Date(timestamp).toLocaleString('zh-CN');
  }
};

const handleNotificationClick = (item: AlertNotificationItem) => {
  securityStore.markNotificationAsRead(item.id);
  router.push(`/security/alerts?id=${item.alert.id}`);
  panelVisible.value = false;
};

const handleMarkRead = (item: AlertNotificationItem) => {
  securityStore.markNotificationAsRead(item.id);
};

const handleMarkAllRead = () => {
  securityStore.markAllNotificationsAsRead();
  Message.success('已全部标记为已读');
};

const handleClear = (item: AlertNotificationItem) => {
  securityStore.clearNotification(item.id);
};

const handleClearAll = () => {
  securityStore.clearAllNotifications();
  Message.success('已清空所有通知');
};

const goToAlerts = () => {
  router.push('/security/alerts');
  panelVisible.value = false;
};

const requestNotificationPermission = async () => {
  if (!('Notification' in window)) {
    Message.warning('您的浏览器不支持桌面通知');
    return;
  }

  try {
    const permission = await Notification.requestPermission();
    notificationPermission.value = permission;
    
    if (permission === 'granted') {
      Message.success('已授权桌面通知');
    } else {
      Message.warning('您拒绝了桌面通知权限');
    }
  } catch (error) {
    console.error('请求通知权限失败', error);
    Message.error('请求通知权限失败');
  }
};

const handleSaveSettings = () => {
  securityStore.updateNotificationConfig(settingsForm.value);
  Message.success('设置已保存');
  showSettings.value = false;
};

// 生命周期
onMounted(() => {
  // 加载通知配置
  securityStore.loadNotificationConfig();
  settingsForm.value = { ...securityStore.notificationConfig };
  
  // 检查通知权限
  if ('Notification' in window) {
    notificationPermission.value = Notification.permission;
  }
  
  // 启动实时轮询
  securityStore.startRealtimePolling(30000); // 30秒
});

onUnmounted(() => {
  // 停止实时轮询
  securityStore.stopRealtimePolling();
});
</script>

<style scoped lang="less">
.alert-notification {
  display: inline-block;
}

.notification-toolbar {
  padding: 12px 0;
  border-bottom: 1px solid var(--color-border);
  margin-bottom: 12px;
}

.notification-list {
  max-height: calc(100vh - 200px);
  overflow-y: auto;
}

.notification-item {
  position: relative;
  padding: 12px;
  border-radius: 4px;
  margin-bottom: 8px;
  cursor: pointer;
  transition: all 0.3s;
  border: 1px solid var(--color-border);

  &:hover {
    background-color: var(--color-fill-2);
  }

  &.notification-item-unread {
    background-color: var(--color-primary-light-1);
    border-color: var(--color-primary-light-3);
  }
}

.notification-level {
  position: absolute;
  top: 12px;
  right: 12px;
}

.notification-content {
  padding-right: 60px;
}

.notification-title {
  font-weight: 500;
  margin-bottom: 4px;
  color: var(--color-text-1);
}

.notification-desc {
  font-size: 12px;
  color: var(--color-text-3);
  margin-bottom: 4px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.notification-time {
  font-size: 12px;
  color: var(--color-text-4);
}

.notification-actions {
  position: absolute;
  bottom: 12px;
  right: 12px;
  display: flex;
  gap: 4px;
}

.notification-footer {
  padding: 12px 0;
  border-top: 1px solid var(--color-border);
  margin-top: 12px;
}
</style>
