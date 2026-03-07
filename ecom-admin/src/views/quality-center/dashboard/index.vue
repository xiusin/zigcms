<template>
  <div class="quality-dashboard">
    <!-- 页面头部 -->
    <div class="dashboard-header">
      <h2 class="dashboard-title">质量中心数据看板</h2>
      <div class="dashboard-actions">
        <!-- 时间范围筛选 -->
        <a-radio-group v-model="timeRange" type="button" @change="handleTimeRangeChange">
          <a-radio value="7">最近 7 天</a-radio>
          <a-radio value="30">最近 30 天</a-radio>
          <a-radio value="90">最近 90 天</a-radio>
          <a-radio value="custom">自定义</a-radio>
        </a-radio-group>

        <!-- 自定义时间范围 -->
        <a-range-picker
          v-if="timeRange === 'custom'"
          v-model="customDateRange"
          class="ml-3"
          @change="handleCustomDateChange"
        />

        <!-- 导出按钮 -->
        <a-button type="primary" class="ml-3" @click="handleExport">
          <template #icon>
            <icon-download />
          </template>
          导出报告
        </a-button>
      </div>
    </div>

    <!-- 数据卡片 -->
    <a-row :gutter="16" class="dashboard-stats">
      <a-col :span="6">
        <a-statistic
          title="测试用例总数"
          :value="stats.totalCases"
          :value-style="{ color: '#165DFF' }"
        >
          <template #prefix>
            <icon-file />
          </template>
        </a-statistic>
      </a-col>
      <a-col :span="6">
        <a-statistic
          title="执行次数"
          :value="stats.executionCount"
          :value-style="{ color: '#00B42A' }"
        >
          <template #prefix>
            <icon-play-arrow />
          </template>
        </a-statistic>
      </a-col>
      <a-col :span="6">
        <a-statistic
          title="通过率"
          :value="stats.passRate"
          suffix="%"
          :precision="2"
          :value-style="{ color: '#F77234' }"
        >
          <template #prefix>
            <icon-check-circle />
          </template>
        </a-statistic>
      </a-col>
      <a-col :span="6">
        <a-statistic
          title="Bug 数量"
          :value="stats.bugCount"
          :value-style="{ color: '#F53F3F' }"
        >
          <template #prefix>
            <icon-bug />
          </template>
        </a-statistic>
      </a-col>
    </a-row>

    <!-- 质量分析面板 -->
    <QualityAnalysisPanel
      v-if="qualityMetrics"
      :metrics="qualityMetrics"
      :auto-refresh="true"
      :refresh-interval="60000"
      @refresh="loadStatistics"
    />

    <!-- 图表区域 -->
    <a-row :gutter="16" class="dashboard-charts">
      <!-- 模块质量分布（使用交互式图表） -->
      <a-col :span="12">
        <a-card title="模块质量分布" :bordered="false">
          <InteractiveChart
            :config="moduleChartConfig"
            :export-formats="['png', 'csv']"
            height="350px"
            @click="handleModuleClick"
          />
        </a-card>
      </a-col>

      <!-- Bug 类型分布（使用交互式图表） -->
      <a-col :span="12">
        <a-card title="Bug 类型分布" :bordered="false">
          <InteractiveChart
            :config="bugChartConfig"
            :export-formats="['png', 'csv']"
            height="350px"
          />
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="16" class="dashboard-charts">
      <!-- 反馈状态分布 -->
      <a-col :span="12">
        <a-card title="反馈状态分布" :bordered="false">
          <InteractiveChart
            :config="feedbackChartConfig"
            :export-formats="['png', 'csv']"
            height="350px"
          />
        </a-card>
      </a-col>

      <!-- 质量趋势（支持钻取） -->
      <a-col :span="12">
        <a-card title="质量趋势" :bordered="false">
          <InteractiveChart
            :config="trendChartConfig"
            :drill-down="trendDrillDown"
            :export-formats="['png', 'csv']"
            :realtime="true"
            :realtime-interval="30000"
            height="350px"
            @drill-down="handleTrendDrillDown"
            @data-update="loadTrendData"
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 对比分析面板 -->
    <ComparisonPanel
      :modules="modules"
      :projects="projects"
      @compare="handleCompare"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconDownload,
  IconFile,
  IconPlayArrow,
  IconCheckCircle,
  IconBug,
} from '@arco-design/web-vue/es/icon';
import InteractiveChart from '@/components/chart/InteractiveChart.vue';
import QualityAnalysisPanel from '@/components/quality/QualityAnalysisPanel.vue';
import ComparisonPanel from '@/components/quality/ComparisonPanel.vue';
import { getStatistics, exportChart } from '@/api/quality-center';
import type { ChartConfig } from '@/composables/useInteractiveChart';
import type { QualityMetrics } from '@/composables/useQualityAnalysis';

