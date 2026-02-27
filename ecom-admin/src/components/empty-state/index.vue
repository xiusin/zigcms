<template>
  <div class="empty-state">
    <div class="empty-icon">
      <icon-empty v-if="type === 'default'" />
      <icon-file v-else-if="type === 'data'" />
      <icon-search v-else-if="type === 'search'" />
      <icon-exclamation-circle v-else-if="type === 'error'" />
    </div>
    <div class="empty-title">{{ title || getDefaultTitle() }}</div>
    <div v-if="description" class="empty-description">{{ description }}</div>
    <div v-if="$slots.action" class="empty-action">
      <slot name="action"></slot>
    </div>
  </div>
</template>

<script setup lang="ts">
  interface Props {
    type?: 'default' | 'data' | 'search' | 'error';
    title?: string;
    description?: string;
  }

  const props = withDefaults(defineProps<Props>(), {
    type: 'default',
  });

  const getDefaultTitle = () => {
    const titles: Record<string, string> = {
      default: '暂无数据',
      data: '暂无数据',
      search: '未找到相关内容',
      error: '加载失败',
    };
    return titles[props.type];
  };
</script>

<style scoped lang="less">
  .empty-state {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 60px 20px;
    text-align: center;
  }

  .empty-icon {
    font-size: 64px;
    color: var(--color-text-4);
    margin-bottom: 16px;
    opacity: 0.5;
  }

  .empty-title {
    font-size: 14px;
    font-weight: 500;
    color: var(--color-text-2);
    margin-bottom: 8px;
  }

  .empty-description {
    font-size: 12px;
    color: var(--color-text-3);
    margin-bottom: 20px;
    max-width: 400px;
  }

  .empty-action {
    margin-top: 8px;
  }
</style>
