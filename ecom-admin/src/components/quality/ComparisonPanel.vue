<template>
  <div class="comparison-panel">
    <!-- 对比类型选择 -->
    <div class="comparison-header">
      <a-radio-group v-model="comparisonType" type="button" @change="handleTypeChange">
        <a-radio value="time">时间对比</a-radio>
        <a-radio value="module">模块对比</a-radio>
        <a-radio value="project">项目对比</a-radio>
        <a-radio value="team">团队对比</a-radio>
      </a-radio-group>

      <a-button type="primary" @click="handleCompare">
        <template #icon>
          <icon-swap />
        </template>
        开始对比
      </a-button>
    </div>

    <!-- 对比配置 -->
    <a-card :bordered="false" class="config-card">
      <template v-if="comparisonType === 'time'">
        <a-form layout="inline">
          <a-form-item label="时间段1">
            <a-range-picker v-model="timeRange1" />
          </a-form-item>
          <a-form-item label="时间段2">
            <a-range-picker v-model="timeRange2" />
          </a-form-item>
        </a-form>
      </template>

      <template v-else-if="comparisonType === 'module'">
        <a-form layout="inline">
          <a-form-item label="选择模块">
            <a-select
              v-model="selectedModules"
              multiple
              placeholder="请选择要对比的模块"
              style="width: 400px"
              :max-tag-count="3"
            >
              <a-option
                v-for="module in modules"
                :key="module.id"
                :value="module.id"
                :label="module.name"
              />
            </a-select>
          </a-form-item>
        </a-form>
      </template>

      <template v-else-if="comparisonType === 'project'">
        <a-form layout="inline">
          <a-form-item label="选择项目">
            <a-select
              v-model="selectedProjects"
              multiple
              placeholder="请选择要对比的项目"
              style="width: 400px"
              :max-tag-count="3"
            >
              <a-option
                v-for="project in projects"
                :key="project.id"
                :value="project.id"
                :label="project.name"
              />
            </a-select>
          </a-form-item>
        </a-form>
      </template>

      <template v-else-if="comparisonType === 'team'">
        <a-form layout="inline">
          <a-form-item label="选择团队">
            <a-select
              v-model="selectedTeams"
              multiple
              placeholder="请选择要对比的团队"
              style="width: 400px"
              :max-tag-count="3"
            >
              <a-option
                v-for="team in teams"
                :key="team.id"
                :value="team.id"
                :label="team.name"
              />
            </a-select>
          </a-form-item>
        </a-form>
      </template>
    </a-card>

    <!-- 对比结果 -->
    <div v-if="comparisonResult" class="comparison-result">
      <!-- 胜者展示 -->
      <a-alert
        type="success"
        :title="`最佳表现: ${comparisonResult.winner}`"
        :closable="false"
        class="winner-alert"
      >
        <template #icon>
          <icon-trophy />
        </template>
      </a-alert>

      <!-- 洞察信息 -->
      <a-card title="数据洞察" :bordered="false" class="insights-card">
        <a-list :data="comparisonResult.insights" size="small">
          <template #item="{ item, index }">
            <a-list-item>
              <template #prefix>
                <icon-bulb />
              </template>
              {{ item }}
            </a-list-item>
          </template>
        </a-list>
      </a-card>

      <!-- 对比表格 -->
      <a-card title="详细对比" :bordered="false" class="table-card">
        <a-table
          :data="comparisonResult.items"
          :pagination="false"
          :bordered="{ cell: true }"
        >
          <template #columns>
            <a-table-column title="排名" data-index="rank" :width="80" align="center">
              <template #cell="{ record }">
                <a-tag v-if="record.rank === 1" color="gold">
                  <template #icon>
                    <icon-trophy />
                  </template>
                  {{ record.rank }}
                </a-tag>
                <a-tag v-else-if="record.rank === 2" color="silver">
                  {{ record.rank }}
                </a-tag>
                <a-tag v-else-if="record.rank === 3" color="orange">
                  {{ record.rank }}
                </a-tag>
                <span v-else>{{ record.rank }}</span>
              </template>
            </a-table-column>

            <a-table-column title="名称" data-index="name" :width="150" />

            <a-table-column
              v-for="(value, key) in comparisonResult.items[0]?.metrics"
              :key="key"
              :title="getMetricName(key)"
              :data-index="`metrics.${key}`"
            >
              <template #cell="{ record }">
                <div class="metric-cell">
                  <span>{{ record.metrics[key].toFixed(2) }}</span>
                  <a-progress
                    :percent="record.metrics[key]"
                    :stroke-width="4"
                    :show-text="false"
                    size="small"
                  />
                </div>
              </template>
            </a-table-column>

            <a-table-column title="综合得分" data-index="score" :width="120" align="center">
              <template #cell="{ record }">
                <a-tag :color="getScoreColor(record.score)">
                  {{ record.score.toFixed(1) }}
                </a-tag>
              </template>
            </a-table-column>
          </template>
        </a-table>
      </a-card>

      <!-- 对比图表 -->
      <a-card title="可视化对比" :bordered="false" class="chart-card">
        <a-tabs>
          <a-tab-pane key="radar" title="雷达图">
            <InteractiveChart
              :config="buildRadarChart()"
              :height="'400px'"
              :export-formats="['png', 'csv']"
            />
          </a-tab-pane>

          <a-tab-pane key="bar" title="柱状图">
            <InteractiveChart
              :config="buildBarChart()"
              :height="'400px'"
              :export-formats="['png', 'csv']"
            />
          </a-tab-pane>

          <a-tab-pane key="line" title="折线图">
            <InteractiveChart
              :config="buildLineChart()"
              :height="'400px'"
              :export-formats="['png', 'csv']"
            />
          </a-tab-pane>
        </a-tabs>
      </a-card>

      <!-- 导出按钮 -->
      <div class="export-actions">
        <a-space>
          <a-button @click="handleExportReport">
            <template #icon>
              <icon-download />
            </template>
            导出对比报告
          </a-button>
          <a-button @click="handleExportData">
            <template #icon>
              <icon-file />
            </template>
            导出数据
          </a-button>
        </a-space>
      </div>
    </div>

    <a-empty v-else description="请配置对比条件并开始对比" />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconSwap,
  IconTrophy,
  IconBulb,
  IconDownload,
  IconFile,
} from '@arco-design/web-vue/es/icon';
import { useQualityAnalysis, type ComparisonResult } from '@/composables/useQualityAnalysis';
import InteractiveChart from '@/components/chart/InteractiveChart.vue';
import type { ChartConfig } from '@/composables/useInteractiveChart';