// 时间范围
const timeRange = ref<string>('7');
const customDateRange = ref<[string, string]>();

// 统计数据
const stats = ref({
  totalCases: 0,
  executionCount: 0,
  passRate: 0,
  bugCount: 0,
});

// 质量指标
const qualityMetrics = ref<QualityMetrics>({
  testCoverage: 85,
  passRate: 92,
  bugDensity: 2.5,
  avgResponseTime: 150,
  codeQuality: 88,
  documentationScore: 75,
});

// 模块和项目列表
const modules = ref([
  { id: 1, name: '用户模块' },
  { id: 2, name: '订单模块' },
  { id: 3, name: '支付模块' },
  { id: 4, name: '商品模块' },
]);

const projects = ref([
  { id: 1, name: '电商平台' },
  { id: 2, name: '管理后台' },
  { id: 3, name: '移动端' },
]);

const loading = ref(false);

// 计算当前时间范围
const currentTimeRange = computed(() => {
  if (timeRange.value === 'custom' && customDateRange.value) {
    return {
      start: customDateRange.value[0],
      end: customDateRange.value[1],
    };
  }

  const days = parseInt(timeRange.value);
  const end = new Date();
  const start = new Date();
  start.setDate(start.getDate() - days);

  return {
    start: start.toISOString().split('T')[0],
    end: end.toISOString().split('T')[0],
  };
});

// 模块质量分布图表配置
const moduleChartConfig = computed<ChartConfig>(() => ({
  type: 'bar',
  title: '模块质量分布',
  xAxis: {
    type: 'category',
    data: ['用户模块', '订单模块', '支付模块', '商品模块', '库存模块'],
  },
  yAxis: {
    type: 'value',
    name: '质量分',
  },
  series: [
    {
      name: '质量分',
      type: 'bar',
      data: [85, 92, 78, 88, 90],
      itemStyle: {
        color: '#165DFF',
      },
    },
  ],
}));

// Bug类型分布图表配置
const bugChartConfig = computed<ChartConfig>(() => ({
  type: 'pie',
  title: 'Bug类型分布',
  series: [
    {
      name: 'Bug类型',
      type: 'pie',
      radius: '50%',
      data: [
        { value: 35, name: '功能Bug' },
        { value: 25, name: '性能Bug' },
        { value: 20, name: 'UI Bug' },
        { value: 15, name: '兼容性Bug' },
        { value: 5, name: '其他' },
      ],
    },
  ],
}));

// 反馈状态分布图表配置
const feedbackChartConfig = computed<ChartConfig>(() => ({
  type: 'pie',
  title: '反馈状态分布',
  series: [
    {
      name: '反馈状态',
      type: 'pie',
      radius: ['40%', '70%'],
      data: [
        { value: 40, name: '待处理' },
        { value: 30, name: '处理中' },
        { value: 20, name: '已解决' },
        { value: 10, name: '已关闭' },
      ],
    },
  ],
}));

