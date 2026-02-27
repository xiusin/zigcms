<template>
  <div class="notification-settings-page">
    <Breadcrumb :items="breadcrumbItems" />

    <a-card class="settings-card" :loading="loading">
      <template #title>
        <div class="card-title">
          <icon-settings />
          <span>通知设置</span>
        </div>
      </template>

      <a-form
        ref="formRef"
        :model="formData"
        layout="vertical"
        class="settings-form"
      >
        <!-- 反馈通知设置 -->
        <div class="settings-section">
          <h3 class="section-title">
            <icon-notification />
            反馈通知
          </h3>
          <p class="section-desc">选择您希望接收的反馈相关通知类型</p>

          <div class="settings-list">
            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">反馈被指派</div>
                <div class="setting-desc">当有反馈被指派给您时接收通知</div>
              </div>
              <a-switch v-model="formData.notify_assigned" />
            </div>

            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">状态变更</div>
                <div class="setting-desc">当反馈状态发生变更时接收通知</div>
              </div>
              <a-switch v-model="formData.notify_status_changed" />
            </div>

            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">新评论</div>
                <div class="setting-desc">当反馈有新评论时接收通知</div>
              </div>
              <a-switch v-model="formData.notify_new_comment" />
            </div>

            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">被@提及</div>
                <div class="setting-desc">当有人在评论中@您时接收通知</div>
              </div>
              <a-switch v-model="formData.notify_mentioned" />
            </div>

            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">反馈关闭/解决</div>
                <div class="setting-desc">当反馈被关闭或解决时接收通知</div>
              </div>
              <a-switch v-model="formData.notify_feedback_closed" />
            </div>
          </div>
        </div>

        <a-divider />

        <!-- 通知渠道设置 -->
        <div class="settings-section">
          <h3 class="section-title">
            <icon-send />
            通知渠道
          </h3>
          <p class="section-desc">选择您希望使用的通知渠道</p>

          <div class="settings-list">
            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">
                  <icon-email />
                  邮件通知
                </div>
                <div class="setting-desc">通过邮件接收通知</div>
              </div>
              <a-switch v-model="formData.email_notification" />
            </div>

            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">
                  <icon-desktop />
                  浏览器推送
                </div>
                <div class="setting-desc">通过浏览器桌面通知接收提醒</div>
              </div>
              <div class="setting-action">
                <a-switch
                  v-model="formData.browser_notification"
                  @change="handleBrowserNotificationChange"
                />
                <a-button
                  v-if="formData.browser_notification && !browserPermissionGranted"
                  type="primary"
                  size="small"
                  @click="requestBrowserPermission"
                >
                  授权
                </a-button>
              </div>
            </div>
          </div>
        </div>

        <a-divider />

        <!-- 免打扰设置 -->
        <div class="settings-section">
          <h3 class="section-title">
            <icon-moon-fill />
            免打扰模式
          </h3>
          <p class="section-desc">设置在特定时间段内不接收通知</p>

          <div class="settings-list">
            <div class="setting-item">
              <div class="setting-info">
                <div class="setting-title">开启免打扰</div>
                <div class="setting-desc">在指定时间段内暂停接收通知</div>
              </div>
              <a-switch v-model="formData.do_not_disturb" />
            </div>

            <a-row v-if="formData.do_not_disturb" :gutter="16" class="time-range">
              <a-col :span="12">
                <a-form-item label="开始时间" field="do_not_disturb_start">
                  <a-time-picker
                    v-model="formData.do_not_disturb_start"
                    format="HH:mm"
                    placeholder="选择开始时间"
                    style="width: 100%"
                  />
                </a-form-item>
              </a-col>
              <a-col :span="12">
                <a-form-item label="结束时间" field="do_not_disturb_end">
                  <a-time-picker
                    v-model="formData.do_not_disturb_end"
                    format="HH:mm"
                    placeholder="选择结束时间"
                    style="width: 100%"
                  />
                </a-form-item>
              </a-col>
            </a-row>
          </div>
        </div>

        <!-- 操作按钮 -->
        <div class="form-actions">
          <a-space>
            <a-button type="primary" :loading="saving" @click="handleSave">
              <template #icon><icon-save /></template>
              保存设置
            </a-button>
            <a-button @click="handleReset">
              <template #icon><icon-refresh /></template>
              重置
            </a-button>
          </a-space>
        </div>
      </a-form>
    </a-card>

    <!-- 测试通知按钮 -->
    <a-card class="test-card">
      <template #title>
        <div class="card-title">
          <icon-experiment />
          <span>测试通知</span>
        </div>
      </template>
      <p>发送一条测试通知，验证通知功能是否正常工作</p>
      <a-space>
        <a-button type="outline" @click="sendTestNotification('assigned')">
          <icon-user-add />
          测试指派通知
        </a-button>
        <a-button type="outline" @click="sendTestNotification('comment')">
          <icon-message />
          测试评论通知
        </a-button>
        <a-button type="outline" @click="sendTestNotification('mentioned')">
          <icon-at />
          测试@提及通知
        </a-button>
      </a-space>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue';
