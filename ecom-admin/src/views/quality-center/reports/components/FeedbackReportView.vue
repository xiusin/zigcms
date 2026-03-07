<template>
  <div class="feedback-report-view">
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="stats-cards">
      <a-col :span="4">
        <a-statistic title="总反馈数" :value="data.total">
          <template #prefix><icon-message /></template>
        </a-statistic>
      </a-col>
      <a-col :span="4">
        <a-statistic title="待处理" :value="data.open" :value-style="{ color: '#faad14' }">
          <template #prefix><icon-clock-circle /></template>
        </a-statistic>
      </a-col>
      <a-col :span="4">
        <a-statistic title="处理中" :value="data.in_progress" :value-style="{ color: '#1890ff' }">
          <template #prefix><icon-loading /></template>
        </a-statistic>
      </a-col>
      <a-col :span="4">
        <a-statistic title="已解决" :value="data.resolved" :value-style="{ color: '#52c41a' }">
          <template #prefix><icon-check-circle /></template>
        </a-statistic>
      </a-col>
      <a-col :span="4">
        <a-statistic title="解决率" :value="data.resolution_rate" suffix="%" :precision="1">
          <template #prefix><icon-trophy /></template>
        </a-statistic>
      </a-col>
      <a-col :span="4">
        <a-statistic title="平均处理时长" :value="data.avg_resolution_time" suffix="小时" :precision="1">
          <template #prefix><icon-clock-circle /></template>
        </a-statistic>
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="16" class="charts-area">
      <!-- 类型分布 -->
      <a-col :span="8">
        <a-card title="类型分布" :bordered="false">
          <div ref="typeChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>

      <!-- 优先级分布 -->
      <a-col :span="8">
        <a-card title="优先级分布" :bordered="false">
          <div ref="priorityChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>

      <!-- 状态分布 -->
      <a-col :span="8">
        <a-card title="状态分布" :bordered="false">
          <div ref="statusChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 处理趋势 -->
    <a-row :gutter="16" class="trend-area">
      <a-col :span="24">
        <a-card title="处理趋势" :bordered="false">
          <div ref="trendChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 最近反馈 -->
    <a-row :gutter="16" class="recent-area">
      <a-col :span="24">
        <a-card title="最近反馈" :bordered="false">
          <a-table
            :columns="feedbackColumns"
            :data="data.recent_feedbacks"
            :pagination="false"
          >
            <template #type="{ record }">
              <a-tag>{{ record.type }}</a-tag>
            </template>
            <template #status="{ record }">
              <a-tag :color="getStatusColor(record.status)">
                {{ getStatusText(record.status) }}
              </a-tag>
            </template>
            <template #priority="{ record }">
              <a-tag :color="getPriorityColor(record.priority)">
                {{ getPriorityText(record.priority) }}
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
  IconMessage,
  IconClockCircle,
  IconLoading,
  IconCheckCircle,
  IconTrophy,
  IconDownload,
  IconFilePdf,
  IconFile,
} from '@arco-design/web-vue/es/icon';
import type { FeedbackStats } from '@/types/quality-report';

const props = defineProps<{
  data: FeedbackStats;
}>();

defineEmits<{
  export: [format: string];
}>();

const typeChartRef = ref<HTMLElement>();
const priorityChartRef = ref<HTMLElement>();
const statusChartRef = ref<HTMLElement>();
const trendChartRef = ref<HTMLElement>();

const feedbackColumns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '标题', dataIndex: 'title' },
  { title: '类型', slotName: 'type', width: 120 },
  { title: '状态', slotName: 'status', width: 100 },
  { title: '优先级', slotName: 'priority', width: 100 },
  { title: '创建时间', dataIndex: 'created_at', width: 180 },
];

const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    open: 'orange',
    in_progress: 'blue',
    resolved: 'green',
    closed: 'gray',
  };
  return colors[status] || 'default';
};

const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    open: '待处理',
    in_progress: '处理中',
    resolved: '已解决',
    closed: '已关闭',
  };
  return texts[status] || status;
};

const getPriorityColor = (priority: string) => {
  const colors: Record<string, string> = {
    high: 'red',
    medium: 'orange',
    low: 'green',
  };
  return colors[priority] || 'default';
};

const getPriorityText = (priority: string) => {
  const texts: Record<string, string> = {
    high: '高',
    medium: '中',
    low: '低',
  };
  return texts[priority] || priority;
};

// 初始化类型分布图表
const initTypeChart = () => {
  if (!typeChartRef.value) return;
  
  const chart = echarts.init(typeChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    series: [
      {
        type: 'pie',
        radius: '70%',
        data: props.data.type_distribution.map((t) => ({
          value: t.count,
          name: t.type_name,
        })),
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
      },
    ],
  });
};

// 初始化优先级分布图表
const initPriorityChart = () => {
  if (!priorityChartRef.value) return;
  
  const chart = echarts.init(priorityChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'item',
    },
    series: [
      {
        type: 'pie',
        radius: ['40%', '70%'],
        data: [
          { value: props.data.priority_high, name: '高优先级', itemStyle: { color: '#f5222d' } },
          { value: props.data.priority_medium, name: '中优先级', itemStyle: { color: '#faad14' } },
          { value: props.data.priority_low, name: '低优先级', itemStyle: { color: '#52c41a' } },
        ],
      },
    ],
  });
};

// 初始化状态分布图表
const initStatusChart = () => {
  if (!statusChartRef.value) return;
  
  const chart = echarts.init(statusChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'item',
    },
    series: [
      {
        type: 'pie',
        radius: '70%',
        data: [
          { value: props.data.open, name: '待处理', itemStyle: { color: '#faad14' } },
          { value: props.data.in_progress, name: '处理中', itemStyle: { color: '#1890ff' } },
          { value: props.data.resolved, name: '已解决', itemStyle: { color: '#52c41a' } },
          { value: props.data.closed, name: '已关闭', itemStyle: { color: '#d9d9d9' } },
        ],
      },
    ],
  });
};

// 初始化处理趋势图表
const initTrendChart = () => {
  if (!trendChartRef.value) return;
  
  const chart = echarts.init(trendChartRef.value);
  chart.setOption({
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: props.data.resolution_trend.map((t) => t.date),
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '解决数',
        type: 'line',
        data: props.data.resolution_trend.map((t) => t.value),
        smooth: true,
        itemStyle: { color: '#52c41a' },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(82, 196, 26, 0.3)' },
            { offset: 1, color: 'rgba(82, 196, 26, 0.1)' },
          ]),
        },
      },
    ],
  });
};

onMounted(() => {
  initTypeChart();
  initPriorityChart();
  initStatusChart();
  initTrendChart();
});

watch(() => props.data, () => {
  initTypeChart();
  initPriorityChart();
  initStatusChart();
  initTrendChart();
});
</script>

<style scoped lang="scss">
.feedback-report-view {
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
