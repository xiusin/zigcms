<template>
  <div class="form-skeleton">
    <a-skeleton :animation="animation">
      <div v-for="i in rows" :key="i" class="skeleton-form-item">
        <!-- 标签骨架 -->
        <div class="skeleton-label">
          <a-skeleton-line :rows="1" :line-height="20" :line-spacing="8" />
        </div>

        <!-- 输入框骨架 -->
        <div class="skeleton-input">
          <a-skeleton-line :rows="1" :line-height="32" :line-spacing="8" />
        </div>
      </div>

      <!-- 按钮组骨架 -->
      <div v-if="showButtons" class="skeleton-buttons">
        <a-skeleton-line :rows="1" :line-height="32" :line-spacing="16" />
      </div>
    </a-skeleton>
  </div>
</template>

<script lang="ts" setup>
import { withDefaults } from 'vue';

interface Props {
  rows?: number;
  showButtons?: boolean;
  animation?: boolean;
}

withDefaults(defineProps<Props>(), {
  rows: 5,
  showButtons: true,
  animation: true,
});
</script>

<style lang="less" scoped>
.form-skeleton {
  padding: 16px;

  .skeleton-form-item {
    margin-bottom: 24px;

    .skeleton-label {
      margin-bottom: 8px;
      width: 120px;
    }

    .skeleton-input {
      width: 100%;
    }
  }

  .skeleton-buttons {
    margin-top: 32px;
    padding-top: 16px;
    border-top: 1px solid var(--color-neutral-2);
    width: 200px;
  }
}
</style>
