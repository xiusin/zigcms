/**
 * 脑图节点组件
 * 【功能】显示节点信息、统计数据、展开折叠控制
 */
<template>
  <div
    class="mindmap-node"
    :class="{
      'node-root': isRoot,
      'node-collapsed': collapsed,
      'node-highlighted': highlighted,
    }"
    :style="nodeStyle"
    @click="handleClick"
    @mouseenter="handleMouseEnter"
    @mouseleave="handleMouseLeave"
  >
    <!-- 节点内容 -->
    <div class="node-content">
      <div class="node-title">{{ node.label }}</div>
      <div class="node-stats" v-if="node.stats && showStats">
        <div class="stat-item" v-for="(value, key) in node.stats" :key="key">
          <span class="stat-label">{{ key }}:</span>
          <span class="stat-value">{{ value }}</span>
        </div>
      </div>
    </div>

    <!-- 展开/折叠按钮 -->
    <div
      v-if="hasChildren"
      class="collapse-btn"
      @click.stop="handleToggleCollapse"
    >
      <icon-down v-if="!collapsed" />
      <icon-right v-else />
    </div>

    <!-- 子节点指示器 -->
    <div v-if="hasChildren && !collapsed" class="children-indicator">
      {{ node.children?.length }} 个子节点
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

// ========== Props ==========
interface MindMapNode {
  label: string;
  children?: MindMapNode[];
  color?: string;
  stats?: Record<string, string | number>;
  collapsed?: boolean;
}

interface Props {
  node: MindMapNode;
  level?: number;
  collapsed?: boolean;
  highlighted?: boolean;
  showStats?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  level: 0,
  collapsed: false,
  highlighted: false,
  showStats: true,
});

// ========== Emits ==========
const emit = defineEmits<{
  click: [node: MindMapNode];
  toggleCollapse: [node: MindMapNode];
  mouseEnter: [node: MindMapNode];
  mouseLeave: [node: MindMapNode];
}>();

// ========== 计算属性 ==========
const isRoot = computed(() => props.level === 0);

const hasChildren = computed(() => {
  return props.node.children && props.node.children.length > 0;
});

const nodeStyle = computed(() => {
  const baseColor = props.node.color || '#165DFF';
  return {
    '--node-color': baseColor,
    '--node-bg': isRoot.value ? baseColor : '#ffffff',
    '--node-text-color': isRoot.value ? '#ffffff' : baseColor,
    '--node-border-color': baseColor,
  };
});

// ========== 方法 ==========
function handleClick() {
  emit('click', props.node);
}

function handleToggleCollapse() {
  emit('toggleCollapse', props.node);
}

function handleMouseEnter() {
  emit('mouseEnter', props.node);
}

function handleMouseLeave() {
  emit('mouseLeave', props.node);
}
</script>

<style lang="less" scoped>
.mindmap-node {
  position: relative;
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 8px 16px;
  background: var(--node-bg);
  color: var(--node-text-color);
  border: 2px solid var(--node-border-color);
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
  user-select: none;

  &:hover {
    transform: translateY(-2px);
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  }

  &.node-root {
    font-size: 16px;
    font-weight: 600;
    padding: 12px 20px;
  }

  &.node-collapsed {
    opacity: 0.7;
  }

  &.node-highlighted {
    border-width: 3px;
    box-shadow: 0 0 0 3px rgba(255, 215, 0, 0.3);
    animation: pulse 1.5s ease-in-out infinite;
  }
}

.node-content {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.node-title {
  font-size: 14px;
  font-weight: 500;
  line-height: 1.4;
}

.node-stats {
  display: flex;
  flex-direction: column;
  gap: 2px;
  font-size: 11px;
  opacity: 0.8;
}

.stat-item {
  display: flex;
  gap: 4px;

  .stat-label {
    opacity: 0.7;
  }

  .stat-value {
    font-weight: 600;
  }
}

.collapse-btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 20px;
  height: 20px;
  background: var(--node-color);
  color: #ffffff;
  border-radius: 50%;
  transition: transform 0.2s;

  &:hover {
    transform: scale(1.2);
  }
}

.children-indicator {
  position: absolute;
  bottom: -20px;
  left: 50%;
  transform: translateX(-50%);
  font-size: 10px;
  color: var(--color-text-3);
  white-space: nowrap;
}

@keyframes pulse {
  0%, 100% {
    box-shadow: 0 0 0 3px rgba(255, 215, 0, 0.3);
  }
  50% {
    box-shadow: 0 0 0 6px rgba(255, 215, 0, 0.1);
  }
}
</style>
