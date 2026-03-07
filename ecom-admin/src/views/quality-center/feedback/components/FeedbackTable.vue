<template>
  <a-table
    :loading="loading"
    :data="data"
    :pagination="paginationProps"
    :row-selection="rowSelection"
    :scroll="{ x: 1400 }"
    @page-change="handlePageChange"
    @page-size-change="handlePageSizeChange"
  >
    <template #columns>
      <a-table-column title="ID" data-index="id" :width="80" fixed="left" />
      
      <a-table-column title="标题" data-index="title" :width="200" fixed="left">
        <template #cell="{ record }">
          <a-link @click="$emit('view', record)">{{ record.title }}</a-link>
        </template>
      </a-table-column>

      <a-table-column title="类型" data-index="type" :width="120">
        <template #cell="{ record }">
          <a-tag :color="getTypeColor(record.type)">
            {{ getTypeText(record.type) }}
          </a-tag>
        </template>
      </a-table-column>

      <a-table-column title="严重程度" data-index="severity" :width="120">
        <template #cell="{ record }">
          <a-tag :color="getSeverityColor(record.severity)">
            {{ getSeverityText(record.severity) }}
          </a-tag>
        </template>
      </a-table-column>

      <a-table-column title="状态" data-index="status" :width="120">
        <template #cell="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
      </a-table-column>

      <a-table-column title="负责人" data-index="assignee" :width="120">
        <template #cell="{ record }">
          <span v-if="record.assignee">{{ record.assignee }}</span>
          <span v-else class="text-placeholder">未指派</span>
        </template>
      </a-table-column>

      <a-table-column title="提交人" data-index="submitter" :width="120" />

      <a-table-column title="跟进进度" :width="150">
        <template #cell="{ record }">
          <div class="follow-progress">
            <div class="progress-text">
              跟进 {{ record.follow_count || 0 }} 次
            </div>
            <div v-if="record.last_follow_at" class="progress-time">
              最后跟进: {{ formatTime(record.last_follow_at) }}
            </div>
            <div v-else class="progress-time text-placeholder">
              暂无跟进
            </div>
          </div>
        </template>
      </a-table-column>

      <a-table-column title="提交时间" data-index="created_at" :width="180">
        <template #cell="{ record }">
          {{ formatDateTime(record.created_at) }}
        </template>
      </a-table-column>

      <a-table-column title="SLA 状态" :width="150">
        <template #cell="{ record }">
          <SLAIndicator
            :created-at="record.created_at"
            :severity="record.severity"
            :status="record.status"
          />
        </template>
      </a-table-column>

      <a-table-column title="操作" :width="180" fixed="right">
        <template #cell="{ record }">
          <a-space>
            <a-button type="text" size="small" @click="$emit('view', record)">
              查看
            </a-button>
            <a-button type="text" size="small" @click="$emit('edit', record)">
              编辑
            </a-button>
            <a-button
              type="text"
              size="small"
              status="danger"
              @click="$emit('delete', record)"
            >
              删除
            </a-button>
          </a-space>
        </template>
      </a-table-column>
    </template>
  </a-table>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import type { Feedback } from '@/types/quality-center';
import { formatDateTime, formatTime } from '@/utils/date';
import SLAIndicator from '@/components/sla/SLAIndicator.vue';

interface Props {
  loading?: boolean;
  data: Feedback[];
  pagination: {
    current: number;
    pageSize: number;
    total: number;
  };
  selectedKeys: number[];
}

interface Emits {
  (e: 'selection-change', keys: number[]): void;
  (e: 'page-change', page: number, pageSize: number): void;
  (e: 'view', record: Feedback): void;
  (e: 'edit', record: Feedback): void;
  (e: 'delete', record: Feedback): void;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
});

const emit = defineEmits<Emits>();

// 分页配置
const paginationProps = computed(() => ({
  current: props.pagination.current,
  pageSize: props.pagination.pageSize,
  total: props.pagination.total,
  showTotal: true,
  showPageSize: true,
  pageSizeOptions: [10, 20, 50, 100],
}));

// 行选择配置
const rowSelection = computed(() => ({
  type: 'checkbox',
  selectedRowKeys: props.selectedKeys,
  onSelect: (rowKeys: number[]) => {
    emit('selection-change', rowKeys);
  },
  onSelectAll: (checked: boolean) => {
    if (checked) {
      const allKeys = props.data.map((item) => item.id!);
      emit('selection-change', allKeys);
    } else {
      emit('selection-change', []);
    }
  },
}));

// 分页变化
const handlePageChange = (page: number) => {
  emit('page-change', page, props.pagination.pageSize);
};

const handlePageSizeChange = (pageSize: number) => {
  emit('page-change', 1, pageSize);
};

// 类型相关
const getTypeText = (type: string) => {
  const map: Record<string, string> = {
    bug: 'Bug',
    feature: '功能建议',
    improvement: '改进建议',
    question: '问题咨询',
  };
  return map[type] || type;
};

const getTypeColor = (type: string) => {
  const map: Record<string, string> = {
    bug: 'red',
    feature: 'blue',
    improvement: 'orange',
    question: 'purple',
  };
  return map[type] || 'gray';
};

// 严重程度相关
const getSeverityText = (severity: string) => {
  const map: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '紧急',
  };
  return map[severity] || severity;
};

const getSeverityColor = (severity: string) => {
  const map: Record<string, string> = {
    low: 'gray',
    medium: 'blue',
    high: 'orange',
    critical: 'red',
  };
  return map[severity] || 'gray';
};

// 状态相关
const getStatusText = (status: string) => {
  const map: Record<string, string> = {
    pending: '待处理',
    in_progress: '处理中',
    resolved: '已解决',
    closed: '已关闭',
    rejected: '已拒绝',
  };
  return map[status] || status;
};

const getStatusColor = (status: string) => {
  const map: Record<string, string> = {
    pending: 'gray',
    in_progress: 'blue',
    resolved: 'green',
    closed: 'arcoblue',
    rejected: 'red',
  };
  return map[status] || 'gray';
};
</script>

<style scoped lang="less">
.follow-progress {
  .progress-text {
    font-size: 14px;
    color: var(--color-text-1);
    margin-bottom: 4px;
  }

  .progress-time {
    font-size: 12px;
    color: var(--color-text-3);
  }
}

.text-placeholder {
  color: var(--color-text-3);
}
</style>
