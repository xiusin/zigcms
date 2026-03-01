/**
 * 质量中心 Dashboard - 融合自动化测试+反馈系统的统一数据总览
 * 【高级特性】响应式栅格布局、Pinia状态驱动、多图表联动、骨架屏优化
 */
<template>
  <div class="quality-dashboard">
    <!-- 加载骨架屏 -->
    <DashboardSkeleton v-if="isInitialLoading" />

    <!-- 主内容 -->
    <div v-else>
    <!-- 顶部统计卡片区域 -->
    <a-row :gutter="16" class="stat-cards">
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="测试通过率"
            :value="store.overview?.pass_rate ?? 0"
            :precision="1"
            suffix="%"
            :value-style="{ color: passRateColor }"
          >
            <template #prefix>
              <icon-check-circle-fill />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="总测试任务"
            :value="store.overview?.total_tasks ?? 0"
            :value-style="{ color: '#165DFF' }"
          >
            <template #prefix>
              <icon-file />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="活跃Bug"
            :value="store.overview?.active_bugs ?? 0"
            :value-style="{ color: '#F53F3F' }"
          >
            <template #prefix>
              <icon-bug />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="待处理反馈"
            :value="store.overview?.pending_feedbacks ?? 0"
            :value-style="{ color: '#FF7D00' }"
          >
            <template #prefix>
              <icon-message />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="AI修复率"
            :value="store.overview?.ai_fix_rate ?? 0"
            :precision="1"
            suffix="%"
            :value-style="{ color: '#722ED1' }"
          >
            <template #prefix>
              <icon-robot />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="本周执行"
            :value="store.overview?.weekly_executions ?? 0"
            :value-style="{ color: '#0FC6C2' }"
          >
            <template #prefix>
              <icon-play-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="反馈转任务"
            :value="store.overview?.feedback_to_task_count ?? 0"
            :value-style="{ color: '#F7BA1E' }"
          >
            <template #prefix>
              <icon-swap />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :xs="12" :sm="6" :md="6" :lg="3">
        <a-card class="stat-card" :loading="store.loading.overview">
          <a-statistic
            title="平均修复时长"
            :value="store.overview?.avg_bug_fix_hours ?? 0"
            :precision="1"
            suffix="h"
            :value-style="{ color: '#86909C' }"
          >
            <template #prefix>
              <icon-clock-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <!-- 第二行：AI洞察 + 质量趋势 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <!-- AI质量洞察 -->
      <a-col :xs="24" :lg="8">
        <a-card title="AI质量洞察" :loading="store.loading.aiInsights" class="insight-card">
          <template #extra>
            <a-tag color="arcoblue" size="small">
              <icon-robot /> AI分析
            </a-tag>
          </template>
          <div v-if="store.aiInsights.length === 0" class="empty-state">
            <a-empty description="暂无洞察数据" />
          </div>
          <div v-else class="insight-list">
            <div
              v-for="insight in store.aiInsights"
              :key="insight.id"
              class="insight-item"
              :class="`insight-${insight.severity}`"
            >
              <div class="insight-header">
                <a-tag
                  :color="insightSeverityColor(insight.severity)"
                  size="small"
                >
                  {{ insightSeverityText(insight.severity) }}
                </a-tag>
                <a-tag size="small" :color="insightTypeColor(insight.type)">
                  {{ insightTypeText(insight.type) }}
                </a-tag>
                <span v-if="insight.module" class="insight-module">
                  {{ insight.module }}
                </span>
              </div>
              <div class="insight-title">{{ insight.title }}</div>
              <div class="insight-desc">{{ insight.description }}</div>
              <div v-if="insight.action_url" class="insight-action">
                <a-link @click="handleInsightAction(insight)">
                  {{ insight.action_text || '查看详情' }}
                  <icon-right />
                </a-link>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>

      <!-- 质量趋势图 - ECharts折线图 -->
      <a-col :xs="24" :lg="16">
        <a-card title="质量趋势" :loading="store.loading.trend" class="trend-card">
          <template #extra>
            <a-radio-group
              v-model="trendPeriod"
              type="button"
              size="small"
              @change="handleTrendPeriodChange"
            >
              <a-radio value="week">近7天</a-radio>
              <a-radio value="month">近30天</a-radio>
              <a-radio value="quarter">近90天</a-radio>
            </a-radio-group>
          </template>
          <div class="trend-chart-container">
            <div v-if="!store.trend?.trend_data?.length" class="empty-state">
              <a-empty description="暂无趋势数据" />
            </div>
            <QualityTrendChart
              v-else
              :data="store.trend.trend_data"
              :loading="store.loading.trend"
              @date-click="handleTrendDateClick"
            />
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 第三行：模块质量 + Bug分布 + 反馈分布 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <!-- 模块质量分布 -->
      <a-col :xs="24" :lg="10">
        <a-card title="模块质量分布" :loading="store.loading.moduleQuality">
          <template #extra>
            <a-link @click="$router.push('/auto-test/report')">查看报告</a-link>
          </template>
          <a-table
            :columns="moduleColumns"
            :data="store.moduleQuality"
            :pagination="false"
            size="small"
            stripe
          >
            <template #pass_rate="{ record }">
              <a-progress
                :percent="record.pass_rate / 100"
                :status="record.pass_rate >= 90 ? 'success' : record.pass_rate >= 70 ? 'warning' : 'danger'"
                size="small"
                style="width: 100px"
              />
              <span style="margin-left: 8px; font-size: 12px">{{ record.pass_rate }}%</span>
            </template>
            <template #bug_count="{ record }">
              <a-tag :color="record.bug_count > 5 ? 'red' : record.bug_count > 2 ? 'orange' : 'green'" size="small">
                {{ record.bug_count }}
              </a-tag>
            </template>
          </a-table>
        </a-card>
      </a-col>

      <!-- Bug类型分布 - ECharts饼图 -->
      <a-col :xs="24" :sm="12" :lg="7">
        <a-card title="Bug类型分布" :loading="store.loading.bugDistribution">
          <template #extra>
            <a-link @click="$router.push('/auto-test/bug')">查看全部</a-link>
          </template>
          <div v-if="store.bugDistribution.length === 0" class="empty-state">
            <a-empty description="暂无数据" />
          </div>
          <BugDistributionChart
            v-else
            :data="store.bugDistribution"
            :loading="store.loading.bugDistribution"
            @type-click="handleBugTypeClick"
          />
        </a-card>
      </a-col>

      <!-- 反馈状态分布 - ECharts环形图 -->
      <a-col :xs="24" :sm="12" :lg="7">
        <a-card title="反馈状态分布" :loading="store.loading.feedbackDistribution">
          <template #extra>
            <a-link @click="$router.push('/feedback/list')">查看全部</a-link>
          </template>
          <div v-if="store.feedbackDistribution.length === 0" class="empty-state">
            <a-empty description="暂无数据" />
          </div>
          <FeedbackDistributionChart
            v-else
            :data="store.feedbackDistribution"
            :loading="store.loading.feedbackDistribution"
            @status-click="handleFeedbackStatusClick"
          />
        </a-card>
      </a-col>
    </a-row>

    <!-- 第四行：活动流 + 关联记录 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <!-- 最近活动 -->
      <a-col :xs="24" :lg="14">
        <a-card title="最近活动" :loading="store.loading.activities">
          <template #extra>
            <a-space>
              <a-select
                v-model="activityFilter"
                placeholder="筛选类型"
                allow-clear
                size="small"
                style="width: 120px"
                @change="handleActivityFilter"
              >
                <a-option value="test_pass">测试通过</a-option>
                <a-option value="test_fail">测试失败</a-option>
                <a-option value="bug_found">发现Bug</a-option>
                <a-option value="bug_fixed">Bug修复</a-option>
                <a-option value="feedback_created">新反馈</a-option>
                <a-option value="feedback_resolved">反馈解决</a-option>
                <a-option value="ai_analysis">AI分析</a-option>
                <a-option value="ai_fix">AI修复</a-option>
              </a-select>
            </a-space>
          </template>
          <a-timeline v-if="store.activities.length > 0" class="activity-timeline">
            <a-timeline-item
              v-for="activity in store.activities"
              :key="activity.id"
              :dot-color="activityColor(activity.type)"
            >
              <div class="activity-item">
                <div class="activity-header">
                  <a-tag :color="activityColor(activity.type)" size="small">
                    {{ activity.title }}
                  </a-tag>
                  <span class="activity-module">{{ activity.module }}</span>
                  <span class="activity-time">{{ activity.created_at }}</span>
                </div>
                <div class="activity-desc">{{ activity.description }}</div>
                <div class="activity-user">
                  <a-avatar :size="20" :style="{ marginRight: '4px' }">
                    {{ activity.user_name?.[0] }}
                  </a-avatar>
                  <span>{{ activity.user_name }}</span>
                </div>
              </div>
            </a-timeline-item>
          </a-timeline>
          <a-empty v-else description="暂无活动记录" />
        </a-card>
      </a-col>

      <!-- 关联记录 -->
      <a-col :xs="24" :lg="10">
        <a-card title="关联记录" :loading="store.loading.linkRecords">
          <template #extra>
            <a-button type="primary" size="small" @click="showFeedbackToTaskModal = true">
              <icon-swap /> 反馈转任务
            </a-button>
          </template>
          <a-table
            :columns="linkColumns"
            :data="store.linkRecords"
            :pagination="{ pageSize: 5, simple: true }"
            size="small"
          >
            <template #source="{ record }">
              <a-tag :color="linkTypeColor(record.source_type)" size="small">
                {{ linkTypeText(record.source_type) }}
              </a-tag>
              <a-tooltip :content="record.source_title">
                <span class="link-title">{{ truncate(record.source_title, 12) }}</span>
              </a-tooltip>
            </template>
            <template #target="{ record }">
              <a-tag :color="linkTypeColor(record.target_type)" size="small">
                {{ linkTypeText(record.target_type) }}
              </a-tag>
              <a-tooltip :content="record.target_title">
                <span class="link-title">{{ truncate(record.target_title, 12) }}</span>
              </a-tooltip>
            </template>
            <template #created_at="{ record }">
              <span class="link-time">{{ record.created_at }}</span>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>

    <!-- 反馈转测试任务弹窗 -->
    <FeedbackToTaskModal
      v-model:visible="showFeedbackToTaskModal"
      @success="handleFeedbackToTaskSuccess"
    />
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import FeedbackToTaskModal from '../components/FeedbackToTaskModal.vue';
import QualityTrendChart from '../components/QualityTrendChart.vue';
import BugDistributionChart from '../components/BugDistributionChart.vue';
import FeedbackDistributionChart from '../components/FeedbackDistributionChart.vue';
import DashboardSkeleton from '../components/DashboardSkeleton.vue';
import type { AIQualityInsight } from '@/types/quality-center';

