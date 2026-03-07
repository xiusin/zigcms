/**
 * 脑图画布组件（增强版）
 * 【新增功能】节点搜索高亮、悬停提示、展开折叠动画、自定义主题
 */
<template>
  <div class="mindmap-canvas">
    <!-- 搜索栏 -->
    <div class="search-bar" v-if="searchable">
      <a-input-search
        v-model="searchKeyword"
        placeholder="搜索节点..."
        size="small"
        allow-clear
        @search="handleSearch"
        @clear="clearSearch"
      >
        <template #prefix>
          <icon-search />
        </template>
      </a-input-search>
      <a-tag v-if="searchResults.length > 0" size="small" color="arcoblue">
        找到 {{ searchResults.length }} 个节点
      </a-tag>
      <a-space v-if="searchResults.length > 0" size="mini">
        <a-button size="mini" @click="prevSearchResult">
          <icon-up />
        </a-button>
        <span class="search-index">{{ currentSearchIndex + 1 }} / {{ searchResults.length }}</span>
        <a-button size="mini" @click="nextSearchResult">
          <icon-down />
        </a-button>
      </a-space>
    </div>

    <!-- 画布容器 -->
    <div
      class="canvas-container"
      ref="containerRef"
      @wheel.prevent="handleWheel"
      @mousedown="handleMouseDown"
      @mousemove="handleMouseMove"
      @mouseup="handleMouseUp"
      @mouseleave="handleMouseUp"
    >
      <div
        class="svg-wrapper"
        :style="transformStyle"
        @click="handleNodeClick"
        @mousemove="handleNodeHover"
      >
        <div v-html="enhancedSvgContent" />
      </div>

      <!-- 节点悬停提示 -->
      <div
        v-if="hoveredNode"
        class="node-tooltip"
        :style="tooltipStyle"
      >
        <div class="tooltip-title">{{ hoveredNode.label }}</div>
        <div class="tooltip-content" v-if="hoveredNode.stats">
          <div class="stat-item" v-for="(value, key) in hoveredNode.stats" :key="key">
            <span class="stat-label">{{ key }}:</span>
            <span class="stat-value">{{ value }}</span>
          </div>
        </div>
      </div>
    </div>

    <!-- 控制面板 -->
    <div class="control-panel">
      <a-space>
        <!-- 缩放控制 -->
        <a-button-group size="mini">
          <a-button @click="zoomIn" :disabled="scale >= 3">
            <icon-zoom-in />
          </a-button>
          <a-button @click="zoomOut" :disabled="scale <= 0.3">
            <icon-zoom-out />
          </a-button>
          <a-button @click="resetView">
            <icon-fullscreen />
          </a-button>
        </a-button-group>
        <a-tag size="small">{{ Math.round(scale * 100) }}%</a-tag>

        <!-- 主题切换 -->
        <a-dropdown @select="handleThemeChange" v-if="themeable">
          <a-button size="mini">
            <icon-palette />
            主题
          </a-button>
          <template #content>
            <a-doption
              v-for="theme in themes"
              :key="theme.name"
              :value="theme.name"
            >
              <a-space>
                <div
                  class="theme-preview"
                  :style="{ background: theme.colors[0] }"
                />
                {{ theme.label }}
              </a-space>
            </a-doption>
          </template>
        </a-dropdown>

        <!-- 展开/折叠全部 -->
        <a-button-group size="mini" v-if="collapsible">
          <a-button @click="expandAll">
            <icon-expand />
            全部展开
          </a-button>
          <a-button @click="collapseAll">
            <icon-shrink />
            全部折叠
          </a-button>
        </a-button-group>
      </a-space>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick } from 'vue';
import { Message } from '@arco-design/web-vue';

// ========== Props ==========
interface MindMapNode {
  label: string;
  children?: MindMapNode[];
  color?: string;
  stats?: Record<string, string | number>;
  collapsed?: boolean;
}

interface Props {
  data: MindMapNode;
  searchable?: boolean;
  themeable?: boolean;
  collapsible?: boolean;
  initialScale?: number;
}

const props = withDefaults(defineProps<Props>(), {
  searchable: true,
  themeable: true,
  collapsible: true,
  initialScale: 1,
});

