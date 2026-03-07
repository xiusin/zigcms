<template>
  <div class="execution-history">
    <a-spin :loading="loading" style="width: 100%">
      <a-empty v-if="executions.length === 0" description="暂无执行记录" />
      
      <a-timeline v-else>
        <a-timeline-item
          v-for="execution in executions"
          :key="execution.id"
          :label="formatDate(execution.executed_at)"
        >
          <template #dot>
            <div
              class="status-dot"
              :class="`status-${execution.status}`"
            />
          </template>

          <a-card class="execution-card" :bordered="false">
            <div class="execution-header">
              <div class="execution-info">
                <a-tag :color="getStatusColor(execution.status)">
                  {{ getStatusText(execution.status) }}
                </a-tag>
                <span class="executor">执行人: {{ execution.executor }}</span>
                <span class="duration">
                  耗时: {{ formatDuration(execution.duration_ms) }}
                </span>
              </div>
            </div>

            <a-descriptions
              :column="1"
              bordered
              size="small"
              class="execution-details"
            >
              <a-descriptions-item label="实际结果">
                <div class="result-text">
                  {{ execution.actual_result || '-' }}
                </div>
              </a-descriptions-item>

              <a-descriptions-item v-if="execution.remark" label="备注">
                <div class="remark-text">
                  {{ execution.remark }}
                </div>
              </a-descriptions-item>
            </a-descriptions>
          </a-card>
        </a-timeline-item>
      </a-timeline>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { ref, watch, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import qualityCenterApi from '@/api/quality-center';
import type { TestExecution, ExecutionStatus } from '@/types/quality-center';
import dayjs from 'dayjs';

interface Props {
  testCaseId: number;
}

const props = defineProps<Props>();

// 执行历史列表
const executions = ref<TestExecution[]>([]);

// 加载中
const loading = ref(false);

// 加载执行历史
const loadExecutions = async () => {
  if (!props.testCaseId) return;

  loading.value = true;
  try {
    executions.value = await qualityCenterApi.getTestCaseExecutions(
      props.testCaseId
    );
  } catch (error) {
    Message.error('加载执行历史失败');
  } finally {
    loading.value = false;
  }
};

// 监听测试用例 ID 变化
watch(
  () => props.testCaseId,
  () => {
    loadExecutions();
  },
  { immediate: true }
);

// 状态颜色
const getStatusColor = (status: ExecutionStatus): string => {
  const colorMap: Record<ExecutionStatus, string> = {
    passed: 'green',
    failed: 'red',
    blocked: 'orange',
  };
  return colorMap[status] || 'gray';
};

// 状态文本
const getStatusText = (status: ExecutionStatus): string => {
  const textMap: Record<ExecutionStatus, string> = {
    passed: '通过',
    failed: '失败',
    blocked: '阻塞',
  };
  return textMap[status] || status;
};

// 格式化日期
const formatDate = (timestamp: number): string => {
  return dayjs(timestamp * 1000).format('YYYY-MM-DD HH:mm:ss');
};

// 格式化时长
const formatDuration = (ms: number): string => {
  if (ms < 1000) {
    return `${ms}ms`;
  } else if (ms < 60000) {
    return `${(ms / 1000).toFixed(1)}s`;
  } else {
    const minutes = Math.floor(ms / 60000);
    const seconds = Math.floor((ms % 60000) / 1000);
    return `${minutes}m ${seconds}s`;
  }
};

// 初始化
onMounted(() => {
  loadExecutions();
});
</script>

<style scoped lang="less">
.execution-history {
  padding: 16px 0;
}

.status-dot {
  width: 12px;
  height: 12px;
  border-radius: 50%;
  
  &.status-passed {
    background-color: #00b42a;
  }
  
  &.status-failed {
    background-color: #f53f3f;
  }
  
  &.status-blocked {
    background-color: #ff7d00;
  }
}

.execution-card {
  background: #f7f8fa;
  margin-bottom: 8px;
}

.execution-header {
  margin-bottom: 12px;
}

.execution-info {
  display: flex;
  align-items: center;
  gap: 16px;
  
  .executor,
  .duration {
    font-size: 13px;
    color: #666;
  }
}

.execution-details {
  margin-top: 12px;
}

.result-text,
.remark-text {
  white-space: pre-wrap;
  word-break: break-word;
  line-height: 1.6;
  color: #333;
}
</style>