const router = useRouter();
const store = useQualityCenterStore();

// ========== 状态 ==========
const isInitialLoading = ref(true);
const trendPeriod = ref<'week' | 'month' | 'quarter'>('week');
const activityFilter = ref<string | undefined>(undefined);
const showFeedbackToTaskModal = ref(false);

// ========== 计算属性 ==========
const passRateColor = computed(() => {
  const rate = store.overview?.pass_rate ?? 0;
  if (rate >= 90) return '#00B42A';
  if (rate >= 70) return '#FF7D00';
  return '#F53F3F';
});

// 模块质量表格列
const moduleColumns = [
  { title: '模块', dataIndex: 'module_name', width: 100 },
  { title: '通过率', slotName: 'pass_rate', width: 160 },
  { title: 'Bug数', slotName: 'bug_count', width: 70 },
  { title: '用例数', dataIndex: 'case_count', width: 70 },
  { title: '反馈数', dataIndex: 'feedback_count', width: 70 },
];

// 关联记录表格列
const linkColumns = [
  { title: '来源', slotName: 'source', width: 160 },
  { title: '目标', slotName: 'target', width: 160 },
  { title: '时间', slotName: 'created_at', width: 100 },
];

// ========== 方法 ==========

/** 洞察严重程度颜色 */
function insightSeverityColor(severity: string): string {
  const map: Record<string, string> = { high: 'red', medium: 'orange', low: 'green' };
  return map[severity] || 'blue';
}

