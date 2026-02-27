<template>
  <div class="feedback-statistics">
    <!-- 页面标题和时间筛选 -->
    <a-card class="header-card" :bordered="false">
      <div class="header-content">
        <div class="page-title">
          <icon-message class="title-icon" />
          <span>反馈统计报表</span>
        </div>
        <div class="header-actions">
          <a-space>
            <a-radio-group
              v-model="dateType"
              type="button"
              size="small"
              @change="handleDateTypeChange"
            >
              <a-radio value="today">今天</a-radio>
              <a-radio value="week">本周</a-radio>
              <a-radio value="month">本月</a-radio>
              <a-radio value="year">本年</a-radio>
              <a-radio value="custom">自定义</a-radio>
            </a-radio-group>
            <a-range-picker
              v-if="dateType === 'custom'"
              v-model="dateRange"
              style="width: 220px"
              size="small"
              @change="handleDateRangeChange"
            />
            <a-button
              type="primary"
              size="small"
              :loading="loading"
              @click="refreshData"
            >
              <template #icon>
                <icon-refresh />
              </template>
              刷新
            </a-button>
          </a-space>
        </div>
      </div>
    </a-card>

    <!-- 统计概览卡片 -->
    <a-row :gutter="16" class="statistics-row">
      <a-col :span="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-item">
            <div
              class="stat-icon"
              style="background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%)"
            >
              <icon-message :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">总反馈数</div>
              <a-statistic
                :value="statistics.total_count"
                :value-from="0"
                animation
                show-group-separator
              />
              <div class="stat-trend">
                <span class="trend-label">较上期</span>
                <span :class="['trend-value', totalTrend >= 0 ? 'up' : 'down']">
                  <icon-arrow-rise v-if="totalTrend >= 0" />
                  <icon-arrow-fall v-else />
                  {{ Math.abs(totalTrend).toFixed(1) }}%
                </span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-item">
            <div
              class="stat-icon"
              style="background: linear-gradient(135deg, #ff7d00 0%, #ff9a2e 100%)"
            >
              <icon-clock-circle :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">待处理数</div>
              <a-statistic
                :value="statistics.pending_count"
                :value-from="0"
                animation
                show-group-separator
              />
              <div class="stat-trend">
                <span class="trend-label">占比</span>
                <span class="trend-value neutral">
                  {{ pendingRate.toFixed(1) }}%
                </span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-item">
            <div
              class="stat-icon"
              style="background: linear-gradient(135deg, #00b42a 0%, #23c343 100%)"
            >
              <icon-calendar :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">本周新增</div>
              <a-statistic
                :value="statistics.week_count"
                :value-from="0"
                animation
                show-group-separator
              />
              <div class="stat-trend">
                <span class="trend-label">较上周</span>
                <span :class="['trend-value', weekTrend >= 0 ? 'up' : 'down']">
                  <icon-arrow-rise v-if="weekTrend >= 0" />
                  <icon-arrow-fall v-else />
                  {{ Math.abs(weekTrend).toFixed(1) }}%
                </span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-item">
            <div
              class="stat-icon"
              style="background: linear-gradient(135deg, #165dff 0%, #4080ff 100%)"
            >
              <icon-check-circle :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">解决率</div>
              <a-statistic
                :value="statistics.resolve_rate"
                :value-from="0"
                :precision="1"
                animation
              >
                <template #suffix>%</template>
              </a-statistic>
              <div class="stat-trend">
                <span class="trend-label">平均处理时长</span>
                <span class="trend-value neutral">
                  {{ statistics.avg_handle_time.toFixed(1) }}h
                </span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="16" class="charts-row">
      <!-- 反馈趋势图 -->
      <a-col :span="16">
        <a-card class="chart-card" :bordered="false">
          <template #title>
            <div class="chart-header">
              <span class="chart-title">反馈趋势</span>
              <a-radio-group
                v-model="trendGranularity"
                type="button"
                size="mini"
                @change="fetchTrendData"
              >
                <a-radio value="day">按日</a-radio>
                <a-radio value="week">按周</a-radio>
                <a-radio value="month">按月</a-radio>
              </a-radio-group>
            </div>
          </template>
          <div ref="trendChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
      <!-- 类型分布图 -->
      <a-col :span="8">
        <a-card class="chart-card" :bordered="false">
          <template #title>
            <span class="chart-title">类型分布</span>
          </template>
          <div ref="typeChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="16" class="charts-row">
      <!-- 优先级分布图 -->
      <a-col :span="12">
        <a-card class="chart-card" :bordered="false">
          <template #title>
            <span class="chart-title">优先级分布</span>
          </template>
          <div ref="priorityChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
      <!-- 状态分布图 -->
      <a-col :span="12">
        <a-card class="chart-card" :bordered="false">
          <template #title>
            <span class="chart-title">状态分布</span>
          </template>
          <div ref="statusChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 处理人效率排行 -->
    <a-card class="ranking-card" :bordered="false">
      <template #title>
        <div class="ranking-header">
          <span class="chart-title">处理人效率排行</span>
          <a-space>
            <a-input-search
              v-model="handlerSearchKeyword"
              placeholder="搜索处理人"
              size="small"
              style="width: 200px"
              allow-clear
              @search="filterHandlerRanking"
            />
            <a-button size="small" @click="exportRanking">
              <template #icon>
                <icon-download />
              </template>
              导出
            </a-button>
          </a-space>
        </div>
      </template>
      <a-table
        :data="filteredHandlerRanking"
        :loading="rankingLoading"
        :pagination="{
          total: filteredHandlerRanking.length,
          pageSize: 10,
          showTotal: true,
          showJumper: true,
        }"
        stripe
      >
        <template #columns>
          <a-table-column title="排名" width="80" align="center">
            <template #cell="{ rowIndex }">
              <div :class="['rank-cell', rowIndex < 3 ? 'top-' + (rowIndex + 1) : '']">
                <icon-trophy v-if="rowIndex < 3" class="rank-icon" />
                <span v-else>{{ rowIndex + 1 }}</span>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="处理人" width="180">
            <template #cell="{ record }">
              <a-space>
                <a-avatar :size="32" :src="record.avatar">
                  <icon-user v-if="!record.avatar" />
                </a-avatar>
                <span>{{ record.name }}</span>
              </a-space>
            </template>
          </a-table-column>
          <a-table-column title="处理数量" width="120" align="center" sortable>
            <template #cell="{ record }">
              <a-tag color="arcoblue">{{ record.handle_count }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="解决数量" width="120" align="center" sortable>
            <template #cell="{ record }">
              <a-tag color="green">{{ record.resolve_count }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="平均处理时长" width="140" align="center" sortable>
            <template #cell="{ record }">
              <span :class="getHandleTimeClass(record.avg_handle_time)">
                {{ record.avg_handle_time.toFixed(1) }}h
              </span>
            </template>
          </a-table-column>
          <a-table-column title="满意度" width="120" align="center" sortable>
            <template #cell="{ record }">
              <a-rate
                :model-value="record.satisfaction_score"
                readonly
                :count="5"
                :allow-half="true"
              />
              <div class="score-text">{{ record.satisfaction_score.toFixed(1) }}</div>
            </template>
          </a-table-column>
          <a-table-column title="解决率" align="center" sortable>
            <template #cell="{ record }">
              <a-progress
                :percent="getResolveRate(record)"
                :color="getProgressColor(getResolveRate(record))"
                size="small"
              />
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted, nextTick } from 'vue';
import * as echarts from 'echarts';
import { Message } from '@arco-design/web-vue';
import {
  getFeedbackStatistics,
  getFeedbackTrend,
  getHandlerRanking,
  FeedbackStatus,
  FeedbackPriority,
  FeedbackType,
  type FeedbackStatisticsResponse,
  type TrendDataItem,
  type HandlerRankingItem,
} from '@/api/feedback';

// ========== 响应式数据 ==========
const loading = ref(false);
const rankingLoading = ref(false);
const dateType = ref('week');
const dateRange = ref<string[]>([]);
const trendGranularity = ref<'day' | 'week' | 'month'>('day');
const handlerSearchKeyword = ref('');

// 图表 DOM 引用
const trendChartRef = ref<HTMLElement>();
const typeChartRef = ref<HTMLElement>();
const priorityChartRef = ref<HTMLElement>();
const statusChartRef = ref<HTMLElement>();

// 图表实例
let trendChart: echarts.ECharts | null = null;
let typeChart: echarts.ECharts | null = null;
let priorityChart: echarts.ECharts | null = null;
let statusChart: echarts.ECharts | null = null;

// 统计数据
const statistics = reactive<FeedbackStatisticsResponse>({
  total_count: 0,
  pending_count: 0,
  processing_count: 0,
  resolved_count: 0,
  today_count: 0,
  week_count: 0,
  month_count: 0,
  avg_handle_time: 0,
  resolve_rate: 0,
});

// 趋势数据
const trendData = ref<TrendDataItem[]>([]);

// 处理人排行数据
const handlerRanking = ref<HandlerRankingItem[]>([]);

// 模拟趋势数据（用于对比）
const prevWeekCount = ref(0);
const prevTotalCount = ref(0);

// ========== 计算属性 ==========
const totalTrend = computed(() => {
  if (prevTotalCount.value === 0) return 0;
  return ((statistics.total_count - prevTotalCount.value) / prevTotalCount.value) * 100;
});

const pendingRate = computed(() => {
  if (statistics.total_count === 0) return 0;
  return (statistics.pending_count / statistics.total_count) * 100;
});

const weekTrend = computed(() => {
  if (prevWeekCount.value === 0) return 0;
  return ((statistics.week_count - prevWeekCount.value) / prevWeekCount.value) * 100;
});

const filteredHandlerRanking = computed(() => {
  if (!handlerSearchKeyword.value) return handlerRanking.value;
  const keyword = handlerSearchKeyword.value.toLowerCase();
  return handlerRanking.value.filter(
    (item) => item.name.toLowerCase().includes(keyword)
  );
});

// ========== 方法 ==========
const getResolveRate = (record: HandlerRankingItem): number => {
  if (record.handle_count === 0) return 0;
  return Math.round((record.resolve_count / record.handle_count) * 100);
};

const getProgressColor = (rate: number): string => {
  if (rate >= 80) return '#00b42a';
  if (rate >= 60) return '#165dff';
  if (rate >= 40) return '#ff7d00';
  return '#f53f3f';
};

const getHandleTimeClass = (time: number): string => {
  if (time <= 24) return 'time-good';
  if (time <= 48) return 'time-normal';
  return 'time-bad';
};

// 获取时间范围
const getTimeRange = (): { start_time?: string; end_time?: string } => {
  const now = new Date();
  const format = (date: Date) => date.toISOString().split('T')[0];

  switch (dateType.value) {
    case 'today':
      return { start_time: format(now), end_time: format(now) };
    case 'week': {
      const weekStart = new Date(now);
      weekStart.setDate(now.getDate() - now.getDay());
      return { start_time: format(weekStart), end_time: format(now) };
    }
    case 'month': {
      const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);
      return { start_time: format(monthStart), end_time: format(now) };
    }
    case 'year': {
      const yearStart = new Date(now.getFullYear(), 0, 1);
      return { start_time: format(yearStart), end_time: format(now) };
    }
    case 'custom':
      if (dateRange.value.length === 2) {
        return { start_time: dateRange.value[0], end_time: dateRange.value[1] };
      }
      return {};
    default:
      return {};
  }
};

