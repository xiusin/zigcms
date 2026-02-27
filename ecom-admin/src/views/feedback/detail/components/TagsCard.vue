<template>
  <div class="tags-card">
    <div class="card-header">
      <div class="card-title">
        <icon-tag />
        标签
      </div>
    </div>

    <div class="card-body">
      <!-- 当前标签列表 -->
      <div class="current-tags">
        <div class="tags-label">当前标签</div>
        <div v-if="tags.length > 0" class="tags-list">
          <a-tag
            v-for="tag in tags"
            :key="tag.id"
            :color="tag.color"
            closable
            @close="handleRemoveTag(tag.id)"
          >
            {{ tag.name }}
          </a-tag>
        </div>
        <div v-else class="no-tags">
          <icon-info-circle />
          暂无标签
        </div>
      </div>

      <!-- 添加标签 -->
      <div class="add-tag">
        <div class="add-label">添加标签</div>
        <a-select
          v-model="selectedTag"
          placeholder="选择标签"
          style="width: 100%"
          allow-search
          @change="handleAddTag"
        >
          <a-option
            v-for="tag in availableTags"
            :key="tag.id"
            :value="tag.id"
            :label="tag.name"
          >
            <div class="tag-option">
              <span
                class="tag-dot"
                :style="{ backgroundColor: tag.color }"
              />
              <span class="tag-name">{{ tag.name }}</span>
              <span v-if="tag.description" class="tag-desc">{{ tag.description }}</span>
            </div>
          </a-option>
        </a-select>
      </div>

      <!-- 常用标签 -->
      <div class="common-tags">
        <div class="common-label">常用标签</div>
        <div class="common-list">
          <a-tag
            v-for="tag in commonTags"
            :key="tag.id"
            :color="tag.color"
            class="common-tag"
            :class="{ disabled: isTagSelected(tag.id) }"
            @click="!isTagSelected(tag.id) && handleQuickAddTag(tag.id)"
          >
            <template #icon>
              <icon-plus v-if="!isTagSelected(tag.id)" />
              <icon-check v-else />
            </template>
            {{ tag.name }}
          </a-tag>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { IconTag, IconInfoCircle, IconPlus, IconCheck } from '@arco-design/web-vue/es/icon';
import { type Tag } from '@/api/feedback';

interface Props {
  tags: Tag[];
  tagIds: number[];
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'add', tagId: number): void;
  (e: 'remove', tagId: number): void;
}>();

// 模拟所有可用标签
const allTags: Tag[] = [
  { id: 1, name: '功能建议', color: '#165dff', description: '新功能或改进建议' },
  { id: 2, name: 'Bug报告', color: '#f53f3f', description: '系统缺陷或错误报告' },
  { id: 3, name: '性能优化', color: '#722ed1', description: '性能相关问题' },
  { id: 4, name: 'UI/UX改进', color: '#0fc6c2', description: '界面或体验改进' },
  { id: 5, name: '文档改进', color: '#14c9c9', description: '文档相关问题' },
  { id: 6, name: '安全问题', color: '#f53f3f', description: '安全漏洞或风险' },
  { id: 7, name: '紧急', color: '#ff7d00', description: '需要紧急处理' },
  { id: 8, name: '待讨论', color: '#86909c', description: '需要进一步讨论' },
];

// 当前选择的标签
const selectedTag = ref<number | undefined>(undefined);

// 可用标签（排除已选择的）
const availableTags = computed(() => {
  return allTags.filter((tag) => !props.tagIds.includes(tag.id));
});

// 常用标签
const commonTags = computed(() => {
  return allTags.slice(0, 6);
});

// 检查标签是否已选择
const isTagSelected = (tagId: number) => {
  return props.tagIds.includes(tagId);
};

// 处理添加标签
const handleAddTag = (value: number) => {
  if (isTagSelected(value)) {
    selectedTag.value = undefined;
    return;
  }
  emit('add', value);
  selectedTag.value = undefined;
};

// 快速添加标签
const handleQuickAddTag = (tagId: number) => {
  emit('add', tagId);
};

// 处理移除标签
const handleRemoveTag = (tagId: number) => {
  emit('remove', tagId);
};
</script>

<style scoped lang="less">
.tags-card {
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

    .current-tags {
      .tags-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 10px;
      }

      .tags-list {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;

        :deep(.arco-tag) {
          cursor: pointer;
          transition: all 0.2s;

          &:hover {
            opacity: 0.8;
          }
        }
      }

      .no-tags {
        display: flex;
        align-items: center;
        gap: 6px;
        padding: 12px;
        background: var(--color-fill-1);
        border-radius: 6px;
        font-size: 13px;
        color: var(--color-text-3);
      }
    }

    .add-tag {
      .add-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 8px;
      }

      .tag-option {
        display: flex;
        align-items: center;
        gap: 8px;

        .tag-dot {
          width: 10px;
          height: 10px;
          border-radius: 50%;
        }

        .tag-name {
          flex: 1;
        }

        .tag-desc {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }
    }

    .common-tags {
      .common-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 10px;
      }

      .common-list {
        display: flex;
        flex-wrap: wrap;
        gap: 8px;

        .common-tag {
          cursor: pointer;
          transition: all 0.2s;

          &:hover:not(.disabled) {
            opacity: 0.8;
          }

          &.disabled {
            cursor: not-allowed;
            opacity: 0.5;
          }
        }
      }
    }
  }
}
</style>
