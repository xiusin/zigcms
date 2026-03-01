/**
 * Dashboard自定义布局配置组件
 * 【高级特性】vuedraggable真实拖拽排序、显隐控制、布局持久化到localStorage
 */
<template>
  <a-drawer
    :visible="visible"
    title="自定义Dashboard布局"
    :width="420"
    @cancel="handleClose"
  >
    <template #footer>
      <a-space>
        <a-button @click="handleReset">恢复默认</a-button>
        <a-button type="primary" @click="handleSave">保存布局</a-button>
      </a-space>
    </template>

    <div class="layout-config">
      <!-- 卡片显隐控制 -->
      <div class="config-section">
        <div class="config-title">显示控制</div>
        <div class="config-desc">勾选需要在Dashboard中显示的卡片模块</div>
        <div class="card-toggle-list">
          <div
            v-for="card in localCards"
            :key="card.key"
            class="card-toggle-item"
          >
            <a-checkbox v-model="card.visible">
              <div class="card-info">
                <span class="card-icon" :style="{ color: card.color }">
                  <component :is="card.icon" />
                </span>
                <span class="card-label">{{ card.label }}</span>
              </div>
            </a-checkbox>
          </div>
        </div>
      </div>

      <a-divider />

      <!-- 拖拽排序控制 (vuedraggable) -->
      <div class="config-section">
        <div class="config-title">
          排列顺序
          <a-tag size="small" color="arcoblue" style="margin-left: 8px">拖拽排序</a-tag>
        </div>
        <div class="config-desc">按住拖拽手柄调整卡片在Dashboard中的显示顺序</div>
        <draggable
          v-model="dragSortList"
          item-key="key"
          handle=".drag-handle"
          ghost-class="drag-ghost"
          chosen-class="drag-chosen"
          animation="200"
          @end="onDragEnd"
        >
          <template #item="{ element, index }">
            <div class="card-sort-item">
              <a-space>
                <span class="drag-handle" title="拖拽排序">
                  <icon-drag-dot-vertical />
                </span>
                <span class="sort-index">{{ index + 1 }}</span>
                <span class="card-icon-sm" :style="{ color: element.color }">
                  <component :is="element.icon" />
                </span>
                <span>{{ element.label }}</span>
              </a-space>
              <a-tag v-if="!element.visible" size="small" color="gray">已隐藏</a-tag>
            </div>
          </template>
        </draggable>
      </div>

      <a-divider />

      <!-- 统计卡片选择 -->
      <div class="config-section">
        <div class="config-title">统计卡片</div>
        <div class="config-desc">选择需要在顶部显示的统计指标</div>
        <a-checkbox-group v-model="localStatCards" direction="vertical">
          <a-checkbox
            v-for="stat in allStatCards"
            :key="stat.key"
            :value="stat.key"
          >
            <a-space>
              <component :is="stat.icon" :style="{ color: stat.color }" />
              <span>{{ stat.label }}</span>
            </a-space>
          </a-checkbox>
        </a-checkbox-group>
      </div>
    </div>
  </a-drawer>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import draggable from 'vuedraggable';

/** 卡片配置项 */
export interface DashboardCardConfig {
  key: string;
  label: string;
  icon: string;
  color: string;
  visible: boolean;
  order: number;
}

/** 统计卡片配置项 */
export interface StatCardConfig {
  key: string;
  label: string;
  icon: string;
  color: string;
}

const STORAGE_KEY = 'quality-center-dashboard-layout';

const props = defineProps<{
  visible: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:visible', val: boolean): void;
  (e: 'save', config: { cards: DashboardCardConfig[]; statCards: string[] }): void;
}>();

// ========== 默认配置 ==========
const defaultCards: DashboardCardConfig[] = [
  { key: 'ai-insights', label: 'AI质量洞察', icon: 'icon-robot', color: '#722ED1', visible: true, order: 0 },
  { key: 'trend-chart', label: '质量趋势图', icon: 'icon-line-chart', color: '#165DFF', visible: true, order: 1 },
  { key: 'module-quality', label: '模块质量分布', icon: 'icon-apps', color: '#00B42A', visible: true, order: 2 },
  { key: 'bug-distribution', label: 'Bug类型分布', icon: 'icon-bug', color: '#F53F3F', visible: true, order: 3 },
  { key: 'feedback-distribution', label: '反馈状态分布', icon: 'icon-message', color: '#FF7D00', visible: true, order: 4 },
  { key: 'activities', label: '最近活动', icon: 'icon-history', color: '#0FC6C2', visible: true, order: 5 },
  { key: 'link-records', label: '关联记录', icon: 'icon-link', color: '#F7BA1E', visible: true, order: 6 },
];