import { Message, Notification } from '@arco-design/web-vue';
import Breadcrumb from '@/components/breadcrumb/index.vue';
import useFeedbackNotificationStore from '@/store/modules/feedback-notification';
import type { NotificationSettings } from '@/api/feedback-notification';

const notificationStore = useFeedbackNotificationStore();

// ========== 面包屑配置 ==========
const breadcrumbItems = [
  { label: '首页', path: '/' },
  { label: '反馈管理', path: '/feedback' },
  { label: '通知设置' },
];

// ========== 状态定义 ==========
const loading = ref(false);
const saving = ref(false);
const formRef = ref();
const browserPermissionGranted = ref(false);

// 表单数据
const formData = reactive({
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
});

// 原始数据（用于重置）
let originalData: Partial<NotificationSettings> | null = null;

// ========== 计算属性 ==========
const isInDNDPeriod = computed(() => {
  if (!formData.do_not_disturb) return false;
  const now = new Date();
  const currentTime = `${String(now.getHours()).padStart(2, '0')}:${String(
    now.getMinutes()
  ).padStart(2, '0')}`;
  return (
    currentTime >= formData.do_not_disturb_start &&
    currentTime <= formData.do_not_disturb_end
  );
});

// ========== 方法 ==========
const loadSettings = async () => {
  loading.value = true;
  try {
    await notificationStore.fetchSettings();
    const settings = notificationStore.getSettings;
    if (settings) {
      Object.assign(formData, {
        notify_assigned: settings.notify_assigned,
        notify_status_changed: settings.notify_status_changed,
        notify_new_comment: settings.notify_new_comment,
        notify_mentioned: settings.notify_mentioned,
        notify_feedback_closed: settings.notify_feedback_closed,
        email_notification: settings.email_notification,
        browser_notification: settings.browser_notification,
        do_not_disturb: settings.do_not_disturb,
        do_not_disturb_start: settings.do_not_disturb_start || '22:00',
        do_not_disturb_end: settings.do_not_disturb_end || '08:00',
      });
      originalData = { ...formData };
    }
  } finally {
    loading.value = false;
  }
};

const handleSave = async () => {
  saving.value = true;
  try {
    await notificationStore.updateSettings({
      notify_assigned: formData.notify_assigned,
      notify_status_changed: formData.notify_status_changed,
      notify_new_comment: formData.notify_new_comment,
      notify_mentioned: formData.notify_mentioned,
      notify_feedback_closed: formData.notify_feedback_closed,
      email_notification: formData.email_notification,
      browser_notification: formData.browser_notification,
      do_not_disturb: formData.do_not_disturb,
      do_not_disturb_start: formData.do_not_disturb_start,
      do_not_disturb_end: formData.do_not_disturb_end,
    });
    originalData = { ...formData };
    Message.success('设置已保存');
  } catch (error) {
    Message.error('保存失败');
  } finally {
    saving.value = false;
  }
};

const handleReset = () => {
  if (originalData) {
    Object.assign(formData, originalData);
    Message.success('已重置为上次保存的设置');
  } else {
    // 重置为默认值
    Object.assign(formData, {
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
    });
    Message.success('已重置为默认设置');
  }
};

// 浏览器通知权限
const checkBrowserPermission = () => {
  if (!('Notification' in window)) {
    browserPermissionGranted.value = false;
    return;
  }
  browserPermissionGranted.value = Notification.permission === 'granted';
};

