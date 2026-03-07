<template>
  <div class="action-config">
    <div v-for="(action, index) in actions" :key="index" class="action-item">
      <a-card>
        <template #title>
          <a-space>
            <span>动作 {{ index + 1 }}</span>
            <a-button
              type="text"
              size="small"
              status="danger"
              @click="removeAction(index)"
            >
              <template #icon><icon-delete /></template>
            </a-button>
          </a-space>
        </template>

        <a-form-item label="动作类型">
          <a-select v-model="action.action_type" placeholder="请选择动作类型">
            <a-option value="alert">发送告警</a-option>
            <a-option value="block">阻断请求</a-option>
            <a-option value="notify">发送通知</a-option>
            <a-option value="log">记录日志</a-option>
          </a-select>
        </a-form-item>

        <!-- 告警配置 -->
        <template v-if="action.action_type === 'alert'">
          <a-form-item label="告警级别">
            <a-select v-model="action.params.level">
              <a-option value="critical">严重</a-option>
              <a-option value="high">高危</a-option>
              <a-option value="medium">中危</a-option>
              <a-option value="low">低危</a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="告警消息">
            <a-input v-model="action.params.message" placeholder="请输入告警消息" />
          </a-form-item>

          <a-form-item label="通知渠道">
            <a-checkbox-group v-model="action.params.channels">
              <a-checkbox value="websocket">WebSocket</a-checkbox>
              <a-checkbox value="email">邮件</a-checkbox>
              <a-checkbox value="dingtalk">钉钉</a-checkbox>
            </a-checkbox-group>
          </a-form-item>
        </template>

        <!-- 阻断配置 -->
        <template v-if="action.action_type === 'block'">
          <a-form-item label="阻断时长（秒）">
            <a-input-number
              v-model="action.params.duration"
              :min="60"
              :max="86400"
              placeholder="阻断时长"
            />
          </a-form-item>

          <a-form-item label="阻断原因">
            <a-input v-model="action.params.reason" placeholder="请输入阻断原因" />
          </a-form-item>
        </template>

        <!-- 通知配置 -->
        <template v-if="action.action_type === 'notify'">
          <a-form-item label="通知用户">
            <a-input v-model="action.params.users" placeholder="用户ID，多个用逗号分隔" />
          </a-form-item>

          <a-form-item label="通知消息">
            <a-textarea
              v-model="action.params.message"
              placeholder="请输入通知消息"
              :rows="3"
            />
          </a-form-item>
        </template>

        <!-- 日志配置 -->
        <template v-if="action.action_type === 'log'">
          <a-form-item label="日志级别">
            <a-select v-model="action.params.level">
              <a-option value="error">错误</a-option>
              <a-option value="warn">警告</a-option>
              <a-option value="info">信息</a-option>
              <a-option value="debug">调试</a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="日志消息">
            <a-input v-model="action.params.message" placeholder="请输入日志消息" />
          </a-form-item>
        </template>
      </a-card>
    </div>

    <a-button type="dashed" @click="addAction">
      <template #icon><icon-plus /></template>
      添加动作
    </a-button>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { RuleAction } from '@/types/alert-rule';

const props = defineProps<{
  modelValue: RuleAction[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: RuleAction[]): void;
}>();

const actions = ref<RuleAction[]>([]);

watch(
  () => props.modelValue,
  (value) => {
    actions.value = value.length > 0 ? value : [createEmptyAction()];
  },
  { immediate: true }
);

watch(
  actions,
  (value) => {
    emit('update:modelValue', value);
  },
  { deep: true }
);

function createEmptyAction(): RuleAction {
  return {
    action_type: 'alert',
    params: {
      level: 'medium',
      message: '',
      channels: ['websocket'],
    },
  };
}

function addAction() {
  actions.value.push(createEmptyAction());
}

function removeAction(index: number) {
  actions.value.splice(index, 1);
  if (actions.value.length === 0) {
    actions.value.push(createEmptyAction());
  }
}
</script>

<style scoped lang="scss">
.action-config {
  .action-item {
    margin-bottom: 16px;
  }
}
</style>
