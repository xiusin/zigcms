<template>
  <div class="assignee-card">
    <div class="card-header">
      <div class="card-title">
        <icon-user />
        指派信息
      </div>
    </div>

    <div class="card-body">
      <!-- 当前指派者 -->
      <div class="current-assignee">
        <div class="assignee-label">当前指派</div>
        <div v-if="assigneeId" class="assignee-info">
          <a-avatar :size="40" :src="assigneeAvatar">
            <template #default>{{ assigneeName?.charAt(0) }}</template>
          </a-avatar>
          <div class="assignee-detail">
            <div class="assignee-name">{{ assigneeName }}</div>
            <div class="assignee-role">处理人</div>
          </div>
        </div>
        <div v-else class="no-assignee">
          <a-avatar :size="40" style="background-color: var(--color-fill-3)">
            <icon-question />
          </a-avatar>
          <div class="no-assignee-text">暂未指派</div>
        </div>
      </div>

      <!-- 指派选择器 -->
      <div class="assignee-select">
        <div class="select-label">重新指派</div>
        <a-select
          v-model="selectedAssignee"
          placeholder="选择处理人"
          style="width: 100%"
          allow-search
          @change="handleAssigneeChange"
        >
          <a-option
            v-for="user in assigneeOptions"
            :key="user.id"
            :value="user.id"
            :label="user.name"
          >
            <div class="assignee-option">
              <a-avatar :size="24" :src="user.avatar">
                <template #default>{{ user.name?.charAt(0) }}</template>
              </a-avatar>
              <span class="option-name">{{ user.name }}</span>
              <span v-if="user.count" class="option-count">{{ user.count }}个待处理</span>
            </div>
          </a-option>
        </a-select>
      </div>

      <!-- 指派历史 -->
      <div v-if="history.length > 0" class="assignee-history">
        <div class="history-title">
          <icon-history />
          指派历史
        </div>
        <div class="history-list">
          <div
            v-for="(record, index) in history"
            :key="index"
            class="history-item"
          >
            <a-avatar :size="28" :src="record.avatar">
              <template #default>{{ record.name?.charAt(0) }}</template>
            </a-avatar>
            <div class="history-content">
              <div class="history-name">{{ record.name }}</div>
              <div class="history-time">{{ record.time }}</div>
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { IconUser, IconQuestion, IconHistory } from '@arco-design/web-vue/es/icon';

interface Props {
  assigneeId?: number;
  assigneeName?: string;
  assigneeAvatar?: string;
}

const props = defineProps<Props>();

const emit = defineEmits<{
  (e: 'change', assigneeId: number): void;
}>();

// 模拟处理人选项
const assigneeOptions = [
  { id: 1, name: '张三', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png', count: 5 },
  { id: 2, name: '李四', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png', count: 3 },
  { id: 3, name: '王五', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png', count: 8 },
  { id: 4, name: '赵六', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png', count: 2 },
  { id: 5, name: '钱七', avatar: 'https://cube.elemecdn.com/0/88/03b0d39583f48206768a7534e55bcpng.png', count: 6 },
];

// 当前选择的处理人
const selectedAssignee = ref<number | undefined>(undefined);

// 指派历史（模拟数据）
const history = computed(() => {
  const records: { name: string; avatar: string; time: string }[] = [];
  
  // 如果当前有指派，添加到历史
  if (props.assigneeId && props.assigneeName) {
    records.push({
      name: props.assigneeName,
      avatar: props.assigneeAvatar || '',
      time: '当前指派',
    });
  }
  
  // 添加历史记录
  if (props.assigneeId) {
    records.push({
      name: '系统',
      avatar: '',
      time: '2024-01-15 10:30',
    });
  }
  
  return records;
});

// 处理指派变更
const handleAssigneeChange = (value: number) => {
  if (value === props.assigneeId) {
    selectedAssignee.value = undefined;
    return;
  }
  
  emit('change', value);
  selectedAssignee.value = undefined;
};
</script>

<style scoped lang="less">
.assignee-card {
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

    .current-assignee {
      .assignee-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 10px;
      }

      .assignee-info {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px;
        background: var(--color-fill-1);
        border-radius: 8px;

        .assignee-detail {
          flex: 1;

          .assignee-name {
            font-size: 14px;
            font-weight: 500;
            color: var(--color-text-1);
            margin-bottom: 2px;
          }

          .assignee-role {
            font-size: 12px;
            color: var(--color-text-3);
          }
        }
      }

      .no-assignee {
        display: flex;
        align-items: center;
        gap: 12px;
        padding: 12px;
        background: var(--color-fill-1);
        border-radius: 8px;

        .no-assignee-text {
          font-size: 14px;
          color: var(--color-text-3);
        }
      }
    }

    .assignee-select {
      .select-label {
        font-size: 12px;
        color: var(--color-text-3);
        margin-bottom: 8px;
      }

      .assignee-option {
        display: flex;
        align-items: center;
        gap: 8px;

        .option-name {
          flex: 1;
        }

        .option-count {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }
    }

    .assignee-history {
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
        gap: 10px;

        .history-item {
          display: flex;
          align-items: center;
          gap: 10px;
          padding: 8px;
          background: var(--color-fill-1);
          border-radius: 6px;

          .history-content {
            flex: 1;

            .history-name {
              font-size: 13px;
              font-weight: 500;
              color: var(--color-text-1);
            }

            .history-time {
              font-size: 11px;
              color: var(--color-text-3);
            }
          }
        }
      }
    }
  }
}
</style>
