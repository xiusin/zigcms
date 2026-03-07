<template>
  <div class="project-card" @click="handleView">
    <!-- 卡片头部 -->
    <div class="card-header">
      <div class="project-info">
        <h3 class="project-name">{{ project.name }}</h3>
        <a-tag :color="statusColor">{{ statusText }}</a-tag>
      </div>
      <a-dropdown @select="handleAction" trigger="click" @click.stop>
        <a-button type="text" size="small">
          <template #icon>
            <icon-more />
          </template>
        </a-button>
        <template #content>
          <a-doption value="view">
            <template #icon>
              <icon-eye />
            </template>
            查看详情
          </a-doption>
          <a-doption value="edit">
            <template #icon>
              <icon-edit />
            </template>
            编辑
          </a-doption>
          <a-doption v-if="project.status === 'active'" value="archive">
            <template #icon>
              <icon-archive />
            </template>
            归档
          </a-doption>
          <a-doption v-if="project.status === 'archived'" value="restore">
            <template #icon>
              <icon-undo />
            </template>
            恢复
          </a-doption>
          <a-doption value="delete" class="danger-option">
            <template #icon>
              <icon-delete />
            </template>
            删除
          </a-doption>
        </template>
      </a-dropdown>
    </div>

    <!-- 项目描述 -->
    <p class="project-description">{{ project.description }}</p>

    <!-- 项目负责人 -->
    <div class="project-owner">
      <icon-user />
      <span>{{ project.owner || '未指定' }}</span>
    </div>

    <!-- 统计数据 -->
    <div class="statistics-section">
      <a-spin :loading="loadingStats" style="width: 100%">
        <div v-if="statistics" class="statistics-grid">
          <div class="stat-item">
            <div class="stat-value">{{ statistics.total_cases }}</div>
            <div class="stat-label">用例总数</div>
          </div>
          <div class="stat-item">
            <div class="stat-value pass-rate">{{ statistics.pass_rate.toFixed(1) }}%</div>
            <div class="stat-label">通过率</div>
          </div>
          <div class="stat-item">
            <div class="stat-value bug-count">{{ statistics.bug_count }}</div>
            <div class="stat-label">Bug 数量</div>
          </div>
        </div>
        <a-skeleton v-else animation>
          <a-skeleton-line :rows="2" />
        </a-skeleton>
      </a-spin>
    </div>

    <!-- 卡片底部 -->
    <div class="card-footer">
      <div class="footer-info">
        <icon-clock-circle />
        <span>{{ formatDate(project.created_at) }}</span>
      </div>
      <a-button type="text" size="small" @click.stop="handleView">
        查看详情
        <template #icon>
          <icon-right />
        </template>
      </a-button>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconMore,
  IconEye,
  IconEdit,
  IconArchive,
  IconUndo,
  IconDelete,
  IconUser,
  IconClockCircle,
  IconRight,
} from '@arco-design/web-vue/es/icon';
import qualityCenterApi from '@/api/quality-center';
import type { Project, ProjectStatistics } from '@/types/quality-center';

interface Props {
  project: Project;
}

interface Emits {
  (e: 'view', project: Project): void;
  (e: 'edit', project: Project): void;
  (e: 'archive', project: Project): void;
  (e: 'restore', project: Project): void;
  (e: 'delete', project: Project): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// 统计数据
const loadingStats = ref(false);
const statistics = ref<ProjectStatistics | null>(null);

// 状态颜色
const statusColor = computed(() => {
  switch (props.project.status) {
    case 'active':
      return 'green';
    case 'archived':
      return 'orange';
    case 'closed':
      return 'red';
    default:
      return 'gray';
  }
});

// 状态文本
const statusText = computed(() => {
  switch (props.project.status) {
    case 'active':
      return '活跃';
    case 'archived':
      return '已归档';
    case 'closed':
      return '已关闭';
    default:
      return '未知';
  }
});

// 格式化日期
const formatDate = (timestamp?: number | null) => {
  if (!timestamp) return '未知';
  const date = new Date(timestamp * 1000);
  return date.toLocaleDateString('zh-CN');
};

// 加载统计数据
const loadStatistics = async () => {
  if (!props.project.id) return;
  
  try {
    loadingStats.value = true;
    statistics.value = await qualityCenterApi.getProjectStatistics(props.project.id);
  } catch (error) {
    console.error('加载统计数据失败:', error);
    // 使用默认值
    statistics.value = {
      total_cases: 0,
      execution_count: 0,
      pass_rate: 0,
      bug_count: 0,
      requirement_coverage: 0,
    };
  } finally {
    loadingStats.value = false;
  }
};

// 查看详情
const handleView = () => {
  emit('view', props.project);
};

// 操作菜单
const handleAction = (value: string | number | Record<string, any> | undefined) => {
  const action = value as string;
  
  switch (action) {
    case 'view':
      emit('view', props.project);
      break;
    case 'edit':
      emit('edit', props.project);
      break;
    case 'archive':
      emit('archive', props.project);
      break;
    case 'restore':
      emit('restore', props.project);
      break;
    case 'delete':
      emit('delete', props.project);
      break;
  }
};

onMounted(() => {
  loadStatistics();
});
</script>

<style scoped lang="less">
.project-card {
  padding: 20px;
  background: white;
  border-radius: 8px;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  cursor: pointer;
  transition: all 0.2s;
  
  &:hover {
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
    transform: translateY(-2px);
  }
}

.card-header {
  display: flex;
  justify-content: space-between;
  align-items: flex-start;
  margin-bottom: 12px;
}

.project-info {
  flex: 1;
  display: flex;
  align-items: center;
  gap: 12px;
}

.project-name {
  margin: 0;
  font-size: 18px;
  font-weight: 600;
  color: #1d2129;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.project-description {
  margin: 0 0 16px 0;
  font-size: 14px;
  color: #4e5969;
  line-height: 1.6;
  display: -webkit-box;
  -webkit-line-clamp: 2;
  -webkit-box-orient: vertical;
  overflow: hidden;
  text-overflow: ellipsis;
  min-height: 44px;
}

.project-owner {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 16px;
  font-size: 14px;
  color: #86909c;
  
  svg {
    font-size: 16px;
  }
}

.statistics-section {
  padding: 16px 0;
  border-top: 1px solid #e5e6eb;
  border-bottom: 1px solid #e5e6eb;
  margin-bottom: 16px;
}

.statistics-grid {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 16px;
}

.stat-item {
  text-align: center;
}

.stat-value {
  font-size: 24px;
  font-weight: 600;
  color: #1d2129;
  margin-bottom: 4px;
  
  &.pass-rate {
    color: #00b42a;
  }
  
  &.bug-count {
    color: #f53f3f;
  }
}

.stat-label {
  font-size: 12px;
  color: #86909c;
}

.card-footer {
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.footer-info {
  display: flex;
  align-items: center;
  gap: 6px;
  font-size: 12px;
  color: #86909c;
  
  svg {
    font-size: 14px;
  }
}

:deep(.danger-option) {
  color: #f53f3f;
  
  &:hover {
    background-color: #ffece8;
  }
}

@media (max-width: 768px) {
  .project-card {
    padding: 16px;
  }
  
  .project-name {
    font-size: 16px;
  }
  
  .statistics-grid {
    gap: 12px;
  }
  
  .stat-value {
    font-size: 20px;
  }
}
</style>
