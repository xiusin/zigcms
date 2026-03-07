<template>
  <div class="quality-reports-container">
    <a-card :bordered="false">
      <!-- 页面标题 -->
      <template #title>
        <div class="page-header">
          <a-space>
            <icon-file-text :size="24" />
            <span class="page-title">质量报表</span>
          </a-space>
        </div>
      </template>

      <!-- 操作栏 -->
      <template #extra>
        <a-space>
          <a-range-picker
            v-model="dateRange"
            style="width: 300px"
            @change="handleDateChange"
          />
          <a-select
            v-model="selectedProject"
            placeholder="选择项目"
            style="width: 200px"
            allow-clear
            @change="handleProjectChange"
          >
            <a-option
              v-for="project in projects"
              :key="project.id"
              :value="project.id"
            >
              {{ project.name }}
            </a-option>
          </a-select>
        </a-space>
      </template>

      <!-- 快捷报表 -->
      <div class="quick-reports">
        <a-row :gutter="16">
          <a-col :span="6">
            <a-card
              class="quick-report-card"
              hoverable
              @click="showReport('test_case')"
            >
              <template #cover>
                <div class="report-icon test-case">
                  <icon-check-circle :size="48" />
                </div>
              </template>
              <a-card-meta
                title="测试用例报表"
                description="查看测试用例统计和执行情况"
              />
            </a-card>
          </a-col>

          <a-col :span="6">
            <a-card
              class="quick-report-card"
              hoverable
              @click="showReport('feedback')"
            >
              <template #cover>
                <div class="report-icon feedback">
                  <icon-message :size="48" />
                </div>
              </template>
              <a-card-meta
                title="反馈报表"
                description="查看反馈统计和处理情况"
              />
            </a-card>
          </a-col>

          <a-col :span="6">
            <a-card
              class="quick-report-card"
              hoverable
              @click="showReport('requirement')"
            >
              <template #cover>
                <div class="report-icon requirement">
                  <icon-file :size="48" />
                </div>
              </template>
              <a-card-meta
                title="需求报表"
                description="查看需求统计和完成情况"
              />
            </a-card>
          </a-col>

          <a-col :span="6">
            <a-card
              class="quick-report-card"
              hoverable
              @click="showReport('project_quality')"
            >
              <template #cover>
                <div class="report-icon quality">
                  <icon-trophy :size="48" />
                </div>
              </template>
              <a-card-meta
                title="项目质量报表"
                description="查看项目整体质量情况"
              />
            </a-card>
          </a-col>
        </a-row>
      </div>

      <!-- 报表内容 -->
      <div v-if="currentReportType" class="report-content">
        <a-divider>{{ reportTitle }}</a-divider>

        <!-- 加载中 -->
        <a-spin v-if="loading" :loading="loading" tip="正在生成报表...">
          <div style="height: 400px"></div>
        </a-spin>

        <!-- 测试用例报表 -->
        <TestCaseReportView
          v-else-if="currentReportType === 'test_case' && testCaseData"
          :data="testCaseData"
          @export="handleExport"
        />

        <!-- 反馈报表 -->
        <FeedbackReportView
          v-else-if="currentReportType === 'feedback' && feedbackData"
          :data="feedbackData"
          @export="handleExport"
        />

        <!-- 需求报表 -->
        <RequirementReportView
          v-else-if="currentReportType === 'requirement' && requirementData"
          :data="requirementData"
          @export="handleExport"
        />

        <!-- 项目质量报表 -->
        <ProjectQualityReportView
          v-else-if="currentReportType === 'project_quality' && projectQualityData"
          :data="projectQualityData"
          @export="handleExport"
        />
      </div>

      <!-- 空状态 -->
      <a-empty v-else description="点击上方卡片生成报表" />
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconFileText,
  IconCheckCircle,
  IconMessage,
  IconFile,
  IconTrophy,
} from '@arco-design/web-vue/es/icon';
import dayjs from 'dayjs';
import {
  generateTestCaseReport,
  generateFeedbackReport,
  generateRequirementReport,
  generateProjectQualityReport,
  exportReportHTML,
  downloadReport,
} from '@/api/quality-center';
import type {
  TestCaseStats,
  FeedbackStats,
  RequirementStats,
  ProjectQualityStats,
} from '@/types/quality-report';
import TestCaseReportView from './components/TestCaseReportView.vue';
import FeedbackReportView from './components/FeedbackReportView.vue';
import RequirementReportView from './components/RequirementReportView.vue';
import ProjectQualityReportView from './components/ProjectQualityReportView.vue';

