<template>
  <div class="chart-skeleton">
    <a-skeleton :animation="animation">
      <!-- 图表标题骨架 -->
      <div v-if="showTitle" class="skeleton-chart-title">
        <a-skeleton-line :rows="1" :line-height="24" :line-spacing="12" />
      </div>

      <!-- 图表内容骨架 -->
      <div class="skeleton-chart-content" :style="{ height: `${height}px` }">
        <div class="skeleton-chart-placeholder">
          <a-skeleton-shape shape="square" :size="height" />
        </div>
      </div>

      <!-- 图表图例骨架 -->
      <div v-if="showLegend" class="skeleton-chart-legend">
        <a-skeleton-line :rows="1" :line-height="20" :line-spacing="12" />
      </div>
    </a-skeleton>
  </div>
</template>

<script lang="ts" setup>
import { withDefaults } from 'vue';

interface Props {
  showTitle?: boolean;
  showLegend?: boolean;
  height?: number;
  animation?: boolean;
}

withDefaults(defineProps<Props>(), {
  showTitle: true,
  showLegend: true,
  height: 300,
  animation: true,
});
</script>

<style lang="less" scoped>
.chart-skeleton {
  .skeleton-chart-title {
    margin-bottom: 16px;
    width: 200px;
  }

  .skeleton-chart-content {
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--color-fill-1);
    border-radius: 4px;

    .skeleton-chart-placeholder {
      width: 100%;
      height: 100%;
      display: flex;
      align-items: center;
      justify-content: center;
    }
  }

  .skeleton-chart-legend {
    width: 300px;
    margin: 0 auto;
  }
}
</style>
