<template>
  <transition name="slide-up">
    <div v-if="selectedIds.length > 0" class="enhanced-batch-bar">
      <div class="batch-bar-content">
        <!-- 选中信息 -->
        <div class="selection-info">
          <a-checkbox
            :model-value="isAllSelected"
            :indeterminate="isIndeterminate"
            @change="handleSelectAll"
          >
            <span class="selection-text">
              已选择 <strong>{{ selectedIds.length }}</strong> 项
              <span v-if="total > 0" class="total-text">/ 共 {{ total }} 项</span>
            </span>
          </a-checkbox>
          
          <a-button type="text" size="small" @click="handleClear">
            清空选择
          </a-button>
        </div>
        
        <!-- 批量操作按钮 -->
        <div class="batch-actions">
          <a-space :size="12">
            <!-- 标记已读 -->
            <a-button
              v-if="actions.includes('mark_read')"
              type="outline"
              size="small"
              @click="handleAction('mark_read')"
            >
              <template #icon><icon-check /></template>
              标记已读
            </a-button>
            
            <!-- 分配处理人 -->
            <a-button
              v-if="actions.includes('assign')"
              type="outline"
              size="small"
              @click="handleAction('assign')"
            >
              <template #icon><icon-user /></template>
              分配处理人
            </a-button>
            
            <!-- 修改状态 -->
            <a-button
              v-if="actions.includes('update_status')"
              type="outline"
              size="small"
              @click="handleAction('update_status')"
            >
              <template #icon><icon-edit /></template>
              修改状态
            </a-button>
            
            <!-- 添加标签 -->
            <a-button
              v-if="actions.includes('add_tag')"
              type="outline"
              size="small"
              @click="handleAction('add_tag')"
            >
              <template #icon><icon-tag /></template>
              添加标签
            </a-button>
            
            <!-- 导出 -->
            <a-button
              v-if="actions.includes('export')"
              type="outline"
              size="small"
              @click="handleAction('export')"
            >
              <template #icon><icon-download /></template>
              导出
            </a-button>
            
            <!-- 更多操作 -->
            <a-dropdown v-if="moreActions.length > 0" trigger="click">
              <a-button type="outline" size="small">
                更多
                <icon-down />
              </a-button>
              <template #content>
                <a-doption
                  v-for="action in moreActions"
                  :key="action.key"
                  @click="handleAction(action.key)"
                >
                  <template #icon>
                    <component :is="action.icon" />
                  </template>
                  {{ action.label }}
                </a-doption>
              </template>
            </a-dropdown>
            
            <!-- 删除 -->
            <a-button
              v-if="actions.includes('delete')"
              type="outline"
              size="small"
              status="danger"
              @click="handleAction('delete')"
            >
              <template #icon><icon-delete /></template>
              删除
            </a-button>
          </a-space>
        </div>
      </div>
      
      <!-- 操作进度 -->
      <transition name="fade">
        <div v-if="processing" class="batch-progress">
          <a-progress
            :percent="progress"
            :status="progressStatus"
            :show-text="true"
          />
          <span class="progress-text">
            {{ progressText }}
          </span>
        </div>
      </transition>
    </div>
  </transition>
  
  <!-- 分配处理人对话框 -->
  <a-modal
    v-model:visible="assignDialogVisible"
    title="批量分配处理人"
    @ok="handleAssignConfirm"
    @cancel="assignDialogVisible = false"
  >
    <a-form :model="assignForm" layout="vertical">
      <a-form-item label="处理人" required>
        <a-select
          v-model="assignForm.assignee"
          placeholder="请选择处理人"
          allow-search
        >
          <a-option
            v-for="user in users"
            :key="user.id"
            :value="user.id"
          >
            {{ user.name }}
          </a-option>
        </a-select>
      </a-form-item>
      <a-form-item label="备注">
        <a-textarea
          v-model="assignForm.remark"
          placeholder="请输入备注（可选）"
          :max-length="200"
          show-word-limit
        />
      </a-form-item>
    </a-form>
  </a-modal>
  
  <!-- 修改状态对话框 -->
  <a-modal
    v-model:visible="statusDialogVisible"
    title="批量修改状态"
    @ok="handleStatusConfirm"
    @cancel="statusDialogVisible = false"
  >
    <a-form :model="statusForm" layout="vertical">
      <a-form-item label="状态" required>
        <a-select
          v-model="statusForm.status"
          placeholder="请选择状态"
        >
          <a-option
            v-for="status in statusOptions"
            :key="status.value"
            :value="status.value"
          >
            {{ status.label }}
          </a-option>
        </a-select>
      </a-form-item>
      <a-form-item label="备注">
        <a-textarea
          v-model="statusForm.remark"
          placeholder="请输入备注（可选）"
          :max-length="200"
          show-word-limit
        />
      </a-form-item>
    </a-form>
  </a-modal>
  
  <!-- 添加标签对话框 -->
  <a-modal
    v-model:visible="tagDialogVisible"
    title="批量添加标签"
    @ok="handleTagConfirm"
    @cancel="tagDialogVisible = false"
  >
    <a-form :model="tagForm" layout="vertical">
      <a-form-item label="标签" required>
        <a-select
          v-model="tagForm.tags"
          placeholder="请选择标签"
          multiple
          allow-create
        >
          <a-option
            v-for="tag in availableTags"
            :key="tag"
            :value="tag"
          >
            {{ tag }}
          </a-option>
        </a-select>
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import {
  IconCheck,
  IconUser,
  IconEdit,
  IconTag,
  IconDownload,
  IconDelete,
  IconDown,
} from '@arco-design/web-vue/es/icon';
import { withFeedback } from '@/utils/feedback';

