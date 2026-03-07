<template>
  <div class="feedback-detail-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-breadcrumb>
        <a-breadcrumb-item>质量中心</a-breadcrumb-item>
        <a-breadcrumb-item>
          <a-link @click="router.back()">反馈管理</a-link>
        </a-breadcrumb-item>
        <a-breadcrumb-item>反馈详情</a-breadcrumb-item>
      </a-breadcrumb>
      <div class="header-actions">
        <a-space>
          <a-button @click="handleEdit">
            <template #icon><icon-edit /></template>
            编辑
          </a-button>
          <a-button status="danger" @click="handleDelete">
            <template #icon><icon-delete /></template>
            删除
          </a-button>
        </a-space>
      </div>
    </div>

    <!-- 骨架屏 -->
    <DetailSkeleton v-if="isInitialLoad" :rows="8" :show-title="true" :show-actions="true" />
    
    <!-- 实际内容 -->
    <a-spin v-else :loading="dataLoading" style="width: 100%">
      <a-row :gutter="16">
        <!-- 左侧：基本信息和 AI 分析 -->
        <a-col :span="16">
          <!-- 基本信息 -->
          <a-card title="基本信息" :bordered="false" class="info-card">
            <a-descriptions :column="2" bordered>
              <a-descriptions-item label="反馈标题">
                <span class="feedback-title">{{ feedback?.title }}</span>
              </a-descriptions-item>

              <a-descriptions-item label="反馈类型">
                <a-tag :color="getTypeColor(feedback?.type)">
                  {{ getTypeText(feedback?.type) }}
                </a-tag>
              </a-descriptions-item>

              <a-descriptions-item label="严重程度">
                <a-tag :color="getSeverityColor(feedback?.severity)">
                  {{ getSeverityText(feedback?.severity) }}
                </a-tag>
              </a-descriptions-item>

              <a-descriptions-item label="状态">
                <a-tag :color="getStatusColor(feedback?.status)">
                  {{ getStatusText(feedback?.status) }}
                </a-tag>
              </a-descriptions-item>

              <a-descriptions-item label="负责人">
                <span v-if="feedback?.assignee">{{ feedback.assignee }}</span>
                <span v-else class="text-placeholder">未指派</span>
              </a-descriptions-item>

              <a-descriptions-item label="提交人">
                {{ feedback?.submitter }}
              </a-descriptions-item>

              <a-descriptions-item label="提交时间">
                {{ formatDateTime(feedback?.created_at) }}
              </a-descriptions-item>

              <a-descriptions-item label="更新时间">
                {{ formatDateTime(feedback?.updated_at) }}
              </a-descriptions-item>

              <a-descriptions-item label="反馈内容" :span="2">
                <div class="feedback-content">{{ feedback?.content }}</div>
              </a-descriptions-item>
            </a-descriptions>
          </a-card>

          <!-- AI 分析结果 -->
          <a-card
            v-if="aiAnalysis"
            title="AI 分析结果"
            :bordered="false"
            class="analysis-card"
          >
            <a-descriptions :column="1" bordered>
              <a-descriptions-item label="Bug 类型">
                <a-tag color="blue">{{ aiAnalysis.bug_type }}</a-tag>
              </a-descriptions-item>

              <a-descriptions-item label="严重程度">
                <a-tag :color="getSeverityColor(aiAnalysis.severity)">
                  {{ getSeverityText(aiAnalysis.severity) }}
                </a-tag>
              </a-descriptions-item>

              <a-descriptions-item label="影响范围">
                <a-space wrap>
                  <a-tag
                    v-for="module in aiAnalysis.affected_modules"
                    :key="module"
                    color="orange"
                  >
                    {{ module }}
                  </a-tag>
                </a-space>
              </a-descriptions-item>

              <a-descriptions-item label="建议操作">
                <ul class="suggestion-list">
                  <li
                    v-for="(action, index) in aiAnalysis.suggested_actions"
                    :key="index"
                  >
                    {{ action }}
                  </li>
                </ul>
              </a-descriptions-item>
            </a-descriptions>
          </a-card>
          
          <!-- 评论讨论 -->
          <a-card title="评论讨论" :bordered="false" class="comment-card">
            <CommentSection
              :comments="comments"
              :current-user="currentUser"
              @add="handleAddComment"
              @reply="handleReplyComment"
              @edit="handleEditComment"
              @delete="handleDeleteComment"
            />
          </a-card>
        </a-col>

        <!-- 右侧：跟进时间线和流转图 -->
        <a-col :span="8">
          <!-- 反馈流转图 -->
          <a-card title="流转流程" :bordered="false" class="flow-card">
            <template #extra>
              <a-button
                type="text"
                size="small"
                @click="handleOpenFlowConfig"
              >
                <template #icon><icon-settings /></template>
                配置
              </a-button>
            </template>
            
            <FeedbackFlowChart
              ref="flowChartRef"
              :current-status="feedback?.status"
              @status-change="handleStatusChange"
              @config-change="handleFlowConfigChange"
            />
          </a-card>
          
          <!-- 跟进记录 -->
          <a-card title="跟进记录" :bordered="false" class="timeline-card">
            <template #extra>
              <a-button type="primary" size="small" @click="handleAddFollowUp">
                <template #icon><icon-plus /></template>
                添加跟进
              </a-button>
            </template>

            <FollowUpTimeline
              v-if="feedback?.follow_ups"
              :follow-ups="feedback.follow_ups"
            />
            <a-empty v-else description="暂无跟进记录" />
          </a-card>
        </a-col>
      </a-row>
    </a-spin>

    <!-- 添加跟进记录对话框 -->
    <a-modal
      v-model:visible="followUpVisible"
      title="添加跟进记录"
      width="800px"
      @ok="handleFollowUpConfirm"
      @cancel="followUpVisible = false"
    >
      <a-form :model="followUpForm" layout="vertical">
        <a-form-item label="跟进内容" required>
          <RichTextEditor
            v-model="followUpForm.content"
            placeholder="请输入跟进内容..."
            height="300px"
          />
        </a-form-item>

        <a-form-item label="附件">
          <AttachmentUpload
            v-model="followUpForm.attachments"
            :limit="5"
            :max-size="10"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { Message, Modal } from '@arco-design/web-vue';
