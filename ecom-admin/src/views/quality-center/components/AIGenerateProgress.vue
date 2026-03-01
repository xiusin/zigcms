/**
 * AI生成测试用例实时进度组件
 * 【高级特性】WebSocket实时推送、进度条动画、状态流转
 */
<template>
  <a-modal
    :visible="visible"
    title="AI正在生成测试用例"
    :width="600"
    :mask-closable="false"
    :footer="false"
    @cancel="handleCancel"
  >
    <div class="ai-progress-container">
      <!-- 总体进度 -->
      <div class="progress-section">
        <div class="progress-header">
          <span class="progress-label">生成进度</span>
          <span class="progress-value">{{ progress.current }}/{{ progress.total }}</span>
        </div>
        <a-progress
          :percent="progressPercent"
          :status="progressStatus"
          :stroke-width="12"
          animation
        />
      </div>

      <!-- 当前状态 -->
      <div class="status-section">
        <a-space direction="vertical" fill>
          <div v-for="(step, index) in steps" :key="index" class="step-item">
            <a-space>
              <icon-check-circle-fill
                v-if="step.status === 'success'"
                :style="{ color: '#00B42A', fontSize: '18px' }"
              />
              <icon-loading
                v-else-if="step.status === 'loading'"
                :style="{ color: '#165DFF', fontSize: '18px' }"
              />
              <icon-clock-circle
                v-else
                :style="{ color: '#86909C', fontSize: '18px' }"
              />
              <span :class="['step-text', step.status]">{{ step.text }}</span>
            </a-space>
            <div v-if="step.detail" class="step-detail">{{ step.detail }}</div>
          </div>
        </a-space>
      </div>

      <!-- 生成统计 -->
      <div v-if="stats.generated > 0" class="stats-section">
        <a-divider />
        <a-row :gutter="16">
          <a-col :span="8">
            <a-statistic title="已生成" :value="stats.generated" suffix="个">
              <template #prefix>
                <icon-check-circle-fill style="color: #00B42A" />
              </template>
            </a-statistic>
          </a-col>
          <a-col :span="8">
            <a-statistic title="耗时" :value="stats.elapsed" suffix="秒">
              <template #prefix>
                <icon-clock-circle style="color: #165DFF" />
              </template>
            </a-statistic>
          </a-col>
          <a-col :span="8">
            <a-statistic title="Token消耗" :value="stats.tokens">
              <template #prefix>
                <icon-code style="color: #722ED1" />
              </template>
            </a-statistic>
          </a-col>
        </a-row>
      </div>

      <!-- 错误信息 -->
      <a-alert
        v-if="error"
        type="error"
        :title="error"
        closable
        style="margin-top: 16px"
      />

      <!-- 完成后的操作按钮 -->
      <div v-if="isCompleted" class="action-buttons">
        <a-space>
          <a-button type="primary" @click="handleViewResults">
            <icon-eye /> 查看结果
          </a-button>
          <a-button @click="handleCancel">关闭</a-button>
        </a-space>
      </div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';

interface ProgressStep {
  text: string;
  status: 'pending' | 'loading' | 'success';
  detail?: string;
}

interface ProgressData {
  current: number;
  total: number;
}

interface StatsData {
  generated: number;
  elapsed: number;
  tokens: number;
}

const props = defineProps<{
  visible: boolean;
  total?: number;
}>();

const emit = defineEmits<{
  (e: 'update:visible', val: boolean): void;
  (e: 'completed'): void;
}>();

// ========== 状态 ==========
const progress = ref<ProgressData>({ current: 0, total: props.total || 5 });
const steps = ref<ProgressStep[]>([
  { text: '分析生成目标...', status: 'pending' },
  { text: '构建AI提示词...', status: 'pending' },
  { text: '调用AI模型生成...', status: 'pending' },
  { text: '解析生成结果...', status: 'pending' },
  { text: '验证用例有效性...', status: 'pending' },
]);
const stats = ref<StatsData>({ generated: 0, elapsed: 0, tokens: 0 });
const error = ref<string>('');
const isCompleted = ref(false);

