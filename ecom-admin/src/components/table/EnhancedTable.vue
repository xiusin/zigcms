<template>
  <div class="enhanced-table">
    <!-- 表格工具栏 -->
    <div v-if="showToolbar" class="table-toolbar">
      <div class="toolbar-left">
        <slot name="toolbar-left" />
      </div>
      <div class="toolbar-right">
        <!-- 列设置 -->
        <a-tooltip content="列设置">
          <a-button type="text" @click="showColumnSettings = true">
            <template #icon>
              <icon-settings />
            </template>
          </a-button>
        </a-tooltip>

        <!-- 刷新 -->
        <a-tooltip content="刷新">
          <a-button type="text" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
          </a-button>
        </a-tooltip>

        <!-- 全屏 -->
        <a-tooltip :content="isFullscreen ? '退出全屏' : '全屏'">
          <a-button type="text" @click="toggleFullscreen">
            <template #icon>
              <icon-fullscreen v-if="!isFullscreen" />
              <icon-fullscreen-exit v-else />
            </template>
          </a-button>
        </a-tooltip>

        <slot name="toolbar-right" />
      </div>
    </div>

    <!-- 表格主体 -->
    <a-table
      ref="tableRef"
      v-bind="$attrs"
      :columns="visibleColumns"
      :data="data"
      :loading="loading"
      :pagination="paginationConfig"
      :row-selection="rowSelection"
      :scroll="scrollConfig"
      @change="handleTableChange"
      @page-change="handlePageChange"
      @page-size-change="handlePageSizeChange"
      @sorter-change="handleSorterChange"
      @filter-change="handleFilterChange"
    >
      <!-- 透传所有插槽 -->
      <template v-for="(_, name) in $slots" #[name]="slotData">
        <slot :name="name" v-bind="slotData || {}" />
      </template>
    </a-table>

    <!-- 列设置抽屉 -->
    <a-drawer
      v-model:visible="showColumnSettings"
      title="列设置"
      :width="400"
      @ok="handleSaveColumnSettings"
      @cancel="showColumnSettings = false"
    >
      <div class="column-settings">
        <a-checkbox-group v-model="selectedColumns" direction="vertical">
          <draggable
            v-model="columnList"
            item-key="dataIndex"
            handle=".drag-handle"
            @end="handleColumnDragEnd"
          >
            <template #item="{ element }">
              <div class="column-item">
                <icon-drag-dot-vertical class="drag-handle" />
                <a-checkbox :value="element.dataIndex">
                  {{ element.title }}
                </a-checkbox>
                <a-input-number
                  v-if="element.resizable"
                  v-model="element.width"
                  :min="50"
                  :max="500"
                  :step="10"
                  size="mini"
                  placeholder="宽度"
                  style="width: 80px; margin-left: auto"
                />
              </div>
            </template>
          </draggable>
        </a-checkbox-group>

        <div class="column-settings-actions">
          <a-button type="text" @click="handleResetColumns">
            <template #icon>
              <icon-refresh />
            </template>
            重置
          </a-button>
        </div>
      </div>
    </a-drawer>
  </div>
</template>

<script lang="ts" setup>
import { ref, computed, watch, onMounted, onUnmounted } from 'vue';
import {
  IconSettings,
  IconRefresh,
  IconFullscreen,
  IconFullscreenExit,
  IconDragDotVertical,
} from '@arco-design/web-vue/es/icon';
import draggable from 'vuedraggable';
import { storage } from '@/utils/storage';

interface Props {
  tableId: string;
  columns: any[];
  data: any[];
  loading?: boolean;
  pagination?: any;
  rowSelection?: any;
  scroll?: any;
  showToolbar?: boolean;
  rememberState?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false,
  showToolbar: true,
  rememberState: true,
});

const emit = defineEmits([
  'refresh',
  'change',
  'page-change',
  'page-size-change',
  'sorter-change',
  'filter-change',
]);

// 表格引用
const tableRef = ref();

// 列设置
const showColumnSettings = ref(false);
const columnList = ref<any[]>([]);
const selectedColumns = ref<string[]>([]);

// 全屏状态
const isFullscreen = ref(false);

// 初始化列配置
const initColumns = () => {
  // 从存储中恢复列配置
  if (props.rememberState) {
    const savedColumns = storage.getTableColumns(props.tableId);
    if (savedColumns && savedColumns.length > 0) {
      columnList.value = savedColumns.map((saved) => {
        const original = props.columns.find((col) => col.dataIndex === saved.dataIndex);
        return {
          ...original,
          ...saved,
        };
      });
      selectedColumns.value = savedColumns.filter((col) => col.visible).map((col) => col.dataIndex);
      return;
    }
  }

  // 使用默认列配置
  columnList.value = props.columns.map((col) => ({
    ...col,
    visible: true,
  }));
  selectedColumns.value = props.columns.map((col) => col.dataIndex);
};

