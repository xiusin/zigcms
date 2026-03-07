<template>
  <div class="project-list-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <div class="header-left">
        <h2 class="page-title">项目管理</h2>
        <p class="page-description">管理测试项目，跟踪项目质量</p>
      </div>
      <div class="header-right">
        <a-button type="primary" @click="handleCreate">
          <template #icon>
            <icon-plus />
          </template>
          创建项目
        </a-button>
      </div>
    </div>

    <!-- 搜索和筛选 -->
    <div class="search-bar">
      <a-input-search
        v-model="searchKeyword"
        placeholder="搜索项目名称或描述"
        style="width: 300px"
        @search="handleSearch"
        @clear="handleSearch"
        allow-clear
      />
      <a-select
        v-model="filterStatus"
        placeholder="项目状态"
        style="width: 150px; margin-left: 12px"
        @change="handleSearch"
        allow-clear
      >
        <a-option value="active">活跃</a-option>
        <a-option value="archived">已归档</a-option>
        <a-option value="closed">已关闭</a-option>
      </a-select>
    </div>

    <!-- 项目卡片列表 -->
    <!-- 骨架屏 -->
    <div v-if="isInitialLoad" class="project-grid">
      <CardSkeleton v-for="i in 6" :key="i" :show-title="true" :content-rows="3" />
    </div>
    
    <!-- 实际内容 -->
    <template v-else>
      <a-spin :loading="dataLoading" style="width: 100%">
        <div v-if="projects.length > 0" class="project-grid">
          <ProjectCard
            v-for="project in projects"
            :key="project.id"
            :project="project"
            @view="handleView"
            @edit="handleEdit"
            @archive="handleArchive"
            @restore="handleRestore"
            @delete="handleDelete"
          />
        </div>
        <a-empty v-else description="暂无项目" />
      </a-spin>
    </template>

    <!-- 分页 -->
    <div v-if="total > 0" class="pagination">
      <a-pagination
        v-model:current="currentPage"
        v-model:page-size="pageSize"
        :total="total"
        :page-size-options="[6, 12, 24, 48]"
        show-total
        show-jumper
        show-page-size
        @change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>

    <!-- 创建/编辑项目对话框 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="modalTitle"
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
import { ref, reactive, onMounted, onUnmounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message, Modal } from '@arco-design/web-vue';
import { IconPlus } from '@arco-design/web-vue/es/icon';
import ProjectCard from './components/ProjectCard.vue';
import { CardSkeleton } from '@/components/skeleton';
import qualityCenterApi from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import { storage } from '@/utils/storage';
import type { Project, CreateProjectDto, UpdateProjectDto } from '@/types/quality-center';

// 页面标识（用于状态记忆）
const PAGE_ID = 'project-list';

const router = useRouter();

// 列表数据
const dataLoading = ref(false);
const isInitialLoad = ref(true);
const projects = ref<Project[]>([]);
const total = ref(0);
const currentPage = ref(1);
const savedPageSize = storage.getTablePageSize(PAGE_ID, 12);
const pageSize = ref(savedPageSize);

// 搜索和筛选
const searchKeyword = ref('');
const filterStatus = ref<string | undefined>(undefined);

