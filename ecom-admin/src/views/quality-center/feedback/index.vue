<template>
  <div class="feedback-list-container">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-breadcrumb>
        <a-breadcrumb-item>质量中心</a-breadcrumb-item>
        <a-breadcrumb-item>反馈管理</a-breadcrumb-item>
      </a-breadcrumb>
      <h1 class="page-title">反馈管理</h1>
    </div>

    <!-- 筛选区域 -->
    <a-card class="filter-card" :bordered="false">
      <a-form :model="filterForm" layout="inline">
        <a-form-item label="关键字">
          <a-input
            v-model="filterForm.keyword"
            placeholder="搜索标题或内容"
            allow-clear
            style="width: 200px"
            @press-enter="handleSearch"
          >
            <template #prefix>
              <icon-search />
            </template>
          </a-input>
        </a-form-item>

        <a-form-item label="状态">
          <a-select
            v-model="filterForm.status"
            placeholder="全部状态"
            allow-clear
            style="width: 150px"
            @change="handleSearch"
          >
            <a-option value="pending">待处理</a-option>
            <a-option value="in_progress">处理中</a-option>
            <a-option value="resolved">已解决</a-option>
            <a-option value="closed">已关闭</a-option>
            <a-option value="rejected">已拒绝</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="类型">
          <a-select
            v-model="filterForm.type"
            placeholder="全部类型"
            allow-clear
            style="width: 150px"
            @change="handleSearch"
          >
            <a-option value="bug">Bug</a-option>
            <a-option value="feature">功能建议</a-option>
            <a-option value="improvement">改进建议</a-option>
            <a-option value="question">问题咨询</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="严重程度">
          <a-select
            v-model="filterForm.severity"
            placeholder="全部程度"
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
        
        <a-form-item label="智能分类">
          <a-select
            v-model="filterForm.category"
            placeholder="全部分类"
            allow-clear
            style="width: 150px"
            @change="handleSearch"
          >
            <a-option value="用户认证">用户认证</a-option>
            <a-option value="支付系统">支付系统</a-option>
            <a-option value="订单管理">订单管理</a-option>
            <a-option value="商品管理">商品管理</a-option>
            <a-option value="性能优化">性能优化</a-option>
            <a-option value="界面设计">界面设计</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="负责人">
          <a-input
            v-model="filterForm.assignee"
            placeholder="负责人"
            allow-clear
            style="width: 150px"
            @press-enter="handleSearch"
          />
        </a-form-item>

        <a-form-item label="提交时间">
          <a-range-picker
            v-model="filterForm.dateRange"
            style="width: 260px"
            @change="handleSearch"
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

    <!-- 操作栏 -->
    <a-card class="action-card" :bordered="false">
      <a-space>
        <a-button
          type="primary"
          :disabled="selectedRowKeys.length === 0"
          @click="handleBatchAssign"
        >
          <template #icon><icon-user /></template>
          批量指派
        </a-button>
        <a-button
          :disabled="selectedRowKeys.length === 0"
          @click="handleBatchUpdateStatus"
        >
          <template #icon><icon-edit /></template>
          批量修改状态
        </a-button>
        <a-button
          status="danger"
          :disabled="selectedRowKeys.length === 0"
          @click="handleBatchDelete"
        >
          <template #icon><icon-delete /></template>
          批量删除
        </a-button>
        <a-button @click="handleExport">
          <template #icon><icon-download /></template>
          导出
        </a-button>
      </a-space>
      <div class="selected-info" v-if="selectedRowKeys.length > 0">
        已选择 {{ selectedRowKeys.length }} 项
        <a-button type="text" size="small" @click="handleClearSelection">
          清空
        </a-button>
      </div>
    </a-card>

    <!-- 反馈表格 -->
    <a-card :bordered="false">
      <!-- 骨架屏 -->
      <TableSkeleton v-if="isInitialLoad" :rows="10" />
      
      <!-- 实际表格 -->
      <FeedbackTable
        v-else
        :loading="dataLoading"
        :data="feedbackList"
        :pagination="pagination"
        :selected-keys="selectedRowKeys"
        @selection-change="handleSelectionChange"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
        @view="handleView"
        @edit="handleEdit"
        @delete="handleDelete"
      />
    </a-card>

    <!-- 批量指派对话框 -->
    <a-modal
      v-model:visible="batchAssignVisible"
      title="批量指派"
      @ok="handleBatchAssignConfirm"
      @cancel="batchAssignVisible = false"
    >
      <a-form :model="batchAssignForm" layout="vertical">
        <a-form-item label="负责人" required>
          <a-input
            v-model="batchAssignForm.assignee"
            placeholder="请输入负责人"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 批量修改状态对话框 -->
    <a-modal
      v-model:visible="batchStatusVisible"
      title="批量修改状态"
      @ok="handleBatchStatusConfirm"
      @cancel="batchStatusVisible = false"
    >
      <a-form :model="batchStatusForm" layout="vertical">
        <a-form-item label="状态" required>
          <a-select
            v-model="batchStatusForm.status"
            placeholder="请选择状态"
          >
            <a-option value="pending">待处理</a-option>
            <a-option value="in_progress">处理中</a-option>
            <a-option value="resolved">已解决</a-option>
            <a-option value="closed">已关闭</a-option>
            <a-option value="rejected">已拒绝</a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, onUnmounted } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import { useRouter } from 'vue-router';