interface Module {
  id: number;
  name: string;
}

interface Project {
  id: number;
  name: string;
}

interface Team {
  id: number;
  name: string;
}

interface Props {
  modules?: Module[];
  projects?: Project[];
  teams?: Team[];
}

const props = withDefaults(defineProps<Props>(), {
  modules: () => [],
  projects: () => [],
  teams: () => [],
});

const emit = defineEmits<{
  compare: [type: string, config: any];
}>();

const { compare } = useQualityAnalysis();

// 对比类型
const comparisonType = ref<'time' | 'module' | 'project' | 'team'>('time');

// 时间对比配置
const timeRange1 = ref<[string, string]>();
const timeRange2 = ref<[string, string]>();

// 模块对比配置
const selectedModules = ref<number[]>([]);

// 项目对比配置
const selectedProjects = ref<number[]>([]);

// 团队对比配置
const selectedTeams = ref<number[]>([]);

// 对比结果
const comparisonResult = ref<ComparisonResult | null>(null);

// 类型变更
const handleTypeChange = () => {
  comparisonResult.value = null;
};

// 开始对比
const handleCompare = async () => {
  try {
    let items: Array<{ name: string; metrics: Record<string, number> }> = [];

    if (comparisonType.value === 'time') {
      if (!timeRange1.value || !timeRange2.value) {
        Message.warning('请选择时间段');
        return;
      }

      // TODO: 调用API获取时间段数据
      items = [
        {
          name: `${timeRange1.value[0]} ~ ${timeRange1.value[1]}`,
          metrics: {
            testCoverage: 85,
            passRate: 92,
            bugDensity: 2.5,
            avgResponseTime: 150,
          },
        },
        {
          name: `${timeRange2.value[0]} ~ ${timeRange2.value[1]}`,
          metrics: {
            testCoverage: 78,
            passRate: 88,
            bugDensity: 3.2,
            avgResponseTime: 180,
          },
        },
      ];
    } else if (comparisonType.value === 'module') {
      if (selectedModules.value.length < 2) {
        Message.warning('请至少选择2个模块');
        return;
      }

      // TODO: 调用API获取模块数据
      items = selectedModules.value.map((id) => {
        const module = props.modules.find((m) => m.id === id);
        return {
          name: module?.name || `模块${id}`,
          metrics: {
            testCoverage: Math.random() * 100,
            passRate: Math.random() * 100,
            bugDensity: Math.random() * 10,
            avgResponseTime: Math.random() * 500,
          },
        };
      });
    } else if (comparisonType.value === 'project') {
      if (selectedProjects.value.length < 2) {
        Message.warning('请至少选择2个项目');
        return;
      }

      // TODO: 调用API获取项目数据
      items = selectedProjects.value.map((id) => {
        const project = props.projects.find((p) => p.id === id);
        return {
          name: project?.name || `项目${id}`,
          metrics: {
            testCoverage: Math.random() * 100,
            passRate: Math.random() * 100,
            bugDensity: Math.random() * 10,
            avgResponseTime: Math.random() * 500,
          },
        };
      });
    } else if (comparisonType.value === 'team') {
      if (selectedTeams.value.length < 2) {
        Message.warning('请至少选择2个团队');
        return;
      }

      // TODO: 调用API获取团队数据
      items = selectedTeams.value.map((id) => {
        const team = props.teams.find((t) => t.id === id);
        return {
          name: team?.name || `团队${id}`,
          metrics: {
            testCoverage: Math.random() * 100,
            passRate: Math.random() * 100,
            bugDensity: Math.random() * 10,
            avgResponseTime: Math.random() * 500,
          },
        };
      });
    }

    comparisonResult.value = compare(comparisonType.value, items);
    emit('compare', comparisonType.value, items);
    Message.success('对比完成');
  } catch (error: any) {
    Message.error(`对比失败: ${error.message}`);
  }
};

