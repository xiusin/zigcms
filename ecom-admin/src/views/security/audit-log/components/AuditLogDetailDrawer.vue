<template>
  <a-drawer
    v-model:visible="visible"
    title="审计日志详情"
    :width="720"
    :footer="false"
  >
    <div v-if="log" class="audit-log-detail">
      <!-- 基本信息 -->
      <a-card title="基本信息" :bordered="false" class="section-card">
        <a-descriptions :column="2" bordered>
          <a-descriptions-item label="日志ID">
            {{ log.id }}
          </a-descriptions-item>
          <a-descriptions-item label="状态">
            <a-tag :color="log.status === 'success' ? 'green' : 'red'">
              {{ log.status === 'success' ? '成功' : '失败' }}
            </a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="操作用户">
            {{ log.username || '-' }}
          </a-descriptions-item>
          <a-descriptions-item label="用户ID">
            {{ log.user_id || '-' }}
          </a-descriptions-item>
          <a-descriptions-item label="操作类型" :span="2">
            {{ log.action }}
          </a-descriptions-item>
          <a-descriptions-item label="资源类型">
            {{ getResourceTypeText(log.resource_type) }}
          </a-descriptions-item>
          <a-descriptions-item label="资源ID">
            {{ log.resource_id || '-' }}
          </a-descriptions-item>
          <a-descriptions-item label="操作时间" :span="2">
            {{ formatTime(log.created_at) }}
          </a-descriptions-item>
        </a-descriptions>
      </a-card>
      
      <!-- 请求信息 -->
      <a-card title="请求信息" :bordered="false" class="section-card">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="IP地址">
            {{ log.ip_address || '-' }}
          </a-descriptions-item>
          <a-descriptions-item label="User Agent">
            <div class="user-agent">{{ log.user_agent || '-' }}</div>
          </a-descriptions-item>
          <a-descriptions-item label="请求方法">
            <a-tag>{{ log.request_method || '-' }}</a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="请求路径">
            <code>{{ log.request_path || '-' }}</code>
          </a-descriptions-item>
        </a-descriptions>
      </a-card>
      
      <!-- 变更详情 -->
      <a-card v-if="log.changes" title="变更详情" :bordered="false" class="section-card">
        <pre class="json-pre">{{ formatJSON(log.changes) }}</pre>
      </a-card>
      
      <!-- 错误信息 -->
      <a-card v-if="log.error_message" title="错误信息" :bordered="false" class="section-card">
        <a-alert type="error" :message="log.error_message" />
      </a-card>
      
      <!-- 操作按钮 -->
      <div class="action-buttons">
        <a-space>
          <a-button @click="exportLog">
            导出详情
          </a-button>
          <a-button @click="copyLogId">
            复制ID
          </a-button>
        </a-space>
      </div>
    </div>
  </a-drawer>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { AuditLog } from '@/types/security';

const props = defineProps<{
  modelValue: boolean;
  log: AuditLog | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
}>();

const visible = ref(props.modelValue);

watch(() => props.modelValue, (val) => {
  visible.value = val;
});

watch(visible, (val) => {
  emit('update:modelValue', val);
});

const getResourceTypeText = (type: string) => {
  const types: Record<string, string> = {
    test_case: '测试用例',
    project: '项目',
    module: '模块',
    requirement: '需求',
    feedback: '反馈',
    user: '用户',
    role: '角色'
  };
  return types[type] || type;
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

const exportLog = () => {
  if (!props.log) return;
  
  const data = JSON.stringify(props.log, null, 2);
  const blob = new Blob([data], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `audit-log-${props.log.id}.json`;
  a.click();
  URL.revokeObjectURL(url);
  Message.success('导出成功');
};

const copyLogId = () => {
  if (!props.log) return;
  
  navigator.clipboard.writeText(String(props.log.id));
  Message.success('已复制日志ID');
};
</script>

<style scoped lang="less">
.audit-log-detail {
  .section-card {
    margin-bottom: 16px;
    
    &:last-child {
      margin-bottom: 0;
    }
  }
  
  .user-agent {
    word-break: break-all;
    font-size: 12px;
    color: var(--color-text-2);
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
  
  .action-buttons {
    margin-top: 24px;
    padding-top: 16px;
    border-top: 1px solid var(--color-border-2);
  }
}
</style>
