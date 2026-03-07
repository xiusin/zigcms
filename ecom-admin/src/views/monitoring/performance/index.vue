<template>
  <div class="performance-monitoring-container">
    <a-card :bordered="false">
      <!-- 页面标题 -->
      <template #title>
        <div class="page-header">
          <a-space>
            <icon-dashboard :size="24" />
            <span class="page-title">性能监控</span>
          </a-space>
        </div>
      </template>

      <!-- 操作栏 -->
      <template #extra>
        <a-space>
          <a-button @click="refreshData">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
          <a-switch v-model="autoRefresh" @change="toggleAutoRefresh">
            <template #checked>自动刷新</template>
            <template #unchecked>手动刷新</template>
          </a-switch>
        </a-space>
      </template>

      <!-- 健康状态 -->
      <div class="health-status">
        <a-alert
          :type="healthStatusType"
          :title="`系统状态: ${healthStatusText}`"
          :description="healthIssues"
          show-icon
        />
      </div>

      <!-- 系统概览 -->
      <div class="system-overview">
        <a-row :gutter="16">
          <!-- HTTP 指标 -->
          <a-col :span="6">
            <a-card class="metric-card" hoverable>
              <a-statistic
                title="HTTP 请求总数"
                :value="overview.http.total_requests || 0"
                :precision="0"
              >
                <template #prefix>
                  <icon-link :style="{ color: '#1890ff' }" />
                </template>
              </a-statistic>
              <div class="metric-detail">
                平均耗时: {{ formatDuration(overview.http.avg_duration) }}
              </div>
            </a-card>
          </a-col>

          <!-- 数据库指标 -->
          <a-col :span="6">
            <a-card class="metric-card" hoverable>
              <a-statistic
                title="数据库查询总数"
                :value="overview.database.total_queries || 0"
                :precision="0"
              >
                <template #prefix>
                  <icon-storage :style="{ color: '#52c41a' }" />
                </template>
              </a-statistic>
              <div class="metric-detail">
                平均耗时: {{ formatDuration(overview.database.avg_duration) }}
              </div>
            </a-card>
          </a-col>

          <!-- 缓存指标 -->
          <a-col :span="6">
            <a-card class="metric-card" hoverable>
              <a-statistic
                title="缓存命中率"
                :value="overview.cache.hit_rate || 0"
                :precision="2"
                suffix="%"
              >
                <template #prefix>
                  <icon-thunderbolt :style="{ color: '#faad14' }" />
                </template>
              </a-statistic>
              <div class="metric-detail">
                缓存性能良好
              </div>
            </a-card>
          </a-col>

          <!-- 活跃用户 -->
          <a-col :span="6">
            <a-card class="metric-card" hoverable>
              <a-statistic
                title="活跃用户数"
                :value="overview.business.active_users || 0"
                :precision="0"
              >
                <template #prefix>
                  <icon-user :style="{ color: '#722ed1' }" />
                </template>
              </a-statistic>
              <div class="metric-detail">
                在线用户
              </div>
            </a-card>
          </a-col>
        </a-row>
      </div>

      <!-- 系统资源 -->
      <div class="system-resources">
        <a-divider>系统资源</a-divider>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-card title="内存使用">
              <div ref="memoryChartRef" style="height: 300px"></div>
            </a-card>
          </a-col>
          <a-col :span="12">
            <a-card title="CPU使用率">
              <div ref="cpuChartRef" style="height: 300px"></div>
            </a-card>
          </a-col>
        </a-row>
      </div>

      <!-- 性能指标 -->
      <div class="performance-metrics">
        <a-divider>性能指标</a-divider>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-card title="HTTP 请求耗时">
              <div ref="httpDurationChartRef" style="height: 300px"></div>
            </a-card>
          </a-col>
          <a-col :span="12">
            <a-card title="数据库查询耗时">
              <div ref="dbDurationChartRef" style="height: 300px"></div>
            </a-card>
          </a-col>
        </a-row>
      </div>

      <!-- 指标列表 -->
      <div class="metrics-list">
        <a-divider>所有指标</a-divider>
        <a-table
          :columns="metricColumns"
          :data="metrics"
          :pagination="false"
          :loading="loading"
        >
          <template #type="{ record }">
            <a-tag :color="getMetricTypeColor(record.type)">
              {{ record.type }}
            </a-tag>
          </template>
          <template #current="{ record }">
            {{ formatMetricValue(record.current, record.unit) }}
          </template>
          <template #actions="{ record }">
            <a-button type="text" size="small" @click="viewMetricDetails(record)">
              查看详情
            </a-button>
          </template>
        </a-table>
      </div>
    </a-card>

    <!-- 指标详情对话框 -->
    <MetricDetailDialog
      v-model:visible="detailDialogVisible"
      :metric="selectedMetric"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconDashboard,
  IconRefresh,
  IconLink,
  IconStorage,
  IconThunderbolt,
  IconUser,
} from '@arco-design/web-vue/es/icon';
import * as echarts from 'echarts';
import {
  getAllMetrics,
  healthCheck,
  getSystemOverview,
} from '@/api/performance';
import type {
  Metric,
  HealthCheckResponse,
  SystemOverview,
  HealthStatus,
} from '@/types/performance';
import MetricDetailDialog from './components/MetricDetailDialog.vue';

