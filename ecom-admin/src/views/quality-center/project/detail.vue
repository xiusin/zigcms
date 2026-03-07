<template>
  <div class="project-detail-container">
    <!-- 骨架屏 -->
    <DetailSkeleton v-if="isInitialLoad" :rows="8" :show-title="true" :show-actions="true" />
    
    <!-- 实际内容 -->
    <a-spin v-else :loading="dataLoading" style="width: 100%">
      <div v-if="project" class="detail-content">
        <!-- 页面头部 -->
        <div class="page-header">
          <div class="header-left">
            <a-button type="text" @click="handleBack">
              <template #icon>
                <icon-left />
              </template>
              返回
            </a-button>
            <h2 class="page-title">{{ project.name }}</h2>
            <a-tag :color="statusColor">{{ statusText }}</a-tag>
          </div>
          <div class="header-right">
            <a-button @click="handleEdit">
              <template #icon>
                <icon-edit />
              </template>
              编辑
            </a-button>
            <a-button v-if="project.status === 'active'" @click="handleArchive">
              <template #icon>
                <icon-archive />
              </template>
              归档
            </a-button>
            <a-button v-if="project.status === 'archived'" @click="handleRestore">
              <template #icon>
                <icon-undo />
              </template>
              恢复
            </a-button>
            <a-button status="danger" @click="handleDelete">
              <template #icon>
                <icon-delete />
              </template>
              删除
            </a-button>
          </div>
        </div>

        <!-- 项目基本信息 -->
        <a-card title="基本信息" class="info-card">
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="项目名称">
              {{ project.name }}
            </a-descriptions-item>
            <a-descriptions-item label="项目状态">
              <a-tag :color="statusColor">{{ statusText }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="项目负责人">
              {{ project.owner || '未指定' }}
            </a-descriptions-item>
            <a-descriptions-item label="创建人">
              {{ project.created_by }}
            </a-descriptions-item>
            <a-descriptions-item label="创建时间">
              {{ formatDateTime(project.created_at) }}
            </a-descriptions-item>
            <a-descriptions-item label="更新时间">
              {{ formatDateTime(project.updated_at) }}
            </a-descriptions-item>
            <a-descriptions-item label="项目描述" :span="2">
              {{ project.description }}
            </a-descriptions-item>
          </a-descriptions>
        </a-card>

        <!-- 项目统计数据 -->
        <a-card title="统计数据" class="statistics-card">
          <ProjectStatistics :project-id="project.id!" />
        </a-card>

        <!-- 项目成员 -->
        <a-card title="项目成员" class="members-card">
          <div v-if="memberList.length > 0" class="members-list">
            <a-tag
              v-for="(member, index) in memberList"
              :key="index"
              color="arcoblue"
              class="member-tag"
            >
              <template #icon>
                <icon-user />
              </template>
              {{ member }}
            </a-tag>
          </div>
          <a-empty v-else description="暂无成员" />
        </a-card>

        <!-- 项目设置 -->
        <a-card title="项目设置" class="settings-card">
          <a-descriptions :column="1" bordered>
            <a-descriptions-item label="测试环境">
              {{ projectSettings.test_env || '未配置' }}
            </a-descriptions-item>
            <a-descriptions-item label="通知设置">
              {{ projectSettings.notification || '未配置' }}
            </a-descriptions-item>
            <a-descriptions-item label="工作流规则">
              {{ projectSettings.workflow || '未配置' }}
            </a-descriptions-item>
          </a-descriptions>
        </a-card>
      </div>
      <a-empty v-else description="项目不存在" />
    </a-spin>

    <!-- 编辑项目对话框 -->
    <a-modal
      v-model:visible="editModalVisible"
      title="编辑项目"
      :width="600"
      @ok="handleSubmit"
      @cancel="handleCancel"
    >
      <a-form :model="formData" :rules="formRules" ref="formRef" layout="vertical">
        <a-form-item label="项目名称" field="name" required>
          <a-input
            v-model="formData.name"
            placeholder="请输入项目名称"
            :max-length="200"
            show-word-limit
          />
        </a-form-item>
        <a-form-item label="项目描述" field="description" required>
          <a-textarea
            v-model="formData.description"
            placeholder="请输入项目描述"
            :max-length="500"
            :auto-size="{ minRows: 3, maxRows: 6 }"
            show-word-limit
          />
        </a-form-item>
        <a-form-item label="项目负责人" field="owner">
          <a-input
            v-model="formData.owner"
            placeholder="请输入负责人"
            :max-length="64"
          />
        </a-form-item>
        <a-form-item label="项目成员" field="members">
          <a-textarea
            v-model="formData.members"
            placeholder="请输入项目成员，多个成员用逗号分隔"
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue';
import { useRouter, useRoute } from 'vue-router';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconLeft,
  IconEdit,
  IconArchive,
  IconUndo,
  IconDelete,
  IconUser,
} from '@arco-design/web-vue/es/icon';
import ProjectStatistics from './components/ProjectStatistics.vue';
import { DetailSkeleton } from '@/components/skeleton';
import qualityCenterApi from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import type { Project, UpdateProjectDto } from '@/types/quality-center';

const router = useRouter();
const route = useRoute();

// 项目数据
const dataLoading = ref(false);
const isInitialLoad = ref(true);
const project = ref<Project | null>(null);