import FeedbackTable from './components/FeedbackTable.vue';
import { TableSkeleton } from '@/components/skeleton';
import {
  searchFeedbacks,
  batchAssignFeedbacks,
  batchUpdateFeedbackStatus,
  batchDeleteFeedbacks,
  exportFeedbacks,
} from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  showBatchConfirm,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import { storage } from '@/utils/storage';
import type { Feedback, FeedbackSearchQuery } from '@/types/quality-center';

// 页面标识（用于状态记忆）
const PAGE_ID = 'feedback-list';

const router = useRouter();

// 从存储中恢复分页大小
const savedPageSize = storage.getTablePageSize(PAGE_ID, 20);

// 筛选表单
const filterForm = reactive<FeedbackSearchQuery>({
  keyword: '',
  status: undefined,
  type: undefined,
  severity: undefined,
  category: undefined,
  assignee: '',
  dateRange: undefined,
  page: 1,
  page_size: savedPageSize,
});

// 反馈列表
const feedbackList = ref<Feedback[]>([]);
const dataLoading = ref(false);
const isInitialLoad = ref(true);
const pagination = reactive({
  current: 1,
  pageSize: savedPageSize,
  total: 0,
});

// 选中的行
const selectedRowKeys = ref<number[]>([]);

// 批量指派
const batchAssignVisible = ref(false);
const batchAssignForm = reactive({
  assignee: '',
});

// 批量修改状态
const batchStatusVisible = ref(false);
const batchStatusForm = reactive({
  status: '',
});

// 加载反馈列表
const loadFeedbacks = async () => {
  dataLoading.value = true;
  try {
    const query: FeedbackSearchQuery = {
      ...filterForm,
      page: pagination.current,
      page_size: pagination.pageSize,
    };

    // 处理日期范围
    if (filterForm.dateRange && filterForm.dateRange.length === 2) {
      query.start_date = filterForm.dateRange[0];
      query.end_date = filterForm.dateRange[1];
    }

    const result = await searchFeedbacks(query);
    feedbackList.value = result.items;
    pagination.total = result.total;
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载反馈列表失败');
  } finally {
    dataLoading.value = false;
  }
};

// 搜索
const handleSearch = () => {
  pagination.current = 1;
  loadFeedbacks();
};

// 重置
const handleReset = () => {
  Object.assign(filterForm, {
    keyword: '',
    status: undefined,
    type: undefined,
    severity: undefined,
    category: undefined,
    assignee: '',
    dateRange: undefined,
  });
  handleSearch();
};

// 分页变化
const handlePageChange = (page: number) => {
  pagination.current = page;
  loadFeedbacks();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.pageSize = pageSize;
  pagination.current = 1;
  // 保存分页大小到存储
  storage.saveTablePageSize(PAGE_ID, pageSize);
  loadFeedbacks();
};

// 选择变化
const handleSelectionChange = (keys: number[]) => {
  selectedRowKeys.value = keys;
};