// 表单数据
const modalVisible = ref(false);
const modalTitle = ref('创建项目');
const formRef = ref();
const editingId = ref<number | null>(null);
const formData = reactive<CreateProjectDto | UpdateProjectDto>({
  name: '',
  description: '',
  owner: '',
  members: '',
  created_by: 'current_user', // TODO: 从用户上下文获取
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

// 加载项目列表
const loadProjects = async () => {
  dataLoading.value = true;
  try {
    const response = await qualityCenterApi.getProjects();
    
    // 过滤数据
    let filteredProjects = response.items;
    
    if (searchKeyword.value) {
      const keyword = searchKeyword.value.toLowerCase();
      filteredProjects = filteredProjects.filter(
        (p) =>
          p.name.toLowerCase().includes(keyword) ||
          p.description.toLowerCase().includes(keyword)
      );
    }
    
    if (filterStatus.value) {
      filteredProjects = filteredProjects.filter((p) => p.status === filterStatus.value);
    }
    
    // 分页
    const start = (currentPage.value - 1) * pageSize.value;
    const end = start + pageSize.value;
    projects.value = filteredProjects.slice(start, end);
    total.value = filteredProjects.length;
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载项目列表失败');
  } finally {
    dataLoading.value = false;
  }
};

// 搜索
const handleSearch = () => {
  currentPage.value = 1;
  loadProjects();
};

// 分页变化
const handlePageChange = (page: number) => {
  currentPage.value = page;
  loadProjects();
};

const handlePageSizeChange = (size: number) => {
  pageSize.value = size;
  currentPage.value = 1;
  // 保存分页大小到存储
  storage.saveTablePageSize(PAGE_ID, size);
  loadProjects();
};

// 创建项目
const handleCreate = () => {
  modalTitle.value = '创建项目';
  editingId.value = null;
  Object.assign(formData, {
    name: '',
    description: '',
    owner: '',
    members: '',
    created_by: 'current_user',
  });
  modalVisible.value = true;
};

// 查看项目详情
const handleView = (project: Project) => {
  router.push(`/quality-center/project/${project.id}`);
};

// 编辑项目
const handleEdit = async (project: Project) => {
  modalTitle.value = '编辑项目';
  editingId.value = project.id!;
  Object.assign(formData, {
    name: project.name,
    description: project.description,
    owner: project.owner,
    members: project.members,
  });
  modalVisible.value = true;
};

// 归档项目
const handleArchive = async (project: Project) => {
  const confirmed = await showDeleteConfirm(
    `确定要归档项目"${project.name}"吗？归档后项目将不再显示在活跃列表中。`,
    '确认归档'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.archiveProject(project.id!),
    {
      loadingText: '归档中...',
      successText: '归档成功',
      errorText: '归档失败',
    }
  );
  
  loadProjects();
};

// 恢复项目
const handleRestore = async (project: Project) => {
  await withFeedback(
    () => qualityCenterApi.restoreProject(project.id!),
    {
      loadingText: '恢复中...',
      successText: '恢复成功',
      errorText: '恢复失败',
    }
  );
  
  loadProjects();
};

// 删除项目
const handleDelete = async (project: Project) => {
  const confirmed = await showDeleteConfirm(
    `确定要删除项目"${project.name}"吗？删除后将无法恢复，所有关联的测试用例、模块、需求也将被删除。`,
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.deleteProject(project.id!),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  loadProjects();
};

// 提交表单
const handleSubmit = async () => {
  try {
    await formRef.value?.validate();
    
    await withFeedback(
      async () => {
        if (editingId.value) {
          await qualityCenterApi.updateProject(editingId.value, formData as UpdateProjectDto);
        } else {
          await qualityCenterApi.createProject(formData as CreateProjectDto);
        }
      },
      {
        loadingText: editingId.value ? '更新中...' : '创建中...',
        successText: editingId.value ? '更新成功' : '创建成功',
        errorText: editingId.value ? '更新失败' : '创建失败',
      }
    );
    
    modalVisible.value = false;
    loadProjects();
  } catch (error) {
    // 验证失败，不显示错误提示
  }
};

// 取消
const handleCancel = () => {
  modalVisible.value = false;
  formRef.value?.resetFields();
};

// 注册键盘快捷键
const registerShortcuts = () => {
  // Ctrl+F 聚焦搜索框
  keyboard.register(
    CommonShortcuts.search(() => {
      const searchInput = document.querySelector<HTMLInputElement>(
        '.search-bar input[type="text"]'
      );
      searchInput?.focus();
    })
  );

  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (modalVisible.value) {
        modalVisible.value = false;
        return false;
      }
    })
  );
};

onMounted(() => {
  loadProjects();
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});
</script>

<style scoped lang="less">
.project-list-container {
  padding: 20px;
  background: #f5f5f5;
  min-height: calc(100vh - 60px);
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 24px;
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.header-left {
  .page-title {
    margin: 0 0 8px 0;
    font-size: 24px;
    font-weight: 600;
    color: #1d2129;
  }
  
  .page-description {
    margin: 0;
    font-size: 14px;
    color: #86909c;
  }
}

.search-bar {
  display: flex;
  align-items: center;
  margin-bottom: 20px;
  padding: 16px 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

.project-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(350px, 1fr));
  gap: 20px;
  margin-bottom: 20px;
}

.pagination {
  display: flex;
  justify-content: flex-end;
  padding: 16px 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
}

@media (max-width: 768px) {
  .project-grid {
    grid-template-columns: 1fr;
  }
  
  .page-header {
    flex-direction: column;
    align-items: flex-start;
    gap: 16px;
  }
  
  .search-bar {
    flex-direction: column;
    align-items: stretch;
    gap: 12px;
    
    :deep(.arco-input-search),
    :deep(.arco-select) {
      width: 100% !important;
      margin-left: 0 !important;
    }
  }
}
</style>