// 获取指标名称
const getMetricName = (key: string) => {
  const names: Record<string, string> = {
    testCoverage: '测试覆盖率',
    passRate: '通过率',
    bugDensity: 'Bug密度',
    avgResponseTime: '响应时间',
    codeQuality: '代码质量',
    documentationScore: '文档完整度',
  };
  return names[key] || key;
};

// 获取得分颜色
const getScoreColor = (score: number) => {
  if (score >= 90) return 'green';
  if (score >= 75) return 'blue';
  if (score >= 60) return 'orange';
  return 'red';
};

// 构建雷达图
const buildRadarChart = (): ChartConfig => {
  if (!comparisonResult.value) return { type: 'line' };

  const indicators = Object.keys(comparisonResult.value.items[0].metrics).map((key) => ({
    name: getMetricName(key),
    max: 100,
  }));

  const series = comparisonResult.value.items.map((item) => ({
    name: item.name,
    type: 'radar',
    data: [
      {
        value: Object.values(item.metrics),
        name: item.name,
      },
    ],
  }));

  return {
    type: 'line',
    title: '综合对比雷达图',
    legend: {
      bottom: 0,
    },
    series: [
      {
        type: 'radar',
        data: comparisonResult.value.items.map((item) => ({
          value: Object.values(item.metrics),
          name: item.name,
        })),
      },
    ],
  };
};

// 构建柱状图
const buildBarChart = (): ChartConfig => {
  if (!comparisonResult.value) return { type: 'bar' };

  const metricKeys = Object.keys(comparisonResult.value.items[0].metrics);
  const series = metricKeys.map((key) => ({
    name: getMetricName(key),
    type: 'bar',
    data: comparisonResult.value!.items.map((item) => item.metrics[key]),
  }));

  return {
    type: 'bar',
    title: '指标对比柱状图',
    xAxis: {
      type: 'category',
      data: comparisonResult.value.items.map((item) => item.name),
    },
    yAxis: {
      type: 'value',
    },
    series,
    legend: {
      bottom: 0,
    },
  };
};

// 构建折线图
const buildLineChart = (): ChartConfig => {
  if (!comparisonResult.value) return { type: 'line' };

  const metricKeys = Object.keys(comparisonResult.value.items[0].metrics);
  const series = metricKeys.map((key) => ({
    name: getMetricName(key),
    type: 'line',
    data: comparisonResult.value!.items.map((item) => item.metrics[key]),
    smooth: true,
  }));

  return {
    type: 'line',
    title: '指标对比折线图',
    xAxis: {
      type: 'category',
      data: comparisonResult.value.items.map((item) => item.name),
    },
    yAxis: {
      type: 'value',
    },
    series,
    legend: {
      bottom: 0,
    },
  };
};

// 导出报告
const handleExportReport = () => {
  Message.info('导出报告功能开发中...');
};

// 导出数据
const handleExportData = () => {
  if (!comparisonResult.value) return;

  const csv = convertToCSV(comparisonResult.value);
  const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `comparison_${Date.now()}.csv`;
  a.click();
  URL.revokeObjectURL(url);

  Message.success('数据导出成功');
};

// 转换为CSV
const convertToCSV = (result: ComparisonResult): string => {
  const headers = ['排名', '名称', ...Object.keys(result.items[0].metrics).map(getMetricName), '综合得分'];
  const rows = result.items.map((item) => [
    item.rank,
    item.name,
    ...Object.values(item.metrics).map((v) => v.toFixed(2)),
    item.score.toFixed(1),
  ]);

  return [headers.join(','), ...rows.map((row) => row.join(','))].join('\n');
};
</script>

<style scoped lang="less">
.comparison-panel {
  .comparison-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }

  .config-card {
    margin-bottom: 16px;
  }

  .comparison-result {
    .winner-alert {
      margin-bottom: 16px;
    }

    .insights-card,
    .table-card,
    .chart-card {
      margin-bottom: 16px;
    }

    .metric-cell {
      display: flex;
      flex-direction: column;
      gap: 4px;
    }

    .export-actions {
      display: flex;
      justify-content: flex-end;
    }
  }
}
</style>
