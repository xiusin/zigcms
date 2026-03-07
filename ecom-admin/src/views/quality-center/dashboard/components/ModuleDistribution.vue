<template>
  <div ref="chartRef" class="module-distribution-chart"></div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';
import type { EChartsOption } from 'echarts';
import { getModuleDistribution } from '@/api/quality-center';

interface Props {
  timeRange: {
    start: string;
    end: string;
  };
  loading?: boolean;
}

const props = defineProps<Props>();
const router = useRouter();

const chartRef = ref<HTMLDivElement>();
let chartInstance: echarts.ECharts | null = null;

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
      type: 'scroll',
    },
    series: [
      {
        name: '模块质量分布',
        type: 'pie',
        radius: ['40%', '70%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 10,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: false,
          position: 'center',
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 20,
            fontWeight: 'bold',
          },
        },
        labelLine: {
          show: false,
        },
        data: [],
      },
    ],
  };

  chartInstance.setOption(option);

  // 点击事件：跳转到模块详情页
  chartInstance.on('click', (params: any) => {
    if (params.data && params.data.moduleId) {
      router.push({
        name: 'ModuleDetail',
        params: { id: params.data.moduleId },
      });
    }
  });

  // 响应式
  window.addEventListener('resize', handleResize);
};

// 加载数据
const loadData = async () => {
  if (!chartInstance) return;

  try {
    const response = await getModuleDistribution(props.timeRange);
    const data = response.data.map((item: any) => ({
      name: item.moduleName,
      value: item.testCaseCount,
      moduleId: item.moduleId,
      passRate: item.passRate,
      bugCount: item.bugCount,
    }));

    chartInstance.setOption({
      series: [
        {
          data,
        },
      ],
      tooltip: {
        formatter: (params: any) => {
          const data = params.data;
          return `
            <div style="padding: 8px;">
              <div style="font-weight: bold; margin-bottom: 4px;">${data.name}</div>
              <div>测试用例: ${data.value}</div>
              <div>通过率: ${data.passRate}%</div>
              <div>Bug 数量: ${data.bugCount}</div>
            </div>
          `;
        },
      },
    });
  } catch (error) {
    Message.error('加载模块分布数据失败');
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
.module-distribution-chart {
  width: 100%;
  height: 100%;
  min-height: 300px;
}
</style>
