<template>
  <div class="linked-test-cases">
    <!-- 操作栏 -->
    <div class="actions-bar">
      <a-space>
        <a-button type="primary" @click="handleAddLink">
          <template #icon><icon-plus /></template>
          添加关联
        </a-button>
        <a-button @click="handleRefresh">
          <template #icon><icon-refresh /></template>
          刷新
        </a-button>
      </a-space>
      
      <div class="stats">
        <a-statistic
          title="关联用例数"
          :value="testCases.length"
          :value-style="{ fontSize: '20px' }"
        />
      </div>
    </div>

    <!-- 测试用例列表 -->
    <a-table
      :data="testCases"
      :loading="loading"
      :pagination="false"
      :bordered="false"
      :stripe="true"
      row-key="id"
    >
      <!-- ID 列 -->
      <a-table-column
        title="ID"
        data-index="id"
        :width="80"
        align="center"
      />

      <!-- 标题列 -->
      <a-table-column
        title="测试用例标题"
        data-index="title"
        :width="300"
      >
        <template #cell="{ record }">
          <a-link @click="handleViewCase(record)" class="case-title">
            {{ record.title }}
          </a-link>
        </template>
      </a-table-column>

      <!-- 状态列 -->
      <a-table-column
        title="状态"
        data-index="status"
        :width="120"
        align="center"
      >
        <template #cell="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
      </a-table-column>

      <!-- 优先级列 -->
      <a-table-column
        title="优先级"
        data-index="priority"
        :width="100"
        align="center"
      >
        <template #cell="{ record }">
          <a-tag :color="getPriorityColor(record.priority)">
            {{ getPriorityText(record.priority) }}
          </a-tag>
        </template>
      </a-table-column>

      <!-- 负责人列 -->
      <a-table-column
        title="负责人"
        data-index="assignee"
        :width="120"
        align="center"
      >
        <template #cell="{ record }">
          <span v-if="record.assignee">{{ record.assignee }}</span>
          <span v-else class="text-gray">未分配</span>
        </template>
      </a-table-column>

      <!-- 创建时间列 -->
      <a-table-column
        title="创建时间"
        data-index="created_at"
        :width="180"
        align="center"
      >
        <template #cell="{ record }">
          {{ formatDate(record.created_at) }}
        </template>
      </a-table-column>

      <!-- 操作列 -->
      <a-table-column
        title="操作"
        :width="150"
        align="center"
        fixed="right"
      >
        <template #cell="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleViewCase(record)"
            >
              <template #icon><icon-eye /></template>
              查看
            </a-button>
            <a-button
              type="text"
              size="small"
              status="danger"
              @click="handleUnlink(record)"
            >
              <template #icon><icon-close /></template>
              移除
            </a-button>
          </a-space>
        </template>
      </a-table-column>
    </a-table>

    <!-- 空状态 -->
    <a-empty
      v-if="testCases.length === 0 && !loading"
      description="暂无关联测试用例"
    >
      <a-button type="primary" @click="handleAddLink">
        <template #icon><icon-plus /></template>
        添加关联
      </a-button>
    </a-empty>

    <!-- 添加关联对话框 -->
    <a-modal
      v-model:visible="linkVisible"
      title="添加关联测试用例"
      width="900px"
      @ok="handleLinkSubmit"
      @cancel="linkVisible = false"
    >
      <!-- 搜索栏 -->
      <div class="search-bar">
        <a-input
          v-model="searchKeyword"
          placeholder="搜索测试用例标题"
          allow-clear
          @press-enter="handleSearchCases"
        >
          <template #prefix><icon-search /></template>
        </a-input>
        <a-button type="primary" @click="handleSearchCases">
          搜索
        </a-button>
      </div>

      <!-- 可选测试用例列表 -->
      <a-table
        :data="availableCases"
        :loading="searchLoading"
        :pagination="searchPagination"
        :row-selection="{
          type: 'checkbox',
          selectedRowKeys: selectedCaseIds,
          onSelect: handleSelectCase,
          onSelectAll: handleSelectAllCases,
        }"
        :bordered="false"
        :stripe="true"
        row-key="id"
        @page-change="handleSearchPageChange"
      >
        <a-table-column
          title="ID"
          data-index="id"
          :width="80"
          align="center"
        />

        <a-table-column
          title="测试用例标题"
          data-index="title"
        />

        <a-table-column
          title="状态"
          data-index="status"
          :width="120"
          align="center"
        >
          <template #cell="{ record }">
            <a-tag :color="getStatusColor(record.status)">
              {{ getStatusText(record.status) }}
            </a-tag>
          </template>
        </a-table-column>

        <a-table-column
          title="优先级"
          data-index="priority"
          :width="100"
          align="center"
        >
          <template #cell="{ record }">
            <a-tag :color="getPriorityColor(record.priority)">
              {{ getPriorityText(record.priority) }}
            </a-tag>
          </template>
        </a-table-column>
      </a-table>

      <template #footer>
        <div class="modal-footer">
          <span class="selected-count">
            已选择 {{ selectedCaseIds.length }} 个测试用例
          </span>
          <a-space>
            <a-button @click="linkVisible = false">取消</a-button>
            <a-button
              type="primary"
              :disabled="selectedCaseIds.length === 0"
              @click="handleLinkSubmit"
            >
              确定
            </a-button>
          </a-space>
        </div>
      </template>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconPlus,
  IconRefresh,
  IconEye,
  IconClose,
  IconSearch,
} from '@arco-design/web-vue/es/icon';
import qualityCenterApi from '@/api/quality-center';
import type {
  TestCase,
  TestCaseStatus,
  Priority,
  SearchTestCasesQuery,
} from '@/types/quality-center';

