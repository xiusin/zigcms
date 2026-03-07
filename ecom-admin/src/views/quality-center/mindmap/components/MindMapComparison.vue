/**
 * 脑图对比组件
 * 【功能】时间维度数据对比、趋势分析
 */
<template>
  <div class="mindmap-comparison">
    <a-card class="comparison-card">
      <template #title>
        <a-space>
          <icon-swap />
          <span>脑图对比分析</span>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" @click="handleCompare" :loading="loading">
            <template #icon><icon-refresh /></template>
            对比
          </a-button>
          <a-button size="small" @click="handleExport">
            <template #icon><icon-download /></template>
            导出对比报告
          </a-button>
        </a-space>
      </template>

      <!-- 时间选择器 -->
      <a-row :gutter="16" class="time-selector">
        <a-col :span="12">
          <a-card size="small" title="基准时间">
            <a-date-picker
              v-model="baselineDate"
              style="width: 100%"
              :disabled-date="disabledBaselineDate"
            />
          </a-card>
        </a-col>
        <a-col :span="12">
          <a-card size="small" title="对比时间">
            <a-date-picker
              v-model="comparisonDate"
              style="width: 100%"
              :disabled-date="disabledComparisonDate"
            />
          </a-card>
        </a-col>
      </a-row>

      <!-- 对比结果 -->
      <div v-if="comparisonResult" class="comparison-result">
        <a-divider>对比结果</a-divider>

        <!-- 总体变化 -->
        <a-row :gutter="16" class="summary-row">
          <a-col :span="6" v-for="metric in summaryMetrics" :key="metric.key">
            <a-card class="metric-card">
              <a-statistic
                :title="metric.label"
                :value="metric.value"
                :value-style="{ color: metric.color }"
              >
                <template #prefix>
                  <icon-arrow-up v-if="metric.trend === 'up'" />
                  <icon-arrow-down v-if="metric.trend === 'down'" />
                  <icon-minus v-if="metric.trend === 'stable'" />
                </template>
                <template #suffix>
                  <span class="trend-text">{{ metric.change }}</span>
                </template>
              </a-statistic>
            </a-card>
          </a-col>
        </a-row>

        <!-- 详细对比表格 -->
        <a-table
          :columns="comparisonColumns"
          :data="comparisonResult.details"
          :pagination="false"
          class="comparison-table"
        >
          <template #module="{ record }">
            <a-space>
              <div
                class="module-indicator"
                :style="{ background: record.color }"
              />
              {{ record.module }}
            </a-space>
          </template>
          <template #baseline="{ record }">
            <a-space direction="vertical" size="mini">
              <div>通过率: {{ record.baseline.passRate }}%</div>
              <div>Bug: {{ record.baseline.bugCount }}</div>
              <div>用例: {{ record.baseline.caseCount }}</div>
            </a-space>
          </template>
          <template #comparison="{ record }">
            <a-space direction="vertical" size="mini">
              <div>通过率: {{ record.comparison.passRate }}%</div>
              <div>Bug: {{ record.comparison.bugCount }}</div>
              <div>用例: {{ record.comparison.caseCount }}</div>
            </a-space>
          </template>
          <template #change="{ record }">
            <a-space direction="vertical" size="mini">
              <a-tag
                :color="record.change.passRate >= 0 ? 'green' : 'red'"
                size="small"
              >
                通过率: {{ record.change.passRate > 0 ? '+' : '' }}{{ record.change.passRate }}%
              </a-tag>
              <a-tag
                :color="record.change.bugCount <= 0 ? 'green' : 'red'"
                size="small"
              >
                Bug: {{ record.change.bugCount > 0 ? '+' : '' }}{{ record.change.bugCount }}
              </a-tag>
              <a-tag
                :color="record.change.caseCount >= 0 ? 'green' : 'orange'"
                size="small"
              >
                用例: {{ record.change.caseCount > 0 ? '+' : '' }}{{ record.change.caseCount }}
              </a-tag>
            </a-space>
          </template>
        </a-table>

        <!-- 趋势图表 -->
        <a-divider>趋势分析</a-divider>
        <div ref="chartRef" class="trend-chart" />
      </div>

      <a-empty v-else description="请选择时间进行对比" />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted, nextTick } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';

// ========== Props ==========
interface Props {
  mode: 'quality' | 'bug-link' | 'feedback';
}

const props = defineProps<Props>();

