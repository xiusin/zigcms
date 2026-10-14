<template>
  <div class="card-skeleton">
    <a-card :bordered="bordered">
      <a-skeleton :animation="animation">
        <!-- 卡片标题骨架 -->
        <div v-if="showTitle" class="skeleton-title">
          <a-skeleton-line :rows="1" :line-height="24" :line-spacing="12" />
        </div>

        <!-- 卡片内容骨架 -->
        <div class="skeleton-content">
          <a-skeleton-line :rows="contentRows" :line-height="20" :line-spacing="12" />
        </div>

        <!-- 卡片底部骨架 -->
        <div v-if="showFooter" class="skeleton-footer">
          <a-skeleton-line :rows="1" :line-height="32" :line-spacing="12" />
        </div>
      </a-skeleton>
    </a-card>
  </div>
</template>

<script lang="ts" setup>
import { withDefaults } from 'vue';

interface Props {
  showTitle?: boolean;
  showFooter?: boolean;
  contentRows?: number;
  bordered?: boolean;
  animation?: boolean;
}

withDefaults(defineProps<Props>(), {
  showTitle: true,
  showFooter: false,
  contentRows: 3,
  bordered: true,
  animation: true,
});
</script>

<style lang="less" scoped>
.card-skeleton {
  .skeleton-title {
    margin-bottom: 16px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--color-neutral-2);
  }

  .skeleton-content {
    margin-bottom: 16px;
  }

  .skeleton-footer {
    padding-top: 12px;
    border-top: 1px solid var(--color-neutral-2);
  }
}
</style>
