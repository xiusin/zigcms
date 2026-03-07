<template>
  <div class="requirement-list-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-page-header title="需求管理" subtitle="管理产品需求和测试覆盖率" />
      
      <div class="header-actions">
        <a-button type="primary" @click="handleAIGenerate">
          <template #icon><icon-robot /></template>
          AI 生成需求
        </a-button>
        <a-button @click="handleImport">
          <template #icon><icon-import /></template>
          导入
        </a-button>
        <a-button @click="handleExport">
          <template #icon><icon-export /></template>
          导出
        </a-button>
        <a-button type="primary" @click="handleCreate">
          <template #icon><icon-plus /></template>
          新建需求
        </a-button>
      </div>
    </div>

    <!-- 搜索和筛选 -->
    <div class="search-section">
      <a-card :bordered="false">
        <a-form :model="searchForm" layout="inline">
          <a-form-item label="项目">
            <a-select
              v-model="searchForm.project_id"
              placeholder="选择项目"
              allow-clear
              style="width: 200px"
              @change="handleSearch"
            >
              <a-option
                v-for="project in projects"
                :key="project.id"
                :value="project.id"
              >
                {{ project.name }}
              </a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="状态">
            <a-select
              v-model="searchForm.status"
              placeholder="选择状态"
              allow-clear
              style="width: 150px"
              @change="handleSearch"
            >
              <a-option value="pending">待评审</a-option>
              <a-option value="reviewed">已评审</a-option>
              <a-option value="developing">开发中</a-option>
              <a-option value="testing">待测试</a-option>
              <a-option value="in_test">测试中</a-option>
              <a-option value="completed">已完成</a-option>
              <a-option value="closed">已关闭</a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="优先级">
            <a-select
              v-model="searchForm.priority"
              placeholder="选择优先级"
              allow-clear
              style="width: 150px"
              @change="handleSearch"
            >
              <a-option value="low">低</a-option>
              <a-option value="medium">中</a-option>
              <a-option value="high">高</a-option>
              <a-option value="critical">紧急</a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="负责人">
            <a-input
              v-model="searchForm.assignee"
              placeholder="输入负责人"
              allow-clear
              style="width: 150px"
              @press-enter="handleSearch"
            />
          </a-form-item>

          <a-form-item label="关键字">
            <a-input
              v-model="searchForm.keyword"
              placeholder="搜索标题或描述"
              allow-clear
              style="width: 200px"
              @press-enter="handleSearch"
            >
              <template #prefix><icon-search /></template>
            </a-input>
          </a-form-item>

          <a-form-item>
            <a-space>
              <a-button type="primary" @click="handleSearch">
                <template #icon><icon-search /></template>
                搜索
              </a-button>
              <a-button @click="handleReset">
                <template #icon><icon-refresh /></template>
                重置
              </a-button>
            </a-space>
          </a-form-item>
        </a-form>
      </a-card>
    </div>

    <!-- 需求表格 -->
    <div class="table-section">
      <a-card :bordered="false">
        <!-- 骨架屏 -->
        <TableSkeleton v-if="isInitialLoad" :rows="10" />
        
        <!-- 实际表格 -->
        <RequirementTable
          v-else
          :data="requirements"
          :loading="dataLoading"
          :pagination="pagination"
          @view="handleView"
          @edit="handleEdit"
          @delete="handleDelete"
          @page-change="handlePageChange"
          @page-size-change="handlePageSizeChange"
        />
      </a-card>
    </div>

    <!-- 创建/编辑需求对话框 -->
    <a-modal
      v-model:visible="formVisible"
      :title="formMode === 'create' ? '新建需求' : '编辑需求'"
      width="800px"
      @ok="handleFormSubmit"
      @cancel="handleFormCancel"
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

        <a-form-item label="所属项目" field="project_id" required>
          <a-select
            v-model="formData.project_id"
            placeholder="选择项目"
          >
            <a-option
              v-for="project in projects"
              :key="project.id"
              :value="project.id"
            >
              {{ project.name }}
            </a-option>
          </a-select>
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
          <a-col :span="12">
            <a-form-item label="优先级" field="priority">
              <a-select v-model="formData.priority" placeholder="选择优先级">
                <a-option value="low">低</a-option>
                <a-option value="medium">中</a-option>
                <a-option value="high">高</a-option>
                <a-option value="critical">紧急</a-option>
              </a-select>
            </a-form-item>
          </a-col>

          <a-col :span="12">
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

    <!-- AI 生成需求对话框 -->
    <a-modal
      v-model:visible="aiGenerateVisible"
      title="AI 生成需求"
      width="600px"
      @ok="handleAIGenerateSubmit"
      @cancel="aiGenerateVisible = false"
    >
      <a-form layout="vertical">
        <a-form-item label="项目描述">
          <a-textarea
            v-model="aiGenerateForm.project_description"
            placeholder="请输入项目描述，AI 将基于此生成需求"
            :auto-size="{ minRows: 4, maxRows: 8 }"
          />
        </a-form-item>

        <a-form-item label="生成数量">
          <a-input-number
            v-model="aiGenerateForm.max_requirements"
            :min="1"
            :max="20"
            placeholder="请输入生成数量"
            style="width: 100%"
          />
        </a-form-item>
      </a-form>

      <a-alert
        v-if="aiGenerating"
        type="info"
        message="AI 正在生成需求，请稍候..."
      />
    </a-modal>

    <!-- 导入文件对话框 -->
    <a-modal
      v-model:visible="importVisible"
      title="导入需求"
      @ok="handleImportSubmit"
      @cancel="importVisible = false"
    >
      <a-upload
        :file-list="importFileList"
        :auto-upload="false"
        accept=".xlsx,.xls"
        @change="handleImportFileChange"
      >
        <template #upload-button>
          <a-button>
            <template #icon><icon-upload /></template>
            选择文件
          </a-button>
        </template>
      </a-upload>

      <a-alert
        type="info"
        message="请上传 Excel 文件，支持 .xlsx 和 .xls 格式"
        style="margin-top: 16px"
      />
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconPlus,
  IconSearch,
  IconRefresh,
  IconRobot,
  IconImport,
  IconExport,
  IconUpload,
} from '@arco-design/web-vue/es/icon';
import RequirementTable from './components/RequirementTable.vue';
import { TableSkeleton } from '@/components/skeleton';
import qualityCenterApi from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import { storage } from '@/utils/storage';
import type {
  Requirement,
  Project,
  SearchRequirementsQuery,
  CreateRequirementDto,
  UpdateRequirementDto,
  AIGenerateRequirementDto,
} from '@/types/quality-center';