// ==================== Props ====================

interface Props {
  requirementId: number;
  testCases: TestCase[];
}

const props = defineProps<Props>();

// ==================== Emits ====================

const emit = defineEmits<{
  refresh: [];
}>();

// ==================== 数据定义 ====================

const loading = ref(false);

// 添加关联
const linkVisible = ref(false);
const searchLoading = ref(false);
const searchKeyword = ref('');
const availableCases = ref<TestCase[]>([]);
const selectedCaseIds = ref<number[]>([]);

const searchPagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
  showTotal: true,
});

// ==================== 计算属性 ====================

const linkedCaseIds = computed(() => {
  return props.testCases.map(c => c.id).filter(id => id !== undefined) as number[];
});

// ==================== 方法 ====================

/**
 * 获取状态颜色
 */
const getStatusColor = (status: TestCaseStatus): string => {
  const colorMap: Record<TestCaseStatus, string> = {
    pending: 'gray',
    in_progress: 'blue',
    passed: 'green',
    failed: 'red',
    blocked: 'orange',
  };
  return colorMap[status] || 'gray';
};

/**
 * 获取状态文本
 */
const getStatusText = (status: TestCaseStatus): string => {
  const textMap: Record<TestCaseStatus, string> = {
    pending: '待执行',
    in_progress: '执行中',
    passed: '已通过',
    failed: '未通过',
    blocked: '已阻塞',
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
 * 查看测试用例
 */
const handleViewCase = (record: TestCase) => {
  window.open(`/quality-center/test-case/${record.id}`, '_blank');
};

/**
 * 刷新
 */
const handleRefresh = () => {
  emit('refresh');
};

/**
 * 添加关联
 */
const handleAddLink = () => {
  searchKeyword.value = '';
  selectedCaseIds.value = [];
  linkVisible.value = true;
  searchAvailableCases();
};

/**
 * 搜索可用测试用例
 */
const searchAvailableCases = async () => {
  searchLoading.value = true;
  try {
    const query: SearchTestCasesQuery = {
      keyword: searchKeyword.value || undefined,
      page: searchPagination.current,
      page_size: searchPagination.pageSize,
    };
    
    const result = await qualityCenterApi.searchTestCases(query);
    
    // 过滤掉已关联的测试用例
    availableCases.value = result.items.filter(
      c => !linkedCaseIds.value.includes(c.id!)
    );
    
    searchPagination.total = result.total;
  } catch (error) {
    Message.error('搜索测试用例失败');
    console.error(error);
  } finally {
    searchLoading.value = false;
  }
};

/**
 * 搜索测试用例
 */
const handleSearchCases = () => {
  searchPagination.current = 1;
  searchAvailableCases();
};

/**
 * 搜索分页变化
 */
const handleSearchPageChange = (page: number) => {
  searchPagination.current = page;
  searchAvailableCases();
};

/**
 * 选择测试用例
 */
const handleSelectCase = (rowKeys: (string | number)[], record: TestCase) => {
  const id = record.id!;
  const index = selectedCaseIds.value.indexOf(id);
  
  if (index > -1) {
    selectedCaseIds.value.splice(index, 1);
  } else {
    selectedCaseIds.value.push(id);
  }
};

/**
 * 全选测试用例
 */
const handleSelectAllCases = (checked: boolean) => {
  if (checked) {
    selectedCaseIds.value = availableCases.value
      .map(c => c.id)
      .filter(id => id !== undefined) as number[];
  } else {
    selectedCaseIds.value = [];
  }
};

/**
 * 提交关联
 */
const handleLinkSubmit = async () => {
  if (selectedCaseIds.value.length === 0) {
    Message.warning('请选择要关联的测试用例');
    return;
  }
  
  try {
    // 批量关联
    for (const caseId of selectedCaseIds.value) {
      await qualityCenterApi.linkTestCase(props.requirementId, {
        test_case_id: caseId,
      });
    }
    
    Message.success(`成功关联 ${selectedCaseIds.value.length} 个测试用例`);
    linkVisible.value = false;
    emit('refresh');
  } catch (error) {
    Message.error('关联失败');
    console.error(error);
  }
};

/**
 * 移除关联
 */
const handleUnlink = (record: TestCase) => {
  Modal.confirm({
    title: '确认移除',
    content: `确定要移除测试用例"${record.title}"的关联吗？`,
    onOk: async () => {
      try {
        await qualityCenterApi.unlinkTestCase(props.requirementId, record.id!);
        Message.success('移除成功');
        emit('refresh');
      } catch (error) {
        Message.error('移除失败');
        console.error(error);
      }
    },
  });
};
</script>

<style scoped lang="less">
.linked-test-cases {
  .actions-bar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    
    .stats {
      // 统计样式
    }
  }
  
  .case-title {
    font-weight: 500;
    cursor: pointer;
    
    &:hover {
      color: rgb(var(--primary-6));
    }
  }
  
  .text-gray {
    color: var(--color-text-3);
  }
  
  .search-bar {
    display: flex;
    gap: 12px;
    margin-bottom: 16px;
  }
  
  .modal-footer {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;
    
    .selected-count {
      color: var(--color-text-2);
      font-size: 14px;
    }
  }
}
</style>
