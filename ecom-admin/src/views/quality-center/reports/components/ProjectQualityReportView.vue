<template>
  <div class="project-quality-report-view">
    <!-- 质量指标卡片 -->
    <a-row :gutter="16" class="quality-cards">
      <a-col :span="6">
        <a-card>
          <a-statistic title="测试覆盖率" :value="data.test_coverage" suffix="%" :precision="1">
            <template #prefix><icon-check-circle /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card>
          <a-statistic title="缺陷密度" :value="data.defect_density" suffix="/KLOC" :precision="2">
            <template #prefix><icon-bug /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card>
          <a-statistic title="质量分数" :value="data.quality_score" :precision="1">
            <template #prefix><icon-trophy /></template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card>
          <a-statistic title="项目进度" :value="data.progress" suffix="%" :precision="1">
            <template #prefix><icon-clock-circle /></template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <!-- 风险评估 -->
    <a-row :gutter="16" class="risk-area">
      <a-col :span="24">
        <a-card title="风险评估" :bordered="false">
          <a-alert
            :type="getRiskAlertType(data.risk_level)"
            :message="`当前风险等级: ${getRiskLevelText(data.risk_level)}`"
            show-icon
            style="margin-bottom: 16px"
          />
          <a-table
            :columns="riskColumns"
            :data="data.risk_factors"
            :pagination="false"
          >
            <template #level="{ record }">
              <a-tag :color="getRiskLevelColor(record.level)">
                {{ getRiskLevelText(record.level) }}
              </a-tag>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>

    <!-- 各维度统计 -->
    <a-row :gutter="16" class="dimension-area">
      <a-col :span="8">
        <a-card title="测试用例" :bordered="false">
          <a-descriptions :column="1">
            <a-descriptions-item label="总数">{{ data.test_case_stats.total }}</a-descriptions-item>
            <a-descriptions-item label="通过">{{ data.test_case_stats.passed }}</a-descriptions-item>
            <a-descriptions-item label="失败">{{ data.test_case_stats.failed }}</a-descriptions-item>
            <a-descriptions-item label="通过率">{{ data.test_case_stats.pass_rate }}%</a-descriptions-item>
          </a-descriptions>
        </a-card>
      </a-col>
      <a-col :span="8">
        <a-card title="反馈" :bordered="false">
          <a-descriptions :column="1">
            <a-descriptions-item label="总数">{{ data.feedback_stats.total }}</a-descriptions-item>
            <a-descriptions-item label="待处理">{{ data.feedback_stats.open }}</a-descriptions-item>
            <a-descriptions-item label="已解决">{{ data.feedback_stats.resolved }}</a-descriptions-item>
            <a-descriptions-item label="解决率">{{ data.feedback_stats.resolution_rate }}%</a-descriptions-item>
          </a-descriptions>
        </a-card>
      </a-col>
      <a-col :span="8">
        <a-card title="需求" :bordered="false">
          <a-descriptions :column="1">
            <a-descriptions-item label="总数">{{ data.requirement_stats.total }}</a-descriptions-item>
            <a-descriptions-item label="开发中">{{ data.requirement_stats.in_development }}</a-descriptions-item>
            <a-descriptions-item label="已完成">{{ data.requirement_stats.completed }}</a-descriptions-item>
            <a-descriptions-item label="完成率">{{ data.requirement_stats.completion_rate }}%</a-descriptions-item>
          </a-descriptions>
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
import {
  IconCheckCircle,
  IconBug,
  IconTrophy,
  IconClockCircle,
  IconDownload,
} from '@arco-design/web-vue/es/icon';
import type { ProjectQualityStats } from '@/types/quality-report';

defineProps<{
  data: ProjectQualityStats;
}>();

defineEmits<{
  export: [format: string];
}>();

const riskColumns = [
  { title: '风险因素', dataIndex: 'factor' },
  { title: '风险等级', slotName: 'level', width: 120 },
  { title: '描述', dataIndex: 'description' },
];

const getRiskAlertType = (level: string) => {
  const types: Record<string, string> = {
    low: 'success',
    medium: 'warning',
    high: 'error',
  };
  return types[level] || 'info';
};

const getRiskLevelColor = (level: string) => {
  const colors: Record<string, string> = {
    low: 'green',
    medium: 'orange',
    high: 'red',
  };
  return colors[level] || 'default';
};

const getRiskLevelText = (level: string) => {
  const texts: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
  };
  return texts[level] || level;
};
</script>

<style scoped lang="scss">
.project-quality-report-view {
  .quality-cards,
  .risk-area,
  .dimension-area {
    margin-bottom: 24px;
  }

  .export-actions {
    margin-top: 24px;
    text-align: right;
  }
}
</style>
