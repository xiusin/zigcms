/**
 * AI智能分析通用组件
 * 【功能】可在任意模块中调用，支持多种分析类型、实时进度、建议操作
 * 【高级特性】流式输出模拟、风险评分仪表盘、建议一键执行、历史记录
 */
<template>
  <div class="ai-analysis-panel">
    <!-- 触发按钮（外部可通过 slot 自定义） -->
    <slot name="trigger" :open="openPanel" :loading="store.loading.aiAnalysis">
      <a-button type="primary" status="warning" @click="openPanel" :loading="store.loading.aiAnalysis">
        <template #icon><icon-robot /></template>
        AI 分析
      </a-button>
    </slot>

    <!-- 分析面板 Drawer -->
    <a-drawer
      v-model:visible="visible"
      :title="drawerTitle"
      :width="720"
      unmount-on-close
      @close="handleClose"
    >
      <!-- 未分析：选择分析类型 -->
      <div v-if="!result && !store.loading.aiAnalysis" class="analysis-start">
        <div class="type-selector">
          <div class="section-label">选择分析类型</div>
          <a-radio-group v-model="analysisType" direction="vertical">
            <a-radio v-for="opt in typeOptions" :key="opt.value" :value="opt.value">
              <div class="type-option">
                <component :is="opt.icon" :style="{ fontSize: '16px', color: opt.color }" />
                <div>
                  <div class="type-title">{{ opt.label }}</div>
                  <div class="type-desc">{{ opt.desc }}</div>
                </div>
              </div>
            </a-radio>
          </a-radio-group>
        </div>

        <!-- 自定义问题输入 -->
        <div v-if="analysisType === 'custom'" class="custom-question">
          <div class="section-label">输入分析问题</div>
          <a-textarea v-model="customQuestion" placeholder="请描述您想分析的问题..." :max-length="500" show-word-limit :auto-size="{ minRows: 3 }" />
        </div>

        <a-button type="primary" long size="large" @click="startAnalysis" :loading="store.loading.aiAnalysis" style="margin-top: 16px">
          <template #icon><icon-thunderbolt /></template>
          开始分析
        </a-button>

        <!-- 历史记录 -->
        <div v-if="store.aiAnalysisHistory.length" class="history-section">
          <div class="section-label">分析历史</div>
          <a-list :data="store.aiAnalysisHistory.slice(0, 5)" size="small">
            <template #item="{ item }">
              <a-list-item class="history-item" @click="loadHistoryResult(item)">
                <a-list-item-meta :title="item.summary?.slice(0, 60) + '...'" :description="item.created_at" />
                <template #actions>
                  <a-tag v-if="item.risk_score !== undefined" :color="riskColor(item.risk_score)" size="small">
                    风险: {{ item.risk_score }}
                  </a-tag>
                </template>
              </a-list-item>
            </template>
          </a-list>
        </div>
      </div>

      <!-- 分析中：进度动画 -->
      <div v-if="store.loading.aiAnalysis" class="analysis-loading">
        <div class="loading-animation">
          <icon-robot style="font-size: 48px; color: #165DFF; animation: pulse 1.5s infinite" />
        </div>
        <div class="loading-text">{{ loadingText }}</div>
        <a-progress :percent="loadingProgress" :stroke-width="8" animation style="margin-top: 16px" />
        <div class="loading-steps">
          <a-timeline>
            <a-timeline-item v-for="(step, i) in loadingSteps" :key="i" :dot-color="i <= currentStep ? '#165DFF' : '#C9CDD4'">
              <span :style="{ color: i <= currentStep ? '#1D2129' : '#C9CDD4' }">{{ step }}</span>
            </a-timeline-item>
          </a-timeline>
        </div>
      </div>

      <!-- 分析结果 -->
      <div v-if="result && !store.loading.aiAnalysis" class="analysis-result">
        <!-- 风险评分卡片 -->
        <div v-if="result.risk_score !== undefined" class="risk-card">
          <div class="risk-score-ring">
            <a-progress type="circle" :percent="result.risk_score" :stroke-width="8" :color="riskColor(result.risk_score)" :size="100">
              <template #text>
                <div class="risk-value">{{ result.risk_score }}</div>
                <div class="risk-label">{{ riskLabel(result.risk_score) }}</div>
              </template>
            </a-progress>
          </div>
          <div class="risk-meta">
            <a-tag :color="riskColor(result.risk_score)" size="small">{{ riskLabel(result.risk_score) }}</a-tag>
            <span class="risk-time">耗时 {{ ((result.duration_ms || 0) / 1000).toFixed(1) }}s</span>
          </div>
        </div>

        <!-- 摘要 -->
        <a-card class="summary-card" :bordered="false">
          <template #title>
            <a-space><icon-bulb style="color: #FF7D00" /><span>分析摘要</span></a-space>
          </template>
          <div class="summary-text">{{ result.summary }}</div>
        </a-card>

        <!-- 详细分析 -->
        <a-card v-if="result.details.length" class="details-card" :bordered="false">
          <template #title>
            <a-space><icon-file-text style="color: #165DFF" /><span>详细分析</span></a-space>
          </template>
          <a-collapse :default-active-key="[0]" :bordered="false">
            <a-collapse-item v-for="(detail, i) in result.details" :key="i" :header="detail.title">
              <div class="detail-content">{{ detail.content }}</div>
            </a-collapse-item>
          </a-collapse>
        </a-card>

        <!-- 建议列表 -->
        <a-card v-if="result.suggestions.length" class="suggestions-card" :bordered="false">
          <template #title>
            <a-space><icon-star style="color: #00B42A" /><span>改进建议 ({{ result.suggestions.length }})</span></a-space>
          </template>
          <div class="suggestion-list">
            <div v-for="s in result.suggestions" :key="s.id" class="suggestion-item" :class="`priority-${s.priority}`">
              <div class="suggestion-header">
                <a-tag :color="priorityColor(s.priority)" size="small">{{ priorityLabel(s.priority) }}</a-tag>
                <span class="suggestion-title">{{ s.title }}</span>
              </div>
              <div class="suggestion-desc">{{ s.description }}</div>
              <a-button
                v-if="s.action_type === 'navigate' && s.action_url"
                size="mini"
                type="text"
                @click="handleSuggestionAction(s)"
              >
                <template #icon><icon-right /></template>
                前往处理
              </a-button>
            </div>
          </div>
        </a-card>

        <!-- 操作栏 -->
        <div class="result-actions">
          <a-space>
            <a-button @click="resetPanel">
              <template #icon><icon-redo /></template>
              重新分析
            </a-button>
          </a-space>
        </div>
      </div>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import type { AIAnalysisResponse, AIAnalysisSuggestion, AIAnalysisRequest } from '@/types/quality-center';

