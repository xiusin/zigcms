<template>
  <a-alert
    v-if="isRateLimited"
    type="warning"
    :closable="false"
    class="rate-limit-warning"
  >
    <template #icon>
      <icon-exclamation-circle-fill />
    </template>
    <template #title>
      请求过于频繁
    </template>
    <div class="warning-content">
      <p>您的请求速度过快，请稍后再试。</p>
      <p v-if="retryAfter">
        请在 <strong>{{ retryAfter }}</strong> 秒后重试
      </p>
      <a-progress
        v-if="retryAfter"
        :percent="progressPercent"
        :show-text="false"
        status="warning"
        class="retry-progress"
      />
    </div>
  </a-alert>
</template>

<script setup lang="ts">
import { ref, computed, watch, onUnmounted } from 'vue';
import { IconExclamationCircleFill } from '@arco-design/web-vue/es/icon';

interface Props {
  /** 是否被限流 */
  isRateLimited: boolean;
  /** 重试等待时间（秒） */
  retryAfter?: number;
}

const props = withDefaults(defineProps<Props>(), {
  retryAfter: 60
});

const emit = defineEmits<{
  (e: 'retry'): void;
}>();

// 剩余等待时间
const remainingTime = ref(props.retryAfter);

// 进度百分比
const progressPercent = computed(() => {
  if (!props.retryAfter) return 0;
  return ((props.retryAfter - remainingTime.value) / props.retryAfter) * 100;
});

// 定时器
let timer: number | null = null;

// 监听限流状态
watch(() => props.isRateLimited, (limited) => {
  if (limited) {
    startCountdown();
  } else {
    stopCountdown();
  }
}, { immediate: true });

// 开始倒计时
function startCountdown() {
  remainingTime.value = props.retryAfter;
  
  timer = window.setInterval(() => {
    remainingTime.value--;
    
    if (remainingTime.value <= 0) {
      stopCountdown();
      emit('retry');
    }
  }, 1000);
}

// 停止倒计时
function stopCountdown() {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
}

// 组件卸载时清理定时器
onUnmounted(() => {
  stopCountdown();
});
</script>

<style scoped lang="less">
.rate-limit-warning {
  margin-bottom: 16px;
  
  .warning-content {
    margin-top: 8px;
    
    p {
      margin: 4px 0;
      color: var(--color-text-2);
      
      strong {
        color: var(--color-warning-6);
        font-weight: 600;
      }
    }
    
    .retry-progress {
      margin-top: 12px;
    }
  }
}
</style>