// ========== 状态 ==========
const loading = ref(false);
const baselineDate = ref<string>('');
const comparisonDate = ref<string>('');
const comparisonResult = ref<any>(null);
const chartRef = ref<HTMLElement | null>(null);
let chartInstance: echarts.ECharts | null = null;

// ========== 计算属性 ==========
const comparisonColumns = [
  {
    title: '模块',
    dataIndex: 'module',
    slotName: 'module',
    width: 150,
  },
  {
    title: '基准数据',
    dataIndex: 'baseline',
    slotName: 'baseline',
    width: 150,
  },
  {
    title: '对比数据',
    dataIndex: 'comparison',
    slotName: 'comparison',
    width: 150,
  },
  {
    title: '变化',
    dataIndex: 'change',
    slotName: 'change',
    width: 200,
  },
];

const summaryMetrics = computed(() => {
  if (!comparisonResult.value) return [];

  const { summary } = comparisonResult.value;
  return [
    {
      key: 'passRate',
      label: '平均通过率',
      value: `${summary.comparison.avgPassRate}%`,
      change: `${summary.change.avgPassRate > 0 ? '+' : ''}${summary.change.avgPassRate}%`,
      trend: summary.change.avgPassRate > 0 ? 'up' : summary.change.avgPassRate < 0 ? 'down' : 'stable',
      color: summary.change.avgPassRate >= 0 ? '#00B42A' : '#F53F3F',
    },
    {
      key: 'bugCount',
      label: 'Bug总数',
      value: summary.comparison.totalBugs,
      change: `${summary.change.totalBugs > 0 ? '+' : ''}${summary.change.totalBugs}`,
      trend: summary.change.totalBugs < 0 ? 'up' : summary.change.totalBugs > 0 ? 'down' : 'stable',
      color: summary.change.totalBugs <= 0 ? '#00B42A' : '#F53F3F',
    },
    {
      key: 'caseCount',
      label: '用例总数',
      value: summary.comparison.totalCases,
      change: `${summary.change.totalCases > 0 ? '+' : ''}${summary.change.totalCases}`,
      trend: summary.change.totalCases > 0 ? 'up' : summary.change.totalCases < 0 ? 'down' : 'stable',
      color: summary.change.totalCases >= 0 ? '#165DFF' : '#FF7D00',
    },
    {
      key: 'quality',
      label: '质量评分',
      value: summary.comparison.qualityScore,
      change: `${summary.change.qualityScore > 0 ? '+' : ''}${summary.change.qualityScore}`,
      trend: summary.change.qualityScore > 0 ? 'up' : summary.change.qualityScore < 0 ? 'down' : 'stable',
      color: summary.change.qualityScore >= 0 ? '#00B42A' : '#F53F3F',
    },
  ];
});

// ========== 方法 ==========
function disabledBaselineDate(current: Date) {
  return current && current > new Date();
}

function disabledComparisonDate(current: Date) {
  if (!baselineDate.value) return current && current > new Date();
  const baseline = new Date(baselineDate.value);
  return current && (current <= baseline || current > new Date());
}

async function handleCompare() {
  if (!baselineDate.value || !comparisonDate.value) {
    Message.warning('请选择基准时间和对比时间');
    return;
  }

  loading.value = true;
  try {
    // 模拟数据获取
    await new Promise(resolve => setTimeout(resolve, 1000));

    // 生成模拟对比数据
    comparisonResult.value = generateMockComparisonData();

    Message.success('对比完成');

    // 渲染图表
    await nextTick();
    renderTrendChart();
  } catch (error) {
    Message.error('对比失败');
    console.error('[脑图对比][失败]', error);
  } finally {
    loading.value = false;
  }
}

