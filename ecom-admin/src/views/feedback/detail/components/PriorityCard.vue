<template>
  <div class="priority-card">
    <div class="card-header">
      <div class="card-title">
        <icon-thunderbolt />
        优先级
      </div>
    </div>

    <div class="card-body">
      <!-- 当前优先级 -->
      <div class="current-priority">
        <div class="priority-label">当前优先级</div>
        <div class="priority-value">
          <a-tag :color="priorityColor" size="large">
            <template #icon>
              <icon-exclamation-circle v-if="priority === 0" />
              <icon-arrow-up v-else-if="priority === 1" />
              <icon-minus v-else-if="priority === 2" />
              <icon-arrow-down v-else />
            </template>
            {{ priorityName }}
          </a-tag>
        </div>
      </div>

      <!-- 优先级变更 -->
      <div class="priority-change">
        <div class="change-label">变更优先级</div>
        <div class="priority-options">
          <div
            v-for="item in priorityOptions"
            :key="item.value"
            class="priority-option"
            :class="{ active: selectedPriority === item.value }"
            @click="handlePrioritySelect(item.value)"
          >
            <div
              class="priority-indicator"
              :style="{ backgroundColor: item.color }"
            >
              <icon-exclamation-circle v-if="item.value === 0" />
              <icon-arrow-up v-else-if="item.value === 1" />
              <icon-minus v-else-if="item.value === 2" />
              <icon-arrow-down v-else />
            </div>
            <div class="priority-info">
              <div class="priority-name">{{ item.label }}</div>
              <div class="priority-desc">{{ item.description }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconThunderbolt,
  IconExclamationCircle,
  IconArrowUp,
  IconMinus,
  IconArrowDown,
} from '@arco-design/web-vue/es/icon';
import { FeedbackPriority } from '@/api/feedback';

interface Props {
  priority: number;
  priorityName: string;
  priorityColor: string;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'change', priority: number): void;
}>();

// 优先级选项
const priorityOptions = [
  {
    value: FeedbackPriority.URGENT,
    label: '紧急',
    color: '#f53f3f',
    description: '需要立即处理',
  },
  {
    value: FeedbackPriority.HIGH,
    label: '高',
    color: '#ff7d00',
    description: '需要优先处理',
  },
  {
    value: FeedbackPriority.MEDIUM,
    label: '中',
    color: '#165dff',
    description: '正常处理',
  },
  {
    value: FeedbackPriority.LOW,
    label: '低',
    color: '#00b42a',
    description: '可以延后处理',
  },
];

// 当前选择的优先级
const selectedPriority = ref<number | null>(null);

// 处理优先级选择
const handlePrioritySelect = (value: number) => {
  if (value === props.priority) {
    Message.warning('不能设置为相同的优先级');
    selectedPriority.value = null;
    return;
  }

  selectedPriority.value = value;
  const option = priorityOptions.find((item) => item.value === value);

  Modal.confirm({
    title: '确认变更优先级',
    content: `确定要将优先级变更为 "${option?.label}" 吗？`,
    onOk: () => {
      emit('change', value);
      selectedPriority.value = null;
    },
    onCancel: () => {
      selectedPriority.value = null;
    },
  });
};
</script>

<style scoped lang="less">
.priority-card {
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

    .current-priority {
      .priority-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 8px;
      }

      .priority-value {
        :deep(.arco-tag) {
          font-size: 14px;
          padding: 4px 12px;
        }
      }
    }

    .priority-change {
      .change-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 10px;
      }

      .priority-options {
        display: flex;
        flex-direction: column;
        gap: 8px;

        .priority-option {
          display: flex;
          align-items: center;
          gap: 12px;
          padding: 10px 12px;
          background: var(--color-fill-1);
          border-radius: 6px;
          cursor: pointer;
          transition: all 0.2s;
          border: 2px solid transparent;

          &:hover {
            background: var(--color-fill-2);
          }

          &.active {
            border-color: var(--color-primary);
            background: var(--color-primary-light-1);
          }

          .priority-indicator {
            width: 32px;
            height: 32px;
            border-radius: 6px;
            display: flex;
            align-items: center;
            justify-content: center;
            color: #fff;
            font-size: 16px;
          }

          .priority-info {
            flex: 1;

            .priority-name {
              font-size: 14px;
              font-weight: 500;
              color: var(--color-text-1);
              margin-bottom: 2px;
            }

            .priority-desc {
              font-size: 12px;
              color: var(--color-text-3);
            }
          }
        }
      }
    }
  }
}
</style>