/** 洞察严重程度文本 */
function insightSeverityText(severity: string): string {
  const map: Record<string, string> = { high: '高风险', medium: '中等', low: '低' };
  return map[severity] || severity;
}

/** 洞察类型颜色 */
function insightTypeColor(type: string): string {
  const map: Record<string, string> = { risk: 'red', suggestion: 'blue', anomaly: 'orange', trend: 'green' };
  return map[type] || 'gray';
}

/** 洞察类型文本 */
function insightTypeText(type: string): string {
  const map: Record<string, string> = { risk: '风险', suggestion: '建议', anomaly: '异常', trend: '趋势' };
  return map[type] || type;
}

/** 活动类型颜色 */
function activityColor(type: string): string {
  const map: Record<string, string> = {
    test_pass: '#00B42A', test_fail: '#F53F3F', bug_found: '#FF7D00',
    bug_fixed: '#00B42A', feedback_created: '#165DFF', feedback_resolved: '#0FC6C2',
    ai_analysis: '#722ED1', ai_fix: '#722ED1',
  };
  return map[type] || '#86909C';
}

/** 关联类型颜色 */
function linkTypeColor(type: string): string {
  const map: Record<string, string> = {
    feedback: 'blue', bug: 'red', task: 'green', case: 'purple',
  };
  return map[type] || 'gray';
}

