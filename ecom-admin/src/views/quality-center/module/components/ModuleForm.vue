<template>
  <a-form
    ref="formRef"
    :model="formData"
    :rules="formRules"
    layout="vertical"
    auto-label-width
  >
    <a-form-item label="模块名称" field="name" required>
      <a-input
        v-model="formData.name"
        placeholder="请输入模块名称"
        :max-length="100"
        show-word-limit
      />
    </a-form-item>

    <a-form-item label="父模块" field="parent_id">
      <a-tree-select
        v-model="formData.parent_id"
        :data="parentOptions"
        placeholder="选择父模块（不选则为根模块）"
        :disabled="mode === 'edit'"
        allow-clear
        :field-names="{
          key: 'id',
          title: 'name',
          children: 'children',
        }"
      />
      <template #extra>
        <span v-if="currentLevel > 0" class="level-hint">
          当前层级: L{{ currentLevel }}
          <a-tag v-if="currentLevel >= 5" color="red" size="small">
            已达最大层级
          </a-tag>
        </span>
      </template>
    </a-form-item>

    <a-form-item label="模块描述" field="description">
      <a-textarea
        v-model="formData.description"
        placeholder="请输入模块描述"
        :max-length="500"
        :auto-size="{ minRows: 3, maxRows: 6 }"
        show-word-limit
      />
    </a-form-item>
  </a-form>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import type { FormInstance } from '@arco-design/web-vue';
import type { Module, ModuleTreeNode } from '@/types/quality-center';

// ==================== Props ====================

interface Props {
  mode: 'create' | 'edit';
  projectId: number | null;
  parentId?: number | null;
  moduleData?: Module | null;
  treeData: ModuleTreeNode[];
}

const props = withDefaults(defineProps<Props>(), {
  parentId: null,
  moduleData: null,
});

// ==================== 状态管理 ====================

const formRef = ref<FormInstance>();

const formData = ref({
  name: '',
  parent_id: props.parentId,
  description: '',
});

// ==================== 计算属性 ====================

/**
 * 父模块选项（排除当前模块及其子模块）
 */
const parentOptions = computed(() => {
  if (props.mode === 'create') {
    // 创建模式：过滤掉层级 >= 5 的节点
    return filterByLevel(props.treeData, 5);
  } else {
    // 编辑模式：排除当前模块及其子模块
    return filterExcludeSelf(props.treeData, props.moduleData?.id);
  }
});

/**
 * 当前层级
 */
const currentLevel = computed(() => {
  if (!formData.value.parent_id) return 1;
  
  const parent = findNodeById(props.treeData, formData.value.parent_id);
  return parent ? (parent.level || 0) + 1 : 1;
});

// ==================== 表单验证规则 ====================

const formRules = computed(() => ({
  name: [
    { required: true, message: '请输入模块名称' },
    { minLength: 2, message: '模块名称至少 2 个字符' },
    { maxLength: 100, message: '模块名称最多 100 个字符' },
    {
      validator: (value: string, callback: (error?: string) => void) => {
        // 验证名称唯一性（同一父模块下）
        if (isDuplicateName(value, formData.value.parent_id)) {
          callback('该父模块下已存在同名模块');
        } else {
          callback();
        }
      },
    },
  ],
  parent_id: [
    {
      validator: (value: number | null, callback: (error?: string) => void) => {
        // 验证层级深度限制
        if (value) {
          const parent = findNodeById(props.treeData, value);
          const level = parent ? (parent.level || 0) + 1 : 1;
          if (level > 5) {
            callback('模块层级不能超过 5 层');
          } else {
            callback();
          }
        } else {
          callback();
        }
      },
    },
  ],
}));

// ==================== 生命周期 ====================

onMounted(() => {
  if (props.mode === 'edit' && props.moduleData) {
    formData.value = {
      name: props.moduleData.name,
      parent_id: props.moduleData.parent_id || null,
      description: props.moduleData.description || '',
    };
  }
});

// ==================== 监听 ====================

watch(() => props.parentId, (newVal) => {
  if (props.mode === 'create') {
    formData.value.parent_id = newVal;
  }
});

// ==================== 工具函数 ====================

/**
 * 查找节点
 */
const findNodeById = (nodes: ModuleTreeNode[], id: number): ModuleTreeNode | null => {
  for (const node of nodes) {
    if (node.id === id) return node;
    if (node.children) {
      const found = findNodeById(node.children, id);
      if (found) return found;
    }
  }
  return null;
};

/**
 * 过滤掉层级 >= maxLevel 的节点
 */
const filterByLevel = (nodes: ModuleTreeNode[], maxLevel: number): ModuleTreeNode[] => {
  return nodes.reduce((filtered: ModuleTreeNode[], node) => {
    if ((node.level || 0) < maxLevel) {
      const children = node.children ? filterByLevel(node.children, maxLevel) : [];
      filtered.push({
        ...node,
        children: children.length > 0 ? children : undefined,
      });
    }
    return filtered;
  }, []);
};

/**
 * 排除当前模块及其子模块
 */
const filterExcludeSelf = (nodes: ModuleTreeNode[], excludeId?: number): ModuleTreeNode[] => {
  if (!excludeId) return nodes;
  
  return nodes.reduce((filtered: ModuleTreeNode[], node) => {
    if (node.id !== excludeId) {
      const children = node.children ? filterExcludeSelf(node.children, excludeId) : [];
      filtered.push({
        ...node,
        children: children.length > 0 ? children : undefined,
      });
    }
    return filtered;
  }, []);
};

/**
 * 检查名称是否重复
 */
const isDuplicateName = (name: string, parentId: number | null): boolean => {
  if (props.mode === 'edit' && name === props.moduleData?.name) {
    return false; // 编辑模式下，名称未改变
  }
  
  const siblings = parentId 
    ? findNodeById(props.treeData, parentId)?.children || []
    : props.treeData;
  
  return siblings.some(node => 
    node.name === name && node.id !== props.moduleData?.id
  );
};

// ==================== 公开方法 ====================

/**
 * 验证表单
 */
const validate = async (): Promise<boolean> => {
  try {
    const errors = await formRef.value?.validate();
    return !errors;
  } catch (error) {
    return false;
  }
};

/**
 * 获取表单数据
 */
const getFormData = () => {
  return formData.value;
};

/**
 * 重置表单
 */
const resetForm = () => {
  formRef.value?.resetFields();
};

defineExpose({
  validate,
  getFormData,
  resetForm,
});
</script>

<style scoped lang="less">
.level-hint {
  font-size: 12px;
  color: var(--color-text-3);
  
  .arco-tag {
    margin-left: 8px;
  }
}
</style>
