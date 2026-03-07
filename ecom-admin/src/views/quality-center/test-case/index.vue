<template>
  <div class="test-case-page">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-breadcrumb>
        <a-breadcrumb-item>质量中心</a-breadcrumb-item>
        <a-breadcrumb-item>测试用例</a-breadcrumb-item>
      </a-breadcrumb>
      
      <div class="header-actions">
        <a-button type="primary" @click="handleCreate">
          <template #icon><icon-plus /></template>
          新建用例
        </a-button>
        <a-button @click="handleAIGenerate">
          <template #icon><icon-robot /></template>
          AI 生成
        </a-button>
      </div>
    </div>

    <!-- 搜索筛选 -->
    <a-card class="search-card" :bordered="false">
      <a-form :model="searchForm" layout="inline">
        <a-form-item label="项目">
          <a-select
            v-model="searchForm.project_id"
            placeholder="请选择项目"
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
        </a-form-item>

        <a-form-item label="模块">
          <a-select
            v-model="searchForm.module_id"
            placeholder="请选择模块"
            style="width: 200px"
            allow-clear
            :disabled="!searchForm.project_id"
          >
            <a-option
              v-for="module in modules"
              :key="module.id"
              :value="module.id"
            >
              {{ module.name }}
            </a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="状态">
          <a-select
            v-model="searchForm.status"
            placeholder="请选择状态"
            style="width: 150px"
            allow-clear
          >
            <a-option value="pending">待执行</a-option>
            <a-option value="in_progress">执行中</a-option>
            <a-option value="passed">已通过</a-option>
            <a-option value="failed">未通过</a-option>
            <a-option value="blocked">已阻塞</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="负责人">
          <a-input
            v-model="searchForm.assignee"
            placeholder="请输入负责人"
            style="width: 150px"
            allow-clear
          />
        </a-form-item>

        <a-form-item label="关键字">
          <a-input
            v-model="searchForm.keyword"
            placeholder="搜索标题"
            style="width: 200px"
            allow-clear
          />
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

    <!-- 测试用例表格 -->
    <a-card class="table-card" :bordered="false">
      <!-- 骨架屏 -->
      <TableSkeleton v-if="isInitialLoad" :rows="10" />
      
      <!-- 表格内容 -->
      <template v-else>
        <TestCaseTable
          :data="testCases"
          :loading="dataLoading"
          :selected-keys="selectedKeys"
          @selection-change="handleSelectionChange"
          @view="handleView"
          @edit="handleEdit"
          @execute="handleExecute"
          @delete="handleDelete"
        />

        <!-- 分页 -->
        <div class="pagination-wrapper">
          <a-pagination
            v-model:current="pagination.page"
            v-model:page-size="pagination.page_size"
            :total="pagination.total"
            :page-size-options="[10, 20, 50, 100]"
            show-total
            show-jumper
            show-page-size
            @change="handlePageChange"
            @page-size-change="handlePageSizeChange"
          />
        </div>
      </template>
    </a-card>

    <!-- 批量操作栏 -->
    <div v-if="selectedKeys.length > 0" class="batch-actions">
      <div class="batch-info">
        已选择 <span class="count">{{ selectedKeys.length }}</span> 项
      </div>
      <a-space>
        <a-button @click="handleBatchUpdateStatus">批量更新状态</a-button>
        <a-button @click="handleBatchUpdateAssignee">批量分配</a-button>
        <a-button status="danger" @click="handleBatchDelete">批量删除</a-button>
        <a-button @click="handleClearSelection">取消选择</a-button>
      </a-space>
    </div>

    <!-- 测试用例表单对话框 -->
    <a-modal
      v-model:visible="formVisible"
      :title="formMode === 'create' ? '新建测试用例' : '编辑测试用例'"
      width="800px"
      @ok="handleFormSubmit"
      @cancel="handleFormCancel"
    >
      <TestCaseForm
        ref="formRef"
        :mode="formMode"
        :data="currentTestCase"
        :projects="projects"
      />
    </a-modal>

    <!-- AI 生成对话框 -->
    <AIGenerateDialog
      v-model:visible="aiDialogVisible"
      :projects="projects"
      @success="handleAIGenerateSuccess"
    />

    <!-- 执行历史对话框 -->
    <a-modal
      v-model:visible="historyVisible"
      title="执行历史"
      width="800px"
      :footer="false"
    >
      <ExecutionHistory :test-case-id="currentTestCaseId" />
    </a-modal>

    <!-- 批量更新状态对话框 -->
    <a-modal
      v-model:visible="batchStatusVisible"
      title="批量更新状态"
      @ok="handleBatchStatusSubmit"
    >
      <a-form :model="batchStatusForm">
        <a-form-item label="目标状态" required>
          <a-select v-model="batchStatusForm.status" placeholder="请选择状态">
            <a-option value="pending">待执行</a-option>
            <a-option value="in_progress">执行中</a-option>
            <a-option value="passed">已通过</a-option>
            <a-option value="failed">未通过</a-option>
            <a-option value="blocked">已阻塞</a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 批量分配对话框 -->
    <a-modal
      v-model:visible="batchAssigneeVisible"
      title="批量分配负责人"
      @ok="handleBatchAssigneeSubmit"
    >
      <a-form :model="batchAssigneeForm">
        <a-form-item label="负责人" required>
          <a-input
            v-model="batchAssigneeForm.assignee"
            placeholder="请输入负责人"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconPlus,
  IconRobot,
  IconSearch,
  IconRefresh,
} from '@arco-design/web-vue/es/icon';
import TestCaseTable from './components/TestCaseTable.vue';
import TestCaseForm from './components/TestCaseForm.vue';
import AIGenerateDialog from './components/AIGenerateDialog.vue';
import ExecutionHistory from './components/ExecutionHistory.vue';
import { TableSkeleton } from '@/components/skeleton';
import qualityCenterApi from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  showBatchConfirm,
  loading,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import { storage } from '@/utils/storage';
