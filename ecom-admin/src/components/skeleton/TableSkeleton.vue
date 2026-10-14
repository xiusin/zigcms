<template>
  <div class="table-skeleton">
    <a-skeleton :animation="animation">
      <!-- 表格头部骨架 -->
      <div class="skeleton-header">
        <a-skeleton-line :rows="1" :line-height="32" :line-spacing="16" />
      </div>

      <!-- 表格行骨架 -->
      <div class="skeleton-rows">
        <div v-for="i in rows" :key="i" class="skeleton-row">
          <a-skeleton-line :rows="1" :line-height="40" :line-spacing="8" />
        </div>
      </div>

      <!-- 分页骨架 -->
      <div v-if="showPagination" class="skeleton-pagination">
        <a-skeleton-line :rows="1" :line-height="32" :line-spacing="16" />
      </div>
    </a-skeleton>
  </div>
</template>

<script lang="ts" setup>
import { withDefaults } from 'vue';

interface Props {
  rows?: number;
  showPagination?: boolean;
  animation?: boolean;
}

withDefaults(defineProps<Props>(), {
  rows: 10,
  showPagination: true,
  animation: true,
});
</script>

<style lang="less" scoped>
.table-skeleton {
  padding: 16px;

  .skeleton-header {
    margin-bottom: 16px;
  }

  .skeleton-rows {
    .skeleton-row {
      margin-bottom: 8px;
      border-bottom: 1px solid var(--color-neutral-2);
      padding-bottom: 8px;

      &:last-child {
        border-bottom: none;
      }
    }
  }

  .skeleton-pagination {
    margin-top: 16px;
    padding-top: 16px;
    border-top: 1px solid var(--color-neutral-2);
  }
}
</style>
