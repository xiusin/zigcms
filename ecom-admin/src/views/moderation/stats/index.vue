<template>
  <div class="moderation-stats">
    <a-card title="审核统计" :bordered="false">
      <!-- 日期筛选 -->
      <div class="filter-bar">
        <a-space>
          <a-range-picker
            v-model="dateRange"
            style="width: 300px"
            @change="handleDateChange"
          />
          <a-button type="primary" @click="loadData">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </div>

      <!-- 统计卡片 -->
      <a-row :gutter="16" class="stats-cards">
        <a-col :span="6">
          <a-card :bordered="false" class="stat-card">
            <a-statistic
              title="总审核数"
              :value="stats.total"
              :value-style="{ color: '#1890ff' }"
            >
              <template #prefix>
                <icon-file-text />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
        <a-col :span="6">
          <a-card :bordered="false" class="stat-card">
            <a-statistic
              title="待审核"
              :value="stats.pending"
              :value-style="{ color: '#faad14' }"
            >
              <template #prefix>
                <icon-clock-circle />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
        <a-col :span="6">
          <a-card :bordered="false" class="stat-card">
            <a-statistic
              title="已通过"
              :value="stats.approved"
              :value-style="{ color: '#52c41a' }"
            >
              <template #prefix>
                <icon-check-circle />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
        <a-col :span="6">
          <a-card :bordered="false" class="stat-card">
            <a-statistic
              title="已拒绝"
              :value="stats.rejected"
              :value-style="{ color: '#f5222d' }"
            >
              <template #prefix>
                <icon-close-circle />
              </template>
            </a-statistic>
          </a-col>
      </a-row>

      <!-- 审核趋势图 -->
      <a-card title="审核趋势" :bordered="false" class="chart-card">
        <div ref="trendChartRef" style="width: 100%; height: 400px"></div>
      </a-card>

      <!-- 敏感词命中统计 -->
      <a-row :gutter="16" class="chart-row">
        <a-col :span="12">
          <a-card title="敏感词命中 Top 10" :bordered="false" class="chart-card">
            <div ref="wordChartRef" style="width: 100%; height: 350px"></div>
          </a-card>
        </a-col>
        <a-col :span="12">
          <a-card title="敏感词分类分布" :bordered="false" class="chart-card">
            <div ref="categoryChartRef" style="width: 100%; height: 350px"></div>
          </a-card>
        </a-col>
      </a-row>

      <!-- 用户违规统计 -->
      <a-card title="用户违规 Top 10" :bordered="false" class="chart-card">
        <a-table
          :columns="userColumns"
          :data="userViolations"
          :pagination="false"
          row-key="user_id"
        >
          <template #user_id="{ record }">
            <a-link>用户 {{ record.user_id }}</a-link>
          </template>

          <template #violation_count="{ record }">
            <a-tag :color="getViolationColor(record.violation_count)">
              {{ record.violation_count }}
            </a-tag>
          </template>

          <template #credit_score="{ record }">
            <a-progress
              :percent="record.credit_score"
              :color="getCreditColor(record.credit_score)"
              :show-text="true"
            />
          </template>

          <template #status="{ record }">
            <a-tag :color="getStatusColor(record.status)">
              {{ getStatusText(record.status) }}
            </a-tag>
          </template>

          <template #last_violation_at="{ record }">
            {{ formatDateTime(record.last_violation_at) }}
          </template>
        </a-table>
      </a-card>

      <!-- 审核效率统计 -->
      <a-row :gutter="16" class="chart-row">
        <a-col :span="12">
          <a-card title="审核方式分布" :bordered="false" class="chart-card">
            <div ref="actionChartRef" style="width: 100%; height: 300px"></div>
          </a-card>
        </a-col>
        <a-col :span="12">
          <a-card title="审核效率" :bordered="false" class="chart-card">
            <a-descriptions :column="1" bordered>
              <a-descriptions-item label="平均审核时长">
                {{ efficiency.avg_review_time }} 分钟
              </a-descriptions-item>
              <a-descriptions-item label="自动处理率">
                {{ efficiency.auto_process_rate }}%
              </a-descriptions-item>
              <a-descriptions-item label="人工审核率">
                {{ efficiency.manual_review_rate }}%
              </a-descriptions-item>
              <a-descriptions-item label="拦截率">
                {{ efficiency.reject_rate }}%
              </a-descriptions-item>
            </a-descriptions>
          </a-card>
        </a-col>
      </a-row>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onBeforeUnmount, nextTick } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';
import { moderationApi } from '@/api/moderation';
import type { ModerationStats } from '@/types/moderation';
import dayjs from 'dayjs';

