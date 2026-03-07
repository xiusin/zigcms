<template>
  <div v-if="selectedCount > 0" class="batch-operation-bar">
    <div class="selected-info">
      <icon-check-circle-fill class="icon" />
      <span>已选择 <strong>{{ selectedCount }}</strong> 项</span>
      <a-button type="text" size="small" @click="clearSelection">
        清空
      </a-button>
    </div>
    
    <a-space class="actions">
      <a-button type="primary" size="small" @click="handleBatchResolve">
        <icon-check />
        批量处理
      </a-button>
      <a-button size="small" @click="handleBatchIgnore">
        <icon-close />
        批量忽略
      </a-button>
      <a-button size="small" @click="handleBatchExport">
        <icon-download />
        批量导出
      </a-button>
      <a-popconfirm
        content="确定删除选中的告警吗？"
        @ok="handleBatchDelete"
      >
        <a-button size="small" status="danger">
          <icon-delete />
          批量删除
        </a-button>
      </a-popconfirm>
    </a-space>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconCheckCircleFill,
  IconCheck,
  IconClose,
  IconDownload,
  IconDelete
} from '@arco-design/web-vue/es/icon';
import { useSecurityStore } from '@/store/modules/security';
import type { BatchHandleAlertsDto } from '@/types/security';

const props = defineProps<{
  selectedIds: number[];
}>();

const emit = defineEmits<{
  (e: 'clear'): void;
  (e: 'success'): void;
}>();

const securityStore = useSecurityStore();
const selectedCount = computed(() => props.selectedIds.length);

const clearSelection = () => {
  emit('clear');
};

const handleBatchResolve = async () => {
  try {
    const dto: BatchHandleAlertsDto = {
      alert_ids: props.selectedIds,
      action: 'resolve',
      comment: '批量处理'
    };
    
    await securityStore.batchHandleAlerts(dto);
    Message.success(`成功处理 ${selectedCount.value} 条告警`);
    emit('success');
  } catch (error) {
    Message.error('批量处理失败');
  }
};

const handleBatchIgnore = async () => {
  try {
    const dto: BatchHandleAlertsDto = {
      alert_ids: props.selectedIds,
      action: 'ignore',
      comment: '批量忽略'
    };
    
    await securityStore.batchHandleAlerts(dto);
    Message.success(`成功忽略 ${selectedCount.value} 条告警`);
    emit('success');
  } catch (error) {
    Message.error('批量忽略失败');
  }
};

const handleBatchExport = () => {
  const alerts = securityStore.alerts.filter(a => 
    props.selectedIds.includes(a.id!)
  );
  
  const data = JSON.stringify(alerts, null, 2);
  const blob = new Blob([data], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `alerts-${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
  Message.success('导出成功');
};

const handleBatchDelete = async () => {
  try {
    await securityStore.batchDeleteAlerts(props.selectedIds);
    Message.success(`成功删除 ${selectedCount.value} 条告警`);
    emit('success');
  } catch (error) {
    Message.error('批量删除失败');
  }
};
</script>

<style scoped lang="less">
.batch-operation-bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px 16px;
  background: var(--color-fill-2);
  border-radius: 4px;
  margin-bottom: 16px;
  
  .selected-info {
    display: flex;
    align-items: center;
    gap: 8px;
    
    .icon {
      font-size: 18px;
      color: rgb(var(--primary-6));
    }
    
    strong {
      color: rgb(var(--primary-6));
    }
  }
  
  .actions {
    :deep(.arco-btn) {
      margin-left: 8px;
    }
  }
}
</style>