/** 关联类型文本 */
function linkTypeText(type: string): string {
  const map: Record<string, string> = {
    feedback: '反馈', bug: 'Bug', task: '任务', case: '用例',
  };
  return map[type] || type;
}

/** 文本截断 */
function truncate(text: string, maxLen: number): string {
  return text.length > maxLen ? `${text.slice(0, maxLen)}...` : text;
}

/** 趋势周期切换 */
function handleTrendPeriodChange(val: string | number | boolean) {
  store.fetchTrend(val as 'week' | 'month' | 'quarter');
}

/** 趋势图日期点击 - 数据钻取 */
function handleTrendDateClick(date: string) {
  console.log('[质量中心][趋势图点击]', date);
  Message.info(`查看 ${date} 的详细数据`);
  // 可以跳转到详细页面或打开弹窗展示该日期的详细数据
  router.push(`/auto-test/execution?date=${date}`);
}

/** Bug类型点击 - 跳转到Bug列表并筛选 */
function handleBugTypeClick(type: string) {
  console.log('[质量中心][Bug类型点击]', type);
  Message.info(`查看${type}类型的Bug列表`);
  router.push(`/auto-test/bug?type=${type}`);
}

/** 反馈状态点击 - 跳转到反馈列表并筛选 */
function handleFeedbackStatusClick(status: number) {
  console.log('[质量中心][反馈状态点击]', status);
  const statusMap: Record<number, string> = {
    0: '待处理', 1: '处理中', 2: '已解决', 3: '已关闭', 4: '已拒绝',
  };
  Message.info(`查看${statusMap[status]}的反馈列表`);
  router.push(`/feedback/list?status=${status}`);
}

/** 活动筛选 */
function handleActivityFilter(val: string | number | boolean | Record<string, unknown> | (string | number | boolean | Record<string, unknown>)[]) {
  store.fetchActivities({ limit: 10, type: val as string });
}

/** 洞察操作 */
function handleInsightAction(insight: AIQualityInsight) {
  if (insight.action_url) {
    router.push(insight.action_url);
  }
}

/** 反馈转任务成功回调 */
function handleFeedbackToTaskSuccess() {
  Message.success('反馈已成功转为测试任务');
  store.fetchLinkRecords();
  store.fetchOverview();
  store.fetchActivities({ limit: 10 });
}

