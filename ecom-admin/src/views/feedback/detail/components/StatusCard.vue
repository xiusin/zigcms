<template>
  <div class="status-card">
    <div class="card-header">
      <div class="card-title">
        <icon-tag />
        状态管理
      </div>
    </div>

    <div class="card-body">
      <!-- 当前状态展示 -->
      <div class="current-status">
        <div class="status-label">当前状态</div>
        <div class="status-value">
          <a-tag :color="statusColor" size="large">{{ statusName }}</a-tag>
        </div>
      </div>

      <!-- 状态变更 -->
      <div class="status-change">
        <div class="change-label">变更状态</div>
        <a-select
          v-model="selectedStatus"
          placeholder="选择新状态"
          style="width: 100%"
          @change="handleStatusChange"
        >
          <a-option
            v-for="item in statusOptions"
            :key="item.value"
            :value="item.value"
            :label="item.label"
          >
            <div class="status-option">
              <span
                class="status-dot"
                :style="{ backgroundColor: item.color }"
              />
              {{ item.label }}
            </div>
          </a-option>
        </a-select>
      </div>

      <!-- 状态历史 -->
      <div v-if="history.length > 0" class="status-history">
        <div class="history-title">
          <icon-history />
          变更历史
        </div>
        <div class="history-list">
          <div
            v-for="(record, index) in history"
            :key="index"
            class="history-item"
          >
            <div class="history-dot" :style="{ backgroundColor: record.color }" />
            <div class="history-content">
              <div class="history-status">{{ record.statusName }}</div>
              <div class="history-meta">
                <span class="history-operator">{{ record.operator }}</span>
                <span class="history-time">{{ record.time }}</span>
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import { IconTag, IconHistory } from '@arco-design/web-vue/es/icon';
  import { FeedbackStatus } from '@/api/feedback';

  interface Props {
    status: number;
    statusName: string;
    statusColor: string;
  }

  const props = defineProps<Props>();

  const emit = defineEmits<{
    (e: 'change', status: number): void;
  }>();

  // 状态选项
  const statusOptions = [
    { value: FeedbackStatus.PENDING, label: '待处理', color: '#86909c' },
    { value: FeedbackStatus.PROCESSING, label: '处理中', color: '#ff7d00' },
    { value: FeedbackStatus.RESOLVED, label: '已解决', color: '#00b42a' },
    { value: FeedbackStatus.CLOSED, label: '已关闭', color: '#86909c' },
    { value: FeedbackStatus.REJECTED, label: '已拒绝', color: '#f53f3f' },
  ];

  // 当前选择的状态
  const selectedStatus = ref<number | undefined>(undefined);

  // 状态历史记录（模拟数据）
  const history = computed(() => {
    const records: {
      statusName: string;
      operator: string;
      time: string;
      color: string;
    }[] = [];

    // 根据当前状态生成历史记录
    if (props.status !== FeedbackStatus.PENDING) {
      records.push({
        statusName: '待处理',
        operator: '系统',
        time: '2024-01-15 10:30',
        color: '#86909c',
      });
    }

    if (props.status === FeedbackStatus.PROCESSING ||
        props.status === FeedbackStatus.RESOLVED ||
        props.status === FeedbackStatus.CLOSED) {
      records.push({
        statusName: '处理中',
        operator: '张三',
        time: '2024-01-15 14:20',
        color: '#ff7d00',
      });
    }

    if (props.status === FeedbackStatus.RESOLVED ||
        props.status === FeedbackStatus.CLOSED) {
      records.push({
        statusName: '已解决',
        operator: '李四',
        time: '2024-01-16 09:15',
        color: '#00b42a',
      });
    }

    return records.reverse();
  });

  // 处理状态变更
  const handleStatusChange = (value: number) => {
    if (value === props.status) {
      Message.warning('不能变更为相同的状态');
      selectedStatus.value = undefined;
      return;
    }

    emit('change', value);
    selectedStatus.value = undefined;
  };
</script>

<style scoped lang="less">
  .status-card {
    background: var(--color-bg-2);
    border-radius: 8px;
    padding: 16px;
    box-shadow: 0 1px 2px rgba(0, 0, 0, 0.05);

    .card-header {
      margin-bottom: 16px;
      padding-bottom: 12px;
      border-bottom: 1px solid var(--color-border-2);

      .card-title {
        display: flex;
        align-items: center;
        gap: 8px;
        font-size: 15px;
        font-weight: 600;
        color: var(--color-text-1);
      }
    }

    .card-body {
      display: flex;
      flex-direction: column;
      gap: 16px;

      .current-status {
        .status-label {
          font-size: 12px;
          color: var(--color-text-3);
          margin-bottom: 8px;
        }

        .status-value {
          :deep(.arco-tag) {
            font-size: 14px;
            padding: 4px 12px;
          }
        }
      }

      .status-change {
        .change-label {
          font-size: 12px;
          color: var(--color-text-3);
          margin-bottom: 8px;
        }

        .status-option {
          display: flex;
          align-items: center;
          gap: 8px;

          .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
          }
        }
      }

      .status-history {
        .history-title {
          display: flex;
          align-items: center;
          gap: 6px;
          font-size: 13px;
          font-weight: 500;
          color: var(--color-text-1);
          margin-bottom: 12px;
        }

        .history-list {
          display: flex;
          flex-direction: column;
          gap: 12px;

          .history-item {
            display: flex;
            gap: 10px;

            .history-dot {
              width: 10px;
              height: 10px;
              border-radius: 50%;
              margin-top: 4px;
              flex-shrink: 0;
            }

            .history-content {
              flex: 1;

              .history-status {
                font-size: 13px;
                font-weight: 500;
                color: var(--color-text-1);
                margin-bottom: 4px;
              }

              .history-meta {
                display: flex;
                justify-content: space-between;
                font-size: 12px;
                color: var(--color-text-3);

                .history-operator {
                  color: var(--color-primary);
                }
              }
            }
          }
        }
      }
    }
  }
</style>
