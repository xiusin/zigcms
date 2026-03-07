<template>
  <a-table
    :data="data"
    :loading="loading"
    :row-selection="{
      type: 'checkbox',
      selectedRowKeys: selectedKeys,
      onSelect: handleSelect,
      onSelectAll: handleSelectAll,
    }"
    :pagination="false"
    :scroll="{ x: 1400 }"
    row-key="id"
  >
    <!-- ID -->
    <a-table-column title="ID" data-index="id" :width="80" fixed="left" />

    <!-- 标题 -->
    <a-table-column title="标题" data-index="title" :width="250" fixed="left">
      <template #cell="{ record }">
        <a-tooltip :content="record.title">
          <div class="title-cell">{{ record.title }}</div>
        </a-tooltip>
      </template>
    </a-table-column>

    <!-- 状态 -->
    <a-table-column title="状态" data-index="status" :width="120">
      <template #cell="{ record }">
        <a-tag :color="getStatusColor(record.status)">
          {{ getStatusText(record.status) }}
        </a-tag>
      </template>
    </a-table-column>

    <!-- 优先级 -->
    <a-table-column title="优先级" data-index="priority" :width="120">
      <template #cell="{ record }">
        <a-tag :color="getPriorityColor(record.priority)">
          {{ getPriorityText(record.priority) }}
        </a-tag>
      </template>
    </a-table-column>

    <!-- 负责人 -->
    <a-table-column title="负责人" data-index="assignee" :width="120">
      <template #cell="{ record }">
        <span>{{ record.assignee || '-' }}</span>
      </template>
    </a-table-column>

    <!-- 创建人 -->
    <a-table-column title="创建人" data-index="created_by" :width="120" />

    <!-- 创建时间 -->
    <a-table-column title="创建时间" data-index="created_at" :width="180">
      <template #cell="{ record }">
        {{ formatDate(record.created_at) }}
      </template>
    </a-table-column>

    <!-- 更新时间 -->
    <a-table-column title="更新时间" data-index="updated_at" :width="180">
      <template #cell="{ record }">
        {{ formatDate(record.updated_at) }}
      </template>
    </a-table-column>

    <!-- 操作 -->
    <a-table-column title="操作" :width="240" fixed="right">
      <template #cell="{ record }">
        <a-space>
          <a-button
            type="text"
            size="small"
            @click="$emit('view', record)"
          >
            查看
          </a-button>
          <a-button
            type="text"
            size="small"
            @click="$emit('edit', record)"
          >
            编辑
          </a-button>
          <a-button
            type="text"
            size="small"
            status="success"
            @click="$emit('execute', record)"
          >
            执行
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
  </a-table>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { TestCase, TestCaseStatus, Priority } from '@/types/quality-center';
import dayjs from 'dayjs';

interface Props {
  data: TestCase[];
  loading?: boolean;
  selectedKeys?: number[];
}

interface Emits {
  (e: 'selection-change', keys: number[]): void;
  (e: 'view', record: TestCase): void;
  (e: 'edit', record: TestCase): void;
  (e: 'execute', record: TestCase): void;
  (e: 'delete', record: TestCase): void;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  selectedKeys: () => [],
});

const emit = defineEmits<Emits>();

// 内部选中状态
const internalSelectedKeys = ref<number[]>([]);

// 监听外部选中状态变化
watch(
  () => props.selectedKeys,
  (newKeys) => {
    internalSelectedKeys.value = newKeys;
  },
  { immediate: true }
);

// 选择单行
const handleSelect = (rowKeys: number[], rowKey: number, record: TestCase) => {
  internalSelectedKeys.value = rowKeys;
  emit('selection-change', rowKeys);
};

// 全选/取消全选
const handleSelectAll = (checked: boolean) => {
  if (checked) {
    internalSelectedKeys.value = props.data.map((item) => item.id!);
  } else {
    internalSelectedKeys.value = [];
  }
  emit('selection-change', internalSelectedKeys.value);
};

// 状态颜色
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

// 状态文本
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

// 优先级颜色
const getPriorityColor = (priority: Priority): string => {
  const colorMap: Record<Priority, string> = {
    low: 'gray',
    medium: 'blue',
    high: 'orange',
    critical: 'red',
  };
  return colorMap[priority] || 'gray';
};

// 优先级文本
const getPriorityText = (priority: Priority): string => {
  const textMap: Record<Priority, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '紧急',
  };
  return textMap[priority] || priority;
};

// 格式化日期
const formatDate = (timestamp: number | null | undefined): string => {
  if (!timestamp) return '-';
  return dayjs(timestamp * 1000).format('YYYY-MM-DD HH:mm:ss');
};
</script>

<style scoped lang="less">
.title-cell {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
  max-width: 230px;
}
</style>
