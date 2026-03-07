<template>
  <div class="report-preview">
    <!-- 报告头部 -->
    <div class="report-header">
      <h2>{{ report.title }}</h2>
      <p class="report-period">报告周期: {{ report.period }}</p>
      <p class="report-time">生成时间: {{ formatTime(report.generated_at) }}</p>
      
      <!-- 导出按钮 -->
      <div class="export-buttons">
        <a-space>
          <a-button type="primary" @click="emit('export', 'html')">
            <template #icon>
              <icon-download />
            </template>
            导出HTML
          </a-button>
          <a-button @click="emit('export', 'pdf')">
            <template #icon>
              <icon-file-pdf />
            </template>
            导出PDF
          </a-button>
          <a-button @click="emit('export', 'excel')">
            <template #icon>
              <icon-file />
            </template>
            导出Excel
          </a-button>
        </a-space>
      </div>
    </div>

    <!-- 统计概览 -->
    <div class="report-section">
      <h3>统计概览</h3>
      <a-row :gutter="16">
        <a-col :span="6">
          <a-statistic title="总告警数" :value="report.total_alerts">
            <template #prefix>
              <icon-notification :style="{ color: '#1890ff' }" />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="严重告警" :value="report.critical_alerts">
            <template #prefix>
              <icon-exclamation-circle :style="{ color: '#f5222d' }" />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="高危告警" :value="report.high_alerts">
            <template #prefix>
              <icon-exclamation :style="{ color: '#fa8c16' }" />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="中危告警" :value="report.medium_alerts">
            <template #prefix>
              <icon-info-circle :style="{ color: '#faad14' }" />
            </template>
          </a-statistic>
        </a-col>
      </a-row>

      <a-row :gutter="16" style="margin-top: 16px">
        <a-col :span="6">
          <a-statistic title="总事件数" :value="report.total_events">
            <template #prefix>
              <icon-file-text :style="{ color: '#52c41a' }" />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="被阻断IP" :value="report.blocked_ips">
            <template #prefix>
              <icon-stop :style="{ color: '#f5222d' }" />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="受影响用户" :value="report.affected_users">
            <template #prefix>
              <icon-user :style="{ color: '#fa8c16' }" />
            </template>
          </a-statistic>
        </a-col>
      </a-row>
    </div>

    <!-- 告警趋势 -->
    <div class="report-section">
      <h3>告警趋势</h3>
      <div ref="trendChartRef" style="height: 300px"></div>
    </div>

    <!-- 事件分布 -->
    <div class="report-section">
      <h3>事件分布</h3>
      <div ref="distributionChartRef" style="height: 300px"></div>
    </div>

    <!-- Top攻击类型 -->
    <div class="report-section">
      <h3>Top攻击类型</h3>
      <a-table
        :columns="attackTypeColumns"
        :data="report.top_attack_types"
        :pagination="false"
      />
    </div>

    <!-- Top攻击IP -->
    <div class="report-section">
      <h3>Top攻击IP</h3>
      <a-table
        :columns="attackIPColumns"
        :data="report.top_attack_ips"
        :pagination="false"
      />
    </div>

    <!-- 最近告警 -->
    <div class="report-section">
      <h3>最近告警</h3>
      <a-table
        :columns="alertColumns"
        :data="report.recent_alerts"
        :pagination="false"
      />
    </div>

    <!-- 最近事件 -->
    <div class="report-section">
      <h3>最近事件</h3>
      <a-table
        :columns="eventColumns"
        :data="report.recent_events"
        :pagination="false"
      />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import {
  IconDownload,
  IconFilePdf,
  IconFile,
  IconNotification,
  IconExclamationCircle,
  IconExclamation,
  IconInfoCircle,
  IconFileText,
  IconStop,
  IconUser,
} from '@arco-design/web-vue/es/icon';
import * as echarts from 'echarts';
import dayjs from 'dayjs';
import type { ReportData } from '@/types/security-report';

interface Props {
  report: ReportData;
}

