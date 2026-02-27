<template>
  <div class="subscribe-card">
    <div class="card-header">
      <div class="card-title">
        <icon-bell />
        订阅通知
      </div>
    </div>

    <div class="card-body">
      <!-- 订阅状态 -->
      <div class="subscribe-status">
        <div class="status-icon" :class="{ subscribed: isSubscribed }">
          <icon-bell v-if="isSubscribed" />
          <icon-bell-slash v-else />
        </div>
        <div class="status-info">
          <div class="status-title">
            {{ isSubscribed ? '已订阅' : '未订阅' }}
          </div>
          <div class="status-desc">
            {{ isSubscribed ? '您将收到此反馈的更新通知' : '订阅后接收更新通知' }}
          </div>
        </div>
      </div>

      <!-- 订阅统计 -->
      <div class="subscribe-stats">
        <div class="stat-item">
          <div class="stat-value">{{ subscriberCount }}</div>
          <div class="stat-label">订阅者</div>
        </div>
        <div class="stat-divider" />
        <div class="stat-item">
          <div class="stat-value">{{ isSubscribed ? '是' : '否' }}</div>
          <div class="stat-label">我的订阅</div>
        </div>
      </div>

      <!-- 订阅/取消订阅按钮 -->
      <a-button
        :type="isSubscribed ? 'outline' : 'primary'"
        long
        size="large"
        @click="handleToggleSubscribe"
      >
        <template #icon>
          <icon-minus v-if="isSubscribed" />
          <icon-plus v-else />
        </template>
        {{ isSubscribed ? '取消订阅' : '订阅此反馈' }}
      </a-button>

      <!-- 通知设置提示 -->
      <div class="subscribe-tips">
        <icon-info-circle />
        <span>订阅后将在反馈更新、有新评论时收到通知</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { IconBell, IconBellSlash, IconPlus, IconMinus, IconInfoCircle } from '@arco-design/web-vue/es/icon';

interface Props {
  isSubscribed: boolean;
  subscriberCount: number;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'toggle', isSubscribed: boolean): void;
}>();

// 处理订阅切换
const handleToggleSubscribe = () => {
  emit('toggle', !props.isSubscribed);
};
</script>

<style scoped lang="less">
.subscribe-card {
  background: var(--color-bg-2);
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

  .card-header {
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--color-border-2);

    .card-title {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 15px;
      font-weight: 600;
      color: var(--color-text-1);
    }
  }

  .card-body {
    display: flex;
    flex-direction: column;
    gap: 16px;

    .subscribe-status {
      display: flex;
      align-items: center;
      gap: 12px;
      padding: 12px;
      background: var(--color-fill-1);
      border-radius: 8px;

      .status-icon {
        width: 44px;
        height: 44px;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--color-fill-3);
        color: var(--color-text-3);
        font-size: 20px;
        transition: all 0.3s;

        &.subscribed {
          background: var(--color-primary-light-1);
          color: var(--color-primary);
        }
      }

      .status-info {
        flex: 1;

        .status-title {
          font-size: 15px;
          font-weight: 600;
          color: var(--color-text-1);
          margin-bottom: 4px;
        }

        .status-desc {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }
    }

    .subscribe-stats {
      display: flex;
      align-items: center;
      justify-content: space-around;
      padding: 12px;
      background: var(--color-fill-1);
      border-radius: 8px;

      .stat-item {
        text-align: center;

        .stat-value {
          font-size: 20px;
          font-weight: 600;
          color: var(--color-text-1);
          margin-bottom: 4px;
        }

        .stat-label {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }

      .stat-divider {
        width: 1px;
        height: 32px;
        background: var(--color-border-2);
      }
    }

    .subscribe-tips {
      display: flex;
      align-items: flex-start;
      gap: 8px;
      padding: 10px 12px;
      background: var(--color-primary-light-1);
      border-radius: 6px;
      font-size: 12px;
      color: var(--color-primary);
      line-height: 1.5;
    }
  }
}
</style>
