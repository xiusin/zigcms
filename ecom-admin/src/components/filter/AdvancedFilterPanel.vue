<template>
  <a-drawer
    v-model:visible="visible"
    title="高级筛选"
    :width="600"
    :footer="true"
    @cancel="handleCancel"
  >
    <!-- 筛选条件列表 -->
    <div class="filter-conditions">
      <div
        v-for="(condition, index) in filter.conditions"
        :key="condition.id"
        class="condition-item"
      >
        <!-- 逻辑运算符 -->
        <div v-if="index > 0" class="logic-operator">
          <a-button
            type="text"
            size="small"
            @click="toggleLogic"
          >
            {{ filter.logic === 'and' ? '且' : '或' }}
          </a-button>
        </div>
        
        <!-- 筛选条件 -->
        <a-card class="condition-card" :bordered="false">
          <a-row :gutter="12">
            <!-- 字段选择 -->
            <a-col :span="8">
              <a-select
                v-model="condition.field"
                placeholder="选择字段"
                @change="handleFieldChange(condition)"
              >
                <a-option
                  v-for="field in fields"
                  :key="field.key"
                  :value="field.key"
                >
                  {{ field.label }}
                </a-option>
              </a-select>
            </a-col>
            
            <!-- 操作符选择 -->
            <a-col :span="7">
              <a-select
                v-model="condition.operator"
                placeholder="操作符"
              >
                <a-option
                  v-for="op in getOperators(condition.field)"
                  :key="op.value"
                  :value="op.value"
                >
                  {{ op.label }}
                </a-option>
              </a-select>
            </a-col>
            
            <!-- 值输入 -->
            <a-col :span="7">
              <component
                :is="getValueComponent(condition.field)"
                v-model="condition.value"
                :placeholder="getValuePlaceholder(condition.field)"
                v-bind="getValueProps(condition.field)"
              />
            </a-col>
            
            <!-- 删除按钮 -->
            <a-col :span="2">
              <a-button
                type="text"
                status="danger"
                @click="removeCondition(condition.id)"
              >
                <template #icon>
                  <icon-delete />
                </template>
              </a-button>
            </a-col>
          </a-row>
        </a-card>
      </div>
      
      <!-- 添加条件按钮 -->
      <a-button
        type="dashed"
        long
        class="add-condition-btn"
        @click="addCondition"
      >
        <template #icon>
          <icon-plus />
        </template>
        添加筛选条件
      </a-button>
    </div>
    
    <!-- 保存的筛选 -->
    <a-divider>保存的筛选</a-divider>
    
    <div class="saved-filters">
      <a-empty v-if="savedFilters.length === 0" description="暂无保存的筛选">
        <template #image>
          <icon-filter />
        </template>
      </a-empty>
      
      <div
        v-for="savedFilter in savedFilters"
        :key="savedFilter.id"
        class="saved-filter-item"
      >
        <div class="filter-info">
          <div class="filter-name">{{ savedFilter.name }}</div>
          <div class="filter-desc">
            {{ getFilterDescription(savedFilter) }}
          </div>
        </div>
        <a-space>
          <a-button
            type="text"
            size="small"
            @click="applySavedFilter(savedFilter.id!)"
          >
            应用
          </a-button>
          <a-popconfirm
            content="确定删除此筛选吗？"
            @ok="deleteSavedFilter(savedFilter.id!)"
          >
            <a-button type="text" size="small" status="danger">
              删除
            </a-button>
          </a-popconfirm>
        </a-space>
      </div>
    </div>
    
    <!-- 筛选历史 -->
    <a-divider>
      <span>筛选历史</span>
      <a-button
        v-if="filterHistory.length > 0"
        type="text"
        size="small"
        @click="clearHistory"
      >
        清空
      </a-button>
    </a-divider>
    
    <div class="filter-history">
      <a-empty v-if="filterHistory.length === 0" description="暂无筛选历史">
        <template #image>
          <icon-history />
        </template>
      </a-empty>
      
      <div
        v-for="historyFilter in filterHistory"
        :key="historyFilter.id"
        class="history-item"
        @click="applyHistoryFilter(historyFilter.id!)"
      >
        <div class="history-desc">
          {{ getFilterDescription(historyFilter) }}
        </div>
        <div class="history-time">
          {{ formatTime(historyFilter.createdAt!) }}
        </div>
      </div>
    </div>
    
    <!-- 底部操作 -->
    <template #footer>
      <a-space>
        <a-button @click="handleCancel">取消</a-button>
        <a-button @click="handleClear">清空</a-button>
        <a-button @click="handleSave">保存筛选</a-button>
        <a-button type="primary" @click="handleApply">应用</a-button>
      </a-space>
    </template>
    
    <!-- 保存筛选对话框 -->
    <a-modal
      v-model:visible="saveDialogVisible"
      title="保存筛选"
      @ok="handleSaveConfirm"
    >
      <a-form :model="saveForm" layout="vertical">
        <a-form-item label="筛选名称" required>
          <a-input
            v-model="saveForm.name"
            placeholder="请输入筛选名称"
            @press-enter="handleSaveConfirm"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </a-drawer>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconDelete,
  IconPlus,
  IconFilter,
  IconHistory,
} from '@arco-design/web-vue/es/icon';
import type { AdvancedFilter, FilterField } from '@/composables/useAdvancedFilter';