interface Emits {
  (e: 'export', format: string): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// 图表引用
const trendChartRef = ref<HTMLElement>();
const distributionChartRef = ref<HTMLElement>();

// 格式化时间
const formatTime = (timestamp: number) => {
  return dayjs.unix(timestamp).format('YYYY-MM-DD HH:mm:ss');
};

// 攻击类型表格列
const attackTypeColumns = [
  { title: '攻击类型', dataIndex: 'type' },
  { title: '数量', dataIndex: 'count' },
  {
    title: '占比',
    dataIndex: 'percentage',
    render: ({ record }: any) => `${record.percentage.toFixed(2)}%`,
  },
];

// 攻击IP表格列
const attackIPColumns = [
  { title: 'IP地址', dataIndex: 'ip' },
  { title: '攻击次数', dataIndex: 'count' },
  { title: '最后出现', dataIndex: 'last_seen' },
];

// 告警表格列
const alertColumns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  {
    title: '级别',
    dataIndex: 'level',
    width: 100,
    render: ({ record }: any) => {
      const levelMap: Record<string, { color: string; text: string }> = {
        critical: { color: 'red', text: '严重' },
        high: { color: 'orange', text: '高危' },
        medium: { color: 'gold', text: '中危' },
        low: { color: 'blue', text: '低危' },
      };
      const level = levelMap[record.level] || { color: 'gray', text: record.level };
      return `<a-tag color="${level.color}">${level.text}</a-tag>`;
    },
  },
  { title: '类型', dataIndex: 'type', width: 120 },
  { title: '消息', dataIndex: 'message' },
  { title: '时间', dataIndex: 'created_at', width: 180 },
];

// 事件表格列
const eventColumns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '类型', dataIndex: 'type', width: 120 },
  { title: '严重程度', dataIndex: 'severity', width: 100 },
  { title: '描述', dataIndex: 'description' },
  { title: '时间', dataIndex: 'created_at', width: 180 },
];

// 初始化趋势图表
const initTrendChart = () => {
  if (!trendChartRef.value) return;

  const chart = echarts.init(trendChartRef.value);
  
  const option = {
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: props.report.alert_trend.map((item) => item.date),
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '告警数量',
        type: 'line',
        data: props.report.alert_trend.map((item) => item.count),
        smooth: true,
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(24, 144, 255, 0.3)' },
            { offset: 1, color: 'rgba(24, 144, 255, 0.1)' },
          ]),
        },
      },
    ],
  };

  chart.setOption(option);

  // 响应式
  window.addEventListener('resize', () => chart.resize());
};

// 初始化分布图表
const initDistributionChart = () => {
  if (!distributionChartRef.value) return;

  const chart = echarts.init(distributionChartRef.value);
  
  const option = {
    tooltip: {
      trigger: 'item',
    },
    legend: {
      orient: 'vertical',
      left: 'left',
    },
    series: [
      {
        name: '事件分布',
        type: 'pie',
        radius: '50%',
        data: props.report.event_distribution.map((item) => ({
          name: item.name,
          value: item.value,
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
  };

  chart.setOption(option);

  // 响应式
  window.addEventListener('resize', () => chart.resize());
};

// 初始化图表
onMounted(() => {
  initTrendChart();
  initDistributionChart();
});

// 监听报告变化
watch(() => props.report, () => {
  initTrendChart();
  initDistributionChart();
}, { deep: true });
</script>

<style scoped lang="scss">
.report-preview {
  .report-header {
    text-align: center;
    margin-bottom: 32px;

    h2 {
      font-size: 28px;
      font-weight: 600;
      margin-bottom: 8px;
    }

    .report-period {
      font-size: 16px;
      color: #666;
      margin-bottom: 4px;
    }

    .report-time {
      font-size: 14px;
      color: #999;
      margin-bottom: 16px;
    }

    .export-buttons {
      margin-top: 16px;
    }
  }

  .report-section {
    margin-bottom: 32px;

    h3 {
      font-size: 18px;
      font-weight: 600;
      margin-bottom: 16px;
      padding-bottom: 8px;
      border-bottom: 2px solid #1890ff;
    }
  }
}
</style>