// 获取统计数据
const fetchStatistics = async () => {
  try {
    loading.value = true;
    const params = getTimeRange();
    const res = await getFeedbackStatistics(params);
    if (res.data) {
      Object.assign(statistics, res.data);
      // 模拟上期数据用于趋势计算
      prevTotalCount.value = Math.floor(res.data.total_count * 0.9);
      prevWeekCount.value = Math.floor(res.data.week_count * 0.85);
    }
  } catch (error) {
    Message.error('获取统计数据失败');
  } finally {
    loading.value = false;
  }
};

// 获取趋势数据
const fetchTrendData = async () => {
  try {
    const params = {
      ...getTimeRange(),
      granularity: trendGranularity.value,
    };
    const res = await getFeedbackTrend(params);
    if (res.data?.list) {
      trendData.value = res.data.list;
      updateTrendChart();
    }
  } catch (error) {
    Message.error('获取趋势数据失败');
  }
};

// 获取处理人排行
const fetchHandlerRanking = async () => {
  try {
    rankingLoading.value = true;
    const params = getTimeRange();
    const res = await getHandlerRanking(params);
    if (res.data?.list) {
      handlerRanking.value = res.data.list;
    }
  } catch (error) {
    Message.error('获取处理人排行失败');
  } finally {
    rankingLoading.value = false;
  }
};

