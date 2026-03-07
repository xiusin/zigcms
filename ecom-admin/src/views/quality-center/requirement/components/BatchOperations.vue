<template>
  <div class="batch-operations">
    <a-space>
      <span class="selected-count">
        已选择 {{ selectedCount }} 项
      </span>
      
      <a-button
        type="primary"
        status="danger"
        :disabled="selectedCount === 0"
        @click="handleBatchDelete"
      >
        <template #icon><icon-delete /></template>
        批量删除
      </a-button>
      
      <a-button
        :disabled="selectedCount === 0"
        @click="handleBatchUpdateStatus"
      >
        <template #icon><icon-edit /></template>
        批量修改状态
      </a-button>
      
      <a-button
        :disabled="selectedCount === 0"
        @click="handleBatchAssign"
      >
        <template #icon><icon-user /></template>
        批量分配负责人
      </a-button>
      
      <a-button
        :disabled="selectedCount === 0"
        @click="handleBatchExport"
      >
        <template #icon><icon-export /></template>
        批量导出
      </a-button>
      
      <a-button @click="handleClearSelection">
        <template #icon><icon-close /></template>
        清空选择
      </a-button>
    </a-space>

    <!-- 批量修改状态对话框 -->
    <a-modal
      v-model:visible="statusVisible"
      title="批量修改状态"
      @ok="handleStatusSubmit"
      @cancel="statusVisible = false"
    >
      <a-form layout="vertical">
        <a-form-item label="目标状态" required>
          <a-select v-model="targetStatus" placeholder="选择目标状态">
            <a-option value="pending">待评审</a-option>
            <a-option value="reviewed">已评审</a-option>
            <a-option value="developing">开发中</a-option>
            <a-option value="testing">待测试</a-option>
            <a-option value="in_test">测试中</a-option>
            <a-option value="completed">已完成</a-option>
            <a-option value="closed">已关闭</a-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="备注">
          <a-textarea
            v-model="statusRemark"
            placeholder="请输入备注（可选）"
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 批量分配负责人对话框 -->
    <a-modal
      v-model:visible="assignVisible"
      title="批量分配负责人"
      @ok="handleAssignSubmit"
      @cancel="assignVisible = false"
    >
      <a-form layout="vertical">
        <a-form-item label="负责人" required>
          <a-input
            v-model="targetAssignee"
            placeholder="请输入负责人"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconDelete,
  IconEdit,
  IconUser,
  IconExport,
  IconClose,
} from '@arco-design/web-vue/es/icon';
import type { RequirementStatus } from '@/types/quality-center';

// ==================== Props ====================

interface Props {
  selectedIds: number[];
  selectedCount: number;
}

const props = defineProps<Props>();

// ==================== Emits ====================

const emit = defineEmits<{
  batchDelete: [ids: number[]];
  batchUpdateStatus: [ids: number[], status: RequirementStatus, remark?: string];
  batchAssign: [ids: number[], assignee: string];
  batchExport: [ids: number[]];
  clearSelection: [];
}>();

// ==================== 数据定义 ====================

// 批量修改状态
const statusVisible = ref(false);
const targetStatus = ref<RequirementStatus>('pending');
const statusRemark = ref('');

// 批量分配负责人
const assignVisible = ref(false);
const targetAssignee = ref('');

// ==================== 方法 ====================

/**
 * 批量删除
 */
const handleBatchDelete = () => {
  Modal.confirm({
    title: '确认批量删除',
    content: `确定要删除选中的 ${props.selectedCount} 个需求吗？此操作不可恢复。`,
    onOk: () => {
      emit('batchDelete', props.selectedIds);
    },
  });
};

/**
 * 批量修改状态
 */
const handleBatchUpdateStatus = () => {
  targetStatus.value = 'pending';
  statusRemark.value = '';
  statusVisible.value = true;
};

/**
 * 提交批量修改状态
 */
const handleStatusSubmit = () => {
  if (!targetStatus.value) {
    Message.warning('请选择目标状态');
    return;
  }
  
  emit('batchUpdateStatus', props.selectedIds, targetStatus.value, statusRemark.value);
  statusVisible.value = false;
};

/**
 * 批量分配负责人
 */
const handleBatchAssign = () => {
  targetAssignee.value = '';
  assignVisible.value = true;
};

/**
 * 提交批量分配
 */
const handleAssignSubmit = () => {
  if (!targetAssignee.value) {
    Message.warning('请输入负责人');
    return;
  }
  
  emit('batchAssign', props.selectedIds, targetAssignee.value);
  assignVisible.value = false;
};

/**
 * 批量导出
 */
const handleBatchExport = () => {
  emit('batchExport', props.selectedIds);
};

/**
 * 清空选择
 */
const handleClearSelection = () => {
  emit('clearSelection');
};
</script>

<style scoped lang="less">
.batch-operations {
  padding: 12px 16px;
  background: var(--color-fill-2);
  border-radius: 4px;
  
  .selected-count {
    font-weight: 500;
    color: var(--color-text-1);
  }
}
</style>