function generateMockComparisonData() {
  const modules = ['用户模块', '订单模块', '支付模块', '商品模块', '物流模块'];
  const colors = ['#165DFF', '#00B42A', '#F53F3F', '#FF7D00', '#722ED1'];

  const details = modules.map((module, i) => {
    const baselinePassRate = 70 + Math.random() * 20;
    const comparisonPassRate = baselinePassRate + (Math.random() - 0.5) * 10;
    const baselineBugCount = Math.floor(5 + Math.random() * 10);
    const comparisonBugCount = Math.floor(baselineBugCount + (Math.random() - 0.6) * 5);
    const baselineCaseCount = Math.floor(20 + Math.random() * 30);
    const comparisonCaseCount = Math.floor(baselineCaseCount + (Math.random() - 0.3) * 10);

    return {
      module,
      color: colors[i],
      baseline: {
        passRate: baselinePassRate.toFixed(1),
        bugCount: baselineBugCount,
        caseCount: baselineCaseCount,
      },
      comparison: {
        passRate: comparisonPassRate.toFixed(1),
        bugCount: comparisonBugCount,
        caseCount: comparisonCaseCount,
      },
      change: {
        passRate: (comparisonPassRate - baselinePassRate).toFixed(1),
        bugCount: comparisonBugCount - baselineBugCount,
        caseCount: comparisonCaseCount - baselineCaseCount,
      },
    };
  });

  const summary = {
    baseline: {
      avgPassRate: (details.reduce((s, d) => s + parseFloat(d.baseline.passRate), 0) / details.length).toFixed(1),
      totalBugs: details.reduce((s, d) => s + d.baseline.bugCount, 0),
      totalCases: details.reduce((s, d) => s + d.baseline.caseCount, 0),
      qualityScore: 85,
    },
    comparison: {
      avgPassRate: (details.reduce((s, d) => s + parseFloat(d.comparison.passRate), 0) / details.length).toFixed(1),
      totalBugs: details.reduce((s, d) => s + d.comparison.bugCount, 0),
      totalCases: details.reduce((s, d) => s + d.comparison.caseCount, 0),
      qualityScore: 88,
    },
    change: {
      avgPassRate: 0,
      totalBugs: 0,
      totalCases: 0,
      qualityScore: 0,
    },
  };

  summary.change = {
    avgPassRate: parseFloat((parseFloat(summary.comparison.avgPassRate) - parseFloat(summary.baseline.avgPassRate)).toFixed(1)),
    totalBugs: summary.comparison.totalBugs - summary.baseline.totalBugs,
    totalCases: summary.comparison.totalCases - summary.baseline.totalCases,
    qualityScore: summary.comparison.qualityScore - summary.baseline.qualityScore,
  };

  return { details, summary };
}

function renderTrendChart() {
  if (!chartRef.value || !comparisonResult.value) return;

  if (chartInstance) {
    chartInstance.dispose();
  }

  chartInstance = echarts.init(chartRef.value);

  const modules = comparisonResult.value.details.map((d: any) => d.module);
  const baselineData = comparisonResult.value.details.map((d: any) => parseFloat(d.baseline.passRate));
  const comparisonData = comparisonResult.value.details.map((d: any) => parseFloat(d.comparison.passRate));

  const option = {
    title: {
      text: '通过率对比趋势',
      left: 'center',
    },
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
    },
    legend: {
      data: ['基准时间', '对比时间'],
      bottom: 10,
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '15%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: modules,
      axisLabel: {
        rotate: 30,
      },
    },
    yAxis: {
      type: 'value',
      name: '通过率 (%)',
      min: 0,
      max: 100,
    },
    series: [
      {
        name: '基准时间',
        type: 'bar',
        data: baselineData,
        itemStyle: {
          color: '#86909C',
        },
      },
      {
        name: '对比时间',
        type: 'bar',
        data: comparisonData,
        itemStyle: {
          color: '#165DFF',
        },
      },
    ],
  };

  chartInstance.setOption(option);
}

function handleExport() {
  Message.info('导出对比报告功能开发中...');
}

// ========== 生命周期 ==========
onMounted(() => {
  // 设置默认时间
  const today = new Date();
  const lastWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000);
  baselineDate.value = lastWeek.toISOString().split('T')[0];
  comparisonDate.value = today.toISOString().split('T')[0];
});

watch(() => props.mode, () => {
  comparisonResult.value = null;
  if (chartInstance) {
    chartInstance.dispose();
    chartInstance = null;
  }
});
</script>

<style lang="less" scoped>
.mindmap-comparison {
  padding: 16px;
}

.comparison-card {
  border-radius: 8px;
}

.time-selector {
  margin-bottom: 24px;
}

.comparison-result {
  margin-top: 24px;
}

.summary-row {
  margin-bottom: 24px;

  .metric-card {
    border-radius: 8px;
    text-align: center;

    :deep(.arco-card-body) {
      padding: 16px;
    }

    .trend-text {
      font-size: 12px;
      margin-left: 4px;
    }
  }
}

.comparison-table {
  margin-bottom: 24px;

  .module-indicator {
    width: 12px;
    height: 12px;
    border-radius: 2px;
  }
}

.trend-chart {
  width: 100%;
  height: 400px;
}
</style>