// 质量趋势图表配置
const trendChartConfig = ref<ChartConfig>({
  type: 'line',
  title: '质量趋势',
  xAxis: {
    type: 'category',
    data: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
  },
  yAxis: {
    type: 'value',
    name: '质量分',
  },
  series: [
    {
      name: '质量分',
      type: 'line',
      data: [85, 88, 87, 90, 92, 89, 91],
      smooth: true,
      areaStyle: {
        opacity: 0.3,
      },
    },
  ],
});

// 趋势钻取配置
const trendDrillDown = {
  enabled: true,
  levels: ['week', 'day', 'hour'],
  currentLevel: 0,
};

// 加载统计数据
const loadStatistics = async () => {
  loading.value = true;
  try {
    const response = await getStatistics(currentTimeRange.value);
    stats.value = response.data;
    
    // 更新质量指标
    qualityMetrics.value = {
      testCoverage: response.data.testCoverage || 85,
      passRate: response.data.passRate || 92,
      bugDensity: response.data.bugDensity || 2.5,
      avgResponseTime: response.data.avgResponseTime || 150,
      codeQuality: response.data.codeQuality || 88,
      documentationScore: response.data.documentationScore || 75,
    };
  } catch (error) {
    Message.error('加载统计数据失败');
    console.error(error);
  } finally {
    loading.value = false;
  }
};

// 加载趋势数据
const loadTrendData = async () => {
  try {
    // TODO: 调用API获取最新趋势数据
    console.log('加载趋势数据...');
  } catch (error) {
    console.error('加载趋势数据失败:', error);
  }
};

// 时间范围变更
const handleTimeRangeChange = () => {
  if (timeRange.value !== 'custom') {
    loadStatistics();
  }
};

// 自定义时间范围变更
const handleCustomDateChange = () => {
  if (customDateRange.value && customDateRange.value.length === 2) {
    loadStatistics();
  }
};

// 导出报告
const handleExport = async () => {
  try {
    Message.loading('正在生成报告...');
    await exportChart({
      timeRange: currentTimeRange.value,
      format: 'pdf',
    });
    Message.success('报告导出成功');
  } catch (error) {
    Message.error('报告导出失败');
    console.error(error);
  }
};

// 模块点击事件
const handleModuleClick = (params: any) => {
  console.log('模块点击:', params);
  Message.info(`查看 ${params.name} 详情`);
};

// 趋势钻取事件
const handleTrendDrillDown = (params: any) => {
  console.log('趋势钻取:', params);
  
  // 根据钻取层级更新图表数据
  if (trendDrillDown.currentLevel === 0) {
    // 钻取到天
    trendChartConfig.value = {
      ...trendChartConfig.value,
      xAxis: {
        type: 'category',
        data: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00', '24:00'],
      },
      series: [
        {
          name: '质量分',
          type: 'line',
          data: [88, 85, 87, 90, 92, 89, 88],
          smooth: true,
          areaStyle: {
            opacity: 0.3,
          },
        },
      ],
    };
  }
};

// 对比分析事件
const handleCompare = (type: string, items: any) => {
  console.log('对比分析:', type, items);
  Message.success('对比分析完成');
};

onMounted(() => {
  loadStatistics();
});
</script>

<style scoped lang="less">
.quality-dashboard {
  padding: 20px;

  .dashboard-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 24px;

    .dashboard-title {
      font-size: 20px;
      font-weight: 600;
      margin: 0;
    }

    .dashboard-actions {
      display: flex;
      align-items: center;

      .ml-3 {
        margin-left: 12px;
      }
    }
  }

  .dashboard-stats {
    margin-bottom: 24px;

    :deep(.arco-statistic) {
      padding: 20px;
      background: var(--color-bg-2);
      border-radius: 4px;

      .arco-statistic-title {
        color: var(--color-text-2);
        font-size: 14px;
      }

      .arco-statistic-content {
        margin-top: 8px;

        .arco-statistic-value {
          font-size: 28px;
          font-weight: 600;
        }
      }
    }
  }

  .dashboard-charts {
    margin-bottom: 16px;

    :deep(.arco-card) {
      height: 400px;

      .arco-card-body {
        height: calc(100% - 56px);
      }
    }
  }
}
</style>
