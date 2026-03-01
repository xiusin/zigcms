/**
 * Bug类型分布饼图组件
 * 【高级特性】ECharts饼图、点击钻取、图例交互
 */
<template>
  <div class="bug-distribution-chart">
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
import type { BugTypeDistribution } from '@/types/quality-center';

use([
  CanvasRenderer,
  PieChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
]);

const props = defineProps<{
  data: BugTypeDistribution[];
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'typeClick', type: string): void;
}>();

const chartRef = ref();

// Bug类型颜色映射
const bugTypeColors: Record<string, string> = {
  functional: '#F53F3F',
  ui: '#FF7D00',
  performance: '#F7BA1E',
  security: '#722ED1',
  data: '#165DFF',
  logic: '#0FC6C2',
};

// 图表配置
const chartOption = computed(() => {
  const chartData = props.data.map(item => ({
    name: item.type_name,
    value: item.count,
    type: item.type,
    itemStyle: {
      color: bugTypeColors[item.type] || '#86909C',
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
        const item = props.data.find(d => d.type_name === name);
        return `${name}  ${item?.count || 0}`;
      },
    },
    series: [
      {
        name: 'Bug类型',
        type: 'pie',
        radius: ['40%', '70%'],
        center: ['35%', '50%'],
        avoidLabelOverlap: true,
        itemStyle: {
          borderRadius: 6,
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
    emit('typeClick', params.data.type);
  }
}
</script>

<style lang="less" scoped>
.bug-distribution-chart {
  width: 100%;
  height: 100%;
}
</style>