// 日期范围
const dateRange = ref<[string, string]>([
  dayjs().subtract(7, 'day').format('YYYY-MM-DD'),
  dayjs().format('YYYY-MM-DD'),
]);

// 统计数据
const stats = ref<ModerationStats>({
  total: 0,
  pending: 0,
  approved: 0,
  rejected: 0,
  auto_approved: 0,
  auto_rejected: 0,
});

// 用户违规数据
const userViolations = ref<any[]>([]);

// 审核效率数据
const efficiency = reactive({
  avg_review_time: 0,
  auto_process_rate: 0,
  manual_review_rate: 0,
  reject_rate: 0,
});

// 图表引用
const trendChartRef = ref<HTMLElement>();
const wordChartRef = ref<HTMLElement>();
const categoryChartRef = ref<HTMLElement>();
const actionChartRef = ref<HTMLElement>();

// 图表实例
let trendChart: echarts.ECharts | null = null;
let wordChart: echarts.ECharts | null = null;
let categoryChart: echarts.ECharts | null = null;
let actionChart: echarts.ECharts | null = null;

// 用户违规表格列
const userColumns = [
  { title: '用户ID', dataIndex: 'user_id', slotName: 'user_id', width: 120 },
  { title: '违规次数', dataIndex: 'violation_count', slotName: 'violation_count', width: 120 },
  { title: '信用分', dataIndex: 'credit_score', slotName: 'credit_score', width: 200 },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 120 },
  { title: '最后违规时间', dataIndex: 'last_violation_at', slotName: 'last_violation_at', width: 180 },
];

// 加载数据
const loadData = async () => {
  try {
    // 加载统计数据
    const statsData = await moderationApi.getStats({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
    });
    stats.value = statsData;

    // 加载审核效率数据
    const efficiencyData = await moderationApi.getEfficiencyStats({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
    });
    efficiency.avg_review_time = efficiencyData.avg_review_time;
    efficiency.auto_process_rate = Math.round(efficiencyData.auto_process_rate);
    efficiency.manual_review_rate = Math.round(efficiencyData.manual_review_rate);
    efficiency.reject_rate = Math.round(efficiencyData.reject_rate);

    // 加载图表数据
    await nextTick();
    await initTrendChart();
    await initWordChart();
    await initCategoryChart();
    await initActionChart();
    await loadUserViolations();
  } catch (error) {
    Message.error('加载数据失败');
    console.error('加载数据失败:', error);
  }
};

// 初始化审核趋势图
const initTrendChart = async () => {
  if (!trendChartRef.value) return;

  if (trendChart) {
    trendChart.dispose();
  }

  trendChart = echarts.init(trendChartRef.value);

  try {
    // 从后端获取趋势数据
    const trendData = await moderationApi.getTrend({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
      days: 7,
    });

    const dates = trendData.map((item) => dayjs(item.date).format('MM-DD'));
    const approvedData = trendData.map((item) => item.approved);
    const rejectedData = trendData.map((item) => item.rejected);
    const pendingData = trendData.map((item) => item.pending);

    const option = {
      tooltip: {
        trigger: 'axis',
      },
      legend: {
        data: ['已通过', '已拒绝', '待审核'],
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        containLabel: true,
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: dates,
      },
      yAxis: {
        type: 'value',
      },
      series: [
        {
          name: '已通过',
          type: 'line',
          data: approvedData,
          smooth: true,
          itemStyle: { color: '#52c41a' },
        },
        {
          name: '已拒绝',
          type: 'line',
          data: rejectedData,
          smooth: true,
          itemStyle: { color: '#f5222d' },
        },
        {
          name: '待审核',
          type: 'line',
          data: pendingData,
          smooth: true,
          itemStyle: { color: '#faad14' },
        },
      ],
    };

    trendChart.setOption(option);
  } catch (error) {
    console.error('加载趋势数据失败:', error);
  }
};

// 初始化敏感词命中图
const initWordChart = async () => {
  if (!wordChartRef.value) return;

  if (wordChart) {
    wordChart.dispose();
  }

  wordChart = echarts.init(wordChartRef.value);

  try {
    // 从后端获取敏感词统计数据
    const wordData = await moderationApi.getSensitiveWordStats({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
      limit: 10,
    });

    const option = {
      tooltip: {
        trigger: 'axis',
        axisPointer: {
          type: 'shadow',
        },
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        containLabel: true,
      },
      xAxis: {
        type: 'value',
      },
      yAxis: {
        type: 'category',
        data: wordData.map((item) => item.word),
      },
      series: [
        {
          type: 'bar',
          data: wordData.map((item) => item.hit_count),
          itemStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 1, 0, [
              { offset: 0, color: '#83bff6' },
              { offset: 1, color: '#188df0' },
            ]),
          },
        },
      ],
    };

    wordChart.setOption(option);
  } catch (error) {
    console.error('加载敏感词统计失败:', error);
  }
};

