<template>
  <div class="test-case-report-view">
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="stats-cards">
      <a-col :span="6">
        <a-statistic title="总用例数" :value="data.total">
          <template #prefix>
            <icon-file />
          </template>
        </a-statistic>
      </a-col>
      <a-col :span="6">
        <a-statistic title="通过数" :value="data.passed" :value-style="{ color: '#52c41a' }">
          <template #prefix>
            <icon-check-circle />
          </template>
        </a-statistic>
      </a-col>
      <a-col :span="6">
        <a-statistic title="失败数" :value="data.failed" :value-style="{ color: '#f5222d' }">
          <template #prefix>
            <icon-close-circle />
          </template>
        </a-statistic>
      </a-col>
      <a-col :span="6">
        <a-statistic title="通过率" :value="data.pass_rate" suffix="%" :precision="1">
          <template #prefix>
            <icon-trophy />
          </template>
        </a-statistic>
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="16" class="charts-area">
      <!-- 优先级分布 -->
      <a-col :span="8">
        <a-card title="优先级分布" :bordered="false">
          <div ref="priorityChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>

      <!-- 模块分布 -->
      <a-col :span="16">
        <a-card title="模块分布" :bordered="false">
          <div ref="moduleChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 执行趋势 -->
    <a-row :gutter="16" class="trend-area">
      <a-col :span="24">
        <a-card title="执行趋势" :bordered="false">
          <div ref="trendChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 最近执行 -->
    <a-row :gutter="16" class="recent-area">
      <a-col :span="24">
        <a-card title="最近执行" :bordered="false">
          <a-table
            :columns="executionColumns"
            :data="data.recent_executions"
            :pagination="false"
          >
            <template #result="{ record }">
              <a-tag :color="record.result === 'passed' ? 'green' : 'red'">
                {{ record.result === 'passed' ? '通过' : '失败' }}
              </a-tag>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>

    <!-- 导出按钮 -->
    <div class="export-actions">
      <a-space>
        <a-button type="primary" @click="$emit('export', 'html')">
          <template #icon><icon-download /></template>
          导出 HTML
        </a-button>
        <a-button @click="$emit('export', 'pdf')">
          <template #icon><icon-file-pdf /></template>
          导出 PDF
        </a-button>
        <a-button @click="$emit('export', 'excel')">
          <template #icon><icon-file /></template>
          导出 Excel
        </a-button>
      </a-space>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import * as echarts from 'echarts';
import {
  IconFile,
  IconCheckCircle,
  IconCloseCircle,
  IconTrophy,
  IconDownload,
  IconFilePdf,
} from '@arco-design/web-vue/es/icon';
import type { TestCaseStats } from '@/types/quality-report';

const props = defineProps<{
  data: TestCaseStats;
}>();

defineEmits<{
  export: [format: string];
}>();

const priorityChartRef = ref<HTMLElement>();
const moduleChartRef = ref<HTMLElement>();
const trendChartRef = ref<HTMLElement>();

const executionColumns = [
  { title: '用例ID', dataIndex: 'test_case_id' },
  { title: '用例标题', dataIndex: 'test_case_title' },
  { title: '执行结果', slotName: 'result' },
  { title: '执行人', dataIndex: 'executed_by' },
  { title: '执行时间', dataIndex: 'executed_at' },
];

// 初始化优先级分布图表
const initPriorityChart = () => {
  if (!priorityChartRef.value) return;
  
  const chart = echarts.init(priorityChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: 10,
      top: 'center',
    },
    series: [
      {
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
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 16,
            fontWeight: 'bold',
          },
        },
        data: [
          { value: props.data.priority_high, name: '高优先级', itemStyle: { color: '#f5222d' } },
          { value: props.data.priority_medium, name: '中优先级', itemStyle: { color: '#faad14' } },
          { value: props.data.priority_low, name: '低优先级', itemStyle: { color: '#52c41a' } },
        ],
      },
    ],
  });
};

// 初始化模块分布图表
const initModuleChart = () => {
  if (!moduleChartRef.value) return;
  
  const chart = echarts.init(moduleChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
    },
    legend: {
      data: ['总数', '通过', '失败'],
    },
    xAxis: {
      type: 'category',
      data: props.data.module_distribution.map((m) => m.module_name),
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '总数',
        type: 'bar',
        data: props.data.module_distribution.map((m) => m.total),
        itemStyle: { color: '#1890ff' },
      },
      {
        name: '通过',
        type: 'bar',
        data: props.data.module_distribution.map((m) => m.passed),
        itemStyle: { color: '#52c41a' },
      },
      {
        name: '失败',
        type: 'bar',
        data: props.data.module_distribution.map((m) => m.failed),
        itemStyle: { color: '#f5222d' },
      },
    ],
  });
};

// 初始化执行趋势图表
const initTrendChart = () => {
  if (!trendChartRef.value) return;
  
  const chart = echarts.init(trendChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: props.data.execution_trend.map((t) => t.date),
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '执行数',
        type: 'line',
        data: props.data.execution_trend.map((t) => t.value),
        smooth: true,
        itemStyle: { color: '#1890ff' },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(24, 144, 255, 0.3)' },
            { offset: 1, color: 'rgba(24, 144, 255, 0.1)' },
          ]),
        },
      },
    ],
  });
};

onMounted(() => {
  initPriorityChart();
  initModuleChart();
  initTrendChart();
});

watch(() => props.data, () => {
  initPriorityChart();
  initModuleChart();
  initTrendChart();
});
</script>

<style scoped lang="scss">
.test-case-report-view {
  .stats-cards {
    margin-bottom: 24px;
  }

  .charts-area,
  .trend-area,
  .recent-area {
    margin-bottom: 24px;
  }

  .export-actions {
    margin-top: 24px;
    text-align: right;
  }
}
</style>