// ========== Emits ==========
const emit = defineEmits<{
  nodeClick: [node: MindMapNode];
  nodeHover: [node: MindMapNode | null];
}>();

// ========== 状态 ==========
const containerRef = ref<HTMLElement | null>(null);
const scale = ref(props.initialScale);
const translateX = ref(0);
const translateY = ref(0);
const isDragging = ref(false);
const dragStartX = ref(0);
const dragStartY = ref(0);
const lastTranslateX = ref(0);
const lastTranslateY = ref(0);

// 搜索相关
const searchKeyword = ref('');
const searchResults = ref<string[]>([]);
const currentSearchIndex = ref(0);
const highlightedNodes = ref<Set<string>>(new Set());

// 悬停相关
const hoveredNode = ref<MindMapNode | null>(null);
const tooltipX = ref(0);
const tooltipY = ref(0);

// 主题相关
const currentTheme = ref('default');
const themes = [
  {
    name: 'default',
    label: '默认',
    colors: ['#165DFF', '#00B42A', '#F53F3F', '#FF7D00', '#722ED1', '#0FC6C2', '#F7BA1E'],
  },
  {
    name: 'ocean',
    label: '海洋',
    colors: ['#0077B6', '#00B4D8', '#90E0EF', '#CAF0F8', '#023E8A', '#0096C7', '#48CAE4'],
  },
  {
    name: 'forest',
    label: '森林',
    colors: ['#2D6A4F', '#40916C', '#52B788', '#74C69D', '#95D5B2', '#B7E4C7', '#D8F3DC'],
  },
  {
    name: 'sunset',
    label: '日落',
    colors: ['#F72585', '#B5179E', '#7209B7', '#560BAD', '#480CA8', '#3A0CA3', '#3F37C9'],
  },
  {
    name: 'autumn',
    label: '秋天',
    colors: ['#D62828', '#F77F00', '#FCBF49', '#EAE2B7', '#003049', '#D62828', '#F77F00'],
  },
];

// 折叠状态
const collapsedNodes = ref<Set<string>>(new Set());

// ========== 计算属性 ==========
const transformStyle = computed(() => ({
  transform: `translate(${translateX.value}px, ${translateY.value}px) scale(${scale.value})`,
  transformOrigin: '0 0',
  cursor: isDragging.value ? 'grabbing' : 'grab',
  transition: isDragging.value ? 'none' : 'transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)',
}));

const tooltipStyle = computed(() => ({
  left: `${tooltipX.value}px`,
  top: `${tooltipY.value}px`,
}));

const enhancedSvgContent = computed(() => {
  return generateEnhancedSVG(props.data);
});

// ========== 方法 ==========