// 页面标识（用于状态记忆）
const PAGE_ID = 'requirement-list';

// ==================== 数据定义 ====================

const dataLoading = ref(false);
const isInitialLoad = ref(true);
const requirements = ref<Requirement[]>([]);
const projects = ref<Project[]>([]);

// 从存储中恢复分页大小
const savedPageSize = storage.getTablePageSize(PAGE_ID, 20);

// 搜索表单
const searchForm = reactive<SearchRequirementsQuery>({
  project_id: undefined,
  status: undefined,
  priority: undefined,
  assignee: undefined,
  keyword: undefined,
  page: 1,
  page_size: savedPageSize,
});

// 分页
const pagination = reactive({
  current: 1,
  pageSize: savedPageSize,
  total: 0,
});

// 表单
const formVisible = ref(false);
const formMode = ref<'create' | 'edit'>('create');
const formRef = ref();
const formData = reactive<CreateRequirementDto | UpdateRequirementDto>({
  project_id: 0,
  title: '',
  description: '',
  priority: 'medium',
  assignee: '',
  estimated_cases: 0,
  created_by: 'current_user', // TODO: 从用户上下文获取
});
const currentEditId = ref<number>();

// 表单验证规则
const formRules = {
  title: [
    { required: true, message: '请输入需求标题' },
    { max: 200, message: '标题长度不能超过 200 个字符' },
  ],
  project_id: [
    { required: true, message: '请选择所属项目' },
  ],
  description: [
    { required: true, message: '请输入需求描述' },
    { max: 2000, message: '描述长度不能超过 2000 个字符' },
  ],
};