// 数据
const loading = ref(false);
const metrics = ref<Metric[]>([]);
const health = ref<HealthCheckResponse>({
  status: 'healthy',
  timestamp: Date.now(),
  issues: [],
});
const overview = ref<SystemOverview>({
  http: { total_requests: null, avg_duration: null },
  database: { total_queries: null, avg_duration: null },
  cache: { hit_rate: null },
  system: { memory_usage: null, cpu_usage: null },
  business: { active_users: null },
});

// 自动刷新
const autoRefresh = ref(true);
let refreshTimer: number | null = null;

// 图表引用
const memoryChartRef = ref<HTMLElement>();
const cpuChartRef = ref<HTMLElement>();
const httpDurationChartRef = ref<HTMLElement>();
const dbDurationChartRef = ref<HTMLElement>();

// 指标详情对话框
const detailDialogVisible = ref(false);
const selectedMetric = ref<Metric | null>(null);

// 健康状态
const healthStatusType = computed(() => {
  switch (health.value.status) {
    case 'healthy':
      return 'success';
    case 'warning':
      return 'warning';
    case 'unhealthy':
      return 'error';
    default:
      return 'info';
  }
});

const healthStatusText = computed(() => {
  switch (health.value.status) {
    case 'healthy':
      return '健康';
    case 'warning':
      return '警告';
    case 'unhealthy':
      return '异常';
    default:
      return '未知';
  }
});

const healthIssues = computed(() => {
  if (health.value.issues.length === 0) {
    return '系统运行正常';
  }
  return health.value.issues.join(', ');
});

// 指标表格列
const metricColumns = [
  { title: '指标名称', dataIndex: 'name', width: 250 },
  { title: '类型', dataIndex: 'type', slotName: 'type', width: 100 },
  { title: '描述', dataIndex: 'description' },
  { title: '当前值', dataIndex: 'current', slotName: 'current', width: 150 },
  { title: '数据点', dataIndex: 'points', width: 100 },
  { title: '操作', slotName: 'actions', width: 120 },
];

// 格式化时长
const formatDuration = (ms: number | null) => {
  if (ms === null) return '-';
  if (ms < 1) return `${(ms * 1000).toFixed(2)} μs`;
  if (ms < 1000) return `${ms.toFixed(2)} ms`;
  return `${(ms / 1000).toFixed(2)} s`;
};

// 格式化指标值
const formatMetricValue = (value: number | null, unit: string) => {
  if (value === null) return '-';
  
  if (unit === 'bytes') {
    if (value < 1024) return `${value.toFixed(2)} B`;
    if (value < 1024 * 1024) return `${(value / 1024).toFixed(2)} KB`;
    if (value < 1024 * 1024 * 1024) return `${(value / 1024 / 1024).toFixed(2)} MB`;
    return `${(value / 1024 / 1024 / 1024).toFixed(2)} GB`;
  }
  
  if (unit === 'ms') {
    return formatDuration(value);
  }
  
  if (unit === 'percent') {
    return `${value.toFixed(2)}%`;
  }
  
  return `${value.toFixed(2)} ${unit}`;
};

// 获取指标类型颜色
const getMetricTypeColor = (type: string) => {
  switch (type) {
    case 'counter':
      return 'blue';
    case 'gauge':
      return 'green';
    case 'histogram':
      return 'orange';
    case 'summary':
      return 'purple';
    default:
      return 'gray';
  }
};

// 刷新数据
const refreshData = async () => {
  loading.value = true;
  
  try {
    // 并行获取数据
    const [metricsRes, healthRes, overviewRes] = await Promise.all([
      getAllMetrics(),
      healthCheck(),
      getSystemOverview(),
    ]);
    
    metrics.value = metricsRes.data;
    health.value = healthRes.data;
    overview.value = overviewRes.data;
    
    // 更新图表
    updateCharts();
  } catch (error) {
    Message.error('数据加载失败');
    console.error(error);
  } finally {
    loading.value = false;
  }
};

// 切换自动刷新
const toggleAutoRefresh = (enabled: boolean) => {
  if (enabled) {
    startAutoRefresh();
  } else {
    stopAutoRefresh();
  }
};

// 启动自动刷新
const startAutoRefresh = () => {
  if (refreshTimer) return;
  
  refreshTimer = window.setInterval(() => {
    refreshData();
  }, 5000); // 每5秒刷新一次
};

// 停止自动刷新
const stopAutoRefresh = () => {
  if (refreshTimer) {
    clearInterval(refreshTimer);
    refreshTimer = null;
  }
};

// 更新图表
const updateCharts = () => {
  updateMemoryChart();
  updateCPUChart();
  updateHTTPDurationChart();
  updateDBDurationChart();
};