// 日期范围
const dateRange = ref<[string, string]>([
  dayjs().subtract(7, 'day').format('YYYY-MM-DD'),
  dayjs().format('YYYY-MM-DD'),
]);

// 选中的项目
const selectedProject = ref<number | undefined>();

// 项目列表
const projects = ref([
  { id: 1, name: '电商系统' },
  { id: 2, name: '管理后台' },
  { id: 3, name: '移动端APP' },
]);

// 当前报表类型
const currentReportType = ref<string>('');

// 加载状态
const loading = ref(false);

// 报表数据
const testCaseData = ref<TestCaseStats | null>(null);
const feedbackData = ref<FeedbackStats | null>(null);
const requirementData = ref<RequirementStats | null>(null);
const projectQualityData = ref<ProjectQualityStats | null>(null);

// 报表标题
const reportTitle = computed(() => {
  const titles: Record<string, string> = {
    test_case: '测试用例报表',
    feedback: '反馈报表',
    requirement: '需求报表',
    project_quality: '项目质量报表',
  };
  return titles[currentReportType.value] || '';
});

// 处理日期变更
const handleDateChange = () => {
  if (currentReportType.value) {
    showReport(currentReportType.value);
  }
};

// 处理项目变更
const handleProjectChange = () => {
  if (currentReportType.value) {
    showReport(currentReportType.value);
  }
};

// 显示报表
const showReport = async (type: string) => {
  currentReportType.value = type;
  loading.value = true;

  try {
    const params = {
      start_date: dateRange.value[0],
      end_date: dateRange.value[1],
      project_id: selectedProject.value,
    };

    switch (type) {
      case 'test_case':
        const testCaseResult = await generateTestCaseReport(params);
        testCaseData.value = testCaseResult.data;
        break;

      case 'feedback':
        const feedbackResult = await generateFeedbackReport(params);
        feedbackData.value = feedbackResult.data;
        break;

      case 'requirement':
        const requirementResult = await generateRequirementReport(params);
        requirementData.value = requirementResult.data;
        break;

      case 'project_quality':
        const qualityResult = await generateProjectQualityReport(params);
        projectQualityData.value = qualityResult.data;
        break;
    }

    Message.success('报表生成成功');
  } catch (error) {
    Message.error('报表生成失败');
    console.error(error);
  } finally {
    loading.value = false;
  }
};

// 处理导出
const handleExport = async (format: string) => {
  if (!currentReportType.value) {
    Message.warning('请先生成报表');
    return;
  }

  try {
    if (format === 'html') {
      const blob = await exportReportHTML({
        report_type: currentReportType.value,
        start_date: dateRange.value[0],
        end_date: dateRange.value[1],
        project_id: selectedProject.value,
      });
      downloadReport(
        blob,
        `${reportTitle.value}_${dayjs().format('YYYYMMDD')}.html`
      );
      Message.success('报表导出成功');
    } else {
      Message.info(`${format.toUpperCase()} 导出功能开发中`);
    }
  } catch (error) {
    Message.error('报表导出失败');
    console.error(error);
  }
};
</script>

<style scoped lang="scss">
.quality-reports-container {
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
        color: white;

        &.test-case {
          background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }

        &.feedback {
          background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
        }

        &.requirement {
          background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
        }

        &.quality {
          background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
        }
      }
    }
  }

  .report-content {
    margin-top: 24px;
  }
}
</style>
