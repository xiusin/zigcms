<template>
  <div class="requirement-detail-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-page-header
        :title="requirement?.title || '需求详情'"
        @back="handleBack"
      >
        <template #extra>
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
        </template>
      </a-page-header>
    </div>

    <!-- 加载状态 -->
    <a-spin :loading="loading" style="width: 100%">
      <div v-if="requirement" class="detail-content">
        <!-- 基本信息 -->
        <a-card title="基本信息" :bordered="false" class="info-card">
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="需求 ID">
              {{ requirement.id }}
            </a-descriptions-item>

            <a-descriptions-item label="所属项目">
              {{ getProjectName(requirement.project_id) }}
            </a-descriptions-item>

            <a-descriptions-item label="状态">
              <a-tag :color="getStatusColor(requirement.status)">
                {{ getStatusText(requirement.status) }}
              </a-tag>
            </a-descriptions-item>

            <a-descriptions-item label="优先级">
              <a-tag :color="getPriorityColor(requirement.priority)">
                {{ getPriorityText(requirement.priority) }}
              </a-tag>
            </a-descriptions-item>

            <a-descriptions-item label="负责人">
              {{ requirement.assignee || '未分配' }}
            </a-descriptions-item>

            <a-descriptions-item label="覆盖率">
              <div class="coverage-info">
                <a-progress
                  :percent="requirement.coverage_rate"
                  :status="getCoverageStatus(requirement.coverage_rate)"
                  size="small"
                  style="width: 200px"
                />
                <span class="coverage-text">
                  {{ requirement.coverage_rate.toFixed(1) }}%
                  ({{ requirement.actual_cases }}/{{ requirement.estimated_cases }})
                </span>
              </div>
            </a-descriptions-item>

            <a-descriptions-item label="创建人">
              {{ requirement.created_by }}
            </a-descriptions-item>

            <a-descriptions-item label="创建时间">
              {{ formatDate(requirement.created_at) }}
            </a-descriptions-item>

            <a-descriptions-item label="需求描述" :span="2">
              <div class="description-content">
                {{ requirement.description }}
              </div>
            </a-descriptions-item>
          </a-descriptions>
        </a-card>

        <!-- 状态流转历史 -->
        <a-card title="状态流转历史" :bordered="false" class="history-card">
          <a-timeline>
            <a-timeline-item
              v-for="(history, index) in statusHistory"
              :key="index"
              :label="formatDate(history.timestamp)"
            >
              <div class="history-item">
                <div class="history-status">
                  <a-tag :color="getStatusColor(history.from_status)">
                    {{ getStatusText(history.from_status) }}
                  </a-tag>
                  <icon-arrow-right />
                  <a-tag :color="getStatusColor(history.to_status)">
                    {{ getStatusText(history.to_status) }}
                  </a-tag>
                </div>
                <div class="history-operator">
                  操作人: {{ history.operator }}
                </div>
              </div>
            </a-timeline-item>
          </a-timeline>

          <a-empty v-if="statusHistory.length === 0" description="暂无状态流转记录" />
        </a-card>

        <!-- 关联测试用例 -->
        <a-card title="关联测试用例" :bordered="false" class="linked-cases-card">
          <LinkedTestCases
            :requirement-id="requirement.id!"
            :test-cases="requirement.test_cases || []"
            @refresh="loadRequirement"
          />
        </a-card>
      </div>
    </a-spin>

    <!-- 编辑需求对话框 -->
    <a-modal
      v-model:visible="editVisible"
      title="编辑需求"
      width="800px"
      @ok="handleEditSubmit"
      @cancel="editVisible = false"
    >
      <a-form
        ref="formRef"
        :model="formData"
        :rules="formRules"
        layout="vertical"
      >
        <a-form-item label="需求标题" field="title" required>
          <a-input
            v-model="formData.title"
            placeholder="请输入需求标题"
            :max-length="200"
            show-word-limit
          />
        </a-form-item>

        <a-form-item label="需求描述" field="description" required>
          <a-textarea
            v-model="formData.description"
            placeholder="请输入需求描述"
            :max-length="2000"
            :auto-size="{ minRows: 4, maxRows: 8 }"
            show-word-limit
          />
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="8">
            <a-form-item label="状态" field="status">
              <a-select v-model="formData.status" placeholder="选择状态">
                <a-option value="pending">待评审</a-option>
                <a-option value="reviewed">已评审</a-option>
                <a-option value="developing">开发中</a-option>
                <a-option value="testing">待测试</a-option>
                <a-option value="in_test">测试中</a-option>
                <a-option value="completed">已完成</a-option>
                <a-option value="closed">已关闭</a-option>
              </a-select>
            </a-form-item>
          </a-col>

          <a-col :span="8">
            <a-form-item label="优先级" field="priority">
              <a-select v-model="formData.priority" placeholder="选择优先级">
                <a-option value="low">低</a-option>
                <a-option value="medium">中</a-option>
                <a-option value="high">高</a-option>
                <a-option value="critical">紧急</a-option>
              </a-select>
            </a-form-item>
          </a-col>

          <a-col :span="8">
            <a-form-item label="负责人" field="assignee">
              <a-input
                v-model="formData.assignee"
                placeholder="请输入负责人"
              />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="建议测试用例数" field="estimated_cases">
          <a-input-number
            v-model="formData.estimated_cases"
            :min="0"
            :max="1000"
            placeholder="请输入建议测试用例数"
            style="width: 100%"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRoute, useRouter } from 'vue-router';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconEdit,
  IconDelete,
  IconArrowRight,
} from '@arco-design/web-vue/es/icon';
import LinkedTestCases from './components/LinkedTestCases.vue';
import qualityCenterApi from '@/api/quality-center';
import type {
  Requirement,
  Project,
  RequirementStatus,
  Priority,
  UpdateRequirementDto,
} from '@/types/quality-center';