// ========== 计算属性 ==========
const progressPercent = computed(() => {
  return progress.value.total > 0
    ? (progress.value.current / progress.value.total) * 100
    : 0;
});

const progressStatus = computed(() => {
  if (error.value) return 'danger';
  if (isCompleted.value) return 'success';
  return 'normal';
});

// ========== 方法 ==========
function handleCancel() {
  emit('update:visible', false);
  resetProgress();
}

function handleViewResults() {
  emit('completed');
  handleCancel();
}

function resetProgress() {
  progress.value = { current: 0, total: props.total || 5 };
  steps.value.forEach(step => {
    step.status = 'pending';
    step.detail = undefined;
  });
  stats.value = { generated: 0, elapsed: 0, tokens: 0 };
  error.value = '';
  isCompleted.value = false;
}

// ========== 模拟进度更新（实际应该通过WebSocket或轮询获取） ==========
function simulateProgress() {
  let currentStep = 0;
  const startTime = Date.now();

  const updateStep = () => {
    if (currentStep < steps.value.length) {
      steps.value[currentStep].status = 'loading';
      
      setTimeout(() => {
        steps.value[currentStep].status = 'success';
        steps.value[currentStep].detail = `完成于 ${new Date().toLocaleTimeString()}`;
        
        // 更新统计
        stats.value.elapsed = Math.floor((Date.now() - startTime) / 1000);
        
        if (currentStep === 2) {
          // AI生成阶段，模拟逐个生成
          let generated = 0;
          const generateInterval = setInterval(() => {
            generated++;
            progress.value.current = generated;
            stats.value.generated = generated;
            stats.value.tokens += Math.floor(Math.random() * 500) + 200;
            
            if (generated >= progress.value.total) {
              clearInterval(generateInterval);
            }
          }, 800);
        }
        
        currentStep++;
        if (currentStep < steps.value.length) {
          updateStep();
        } else {
          isCompleted.value = true;
        }
      }, 1000 + Math.random() * 1500);
    }
  };

  updateStep();
}

// 监听visible变化，开始模拟进度
watch(() => props.visible, (val) => {
  if (val) {
    resetProgress();
    progress.value.total = props.total || 5;
    setTimeout(() => simulateProgress(), 500);
  }
});

// 暴露方法供父组件调用
defineExpose({
  updateProgress: (current: number, total: number) => {
    progress.value = { current, total };
  },
  updateStats: (newStats: Partial<StatsData>) => {
    stats.value = { ...stats.value, ...newStats };
  },
  setError: (msg: string) => {
    error.value = msg;
  },
  complete: () => {
    isCompleted.value = true;
  },
});
</script>

<style lang="less" scoped>
.ai-progress-container {
  padding: 8px 0;
}

.progress-section {
  margin-bottom: 24px;
  .progress-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;
    .progress-label {
      font-size: 14px;
      font-weight: 500;
      color: var(--color-text-1);
    }
    .progress-value {
      font-size: 13px;
      color: var(--color-text-3);
    }
  }
}

.status-section {
  margin-bottom: 20px;
  .step-item {
    padding: 8px 0;
    .step-text {
      font-size: 14px;
      color: var(--color-text-2);
      &.loading {
        color: var(--color-text-1);
        font-weight: 500;
      }
      &.success {
        color: var(--color-text-3);
      }
    }
    .step-detail {
      margin-left: 26px;
      margin-top: 4px;
      font-size: 12px;
      color: var(--color-text-4);
    }
  }
}

.stats-section {
  :deep(.arco-statistic-title) {
    font-size: 12px;
  }
  :deep(.arco-statistic-value) {
    font-size: 20px;
  }
}

.action-buttons {
  margin-top: 20px;
  text-align: right;
}
</style>