/** 生成增强版 SVG */
function generateEnhancedSVG(root: MindMapNode): string {
  const svgWidth = 1200;
  const svgHeight = 800;
  const nodeHeight = 36;
  const nodeGap = 12;
  const levelGap = 200;

  // 获取当前主题颜色
  const theme = themes.find(t => t.name === currentTheme.value) || themes[0];
  const colors = theme.colors;

  // 计算节点总数
  function countLeaves(node: MindMapNode): number {
    if (collapsedNodes.value.has(node.label)) return 1;
    if (!node.children || node.children.length === 0) return 1;
    return node.children.reduce((sum, c) => sum + countLeaves(c), 0);
  }

  // 布局计算
  interface LayoutNode {
    label: string;
    x: number;
    y: number;
    width: number;
    height: number;
    color: string;
    children: LayoutNode[];
    collapsed: boolean;
    stats?: Record<string, string | number>;
  }

  function layout(
    node: MindMapNode,
    level: number,
    startY: number,
    parentColor?: string
  ): LayoutNode {
    const isCollapsed = collapsedNodes.value.has(node.label);
    const leaves = countLeaves(node);
    const x = 40 + level * levelGap;
    const width = Math.max(80, node.label.length * 14 + 24);
    const color = node.color || parentColor || colors[level % colors.length];

    const layoutChildren: LayoutNode[] = [];
    if (!isCollapsed && node.children) {
      let childY = startY;
      for (const child of node.children) {
        const childLeaves = countLeaves(child);
        const childHeight = childLeaves * (nodeHeight + nodeGap) - nodeGap;
        layoutChildren.push(layout(child, level + 1, childY, color));
        childY += childHeight + nodeGap;
      }
    }

    const y = layoutChildren.length > 0
      ? (layoutChildren[0].y + layoutChildren[layoutChildren.length - 1].y) / 2
      : startY;

    return {
      label: node.label,
      x,
      y,
      width,
      height: nodeHeight,
      color,
      children: layoutChildren,
      collapsed: isCollapsed,
      stats: node.stats,
    };
  }

  const totalLeaves = countLeaves(root);
  const totalHeight = totalLeaves * (nodeHeight + nodeGap);
  const actualHeight = Math.max(svgHeight, totalHeight + 40);
  const layoutRoot = layout(root, 0, 20);

  // 渲染 SVG
  let paths = '';
  let nodes = '';

  function render(node: LayoutNode) {
    const rx = 8;
    const isRoot = node.x < 100;
    const isHighlighted = highlightedNodes.value.has(node.label);
    const fontSize = isRoot ? 16 : 13;
    const fontWeight = isRoot ? 'bold' : 'normal';
    const fill = isRoot ? node.color : '#ffffff';
    const textColor = isRoot ? '#ffffff' : node.color;
    const strokeColor = node.color;
    const strokeWidth = isHighlighted ? 4 : 2;
    const opacity = isHighlighted ? 1 : 0.95;

    // 高亮效果
    if (isHighlighted) {
      nodes += `<rect x="${node.x - 4}" y="${node.y - 4}" width="${node.width + 8}" height="${node.height + 8}" rx="${rx + 2}" ry="${rx + 2}" fill="none" stroke="#FFD700" stroke-width="3" opacity="0.6" />`;
    }

    // 节点矩形
    nodes += `<rect x="${node.x}" y="${node.y}" width="${node.width}" height="${node.height}" rx="${rx}" ry="${rx}" fill="${fill}" stroke="${strokeColor}" stroke-width="${strokeWidth}" opacity="${opacity}" data-label="${escapeXml(node.label)}" class="mindmap-node" />`;

    // 节点文本
    nodes += `<text x="${node.x + node.width / 2}" y="${node.y + node.height / 2 + 5}" text-anchor="middle" fill="${textColor}" font-size="${fontSize}" font-weight="${fontWeight}" font-family="Arial, sans-serif" data-label="${escapeXml(node.label)}" class="mindmap-text">${escapeXml(node.label)}</text>`;

    // 折叠/展开按钮
    if (node.children.length > 0 || node.collapsed) {
      const btnX = node.x + node.width + 4;
      const btnY = node.y + node.height / 2;
      const btnSize = 16;
      nodes += `<circle cx="${btnX}" cy="${btnY}" r="${btnSize / 2}" fill="${node.color}" stroke="#ffffff" stroke-width="2" class="collapse-btn" data-label="${escapeXml(node.label)}" />`;
      const icon = node.collapsed ? '+' : '−';
      nodes += `<text x="${btnX}" y="${btnY + 5}" text-anchor="middle" fill="#ffffff" font-size="14" font-weight="bold" class="collapse-btn" data-label="${escapeXml(node.label)}">${icon}</text>`;
    }

    // 连接线（带动画效果）
    for (const child of node.children) {
      const x1 = node.x + node.width;
      const y1 = node.y + node.height / 2;
      const x2 = child.x;
      const y2 = child.y + child.height / 2;
      const cx1 = x1 + (x2 - x1) * 0.4;
      const cx2 = x2 - (x2 - x1) * 0.4;
      paths += `<path d="M${x1},${y1} C${cx1},${y1} ${cx2},${y2} ${x2},${y2}" fill="none" stroke="${child.color}" stroke-width="2" opacity="0.6" class="mindmap-path" />`;
      render(child);
    }
  }

  render(layoutRoot);

  // 计算实际宽度
  function maxX(node: LayoutNode): number {
    let mx = node.x + node.width;
    for (const c of node.children) {
      mx = Math.max(mx, maxX(c));
    }
    return mx;
  }
  const actualWidth = Math.max(svgWidth, maxX(layoutRoot) + 40);

  return `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${actualWidth} ${actualHeight}" width="${actualWidth}" height="${actualHeight}" style="background:#ffffff">
  <defs>
    <filter id="shadow" x="-5%" y="-5%" width="110%" height="110%">
      <feDropShadow dx="2" dy="2" stdDeviation="3" flood-opacity="0.15" />
    </filter>
    <style>
      .mindmap-path {
        transition: stroke-width 0.3s, opacity 0.3s;
      }
      .mindmap-path:hover {
        stroke-width: 3;
        opacity: 0.9;
      }
      .mindmap-node, .mindmap-text {
        cursor: pointer;
        transition: all 0.3s cubic-bezier(0.4, 0, 0.2, 1);
      }
      .mindmap-node:hover {
        filter: brightness(0.95);
        transform: scale(1.02);
      }
      .collapse-btn {
        cursor: pointer;
        transition: transform 0.2s;
      }
      .collapse-btn:hover {
        transform: scale(1.2);
      }
    </style>
  </defs>
  <g filter="url(#shadow)">
    ${paths}
    ${nodes}
  </g>
</svg>`;
}