import FollowUpTimeline from './components/FollowUpTimeline.vue';
import FeedbackFlowChart from '@/components/feedback/FeedbackFlowChart.vue';
import CommentSection from '@/components/feedback/CommentSection.vue';
import RichTextEditor from '@/components/editor/RichTextEditor.vue';
import AttachmentUpload from '@/components/upload/AttachmentUpload.vue';
import { DetailSkeleton } from '@/components/skeleton';
import type { FileItem } from '@arco-design/web-vue';
import {
  getFeedbackById,
  deleteFeedback,
  addFeedbackFollowUp,
  updateFeedbackStatus,
  addFeedbackComment,
  replyFeedbackComment,
  editFeedbackComment,
  deleteFeedbackComment,
} from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import type { Feedback, FeedbackAnalysis } from '@/types/quality-center';
import { formatDateTime } from '@/utils/date';

const router = useRouter();
const route = useRoute();

const feedbackId = Number(route.params.id);
const currentUser = '当前用户'; // TODO: 从用户信息获取

// 反馈详情
const feedback = ref<Feedback>();
const aiAnalysis = ref<FeedbackAnalysis>();
const dataLoading = ref(false);
const isInitialLoad = ref(true);

// 评论列表
const comments = ref<any[]>([]);

// 流转图引用
const flowChartRef = ref();

// 添加跟进记录
const followUpVisible = ref(false);
const followUpForm = reactive({
  content: '',
  attachments: [] as FileItem[],
});

// 加载反馈详情
const loadFeedback = async () => {
  dataLoading.value = true;
  try {
    const data = await getFeedbackById(feedbackId);
    feedback.value = data;
    
    // 如果有 AI 分析结果，解析它
    if (data.ai_analysis) {
      aiAnalysis.value = JSON.parse(data.ai_analysis);
    }
    
    // 加载评论列表（模拟数据）
    comments.value = [
      {
        id: 1,
        author: '张三',
        content: '这个问题我也遇到过，建议优先处理',
        created_at: Date.now() - 3600000,
        replies: [
          {
            id: 2,
            author: '李四',
            reply_to: '张三',
            content: '同意，已经影响到多个用户了',
            created_at: Date.now() - 1800000,
          },
        ],
      },
    ];
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载反馈详情失败');
  } finally {
    dataLoading.value = false;
  }
};

// 编辑
const handleEdit = () => {
  router.push(`/quality-center/feedback/${feedbackId}/edit`);
};

