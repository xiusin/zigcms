<template>
  <div class="alert-relation-panel">
    <!-- 加载状态 -->
    <a-spin v-if="loading" :loading="true" tip="分析中...">
      <div class="loading-placeholder"></div>
    </a-spin>
    
    <!-- 关联分析结果 -->
    <template v-else>
      <!-- 攻击模式识别 -->
      <div v-if="patterns.length > 0" class="section">
        <div class="section-header">
          <icon-fire class="section-icon" />
          <h3>攻击模式识别</h3>
          <a-tag color="red">{{ patterns.length }} 个模式</a-tag>
        </div>
        
        <div class="patterns-list">
          <a-card
            v-for="pattern in patterns"
            :key="pattern.id"
            class="pattern-card"
            :class="`severity-${pattern.severity}`"
            hoverable
          >
            <div class="pattern-header">
              <div class="pattern-info">
                <h4>{{ pattern.name }}</h4>
                <p class="pattern-desc">{{ pattern.description }}</p>
              </div>
              <div class="pattern-meta">
                <a-tag :color="getSeverityColor(pattern.severity)">
                  {{ getSeverityText(pattern.severity) }}
                </a-tag>
                <a-tag color="blue">
                  置信度 {{ pattern.confidence }}%
                </a-tag>
              </div>
            </div>
            
            <a-divider />
            
            <div class="pattern-details">
              <!-- 指标 -->
              <div class="detail-section">
                <h5>攻击指标</h5>
                <a-space wrap>
                  <a-tag
                    v-for="(indicator, index) in pattern.indicators"
                    :key="index"
                    color="orange"
                  >
                    {{ indicator }}
                  </a-tag>
                </a-space>
              </div>
              
              <!-- 缓解措施 -->
              <div class="detail-section">
                <h5>缓解措施</h5>
                <ul class="mitigation-list">
                  <li v-for="(item, index) in pattern.mitigation" :key="index">
                    {{ item }}
                  </li>
                </ul>
              </div>
              
              <!-- 相关告警 -->
              <div class="detail-section">
                <a-button
                  type="text"
                  size="small"
                  @click="showPatternAlerts(pattern)"
                >
                  查看相关告警 ({{ pattern.alerts.length }})
                  <icon-right />
                </a-button>
              </div>
            </div>
          </a-card>
        </div>
      </div>
      
      <!-- 关联告警 -->
      <div v-if="relations.length > 0" class="section">
        <div class="section-header">
          <icon-link class="section-icon" />
          <h3>关联告警</h3>
          <a-tag color="blue">{{ relations.length }} 个关联</a-tag>
        </div>
        
        <div class="relations-list">
          <a-card
            v-for="relation in relations"
            :key="relation.type"
            class="relation-card"
            hoverable
          >
            <div class="relation-header">
              <div class="relation-info">
                <component :is="getRelationIcon(relation.type)" class="relation-type-icon" />
                <div>
                  <h4>{{ getRelationTitle(relation.type) }}</h4>
                  <p class="relation-desc">{{ relation.description }}</p>
                </div>
              </div>
              <div class="relation-meta">
                <a-tag :color="getSeverityColor(relation.severity)">
                  {{ getSeverityText(relation.severity) }}
                </a-tag>
                <a-tag :color="getTrendColor(relation.trend)">
                  <icon-arrow-up v-if="relation.trend === 'up'" />
                  <icon-arrow-down v-if="relation.trend === 'down'" />
                  <icon-minus v-if="relation.trend === 'stable'" />
                  {{ getTrendText(relation.trend) }}
                </a-tag>
              </div>
            </div>
            
            <a-divider />
            
            <div class="relation-details">
              <div class="detail-row">
                <span class="label">告警数量：</span>
                <span class="value">{{ relation.count }} 条</span>
              </div>
              
              <div v-if="relation.recommendation" class="detail-row">
                <span class="label">建议：</span>
                <span class="value recommendation">{{ relation.recommendation }}</span>
              </div>
              
              <div class="detail-row">
                <a-button
                  type="text"
                  size="small"
                  @click="showRelationAlerts(relation)"
                >
                  查看详情
                  <icon-right />
                </a-button>
              </div>
            </div>
          </a-card>
        </div>
      </div>
      
      <!-- 时间序列图表 -->
      <div v-if="timeSeriesData.length > 0" class="section">
        <div class="section-header">
          <icon-line-chart class="section-icon" />
          <h3>时间序列分析</h3>
        </div>
        
        <div class="chart-container">
          <div ref="timeSeriesChart" class="chart"></div>
        </div>
      </div>
      
      <!-- 空状态 -->
      <a-empty
        v-if="patterns.length === 0 && relations.length === 0"
        description="暂无关联分析结果"
      >
        <template #image>
          <icon-info-circle />
        </template>
      </a-empty>
    </template>
    
    <!-- 告警列表抽屉 -->
    <a-drawer
      v-model:visible="alertsDrawerVisible"
      :title="alertsDrawerTitle"
      :width="800"
      :footer="false"
    >
      <a-table
        :data="selectedAlerts"
        :pagination="false"
        :scroll="{ y: 600 }"
      >
        <template #columns>
          <a-table-column title="时间" data-index="created_at" :width="180">
            <template #cell="{ record }">
              {{ formatTime(record.created_at) }}
            </template>
          </a-table-column>
          
          <a-table-column title="级别" data-index="level" :width="100">
            <template #cell="{ record }">
              <a-tag :color="getLevelColor(record.level)">
                {{ getLevelText(record.level) }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="类型" data-index="type" :width="150">
            <template #cell="{ record }">
              {{ getTypeText(record.type) }}
            </template>
          </a-table-column>
          
          <a-table-column title="消息" data-index="message" />
          
          <a-table-column title="操作" :width="100" fixed="right">
            <template #cell="{ record }">
              <a-button type="text" size="small" @click="viewAlertDetail(record)">
                详情
              </a-button>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, watch } from 'vue';