// 初始化趋势图
const initTrendChart = () => {
  if (!trendChartRef.value) return;
  trendChart = echarts.init(trendChartRef.value);
  updateTrendChart();
};

// 更新趋势图
const updateTrendChart = () => {
  if (!trendChart) return;

  const dates = trendData.value.map((item) => item.date);
  const created = trendData.value.map((item) => item.created);
  const resolved = trendData.value.map((item) => item.resolved);

  const option: echarts.EChartsOption = {
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'cross' },
    },
    legend: {
      data: ['新增反馈', '已解决'],
      bottom: 0,
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '15%',
      top: '10%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      boundaryGap: false,
      data: dates,
      axisLine: { lineStyle: { color: '#e5e6eb' } },
      axisLabel: { color: '#86909c' },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { color: '#f2f3f5' } },
      axisLabel: { color: '#86909c' },
    },
    series: [
      {
        name: '新增反馈',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 8,
        data: created,
        itemStyle: { color: '#165dff' },
        lineStyle: { width: 3 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(22, 93, 255, 0.3)' },
            { offset: 1, color: 'rgba(22, 93, 255, 0.05)' },
          ]),
        },
      },
      {
        name: '已解决',
        type: 'line',
        smooth: true,
        symbol: 'circle',
        symbolSize: 8,
        data: resolved,
        itemStyle: { color: '#00b42a' },
        lineStyle: { width: 3 },
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(0, 180, 42, 0.3)' },
            { offset: 1, color: 'rgba(0, 180, 42, 0.05)' },
          ]),
        },
      },
    ],
  };

  trendChart.setOption(option);
};