// 删除
const handleDelete = async () => {
  const confirmed = await showDeleteConfirm(
    `确定要删除反馈"${feedback.value?.title}"吗？此操作不可恢复。`,
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => deleteFeedback(feedbackId),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  router.back();
};

// 添加跟进记录
const handleAddFollowUp = () => {
  followUpForm.content = '';
  followUpForm.attachments = [];
  followUpVisible.value = true;
};

const handleFollowUpConfirm = async () => {
  if (!followUpForm.content.trim()) {
    showError('请输入跟进内容');
    return;
  }

  await withFeedback(
    () => addFeedbackFollowUp(feedbackId, {
      content: followUpForm.content,
      follower: '当前用户', // TODO: 从用户信息获取
      attachments: followUpForm.attachments.map((file) => ({
        name: file.name,
        url: file.url || '',
        size: file.file?.size || 0,
      })),
    }),
    {
      loadingText: '添加中...',
      successText: '添加跟进记录成功',
      errorText: '添加跟进记录失败',
    }
  );
  
  followUpVisible.value = false;
  loadFeedback();
};

// 打开流转配置
const handleOpenFlowConfig = () => {
  flowChartRef.value?.openConfig();
};

// 处理状态变化
const handleStatusChange = async (status: string) => {
  await withFeedback(
    () => updateFeedbackStatus(feedbackId, status),
    {
      loadingText: '更新状态中...',
      successText: '状态已更新',
      errorText: '状态更新失败',
    }
  );
  
  loadFeedback();
};

// 处理流转配置变化
const handleFlowConfigChange = (config: any) => {
  console.log('流转配置已更新:', config);
  // TODO: 保存配置到后端
};

// 添加评论
const handleAddComment = async (comment: { content: string; attachments: any[] }) => {
  await withFeedback(
    () => addFeedbackComment(feedbackId, comment),
    {
      loadingText: '发表中...',
      successText: '评论已发表',
      errorText: '发表失败',
    }
  );
  
  loadFeedback();
};

// 回复评论
const handleReplyComment = async (commentId: number, reply: { content: string; reply_to?: string }) => {
  await withFeedback(
    () => replyFeedbackComment(feedbackId, commentId, reply),
    {
      loadingText: '回复中...',
      successText: '回复已发表',
      errorText: '回复失败',
    }
  );
  
  loadFeedback();
};

// 编辑评论
const handleEditComment = async (commentId: number, content: string) => {
  await withFeedback(
    () => editFeedbackComment(feedbackId, commentId, content),
    {
      loadingText: '更新中...',
      successText: '评论已更新',
      errorText: '更新失败',
    }
  );
  
  loadFeedback();
};

// 删除评论
const handleDeleteComment = async (commentId: number) => {
  const confirmed = await showDeleteConfirm(
    '确定要删除这条评论吗？此操作不可恢复。',
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => deleteFeedbackComment(feedbackId, commentId),
    {
      loadingText: '删除中...',
      successText: '评论已删除',
      errorText: '删除失败',
    }
  );
  
  loadFeedback();
};

// 类型相关
const getTypeText = (type?: string) => {
  if (!type) return '';
  const map: Record<string, string> = {
    bug: 'Bug',
    feature: '功能建议',
    improvement: '改进建议',
    question: '问题咨询',
  };
  return map[type] || type;
};

const getTypeColor = (type?: string) => {
  if (!type) return 'gray';
  const map: Record<string, string> = {
    bug: 'red',
    feature: 'blue',
    improvement: 'orange',
    question: 'purple',
  };
  return map[type] || 'gray';
};

// 严重程度相关
const getSeverityText = (severity?: string) => {
  if (!severity) return '';
  const map: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '紧急',
  };
  return map[severity] || severity;
};

const getSeverityColor = (severity?: string) => {
  if (!severity) return 'gray';
  const map: Record<string, string> = {
    low: 'gray',
    medium: 'blue',
    high: 'orange',
    critical: 'red',
  };
  return map[severity] || 'gray';
};

// 状态相关
const getStatusText = (status?: string) => {
  if (!status) return '';
  const map: Record<string, string> = {
    pending: '待处理',
    in_progress: '处理中',
    resolved: '已解决',
    closed: '已关闭',
    rejected: '已拒绝',
  };
  return map[status] || status;
};

const getStatusColor = (status?: string) => {
  if (!status) return 'gray';
  const map: Record<string, string> = {
    pending: 'gray',
    in_progress: 'blue',
    resolved: 'green',
    closed: 'arcoblue',
    rejected: 'red',
  };
  return map[status] || 'gray';
};

// 注册键盘快捷键
const registerShortcuts = () => {
  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (followUpVisible.value) {
        followUpVisible.value = false;
        return false;
      }
    })
  );
};

onMounted(() => {
  loadFeedback();
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});
</script>

<style scoped lang="less">
.feedback-detail-container {
  padding: 20px;

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
  }

  .info-card,
  .analysis-card,
  .comment-card,
  .flow-card,
  .timeline-card {
    margin-bottom: 16px;
  }

  .feedback-title {
    font-size: 16px;
    font-weight: 600;
    color: var(--color-text-1);
  }

  .feedback-content {
    white-space: pre-wrap;
    line-height: 1.6;
    color: var(--color-text-2);
  }

  .suggestion-list {
    margin: 0;
    padding-left: 20px;

    li {
      margin-bottom: 8px;
      line-height: 1.6;
      color: var(--color-text-2);

      &:last-child {
        margin-bottom: 0;
      }
    }
  }

  .text-placeholder {
    color: var(--color-text-3);
  }
}
</style>