// ==================== 路由 ====================

const route = useRoute();
const router = useRouter();
const requirementId = Number(route.params.id);

// ==================== 数据定义 ====================

const loading = ref(false);
const requirement = ref<Requirement>();
const projects = ref<Project[]>([]);

// 状态流转历史（模拟数据，实际应从后端获取）
interface StatusHistory {
  from_status: RequirementStatus;
  to_status: RequirementStatus;
  operator: string;
  timestamp: number;
}

const statusHistory = ref<StatusHistory[]>([]);

// 编辑表单
const editVisible = ref(false);
const formRef = ref();
const formData = reactive<UpdateRequirementDto>({
  title: '',
  description: '',
  status: 'pending',
  priority: 'medium',
  assignee: '',
  estimated_cases: 0,
});

const formRules = {
  title: [
    { required: true, message: '请输入需求标题' },
    { max: 200, message: '标题长度不能超过 200 个字符' },
  ],
  description: [
    { required: true, message: '请输入需求描述' },
    { max: 2000, message: '描述长度不能超过 2000 个字符' },
  ],
};

// ==================== 生命周期 ====================

onMounted(() => {
  loadProjects();
  loadRequirement();
  loadStatusHistory();
});

// ==================== 方法 ====================

/**
 * 加载项目列表
 */
const loadProjects = async () => {
  try {
    const result = await qualityCenterApi.getProjects();
    projects.value = result.items;
  } catch (error) {
    console.error(error);
  }
};

/**
 * 加载需求详情
 */
const loadRequirement = async () => {
  loading.value = true;
  try {
    requirement.value = await qualityCenterApi.getRequirement(requirementId);
  } catch (error) {
    Message.error('加载需求详情失败');
    console.error(error);
  } finally {
    loading.value = false;
  }
};

/**
 * 加载状态流转历史
 */
const loadStatusHistory = async () => {
  // TODO: 从后端获取状态流转历史
  // 这里使用模拟数据
  statusHistory.value = [
    {
      from_status: 'pending',
      to_status: 'reviewed',
      operator: '张三',
      timestamp: Date.now() / 1000 - 86400 * 7,
    },
    {
      from_status: 'reviewed',
      to_status: 'developing',
      operator: '李四',
      timestamp: Date.now() / 1000 - 86400 * 5,
    },
    {
      from_status: 'developing',
      to_status: 'testing',
      operator: '王五',
      timestamp: Date.now() / 1000 - 86400 * 2,
    },
  ];
};