// AI 生成
const aiGenerateVisible = ref(false);
const aiGenerating = ref(false);
const aiGenerateForm = reactive<AIGenerateRequirementDto>({
  project_description: '',
  max_requirements: 5,
  language: 'zh-CN',
});

// 导入
const importVisible = ref(false);
const importFileList = ref<any[]>([]);

// ==================== 生命周期 ====================

// 注册键盘快捷键
const registerShortcuts = () => {
  // Ctrl+F 聚焦搜索框
  keyboard.register(
    CommonShortcuts.search(() => {
      const searchInput = document.querySelector<HTMLInputElement>(
        'input[placeholder="搜索标题或描述"]'
      );
      searchInput?.focus();
    })
  );

  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (formVisible.value) {
        formVisible.value = false;
        return false;
      }
      if (aiGenerateVisible.value) {
        aiGenerateVisible.value = false;
        return false;
      }
      if (importVisible.value) {
        importVisible.value = false;
        return false;
      }
    })
  );
};

onMounted(() => {
  loadProjects();
  loadRequirements();
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});

// ==================== 方法 ====================

/**
 * 加载项目列表
 */
const loadProjects = async () => {
  try {
    const result = await qualityCenterApi.getProjects();
    projects.value = result.items;
  } catch (error: any) {
    showError(error?.message || '加载项目列表失败');
  }
};

/**
 * 加载需求列表
 */
const loadRequirements = async () => {
  dataLoading.value = true;
  try {
    const result = await qualityCenterApi.searchRequirements(searchForm);
    requirements.value = result.items;
    pagination.total = result.total;
    pagination.current = result.page;
    pagination.pageSize = result.page_size;
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载需求列表失败');
  } finally {
    dataLoading.value = false;
  }
};

/**
 * 搜索
 */
const handleSearch = () => {
  searchForm.page = 1;
  pagination.current = 1;
  loadRequirements();
};

/**
 * 重置搜索
 */
const handleReset = () => {
  Object.assign(searchForm, {
    project_id: undefined,
    status: undefined,
    priority: undefined,
    assignee: undefined,
    keyword: undefined,
    page: 1,
    page_size: 20,
  });
  handleSearch();
};

/**
 * 分页变化
 */
const handlePageChange = (page: number) => {
  searchForm.page = page;
  pagination.current = page;
  loadRequirements();
};

/**
 * 分页大小变化
 */
const handlePageSizeChange = (pageSize: number) => {
  searchForm.page_size = pageSize;
  searchForm.page = 1;
  pagination.pageSize = pageSize;
  pagination.current = 1;
  // 保存分页大小到存储
  storage.saveTablePageSize(PAGE_ID, pageSize);
  loadRequirements();
};

/**
 * 新建需求
 */
const handleCreate = () => {
  formMode.value = 'create';
  Object.assign(formData, {
    project_id: searchForm.project_id || 0,
    title: '',
    description: '',
    priority: 'medium',
    assignee: '',
    estimated_cases: 0,
    created_by: 'current_user',
  });
  formVisible.value = true;
};

/**
 * 查看需求
 */
const handleView = (record: Requirement) => {
  // 跳转到需求详情页
  window.location.href = `/quality-center/requirement/${record.id}`;
};

/**
 * 编辑需求
 */
const handleEdit = (record: Requirement) => {
  formMode.value = 'edit';
  currentEditId.value = record.id;
  Object.assign(formData, {
    title: record.title,
    description: record.description,
    priority: record.priority,
    assignee: record.assignee,
    estimated_cases: record.estimated_cases,
  });
  formVisible.value = true;
};