import * as echarts from 'echarts';
import {
  IconFire,
  IconLink,
  IconLineChart,
  IconInfoCircle,
  IconRight,
  IconArrowUp,
  IconArrowDown,
  IconMinus,
} from '@arco-design/web-vue/es/icon';
import { useAlertRelation } from '@/composables/useAlertRelation';
import type { Alert } from '@/types/security';
import type { AlertRelation, AttackPattern } from '@/composables/useAlertRelation';

interface Props {
  alert: Alert;
  allAlerts: Alert[];
}

interface Emits {
  (e: 'view-alert', alert: Alert): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

const {
  loading,
  relations,
  patterns,
  analyzeRelations,
  detectAttackPatterns,
  getTimeSeriesData,
} = useAlertRelation();

// 时间序列图表
const timeSeriesChart = ref<HTMLElement>();
let chartInstance: echarts.ECharts | null = null;
const timeSeriesData = ref<any[]>([]);

// 告警列表抽屉
const alertsDrawerVisible = ref(false);
const alertsDrawerTitle = ref('');
const selectedAlerts = ref<Alert[]>([]);

// 初始化
onMounted(async () => {
  await analyze();
  initChart();
});

// 监听告警变化
watch(() => props.alert, async () => {
  await analyze();
  updateChart();
});

/**
 * 执行分析
 */
const analyze = async () => {
  // 分析关联
  await analyzeRelations(props.alert, props.allAlerts);
  
  // 检测攻击模式
  await detectAttackPatterns(props.allAlerts);
  
  // 获取时间序列数据
  timeSeriesData.value = getTimeSeriesData(props.allAlerts, 3600000); // 1小时间隔
};

/**
 * 初始化图表
 */
const initChart = () => {
  if (!timeSeriesChart.value) return;
  
  chartInstance = echarts.init(timeSeriesChart.value);
  updateChart();
};

/**
 * 更新图表
 */
const updateChart = () => {
  if (!chartInstance || timeSeriesData.value.length === 0) return;
  
  const option = {
    tooltip: {
      trigger: 'axis',
      formatter: (params: any) => {
        const data = params[0];
        const time = new Date(data.axisValue).toLocaleString('zh-CN');
        return `${time}<br/>告警数量: ${data.value}`;
      },
    },
    xAxis: {
      type: 'category',
      data: timeSeriesData.value.map(d => d.timestamp),
      axisLabel: {
        formatter: (value: number) => {
          const date = new Date(value);
          return `${date.getHours()}:${String(date.getMinutes()).padStart(2, '0')}`;
        },
      },
    },
    yAxis: {
      type: 'value',
      name: '告警数量',
    },
    series: [
      {
        data: timeSeriesData.value.map(d => d.count),
        type: 'line',
        smooth: true,
        areaStyle: {
          color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
            { offset: 0, color: 'rgba(var(--primary-6), 0.3)' },
            { offset: 1, color: 'rgba(var(--primary-6), 0.05)' },
          ]),
        },
        itemStyle: {
          color: 'rgb(var(--primary-6))',
        },
      },
    ],
  };
  
  chartInstance.setOption(option);
};

/**
 * 显示模式相关告警
 */
const showPatternAlerts = (pattern: AttackPattern) => {
  alertsDrawerTitle.value = `${pattern.name} - 相关告警`;
  selectedAlerts.value = pattern.alerts;
  alertsDrawerVisible.value = true;
};

/**
 * 显示关联告警
 */
const showRelationAlerts = (relation: AlertRelation) => {
  alertsDrawerTitle.value = `${getRelationTitle(relation.type)} - 相关告警`;
  selectedAlerts.value = relation.alerts;
  alertsDrawerVisible.value = true;
};

/**
 * 查看告警详情
 */
const viewAlertDetail = (alert: Alert) => {
  emit('view-alert', alert);
  alertsDrawerVisible.value = false;
};

/**
 * 获取关联类型图标
 */
const getRelationIcon = (type: string) => {
  const icons: Record<string, any> = {
    same_ip: 'icon-computer',
    same_type: 'icon-apps',
    same_user: 'icon-user',
    time_series: 'icon-clock-circle',
  };
  return icons[type] || 'icon-link';
};

