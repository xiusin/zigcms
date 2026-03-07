<template>
  <div class="module-tree">
    <a-empty v-if="!treeData || treeData.length === 0" description="暂无模块数据">
      <a-button type="primary" @click="$emit('create', null)">
        创建第一个模块
      </a-button>
    </a-empty>

    <a-tree
      v-else
      :data="filteredTreeData"
      :draggable="true"
      :allow-drop="allowDrop"
      :virtual-list-props="virtualListProps"
      :expanded-keys="expandedKeys"
      :selected-keys="selectedKeys"
      block-node
      @drop="handleDrop"
      @expand="handleExpand"
      @select="handleSelect"
    >
      <template #title="nodeData">
        <div class="tree-node-title">
          <div class="node-info">
            <span class="node-name" :class="{ 'highlight': isHighlighted(nodeData) }">
              {{ nodeData.name }}
            </span>
            <a-tag v-if="nodeData.level" size="small" color="arcoblue">
              L{{ nodeData.level }}
            </a-tag>
          </div>

          <div class="node-stats">
            <a-tooltip content="测试用例数">
              <a-tag size="small">
                <template #icon><icon-file /></template>
                {{ getModuleStats(nodeData).caseCount }}
              </a-tag>
            </a-tooltip>
            
            <a-tooltip content="通过率">
              <a-tag 
                size="small" 
                :color="getPassRateColor(getModuleStats(nodeData).passRate)"
              >
                <template #icon><icon-check-circle /></template>
                {{ getModuleStats(nodeData).passRate }}%
              </a-tag>
            </a-tooltip>
          </div>

          <div class="node-actions" @click.stop>
            <a-button
              type="text"
              size="small"
              @click="$emit('create', nodeData.id)"
            >
              <template #icon><icon-plus /></template>
            </a-button>
            
            <a-button
              type="text"
              size="small"
              @click="$emit('edit', nodeData.id)"
            >
              <template #icon><icon-edit /></template>
            </a-button>
            
            <a-popconfirm
              content="确定要删除该模块吗？"
              @ok="$emit('delete', nodeData.id, hasChildren(nodeData))"
            >
              <a-button
                type="text"
                size="small"
                status="danger"
              >
                <template #icon><icon-delete /></template>
              </a-button>
            </a-popconfirm>
          </div>
        </div>
      </template>
    </a-tree>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { 
  IconPlus, 
  IconEdit, 
  IconDelete, 
  IconFile, 
  IconCheckCircle 
} from '@arco-design/web-vue/es/icon';
import type { ModuleTreeNode, MoveModuleDto } from '@/types/quality-center';
import type { TreeNodeData } from '@arco-design/web-vue';

// ==================== Props & Emits ====================

interface Props {
  treeData: ModuleTreeNode[];
  searchKeyword?: string;
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  searchKeyword: '',
  loading: false,
});

const emit = defineEmits<{
  create: [parentId: number | null];
  edit: [id: number];
  delete: [id: number, hasChildren: boolean];
  move: [id: number, dto: MoveModuleDto];
  refresh: [];
}>();

// ==================== 状态管理 ====================

const expandedKeys = ref<string[]>([]);
const selectedKeys = ref<string[]>([]);

// 虚拟列表配置（节点超过 100 个时启用）
const virtualListProps = computed(() => {
  const totalNodes = countNodes(props.treeData);
  return totalNodes > 100 ? { height: 600 } : undefined;
});

// ==================== 计算属性 ====================

/**
 * 过滤后的树数据（搜索高亮）
 */
const filteredTreeData = computed(() => {
  if (!props.searchKeyword) {
    return props.treeData;
  }
  
  return filterTree(props.treeData, props.searchKeyword);
});

// ==================== 生命周期 ====================

onMounted(() => {
  // 加载展开状态
  loadExpandedState();
});

// ==================== 监听 ====================

watch(() => props.searchKeyword, (keyword) => {
  if (keyword) {
    // 搜索时展开所有匹配节点的父节点
    expandMatchedNodes();
  }
});

// ==================== 工具函数 ====================

/**
 * 统计节点总数
 */
const countNodes = (nodes: ModuleTreeNode[]): number => {
  return nodes.reduce((count, node) => {
    return count + 1 + (node.children ? countNodes(node.children) : 0);
  }, 0);
};

/**
 * 过滤树（搜索）
 */
const filterTree = (nodes: ModuleTreeNode[], keyword: string): ModuleTreeNode[] => {
  return nodes.reduce((filtered: ModuleTreeNode[], node) => {
    const matches = node.name.toLowerCase().includes(keyword.toLowerCase());
    const children = node.children ? filterTree(node.children, keyword) : [];
    
    if (matches || children.length > 0) {
      filtered.push({
        ...node,
        children: children.length > 0 ? children : node.children,
      });
    }
    
    return filtered;
  }, []);
};

/**
 * 判断节点是否高亮
 */