import type {
  TestCase,
  Project,
  Module,
  SearchTestCasesQuery,
  BatchUpdateStatusDto,
  BatchUpdateAssigneeDto,
} from '@/types/quality-center';

// 页面标识（用于状态记忆）
const PAGE_ID = 'test-case-list';

// 从存储中恢复分页大小
const savedPageSize = storage.getTablePageSize(PAGE_ID, 20);

// 搜索表单
const searchForm = reactive<SearchTestCasesQuery>({
  project_id: undefined,
  module_id: undefined,
  status: undefined,
  assignee: undefined,
  keyword: undefined,
  page: 1,
  page_size: savedPageSize,
});

// 分页
const pagination = reactive({
  page: 1,
  page_size: savedPageSize,
  total: 0,
});

// 数据
const testCases = ref<TestCase[]>([]);
const projects = ref<Project[]>([]);
const modules = ref<Module[]>([]);
const dataLoading = ref(false);
const selectedKeys = ref<number[]>([]);

// 初始加载标志
const isInitialLoad = ref(true);

// 表单
const formVisible = ref(false);
const formMode = ref<'create' | 'edit'>('create');
const currentTestCase = ref<TestCase | null>(null);
const formRef = ref();

// AI 生成
const aiDialogVisible = ref(false);

// 执行历史
const historyVisible = ref(false);
const currentTestCaseId = ref<number>(0);

// 批量操作
const batchStatusVisible = ref(false);
const batchStatusForm = reactive<BatchUpdateStatusDto>({
  ids: [],
  status: 'pending',
});

const batchAssigneeVisible = ref(false);
const batchAssigneeForm = reactive<BatchUpdateAssigneeDto>({
  ids: [],
  assignee: '',
});

