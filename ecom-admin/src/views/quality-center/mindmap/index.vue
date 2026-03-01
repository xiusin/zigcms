/**
 * 脑图分析页面
 * 【功能】模块质量脑图、Bug关联脑图、反馈分类脑图
 * 【高级特性】多模式切换、缩放平移手势、节点点击跳转、实时预览、SVG/PNG导出、水印控制、AI分析集成、staleTime缓存
 */
<template>
  <div class="mindmap-page">
    <!-- 顶部操作栏 -->
    <div class="page-header">
      <div class="header-left">
        <a-space>
          <icon-mind-mapping :style="{ fontSize: '20px', color: '#722ED1' }" />
          <span class="page-title">脑图分析</span>
        </a-space>
      </div>
      <div class="header-right">
        <a-space>
          <AIAnalysisPanel :default-type="aiType" :context="aiContext" module="mindmap" />
          <a-button size="small" @click="refreshData" :loading="loading">
            <template #icon><icon-refresh /></template>
            刷新数据
          </a-button>
          <a-dropdown @select="handleExport">
            <a-button size="small" type="primary">
              <template #icon><icon-download /></template>
              导出
              <icon-down />
            </a-button>
            <template #content>
              <a-doption value="svg">导出 SVG</a-doption>
              <a-doption value="png">导出 PNG</a-doption>
              <a-doption value="png-watermark">导出 PNG（含水印）</a-doption>
            </template>
          </a-dropdown>
        </a-space>
      </div>
    </div>

    <!-- 脑图模式切换 -->
    <a-card class="mode-card">
      <a-radio-group v-model="currentMode" type="button" size="large" @change="onModeChange">
        <a-radio value="quality">
          <template #radio="{ checked }">
            <div :class="['mode-item', { 'mode-active': checked }]">
              <icon-apps style="font-size: 20px" />
              <span>模块质量</span>
              <span class="mode-desc">各模块通过率/Bug/用例分布</span>
            </div>
          </template>
        </a-radio>
        <a-radio value="bug-link">
          <template #radio="{ checked }">
            <div :class="['mode-item', { 'mode-active': checked }]">
              <icon-bug style="font-size: 20px" />
              <span>Bug关联</span>
              <span class="mode-desc">Bug与用例/反馈关联关系</span>
            </div>
          </template>
        </a-radio>
        <a-radio value="feedback">
          <template #radio="{ checked }">
            <div :class="['mode-item', { 'mode-active': checked }]">
              <icon-message style="font-size: 20px" />
              <span>反馈分类</span>
              <span class="mode-desc">反馈按类型/状态分层展示</span>
            </div>
          </template>
        </a-radio>
      </a-radio-group>
    </a-card>

    <!-- 脑图预览区域（带缩放平移） -->
    <a-card class="preview-card" :loading="loading">
      <template #title>
        <a-space>
          <span>{{ modeLabel }}</span>
          <a-tag v-if="nodeCount > 0" size="small" color="arcoblue">{{ nodeCount }} 个节点</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <!-- 缩放控制按钮 -->
          <a-button-group size="mini">
            <a-button @click="zoomIn"><icon-zoom-in /></a-button>
            <a-button @click="zoomOut"><icon-zoom-out /></a-button>
            <a-button @click="resetZoom"><icon-fullscreen /></a-button>
          </a-button-group>
          <a-tag size="small" color="gray">{{ Math.round(scale * 100) }}%</a-tag>
          <a-checkbox v-model="watermarkEnabled">导出含水印</a-checkbox>
        </a-space>
      </template>
      <div
        class="mindmap-preview"
        ref="previewRef"
        @wheel.prevent="handleWheel"
        @mousedown="handleMouseDown"
        @mousemove="handleMouseMove"
        @mouseup="handleMouseUp"
        @mouseleave="handleMouseUp"
      >
        <div
          v-if="svgContent"
          class="svg-container"
          :style="transformStyle"
          @click="handleSvgClick"
        >
          <div v-html="svgContent" />
        </div>
        <a-empty v-else description="暂无数据，请先刷新数据">
          <template #image>
            <icon-mind-mapping style="font-size: 64px; color: var(--color-text-4)" />
          </template>
        </a-empty>
      </div>
      <!-- 节点点击提示 -->
      <div v-if="clickedNodeInfo" class="node-tooltip">
        <a-alert type="info" closable @close="clickedNodeInfo = ''">
          <template #title>节点: {{ clickedNodeInfo }}</template>
          点击节点可跳转到对应详情页
        </a-alert>
      </div>
    </a-card>

    <!-- 数据统计卡片 -->
    <a-row :gutter="16" class="stats-row" v-if="currentMode === 'bug-link' && store.bugLinks.length">
      <a-col :span="6" v-for="stat in bugStats" :key="stat.label">
        <a-card class="stat-mini-card">
          <a-statistic :title="stat.label" :value="stat.value" :value-style="{ color: stat.color }" />
        </a-card>
      </a-col>
    </a-row>
    <a-row :gutter="16" class="stats-row" v-if="currentMode === 'feedback' && store.feedbackClassification.length">
      <a-col :span="6" v-for="stat in feedbackStats" :key="stat.label">
        <a-card class="stat-mini-card">
          <a-statistic :title="stat.label" :value="stat.value" :value-style="{ color: stat.color }" />
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onBeforeUnmount } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import AIAnalysisPanel from '../components/AIAnalysisPanel.vue';
import {
  generateMindMapSVG,
  buildQualityMindMap,
  buildBugLinkMindMap,
  buildFeedbackMindMap,
  exportMindMapSVG,
  exportMindMapPNG,
} from '@/utils/export';

