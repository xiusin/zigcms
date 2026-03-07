<template>
  <div class="security-reports-container">
    <a-card :bordered="false">
      <!-- 页面标题 -->
      <template #title>
        <div class="page-header">
          <a-space>
            <icon-file-text :size="24" />
            <span class="page-title">安全报告</span>
          </a-space>
        </div>
      </template>

      <!-- 操作栏 -->
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showGeneratorDialog">
            <template #icon>
              <icon-plus />
            </template>
            生成报告
          </a-button>
        </a-space>
      </template>

      <!-- 快捷报告 -->
      <div class="quick-reports">
        <a-row :gutter="16">
          <a-col :span="8">
            <a-card class="quick-report-card" hoverable @click="generateDaily">
              <template #cover>
                <div class="report-icon">
                  <icon-calendar :size="48" />
                </div>
              </template>
              <a-card-meta title="日报" description="生成今日安全报告" />
            </a-card>
          </a-col>

          <a-col :span="8">
            <a-card class="quick-report-card" hoverable @click="generateWeekly">
              <template #cover>
                <div class="report-icon">
                  <icon-calendar-clock :size="48" />
                </div>
              </template>
              <a-card-meta title="周报" description="生成本周安全报告" />
            </a-card>
          </a-col>

          <a-col :span="8">
            <a-card class="quick-report-card" hoverable @click="generateMonthly">
              <template #cover>
                <div class="report-icon">
                  <icon-calendar-range :size="48" />
                </div>
              </template>
              <a-card-meta title="月报" description="生成本月安全报告" />
            </a-card>
          </a-col>
        </a-row>
      </div>

      <!-- 报告预览 -->
      <div v-if="currentReport" class="report-preview">
        <a-divider>报告预览</a-divider>
        <ReportPreview :report="currentReport" @export="handleExport" />
      </div>

      <!-- 空状态 -->
      <a-empty v-else description="点击上方按钮生成报告" />
    </a-card>

    <!-- 报告生成器对话框 -->
    <ReportGenerator
      v-model:visible="generatorVisible"
      @generate="handleGenerate"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconFileText,
  IconPlus,
  IconCalendar,
  IconCalendarClock,
  IconCalendarRange,
} from '@arco-design/web-vue/es/icon';
import dayjs from 'dayjs';
import {
  generateDailyReport,
  generateWeeklyReport,
  generateMonthlyReport,
  generateCustomReport,
  exportHTMLReport,
  downloadReport,
} from '@/api/security-report';
import type { ReportData, GenerateReportRequest } from '@/types/security-report';
import ReportGenerator from './components/ReportGenerator.vue';
import ReportPreview from './components/ReportPreview.vue';

// 当前报告
const currentReport = ref<ReportData | null>(null);

// 报告生成器对话框
const generatorVisible = ref(false);

// 显示生成器对话框
const showGeneratorDialog = () => {
  generatorVisible.value = true;
};

// 生成日报
const generateDaily = async () => {
  try {
    const date = dayjs().format('YYYY-MM-DD');
    const { data } = await generateDailyReport(date);
    currentReport.value = data;
    Message.success('日报生成成功');
  } catch (error) {
    Message.error('日报生成失败');
    console.error(error);
  }
};

// 生成周报
const generateWeekly = async () => {
  try {
    const startDate = dayjs().startOf('week').format('YYYY-MM-DD');
    const endDate = dayjs().endOf('week').format('YYYY-MM-DD');
    const { data } = await generateWeeklyReport(startDate, endDate);
    currentReport.value = data;
    Message.success('周报生成成功');
  } catch (error) {
    Message.error('周报生成失败');
    console.error(error);
  }
};

// 生成月报
const generateMonthly = async () => {
  try {
    const month = dayjs().format('YYYY-MM');
    const { data } = await generateMonthlyReport(month);
    currentReport.value = data;
    Message.success('月报生成成功');
  } catch (error) {
    Message.error('月报生成失败');
    console.error(error);
  }
};

// 处理生成报告
const handleGenerate = async (params: GenerateReportRequest) => {
  try {
    const { data } = await generateCustomReport(params);
    currentReport.value = data;
    generatorVisible.value = false;
    Message.success('报告生成成功');
  } catch (error) {
    Message.error('报告生成失败');
    console.error(error);
  }
};

// 处理导出
const handleExport = async (format: string) => {
  if (!currentReport.value) {
    Message.warning('请先生成报告');
    return;
  }

  try {
    if (format === 'html') {
      const blob = await exportHTMLReport({
        start_date: currentReport.value.period.split(' 至 ')[0] || currentReport.value.period,
        end_date: currentReport.value.period.split(' 至 ')[1] || currentReport.value.period,
        format: 'html',
      });
      downloadReport(blob, `security_report_${dayjs().format('YYYYMMDD')}.html`);
      Message.success('报告导出成功');
    } else {
      Message.info(`${format.toUpperCase()} 导出功能开发中`);
    }
  } catch (error) {
    Message.error('报告导出失败');
    console.error(error);
  }
};
</script>

<style scoped lang="scss">
.security-reports-container {
  padding: 20px;

  .page-header {
    display: flex;
    align-items: center;

    .page-title {
      font-size: 18px;
      font-weight: 600;
    }
  }

  .quick-reports {
    margin-bottom: 24px;

    .quick-report-card {
      text-align: center;
      cursor: pointer;
      transition: all 0.3s;

      &:hover {
        transform: translateY(-4px);
        box-shadow: 0 4px 12px rgba(0, 0, 0, 0.1);
      }

      .report-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        height: 120px;
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        color: white;
      }
    }
  }

  .report-preview {
    margin-top: 24px;
  }
}
</style>
