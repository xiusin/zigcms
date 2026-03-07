<template>
  <div class="interactive-chart">
    <!-- 工具栏 -->
    <div v-if="showToolbar" class="chart-toolbar">
      <a-space>
        <!-- 钻取返回按钮 -->
        <a-button
          v-if="canDrillUp"
          type="text"
          size="small"
          @click="handleDrillUp"
        >
          <template #icon>
            <icon-arrow-left />
          </template>
          返回上一层
        </a-button>

        <!-- 导出按钮 -->
        <a-dropdown v-if="exportFormats.length > 0" @select="handleExport">
          <a-button type="text" size="small">
            <template #icon>
              <icon-download />
            </template>
            导出
          </a-button>
          <template #content>
            <a-doption v-if="exportFormats.includes('png')" value="png">
              PNG 图片
            </a-doption>
            <a-doption v-if="exportFormats.includes('jpg')" value="jpg">
              JPG 图片
            </a-doption>
            <a-doption v-if="exportFormats.includes('svg')" value="svg">
              SVG 矢量图
            </a-doption>
            <a-doption v-if="exportFormats.includes('pdf')" value="pdf">
              PDF 文档
            </a-doption>
            <a-doption v-if="exportFormats.includes('excel')" value="excel">
              Excel 表格
            </a-doption>
            <a-doption v-if="exportFormats.includes('csv')" value="csv">
              CSV 数据
            </a-doption>
          </template>
        </a-dropdown>

        <!-- 刷新按钮 -->
        <a-button
          v-if="realtime"
          type="text"
          size="small"
          @click="handleRefresh"
        >
          <template #icon>
            <icon-refresh />
          </template>
          刷新
        </a-button>

        <!-- 全屏按钮 -->
        <a-button
          type="text"
          size="small"
          @click="handleFullscreen"
        >
          <template #icon>
            <icon-fullscreen v-if="!isFullscreen" />
            <icon-fullscreen-exit v-else />
          </template>
        </a-button>
      </a-space>
    </div>

    <!-- 图表容器 -->
    <div
      ref="chartContainer"
      class="chart-container"
      :class="{ 'is-fullscreen': isFullscreen }"
      :style="{ height: chartHeight }"
    ></div>

    <!-- 加载状态 -->
    <div v-if="loading" class="chart-loading">
      <a-spin />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import {
  IconArrowLeft,
  IconDownload,
  IconRefresh,
  IconFullscreen,
  IconFullscreenExit,
} from '@arco-design/web-vue/es/icon';
import { useInteractiveChart, type ChartConfig, type DrillDownConfig, type ExportConfig } from '@/composables/useInteractiveChart';

interface Props {
  config: ChartConfig;
  drillDown?: DrillDownConfig;
  exportFormats?: ('png' | 'jpg' | 'svg' | 'pdf' | 'excel' | 'csv')[];
  realtime?: boolean;
  realtimeInterval?: number;
  height?: string;
  showToolbar?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  exportFormats: () => ['png', 'jpg', 'csv'],
  realtime: false,
  realtimeInterval: 5000,
  height: '400px',
  showToolbar: true,
});

const emit = defineEmits<{
  click: [params: any];
  drillDown: [params: any];
  drillUp: [];
  dataUpdate: [data: any];
}>();

// 图表容器
const chartContainer = ref<HTMLElement>();
const loading = ref(false);
const isFullscreen = ref(false);

// 图表高度
const chartHeight = computed(() => {
  return isFullscreen.value ? '100vh' : props.height;
});

// 初始化交互式图表
const {
  canDrillUp,
  currentDrillLevel,
  updateChart,
  drillUp,
  exportChart,
  showLoading,
  hideLoading,
  startRealtime,
  stopRealtime,
} = useInteractiveChart({
  container: chartContainer.value,
  config: props.config,
  drillDown: props.drillDown,
  export: {
    formats: props.exportFormats,
  },
  realtime: props.realtime,
  realtimeInterval: props.realtimeInterval,
  onClick: (params) => {
    emit('click', params);
    if (props.drillDown?.enabled) {
      emit('drillDown', params);
    }
  },
  onDataUpdate: (data) => {
    emit('dataUpdate', data);
  },
});

// 监听配置变化
watch(
  () => props.config,
  (newConfig) => {
    updateChart(newConfig);
  },
  { deep: true }
);

// 钻取返回
const handleDrillUp = () => {
  drillUp();
  emit('drillUp');
};

// 导出图表
const handleExport = async (format: string | number | Record<string, any> | undefined) => {
  if (typeof format !== 'string') return;
  
  loading.value = true;
  showLoading();
  
  try {
    await exportChart(format as any);
  } finally {
    loading.value = false;
    hideLoading();
  }
};

// 刷新数据
const handleRefresh = () => {
  emit('dataUpdate', props.config);
};

// 全屏切换
const handleFullscreen = () => {
  isFullscreen.value = !isFullscreen.value;
  
  if (isFullscreen.value) {
    document.documentElement.requestFullscreen?.();
  } else {
    document.exitFullscreen?.();
  }
};

// 监听全屏变化
const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
};

onMounted(() => {
  document.addEventListener('fullscreenchange', handleFullscreenChange);
});

onUnmounted(() => {
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
  stopRealtime();
});
</script>

<style scoped lang="less">
.interactive-chart {
  position: relative;
  width: 100%;

  .chart-toolbar {
    display: flex;
    justify-content: flex-end;
    padding: 8px 0;
    margin-bottom: 8px;
    border-bottom: 1px solid var(--color-border-2);
  }

  .chart-container {
    width: 100%;
    transition: height 0.3s;

    &.is-fullscreen {
      position: fixed;
      top: 0;
      left: 0;
      right: 0;
      bottom: 0;
      z-index: 9999;
      background: var(--color-bg-1);
    }
  }

  .chart-loading {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
    z-index: 10;
  }
}
</style>
