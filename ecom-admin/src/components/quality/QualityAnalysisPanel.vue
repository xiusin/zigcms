<template>
  <div class="quality-analysis-panel">
    <!-- 质量评分卡片 -->
    <a-card title="质量评分" :bordered="false" class="score-card">
      <template #extra>
        <a-button type="text" size="small" @click="handleRefresh">
          <template #icon>
            <icon-refresh />
          </template>
          刷新
        </a-button>
      </template>

      <div v-if="qualityScore" class="score-content">
        <!-- 总分展示 -->
        <div class="score-main">
          <div class="score-circle">
            <a-progress
              type="circle"
              :percent="qualityScore.score"
              :width="120"
              :stroke-width="8"
              :color="getScoreLevelColor(qualityScore.level)"
            >
              <template #text>
                <div class="score-text">
                  <div class="score-value">{{ qualityScore.score.toFixed(1) }}</div>
                  <div class="score-label">{{ getScoreLevelText(qualityScore.level) }}</div>
                </div>
              </template>
            </a-progress>
          </div>

          <!-- 趋势指示 -->
          <div class="score-trend">
            <a-tag :color="getTrendColor(qualityScore.trend)">
              <template #icon>
                <icon-arrow-up v-if="qualityScore.trend === 'improving'" />
                <icon-arrow-down v-if="qualityScore.trend === 'declining'" />
                <icon-minus v-if="qualityScore.trend === 'stable'" />
              </template>
              {{ getTrendText(qualityScore.trend) }}
            </a-tag>
          </div>
        </div>

        <!-- 评分因子 -->
        <div class="score-factors">
          <div
            v-for="factor in qualityScore.factors"
            :key="factor.name"
            class="factor-item"
          >
            <div class="factor-header">
              <span class="factor-name">{{ factor.name }}</span>
              <span class="factor-score">{{ factor.score.toFixed(1) }}</span>
            </div>
            <a-progress
              :percent="factor.score"
              :stroke-width="6"
              :color="factor.impact === 'positive' ? '#00b42a' : '#f53f3f'"
              :show-text="false"
            />
            <div class="factor-description">{{ factor.description }}</div>
          </div>
        </div>

        <!-- 改进建议 -->
        <div class="suggestions">
          <div class="suggestions-title">
            <icon-bulb />
            改进建议
          </div>
          <a-list :data="qualityScore.suggestions" size="small">
            <template #item="{ item, index }">
              <a-list-item>
                <span class="suggestion-index">{{ index + 1 }}.</span>
                {{ item }}
              </a-list-item>
            </template>
          </a-list>
        </div>
      </div>

      <a-empty v-else description="暂无数据" />
    </a-card>

    <!-- 趋势预测 -->
    <a-card v-if="predictions.length > 0" title="趋势预测" :bordered="false" class="prediction-card">
      <a-tabs>
        <a-tab-pane
          v-for="prediction in predictions"
          :key="prediction.metric"
          :title="prediction.metric"
        >
          <div class="prediction-content">
            <!-- 预测信息 -->
            <div class="prediction-info">
              <a-descriptions :column="2" size="small">
                <a-descriptions-item label="当前值">
                  {{ prediction.current.toFixed(2) }}
                </a-descriptions-item>
                <a-descriptions-item label="预测趋势">
                  <a-tag :color="getTrendColor(prediction.trend)">
                    <template #icon>
                      <icon-arrow-up v-if="prediction.trend === 'up'" />
                      <icon-arrow-down v-if="prediction.trend === 'down'" />
                      <icon-minus v-if="prediction.trend === 'stable'" />
                    </template>
                    {{ getTrendText(prediction.trend) }}
                  </a-tag>
                </a-descriptions-item>
                <a-descriptions-item label="置信度">
                  <a-progress
                    :percent="prediction.confidence"
                    :stroke-width="6"
                    size="small"
                  />
                </a-descriptions-item>
              </a-descriptions>
            </div>

            <!-- 预测图表 -->
            <InteractiveChart
              :config="buildPredictionChart(prediction)"
              :height="'300px'"
              :export-formats="['png', 'csv']"
            />
          </div>
        </a-tab-pane>
      </a-tabs>
    </a-card>

    <!-- 异常检测 -->
    <a-card v-if="anomalies.length > 0" title="异常检测" :bordered="false" class="anomaly-card">
      <a-list :data="anomalies" :pagination="{ pageSize: 5 }">
        <template #item="{ item }">
          <a-list-item>
            <a-list-item-meta>
              <template #avatar>
                <a-badge :status="getAnomalySeverityStatus(item.severity)" />
              </template>
              <template #title>
                <a-space>
                  <span>{{ item.description }}</span>
                  <a-tag :color="getAnomalyTypeColor(item.type)">
                    {{ getAnomalyTypeText(item.type) }}
                  </a-tag>
                  <a-tag :color="getAnomalySeverityColor(item.severity)">
                    {{ getAnomalySeverityText(item.severity) }}
                  </a-tag>
                </a-space>
              </template>
              <template #description>
                <div class="anomaly-details">
                  <div>
                    <span class="label">指标:</span>
                    <span>{{ item.metric }}</span>
                  </div>
                  <div>
                    <span class="label">实际值:</span>
                    <span>{{ item.value.toFixed(2) }}</span>
                  </div>
                  <div>
                    <span class="label">预期值:</span>
                    <span>{{ item.expected.toFixed(2) }}</span>
                  </div>
                  <div>
                    <span class="label">偏差:</span>
                    <span>{{ item.deviation.toFixed(1) }}%</span>
                  </div>
                  <div>
                    <span class="label">时间:</span>
                    <span>{{ formatTime(item.timestamp) }}</span>
                  </div>
                </div>

                <!-- 可能原因 -->
                <div class="anomaly-causes">
                  <div class="causes-title">可能原因:</div>
                  <ul>
                    <li v-for="(cause, index) in item.possibleCauses" :key="index">
                      {{ cause }}
                    </li>
                  </ul>
                </div>

                <!-- 建议措施 -->
                <div class="anomaly-recommendations">
                  <div class="recommendations-title">建议措施:</div>
                  <ul>
                    <li v-for="(rec, index) in item.recommendations" :key="index">
                      {{ rec }}
                    </li>
                  </ul>
                </div>
              </template>
            </a-list-item-meta>
          </a-list-item>
        </template>
      </a-list>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import {
  IconRefresh,
  IconArrowUp,
  IconArrowDown,
  IconMinus,
  IconBulb,
} from '@arco-design/web-vue/es/icon';
import { useQualityAnalysis, type QualityMetrics, type TrendPrediction } from '@/composables/useQualityAnalysis';
import InteractiveChart from '@/components/chart/InteractiveChart.vue';
import type { ChartConfig } from '@/composables/useInteractiveChart';