const isHighlighted = (node: ModuleTreeNode): boolean => {
  if (!props.searchKeyword) return false;
  return node.name.toLowerCase().includes(props.searchKeyword.toLowerCase());
};

/**
 * 展开匹配的节点
 */
const expandMatchedNodes = () => {
  const keys: string[] = [];
  
  const collectKeys = (nodes: ModuleTreeNode[]) => {
    nodes.forEach(node => {
      if (node.name.toLowerCase().includes(props.searchKeyword.toLowerCase())) {
        keys.push(String(node.id));
        // 展开父节点
        if (node.parent_id) {
          keys.push(String(node.parent_id));
        }
      }
      if (node.children) {
        collectKeys(node.children);
      }
    });
  };
  
  collectKeys(props.treeData);
  expandedKeys.value = [...new Set(keys)];
};

/**
 * 判断节点是否有子节点
 */
const hasChildren = (node: ModuleTreeNode): boolean => {
  return !!node.children && node.children.length > 0;
};

/**
 * 获取模块统计数据
 */
const getModuleStats = (node: ModuleTreeNode) => {
  // TODO: 从后端获取实际统计数据
  return {
    caseCount: node.test_cases?.length || 0,
    passRate: 85, // 模拟数据
  };
};

/**
 * 获取通过率颜色
 */
const getPassRateColor = (rate: number): string => {
  if (rate >= 90) return 'green';
  if (rate >= 70) return 'orange';
  return 'red';
};

/**
 * 判断是否允许拖放
 */
const allowDrop = (options: {
  dropNode: TreeNodeData;
  dropPosition: number;
}): boolean => {
  const { dropNode, dropPosition } = options;
  
  // 不允许拖放到根节点之前或之后
  if (!dropNode.parent_id && dropPosition !== 0) {
    return false;
  }
  
  // 检查层级深度（最多 5 层）
  const targetLevel = dropPosition === 0 
    ? (dropNode.level || 0) + 1 
    : dropNode.level || 0;
  
  return targetLevel <= 5;
};

/**
 * 处理拖放
 */
const handleDrop = (options: {
  dragNode: TreeNodeData;
  dropNode: TreeNodeData;
  dropPosition: number;
}) => {
  const { dragNode, dropNode, dropPosition } = options;
  
  // 计算新的 parent_id 和 sort_order
  let newParentId: number | null = null;
  let newSortOrder = 0;
  
  if (dropPosition === 0) {
    // 拖放到节点内部（成为子节点）
    newParentId = dropNode.id as number;
    newSortOrder = (dropNode.children?.length || 0);
  } else {
    // 拖放到节点前后（成为兄弟节点）
    newParentId = dropNode.parent_id as number | null;
    newSortOrder = (dropNode.sort_order || 0) + (dropPosition > 0 ? 1 : 0);
  }
  
  const dto: MoveModuleDto = {
    parent_id: newParentId,
    sort_order: newSortOrder,
  };
  
  emit('move', dragNode.id as number, dto);
};

/**
 * 处理展开
 */
const handleExpand = (keys: string[]) => {
  expandedKeys.value = keys;
  saveExpandedState();
};

/**
 * 处理选择
 */
const handleSelect = (keys: string[]) => {
  selectedKeys.value = keys;
};

/**
 * 保存展开状态到 localStorage
 */
const saveExpandedState = () => {
  try {
    localStorage.setItem('module-tree-expanded', JSON.stringify(expandedKeys.value));
  } catch (error) {
    console.error('保存展开状态失败', error);
  }
};

/**
 * 加载展开状态从 localStorage
 */
const loadExpandedState = () => {
  try {
    const saved = localStorage.getItem('module-tree-expanded');
    if (saved) {
      expandedKeys.value = JSON.parse(saved);
    }
  } catch (error) {
    console.error('加载展开状态失败', error);
  }
};
</script>

<style scoped lang="less">
.module-tree {
  .tree-node-title {
    display: flex;
    align-items: center;
    justify-content: space-between;
    width: 100%;
    padding: 4px 8px;
    transition: all 0.2s;
    
    &:hover {
      background-color: var(--color-fill-2);
      border-radius: 4px;
      
      .node-actions {
        opacity: 1;
      }
    }
    
    .node-info {
      display: flex;
      align-items: center;
      gap: 8px;
      flex: 1;
      min-width: 0;
      
      .node-name {
        font-size: 14px;
        font-weight: 500;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
        
        &.highlight {
          color: var(--color-primary-6);
          font-weight: 600;
        }
      }
    }
    
    .node-stats {
      display: flex;
      align-items: center;
      gap: 8px;
      margin: 0 12px;
    }
    
    .node-actions {
      display: flex;
      align-items: center;
      gap: 4px;
      opacity: 0;
      transition: opacity 0.2s;
    }
  }
}

:deep(.arco-tree-node) {
  padding: 2px 0;
}

:deep(.arco-tree-node-drag-icon) {
  cursor: move;
}

:deep(.arco-tree-node-draggable) {
  cursor: move;
}
</style>