// 加载项目列表
const loadProjects = async () => {
  try {
    const result = await qualityCenterApi.getProjects();
    projects.value = result.items;
  } catch (error: any) {
    showError(error?.message || '加载项目列表失败');
  }
};

// 加载模块列表
const loadModules = async (projectId: number) => {
  try {
    const result = await qualityCenterApi.getModuleTree(projectId);
    // 扁平化树形结构
    const flattenModules = (nodes: Module[]): Module[] => {
      return nodes.reduce((acc, node) => {
        acc.push(node);
        if (node.children && node.children.length > 0) {
          acc.push(...flattenModules(node.children));
        }
        return acc;
      }, [] as Module[]);
    };
    modules.value = flattenModules(result);
  } catch (error: any) {
    showError(error?.message || '加载模块列表失败');
  }
};

// 加载测试用例列表
const loadTestCases = async () => {
  dataLoading.value = true;
  try {
    const result = await qualityCenterApi.searchTestCases({
      ...searchForm,
      page: pagination.page,
      page_size: pagination.page_size,
    });
    testCases.value = result.items;
    pagination.total = result.total;
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载测试用例列表失败');
  } finally {
    dataLoading.value = false;
  }
};

// 项目变更
const handleProjectChange = (projectId: number | undefined) => {
  searchForm.module_id = undefined;
  modules.value = [];
  if (projectId) {
    loadModules(projectId);
  }
};

// 搜索
const handleSearch = () => {
  pagination.page = 1;
  loadTestCases();
};

// 重置
const handleReset = () => {
  Object.assign(searchForm, {
    project_id: undefined,
    module_id: undefined,
    status: undefined,
    assignee: undefined,
    keyword: undefined,
  });
  modules.value = [];
  pagination.page = 1;
  loadTestCases();
};

// 分页变更
const handlePageChange = (page: number) => {
  pagination.page = page;
  loadTestCases();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.page_size = pageSize;
  pagination.page = 1;
  // 保存分页大小到存储
  storage.saveTablePageSize(PAGE_ID, pageSize);
  loadTestCases();
};

// 选择变更
const handleSelectionChange = (keys: number[]) => {
  selectedKeys.value = keys;
};

// 新建
const handleCreate = () => {
  formMode.value = 'create';
  currentTestCase.value = null;
  formVisible.value = true;
};

// 查看
const handleView = (record: TestCase) => {
  currentTestCaseId.value = record.id!;
  historyVisible.value = true;
};

// 编辑
const handleEdit = (record: TestCase) => {
  formMode.value = 'edit';
  currentTestCase.value = record;
  formVisible.value = true;
};

// 执行
const handleExecute = (record: TestCase) => {
  // TODO: 打开执行对话框
  Message.info('执行功能待实现');
};