interface Props {
  selectedIds: number[];
  total?: number;
  actions?: string[];
  moreActions?: Array<{
    key: string;
    label: string;
    icon: any;
  }>;
  users?: Array<{ id: number; name: string }>;
  statusOptions?: Array<{ value: string; label: string }>;
  availableTags?: string[];
}

interface Emits {
  (e: 'clear'): void;
  (e: 'select-all'): void;
  (e: 'action', action: string, data?: any): void;
  (e: 'success'): void;
}

const props = withDefaults(defineProps<Props>(), {
  total: 0,
  actions: () => ['mark_read', 'assign', 'update_status', 'add_tag', 'export', 'delete'],
  moreActions: () => [],
  users: () => [],
  statusOptions: () => [],
  availableTags: () => [],
});

const emit = defineEmits<Emits>();

// 选择状态
const isAllSelected = computed(() => {
  return props.total > 0 && props.selectedIds.length === props.total;
});

const isIndeterminate = computed(() => {
  return props.selectedIds.length > 0 && props.selectedIds.length < props.total;
});

// 操作进度
const processing = ref(false);
const progress = ref(0);
const progressStatus = ref<'normal' | 'success' | 'danger'>('normal');
const progressText = ref('');

// 分配处理人
const assignDialogVisible = ref(false);
const assignForm = ref({
  assignee: undefined as number | undefined,
  remark: '',
});

// 修改状态
const statusDialogVisible = ref(false);
const statusForm = ref({
  status: '',
  remark: '',
});

// 添加标签
const tagDialogVisible = ref(false);
const tagForm = ref({
  tags: [] as string[],
});

/**
 * 全选/取消全选
 */
const handleSelectAll = (checked: boolean) => {
  if (checked) {
    emit('select-all');
  } else {
    emit('clear');
  }
};

/**
 * 清空选择
 */
const handleClear = () => {
  emit('clear');
};

/**
 * 处理批量操作
 */
const handleAction = async (action: string) => {
  switch (action) {
    case 'mark_read':
      await handleMarkRead();
      break;
    case 'assign':
      handleAssign();
      break;
    case 'update_status':
      handleUpdateStatus();
      break;
    case 'add_tag':
      handleAddTag();
      break;
    case 'export':
      await handleExport();
      break;
    case 'delete':
      await handleDelete();
      break;
    default:
      emit('action', action);
  }
};

/**
 * 批量标记已读
 */
const handleMarkRead = async () => {
  const confirmed = await Modal.confirm({
    title: '确认操作',
    content: `确定要将选中的 ${props.selectedIds.length} 项标记为已读吗？`,
  });
  
  if (!confirmed) return;
  
  await executeBatchOperation(
    'mark_read',
    '标记已读',
    async (id, index, total) => {
      // 模拟API调用
      await new Promise(resolve => setTimeout(resolve, 100));
      return { success: true };
    }
  );
};

/**
 * 批量分配处理人
 */
const handleAssign = () => {
  assignForm.value = {
    assignee: undefined,
    remark: '',
  };
  assignDialogVisible.value = true;
};

const handleAssignConfirm = async () => {
  if (!assignForm.value.assignee) {
    Message.error('请选择处理人');
    return;
  }
  
  assignDialogVisible.value = false;
  
  await executeBatchOperation(
    'assign',
    '分配处理人',
    async (id, index, total) => {
      // 模拟API调用
      await new Promise(resolve => setTimeout(resolve, 100));
      return { success: true };
    }
  );
};

/**
 * 批量修改状态
 */
const handleUpdateStatus = () => {
  statusForm.value = {
    status: '',
    remark: '',
  };
  statusDialogVisible.value = true;
};

const handleStatusConfirm = async () => {
  if (!statusForm.value.status) {
    Message.error('请选择状态');
    return;
  }
  
  statusDialogVisible.value = false;
  
  await executeBatchOperation(
    'update_status',
    '修改状态',
    async (id, index, total) => {
      // 模拟API调用
      await new Promise(resolve => setTimeout(resolve, 100));
      return { success: true };
    }
  );
};

/**
 * 批量添加标签
 */
const handleAddTag = () => {
  tagForm.value = {
    tags: [],
  };
  tagDialogVisible.value = true;
};