// 初始化敏感词分类图
const initCategoryChart = async () => {
  if (!categoryChartRef.value) return;

  if (categoryChart) {
    categoryChart.dispose();
  }

  categoryChart = echarts.init(categoryChartRef.value);

  try {
    // 从后端获取分类统计数据
    const categoryData = await moderationApi.getCategoryStats({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
    });

    // 分类名称映射
    const categoryNames: Record<string, string> = {
      abuse: '辱骂',
      ad: '广告',
      political: '政治',
      porn: '色情',
      violence: '暴力',
      general: '通用',
    };

    const data = categoryData.map((item) => ({
      name: categoryNames[item.category] || item.category,
      value: item.count,
    }));

    const option = {
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
          name: '敏感词分类',
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
          data: data,
        },
      ],
    };

    categoryChart.setOption(option);
  } catch (error) {
    console.error('加载分类统计失败:', error);
  }
};

// 初始化审核方式图
const initActionChart = async () => {
  if (!actionChartRef.value) return;

  if (actionChart) {
    actionChart.dispose();
  }

  actionChart = echarts.init(actionChartRef.value);

  try {
    // 从后端获取审核方式分布数据
    const actionData = await moderationApi.getActionDistribution({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
    });

    // 动作名称映射
    const actionNames: Record<string, string> = {
      auto_approved: '自动通过',
      auto_rejected: '自动拒绝',
      manual_approved: '人工通过',
      manual_rejected: '人工拒绝',
      pending: '待审核',
    };

    const data = actionData.map((item) => ({
      name: actionNames[item.action] || item.action,
      value: item.count,
    }));

    const option = {
      tooltip: {
        trigger: 'item',
        formatter: '{a} <br/>{b}: {c} ({d}%)',
      },
      legend: {
        bottom: 10,
      },
      series: [
        {
          name: '审核方式',
          type: 'pie',
          radius: '60%',
          data: data,
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

    actionChart.setOption(option);
  } catch (error) {
    console.error('加载审核方式分布失败:', error);
  }
};

// 加载用户违规数据
const loadUserViolations = async () => {
  try {
    // 从后端获取用户违规统计数据
    const data = await moderationApi.getUserViolationStats({
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
      limit: 10,
    });
    userViolations.value = data;
  } catch (error) {
    console.error('加载用户违规数据失败:', error);
  }
};

// 日期变化
const handleDateChange = () => {
  loadData();
};

// 获取违规次数颜色
const getViolationColor = (count: number) => {
  if (count >= 10) return 'red';
  if (count >= 5) return 'orange';
  return 'blue';
};

// 获取信用分颜色
const getCreditColor = (score: number) => {
  if (score >= 80) return '#52c41a';
  if (score >= 60) return '#faad14';
  return '#f5222d';
};

// 获取状态颜色
const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    normal: 'green',
    warning: 'orange',
    restricted: 'red',
    banned: 'magenta',
  };
  return colors[status] || 'gray';
};

// 获取状态文本
const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    normal: '正常',
    warning: '警告',
    restricted: '受限',
    banned: '封禁',
  };
  return texts[status] || status;
};

// 格式化日期时间
const formatDateTime = (dateTime: string) => {
  return dayjs(dateTime).format('YYYY-MM-DD HH:mm:ss');
};

// 窗口大小变化时重绘图表
const handleResize = () => {
  trendChart?.resize();
  wordChart?.resize();
  categoryChart?.resize();
  actionChart?.resize();
};

// 初始化
onMounted(() => {
  loadData();
  window.addEventListener('resize', handleResize);
});

// 清理
onBeforeUnmount(() => {
  window.removeEventListener('resize', handleResize);
  trendChart?.dispose();
  wordChart?.dispose();
  categoryChart?.dispose();
  actionChart?.dispose();
});
</script>

<style scoped lang="scss">
.moderation-stats {
  .filter-bar {
    margin-bottom: 24px;
  }

  .stats-cards {
    margin-bottom: 24px;

    .stat-card {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;

      :deep(.arco-statistic-title) {
        color: rgba(255, 255, 255, 0.85);
      }

      :deep(.arco-statistic-value) {
        color: white;
      }

      &:nth-child(2) {
        background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      }

      &:nth-child(3) {
        background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
      }

      &:nth-child(4) {
        background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
      }
    }
  }

  .chart-card {
    margin-bottom: 24px;
  }

  .chart-row {
    margin-bottom: 24px;
  }
}
</style>