const props = withDefaults(defineProps<{
  /** 默认分析类型 */
  defaultType?: AIAnalysisRequest['type'];
  /** 分析上下文数据 */
  context?: Record<string, unknown>;
  /** 关联模块名 */
  module?: string;
}>(), {
  defaultType: 'quality_overview',
  context: () => ({}),
  module: '',
});

const emit = defineEmits<{
  (e: 'analyzed', result: AIAnalysisResponse): void;
}>();

const store = useQualityCenterStore();
const router = useRouter();

const visible = ref(false);
const analysisType = ref<AIAnalysisRequest['type']>(props.defaultType);
const customQuestion = ref('');
const result = ref<AIAnalysisResponse | null>(null);

// 加载进度模拟
const loadingProgress = ref(0);
const currentStep = ref(0);
const loadingText = ref('正在初始化AI分析引擎...');
const loadingSteps = ['收集项目质量数据', '构建分析模型', '执行深度分析', '生成改进建议', '汇总分析报告'];
let progressTimer: ReturnType<typeof setInterval> | null = null;

const drawerTitle = ref('AI 智能分析');

const typeOptions = [
  { value: 'quality_overview', label: '整体质量分析', desc: '综合评估项目质量状况，生成全面质量报告', icon: 'icon-dashboard', color: '#165DFF' },
  { value: 'bug_analysis', label: 'Bug深度分析', desc: '分析Bug分布、趋势和根因，定位高风险模块', icon: 'icon-bug', color: '#F53F3F' },
  { value: 'feedback_analysis', label: '反馈趋势分析', desc: '分析用户反馈趋势，识别高频问题', icon: 'icon-message', color: '#FF7D00' },
  { value: 'trend_prediction', label: '质量趋势预测', desc: '基于历史数据预测未来质量走势', icon: 'icon-line-chart', color: '#722ED1' },
  { value: 'risk_assessment', label: '风险评估', desc: '评估当前项目风险等级，提供风控建议', icon: 'icon-exclamation-circle', color: '#F53F3F' },
  { value: 'custom', label: '自定义分析', desc: '输入自定义问题，AI为您深度解答', icon: 'icon-edit', color: '#0FC6C2' },
];

function openPanel() {
  visible.value = true;
  if (!store.aiAnalysisHistory.length) {
    store.fetchAIAnalysisHistory();
  }
}

function handleClose() {
  stopProgress();
}

function resetPanel() {
  result.value = null;
  loadingProgress.value = 0;
  currentStep.value = 0;
}

async function startAnalysis() {
  if (analysisType.value === 'custom' && !customQuestion.value.trim()) {
    Message.warning('请输入分析问题');
    return;
  }

  startProgress();
  try {
    const res = await store.runAIAnalysis({
      type: analysisType.value,
      context: props.context,
      question: analysisType.value === 'custom' ? customQuestion.value : undefined,
      module: props.module || undefined,
    });
    result.value = res;
    emit('analyzed', res);
    Message.success('AI分析完成');
    console.log(`[AI分析][完成][${analysisType.value}][风险评分:${res.risk_score}]`);
  } catch {
    Message.error('AI分析失败，请重试');
  } finally {
    stopProgress();
    loadingProgress.value = 100;
  }
}