/**
 * 获取项目名称
 */
const getProjectName = (projectId: number): string => {
  const project = projects.value.find(p => p.id === projectId);
  return project?.name || `项目 ${projectId}`;
};

/**
 * 获取状态颜色
 */
const getStatusColor = (status: RequirementStatus): string => {
  const colorMap: Record<RequirementStatus, string> = {
    pending: 'gray',
    reviewed: 'blue',
    developing: 'cyan',
    testing: 'orange',
    in_test: 'orange',
    completed: 'green',
    closed: 'gray',
  };
  return colorMap[status] || 'gray';
};

/**
 * 获取状态文本
 */
const getStatusText = (status: RequirementStatus): string => {
  const textMap: Record<RequirementStatus, string> = {
    pending: '待评审',
    reviewed: '已评审',
    developing: '开发中',
    testing: '待测试',
    in_test: '测试中',
    completed: '已完成',
    closed: '已关闭',
  };
  return textMap[status] || status;
};

/**
 * 获取优先级颜色
 */
const getPriorityColor = (priority: Priority): string => {
  const colorMap: Record<Priority, string> = {
    low: 'gray',
    medium: 'blue',
    high: 'orange',
    critical: 'red',
  };
  return colorMap[priority] || 'gray';
};

/**
 * 获取优先级文本
 */
const getPriorityText = (priority: Priority): string => {
  const textMap: Record<Priority, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '紧急',
  };
  return textMap[priority] || priority;
};

/**
 * 获取覆盖率状态
 */
const getCoverageStatus = (rate: number): 'success' | 'warning' | 'danger' | 'normal' => {
  if (rate >= 80) return 'success';
  if (rate >= 50) return 'warning';
  if (rate > 0) return 'danger';
  return 'normal';
};

/**
 * 格式化日期
 */
const formatDate = (timestamp?: number | null): string => {
  if (!timestamp) return '-';
  
  const date = new Date(timestamp * 1000);
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  
  return `${year}-${month}-${day} ${hours}:${minutes}`;
};

/**
 * 返回
 */
const handleBack = () => {
  router.back();
};

/**
 * 编辑需求
 */
const handleEdit = () => {
  if (!requirement.value) return;
  
  Object.assign(formData, {
    title: requirement.value.title,
    description: requirement.value.description,
    status: requirement.value.status,
    priority: requirement.value.priority,
    assignee: requirement.value.assignee,
    estimated_cases: requirement.value.estimated_cases,
  });
  
  editVisible.value = true;
};

/**
 * 提交编辑
 */
const handleEditSubmit = async () => {
  try {
    await formRef.value?.validate();
    
    await qualityCenterApi.updateRequirement(requirementId, formData);
    Message.success('更新成功');
    
    editVisible.value = false;
    loadRequirement();
    loadStatusHistory();
  } catch (error) {
    if (error) {
      Message.error('更新失败');
      console.error(error);
    }
  }
};

/**
 * 删除需求
 */
const handleDelete = () => {
  Modal.confirm({
    title: '确认删除',
    content: `确定要删除需求"${requirement.value?.title}"吗？此操作不可恢复。`,
    onOk: async () => {
      try {
        await qualityCenterApi.deleteRequirement(requirementId);
        Message.success('删除成功');
        router.push('/quality-center/requirement');
      } catch (error) {
        Message.error('删除失败');
        console.error(error);
      }
    },
  });
};
</script>

<style scoped lang="less">
.requirement-detail-page {
  padding: 20px;
  
  .page-header {
    margin-bottom: 20px;
  }
  
  .detail-content {
    display: flex;
    flex-direction: column;
    gap: 20px;
    
    .info-card,
    .history-card,
    .linked-cases-card {
      // 卡片样式
    }
    
    .description-content {
      white-space: pre-wrap;
      line-height: 1.6;
    }
    
    .coverage-info {
      display: flex;
      align-items: center;
      gap: 12px;
      
      .coverage-text {
        font-size: 14px;
        color: var(--color-text-2);
      }
    }
    
    .history-item {
      .history-status {
        display: flex;
        align-items: center;
        gap: 8px;
        margin-bottom: 4px;
      }
      
      .history-operator {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }
  }
}
</style>
