<template>
  <div ref="chartRef" class="feedback-distribution-chart"></div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, onBeforeUnmount } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';
import type { EChartsOption } from 'echarts';
import { getFeedbackDistribution } from '@/api/quality-center';

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

// 反馈状态颜色映射
const statusColors: Record<string, string> = {
  待处理: '#F53F3F',
  处理中: '#FF7D00',
  已解决: '#00B42A',
  已关闭: '#86909C',
};

// 初始化图表
const initChart = () => {
  if (!chartRef.value) return;

  chartInstance = echarts.init(chartRef.value);

  // 设置初始配置
  const option: EChartsOption = {
    tooltip: {
      trigger: 'item',
      formatter: '{a} <br/>{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: 10,
      top: 'center',
    },
    series: [
      {
        name: '反馈状态分布',
        type: 'pie',
        radius: '70%',
        center: ['40%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 10,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: true,
          formatter: '{b}: {c}',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 16,
            fontWeight: 'bold',
          },
        },
        labelLine: {
          show: true,
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
    const response = await getFeedbackDistribution(props.timeRange);
    const data = response.data.map((item: any) => ({
      name: item.status,
      value: item.count,
      itemStyle: {
        color: statusColors[item.status] || '#165DFF',
      },
    }));

    chartInstance.setOption({
      series: [
        {
          data,
        },
      ],
    });
  } catch (error) {
    Message.error('加载反馈分布数据失败');
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
.feedback-distribution-chart {
  width: 100%;
  height: 100%;
  min-height: 300px;
}
</style>
