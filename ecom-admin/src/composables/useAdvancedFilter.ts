/**
 * 高级筛选 Composable
 * 支持多条件组合、保存筛选、筛选历史等功能
 */

import { ref, reactive, computed, watch } from 'vue';
import { storage } from '@/utils/storage';
import { Message } from '@arco-design/web-vue';

export interface FilterCondition {
  id: string;
  field: string;
  operator: 'eq' | 'ne' | 'gt' | 'gte' | 'lt' | 'lte' | 'in' | 'not_in' | 'like' | 'not_like' | 'between' | 'is_null' | 'is_not_null';
  value: any;
  label?: string;
}

export interface AdvancedFilter {
  id?: string;
  name?: string;
  conditions: FilterCondition[];
  logic: 'and' | 'or';
  createdAt?: string;
}

export interface FilterField {
  key: string;
  label: string;
  type: 'string' | 'number' | 'date' | 'select' | 'multi-select';
  options?: { label: string; value: any }[];
}

export interface UseAdvancedFilterOptions {
  /**
   * 页面标识（用于存储）
   */
  pageId: string;
  
  /**
   * 可筛选字段配置
   */
  fields: FilterField[];
  
  /**
   * 默认筛选条件
   */
  defaultFilter?: AdvancedFilter;
  
  /**
   * 筛选变化回调
   */
  onChange?: (filter: AdvancedFilter) => void;
}