function loadHistoryResult(item: AIAnalysisResponse) {
  result.value = item;
}

function handleSuggestionAction(s: AIAnalysisSuggestion) {
  if (s.action_url) {
    router.push(s.action_url);
    visible.value = false;
    console.log(`[AI分析][建议执行][${s.title}][${s.action_url}]`);
  }
}

// ========== 进度模拟 ==========
function startProgress() {
  loadingProgress.value = 0;
  currentStep.value = 0;
  loadingText.value = '正在初始化AI分析引擎...';

  const texts = ['正在收集项目质量数据...', '正在构建分析模型...', '正在执行深度分析...', '正在生成改进建议...', '正在汇总分析报告...'];
  let tick = 0;
  progressTimer = setInterval(() => {
    tick++;
    const progress = Math.min(tick * 3, 95);
    loadingProgress.value = progress;
    const stepIdx = Math.floor(progress / 20);
    if (stepIdx < texts.length) {
      currentStep.value = stepIdx;
      loadingText.value = texts[stepIdx];
    }
  }, 200);
}

function stopProgress() {
  if (progressTimer) {
    clearInterval(progressTimer);
    progressTimer = null;
  }
}

// ========== 工具函数 ==========
function riskColor(score: number): string {
  if (score >= 70) return '#F53F3F';
  if (score >= 40) return '#FF7D00';
  return '#00B42A';
}
function riskLabel(score: number): string {
  if (score >= 70) return '高风险';
  if (score >= 40) return '中风险';
  return '低风险';
}
function priorityColor(p: string): string {
  const map: Record<string, string> = { high: 'red', medium: 'orange', low: 'green' };
  return map[p] || 'gray';
}
function priorityLabel(p: string): string {
  const map: Record<string, string> = { high: '高', medium: '中', low: '低' };
  return map[p] || p;
}

watch(() => props.defaultType, (v) => { analysisType.value = v; });

onMounted(() => {
  console.log('[AI分析面板][已挂载]');
});
</script>

<style lang="less" scoped>
.ai-analysis-panel {
  display: inline-flex;
}

.analysis-start {
  .section-label {
    font-size: 14px;
    font-weight: 600;
    color: var(--color-text-1);
    margin-bottom: 12px;
    margin-top: 16px;
    &:first-child { margin-top: 0; }
  }
  .type-option {
    display: flex;
    align-items: flex-start;
    gap: 10px;
    .type-title { font-weight: 500; color: var(--color-text-1); }
    .type-desc { font-size: 12px; color: var(--color-text-3); margin-top: 2px; }
  }
  .history-section { margin-top: 24px; }
  .history-item { cursor: pointer; &:hover { background: var(--color-fill-2); } }
}

.analysis-loading {
  text-align: center;
  padding: 40px 20px;
  .loading-animation { margin-bottom: 16px; }
  .loading-text { font-size: 14px; color: var(--color-text-2); margin-bottom: 8px; }
  .loading-steps { margin-top: 24px; text-align: left; padding: 0 40px; }
}

.analysis-result {
  .risk-card {
    display: flex;
    align-items: center;
    gap: 20px;
    padding: 20px;
    background: var(--color-fill-1);
    border-radius: 8px;
    margin-bottom: 16px;
    .risk-value { font-size: 28px; font-weight: bold; line-height: 1; }
    .risk-label { font-size: 12px; color: var(--color-text-3); }
    .risk-meta { display: flex; flex-direction: column; gap: 8px; }
    .risk-time { font-size: 12px; color: var(--color-text-3); }
  }

  .summary-card, .details-card, .suggestions-card {
    margin-bottom: 12px;
    border-radius: 8px;
    background: var(--color-bg-2);
  }
  .summary-text { line-height: 1.8; color: var(--color-text-2); font-size: 14px; }
  .detail-content { line-height: 1.8; color: var(--color-text-2); font-size: 13px; }

  .suggestion-list {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .suggestion-item {
    padding: 12px;
    border-radius: 6px;
    border: 1px solid var(--color-border);
    &.priority-high { border-left: 3px solid #F53F3F; }
    &.priority-medium { border-left: 3px solid #FF7D00; }
    &.priority-low { border-left: 3px solid #00B42A; }
    .suggestion-header { display: flex; align-items: center; gap: 8px; margin-bottom: 6px; }
    .suggestion-title { font-weight: 500; color: var(--color-text-1); }
    .suggestion-desc { font-size: 13px; color: var(--color-text-3); line-height: 1.6; margin-bottom: 4px; }
  }

  .result-actions {
    margin-top: 20px;
    padding-top: 16px;
    border-top: 1px solid var(--color-border);
  }
}

@keyframes pulse {
  0%, 100% { transform: scale(1); opacity: 1; }
  50% { transform: scale(1.1); opacity: 0.7; }
}
</style>
