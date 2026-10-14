<template>
  <div class="virtual-table">
    <!-- 表头 -->
    <div class="virtual-table-header">
      <table>
        <thead>
          <tr>
            <th
              v-for="column in columns"
              :key="column.dataIndex"
              :style="{ width: column.width ? `${column.width}px` : 'auto' }"
            >
              {{ column.title }}
            </th>
          </tr>
        </thead>
      </table>
    </div>

    <!-- 虚拟列表 -->
    <VirtualList
      ref="virtualListRef"
      :items="data"
      :item-height="rowHeight"
      :container-height="containerHeight"
      :buffer-size="bufferSize"
      :item-key="rowKey"
      :loading="loading"
      @load-more="emit('load-more')"
      @scroll="emit('scroll', $event)"
    >
      <template #item="{ item }">
        <table>
          <tbody>
            <tr>
              <td
                v-for="column in columns"
                :key="column.dataIndex"
                :style="{ width: column.width ? `${column.width}px` : 'auto' }"
              >
                <!-- 自定义渲染 -->
                <slot
                  v-if="column.slotName"
                  :name="column.slotName"
                  :record="item"
                  :column="column"
                >
                  {{ item[column.dataIndex] }}
                </slot>
                <!-- 默认渲染 -->
                <span v-else>
                  {{ item[column.dataIndex] }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </template>
    </VirtualList>

    <!-- 空状态 -->
    <a-empty v-if="data.length === 0 && !loading" description="暂无数据" />
  </div>
</template>

<script setup lang="ts" generic="T extends Record<string, any>">
import { ref } from 'vue';
import VirtualList from './VirtualList.vue';

interface Column {
  title: string;
  dataIndex: string;
  width?: number;
  slotName?: string;
}

interface Props {
  columns: Column[];
  data: T[];
  rowHeight?: number;
  containerHeight?: string;
  bufferSize?: number;
  rowKey?: string;
  loading?: boolean;
}

interface Emits {
  (e: 'load-more'): void;
  (e: 'scroll', event: Event): void;
}

withDefaults(defineProps<Props>(), {
  rowHeight: 50,
  containerHeight: '600px',
  bufferSize: 5,
  rowKey: 'id',
  loading: false,
});

const emit = defineEmits<Emits>();

// 虚拟列表引用
const virtualListRef = ref<InstanceType<typeof VirtualList>>();

// 滚动到指定行
const scrollToRow = (index: number) => {
  virtualListRef.value?.scrollTo(index);
};

// 滚动到顶部
const scrollToTop = () => {
  virtualListRef.value?.scrollToTop();
};

// 滚动到底部
const scrollToBottom = () => {
  virtualListRef.value?.scrollToBottom();
};

// 暴露方法
defineExpose({
  scrollToRow,
  scrollToTop,
  scrollToBottom,
});
</script>

<style scoped lang="scss">
.virtual-table {
  border: 1px solid #e5e7eb;
  border-radius: 4px;
  overflow: hidden;

  .virtual-table-header {
    background: #f9fafb;
    border-bottom: 1px solid #e5e7eb;

    table {
      width: 100%;
      border-collapse: collapse;

      th {
        padding: 12px 16px;
        text-align: left;
        font-weight: 600;
        color: #374151;
        border-right: 1px solid #e5e7eb;

        &:last-child {
          border-right: none;
        }
      }
    }
  }

  :deep(.virtual-list-item) {
    table {
      width: 100%;
      border-collapse: collapse;

      td {
        padding: 12px 16px;
        border-right: 1px solid #e5e7eb;
        border-bottom: 1px solid #e5e7eb;

        &:last-child {
          border-right: none;
        }
      }

      tr:hover {
        background: #f9fafb;
      }
    }
  }
}
</style>