// 清空选择
const handleClearSelection = () => {
  selectedRowKeys.value = [];
};

// 查看详情
const handleView = (record: Feedback) => {
  router.push(`/quality-center/feedback/${record.id}`);
};

// 编辑
const handleEdit = (record: Feedback) => {
  router.push(`/quality-center/feedback/${record.id}/edit`);
};

// 删除
const handleDelete = async (record: Feedback) => {
  const confirmed = await showDeleteConfirm(
    `确定要删除反馈"${record.title}"吗？此操作不可恢复。`,
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => batchDeleteFeedbacks([record.id!]),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  loadFeedbacks();
};

// 批量指派
const handleBatchAssign = () => {
  batchAssignForm.assignee = '';
  batchAssignVisible.value = true;
};

const handleBatchAssignConfirm = async () => {
  if (!batchAssignForm.assignee) {
    showError('请输入负责人');
    return;
  }

  await withFeedback(
    () => batchAssignFeedbacks(selectedRowKeys.value, batchAssignForm.assignee),
    {
      loadingText: '批量指派中...',
      successText: '批量指派成功',
      errorText: '批量指派失败',
    }
  );
  
  batchAssignVisible.value = false;
  selectedRowKeys.value = [];
  loadFeedbacks();
};

// 批量修改状态
const handleBatchUpdateStatus = () => {
  batchStatusForm.status = '';
  batchStatusVisible.value = true;
};

const handleBatchStatusConfirm = async () => {
  if (!batchStatusForm.status) {
    showError('请选择状态');
    return;
  }

  await withFeedback(
    () => batchUpdateFeedbackStatus(selectedRowKeys.value, batchStatusForm.status),
    {
      loadingText: '批量修改中...',
      successText: '批量修改状态成功',
      errorText: '批量修改状态失败',
    }
  );
  
  batchStatusVisible.value = false;
  selectedRowKeys.value = [];
  loadFeedbacks();
};

// 批量删除
const handleBatchDelete = async () => {
  const confirmed = await showBatchConfirm(
    selectedRowKeys.value.length,
    '删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => batchDeleteFeedbacks(selectedRowKeys.value),
    {
      loadingText: '批量删除中...',
      successText: '批量删除成功',
      errorText: '批量删除失败',
    }
  );
  
  selectedRowKeys.value = [];
  loadFeedbacks();
};

// 导出
const handleExport = async () => {
  const query: FeedbackSearchQuery = { ...filterForm };
  if (filterForm.dateRange && filterForm.dateRange.length === 2) {
    query.start_date = filterForm.dateRange[0];
    query.end_date = filterForm.dateRange[1];
  }

  await withFeedback(
    () => exportFeedbacks(query),
    {
      loadingText: '导出中...',
      successText: '导出成功',
      errorText: '导出失败',
    }
  );
};

// 注册键盘快捷键
const registerShortcuts = () => {
  // Ctrl+F 聚焦搜索框
  keyboard.register(
    CommonShortcuts.search(() => {
      const searchInput = document.querySelector<HTMLInputElement>(
        'input[placeholder="搜索标题或内容"]'
      );
      searchInput?.focus();
    })
  );

  // Esc 关闭弹窗或取消选择
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (batchAssignVisible.value) {
        batchAssignVisible.value = false;
        return false;
      }
      if (batchStatusVisible.value) {
        batchStatusVisible.value = false;
        return false;
      }
      if (selectedRowKeys.value.length > 0) {
        selectedRowKeys.value = [];
        return false;
      }
    })
  );
};

onMounted(() => {
  loadFeedbacks();
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});
</script>

<style scoped lang="less">
.feedback-list-container {
  padding: 20px;

  .page-header {
    margin-bottom: 20px;

    .page-title {
      margin-top: 8px;
      font-size: 20px;
      font-weight: 600;
    }
  }

  .filter-card {
    margin-bottom: 16px;
  }

  .action-card {
    margin-bottom: 16px;
    display: flex;
    justify-content: space-between;
    align-items: center;

    .selected-info {
      color: var(--color-text-2);
      font-size: 14px;
    }
  }
}
</style>