/**
 * 获取关联类型标题
 */
const getRelationTitle = (type: string): string => {
  const titles: Record<string, string> = {
    same_ip: '相同IP告警',
    same_type: '相同类型告警',
    same_user: '相同用户告警',
    time_series: '时间序列告警',
  };
  return titles[type] || type;
};

/**
 * 获取严重程度颜色
 */
const getSeverityColor = (severity: string): string => {
  const colors: Record<string, string> = {
    low: 'green',
    medium: 'orange',
    high: 'red',
    critical: 'red',
  };
  return colors[severity] || 'blue';
};

/**
 * 获取严重程度文本
 */
const getSeverityText = (severity: string): string => {
  const texts: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '严重',
  };
  return texts[severity] || severity;
};

/**
 * 获取趋势颜色
 */
const getTrendColor = (trend: string): string => {
  const colors: Record<string, string> = {
    up: 'red',
    down: 'green',
    stable: 'blue',
  };
  return colors[trend] || 'blue';
};

/**
 * 获取趋势文本
 */
const getTrendText = (trend: string): string => {
  const texts: Record<string, string> = {
    up: '上升',
    down: '下降',
    stable: '稳定',
  };
  return texts[trend] || trend;
};

/**
 * 获取级别颜色
 */
const getLevelColor = (level: string): string => {
  const colors: Record<string, string> = {
    info: 'blue',
    warning: 'orange',
    error: 'red',
    critical: 'red',
  };
  return colors[level] || 'blue';
};

/**
 * 获取级别文本
 */
const getLevelText = (level: string): string => {
  const texts: Record<string, string> = {
    info: '信息',
    warning: '警告',
    error: '错误',
    critical: '严重',
  };
  return texts[level] || level;
};

/**
 * 获取类型文本
 */
const getTypeText = (type: string): string => {
  const texts: Record<string, string> = {
    login_failed: '登录失败',
    permission_denied: '权限拒绝',
    rate_limit_exceeded: '速率限制',
    sql_injection: 'SQL注入',
    xss: 'XSS攻击',
  };
  return texts[type] || type;
};

/**
 * 格式化时间
 */
const formatTime = (time: string): string => {
  return new Date(time).toLocaleString('zh-CN');
};
</script>

<style scoped lang="less">
.alert-relation-panel {
  .loading-placeholder {
    height: 400px;
  }
  
  .section {
    margin-bottom: 24px;
    
    .section-header {
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 16px;
      
      .section-icon {
        font-size: 20px;
        color: var(--color-primary-6);
      }
      
      h3 {
        margin: 0;
        font-size: 16px;
        font-weight: 600;
      }
    }
  }
  
  .patterns-list,
  .relations-list {
    display: grid;
    gap: 16px;
  }
  
  .pattern-card,
  .relation-card {
    .pattern-header,
    .relation-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      
      .pattern-info,
      .relation-info {
        flex: 1;
        
        h4 {
          margin: 0 0 8px 0;
          font-size: 16px;
          font-weight: 600;
        }
        
        .pattern-desc,
        .relation-desc {
          margin: 0;
          color: var(--color-text-2);
          font-size: 14px;
        }
      }
      
      .pattern-meta,
      .relation-meta {
        display: flex;
        gap: 8px;
      }
    }
    
    .pattern-details,
    .relation-details {
      .detail-section {
        margin-bottom: 16px;
        
        &:last-child {
          margin-bottom: 0;
        }
        
        h5 {
          margin: 0 0 8px 0;
          font-size: 14px;
          font-weight: 600;
          color: var(--color-text-2);
        }
        
        .mitigation-list {
          margin: 0;
          padding-left: 20px;
          
          li {
            margin-bottom: 4px;
            color: var(--color-text-2);
            font-size: 14px;
          }
        }
      }
      
      .detail-row {
        display: flex;
        align-items: center;
        margin-bottom: 8px;
        
        &:last-child {
          margin-bottom: 0;
        }
        
        .label {
          color: var(--color-text-3);
          font-size: 14px;
          margin-right: 8px;
        }
        
        .value {
          color: var(--color-text-1);
          font-size: 14px;
          
          &.recommendation {
            color: var(--color-warning-6);
            font-weight: 500;
          }
        }
      }
    }
  }
  
  .pattern-card {
    &.severity-critical {
      border-left: 4px solid var(--color-danger-6);
    }
    
    &.severity-high {
      border-left: 4px solid var(--color-warning-6);
    }
    
    &.severity-medium {
      border-left: 4px solid var(--color-primary-6);
    }
    
    &.severity-low {
      border-left: 4px solid var(--color-success-6);
    }
  }
  
  .relation-info {
    display: flex;
    align-items: flex-start;
    gap: 12px;
    
    .relation-type-icon {
      font-size: 24px;
      color: var(--color-primary-6);
      margin-top: 4px;
    }
  }
  
  .chart-container {
    .chart {
      height: 300px;
    }
  }
}
</style>

