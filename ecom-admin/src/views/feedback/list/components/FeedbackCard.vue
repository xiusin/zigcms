<template>
  <div
    class="feedback-card"
    :class="{ 'is-urgent': isUrgent, 'is-high': isHigh }"
    @click="handleClick"
  >
    <!-- 卡片头部 -->
    <div class="card-header">
      <div class="card-priority" :class="`priority-${priorityClass}`">
        <icon-fire v-if="feedback.priority === 0" />
        <icon-arrow-rise v-else-if="feedback.priority === 1" />
        <icon-minus v-else-if="feedback.priority === 2" />
        <icon-arrow-fall v-else />
      </div>
      <div class="card-actions">
        <a-dropdown @select="handleAction" position="bottom">
          <a-button type="text" size="mini" @click.stop>
            <icon-more />
          </a-button>
          <template #content>
            <a-doption value="edit">
              <template #icon><icon-edit /></template>
              编辑
            </a-doption>
            <a-doption value="assign" v-if="!feedback.handler_id">
              <template #icon><icon-user /></template>
              指派
            </a-doption>
            <a-doption value="delete">
              <template #icon><icon-delete /></template>
              删除
            </a-doption>
          </template>
        </a-dropdown>
      </div>
    </div>

    <!-- 卡片内容 -->
    <div class="card-body">
      <h4 class="card-title" :title="feedback.title">{{ feedback.title }}</h4>
      <p class="card-desc" v-if="feedback.content">{{ feedback.content }}</p>

      <!-- 标签 -->
      <div class="card-tags" v-if="feedback.tags && feedback.tags.length > 0">
        <a-tag
          v-for="tag in displayTags"
          :key="tag.id"
          :color="tag.color"
          size="small"
        >
          {{ tag.name }}
        </a-tag>
        <a-tag v-if="remainingTags > 0" size="small">+{{ remainingTags }}</a-tag>
      </div>
    </div>

    <!-- 卡片底部 -->
    <div class="card-footer">
      <div class="card-meta">
        <a-avatar :size="20" class="creator-avatar">
          <img v-if="feedback.creator_avatar" :src="feedback.creator_avatar" />
          <span v-else>{{ feedback.creator_name?.charAt(0) }}</span>
        </a-avatar>
        <span class="meta-time">{{ formatTime(feedback.created_at) }}</span>
      </div>
      <div class="card-stats">
        <span class="stat-item" v-if="feedback.comment_count > 0">
          <icon-message /> {{ feedback.comment_count }}
        </span>
        <span class="stat-item" v-if="feedback.subscriber_count > 0">
          <icon-star /> {{ feedback.subscriber_count }}
        </span>
      </div>
    </div>

    <!-- 类型标识 -->
    <div class="card-type" :class="`type-${typeClass}`">
      {{ typeLabel }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import {
  IconFire,
  IconArrowRise,
  IconMinus,
  IconArrowFall,
  IconMore,
  IconEdit,
  IconUser,
  IconDelete,
  IconMessage,
  IconStar,
} from '@arco-design/web-vue/es/icon';
import type { Feedback } from '@/api/feedback';
import {
  FeedbackPriority,
  FeedbackType,
} from '@/api/feedback';

/** Props 定义 */
interface Props {
  /** 反馈数据 */
  feedback: Feedback;
}

const props = defineProps<Props>();

/** Emits 定义 */
const emit = defineEmits<{
  /** 卡片点击 */
  (e: 'click', feedback: Feedback): void;
  /** 编辑 */
  (e: 'edit', feedback: Feedback): void;
  /** 删除 */
  (e: 'delete', feedback: Feedback): void;
  /** 指派 */
  (e: 'assign', feedback: Feedback): void;
  /** 拖拽开始 */
  (e: 'dragstart', feedback: Feedback): void;
}>();

/** 是否紧急 */
const isUrgent = computed(() => props.feedback.priority === FeedbackPriority.URGENT);

/** 是否高优先级 */
const isHigh = computed(() => props.feedback.priority === FeedbackPriority.HIGH);

/** 优先级样式类 */
const priorityClass = computed(() => {
  switch (props.feedback.priority) {
    case FeedbackPriority.URGENT:
      return 'urgent';
    case FeedbackPriority.HIGH:
      return 'high';
    case FeedbackPriority.MEDIUM:
      return 'medium';
    case FeedbackPriority.LOW:
      return 'low';
    default:
      return 'medium';
  }
});

/** 类型样式类 */
const typeClass = computed(() => {
  switch (props.feedback.type) {
    case FeedbackType.FEATURE:
      return 'feature';
    case FeedbackType.BUG:
      return 'bug';
    case FeedbackType.PERFORMANCE:
      return 'performance';
    case FeedbackType.UX:
      return 'ux';
    case FeedbackType.OTHER:
      return 'other';
    default:
      return 'other';
  }
});

/** 类型标签 */
const typeLabel = computed(() => {
  switch (props.feedback.type) {
    case FeedbackType.FEATURE:
      return '功能';
    case FeedbackType.BUG:
      return 'Bug';
    case FeedbackType.PERFORMANCE:
      return '性能';
    case FeedbackType.UX:
      return '体验';
    case FeedbackType.OTHER:
      return '其他';
    default:
      return '其他';
  }
});

/** 显示的标签（最多3个） */
const displayTags = computed(() => {
  return (props.feedback.tags || []).slice(0, 3);
});

/** 剩余标签数量 */
const remainingTags = computed(() => {
  const tags = props.feedback.tags || [];
  return Math.max(0, tags.length - 3);
});

/** 格式化时间 */
const formatTime = (time: string) => {
  const date = new Date(time);
  const now = new Date();
  const diff = now.getTime() - date.getTime();

  // 小于1小时显示"X分钟前"
  if (diff < 60 * 60 * 1000) {
    const minutes = Math.floor(diff / (60 * 1000));
    return minutes < 1 ? '刚刚' : `${minutes}分钟前`;
  }

  // 小于24小时显示"X小时前"
  if (diff < 24 * 60 * 60 * 1000) {
    const hours = Math.floor(diff / (60 * 60 * 1000));
    return `${hours}小时前`;
  }

  // 小于7天显示"X天前"
  if (diff < 7 * 24 * 60 * 60 * 1000) {
    const days = Math.floor(diff / (24 * 60 * 60 * 1000));
    return `${days}天前`;
  }

  // 否则显示日期
  return date.toLocaleDateString('zh-CN', {
    month: 'short',
    day: 'numeric',
  });
};

/** 处理卡片点击 */
const handleClick = () => {
  emit('click', props.feedback);
};

/** 处理操作 */
const handleAction = (action: string | number | Record<string, any>) => {
  switch (action) {
    case 'edit':
      emit('edit', props.feedback);
      break;
    case 'delete':
      emit('delete', props.feedback);
      break;
    case 'assign':
      emit('assign', props.feedback);
      break;
  }
};

/** 处理拖拽开始 */
const handleDragStart = (e: DragEvent) => {
  emit('dragstart', props.feedback);
};
</script>

<style scoped lang="less">
.feedback-card {
  position: relative;
  background: var(--color-bg-1);
  border-radius: 8px;
  padding: 12px;
  box-shadow: 0 1px 2px rgba(0, 0, 0, 0.06);
  cursor: pointer;
  transition: all 0.2s ease;
  border-left: 3px solid transparent;

  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
    transform: translateY(-2px);

    .card-actions {
      opacity: 1;
    }
  }

  &.is-urgent {
    border-left-color: #f53f3f;
    background: linear-gradient(to right, #fff8f7, var(--color-bg-1));
  }

  &.is-high {
    border-left-color: #ff7d00;
    background: linear-gradient(to right, #fffbf5, var(--color-bg-1));
  }

  .card-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 8px;

    .card-priority {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 24px;
      height: 24px;
      border-radius: 4px;
      font-size: 14px;

      &.priority-urgent {
        color: #f53f3f;
        background: #ffece8;
      }

      &.priority-high {
        color: #ff7d00;
        background: #fff3e8;
      }

      &.priority-medium {
        color: #f7ba1e;
        background: #fffce8;
      }

      &.priority-low {
        color: #00b42a;
        background: #e8ffea;
      }
    }

    .card-actions {
      opacity: 0;
      transition: opacity 0.2s;
    }
  }

  .card-body {
    margin-bottom: 12px;

    .card-title {
      margin: 0 0 8px;
      font-size: 14px;
      font-weight: 500;
      color: var(--color-text-1);
      line-height: 1.5;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .card-desc {
      margin: 0 0 8px;
      font-size: 12px;
      color: var(--color-text-3);
      line-height: 1.5;
      overflow: hidden;
      text-overflow: ellipsis;
      display: -webkit-box;
      -webkit-line-clamp: 2;
      -webkit-box-orient: vertical;
    }

    .card-tags {
      display: flex;
      flex-wrap: wrap;
      gap: 4px;
    }
  }

  .card-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding-top: 8px;
    border-top: 1px solid var(--color-fill-2);

    .card-meta {
      display: flex;
      align-items: center;
      gap: 8px;

      .creator-avatar {
        flex-shrink: 0;
      }

      .meta-time {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }

    .card-stats {
      display: flex;
      gap: 12px;

      .stat-item {
        display: flex;
        align-items: center;
        gap: 4px;
        font-size: 12px;
        color: var(--color-text-3);
      }
    }
  }

  .card-type {
    position: absolute;
    top: 8px;
    right: 40px;
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 10px;
    font-weight: 500;

    &.type-feature {
      color: #165dff;
      background: #e8f3ff;
    }

    &.type-bug {
      color: #f53f3f;
      background: #ffece8;
    }

    &.type-performance {
      color: #ff7d00;
      background: #fff3e8;
    }

    &.type-ux {
      color: #722ed1;
      background: #f5e8ff;
    }

    &.type-other {
      color: #86909c;
      background: #f2f3f5;
    }
  }
}
</style>