const requestBrowserPermission = async () => {
  if (!('Notification' in window)) {
    Message.warning('您的浏览器不支持桌面通知');
    return;
  }
  try {
    const permission = await Notification.requestPermission();
    browserPermissionGranted.value = permission === 'granted';
    if (browserPermissionGranted.value) {
      Message.success('已授权浏览器通知');
      // 发送测试通知
      new Notification('通知授权成功', {
        body: '您已成功开启浏览器桌面通知',
        icon: '/favicon.ico',
      });
    } else {
      Message.warning('需要授权才能发送浏览器通知');
    }
  } catch (error) {
    Message.error('授权失败');
  }
};

const handleBrowserNotificationChange = (value: boolean) => {
  if (value) {
    checkBrowserPermission();
    if (!browserPermissionGranted.value) {
      requestBrowserPermission();
    }
  }
};

// 发送测试通知
const sendTestNotification = (type: string) => {
  const typeMap: Record<string, { title: string; content: string; icon: string }> = {
    assigned: {
      title: '测试指派通知',
      content: '您有一条新的反馈被指派给您处理',
      icon: '👤',
    },
    comment: {
      title: '测试评论通知',
      content: '张三在反馈 #1234 中添加了新评论',
      icon: '💬',
    },
    mentioned: {
      title: '测试@提及通知',
      content: '李四在评论中@了您',
      icon: '@',
    },
  };

  const config = typeMap[type];

  // Arco Design 通知
  Notification.info({
    title: config.title,
    content: config.content,
    duration: 5000,
    closable: true,
  });

  // 浏览器通知
  if (formData.browser_notification && browserPermissionGranted.value) {
    new Notification(config.title, {
      body: config.content,
      icon: '/favicon.ico',
      tag: `test-${type}`,
    });
  }

  // 添加到通知列表
  notificationStore.appendNotifications([
    {
      id: Date.now(),
      type: type === 'assigned' ? 'assigned' : type === 'comment' ? 'new_comment' : 'mentioned',
      title: config.title,
      content: config.content,
      feedback_id: 1234,
      feedback_title: '测试反馈标题',
      trigger_user_id: 1,
      trigger_user_name: '系统测试',
      trigger_user_avatar: '',
      is_read: false,
      priority: 2,
      created_at: new Date().toISOString(),
    },
  ]);

  Message.success('测试通知已发送');
};

// ========== 生命周期 ==========
onMounted(() => {
  loadSettings();
  checkBrowserPermission();
});
</script>

<style scoped lang="less">
.notification-settings-page {
  padding: 20px;
}

.settings-card {
  margin-bottom: 20px;

  .card-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 16px;
    font-weight: 500;
  }
}

.test-card {
  .card-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 16px;
    font-weight: 500;
  }

  p {
    color: var(--color-text-2);
    margin-bottom: 16px;
  }
}

.settings-form {
  max-width: 800px;
}

.settings-section {
  margin-bottom: 24px;

  .section-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 16px;
    font-weight: 500;
    margin: 0 0 8px 0;
    color: var(--color-text-1);
  }

  .section-desc {
    color: var(--color-text-3);
    font-size: 13px;
    margin: 0 0 16px 0;
  }
}

.settings-list {
  .setting-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px;
    background: var(--color-fill-2);
    border-radius: 8px;
    margin-bottom: 12px;
    transition: background 0.2s;

    &:hover {
      background: var(--color-fill-3);
    }

    &:last-child {
      margin-bottom: 0;
    }
  }

  .setting-info {
    flex: 1;
    min-width: 0;

    .setting-title {
      display: flex;
      align-items: center;
      gap: 6px;
      font-size: 14px;
      font-weight: 500;
      color: var(--color-text-1);
      margin-bottom: 4px;
    }

    .setting-desc {
      font-size: 12px;
      color: var(--color-text-3);
    }
  }

  .setting-action {
    display: flex;
    align-items: center;
    gap: 12px;
  }
}

.time-range {
  margin-top: 16px;
  padding: 16px;
  background: var(--color-fill-2);
  border-radius: 8px;
}

.form-actions {
  margin-top: 32px;
  padding-top: 24px;
  border-top: 1px solid var(--color-border);
}
</style>