function escapeXml(str: string): string {
  return str
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&apos;');
}

/** 缩放控制 */
function zoomIn() {
  scale.value = Math.min(scale.value + 0.15, 3);
}

function zoomOut() {
  scale.value = Math.max(scale.value - 0.15, 0.3);
}

function resetView() {
  scale.value = props.initialScale;
  translateX.value = 0;
  translateY.value = 0;
}

function handleWheel(e: WheelEvent) {
  const delta = e.deltaY > 0 ? -0.08 : 0.08;
  scale.value = Math.max(0.3, Math.min(3, scale.value + delta));
}

/** 拖拽控制 */
function handleMouseDown(e: MouseEvent) {
  if (e.button !== 0) return;
  isDragging.value = true;
  dragStartX.value = e.clientX;
  dragStartY.value = e.clientY;
  lastTranslateX.value = translateX.value;
  lastTranslateY.value = translateY.value;
}

function handleMouseMove(e: MouseEvent) {
  if (!isDragging.value) return;
  translateX.value = lastTranslateX.value + (e.clientX - dragStartX.value);
  translateY.value = lastTranslateY.value + (e.clientY - dragStartY.value);
}

function handleMouseUp() {
  isDragging.value = false;
}

/** 节点点击 */
function handleNodeClick(e: MouseEvent) {
  const target = e.target as SVGElement;
  const label = target.getAttribute('data-label');
  if (!label) return;

  // 检查是否点击折叠按钮
  if (target.classList.contains('collapse-btn')) {
    toggleNodeCollapse(label);
    return;
  }

  // 查找节点数据
  const node = findNodeByLabel(props.data, label);
  if (node) {
    emit('nodeClick', node);
    Message.info(`节点: ${label}`);
  }
}

/** 节点悬停 */
function handleNodeHover(e: MouseEvent) {
  const target = e.target as SVGElement;
  const label = target.getAttribute('data-label');

  if (!label || target.classList.contains('collapse-btn')) {
    hoveredNode.value = null;
    emit('nodeHover', null);
    return;
  }

  const node = findNodeByLabel(props.data, label);
  if (node && node.stats) {
    hoveredNode.value = node;
    tooltipX.value = e.clientX + 10;
    tooltipY.value = e.clientY + 10;
    emit('nodeHover', node);
  } else {
    hoveredNode.value = null;
    emit('nodeHover', null);
  }
}

/** 查找节点 */
function findNodeByLabel(node: MindMapNode, label: string): MindMapNode | null {
  if (node.label === label) return node;
  if (node.children) {
    for (const child of node.children) {
      const found = findNodeByLabel(child, label);
      if (found) return found;
    }
  }
  return null;
}

