/**
 * 反馈状态分布环形图组件
 * 【高级特性】ECharts环形图、渐变色、点击交互
 */
<template>
  <div class="feedback-distribution-chart">
    <v-chart
      ref="chartRef"
      :option="chartOption"
      :loading="loading"
      :autoresize="true"
      style="height: 280px"
      @click="handleChartClick"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { PieChart } from 'echarts/charts';
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
} from 'echarts/components';
import VChart from 'vue-echarts';
import type { FeedbackStatusDistribution } from '@/types/quality-center';

use([
  CanvasRenderer,
  PieChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
]);

const props = defineProps<{
  data: FeedbackStatusDistribution[];
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'statusClick', status: number): void;
}>();

const chartRef = ref();

// 反馈状态颜色映射
const statusColors: Record<number, string> = {
  0: '#FF7D00', // 待处理
  1: '#165DFF', // 处理中
  2: '#00B42A', // 已解决
  3: '#86909C', // 已关闭
  4: '#F53F3F', // 已拒绝
};

// 图表配置
const chartOption = computed(() => {
  const chartData = props.data.map(item => ({
    name: item.status_name,
    value: item.count,
    status: item.status,
    itemStyle: {
      color: statusColors[item.status] || '#86909C',
    },
  }));

  return {
    tooltip: {
      trigger: 'item',
      formatter: (params: any) => {
        return `<div style="font-weight: bold; margin-bottom: 4px">${params.name}</div>
          <div style="display: flex; align-items: center; justify-content: space-between">
            <span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: ${params.color}; margin-right: 6px"></span>
            <span>数量: <strong>${params.value}</strong>个</span>
            <span style="margin-left: 12px">占比: <strong>${params.percent}%</strong></span>
          </div>`;
      },
    },
    legend: {
      orient: 'vertical',
      right: '5%',
      top: 'center',
      icon: 'circle',
      itemWidth: 10,
      itemHeight: 10,
      textStyle: {
        fontSize: 12,
      },
      formatter: (name: string) => {
        const item = props.data.find(d => d.status_name === name);
        return `${name}  ${item?.count || 0}`;
      },
    },
    series: [
      {
        name: '反馈状态',
        type: 'pie',
        radius: ['45%', '75%'],
        center: ['35%', '50%'],
        avoidLabelOverlap: true,
        itemStyle: {
          borderRadius: 8,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: true,
          position: 'inside',
          formatter: '{d}%',
          fontSize: 12,
          fontWeight: 'bold',
          color: '#fff',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
        data: chartData,
      },
    ],
  };
});

// 图表点击事件
function handleChartClick(params: any) {
  if (params.componentType === 'series' && params.data) {
    emit('statusClick', params.data.status);
  }
}
</script>

<style lang="less" scoped>
.feedback-distribution-chart {
  width: 100%;
  height: 100%;
}
</style>