// 可见列
const visibleColumns = computed(() => {
  return columnList.value
    .filter((col) => selectedColumns.value.includes(col.dataIndex))
    .map((col) => {
      const { visible, ...rest } = col;
      return rest;
    });
});

// 分页配置
const paginationConfig = computed(() => {
  if (props.pagination === false) {
    return false;
  }

  const defaultPageSize = props.rememberState
    ? storage.getTablePageSize(props.tableId, 20)
    : 20;

  return {
    pageSize: defaultPageSize,
    showTotal: true,
    showJumper: true,
    showPageSize: true,
    ...props.pagination,
  };
});

// 滚动配置
const scrollConfig = computed(() => {
  return {
    x: '100%',
    y: 'auto',
    ...props.scroll,
  };
});

// 刷新
const handleRefresh = () => {
  emit('refresh');
};

// 表格变化
const handleTableChange = (data: any) => {
  emit('change', data);
};

// 分页变化
const handlePageChange = (page: number) => {
  emit('page-change', page);
};

// 分页大小变化
const handlePageSizeChange = (pageSize: number) => {
  if (props.rememberState) {
    storage.saveTablePageSize(props.tableId, pageSize);
  }
  emit('page-size-change', pageSize);
};

// 排序变化
const handleSorterChange = (dataIndex: string, direction: string) => {
  if (props.rememberState) {
    storage.saveTableSorter(props.tableId, dataIndex, direction as any);
  }
  emit('sorter-change', dataIndex, direction);
};

// 筛选变化
const handleFilterChange = (dataIndex: string, filteredValues: string[]) => {
  if (props.rememberState) {
    const filters = storage.getTableFilters(props.tableId) || {};
    filters[dataIndex] = filteredValues;
    storage.saveTableFilters(props.tableId, filters);
  }
  emit('filter-change', dataIndex, filteredValues);
};

// 保存列设置
const handleSaveColumnSettings = () => {
  if (props.rememberState) {
    const columns = columnList.value.map((col) => ({
      dataIndex: col.dataIndex,
      visible: selectedColumns.value.includes(col.dataIndex),
      width: col.width,
      fixed: col.fixed,
    }));
    storage.saveTableColumns(props.tableId, columns);
  }
  showColumnSettings.value = false;
};

// 重置列设置
const handleResetColumns = () => {
  columnList.value = props.columns.map((col) => ({
    ...col,
    visible: true,
  }));
  selectedColumns.value = props.columns.map((col) => col.dataIndex);

  if (props.rememberState) {
    storage.removeTableState(props.tableId);
  }
};

// 列拖拽结束
const handleColumnDragEnd = () => {
  // 拖拽结束后自动保存
  if (props.rememberState) {
    const columns = columnList.value.map((col) => ({
      dataIndex: col.dataIndex,
      visible: selectedColumns.value.includes(col.dataIndex),
      width: col.width,
      fixed: col.fixed,
    }));
    storage.saveTableColumns(props.tableId, columns);
  }
};

// 全屏切换
const toggleFullscreen = () => {
  const element = tableRef.value?.$el;
  if (!element) return;

  if (!isFullscreen.value) {
    if (element.requestFullscreen) {
      element.requestFullscreen();
    }
  } else {
    if (document.exitFullscreen) {
      document.exitFullscreen();
    }
  }
};

// 监听全屏变化
const handleFullscreenChange = () => {
  isFullscreen.value = !!document.fullscreenElement;
};

// 初始化
onMounted(() => {
  initColumns();
  document.addEventListener('fullscreenchange', handleFullscreenChange);
});

// 清理
onUnmounted(() => {
  document.removeEventListener('fullscreenchange', handleFullscreenChange);
});

// 监听列变化
watch(
  () => props.columns,
  () => {
    initColumns();
  },
  { deep: true }
);

// 暴露方法
defineExpose({
  refresh: handleRefresh,
  resetColumns: handleResetColumns,
});
</script>

<style lang="less" scoped>
.enhanced-table {
  .table-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
    padding: 12px 16px;
    background: var(--color-bg-1);
    border-radius: 4px;
    border: 1px solid var(--color-neutral-3);

    .toolbar-left,
    .toolbar-right {
      display: flex;
      align-items: center;
      gap: 8px;
    }
  }

  .column-settings {
    .column-item {
      display: flex;
      align-items: center;
      padding: 8px 0;
      border-bottom: 1px solid var(--color-neutral-2);

      &:last-child {
        border-bottom: none;
      }

      .drag-handle {
        cursor: move;
        margin-right: 8px;
        color: var(--color-text-3);

        &:hover {
          color: var(--color-text-1);
        }
      }

      :deep(.arco-checkbox) {
        flex: 1;
      }
    }

    .column-settings-actions {
      margin-top: 16px;
      padding-top: 16px;
      border-top: 1px solid var(--color-neutral-2);
      display: flex;
      justify-content: flex-end;
    }
  }
}
</style>