const handleTagConfirm = async () => {
  if (tagForm.value.tags.length === 0) {
    Message.error('请选择标签');
    return;
  }
  
  tagDialogVisible.value = false;
  
  await executeBatchOperation(
    'add_tag',
    '添加标签',
    async (id, index, total) => {
      // 模拟API调用
      await new Promise(resolve => setTimeout(resolve, 100));
      return { success: true };
    }
  );
};

/**
 * 批量导出
 */
const handleExport = async () => {
  await withFeedback(
    async () => {
      // 模拟导出
      await new Promise(resolve => setTimeout(resolve, 1000));
      
      // 触发下载
      const blob = new Blob(['导出数据'], { type: 'text/csv' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `export_${Date.now()}.csv`;
      a.click();
      URL.revokeObjectURL(url);
    },
    {
      loadingText: '导出中...',
      successText: '导出成功',
      errorText: '导出失败',
    }
  );
};

/**
 * 批量删除
 */
const handleDelete = async () => {
  const confirmed = await Modal.confirm({
    title: '确认删除',
    content: `确定要删除选中的 ${props.selectedIds.length} 项吗？此操作不可恢复。`,
    okText: '确定删除',
    okButtonProps: { status: 'danger' },
  });
  
  if (!confirmed) return;
  
  await executeBatchOperation(
    'delete',
    '删除',
    async (id, index, total) => {
      // 模拟API调用
      await new Promise(resolve => setTimeout(resolve, 100));
      return { success: true };
    }
  );
};

/**
 * 执行批量操作
 */
const executeBatchOperation = async (
  action: string,
  actionName: string,
  handler: (id: number, index: number, total: number) => Promise<{ success: boolean; error?: string }>
) => {
  processing.value = true;
  progress.value = 0;
  progressStatus.value = 'normal';
  
  const total = props.selectedIds.length;
  let successCount = 0;
  let failCount = 0;
  const errors: string[] = [];
  
  try {
    for (let i = 0; i < total; i++) {
      const id = props.selectedIds[i];
      progressText.value = `正在${actionName}... (${i + 1}/${total})`;
      
      try {
        const result = await handler(id, i, total);
        if (result.success) {
          successCount++;
        } else {
          failCount++;
          if (result.error) {
            errors.push(`ID ${id}: ${result.error}`);
          }
        }
      } catch (error: any) {
        failCount++;
        errors.push(`ID ${id}: ${error.message || '操作失败'}`);
      }
      
      progress.value = Math.round(((i + 1) / total) * 100);
    }
    
    // 显示结果
    if (failCount === 0) {
      progressStatus.value = 'success';
      progressText.value = `${actionName}成功！`;
      Message.success(`成功${actionName} ${successCount} 项`);
    } else if (successCount === 0) {
      progressStatus.value = 'danger';
      progressText.value = `${actionName}失败！`;
      Message.error(`${actionName}失败 ${failCount} 项`);
    } else {
      progressStatus.value = 'normal';
      progressText.value = `${actionName}完成！`;
      Message.warning(`成功 ${successCount} 项，失败 ${failCount} 项`);
    }
    
    // 显示错误详情
    if (errors.length > 0 && errors.length <= 5) {
      Modal.error({
        title: '操作失败详情',
        content: errors.join('\n'),
      });
    }
    
    // 延迟隐藏进度条
    setTimeout(() => {
      processing.value = false;
      emit('success');
    }, 2000);
    
  } catch (error: any) {
    progressStatus.value = 'danger';
    progressText.value = '操作失败！';
    Message.error(error.message || '批量操作失败');
    
    setTimeout(() => {
      processing.value = false;
    }, 2000);
  }
};
</script>

<style scoped lang="less">
.enhanced-batch-bar {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  background: var(--color-bg-2);
  border-top: 1px solid var(--color-border-2);
  box-shadow: 0 -2px 8px rgba(0, 0, 0, 0.1);
  z-index: 100;
  
  .batch-bar-content {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 16px 24px;
    max-width: 1600px;
    margin: 0 auto;
    
    .selection-info {
      display: flex;
      align-items: center;
      gap: 16px;
      
      .selection-text {
        font-size: 14px;
        
        strong {
          color: var(--color-primary-6);
          font-size: 16px;
        }
        
        .total-text {
          color: var(--color-text-3);
          margin-left: 4px;
        }
      }
    }
    
    .batch-actions {
      flex: 1;
      display: flex;
      justify-content: flex-end;
    }
  }
  
  .batch-progress {
    padding: 12px 24px;
    background: var(--color-fill-2);
    border-top: 1px solid var(--color-border-2);
    
    .arco-progress {
      margin-bottom: 8px;
    }
    
    .progress-text {
      font-size: 12px;
      color: var(--color-text-2);
    }
  }
}

// 动画
.slide-up-enter-active,
.slide-up-leave-active {
  transition: transform 0.3s ease;
}

.slide-up-enter-from,
.slide-up-leave-to {
  transform: translateY(100%);
}

.fade-enter-active,
.fade-leave-active {
  transition: opacity 0.3s ease;
}

.fade-enter-from,
.fade-leave-to {
  opacity: 0;
}
</style>

