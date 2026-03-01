/**
 * 质量趋势折线图组件
 * 【高级特性】ECharts响应式、数据联动、点击钻取
 */
<template>
  <div class="quality-trend-chart">
    <v-chart
      ref="chartRef"
      :option="chartOption"
      :loading="loading"
      :autoresize="true"
      style="height: 320px"
      @click="handleChartClick"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { use } from 'echarts/core';
import { CanvasRenderer } from 'echarts/renderers';
import { LineChart } from 'echarts/charts';
import {
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
} from 'echarts/components';
import VChart from 'vue-echarts';
import type { TrendDataPoint } from '@/types/quality-center';

use([
  CanvasRenderer,
  LineChart,
  TitleComponent,
  TooltipComponent,
  LegendComponent,
  GridComponent,
  DataZoomComponent,
]);

const props = defineProps<{
  data: TrendDataPoint[];
  loading?: boolean;
}>();

const emit = defineEmits<{
  (e: 'dateClick', date: string): void;
}>();

const chartRef = ref();

// 图表配置
const chartOption = computed(() => {
  const dates = props.data.map(d => d.date);
  const passRates = props.data.map(d => d.pass_rate);
  const bugCounts = props.data.map(d => d.bug_count);
  const feedbackCounts = props.data.map(d => d.feedback_count);
  const executionCounts = props.data.map(d => d.execution_count);

  return {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross',
        label: {
          backgroundColor: '#6a7985',
        },
      },
      formatter: (params: any) => {
        let result = `<div style="font-weight: bold; margin-bottom: 4px">${params[0].axisValue}</div>`;
        params.forEach((item: any) => {
          const unit = item.seriesName === '通过率' ? '%' : item.seriesName === '执行次数' ? '次' : '个';
          result += `<div style="display: flex; align-items: center; margin: 2px 0">
            <span style="display: inline-block; width: 10px; height: 10px; border-radius: 50%; background: ${item.color}; margin-right: 6px"></span>
            <span style="flex: 1">${item.seriesName}</span>
            <span style="font-weight: bold; margin-left: 12px">${item.value}${unit}</span>
          </div>`;
        });
        return result;
      },
    },
    legend: {
      data: ['通过率', 'Bug数', '反馈数', '执行次数'],
      bottom: 0,
      icon: 'roundRect',
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '12%',
      top: '8%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: dates,
      axisLabel: {
        rotate: dates.length > 30 ? 45 : 0,
        fontSize: 11,
      },
    },
    yAxis: [
      {
        type: 'value',
        name: '通过率(%)',
        position: 'left',
        axisLabel: {
          formatter: '{value}%',
        },
        splitLine: {
          lineStyle: {
            type: 'dashed',
          },
        },
      },
      {
        type: 'value',
        name: '数量',
        position: 'right',
        splitLine: {
          show: false,
        },
      },
    ],
    series: [
      {
        name: '通过率',
        type: 'line',
        yAxisIndex: 0,
        data: passRates,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 3,
        },
        areaStyle: {
          opacity: 0.2,
        },
        itemStyle: {
          color: '#00B42A',
        },
      },
      {
        name: 'Bug数',
        type: 'line',
        yAxisIndex: 1,
        data: bugCounts,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 2,
        },
        itemStyle: {
          color: '#F53F3F',
        },
      },
      {
        name: '反馈数',
        type: 'line',
        yAxisIndex: 1,
        data: feedbackCounts,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 2,
        },
        itemStyle: {
          color: '#165DFF',
        },
      },
      {
        name: '执行次数',
        type: 'line',
        yAxisIndex: 1,
        data: executionCounts,
        smooth: true,
        symbol: 'circle',
        symbolSize: 6,
        lineStyle: {
          width: 2,
          type: 'dashed',
        },
        itemStyle: {
          color: '#722ED1',
        },
      },
    ],
    dataZoom: dates.length > 30 ? [
      {
        type: 'inside',
        start: 70,
        end: 100,
      },
      {
        start: 70,
        end: 100,
        height: 20,
        bottom: 30,
      },
    ] : undefined,
  };
});

// 图表点击事件
function handleChartClick(params: any) {
  if (params.componentType === 'series') {
    const date = props.data[params.dataIndex]?.date;
    if (date) {
      emit('dateClick', date);
    }
  }
}

// 监听数据变化自动刷新
watch(() => props.data, () => {
  chartRef.value?.resize();
}, { deep: true });
</script>

<style lang="less" scoped>
.quality-trend-chart {
  width: 100%;
  height: 100%;
}
</style>
