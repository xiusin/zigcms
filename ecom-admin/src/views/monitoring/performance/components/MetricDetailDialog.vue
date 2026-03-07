<template>
  <a-modal
    v-model:visible="modalVisible"
    :title="`指标详情 - ${metric?.name || ''}`"
    width="800px"
    :footer="false"
  >
    <div v-if="metric" class="metric-detail">
      <!-- 基本信息 -->
      <a-descriptions :column="2" bordered>
        <a-descriptions-item label="指标名称">
          {{ metric.name }}
        </a-descriptions-item>
        <a-descriptions-item label="指标类型">
          <a-tag :color="getMetricTypeColor(metric.type)">
            {{ metric.type }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="描述" :span="2">
          {{ metric.description }}
        </a-descriptions-item>
        <a-descriptions-item label="单位">
          {{ metric.unit }}
        </a-descriptions-item>
        <a-descriptions-item label="当前值">
          {{ formatMetricValue(metric.current, metric.unit) }}
        </a-descriptions-item>
        <a-descriptions-item label="数据点数量" :span="2">
          {{ metric.points }}
        </a-descriptions-item>
      </a-descriptions>

      <!-- 统计信息 -->
      <a-divider>统计信息</a-divider>
      <a-row :gutter="16">
        <a-col :span="6">
          <a-statistic title="当前值" :value="stats.current" :precision="2" />
        </a-col>
        <a-col :span="6">
          <a-statistic title="平均值" :value="stats.average" :precision="2" />
        </a-col>
        <a-col :span="6">
          <a-statistic title="最大值" :value="stats.max" :precision="2" />
        </a-col>
        <a-col :span="6">
          <a-statistic title="最小值" :value="stats.min" :precision="2" />
        </a-col>
      </a-row>

      <!-- 趋势图表 -->
      <a-divider>趋势图表</a-divider>
      <div ref="chartRef" style="height: 300px"></div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import * as echarts from 'echarts';
import { getMetricStats } from '@/api/performance';
import type { Metric, MetricStats } from '@/types/performance';

interface Props {
  visible: boolean;
  metric: Metric | null;
}

interface Emits {
  (e: 'update:visible', value: boolean): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// 对话框可见性
const modalVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value),
});

// 图表引用
const chartRef = ref<HTMLElement>();

// 统计数据
const stats = ref<MetricStats>({
  name: '',
  type: 'counter',
  current: 0,
  average: 0,
  max: 0,
  min: 0,
  count: 0,
});

// 获取指标类型颜色
const getMetricTypeColor = (type: string) => {
  switch (type) {
    case 'counter':
      return 'blue';
    case 'gauge':
      return 'green';
    case 'histogram':
      return 'orange';
    case 'summary':
      return 'purple';
    default:
      return 'gray';
  }
};

// 格式化指标值
const formatMetricValue = (value: number | null, unit: string) => {
  if (value === null) return '-';
  
  if (unit === 'bytes') {
    if (value < 1024) return `${value.toFixed(2)} B`;
    if (value < 1024 * 1024) return `${(value / 1024).toFixed(2)} KB`;
    if (value < 1024 * 1024 * 1024) return `${(value / 1024 / 1024).toFixed(2)} MB`;
    return `${(value / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
  
  if (unit === 'ms') {
    if (value < 1) return `${(value * 1000).toFixed(2)} μs`;
    if (value < 1000) return `${value.toFixed(2)} ms`;
    return `${(value / 1000).toFixed(2)} s`;
  }
  
  if (unit === 'percent') {
    return `${value.toFixed(2)}%`;
  }
  
  return `${value.toFixed(2)} ${unit}`;
};

// 加载统计数据
const loadStats = async () => {
  if (!props.metric) return;
  
  try {
    const { data } = await getMetricStats({
      name: props.metric.name,
      duration: 3600, // 1小时
    });
    stats.value = data;
    
    // 更新图表
    updateChart();
  } catch (error) {
    console.error('加载统计数据失败:', error);
  }
};

// 更新图表
const updateChart = () => {
  if (!chartRef.value) return;
  
  const chart = echarts.init(chartRef.value);
  
  const option = {
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: ['当前', '平均', '最大', '最小'],
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: props.metric?.name || '',
        type: 'bar',
        data: [stats.value.current, stats.value.average, stats.value.max, stats.value.min],
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#83bff6' },
            { offset: 1, color: '#188df0' },
          ]),
        },
      },
    ],
  };
  
  chart.setOption(option);
};

// 监听指标变化
watch(() => props.metric, (newMetric) => {
  if (newMetric) {
    loadStats();
  }
});

// 监听可见性变化
watch(() => props.visible, (visible) => {
  if (visible && props.metric) {
    loadStats();
  }
});
</script>

<style scoped lang="scss">
.metric-detail {
  // 样式
}
</style>
