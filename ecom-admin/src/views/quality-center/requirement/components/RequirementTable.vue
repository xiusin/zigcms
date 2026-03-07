<template>
  <div class="requirement-table">
    <a-table
      :data="data"
      :loading="loading"
      :pagination="paginationConfig"
      :bordered="false"
      :stripe="true"
      row-key="id"
      @page-change="handlePageChange"
      @page-size-change="handlePageSizeChange"
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
        title="需求标题"
        data-index="title"
        :width="300"
      >
        <template #cell="{ record }">
          <a-link @click="handleView(record)" class="requirement-title">
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

      <!-- 覆盖率列 -->
      <a-table-column
        title="覆盖率"
        data-index="coverage_rate"
        :width="150"
        align="center"
      >
        <template #cell="{ record }">
          <div class="coverage-cell">
            <a-progress
              :percent="record.coverage_rate"
              :status="getCoverageStatus(record.coverage_rate)"
              :show-text="false"
              size="small"
            />
            <span class="coverage-text">
              {{ record.coverage_rate.toFixed(1) }}%
              ({{ record.actual_cases }}/{{ record.estimated_cases }})
            </span>
          </div>
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
        :width="200"
        align="center"
        fixed="right"
      >
        <template #cell="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleView(record)"
            >
              <template #icon><icon-eye /></template>
              查看
            </a-button>
            <a-button
              type="text"
              size="small"
              @click="handleEdit(record)"
            >
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-button
              type="text"
              size="small"
              status="danger"
              @click="handleDelete(record)"
            >
              <template #icon><icon-delete /></template>
              删除
            </a-button>
          </a-space>
        </template>
      </a-table-column>
    </a-table>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { IconEye, IconEdit, IconDelete } from '@arco-design/web-vue/es/icon';
import type { Requirement, RequirementStatus, Priority } from '@/types/quality-center';

// ==================== Props ====================

interface Props {
  data: Requirement[];
  loading?: boolean;
  pagination: {
    current: number;
    pageSize: number;
    total: number;
  };
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

// ==================== Emits ====================

const emit = defineEmits<{
  view: [record: Requirement];
  edit: [record: Requirement];
  delete: [record: Requirement];
  pageChange: [page: number, pageSize: number];
}>();

// ==================== 计算属性 ====================

const paginationConfig = computed(() => ({
  current: props.pagination.current,
  pageSize: props.pagination.pageSize,
  total: props.pagination.total,
  showTotal: true,
  showPageSize: true,
  pageSizeOptions: [10, 20, 50, 100],
}));

// ==================== 方法 ====================

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
 * 查看需求
 */
const handleView = (record: Requirement) => {
  emit('view', record);
};

/**
 * 编辑需求
 */
const handleEdit = (record: Requirement) => {
  emit('edit', record);
};

/**
 * 删除需求
 */
const handleDelete = (record: Requirement) => {
  emit('delete', record);
};

/**
 * 分页变化
 */
const handlePageChange = (page: number) => {
  emit('pageChange', page, props.pagination.pageSize);
};

/**
 * 每页条数变化
 */
const handlePageSizeChange = (pageSize: number) => {
  emit('pageChange', 1, pageSize);
};
</script>

<style scoped lang="less">
.requirement-table {
  .requirement-title {
    font-weight: 500;
    cursor: pointer;
    
    &:hover {
      color: rgb(var(--primary-6));
    }
  }
  
  .text-gray {
    color: var(--color-text-3);
  }
  
  .coverage-cell {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    
    .coverage-text {
      font-size: 12px;
      color: var(--color-text-2);
    }
  }
}
</style>
