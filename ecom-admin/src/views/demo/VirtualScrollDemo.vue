<template>
  <div class="virtual-scroll-demo">
    <a-card :bordered="false">
      <template #title>
        <h2>虚拟滚动性能对比</h2>
      </template>

      <!-- 控制面板 -->
      <div class="control-panel">
        <a-space size="large">
          <div>
            <label>数据量:</label>
            <a-input-number
              v-model="dataCount"
              :min="100"
              :max="100000"
              :step="1000"
              style="width: 150px; margin-left: 8px"
            />
          </div>
          <a-button type="primary" @click="generateData">
            生成数据
          </a-button>
          <a-button @click="clearData">清空数据</a-button>
        </a-space>
      </div>

      <!-- 性能对比 -->
      <div class="performance-comparison">
        <a-row :gutter="16">
          <!-- 普通渲染 -->
          <a-col :span="12">
            <a-card title="普通渲染" :bordered="false">
              <template #extra>
                <a-tag :color="normalRenderTime > 1000 ? 'red' : 'green'">
                  {{ normalRenderTime }}ms
                </a-tag>
              </template>

              <div class="render-info">
                <a-descriptions :column="1" size="small">
                  <a-descriptions-item label="渲染时间">
                    {{ normalRenderTime }}ms
                  </a-descriptions-item>
                  <a-descriptions-item label="DOM节点数">
                    {{ dataCount }}
                  </a-descriptions-item>
                  <a-descriptions-item label="内存占用">
                    ~{{ Math.round((dataCount * 0.5) / 1024) }}MB
                  </a-descriptions-item>
                  <a-descriptions-item label="滚动流畅度">
                    {{ normalRenderTime > 1000 ? '卡顿' : '流畅' }}
                  </a-descriptions-item>
                </a-descriptions>
              </div>

              <div class="normal-list" style="height: 400px; overflow-y: auto">
                <div
                  v-for="item in normalData"
                  :key="item.id"
                  class="list-item"
                >
                  <div class="item-content">
                    <div class="item-title">{{ item.title }}</div>
                    <div class="item-description">{{ item.description }}</div>
                    <div class="item-meta">
                      <span>ID: {{ item.id }}</span>
                      <span>时间: {{ item.time }}</span>
                    </div>
                  </div>
                </div>
              </div>
            </a-card>
          </a-col>

          <!-- 虚拟滚动 -->
          <a-col :span="12">
            <a-card title="虚拟滚动" :bordered="false">
              <template #extra>
                <a-tag color="green">{{ virtualRenderTime }}ms</a-tag>
              </template>

              <div class="render-info">
                <a-descriptions :column="1" size="small">
                  <a-descriptions-item label="渲染时间">
                    {{ virtualRenderTime }}ms
                  </a-descriptions-item>
                  <a-descriptions-item label="DOM节点数">
                    ~{{ visibleCount }}
                  </a-descriptions-item>
                  <a-descriptions-item label="内存占用">
                    ~{{ Math.round((visibleCount * 0.5) / 1024) }}MB
                  </a-descriptions-item>
                  <a-descriptions-item label="滚动流畅度">
                    流畅 (60fps)
                  </a-descriptions-item>
                </a-descriptions>
              </div>

              <VirtualList
                :items="virtualData"
                :item-height="80"
                container-height="400px"
                :buffer-size="5"
              >
                <template #item="{ item }">
                  <div class="list-item">
                    <div class="item-content">
                      <div class="item-title">{{ item.title }}</div>
                      <div class="item-description">{{ item.description }}</div>
                      <div class="item-meta">
                        <span>ID: {{ item.id }}</span>
                        <span>时间: {{ item.time }}</span>
                      </div>
                    </div>
                  </div>
                </template>
              </VirtualList>
            </a-card>
          </a-col>
        </a-row>
      </div>

      <!-- 性能提升 -->
      <div class="performance-improvement">
        <a-divider>性能提升</a-divider>
        <a-row :gutter="16">
          <a-col :span="8">
            <a-statistic
              title="渲染时间提升"
              :value="renderTimeImprovement"
              suffix="%"
              :value-style="{ color: '#3f8600' }"
            >
              <template #prefix>
                <icon-arrow-down />
              </template>
            </a-statistic>
          </a-col>
          <a-col :span="8">
            <a-statistic
              title="DOM节点减少"
              :value="domNodeReduction"
              suffix="%"
              :value-style="{ color: '#3f8600' }"
            >
              <template #prefix>
                <icon-arrow-down />
              </template>
            </a-statistic>
          </a-col>
          <a-col :span="8">
            <a-statistic
              title="内存占用减少"
              :value="memoryReduction"
              suffix="%"
              :value-style="{ color: '#3f8600' }"
            >
              <template #prefix>
                <icon-arrow-down />
              </template>
            </a-statistic>
          </a-col>
        </a-row>
      </div>

      <!-- 性能图表 -->
      <div class="performance-chart">
        <a-divider>性能对比图表</a-divider>
        <div ref="chartRef" style="height: 400px"></div>
      </div>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, onMounted } from 'vue';