const allStatCards: StatCardConfig[] = [
  { key: 'pass_rate', label: '测试通过率', icon: 'icon-check-circle-fill', color: '#00B42A' },
  { key: 'total_tasks', label: '总测试任务', icon: 'icon-file', color: '#165DFF' },
  { key: 'active_bugs', label: '活跃Bug', icon: 'icon-bug', color: '#F53F3F' },
  { key: 'pending_feedbacks', label: '待处理反馈', icon: 'icon-message', color: '#FF7D00' },
  { key: 'ai_fix_rate', label: 'AI修复率', icon: 'icon-robot', color: '#722ED1' },
  { key: 'weekly_executions', label: '本周执行', icon: 'icon-play-circle', color: '#0FC6C2' },
  { key: 'feedback_to_task_count', label: '反馈转任务', icon: 'icon-swap', color: '#F7BA1E' },
  { key: 'avg_bug_fix_hours', label: '平均修复时长', icon: 'icon-clock-circle', color: '#86909C' },
];

const defaultStatCardKeys = allStatCards.map(s => s.key);

// ========== 状态 ==========
const localCards = ref<DashboardCardConfig[]>(loadFromStorage()?.cards || deepCopy(defaultCards));
const localStatCards = ref<string[]>(loadFromStorage()?.statCards || [...defaultStatCardKeys]);

/** 拖拽排序用的列表（按order排序） */
const dragSortList = computed({
  get: () => [...localCards.value].sort((a, b) => a.order - b.order),
  set: (newList: DashboardCardConfig[]) => {
    newList.forEach((card, idx) => {
      const target = localCards.value.find(c => c.key === card.key);
      if (target) target.order = idx;
    });
  },
});

const visibleCards = computed(() =>
  localCards.value
    .filter(c => c.visible)
    .sort((a, b) => a.order - b.order)
);

// ========== 拖拽事件 ==========
function onDragEnd() {
  console.log('[质量中心][布局配置][拖拽排序完成]');
}

// ========== 方法 ==========
function handleSave() {
  const config = {
    cards: localCards.value,
    statCards: localStatCards.value,
  };
  saveToStorage(config);
  emit('save', config);
  Message.success('布局配置已保存');
  handleClose();
  console.log('[质量中心][布局配置][保存]', config);
}

function handleReset() {
  localCards.value = deepCopy(defaultCards);
  localStatCards.value = [...defaultStatCardKeys];
  saveToStorage({ cards: localCards.value, statCards: localStatCards.value });
  emit('save', { cards: localCards.value, statCards: localStatCards.value });
  Message.success('已恢复默认布局');
}

function handleClose() {
  emit('update:visible', false);
}

// ========== 持久化 ==========
function saveToStorage(config: { cards: DashboardCardConfig[]; statCards: string[] }) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(config));
  } catch (e) {
    console.error('[质量中心][布局持久化][失败]', e);
  }
}

function loadFromStorage(): { cards: DashboardCardConfig[]; statCards: string[] } | null {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (raw) return JSON.parse(raw);
  } catch (e) {
    console.error('[质量中心][布局读取][失败]', e);
  }
  return null;
}

function deepCopy<T>(obj: T): T {
  return JSON.parse(JSON.stringify(obj));
}

// ========== 暴露方法 ==========
defineExpose({
  getConfig: () => ({
    cards: localCards.value,
    statCards: localStatCards.value,
  }),
  allStatCards,
  defaultCards,
});
</script>

<style lang="less" scoped>
.layout-config {
  .config-section {
    .config-title {
      font-size: 15px;
      font-weight: 600;
      color: var(--color-text-1);
      margin-bottom: 4px;
      display: flex;
      align-items: center;
    }
    .config-desc {
      font-size: 12px;
      color: var(--color-text-3);
      margin-bottom: 12px;
    }
  }
}

.card-toggle-list {
  .card-toggle-item {
    padding: 8px 0;
    border-bottom: 1px solid var(--color-fill-2);
    &:last-child {
      border-bottom: none;
    }
    .card-info {
      display: flex;
      align-items: center;
      gap: 8px;
      .card-icon {
        font-size: 18px;
      }
      .card-label {
        font-size: 14px;
      }
    }
  }
}

.card-sort-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 10px 12px;
  margin-bottom: 4px;
  background: var(--color-fill-1);
  border-radius: 6px;
  border: 1px solid transparent;
  transition: all 0.2s;
  cursor: default;
  user-select: none;
  &:hover {
    background: var(--color-fill-2);
    border-color: var(--color-border-2);
  }
  .drag-handle {
    cursor: grab;
    color: var(--color-text-4);
    font-size: 16px;
    display: flex;
    align-items: center;
    &:hover {
      color: var(--color-text-2);
    }
    &:active {
      cursor: grabbing;
    }
  }
  .sort-index {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: var(--color-fill-3);
    font-size: 11px;
    color: var(--color-text-2);
  }
  .card-icon-sm {
    font-size: 14px;
  }
}

// vuedraggable 拖拽样式
.drag-ghost {
  opacity: 0.4;
  background: var(--color-primary-light-1) !important;
  border: 1px dashed var(--color-primary-6) !important;
}
.drag-chosen {
  background: var(--color-fill-3) !important;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.12);
  border-radius: 6px;
}
</style>
