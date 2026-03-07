<template>
  <div class="requirement-report-view">
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="stats-cards">
      <a-col :span="6">
        <a-statistic title="总需求数" :value="data.total" />
      </a-col>
      <a-col :span="6">
        <a-statistic title="已完成" :value="data.completed" :value-style="{ color: '#52c41a' }" />
      </a-col>
      <a-col :span="6">
        <a-statistic title="完成率" :value="data.completion_rate" suffix="%" :precision="1" />
      </a-col>
      <a-col :span="6">
        <a-statistic title="平均变更次数" :value="data.avg_changes_per_requirement" :precision="2" />
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="16" class="charts-area">
      <a-col :span="12">
        <a-card title="状态分布" :bordered="false">
          <div ref="statusChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>
      <a-col :span="12">
        <a-card title="优先级分布" :bordered="false">
          <div ref="priorityChartRef" style="height: 300px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 完成趋势 -->
    <a-row :gutter="16" class="trend-area">
      <a-col :span="24">
        <a-card title="完成趋势" :bordered="false">
          <div ref="trendChartRef" style="height: 300px"></div>
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
      </a-space>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import * as echarts from 'echarts';
import { IconDownload } from '@arco-design/web-vue/es/icon';
import type { RequirementStats } from '@/types/quality-report';

const props = defineProps<{
  data: RequirementStats;
}>();

defineEmits<{
  export: [format: string];
}>();

const statusChartRef = ref<HTMLElement>();
const priorityChartRef = ref<HTMLElement>();
const trendChartRef = ref<HTMLElement>();

onMounted(() => {
  if (statusChartRef.value) {
    const chart = echarts.init(statusChartRef.value);
    chart.setOption({
      tooltip: { trigger: 'item' },
      series: [{
        type: 'pie',
        radius: '70%',
        data: [
          { value: props.data.draft, name: '草稿' },
          { value: props.data.reviewing, name: '评审中' },
          { value: props.data.approved, name: '已批准' },
          { value: props.data.in_development, name: '开发中' },
          { value: props.data.completed, name: '已完成' },
        ],
      }],
    });
  }

  if (priorityChartRef.value) {
    const chart = echarts.init(priorityChartRef.value);
    chart.setOption({
      tooltip: { trigger: 'item' },
      series: [{
        type: 'pie',
        radius: ['40%', '70%'],
        data: [
          { value: props.data.priority_high, name: '高', itemStyle: { color: '#f5222d' } },
          { value: props.data.priority_medium, name: '中', itemStyle: { color: '#faad14' } },
          { value: props.data.priority_low, name: '低', itemStyle: { color: '#52c41a' } },
        ],
      }],
    });
  }

  if (trendChartRef.value) {
    const chart = echarts.init(trendChartRef.value);
    chart.setOption({
      tooltip: { trigger: 'axis' },
      xAxis: {
        type: 'category',
        data: props.data.completion_trend.map((t) => t.date),
      },
      yAxis: { type: 'value' },
      series: [{
        name: '完成数',
        type: 'line',
        data: props.data.completion_trend.map((t) => t.value),
        smooth: true,
        itemStyle: { color: '#1890ff' },
      }],
    });
  }
});
</script>

<style scoped lang="scss">
.requirement-report-view {
  .stats-cards,
  .charts-area,
  .trend-area {
    margin-bottom: 24px;
  }

  .export-actions {
    margin-top: 24px;
    text-align: right;
  }
}
</style>
