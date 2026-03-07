<template>
  <div class="project-statistics">
    <a-spin :loading="loading" style="width: 100%">
      <div v-if="statistics" class="statistics-grid">
        <!-- 用例总数 -->
        <div class="stat-card">
          <a-statistic
            :value="statistics.total_cases"
            :value-style="{ color: '#165dff' }"
          >
            <template #title>
              <div class="stat-title">
                <icon-file-text />
                <span>用例总数</span>
              </div>
            </template>
            <template #suffix>
              <span class="stat-unit">个</span>
            </template>
          </a-statistic>
        </div>

        <!-- 执行次数 -->
        <div class="stat-card">
          <a-statistic
            :value="statistics.execution_count"
            :value-style="{ color: '#722ed1' }"
          >
            <template #title>
              <div class="stat-title">
                <icon-play-circle />
                <span>执行次数</span>
              </div>
            </template>
            <template #suffix>
              <span class="stat-unit">次</span>
            </template>
          </a-statistic>
        </div>

        <!-- 通过率 -->
        <div class="stat-card">
          <a-statistic
            :value="statistics.pass_rate"
            :precision="1"
            :value-style="{ color: passRateColor }"
          >
            <template #title>
              <div class="stat-title">
                <icon-check-circle />
                <span>通过率</span>
              </div>
            </template>
            <template #suffix>
              <span class="stat-unit">%</span>
            </template>
          </a-statistic>
          <div class="stat-progress">
            <a-progress
              :percent="statistics.pass_rate"
              :color="passRateColor"
              :show-text="false"
              size="small"
            />
          </div>
        </div>

        <!-- Bug 数量 -->
        <div class="stat-card">
          <a-statistic
            :value="statistics.bug_count"
            :value-style="{ color: bugCountColor }"
          >
            <template #title>
              <div class="stat-title">
                <icon-bug />
                <span>Bug 数量</span>
              </div>
            </template>
            <template #suffix>
              <span class="stat-unit">个</span>
            </template>
          </a-statistic>
        </div>

        <!-- 需求覆盖率 -->
        <div class="stat-card">
          <a-statistic
            :value="statistics.requirement_coverage"
            :precision="1"
            :value-style="{ color: coverageColor }"
          >
            <template #title>
              <div class="stat-title">
                <icon-layers />
                <span>需求覆盖率</span>
              </div>
            </template>
            <template #suffix>
              <span class="stat-unit">%</span>
            </template>
          </a-statistic>
          <div class="stat-progress">
            <a-progress
              :percent="statistics.requirement_coverage"
              :color="coverageColor"
              :show-text="false"
              size="small"
            />
          </div>
        </div>
      </div>

      <!-- 骨架屏 -->
      <div v-else class="skeleton-grid">
        <a-skeleton
          v-for="i in 5"
          :key="i"
          animation
          class="skeleton-card"
        >
          <a-skeleton-line :rows="3" />
        </a-skeleton>
      </div>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconFileText,
  IconPlayCircle,
  IconCheckCircle,
  IconBug,
  IconLayers,
} from '@arco-design/web-vue/es/icon';
import qualityCenterApi from '@/api/quality-center';
import type { ProjectStatistics } from '@/types/quality-center';

interface Props {
  projectId: number;
}

const props = defineProps<Props>();

// 统计数据
const loading = ref(false);
const statistics = ref<ProjectStatistics | null>(null);

// 通过率颜色
const passRateColor = computed(() => {
  if (!statistics.value) return '#86909c';
  const rate = statistics.value.pass_rate;
  if (rate >= 90) return '#00b42a';
  if (rate >= 70) return '#ff7d00';
  return '#f53f3f';
});

// Bug 数量颜色
const bugCountColor = computed(() => {
  if (!statistics.value) return '#86909c';
  const count = statistics.value.bug_count;
  if (count === 0) return '#00b42a';
  if (count <= 5) return '#ff7d00';
  return '#f53f3f';
});

// 覆盖率颜色
const coverageColor = computed(() => {
  if (!statistics.value) return '#86909c';
  const rate = statistics.value.requirement_coverage;
  if (rate >= 80) return '#00b42a';
  if (rate >= 60) return '#ff7d00';
  return '#f53f3f';
});

// 加载统计数据
const loadStatistics = async () => {
  try {
    loading.value = true;
    statistics.value = await qualityCenterApi.getProjectStatistics(props.projectId);
  } catch (error) {
    Message.error('加载统计数据失败');
    console.error(error);
    // 使用默认值
    statistics.value = {
      total_cases: 0,
      execution_count: 0,
      pass_rate: 0,
      bug_count: 0,
      requirement_coverage: 0,
    };
  } finally {
    loading.value = false;
  }
};

onMounted(() => {
  loadStatistics();
});
</script>

<style scoped lang="less">
.project-statistics {
  width: 100%;
}

.statistics-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.stat-card {
  padding: 20px;
  background: linear-gradient(135deg, #f5f7fa 0%, #ffffff 100%);
  border-radius: 8px;
  border: 1px solid #e5e6eb;
  transition: all 0.2s;
  
  &:hover {
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.08);
    transform: translateY(-2px);
  }
}

.stat-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 14px;
  color: #4e5969;
  margin-bottom: 8px;
  
  svg {
    font-size: 16px;
  }
}

.stat-unit {
  font-size: 14px;
  color: #86909c;
  margin-left: 4px;
}

.stat-progress {
  margin-top: 12px;
}

.skeleton-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
  gap: 20px;
}

.skeleton-card {
  padding: 20px;
  background: #f5f7fa;
  border-radius: 8px;
  border: 1px solid #e5e6eb;
}

:deep(.arco-statistic) {
  .arco-statistic-title {
    margin-bottom: 0;
  }
  
  .arco-statistic-content {
    margin-top: 8px;
    
    .arco-statistic-value {
      font-size: 32px;
      font-weight: 600;
    }
  }
}

@media (max-width: 1200px) {
  .statistics-grid,
  .skeleton-grid {
    grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
  }
}

@media (max-width: 768px) {
  .statistics-grid,
  .skeleton-grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 12px;
  }
  
  .stat-card,
  .skeleton-card {
    padding: 16px;
  }
  
  :deep(.arco-statistic) {
    .arco-statistic-content {
      .arco-statistic-value {
        font-size: 24px;
      }
    }
  }
}

@media (max-width: 480px) {
  .statistics-grid,
  .skeleton-grid {
    grid-template-columns: 1fr;
  }
}
</style>