// ========== 生命周期 ==========
onMounted(async () => {
  try {
    await store.fetchDashboardAll();
  } catch (error) {
    console.error('[质量中心][Dashboard加载失败]', error);
    Message.error('Dashboard数据加载失败，请刷新重试');
  } finally {
    // 延迟隐藏骨架屏，确保平滑过渡
    setTimeout(() => {
      isInitialLoading.value = false;
    }, 300);
  }
});
</script>

<style lang="less" scoped>
.quality-dashboard {
  padding: 16px;
  background: var(--color-bg-1);
  min-height: 100%;
}

.stat-cards {
  .stat-card {
    border-radius: 8px;
    transition: box-shadow 0.3s;
    &:hover {
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    }
    :deep(.arco-card-body) {
      padding: 16px;
    }
    :deep(.arco-statistic-title) {
      font-size: 12px;
      color: var(--color-text-3);
    }
    :deep(.arco-statistic-value) {
      font-size: 24px;
    }
  }
}

// 洞察卡片
.insight-card {
  height: 420px;
  :deep(.arco-card-body) {
    overflow-y: auto;
    max-height: 360px;
  }
}

.insight-list {
  .insight-item {
    padding: 12px;
    margin-bottom: 8px;
    border-radius: 6px;
    border-left: 3px solid transparent;
    background: var(--color-fill-1);
    transition: all 0.2s;

    &:hover {
      background: var(--color-fill-2);
    }

    &.insight-high {
      border-left-color: #F53F3F;
    }
    &.insight-medium {
      border-left-color: #FF7D00;
    }
    &.insight-low {
      border-left-color: #00B42A;
    }

    .insight-header {
      display: flex;
      align-items: center;
      gap: 6px;
      margin-bottom: 6px;
      .insight-module {
        font-size: 11px;
        color: var(--color-text-3);
        margin-left: auto;
      }
    }

    .insight-title {
      font-size: 14px;
      font-weight: 500;
      color: var(--color-text-1);
      margin-bottom: 4px;
    }

    .insight-desc {
      font-size: 12px;
      color: var(--color-text-2);
      line-height: 1.5;
    }

    .insight-action {
      margin-top: 8px;
      text-align: right;
    }
  }
}

// 趋势卡片
.trend-card {
  height: 420px;
  .trend-chart-container {
    height: 320px;
  }
  .trend-table-wrapper {
    height: 300px;
    overflow: hidden;
  }
}

// 分布列表
.distribution-list {
  .distribution-item {
    margin-bottom: 14px;
    &:last-child {
      margin-bottom: 0;
    }
    .distribution-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 4px;
      .distribution-label {
        font-size: 13px;
        color: var(--color-text-1);
      }
      .distribution-value {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }
  }
}

// 活动时间线
.activity-timeline {
  max-height: 500px;
  overflow-y: auto;
  padding-right: 8px;

  .activity-item {
    .activity-header {
      display: flex;
      align-items: center;
      gap: 8px;
      margin-bottom: 4px;
      .activity-module {
        font-size: 11px;
        color: var(--color-text-3);
        background: var(--color-fill-2);
        padding: 1px 6px;
        border-radius: 3px;
      }
      .activity-time {
        font-size: 11px;
        color: var(--color-text-4);
        margin-left: auto;
      }
    }
    .activity-desc {
      font-size: 13px;
      color: var(--color-text-2);
      margin-bottom: 4px;
    }
    .activity-user {
      display: flex;
      align-items: center;
      font-size: 12px;
      color: var(--color-text-3);
    }
  }
}

// 关联记录
.link-title {
  font-size: 12px;
  color: var(--color-text-1);
  cursor: pointer;
  &:hover {
    color: rgb(var(--primary-6));
  }
}

.link-time {
  font-size: 11px;
  color: var(--color-text-3);
}

.empty-state {
  display: flex;
  align-items: center;
  justify-content: center;
  min-height: 120px;
}
</style>