// 编辑表单
const editModalVisible = ref(false);
const formRef = ref();
const formData = reactive<UpdateProjectDto>({
  name: '',
  description: '',
  owner: '',
  members: '',
});

const formRules = {
  name: [
    { required: true, message: '请输入项目名称' },
    { max: 200, message: '项目名称不能超过200个字符' },
  ],
  description: [
    { required: true, message: '请输入项目描述' },
    { max: 500, message: '项目描述不能超过500个字符' },
  ],
};

// 状态颜色
const statusColor = computed(() => {
  if (!project.value) return 'gray';
  switch (project.value.status) {
    case 'active':
      return 'green';
    case 'archived':
      return 'orange';
    case 'closed':
      return 'red';
    default:
      return 'gray';
  }
});

// 状态文本
const statusText = computed(() => {
  if (!project.value) return '未知';
  switch (project.value.status) {
    case 'active':
      return '活跃';
    case 'archived':
      return '已归档';
    case 'closed':
      return '已关闭';
    default:
      return '未知';
  }
});

// 成员列表
const memberList = computed(() => {
  if (!project.value?.members) return [];
  return project.value.members
    .split(',')
    .map((m) => m.trim())
    .filter((m) => m);
});

// 项目设置
const projectSettings = computed(() => {
  if (!project.value?.settings) return {};
  try {
    return JSON.parse(project.value.settings);
  } catch {
    return {};
  }
});

// 格式化日期时间
const formatDateTime = (timestamp?: number | null) => {
  if (!timestamp) return '未知';
  const date = new Date(timestamp * 1000);
  return date.toLocaleString('zh-CN');
};

// 加载项目详情
const loadProject = async () => {
  const projectId = Number(route.params.id);
  if (!projectId) {
    showError('项目 ID 无效');
    return;
  }

  dataLoading.value = true;
  try {
    project.value = await qualityCenterApi.getProject(projectId);
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载项目详情失败');
  } finally {
    dataLoading.value = false;
  }
};

// 返回
const handleBack = () => {
  router.back();
};

// 编辑
const handleEdit = () => {
  if (!project.value) return;
  
  Object.assign(formData, {
    name: project.value.name,
    description: project.value.description,
    owner: project.value.owner,
    members: project.value.members,
  });
  editModalVisible.value = true;
};

// 归档
const handleArchive = async () => {
  if (!project.value) return;
  
  const confirmed = await showDeleteConfirm(
    `确定要归档项目"${project.value.name}"吗？归档后项目将不再显示在活跃列表中。`,
    '确认归档'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.archiveProject(project.value!.id!),
    {
      loadingText: '归档中...',
      successText: '归档成功',
      errorText: '归档失败',
    }
  );
  
  loadProject();
};

// 恢复
const handleRestore = async () => {
  if (!project.value) return;
  
  await withFeedback(
    () => qualityCenterApi.restoreProject(project.value!.id!),
    {
      loadingText: '恢复中...',
      successText: '恢复成功',
      errorText: '恢复失败',
    }
  );
  
  loadProject();
};

// 删除
const handleDelete = async () => {
  if (!project.value) return;
  
  const confirmed = await showDeleteConfirm(
    `确定要删除项目"${project.value.name}"吗？删除后将无法恢复，所有关联的测试用例、模块、需求也将被删除。`,
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.deleteProject(project.value!.id!),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  router.push('/quality-center/project');
};

// 提交表单
const handleSubmit = async () => {
  if (!project.value) return;
  
  try {
    await formRef.value?.validate();
    
    await withFeedback(
      () => qualityCenterApi.updateProject(project.value!.id!, formData),
      {
        loadingText: '更新中...',
        successText: '更新成功',
        errorText: '更新失败',
      }
    );
    
    editModalVisible.value = false;
    loadProject();
  } catch (error) {
    // 验证失败，不显示错误提示
  }
};

// 取消
const handleCancel = () => {
  editModalVisible.value = false;
  formRef.value?.resetFields();
};

// 注册键盘快捷键
const registerShortcuts = () => {
  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (editModalVisible.value) {
        editModalVisible.value = false;
        return false;
      }
    })
  );
};

onMounted(() => {
  loadProject();
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});
</script>

<style scoped lang="less">
.project-detail-container {
  padding: 20px;
  background: #f5f5f5;
  min-height: calc(100vh - 60px);
}

.detail-content {
  max-width: 1200px;
  margin: 0 auto;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 20px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.header-left {
  display: flex;
  align-items: center;
  gap: 12px;
  
  .page-title {
    margin: 0;
    font-size: 24px;
    font-weight: 600;
    color: #1d2129;
  }
}

.header-right {
  display: flex;
  gap: 12px;
}

.info-card,
.statistics-card,
.members-card,
.settings-card {
  margin-bottom: 20px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.members-list {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.member-tag {
  font-size: 14px;
}

@media (max-width: 768px) {
  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 16px;
  }
  
  .header-left {
    flex-wrap: wrap;
  }
  
  .header-right {
    width: 100%;
    flex-wrap: wrap;
    
    button {
      flex: 1;
    }
  }
  
  :deep(.arco-descriptions) {
    .arco-descriptions-item {
      display: block;
      
      .arco-descriptions-item-label,
      .arco-descriptions-item-value {
        display: block;
        width: 100%;
      }
    }
  }
}
</style>