interface Props {
  metrics?: QualityMetrics;
  autoRefresh?: boolean;
  refreshInterval?: number;
}

const props = withDefaults(defineProps<Props>(), {
  autoRefresh: false,
  refreshInterval: 60000,
});

const emit = defineEmits<{
  refresh: [];
}>();

const {
  loading,
  qualityScore,
  predictions,
  anomalies,
  calculateQualityScore,
  predictTrend,
  detectAnomalies,
} = useQualityAnalysis();

// 刷新数据
const handleRefresh = () => {
  if (props.metrics) {
    calculateQualityScore(props.metrics);
  }
  emit('refresh');
};

// 获取评分等级颜色
const getScoreLevelColor = (level: string) => {
  const colors: Record<string, string> = {
    excellent: '#00b42a',
    good: '#00d0b6',
    fair: '#ff7d00',
    poor: '#f53f3f',
  };
  return colors[level] || '#165dff';
};

// 获取评分等级文本
const getScoreLevelText = (level: string) => {
  const texts: Record<string, string> = {
    excellent: '优秀',
    good: '良好',
    fair: '一般',
    poor: '较差',
  };
  return texts[level] || level;
};

// 获取趋势颜色
const getTrendColor = (trend: string) => {
  const colors: Record<string, string> = {
    improving: 'green',
    up: 'green',
    stable: 'blue',
    declining: 'red',
    down: 'red',
  };
  return colors[trend] || 'gray';
};

// 获取趋势文本
const getTrendText = (trend: string) => {
  const texts: Record<string, string> = {
    improving: '改善中',
    up: '上升',
    stable: '稳定',
    declining: '下降中',
    down: '下降',
  };
  return texts[trend] || trend;
};