const store = useQualityCenterStore();
const router = useRouter();

// ========== 状态 ==========
const currentMode = ref<'quality' | 'bug-link' | 'feedback'>('quality');
const svgContent = ref('');
const loading = ref(false);
const watermarkEnabled = ref(true);
const previewRef = ref<HTMLElement | null>(null);
const clickedNodeInfo = ref('');

// ========== 缩放平移状态 ==========
const scale = ref(1);
const translateX = ref(0);
const translateY = ref(0);
const isDragging = ref(false);
const dragStartX = ref(0);
const dragStartY = ref(0);
const lastTranslateX = ref(0);
const lastTranslateY = ref(0);

const transformStyle = computed(() => ({
  transform: `translate(${translateX.value}px, ${translateY.value}px) scale(${scale.value})`,
  transformOrigin: '0 0',
  cursor: isDragging.value ? 'grabbing' : 'grab',
  transition: isDragging.value ? 'none' : 'transform 0.2s ease',
}));

function zoomIn() {
  scale.value = Math.min(scale.value + 0.15, 3);
  console.log(`[脑图][缩放][放大][${Math.round(scale.value * 100)}%]`);
}

function zoomOut() {
  scale.value = Math.max(scale.value - 0.15, 0.3);
  console.log(`[脑图][缩放][缩小][${Math.round(scale.value * 100)}%]`);
}

function resetZoom() {
  scale.value = 1;
  translateX.value = 0;
  translateY.value = 0;
  console.log('[脑图][缩放][重置]');
}

function handleWheel(e: WheelEvent) {
  const delta = e.deltaY > 0 ? -0.08 : 0.08;
  scale.value = Math.max(0.3, Math.min(3, scale.value + delta));
}

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

