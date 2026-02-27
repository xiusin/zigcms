<template>
  <div class="feedback-kanban">
    <!-- 看板列 -->
    <div
      v-for="column in columns"
      :key="column.key"
      class="kanban-column"
      :class="{ 'drag-over': dragOverColumn === column.key }"
      @dragover.prevent="handleDragOver(column.key)"
      @dragleave="handleDragLeave"
      @drop="handleDrop(column.key)"
    >
      <!-- 列头部 -->
      <div class="column-header" :style="{ backgroundColor: column.bgColor }">
        <div class="column-title">
          <span class="column-dot" :style="{ backgroundColor: column.color }"></span>
          <span class="column-name">{{ column.title }}</span>
          <a-tag size="small" class="column-count">{{ column.data.length }}</a-tag>
        </div>
        <div class="column-actions">
          <a-tooltip content="添加反馈">
            <a-button type="text" size="mini" @click="handleAdd(column.key)">
              <icon-plus />
            </a-button>
          </a-tooltip>
        </div>
      </div>

      <!-- 卡片列表 -->
      <div class="column-content" :style="{ backgroundColor: column.bgColor + '40' }">
        <a-scrollbar style="height: calc(100vh - 400px); overflow: auto">
          <div class="card-list">
            <FeedbackCard
              v-for="feedback in column.data"
              :key="feedback.id"
              :feedback="feedback"
              draggable="true"
              @dragstart="handleDragStart(feedback, column.key)"
              @click="handleCardClick(feedback)"
              @edit="handleEdit(feedback)"
              @delete="handleDelete(feedback)"
              @assign="handleAssign(feedback)"
            />
          </div>

          <!-- 空状态 -->
          <div v-if="column.data.length === 0" class="column-empty">
            <a-empty description="暂无数据" />
          </div>
        </a-scrollbar>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { IconPlus } from '@arco-design/web-vue/es/icon';
import FeedbackCard from './FeedbackCard.vue';
import type { Feedback, FeedbackStatus } from '@/api/feedback';
import {
  FeedbackStatus as FeedbackStatusEnum,
  FeedbackPriority as FeedbackPriorityEnum,
} from '@/api/feedback';

/** 看板数据接口 */
interface KanbanData {
  pending: Feedback[];
  processing: Feedback[];
  resolved: Feedback[];
  closed: Feedback[];
}

/** Props 定义 */
interface Props {
  /** 看板数据 */
  data: KanbanData;
  /** 加载状态 */
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

/** Emits 定义 */
const emit = defineEmits<{
  /** 卡片点击 */
  (e: 'card-click', feedback: Feedback): void;
  /** 状态变更（拖拽） */
  (e: 'status-change', feedbackId: number, newStatus: FeedbackStatus): void;
  /** 刷新数据 */
  (e: 'refresh'): void;
  /** 添加反馈 */
  (e: 'add', status: string): void;
  /** 编辑反馈 */
  (e: 'edit', feedback: Feedback): void;
  /** 删除反馈 */
  (e: 'delete', feedback: Feedback): void;
  /** 指派反馈 */
  (e: 'assign', feedback: Feedback): void;
}>();

/** 看板列配置 */
const columns = computed(() => [
  {
    key: 'pending',
    title: '待处理',
    color: '#86909c',
    bgColor: '#f2f3f5',
    status: FeedbackStatusEnum.PENDING,
    data: props.data.pending || [],
  },
  {
    key: 'processing',
    title: '处理中',
    color: '#165dff',
    bgColor: '#e8f3ff',
    status: FeedbackStatusEnum.PROCESSING,
    data: props.data.processing || [],
  },
  {
    key: 'resolved',
    title: '已解决',
    color: '#00b42a',
    bgColor: '#e8ffea',
    status: FeedbackStatusEnum.RESOLVED,
    data: props.data.resolved || [],
  },
  {
    key: 'closed',
    title: '已关闭',
    color: '#86909c',
    bgColor: '#f2f3f5',
    status: FeedbackStatusEnum.CLOSED,
    data: props.data.closed || [],
  },
]);

/** 拖拽相关状态 */
const draggingFeedback = ref<Feedback | null>(null);
const dragSourceColumn = ref<string>('');
const dragOverColumn = ref<string>('');

/** 开始拖拽 */
const handleDragStart = (feedback: Feedback, columnKey: string) => {
  draggingFeedback.value = feedback;
  dragSourceColumn.value = columnKey;
};

/** 拖拽经过 */
const handleDragOver = (columnKey: string) => {
  dragOverColumn.value = columnKey;
};

/** 拖拽离开 */
const handleDragLeave = () => {
  dragOverColumn.value = '';
};

/** 放置 */
const handleDrop = (targetColumnKey: string) => {
  if (!draggingFeedback.value || dragSourceColumn.value === targetColumnKey) {
    dragOverColumn.value = '';
    return;
  }

  // 获取目标列的状态值
  const targetStatus = columns.value.find((col) => col.key === targetColumnKey)?.status;

  if (targetStatus !== undefined) {
    emit('status-change', draggingFeedback.value.id, targetStatus);
  }

  // 重置拖拽状态
  draggingFeedback.value = null;
  dragSourceColumn.value = '';
  dragOverColumn.value = '';
};

/** 卡片点击 */
const handleCardClick = (feedback: Feedback) => {
  emit('card-click', feedback);
};

/** 添加反馈 */
const handleAdd = (status: string) => {
  emit('add', status);
};

/** 编辑反馈 */
const handleEdit = (feedback: Feedback) => {
  emit('edit', feedback);
};

/** 删除反馈 */
const handleDelete = (feedback: Feedback) => {
  emit('delete', feedback);
};

/** 指派反馈 */
const handleAssign = (feedback: Feedback) => {
  emit('assign', feedback);
};
</script>

<style scoped lang="less">
.feedback-kanban {
  display: flex;
  gap: 16px;
  height: calc(100vh - 320px);
  overflow-x: auto;
  padding-bottom: 8px;

  .kanban-column {
    flex: 1;
    min-width: 280px;
    max-width: 360px;
    display: flex;
    flex-direction: column;
    border-radius: 8px;
    transition: all 0.2s ease;

    &.drag-over {
      box-shadow: 0 0 0 2px #165dff;
      transform: scale(1.02);
    }

    .column-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 12px 16px;
      border-radius: 8px 8px 0 0;

      .column-title {
        display: flex;
        align-items: center;
        gap: 8px;

        .column-dot {
          width: 8px;
          height: 8px;
          border-radius: 50%;
        }

        .column-name {
          font-weight: 500;
          font-size: 14px;
          color: var(--color-text-1);
        }

        .column-count {
          font-size: 12px;
        }
      }

      .column-actions {
        opacity: 0;
        transition: opacity 0.2s;
      }

      &:hover .column-actions {
        opacity: 1;
      }
    }

    .column-content {
      flex: 1;
      padding: 12px;
      border-radius: 0 0 8px 8px;
      overflow: hidden;

      .card-list {
        display: flex;
        flex-direction: column;
        gap: 12px;
      }

      .column-empty {
        display: flex;
        justify-content: center;
        align-items: center;
        height: 200px;
      }
    }
  }
}

/* 滚动条样式 */
:deep(.arco-scrollbar) {
  .arco-scrollbar-track {
    background: transparent;
  }

  .arco-scrollbar-thumb {
    background: var(--color-fill-3);
    border-radius: 4px;

    &:hover {
      background: var(--color-fill-4);
    }
  }
}
</style>