// 获取异常类型颜色
const getAnomalyTypeColor = (type: string) => {
  const colors: Record<string, string> = {
    spike: 'red',
    drop: 'orange',
    outlier: 'gold',
    pattern_break: 'purple',
  };
  return colors[type] || 'blue';
};

// 获取异常类型文本
const getAnomalyTypeText = (type: string) => {
  const texts: Record<string, string> = {
    spike: '异常升高',
    drop: '异常降低',
    outlier: '离群点',
    pattern_break: '模式中断',
  };
  return texts[type] || type;
};

// 获取异常严重程度颜色
const getAnomalySeverityColor = (severity: string) => {
  const colors: Record<string, string> = {
    low: 'green',
    medium: 'orange',
    high: 'red',
    critical: 'red',
  };
  return colors[severity] || 'blue';
};

// 获取异常严重程度文本
const getAnomalySeverityText = (severity: string) => {
  const texts: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '严重',
  };
  return texts[severity] || severity;
};

// 获取异常严重程度状态
const getAnomalySeverityStatus = (severity: string) => {
  const statuses: Record<string, any> = {
    low: 'success',
    medium: 'warning',
    high: 'danger',
    critical: 'danger',
  };
  return statuses[severity] || 'normal';
};

// 构建预测图表配置
const buildPredictionChart = (prediction: TrendPrediction): ChartConfig => {
  return {
    type: 'line',
    title: `${prediction.metric} 趋势预测`,
    xAxis: {
      type: 'category',
      data: prediction.dates,
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '预测值',
        type: 'line',
        data: prediction.predicted,
        smooth: true,
        lineStyle: {
          type: 'dashed',
        },
        areaStyle: {
          opacity: 0.3,
        },
      },
    ],
  };
};

// 格式化时间
const formatTime = (time: string) => {
  return new Date(time).toLocaleString('zh-CN');
};

onMounted(() => {
  if (props.metrics) {
    calculateQualityScore(props.metrics);
  }

  // 自动刷新
  if (props.autoRefresh) {
    setInterval(handleRefresh, props.refreshInterval);
  }
});
</script>

<style scoped lang="less">
.quality-analysis-panel {
  .score-card,
  .prediction-card,
  .anomaly-card {
    margin-bottom: 16px;
  }

  .score-content {
    .score-main {
      display: flex;
      align-items: center;
      justify-content: center;
      flex-direction: column;
      padding: 24px 0;

      .score-circle {
        .score-text {
          text-align: center;

          .score-value {
            font-size: 32px;
            font-weight: 600;
            line-height: 1;
          }

          .score-label {
            font-size: 14px;
            color: var(--color-text-3);
            margin-top: 4px;
          }
        }
      }

      .score-trend {
        margin-top: 16px;
      }
    }

    .score-factors {
      margin-top: 24px;

      .factor-item {
        margin-bottom: 16px;

        .factor-header {
          display: flex;
          justify-content: space-between;
          margin-bottom: 8px;

          .factor-name {
            font-weight: 500;
          }

          .factor-score {
            color: var(--color-text-2);
          }
        }

        .factor-description {
          font-size: 12px;
          color: var(--color-text-3);
          margin-top: 4px;
        }
      }
    }

    .suggestions {
      margin-top: 24px;
      padding-top: 24px;
      border-top: 1px solid var(--color-border-2);

      .suggestions-title {
        display: flex;
        align-items: center;
        gap: 8px;
        font-weight: 500;
        margin-bottom: 12px;
      }

      .suggestion-index {
        color: var(--color-text-3);
        margin-right: 8px;
      }
    }
  }

  .prediction-content {
    .prediction-info {
      margin-bottom: 16px;
    }
  }

  .anomaly-details {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
    margin-top: 8px;
    font-size: 12px;

    .label {
      color: var(--color-text-3);
      margin-right: 4px;
    }
  }

  .anomaly-causes,
  .anomaly-recommendations {
    margin-top: 12px;
    font-size: 12px;

    .causes-title,
    .recommendations-title {
      font-weight: 500;
      margin-bottom: 4px;
    }

    ul {
      margin: 0;
      padding-left: 20px;

      li {
        margin-bottom: 4px;
        color: var(--color-text-2);
      }
    }
  }
}
</style>
