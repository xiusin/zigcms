<template>
  <div ref="chartRef" class="quality-trend-chart"></div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, onBeforeUnmount } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';
import type { EChartsOption } from 'echarts';
import { getQualityTrend } from '@/api/quality-center';

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

// 初始化图表
const initChart = () => {
  if (!chartRef.value) return;

  chartInstance = echarts.init(chartRef.value);

  // 设置初始配置
  const option: EChartsOption = {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'cross',
        label: {
          backgroundColor: '#6a7985',
        },
      },
    },
    legend: {
      data: ['通过率', 'Bug 数量', '执行次数'],
      top: 10,
    },
    toolbox: {
      feature: {
        dataZoom: {
          yAxisIndex: 'none',
        },
        restore: {},
        saveAsImage: {},
      },
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      containLabel: true,
    },
    dataZoom: [
      {
        type: 'inside',
        start: 0,
        end: 100,
      },
      {
        start: 0,
        end: 100,
      },
    ],
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: [],
    },
    yAxis: [
      {
        type: 'value',
        name: '通过率 (%)',
        position: 'left',
        axisLabel: {
          formatter: '{value}%',
        },
      },
      {
        type: 'value',
        name: '数量',
        position: 'right',
      },
    ],
    series: [
      {
        name: '通过率',
        type: 'line',
        smooth: true,
        yAxisIndex: 0,
        itemStyle: {
          color: '#00B42A',
        },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            {
              offset: 0,
              color: 'rgba(0, 180, 42, 0.3)',
            },
            {
              offset: 1,
              color: 'rgba(0, 180, 42, 0.05)',
            },
          ]),
        },
        data: [],
      },
      {
        name: 'Bug 数量',
        type: 'line',
        smooth: true,
        yAxisIndex: 1,
        itemStyle: {
          color: '#F53F3F',
        },
        data: [],
      },
      {
        name: '执行次数',
        type: 'line',
        smooth: true,
        yAxisIndex: 1,
        itemStyle: {
          color: '#165DFF',
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
    const response = await getQualityTrend(props.timeRange);
    const data = response.data;

    // 提取日期
    const dates = data.map((item: any) => item.date);

    // 提取各指标数据
    const passRates = data.map((item: any) => item.passRate);
    const bugCounts = data.map((item: any) => item.bugCount);
    const executionCounts = data.map((item: any) => item.executionCount);

    chartInstance.setOption({
      xAxis: {
        data: dates,
      },
      series: [
        { data: passRates },
        { data: bugCounts },
        { data: executionCounts },
      ],
    });
  } catch (error) {
    Message.error('加载质量趋势数据失败');
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
.quality-trend-chart {
  width: 100%;
  height: 100%;
  min-height: 300px;
}
</style>