export function useAdvancedFilter(options: UseAdvancedFilterOptions) {
  const { pageId, fields, defaultFilter, onChange } = options;
  
  // 当前筛选
  const currentFilter = reactive<AdvancedFilter>(
    defaultFilter || {
      conditions: [],
      logic: 'and',
    }
  );
  
  // 保存的筛选列表
  const savedFilters = ref<AdvancedFilter[]>([]);
  
  // 筛选历史
  const filterHistory = ref<AdvancedFilter[]>([]);
  
  // 是否显示高级筛选面板
  const showAdvancedPanel = ref(false);
  
  // 是否有活动筛选
  const hasActiveFilter = computed(() => {
    return currentFilter.conditions.length > 0;
  });
  
  // 筛选条件数量
  const filterCount = computed(() => {
    return currentFilter.conditions.length;
  });
  
  /**
   * 生成唯一ID
   */
  const generateId = () => {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  };
  
  /**
   * 添加筛选条件
   */
  const addCondition = (condition?: Partial<FilterCondition>) => {
    const newCondition: FilterCondition = {
      id: generateId(),
      field: condition?.field || fields[0]?.key || '',
      operator: condition?.operator || 'eq',
      value: condition?.value || '',
      label: condition?.label,
    };
    
    currentFilter.conditions.push(newCondition);
    notifyChange();
  };
  
  /**
   * 更新筛选条件
   */
  const updateCondition = (id: string, updates: Partial<FilterCondition>) => {
    const index = currentFilter.conditions.findIndex(c => c.id === id);
    if (index !== -1) {
      Object.assign(currentFilter.conditions[index], updates);
      notifyChange();
    }
  };
  
  /**
   * 删除筛选条件
   */
  const removeCondition = (id: string) => {
    const index = currentFilter.conditions.findIndex(c => c.id === id);
    if (index !== -1) {
      currentFilter.conditions.splice(index, 1);
      notifyChange();
    }
  };
  
  /**
   * 清空筛选条件
   */
  const clearConditions = () => {
    currentFilter.conditions = [];
    notifyChange();
  };
  
  /**
   * 切换逻辑运算符
   */
  const toggleLogic = () => {
    currentFilter.logic = currentFilter.logic === 'and' ? 'or' : 'and';
    notifyChange();
  };
  
  /**
   * 保存筛选
   */
  const saveFilter = (name: string) => {
    if (!name) {
      Message.error('请输入筛选名称');
      return;
    }
    
    if (currentFilter.conditions.length === 0) {
      Message.error('请至少添加一个筛选条件');
      return;
    }
    
    const filter: AdvancedFilter = {
      id: generateId(),
      name,
      conditions: JSON.parse(JSON.stringify(currentFilter.conditions)),
      logic: currentFilter.logic,
      createdAt: new Date().toISOString(),
    };
    
    savedFilters.value.push(filter);
    storage.saveFilters(pageId, savedFilters.value);
    
    Message.success(`筛选"${name}"已保存`);
  };
  
  /**
   * 删除保存的筛选
   */
  const deleteSavedFilter = (id: string) => {
    const index = savedFilters.value.findIndex(f => f.id === id);
    if (index !== -1) {
      const filter = savedFilters.value[index];
      savedFilters.value.splice(index, 1);
      storage.saveFilters(pageId, savedFilters.value);
      Message.success(`筛选"${filter.name}"已删除`);
    }
  };
  
  /**
   * 应用保存的筛选
   */
  const applySavedFilter = (id: string) => {
    const filter = savedFilters.value.find(f => f.id === id);
    if (filter) {
      currentFilter.conditions = JSON.parse(JSON.stringify(filter.conditions));
      currentFilter.logic = filter.logic;
      notifyChange();
      Message.success(`已应用筛选"${filter.name}"`);
    }
  };
  
  /**
   * 添加到历史
   */
  const addToHistory = () => {
    if (currentFilter.conditions.length === 0) return;
    
    const historyItem: AdvancedFilter = {
      id: generateId(),
      conditions: JSON.parse(JSON.stringify(currentFilter.conditions)),
      logic: currentFilter.logic,
      createdAt: new Date().toISOString(),
    };
    
    // 避免重复
    const isDuplicate = filterHistory.value.some(h => 
      JSON.stringify(h.conditions) === JSON.stringify(historyItem.conditions) &&
      h.logic === historyItem.logic
    );
    
    if (!isDuplicate) {
      filterHistory.value.unshift(historyItem);
      
      // 限制历史记录数量
      if (filterHistory.value.length > 10) {
        filterHistory.value = filterHistory.value.slice(0, 10);
      }
      
      storage.saveFilterHistory(pageId, filterHistory.value);
    }
  };
  
  /**
   * 应用历史筛选
   */
  const applyHistoryFilter = (id: string) => {
    const filter = filterHistory.value.find(f => f.id === id);
    if (filter) {
      currentFilter.conditions = JSON.parse(JSON.stringify(filter.conditions));
      currentFilter.logic = filter.logic;
      notifyChange();
    }
  };
  
  /**
   * 清空历史
   */
  const clearHistory = () => {
    filterHistory.value = [];
    storage.saveFilterHistory(pageId, []);
    Message.success('筛选历史已清空');
  };
  
  /**
   * 构建查询参数
   */
  const buildQuery = (): Record<string, any> => {
    const query: Record<string, any> = {};
    
    if (currentFilter.conditions.length === 0) {
      return query;
    }
    
    // 简单实现：将条件转换为查询参数
    // 实际项目中可能需要更复杂的转换逻辑
    currentFilter.conditions.forEach((condition, index) => {
      const key = `filter_${index}_${condition.field}`;
      const operatorKey = `filter_${index}_operator`;
      
      query[key] = condition.value;
      query[operatorKey] = condition.operator;
    });
    
    query.filter_logic = currentFilter.logic;
    
    return query;
  };
  
  /**
   * 从查询参数恢复筛选
   */
  const restoreFromQuery = (query: Record<string, any>) => {
    const conditions: FilterCondition[] = [];
    
    // 解析查询参数
    Object.keys(query).forEach(key => {
      const match = key.match(/^filter_(\d+)_(.+)$/);
      if (match && match[2] !== 'operator') {
        const index = parseInt(match[1]);
        const field = match[2];
        const operatorKey = `filter_${index}_operator`;
        const operator = query[operatorKey] || 'eq';
        const value = query[key];
        
        conditions.push({
          id: generateId(),
          field,
          operator,
          value,
        });
      }
    });
    
    if (conditions.length > 0) {
      currentFilter.conditions = conditions;
      currentFilter.logic = query.filter_logic || 'and';
    }
  };
  
  /**
   * 获取筛选描述
   */
  const getFilterDescription = (): string => {
    if (currentFilter.conditions.length === 0) {
      return '无筛选条件';
    }
    
    const descriptions = currentFilter.conditions.map(condition => {
      const field = fields.find(f => f.key === condition.field);
      const fieldLabel = field?.label || condition.field;
      const operatorLabel = getOperatorLabel(condition.operator);
      const valueLabel = getValueLabel(condition.value, field);
      
      return `${fieldLabel} ${operatorLabel} ${valueLabel}`;
    });
    
    const logic = currentFilter.logic === 'and' ? '且' : '或';
    return descriptions.join(` ${logic} `);
  };
  
  /**
   * 获取操作符标签
   */
  const getOperatorLabel = (operator: string): string => {
    const labels: Record<string, string> = {
      eq: '等于',
      ne: '不等于',
      gt: '大于',
      gte: '大于等于',
      lt: '小于',
      lte: '小于等于',
      in: '包含',
      not_in: '不包含',
      like: '包含',
      not_like: '不包含',
      between: '介于',
      is_null: '为空',
      is_not_null: '不为空',
    };
    return labels[operator] || operator;
  };
  
  /**
   * 获取值标签
   */
  const getValueLabel = (value: any, field?: FilterField): string => {
    if (value === null || value === undefined || value === '') {
      return '空';
    }
    
    if (Array.isArray(value)) {
      return value.join(', ');
    }
    
    if (field?.type === 'select' || field?.type === 'multi-select') {
      const option = field.options?.find(o => o.value === value);
      return option?.label || String(value);
    }
    
    return String(value);
  };
  
  /**
   * 通知变化
   */
  const notifyChange = () => {
    addToHistory();
    onChange?.(currentFilter);
  };
  
  /**
   * 加载保存的筛选
   */
  const loadSavedFilters = () => {
    savedFilters.value = storage.getFilters(pageId) || [];
  };
  
  /**
   * 加载筛选历史
   */
  const loadFilterHistory = () => {
    filterHistory.value = storage.getFilterHistory(pageId) || [];
  };
  
  // 初始化
  loadSavedFilters();
  loadFilterHistory();
  
  return {
    // 状态
    currentFilter,
    savedFilters: computed(() => savedFilters.value),
    filterHistory: computed(() => filterHistory.value),
    showAdvancedPanel,
    hasActiveFilter,
    filterCount,
    
    // 方法
    addCondition,
    updateCondition,
    removeCondition,
    clearConditions,
    toggleLogic,
    saveFilter,
    deleteSavedFilter,
    applySavedFilter,
    applyHistoryFilter,
    clearHistory,
    buildQuery,
    restoreFromQuery,
    getFilterDescription,
  };
}