// 删除
const handleDelete = async (record: TestCase) => {
  const confirmed = await showDeleteConfirm(
    `确定要删除测试用例"${record.title}"吗？此操作不可恢复。`,
    '删除确认'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.deleteTestCase(record.id!),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  loadTestCases();
};

// 表单提交
const handleFormSubmit = async () => {
  const valid = await formRef.value?.validate();
  if (!valid) return;

  const formData = formRef.value?.getFormData();
  
  await withFeedback(
    async () => {
      if (formMode.value === 'create') {
        await qualityCenterApi.createTestCase(formData);
      } else {
        await qualityCenterApi.updateTestCase(currentTestCase.value!.id!, formData);
      }
    },
    {
      loadingText: formMode.value === 'create' ? '创建中...' : '更新中...',
      successText: formMode.value === 'create' ? '创建成功' : '更新成功',
      errorText: formMode.value === 'create' ? '创建失败' : '更新失败',
    }
  );
  
  formVisible.value = false;
  loadTestCases();
};

// 表单取消
const handleFormCancel = () => {
  formVisible.value = false;
};

// AI 生成
const handleAIGenerate = () => {
  aiDialogVisible.value = true;
};

// AI 生成成功
const handleAIGenerateSuccess = () => {
  loadTestCases();
};

// 批量更新状态
const handleBatchUpdateStatus = () => {
  batchStatusForm.ids = selectedKeys.value;
  batchStatusForm.status = 'pending';
  batchStatusVisible.value = true;
};

const handleBatchStatusSubmit = async () => {
  if (!batchStatusForm.status) {
    showError('请选择目标状态');
    return;
  }

  const confirmed = await showBatchConfirm(
    selectedKeys.value.length,
    '更新状态'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.batchUpdateTestCaseStatus(batchStatusForm),
    {
      loadingText: '批量更新中...',
      successText: '批量更新成功',
      errorText: '批量更新失败',
    }
  );
  
  batchStatusVisible.value = false;
  selectedKeys.value = [];
  loadTestCases();
};

// 批量分配
const handleBatchUpdateAssignee = () => {
  batchAssigneeForm.ids = selectedKeys.value;
  batchAssigneeForm.assignee = '';
  batchAssigneeVisible.value = true;
};

const handleBatchAssigneeSubmit = async () => {
  if (!batchAssigneeForm.assignee) {
    showError('请输入负责人');
    return;
  }

  const confirmed = await showBatchConfirm(
    selectedKeys.value.length,
    '分配负责人'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.batchUpdateTestCaseAssignee(batchAssigneeForm),
    {
      loadingText: '批量分配中...',
      successText: '批量分配成功',
      errorText: '批量分配失败',
    }
  );
  
  batchAssigneeVisible.value = false;
  selectedKeys.value = [];
  loadTestCases();
};

// 批量删除
const handleBatchDelete = async () => {
  const confirmed = await showDeleteConfirm(
    `确定要删除选中的 ${selectedKeys.value.length} 个测试用例吗？此操作不可恢复。`,
    '批量删除确认'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.batchDeleteTestCases(selectedKeys.value),
    {
      loadingText: '批量删除中...',
      successText: '批量删除成功',
      errorText: '批量删除失败',
    }
  );
  
  selectedKeys.value = [];
  loadTestCases();
};

// 取消选择
const handleClearSelection = () => {
  selectedKeys.value = [];
};

// 注册键盘快捷键
const registerShortcuts = () => {
  // Ctrl+F 聚焦搜索框
  keyboard.register(
    CommonShortcuts.search(() => {
      const keywordInput = document.querySelector<HTMLInputElement>(
        'input[placeholder="搜索标题"]'
      );
      keywordInput?.focus();
    })
  );

  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (formVisible.value) {
        formVisible.value = false;
        return false;
      }
      if (aiDialogVisible.value) {
        aiDialogVisible.value = false;
        return false;
      }
      if (historyVisible.value) {
        historyVisible.value = false;
        return false;
      }
      if (batchStatusVisible.value) {
        batchStatusVisible.value = false;
        return false;
      }
      if (batchAssigneeVisible.value) {
        batchAssigneeVisible.value = false;
        return false;
      }
      if (selectedKeys.value.length > 0) {
        selectedKeys.value = [];
        return false;
      }
    })
  );
};

// 初始化
onMounted(() => {
  loadProjects();
  loadTestCases();
  registerShortcuts();
});

// 清理
onUnmounted(() => {
  keyboard.unregisterAll();
});
</script>

<style scoped lang="less">
.test-case-page {
  padding: 20px;
  min-height: 100vh;
  background: #f5f5f5;
}

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

.search-card {
  margin-bottom: 20px;
}

.table-card {
  margin-bottom: 20px;
}

.pagination-wrapper {
  display: flex;
  justify-content: flex-end;
  margin-top: 20px;
}

.batch-actions {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px 24px;
  background: #fff;
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
  z-index: 100;

  .batch-info {
    font-size: 14px;
    color: #666;

    .count {
      color: #165dff;
      font-weight: 600;
      margin: 0 4px;
    }
  }
}
</style>