/** 搜索功能 */
function handleSearch() {
  if (!searchKeyword.value.trim()) {
    clearSearch();
    return;
  }

  const results: string[] = [];
  function search(node: MindMapNode) {
    if (node.label.toLowerCase().includes(searchKeyword.value.toLowerCase())) {
      results.push(node.label);
    }
    if (node.children) {
      node.children.forEach(search);
    }
  }
  search(props.data);

  searchResults.value = results;
  currentSearchIndex.value = 0;

  if (results.length > 0) {
    highlightedNodes.value = new Set(results);
    Message.success(`找到 ${results.length} 个匹配节点`);
  } else {
    highlightedNodes.value.clear();
    Message.warning('未找到匹配节点');
  }
}

function clearSearch() {
  searchKeyword.value = '';
  searchResults.value = [];
  currentSearchIndex.value = 0;
  highlightedNodes.value.clear();
}

function nextSearchResult() {
  if (searchResults.value.length === 0) return;
  currentSearchIndex.value = (currentSearchIndex.value + 1) % searchResults.value.length;
  highlightedNodes.value = new Set([searchResults.value[currentSearchIndex.value]]);
}

function prevSearchResult() {
  if (searchResults.value.length === 0) return;
  currentSearchIndex.value =
    (currentSearchIndex.value - 1 + searchResults.value.length) % searchResults.value.length;
  highlightedNodes.value = new Set([searchResults.value[currentSearchIndex.value]]);
}

/** 主题切换 */
function handleThemeChange(value: string | number | Record<string, unknown> | undefined) {
  currentTheme.value = String(value);
  Message.success(`已切换到${themes.find(t => t.name === value)?.label}主题`);
}

/** 折叠/展开 */
function toggleNodeCollapse(label: string) {
  if (collapsedNodes.value.has(label)) {
    collapsedNodes.value.delete(label);
  } else {
    collapsedNodes.value.add(label);
  }
  // 触发重新渲染
  collapsedNodes.value = new Set(collapsedNodes.value);
}

function expandAll() {
  collapsedNodes.value.clear();
  Message.success('已展开所有节点');
}

function collapseAll() {
  function collectLabels(node: MindMapNode) {
    if (node.children && node.children.length > 0) {
      collapsedNodes.value.add(node.label);
      node.children.forEach(collectLabels);
    }
  }
  collectLabels(props.data);
  collapsedNodes.value = new Set(collapsedNodes.value);
  Message.success('已折叠所有节点');
}

// ========== 监听 ==========
watch(() => props.data, () => {
  clearSearch();
  collapsedNodes.value.clear();
}, { deep: true });
</script>

<style lang="less" scoped>
.mindmap-canvas {
  position: relative;
  width: 100%;
  height: 100%;
  min-height: 500px;
  background: #fafafa;
  border-radius: 8px;
  overflow: hidden;
}

.search-bar {
  position: absolute;
  top: 12px;
  left: 12px;
  z-index: 10;
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 8px 12px;
  background: var(--color-bg-2);
  border-radius: 6px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);

  :deep(.arco-input-wrapper) {
    width: 240px;
  }

  .search-index {
    font-size: 12px;
    color: var(--color-text-2);
  }
}

.canvas-container {
  width: 100%;
  height: 100%;
  overflow: hidden;
  position: relative;
  user-select: none;
}

.svg-wrapper {
  display: inline-block;
  min-width: 100%;
  min-height: 100%;

  :deep(svg) {
    max-width: none;
    height: auto;
  }
}

.node-tooltip {
  position: fixed;
  z-index: 1000;
  padding: 12px;
  background: var(--color-bg-2);
  border: 1px solid var(--color-border);
  border-radius: 6px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  pointer-events: none;
  max-width: 300px;

  .tooltip-title {
    font-size: 14px;
    font-weight: 600;
    color: var(--color-text-1);
    margin-bottom: 8px;
  }

  .tooltip-content {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }

  .stat-item {
    display: flex;
    justify-content: space-between;
    font-size: 12px;

    .stat-label {
      color: var(--color-text-3);
    }

    .stat-value {
      color: var(--color-text-1);
      font-weight: 500;
    }
  }
}

.control-panel {
  position: absolute;
  bottom: 12px;
  right: 12px;
  z-index: 10;
  padding: 8px 12px;
  background: var(--color-bg-2);
  border-radius: 6px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.1);
}

.theme-preview {
  width: 16px;
  height: 16px;
  border-radius: 3px;
  border: 1px solid var(--color-border);
}
</style>