// 初始化类型分布图
const initTypeChart = () => {
  if (!typeChartRef.value) return;
  typeChart = echarts.init(typeChartRef.value);

  // 模拟类型分布数据
  const typeData = [
    { value: statistics.total_count * 0.35, name: '功能建议' },
    { value: statistics.total_count * 0.28, name: 'Bug 反馈' },
    { value: statistics.total_count * 0.15, name: '性能问题' },
    { value: statistics.total_count * 0.12, name: '用户体验' },
    { value: statistics.total_count * 0.1, name: '其他' },
  ];

  const option: echarts.EChartsOption = {
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'vertical',
      right: '5%',
      top: 'center',
      itemWidth: 10,
      itemHeight: 10,
      textStyle: { fontSize: 12 },
    },
    color: ['#165dff', '#00b42a', '#ff7d00', '#f53f3f', '#86909c'],
    series: [
      {
        type: 'pie',
        radius: ['45%', '70%'],
        center: ['35%', '50%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 6,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: false,
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
          itemStyle: {
            shadowBlur: 10,
            shadowOffsetX: 0,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
        labelLine: { show: false },
        data: typeData,
      },
    ],
  };

  typeChart.setOption(option);
};

// 初始化优先级分布图
const initPriorityChart = () => {
  if (!priorityChartRef.value) return;
  priorityChart = echarts.init(priorityChartRef.value);

  // 模拟优先级分布数据
  const priorityData = [
    { name: '紧急', value: Math.floor(statistics.total_count * 0.08) },
    { name: '高', value: Math.floor(statistics.total_count * 0.22) },
    { name: '中', value: Math.floor(statistics.total_count * 0.45) },
    { name: '低', value: Math.floor(statistics.total_count * 0.25) },
  ];

  const option: echarts.EChartsOption = {
    tooltip: {
      trigger: 'axis',
      axisPointer: { type: 'shadow' },
    },
    grid: {
      left: '3%',
      right: '4%',
      bottom: '3%',
      top: '10%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      data: priorityData.map((item) => item.name),
      axisLine: { lineStyle: { color: '#e5e6eb' } },
      axisLabel: { color: '#86909c' },
      axisTick: { show: false },
    },
    yAxis: {
      type: 'value',
      axisLine: { show: false },
      axisTick: { show: false },
      splitLine: { lineStyle: { color: '#f2f3f5' } },
      axisLabel: { color: '#86909c' },
    },
    series: [
      {
        type: 'bar',
        barWidth: '40%',
        data: priorityData.map((item, index) => ({
          value: item.value,
          itemStyle: {
            color: ['#f53f3f', '#ff7d00', '#fadc19', '#00b42a'][index],
            borderRadius: [4, 4, 0, 0],
          },
        })),
      },
    ],
  };

  priorityChart.setOption(option);
};

// 初始化状态分布图
const initStatusChart = () => {
  if (!statusChartRef.value) return;
  statusChart = echarts.init(statusChartRef.value);

  const statusData = [
    { value: statistics.pending_count, name: '待处理' },
    { value: statistics.processing_count, name: '处理中' },
    { value: statistics.resolved_count, name: '已解决' },
    { value: Math.floor(statistics.total_count * 0.08), name: '已关闭' },
    { value: Math.floor(statistics.total_count * 0.05), name: '已拒绝' },
  ];

  const option: echarts.EChartsOption = {
    tooltip: {
      trigger: 'item',
      formatter: '{b}: {c} ({d}%)',
    },
    legend: {
      orient: 'horizontal',
      bottom: '5%',
      left: 'center',
      itemWidth: 10,
      itemHeight: 10,
      textStyle: { fontSize: 12 },
    },
    color: ['#86909c', '#165dff', '#00b42a', '#c9cdd4', '#f53f3f'],
    series: [
      {
        type: 'pie',
        radius: ['40%', '65%'],
        center: ['50%', '45%'],
        avoidLabelOverlap: false,
        itemStyle: {
          borderRadius: 4,
          borderColor: '#fff',
          borderWidth: 2,
        },
        label: {
          show: true,
          formatter: '{b}\n{d}%',
          fontSize: 11,
        },
        emphasis: {
          label: {
            show: true,
            fontSize: 14,
            fontWeight: 'bold',
          },
        },
        data: statusData,
      },
    ],
  };

  statusChart.setOption(option);
};

// 初始化所有图表
const initCharts = () => {
  nextTick(() => {
    initTrendChart();
    initTypeChart();
    initPriorityChart();
    initStatusChart();
  });
};

// 刷新所有数据
const refreshData = async () => {
  await Promise.all([
    fetchStatistics(),
    fetchTrendData(),
    fetchHandlerRanking(),
  ]);
  initCharts();
  Message.success('数据已刷新');
};

// 处理日期类型变化
const handleDateTypeChange = () => {
  if (dateType.value !== 'custom') {
    refreshData();
  }
};

// 处理日期范围变化
const handleDateRangeChange = () => {
  if (dateRange.value.length === 2) {
    refreshData();
  }
};

// 筛选处理人排行
const filterHandlerRanking = () => {
  // 通过 computed 属性自动筛选
};

// 导出排行
const exportRanking = () => {
  Message.success('正在导出处理人排行数据...');
  // 实际项目中调用导出 API
};

// 处理窗口大小变化
const handleResize = () => {
  trendChart?.resize();
  typeChart?.resize();
  priorityChart?.resize();
  statusChart?.resize();
};

// ========== 生命周期 ==========
onMounted(() => {
  refreshData();
  window.addEventListener('resize', handleResize);
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
  trendChart?.dispose();
  typeChart?.dispose();
  priorityChart?.dispose();
  statusChart?.dispose();
});
</script>

<style lang="less" scoped>
.feedback-statistics {
  padding: 16px;

  .header-card {
    margin-bottom: 16px;

    :deep(.arco-card-body) {
      padding: 16px 20px;
    }
  }

  .header-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
  }

  .page-title {
    display: flex;
    align-items: center;
    gap: 12px;
    font-size: 18px;
    font-weight: 600;
    color: var(--color-text-1);

    .title-icon {
      font-size: 24px;
      color: #165dff;
    }
  }

  .statistics-row {
    margin-bottom: 16px;
  }

  .stat-card {
    :deep(.arco-card-body) {
      padding: 20px;
    }
  }

  .stat-item {
    display: flex;
    align-items: center;
    gap: 16px;

    .stat-icon {
      width: 56px;
      height: 56px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
      flex-shrink: 0;
    }

    .stat-content {
      flex: 1;
      min-width: 0;

      .stat-label {
        font-size: 14px;
        color: var(--color-text-2);
        margin-bottom: 4px;
      }

      :deep(.arco-statistic-value) {
        font-size: 28px;
        font-weight: 600;
        color: var(--color-text-1);
      }

      :deep(.arco-statistic-suffix) {
        font-size: 16px;
        color: var(--color-text-2);
      }

      .stat-trend {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-top: 4px;
        font-size: 12px;

        .trend-label {
          color: var(--color-text-3);
        }

        .trend-value {
          display: flex;
          align-items: center;
          gap: 2px;
          font-weight: 500;

          &.up {
            color: #00b42a;
          }

          &.down {
            color: #f53f3f;
          }

          &.neutral {
            color: #165dff;
          }
        }
      }
    }
  }

  .charts-row {
    margin-bottom: 16px;
  }

  .chart-card {
    :deep(.arco-card-body) {
      padding: 16px;
    }

    .chart-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .chart-title {
      font-size: 16px;
      font-weight: 500;
      color: var(--color-text-1);
    }

    .chart-container {
      height: 300px;
    }
  }

  .ranking-card {
    :deep(.arco-card-body) {
      padding: 16px;
    }

    .ranking-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }

    .chart-title {
      font-size: 16px;
      font-weight: 500;
      color: var(--color-text-1);
    }

    .rank-cell {
      display: flex;
      align-items: center;
      justify-content: center;
      width: 28px;
      height: 28px;
      border-radius: 50%;
      font-weight: 600;
      font-size: 14px;

      &.top-1 {
        background: linear-gradient(135deg, #ffd700 0%, #ffaa00 100%);
        color: #fff;
      }

      &.top-2 {
        background: linear-gradient(135deg, #c0c0c0 0%, #a0a0a0 100%);
        color: #fff;
      }

      &.top-3 {
        background: linear-gradient(135deg, #cd7f32 0%, #b87333 100%);
        color: #fff;
      }

      &:not(.top-1):not(.top-2):not(.top-3) {
        color: var(--color-text-3);
      }

      .rank-icon {
        font-size: 16px;
      }
    }

    .time-good {
      color: #00b42a;
      font-weight: 500;
    }

    .time-normal {
      color: #ff7d00;
      font-weight: 500;
    }

    .time-bad {
      color: #f53f3f;
      font-weight: 500;
    }

    .score-text {
      font-size: 12px;
      color: var(--color-text-3);
      margin-top: 4px;
    }

    :deep(.arco-rate) {
      font-size: 14px;
    }
  }
}
</style>