interface Props {
  modelValue: boolean;
  filter: AdvancedFilter;
  fields: FilterField[];
  savedFilters: AdvancedFilter[];
  filterHistory: AdvancedFilter[];
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void;
  (e: 'apply', filter: AdvancedFilter): void;
  (e: 'save', name: string): void;
  (e: 'delete-saved', id: string): void;
  (e: 'apply-saved', id: string): void;
  (e: 'apply-history', id: string): void;
  (e: 'clear-history'): void;
  (e: 'add-condition'): void;
  (e: 'remove-condition', id: string): void;
  (e: 'toggle-logic'): void;
  (e: 'clear'): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

const visible = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value),
});

// 保存对话框
const saveDialogVisible = ref(false);
const saveForm = ref({
  name: '',
});

/**
 * 获取字段配置
 */
const getField = (key: string): FilterField | undefined => {
  return props.fields.find(f => f.key === key);
};

/**
 * 获取操作符列表
 */
const getOperators = (fieldKey: string) => {
  const field = getField(fieldKey);
  
  const baseOperators = [
    { label: '等于', value: 'eq' },
    { label: '不等于', value: 'ne' },
  ];
  
  if (field?.type === 'number' || field?.type === 'date') {
    return [
      ...baseOperators,
      { label: '大于', value: 'gt' },
      { label: '大于等于', value: 'gte' },
      { label: '小于', value: 'lt' },
      { label: '小于等于', value: 'lte' },
      { label: '介于', value: 'between' },
    ];
  }
  
  if (field?.type === 'string') {
    return [
      ...baseOperators,
      { label: '包含', value: 'like' },
      { label: '不包含', value: 'not_like' },
    ];
  }
  
  if (field?.type === 'select' || field?.type === 'multi-select') {
    return [
      ...baseOperators,
      { label: '包含', value: 'in' },
      { label: '不包含', value: 'not_in' },
    ];
  }
  
  return baseOperators;
};

/**
 * 获取值输入组件
 */
const getValueComponent = (fieldKey: string) => {
  const field = getField(fieldKey);
  
  switch (field?.type) {
    case 'number':
      return 'a-input-number';
    case 'date':
      return 'a-date-picker';
    case 'select':
      return 'a-select';
    case 'multi-select':
      return 'a-select';
    default:
      return 'a-input';
  }
};

/**
 * 获取值输入占位符
 */
const getValuePlaceholder = (fieldKey: string) => {
  const field = getField(fieldKey);
  return `请输入${field?.label || '值'}`;
};

/**
 * 获取值输入属性
 */
const getValueProps = (fieldKey: string) => {
  const field = getField(fieldKey);
  
  if (field?.type === 'select') {
    return {
      options: field.options,
      placeholder: `请选择${field.label}`,
    };
  }
  
  if (field?.type === 'multi-select') {
    return {
      options: field.options,
      multiple: true,
      placeholder: `请选择${field.label}`,
    };
  }
  
  return {};
};