// ========== 节点点击跳转 ==========
function handleSvgClick(e: MouseEvent) {
  const target = e.target as SVGElement;
  if (target.tagName === 'text' || target.tagName === 'rect') {
    let textEl: SVGTextElement | null = null;
    if (target.tagName === 'text') {
      textEl = target as unknown as SVGTextElement;
    } else {
      const next = target.nextElementSibling;
      if (next?.tagName === 'text') textEl = next as unknown as SVGTextElement;
    }
    if (!textEl) return;
    const text = textEl.textContent || '';
    clickedNodeInfo.value = text;
    console.log(`[脑图][节点点击][${text}]`);

    // 解析并跳转
    const bugMatch = text.match(/^#(\d+)\s/);
    if (bugMatch && currentMode.value === 'bug-link') {
      router.push(`/auto-test/bug?id=${bugMatch[1]}`);
      return;
    }
    if (bugMatch && currentMode.value === 'feedback') {
      router.push(`/feedback/detail/${bugMatch[1]}`);
      return;
    }
    // 模块名点击 — 跳转到该模块的Bug列表
    if (currentMode.value === 'quality' && !text.includes(':') && !text.includes('总览')) {
      const moduleName = text.split(' ')[0];
      router.push(`/auto-test/bug?module=${encodeURIComponent(moduleName)}`);
      return;
    }
    Message.info(`节点: ${text}`);
  }
}

// ========== AI分析上下文 ==========
const aiType = computed(() => {
  const map: Record<string, 'bug_analysis' | 'feedback_analysis' | 'quality_overview'> = {
    'quality': 'quality_overview',
    'bug-link': 'bug_analysis',
    'feedback': 'feedback_analysis',
  };
  return map[currentMode.value] || 'quality_overview';
});

const aiContext = computed(() => ({
  mode: currentMode.value,
  bugCount: store.bugLinks.length,
  feedbackCount: store.feedbackClassification.length,
  moduleCount: store.moduleQuality.length,
}));

// ========== 计算属性 ==========
const modeLabel = computed(() => {
  const map: Record<string, string> = {
    'quality': '模块质量脑图',
    'bug-link': 'Bug关联脑图',
    'feedback': '反馈分类脑图',
  };
  return map[currentMode.value] || '';
});

const nodeCount = computed(() => {
  const svg = svgContent.value;
  if (!svg) return 0;
  return (svg.match(/<rect /g) || []).length;
});

const bugStats = computed(() => {
  const bugs = store.bugLinks;
  if (!bugs.length) return [];
  const totalCases = bugs.reduce((s, b) => s + b.related_cases.length, 0);
  const totalFeedbacks = bugs.reduce((s, b) => s + b.related_feedbacks.length, 0);
  const criticalCount = bugs.filter(b => b.severity === 'critical').length;
  return [
    { label: 'Bug总数', value: bugs.length, color: '#F53F3F' },
    { label: '关联用例', value: totalCases, color: '#165DFF' },
    { label: '关联反馈', value: totalFeedbacks, color: '#FF7D00' },
    { label: '严重Bug', value: criticalCount, color: '#F53F3F' },
  ];
});

const feedbackStats = computed(() => {
  const fbs = store.feedbackClassification;
  if (!fbs.length) return [];
  const pending = fbs.filter(f => f.status === 0).length;
  const processing = fbs.filter(f => f.status === 1).length;
  const resolved = fbs.filter(f => f.status === 2).length;
  return [
    { label: '反馈总数', value: fbs.length, color: '#165DFF' },
    { label: '待处理', value: pending, color: '#FF7D00' },
    { label: '处理中', value: processing, color: '#165DFF' },
    { label: '已解决', value: resolved, color: '#00B42A' },
  ];
});

// ========== 方法 ==========
function buildCurrentMindMap() {
  switch (currentMode.value) {
    case 'quality': {
      if (!store.moduleQuality.length) return;
      const tree = buildQualityMindMap(store.moduleQuality, '模块质量总览');
      svgContent.value = generateMindMapSVG(tree);
      break;
    }
    case 'bug-link': {
      if (!store.bugLinks.length) return;
      const tree = buildBugLinkMindMap(store.bugLinks, 'Bug关联分析');
      svgContent.value = generateMindMapSVG(tree);
      break;
    }
    case 'feedback': {
      if (!store.feedbackClassification.length) return;
      const tree = buildFeedbackMindMap(store.feedbackClassification, '反馈分类分析');
      svgContent.value = generateMindMapSVG(tree);
      break;
    }
  }
  resetZoom();
  console.log(`[质量中心][脑图][${currentMode.value}][渲染完成]`);
}

async function refreshData() {
  loading.value = true;
  try {
    switch (currentMode.value) {
      case 'quality':
        await store.fetchModuleQuality();
        break;
      case 'bug-link':
        await store.fetchBugLinksCached(true);
        break;
      case 'feedback':
        await store.fetchFeedbackClassificationCached(true);
        break;
    }
    buildCurrentMindMap();
    Message.success('数据已刷新');
  } catch {
    Message.error('数据加载失败');
  } finally {
    loading.value = false;
  }
}

function onModeChange() {
  svgContent.value = '';
  clickedNodeInfo.value = '';
  refreshData();
}

function getCurrentTree() {
  switch (currentMode.value) {
    case 'quality':
      return buildQualityMindMap(store.moduleQuality, '模块质量总览');
    case 'bug-link':
      return buildBugLinkMindMap(store.bugLinks, 'Bug关联分析');
    case 'feedback':
      return buildFeedbackMindMap(store.feedbackClassification, '反馈分类分析');
    default:
      return { label: '空', children: [] };
  }
}

async function handleExport(value: string | number | Record<string, unknown> | undefined) {
  const tree = getCurrentTree();
  const timestamp = new Date().toISOString().slice(0, 10);
  const filename = `${modeLabel.value}_${timestamp}`;

  try {
    if (value === 'svg') {
      exportMindMapSVG(tree, `${filename}.svg`);
      Message.success('SVG导出成功');
    } else if (value === 'png') {
      await exportMindMapPNG(tree, `${filename}.png`, false);
      Message.success('PNG导出成功');
    } else if (value === 'png-watermark') {
      await exportMindMapPNG(tree, `${filename}_水印.png`, watermarkEnabled.value ? undefined : false);
      Message.success('PNG(含水印)导出成功');
    }
    console.log(`[质量中心][脑图导出][${value}][${filename}]`);
  } catch {
    Message.error('导出失败');
  }
}

// ========== 生命周期 ==========
onMounted(async () => {
  loading.value = true;
  try {
    await Promise.allSettled([
      store.fetchModuleQuality(),
      store.fetchBugLinksCached(),
      store.fetchFeedbackClassificationCached(),
    ]);
    buildCurrentMindMap();
  } finally {
    loading.value = false;
  }
  console.log('[质量中心][脑图分析][页面加载完成]');
});

onBeforeUnmount(() => {
  isDragging.value = false;
});
</script>

<style lang="less" scoped>
.mindmap-page {
  padding: 16px;
  background: var(--color-bg-1);
  min-height: 100%;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding: 12px 16px;
  background: var(--color-bg-2);
  border-radius: 8px;
  border: 1px solid var(--color-border);
  .page-title {
    font-size: 16px;
    font-weight: 600;
    color: var(--color-text-1);
  }
}

.mode-card {
  margin-bottom: 16px;
  border-radius: 8px;
  :deep(.arco-card-body) {
    padding: 12px 16px;
  }
  :deep(.arco-radio-group) {
    width: 100%;
    display: flex;
    gap: 12px;
  }
  :deep(.arco-radio) {
    flex: 1;
    margin-right: 0;
    padding: 0;
  }
}

.mode-item {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 4px;
  padding: 16px 12px;
  border-radius: 8px;
  border: 2px solid var(--color-border);
  cursor: pointer;
  transition: all 0.2s;
  text-align: center;
  &:hover {
    border-color: var(--color-primary-light-3);
    background: var(--color-primary-light-1);
  }
  &.mode-active {
    border-color: var(--color-primary-6);
    background: var(--color-primary-light-1);
    color: var(--color-primary-6);
  }
  .mode-desc {
    font-size: 11px;
    color: var(--color-text-3);
  }
}

.preview-card {
  margin-bottom: 16px;
  border-radius: 8px;
  :deep(.arco-card-body) {
    padding: 0;
  }
}

.mindmap-preview {
  min-height: 500px;
  overflow: hidden;
  background: #fafafa;
  border-radius: 0 0 8px 8px;
  position: relative;
  user-select: none;
  .svg-container {
    padding: 16px;
    display: inline-block;
    min-width: 100%;
    :deep(svg) {
      max-width: none;
      height: auto;
    }
    :deep(text) {
      cursor: pointer;
      &:hover {
        text-decoration: underline;
        opacity: 0.8;
      }
    }
    :deep(rect) {
      cursor: pointer;
      &:hover {
        filter: brightness(0.92);
      }
    }
  }
}

.node-tooltip {
  padding: 8px 16px;
  border-top: 1px solid var(--color-border);
}

.stats-row {
  margin-top: 0;
  .stat-mini-card {
    border-radius: 8px;
    :deep(.arco-card-body) {
      padding: 12px 16px;
    }
  }
}
</style>