/**
 * 删除需求
 */
const handleDelete = async (record: Requirement) => {
  const confirmed = await showDeleteConfirm(
    `确定要删除需求"${record.title}"吗？此操作不可恢复。`,
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.deleteRequirement(record.id!),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  loadRequirements();
};

/**
 * 提交表单
 */
const handleFormSubmit = async () => {
  try {
    await formRef.value?.validate();
    
    await withFeedback(
      async () => {
        if (formMode.value === 'create') {
          await qualityCenterApi.createRequirement(formData as CreateRequirementDto);
        } else {
          await qualityCenterApi.updateRequirement(
            currentEditId.value!,
            formData as UpdateRequirementDto
          );
        }
      },
      {
        loadingText: formMode.value === 'create' ? '创建中...' : '更新中...',
        successText: formMode.value === 'create' ? '创建成功' : '更新成功',
        errorText: formMode.value === 'create' ? '创建失败' : '更新失败',
      }
    );
    
    formVisible.value = false;
    loadRequirements();
  } catch (error) {
    // 验证失败，不显示错误提示
  }
};

/**
 * 取消表单
 */
const handleFormCancel = () => {
  formVisible.value = false;
  formRef.value?.resetFields();
};

/**
 * AI 生成需求
 */
const handleAIGenerate = () => {
  aiGenerateForm.project_description = '';
  aiGenerateForm.max_requirements = 5;
  aiGenerateVisible.value = true;
};

/**
 * 提交 AI 生成
 */
const handleAIGenerateSubmit = async () => {
  if (!aiGenerateForm.project_description) {
    showError('请输入项目描述');
    return;
  }
  
  aiGenerating.value = true;
  try {
    const result = await withFeedback(
      () => qualityCenterApi.generateRequirement(aiGenerateForm),
      {
        loadingText: 'AI 生成中...',
        successText: 'AI 生成成功',
        errorText: 'AI 生成失败',
      }
    );
    
    // 自动填充表单
    formMode.value = 'create';
    Object.assign(formData, {
      project_id: searchForm.project_id || 0,
      title: result.title,
      description: result.description,
      priority: result.priority,
      estimated_cases: result.estimated_cases,
      created_by: 'current_user',
    });
    
    aiGenerateVisible.value = false;
    formVisible.value = true;
  } finally {
    aiGenerating.value = false;
  }
};

/**
 * 导入需求
 */
const handleImport = () => {
  importFileList.value = [];
  importVisible.value = true;
};

/**
 * 导入文件变化
 */
const handleImportFileChange = (fileList: any[]) => {
  importFileList.value = fileList;
};

/**
 * 提交导入
 */
const handleImportSubmit = async () => {
  if (importFileList.value.length === 0) {
    showError('请选择文件');
    return;
  }
  
  const file = importFileList.value[0].file;
  await withFeedback(
    () => qualityCenterApi.importRequirements(file),
    {
      loadingText: '导入中...',
      successText: '导入成功',
      errorText: '导入失败',
    }
  );
  
  importVisible.value = false;
  loadRequirements();
};

/**
 * 导出需求
 */
const handleExport = async () => {
  const blob = await withFeedback(
    () => qualityCenterApi.exportRequirements(searchForm.project_id),
    {
      loadingText: '导出中...',
      successText: '导出成功',
      errorText: '导出失败',
    }
  );
  
  // 创建下载链接
  const url = window.URL.createObjectURL(blob);
  const link = document.createElement('a');
  link.href = url;
  link.download = `需求列表_${new Date().getTime()}.xlsx`;
  link.click();
  window.URL.revokeObjectURL(url);
};
</script>

<style scoped lang="less">
.requirement-list-page {
  padding: 20px;
  
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    
    .header-actions {
      display: flex;
      gap: 12px;
    }
  }
  
  .search-section {
    margin-bottom: 20px;
  }
  
  .table-section {
    // 表格样式
  }
}
</style>
