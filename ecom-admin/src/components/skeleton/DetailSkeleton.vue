<template>
  <div class="detail-skeleton">
    <a-skeleton :animation="animation">
      <!-- 标题骨架 -->
      <div v-if="showTitle" class="skeleton-title">
        <a-skeleton-line :rows="1" :line-height="32" :line-spacing="16" />
      </div>

      <!-- 描述列表骨架 -->
      <div class="skeleton-descriptions">
        <div v-for="i in rows" :key="i" class="skeleton-description-item">
          <div class="skeleton-description-label">
            <a-skeleton-line :rows="1" :line-height="20" :line-spacing="8" />
          </div>
          <div class="skeleton-description-content">
            <a-skeleton-line :rows="1" :line-height="20" :line-spacing="8" />
          </div>
        </div>
      </div>

      <!-- 操作按钮骨架 -->
      <div v-if="showActions" class="skeleton-actions">
        <a-skeleton-line :rows="1" :line-height="32" :line-spacing="16" />
      </div>
    </a-skeleton>
  </div>
</template>

<script lang="ts" setup>
import { withDefaults } from 'vue';

interface Props {
  showTitle?: boolean;
  showActions?: boolean;
  rows?: number;
  animation?: boolean;
}

withDefaults(defineProps<Props>(), {
  showTitle: true,
  showActions: true,
  rows: 6,
  animation: true,
});
</script>

<style lang="less" scoped>
.detail-skeleton {
  padding: 16px;

  .skeleton-title {
    margin-bottom: 24px;
    padding-bottom: 16px;
    border-bottom: 1px solid var(--color-neutral-2);
    width: 300px;
  }

  .skeleton-descriptions {
    .skeleton-description-item {
      display: flex;
      margin-bottom: 16px;
      padding: 12px 0;
      border-bottom: 1px solid var(--color-neutral-2);

      &:last-child {
        border-bottom: none;
      }

      .skeleton-description-label {
        width: 150px;
        flex-shrink: 0;
        margin-right: 24px;
      }

      .skeleton-description-content {
        flex: 1;
      }
    }
  }

  .skeleton-actions {
    margin-top: 32px;
    padding-top: 16px;
    border-top: 1px solid var(--color-neutral-2);
    width: 200px;
  }
}
</style>
