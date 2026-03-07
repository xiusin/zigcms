<template>
  <a-drawer
    v-model:visible="visible"
    title="告警详情"
    :width="720"
    :footer="false"
  >
    <div v-if="alert" class="alert-detail">
      <!-- 基本信息 -->
      <a-card title="基本信息" :bordered="false" class="section-card">
        <a-descriptions :column="2" bordered>
          <a-descriptions-item label="告警ID">
            {{ alert.id }}
          </a-descriptions-item>
          <a-descriptions-item label="级别">
            <a-tag :color="getLevelColor(alert.level)">
              {{ getLevelText(alert.level) }}
            </a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="类型">
            {{ getTypeText(alert.type) }}
          </a-descriptions-item>
          <a-descriptions-item label="状态">
            <a-tag :color="getStatusColor(alert.status)">
              {{ getStatusText(alert.status) }}
            </a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="触发时间" :span="2">
            {{ formatTime(alert.created_at) }}
          </a-descriptions-item>
          <a-descriptions-item label="消息" :span="2">
            {{ alert.message }}
          </a-descriptions-item>
        </a-descriptions>
      </a-card>
      
      <!-- 详细信息 -->
      <a-card title="详细信息" :bordered="false" class="section-card">
        <pre class="json-pre">{{ formatJSON(alert.details) }}</pre>
      </a-card>
      
      <!-- 关联事件 -->
      <a-card title="关联事件" :bordered="false" class="section-card">
        <a-timeline v-if="relatedEvents.length > 0">
          <a-timeline-item
            v-for="event in relatedEvents"
            :key="event.id"
          >
            <template #dot>
              <icon-exclamation-circle
                :style="{ color: getLevelColor(event.level) }"
              />
            </template>
            <div class="event-item">
              <div class="event-header">
                <span class="event-type">{{ event.event_type }}</span>
                <span class="event-time">{{ formatTime(event.created_at) }}</span>
              </div>
              <div class="event-desc">{{ event.description }}</div>
            </div>
          </a-timeline-item>
        </a-timeline>
        <a-empty v-else description="暂无关联事件" />
      </a-card>

      <!-- 处理记录 -->
      <a-card v-if="alert.handled_at" title="处理记录" :bordered="false" class="section-card">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="处理人">
            {{ alert.handled_by || '-' }}
          </a-descriptions-item>
          <a-descriptions-item label="处理时间">
            {{ formatTime(alert.handled_at) }}
          </a-descriptions-item>
          <a-descriptions-item label="处理说明">
            {{ alert.handle_comment || '-' }}
          </a-descriptions-item>
        </a-descriptions>
      </a-card>
      
      <!-- 操作按钮 -->
      <div class="action-buttons">
        <a-space>
          <a-button
            v-if="alert.status === 'pending'"
            type="primary"
            @click="handleAlert"
          >
            处理告警
          </a-button>
          <a-button @click="exportAlert">
            导出详情
          </a-button>
          <a-button @click="copyAlertId">
            复制ID
          </a-button>
        </a-space>
      </div>
    </div>
  </a-drawer>
</template>

<script setup lang="ts">
import { ref, watch, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import { IconExclamationCircle } from '@arco-design/web-vue/es/icon';
import type { Alert, SecurityEvent } from '@/types/security';
import { ALERT_LEVEL_LABELS, ALERT_LEVEL_COLORS, ALERT_TYPE_LABELS, ALERT_STATUS_LABELS, ALERT_STATUS_COLORS } from '@/types/security';

const props = defineProps<{
  modelValue: boolean;
  alert: Alert | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'handle', alert: Alert): void;
}>();

const visible = ref(props.modelValue);
const relatedEvents = ref<SecurityEvent[]>([]);

watch(() => props.modelValue, (val) => {
  visible.value = val;
  if (val && props.alert) {
    loadRelatedEvents();
  }
});

watch(visible, (val) => {
  emit('update:modelValue', val);
});

const loadRelatedEvents = async () => {
  // TODO: 加载关联事件
  relatedEvents.value = [];
};

const getLevelColor = (level: string) => {
  return ALERT_LEVEL_COLORS[level] || 'blue';
};

const getLevelText = (level: string) => {
  return ALERT_LEVEL_LABELS[level] || level;
};

const getTypeText = (type: string) => {
  return ALERT_TYPE_LABELS[type] || type;
};

const getStatusColor = (status: string) => {
  return ALERT_STATUS_COLORS[status] || 'blue';
};

const getStatusText = (status: string) => {
  return ALERT_STATUS_LABELS[status] || status;
};

const formatTime = (time: string) => {
  return new Date(time).toLocaleString('zh-CN');
};

const formatJSON = (json: any) => {
  try {
    if (typeof json === 'string') {
      return JSON.stringify(JSON.parse(json), null, 2);
    }
    return JSON.stringify(json, null, 2);
  } catch {
    return json;
  }
};

const handleAlert = () => {
  if (props.alert) {
    emit('handle', props.alert);
  }
};

const exportAlert = () => {
  if (!props.alert) return;
  
  const data = JSON.stringify(props.alert, null, 2);
  const blob = new Blob([data], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `alert-${props.alert.id}.json`;
  a.click();
  URL.revokeObjectURL(url);
  Message.success('导出成功');
};

const copyAlertId = () => {
  if (!props.alert) return;
  
  navigator.clipboard.writeText(String(props.alert.id));
  Message.success('已复制告警ID');
};
</script>

<style scoped lang="less">
.alert-detail {
  .section-card {
    margin-bottom: 16px;
    
    &:last-child {
      margin-bottom: 0;
    }
  }
  
  .json-pre {
    background: var(--color-fill-2);
    padding: 12px;
    border-radius: 4px;
    font-size: 12px;
    max-height: 400px;
    overflow: auto;
    font-family: 'Courier New', monospace;
  }
  
  .event-item {
    .event-header {
      display: flex;
      justify-content: space-between;
      margin-bottom: 4px;
      
      .event-type {
        font-weight: 500;
        color: var(--color-text-1);
      }
      
      .event-time {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }
    
    .event-desc {
      font-size: 13px;
      color: var(--color-text-2);
    }
  }
  
  .action-buttons {
    margin-top: 24px;
    padding-top: 16px;
    border-top: 1px solid var(--color-border-2);
  }
}
</style>