import { IconArrowDown } from '@arco-design/web-vue/es/icon';
import * as echarts from 'echarts';
import dayjs from 'dayjs';
import VirtualList from '@/components/virtual-scroll/VirtualList.vue';

interface ListItem {
  id: number;
  title: string;
  description: string;
  time: string;
}

// 数据量
const dataCount = ref(1000);

// 数据
const normalData = ref<ListItem[]>([]);
const virtualData = ref<ListItem[]>([]);

// 渲染时间
const normalRenderTime = ref(0);
const virtualRenderTime = ref(0);

// 可见项数量
const visibleCount = computed(() => {
  return Math.ceil(400 / 80) + 10; // 容器高度 / 项高度 + 缓冲
});

// 性能提升
const renderTimeImprovement = computed(() => {
  if (normalRenderTime.value === 0) return 0;
  return Math.round(
    ((normalRenderTime.value - virtualRenderTime.value) / normalRenderTime.value) * 100
  );
});

const domNodeReduction = computed(() => {
  if (dataCount.value === 0) return 0;
  return Math.round(((dataCount.value - visibleCount.value) / dataCount.value) * 100);
});

const memoryReduction = computed(() => {
  return domNodeReduction.value; // 简化计算，实际内存占用与DOM节点数成正比
});

// 图表引用
const chartRef = ref<HTMLElement>();

// 生成数据
const generateData = () => {
  const count = dataCount.value;
  const data: ListItem[] = [];

  for (let i = 1; i <= count; i++) {
    data.push({
      id: i,
      title: `数据项 ${i}`,
      description: `这是第 ${i} 条数据的描述信息，用于测试虚拟滚动性能。`,
      time: dayjs().subtract(i, 'minute').format('YYYY-MM-DD HH:mm:ss'),
    });
  }

  // 普通渲染
  const normalStart = performance.now();
  normalData.value = data;
  setTimeout(() => {
    const normalEnd = performance.now();
    normalRenderTime.value = Math.round(normalEnd - normalStart);
  }, 0);

  // 虚拟滚动
  const virtualStart = performance.now();
  virtualData.value = data;
  setTimeout(() => {
    const virtualEnd = performance.now();
    virtualRenderTime.value = Math.round(virtualEnd - virtualStart);
    
    // 更新图表
    updateChart();
  }, 0);
};

// 清空数据
const clearData = () => {
  normalData.value = [];
  virtualData.value = [];
  normalRenderTime.value = 0;
  virtualRenderTime.value = 0;
};

// 更新图表
const updateChart = () => {
  if (!chartRef.value) return;

  const chart = echarts.init(chartRef.value);

  const option = {
    tooltip: {
      trigger: 'axis',
      axisPointer: {
        type: 'shadow',
      },
    },
    legend: {
      data: ['普通渲染', '虚拟滚动'],
    },
    xAxis: {
      type: 'category',
      data: ['渲染时间(ms)', 'DOM节点数', '内存占用(MB)'],
    },
    yAxis: {
      type: 'value',
    },
    series: [
      {
        name: '普通渲染',
        type: 'bar',
        data: [
          normalRenderTime.value,
          dataCount.value,
          Math.round((dataCount.value * 0.5) / 1024),
        ],
        itemStyle: {
          color: '#ff4d4f',
        },
      },
      {
        name: '虚拟滚动',
        type: 'bar',
        data: [
          virtualRenderTime.value,
          visibleCount.value,
          Math.round((visibleCount.value * 0.5) / 1024),
        ],
        itemStyle: {
          color: '#52c41a',
        },
      },
    ],
  };

  chart.setOption(option);

  // 响应式
  window.addEventListener('resize', () => chart.resize());
};

// 初始化
onMounted(() => {
  generateData();
});
</script>

<style scoped lang="scss">
.virtual-scroll-demo {
  padding: 20px;

  .control-panel {
    margin-bottom: 24px;
    padding: 16px;
    background: #f9fafb;
    border-radius: 4px;
  }

  .performance-comparison {
    margin-bottom: 24px;

    .render-info {
      margin-bottom: 16px;
    }

    .list-item {
      padding: 12px;
      border-bottom: 1px solid #e5e7eb;

      &:hover {
        background: #f9fafb;
      }

      .item-content {
        .item-title {
          font-size: 14px;
          font-weight: 600;
          margin-bottom: 4px;
        }

        .item-description {
          font-size: 12px;
          color: #666;
          margin-bottom: 4px;
        }

        .item-meta {
          font-size: 12px;
          color: #999;

          span {
            margin-right: 16px;
          }
        }
      }
    }
  }

  .performance-improvement {
    margin-bottom: 24px;
  }

  .performance-chart {
    margin-bottom: 24px;
  }
}
</style>