// 更新内存图表
const updateMemoryChart = () => {
  if (!memoryChartRef.value) return;
  
  const chart = echarts.init(memoryChartRef.value);
  
  const option = {
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: ['当前'],
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: (value: number) => {
          if (value < 1024) return `${value} B`;
          if (value < 1024 * 1024) return `${(value / 1024).toFixed(0)} KB`;
          if (value < 1024 * 1024 * 1024) return `${(value / 1024 / 1024).toFixed(0)} MB`;
          return `${(value / 1024 / 1024 / 1024).toFixed(2)} GB`;
        },
      },
    },
    series: [
      {
        name: '内存使用',
        type: 'bar',
        data: [overview.value.system.memory_usage || 0],
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#83bff6' },
            { offset: 1, color: '#188df0' },
          ]),
        },
      },
    ],
  };
  
  chart.setOption(option);
};

// 更新CPU图表
const updateCPUChart = () => {
  if (!cpuChartRef.value) return;
  
  const chart = echarts.init(cpuChartRef.value);
  
  const cpuUsage = overview.value.system.cpu_usage || 0;
  
  const option = {
    series: [
      {
        type: 'gauge',
        startAngle: 180,
        endAngle: 0,
        min: 0,
        max: 100,
        splitNumber: 10,
        axisLine: {
          lineStyle: {
            width: 6,
            color: [
              [0.3, '#67e0e3'],
              [0.7, '#37a2da'],
              [1, '#fd666d'],
            ],
          },
        },
        pointer: {
          icon: 'path://M12.8,0.7l12,40.1H0.7L12.8,0.7z',
          length: '12%',
          width: 20,
          offsetCenter: [0, '-60%'],
          itemStyle: {
            color: 'auto',
          },
        },
        axisTick: {
          length: 12,
          lineStyle: {
            color: 'auto',
            width: 2,
          },
        },
        splitLine: {
          length: 20,
          lineStyle: {
            color: 'auto',
            width: 5,
          },
        },
        axisLabel: {
          color: '#464646',
          fontSize: 12,
          distance: -60,
          formatter: (value: number) => `${value}%`,
        },
        title: {
          offsetCenter: [0, '-20%'],
          fontSize: 16,
        },
        detail: {
          fontSize: 24,
          offsetCenter: [0, '0%'],
          valueAnimation: true,
          formatter: (value: number) => `${value.toFixed(1)}%`,
          color: 'auto',
        },
        data: [
          {
            value: cpuUsage,
            name: 'CPU使用率',
          },
        ],
      },
    ],
  };
  
  chart.setOption(option);
};

// 更新HTTP耗时图表
const updateHTTPDurationChart = () => {
  if (!httpDurationChartRef.value) return;
  
  const chart = echarts.init(httpDurationChartRef.value);
  
  const option = {
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: ['平均耗时'],
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: (value: number) => `${value} ms`,
      },
    },
    series: [
      {
        name: 'HTTP请求耗时',
        type: 'bar',
        data: [overview.value.http.avg_duration || 0],
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#2378f7' },
            { offset: 1, color: '#1890ff' },
          ]),
        },
      },
    ],
  };
  
  chart.setOption(option);
};

// 更新数据库耗时图表
const updateDBDurationChart = () => {
  if (!dbDurationChartRef.value) return;
  
  const chart = echarts.init(dbDurationChartRef.value);
  
  const option = {
    tooltip: {
      trigger: 'axis',
    },
    xAxis: {
      type: 'category',
      data: ['平均耗时'],
    },
    yAxis: {
      type: 'value',
      axisLabel: {
        formatter: (value: number) => `${value} ms`,
      },
    },
    series: [
      {
        name: '数据库查询耗时',
        type: 'bar',
        data: [overview.value.database.avg_duration || 0],
        itemStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: '#87d068' },
            { offset: 1, color: '#52c41a' },
          ]),
        },
      },
    ],
  };
  
  chart.setOption(option);
};

// 查看指标详情
const viewMetricDetails = (metric: Metric) => {
  selectedMetric.value = metric;
  detailDialogVisible.value = true;
};

// 初始化
onMounted(() => {
  refreshData();
  if (autoRefresh.value) {
    startAutoRefresh();
  }
});

// 清理
onUnmounted(() => {
  stopAutoRefresh();
});
</script>

<style scoped lang="scss">
.performance-monitoring-container {
  padding: 20px;

  .page-header {
    display: flex;
    align-items: center;

    .page-title {
      font-size: 18px;
      font-weight: 600;
    }
  }

  .health-status {
    margin-bottom: 24px;
  }

  .system-overview {
    margin-bottom: 24px;

    .metric-card {
      .metric-detail {
        margin-top: 8px;
        font-size: 12px;
        color: #666;
      }
    }
  }

  .system-resources,
  .performance-metrics,
  .metrics-list {
    margin-bottom: 24px;
  }
}
</style>
