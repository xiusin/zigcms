<template>
  <div class="skeleton-wrapper">
    <!-- 表格骨架屏 -->
    <div v-if="type === 'table'" class="skeleton-table">
      <div class="skeleton-header">
        <div class="skeleton-btn"></div>
        <div class="skeleton-btn"></div>
        <div class="skeleton-search"></div>
      </div>
      <div class="skeleton-table-header">
        <div v-for="i in columns" :key="i" class="skeleton-th"></div>
      </div>
      <div v-for="i in rows" :key="i" class="skeleton-row">
        <div v-for="j in columns" :key="j" class="skeleton-td"></div>
      </div>
    </div>

    <!-- 卡片骨架屏 -->
    <div v-else-if="type === 'card'" class="skeleton-card">
      <div class="skeleton-card-header"></div>
      <div class="skeleton-card-body">
        <div v-for="i in 3" :key="i" class="skeleton-line"></div>
      </div>
    </div>

    <!-- 表单骨架屏 -->
    <div v-else-if="type === 'form'" class="skeleton-form">
      <div v-for="i in rows" :key="i" class="skeleton-form-item">
        <div class="skeleton-label"></div>
        <div class="skeleton-input"></div>
      </div>
    </div>

    <!-- 默认骨架屏 -->
    <div v-else class="skeleton-default">
      <div v-for="i in rows" :key="i" class="skeleton-line"></div>
    </div>
  </div>
</template>

<script setup lang="ts">
  interface Props {
    type?: 'table' | 'card' | 'form' | 'default';
    rows?: number;
    columns?: number;
  }

  withDefaults(defineProps<Props>(), {
    type: 'default',
    rows: 5,
    columns: 5,
  });
</script>

<style scoped lang="less">
  @keyframes skeleton-loading {
    0% {
      background-position: 100% 50%;
    }
    100% {
      background-position: 0 50%;
    }
  }

  .skeleton-wrapper {
    padding: 16px;
  }

  .skeleton-mixin {
    background: linear-gradient(90deg, #f2f2f2 25%, #e6e6e6 50%, #f2f2f2 75%);
    background-size: 200% 100%;
    animation: skeleton-loading 1.5s ease-in-out infinite;
    border-radius: 4px;
  }

  // 表格骨架屏
  .skeleton-table {
    .skeleton-header {
      display: flex;
      gap: 12px;
      margin-bottom: 16px;

      .skeleton-btn {
        .skeleton-mixin();
        width: 80px;
        height: 28px;
      }

      .skeleton-search {
        .skeleton-mixin();
        width: 200px;
        height: 28px;
        margin-left: auto;
      }
    }

    .skeleton-table-header {
      display: flex;
      gap: 12px;
      margin-bottom: 12px;

      .skeleton-th {
        .skeleton-mixin();
        flex: 1;
        height: 40px;
      }
    }

    .skeleton-row {
      display: flex;
      gap: 12px;
      margin-bottom: 8px;

      .skeleton-td {
        .skeleton-mixin();
        flex: 1;
        height: 48px;
      }
    }
  }

  // 卡片骨架屏
  .skeleton-card {
    .skeleton-card-header {
      .skeleton-mixin();
      height: 24px;
      width: 150px;
      margin-bottom: 16px;
    }

    .skeleton-card-body {
      .skeleton-line {
        .skeleton-mixin();
        height: 16px;
        margin-bottom: 12px;

        &:last-child {
          width: 60%;
        }
      }
    }
  }

  // 表单骨架屏
  .skeleton-form {
    .skeleton-form-item {
      display: flex;
      align-items: center;
      gap: 16px;
      margin-bottom: 20px;

      .skeleton-label {
        .skeleton-mixin();
        width: 100px;
        height: 20px;
      }

      .skeleton-input {
        .skeleton-mixin();
        flex: 1;
        height: 32px;
      }
    }
  }

  // 默认骨架屏
  .skeleton-default {
    .skeleton-line {
      .skeleton-mixin();
      height: 20px;
      margin-bottom: 12px;

      &:last-child {
        width: 70%;
      }
    }
  }
</style>