/**
 * 字段变化处理
 */
const handleFieldChange = (condition: any) => {
  // 重置操作符和值
  condition.operator = 'eq';
  condition.value = '';
};

/**
 * 添加条件
 */
const addCondition = () => {
  emit('add-condition');
};

/**
 * 删除条件
 */
const removeCondition = (id: string) => {
  emit('remove-condition', id);
};

/**
 * 切换逻辑
 */
const toggleLogic = () => {
  emit('toggle-logic');
};

/**
 * 应用保存的筛选
 */
const applySavedFilter = (id: string) => {
  emit('apply-saved', id);
  visible.value = false;
};

/**
 * 删除保存的筛选
 */
const deleteSavedFilter = (id: string) => {
  emit('delete-saved', id);
};

/**
 * 应用历史筛选
 */
const applyHistoryFilter = (id: string) => {
  emit('apply-history', id);
  visible.value = false;
};

/**
 * 清空历史
 */
const clearHistory = () => {
  emit('clear-history');
};

/**
 * 获取筛选描述
 */
const getFilterDescription = (filter: AdvancedFilter): string => {
  if (filter.conditions.length === 0) {
    return '无筛选条件';
  }
  
  const descriptions = filter.conditions.map(condition => {
    const field = getField(condition.field);
    const fieldLabel = field?.label || condition.field;
    const operatorLabel = getOperators(condition.field).find(
      op => op.value === condition.operator
    )?.label || condition.operator;
    const valueLabel = String(condition.value || '');
    
    return `${fieldLabel} ${operatorLabel} ${valueLabel}`;
  });
  
  const logic = filter.logic === 'and' ? '且' : '或';
  return descriptions.join(` ${logic} `);
};

/**
 * 格式化时间
 */
const formatTime = (time: string) => {
  const date = new Date(time);
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  
  if (diff < 60000) {
    return '刚刚';
  } else if (diff < 3600000) {
    return `${Math.floor(diff / 60000)}分钟前`;
  } else if (diff < 86400000) {
    return `${Math.floor(diff / 3600000)}小时前`;
  } else {
    return date.toLocaleDateString('zh-CN');
  }
};

/**
 * 取消
 */
const handleCancel = () => {
  visible.value = false;
};

/**
 * 清空
 */
const handleClear = () => {
  emit('clear');
};

/**
 * 保存
 */
const handleSave = () => {
  if (props.filter.conditions.length === 0) {
    Message.error('请至少添加一个筛选条件');
    return;
  }
  
  saveForm.value.name = '';
  saveDialogVisible.value = true;
};

/**
 * 保存确认
 */
const handleSaveConfirm = () => {
  if (!saveForm.value.name) {
    Message.error('请输入筛选名称');
    return;
  }
  
  emit('save', saveForm.value.name);
  saveDialogVisible.value = false;
};

/**
 * 应用
 */
const handleApply = () => {
  emit('apply', props.filter);
  visible.value = false;
};
</script>

<style scoped lang="less">
.filter-conditions {
  .condition-item {
    margin-bottom: 12px;
    
    .logic-operator {
      text-align: center;
      margin-bottom: 8px;
      
      .arco-btn {
        color: var(--color-text-2);
        font-weight: 600;
      }
    }
    
    .condition-card {
      background: var(--color-fill-2);
    }
  }
  
  .add-condition-btn {
    margin-top: 12px;
  }
}

.saved-filters,
.filter-history {
  .saved-filter-item,
  .history-item {
    padding: 12px;
    margin-bottom: 8px;
    background: var(--color-fill-2);
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;
    
    &:hover {
      background: var(--color-fill-3);
    }
  }
  
  .saved-filter-item {
    display: flex;
    justify-content: space-between;
    align-items: center;
    
    .filter-info {
      flex: 1;
      
      .filter-name {
        font-weight: 600;
        margin-bottom: 4px;
      }
      
      .filter-desc {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }
  }
  
  .history-item {
    .history-desc {
      font-size: 14px;
      margin-bottom: 4px;
    }
    
    .history-time {
      font-size: 12px;
      color: var(--color-text-3);
    }
  }
}
</style>

