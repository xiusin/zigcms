<template>
  <div ref="chartRef" class="bug-distribution-chart"></div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, onBeforeUnmount } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';
import type { EChartsOption } from 'echarts';
import { getBugDistribution } from '@/api/quality-center';

interface Props {
  timeRange: {
    start: string;
    end: string;
  };
  loading?: boolean;
}

const props = defineProps<Props>();

const chartRef = ref<HTMLDivElement>();
let chartInstance: echarts.ECharts | null = null;

// Bug 类型颜色映射
const bugTypeColors: Record<string, string> = {
  功能缺陷: '#F53F3F',
  性能问题: '#F77234',
  UI问题: '#FF7D00',
  兼容性问题: '#F7BA1E',
};

// 初始化图表
const initChart = () => {
  if (!chartRef.value) return;

  chartInstance = echarts.init(chartRef.value);

  // 设置初始配置
  const option: EChartsOption = {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
    },
    legend: {
      data: ['功能缺陷', '性能问题', 'UI问题', '兼容性问题'],
      top: 10,
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: [],
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '功能缺陷',
        type: 'bar',
        stack: 'total',
        emphasis: {
          focus: 'series',
        },
        itemStyle: {
          color: bugTypeColors['功能缺陷'],
        },
        data: [],
      },
      {
        name: '性能问题',
        type: 'bar',
        stack: 'total',
        emphasis: {
          focus: 'series',
        },
        itemStyle: {
          color: bugTypeColors['性能问题'],
        },
        data: [],
      },
      {
        name: 'UI问题',
        type: 'bar',
        stack: 'total',
        emphasis: {
          focus: 'series',
        },
        itemStyle: {
          color: bugTypeColors['UI问题'],
        },
        data: [],
      },
      {
        name: '兼容性问题',
        type: 'bar',
        stack: 'total',
        emphasis: {
          focus: 'series',
        },
        itemStyle: {
          color: bugTypeColors['兼容性问题'],
        },
        data: [],
      },
    ],
  };

  chartInstance.setOption(option);

  // 响应式
  window.addEventListener('resize', handleResize);
};

// 加载数据
const loadData = async () => {
  if (!chartInstance) return;

  try {
    const response = await getBugDistribution(props.timeRange);
    const data = response.data;

    // 提取模块名称
    const modules = data.map((item: any) => item.moduleName);

    // 提取各类型 Bug 数量
    const functionalBugs = data.map((item: any) => item.functionalBugs || 0);
    const performanceBugs = data.map((item: any) => item.performanceBugs || 0);
    const uiBugs = data.map((item: any) => item.uiBugs || 0);
    const compatibilityBugs = data.map((item: any) => item.compatibilityBugs || 0);

    chartInstance.setOption({
      xAxis: {
        data: modules,
      },
      series: [
        { data: functionalBugs },
        { data: performanceBugs },
        { data: uiBugs },
        { data: compatibilityBugs },
      ],
    });
  } catch (error) {
    Message.error('加载 Bug 分布数据失败');
    console.error(error);
  }
};

// 窗口大小变化
const handleResize = () => {
  chartInstance?.resize();
};

// 监听时间范围变化
watch(
  () => props.timeRange,
  () => {
    loadData();
  },
  { deep: true }
);

onMounted(() => {
  initChart();
  loadData();
});

onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize);
  chartInstance?.dispose();
  chartInstance = null;
});
</script>

<style scoped lang="less">
.bug-distribution-chart {
  width: 100%;
  height: 100%;
  min-height: 300px;
}
</style>
