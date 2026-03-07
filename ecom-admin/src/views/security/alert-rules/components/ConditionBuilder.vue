<template>
  <div class="condition-builder">
    <div v-for="(condition, index) in conditions" :key="index" class="condition-item">
      <a-space>
        <a-select
          v-model="condition.field"
          placeholder="字段"
          style="width: 150px"
        >
          <a-option value="event_type">事件类型</a-option>
          <a-option value="count">次数</a-option>
          <a-option value="time_window">时间窗口</a-option>
          <a-option value="client_ip">客户端IP</a-option>
          <a-option value="user_id">用户ID</a-option>
          <a-option value="request_path">请求路径</a-option>
          <a-option value="request_body">请求体</a-option>
        </a-select>

        <a-select
          v-model="condition.operator"
          placeholder="操作符"
          style="width: 120px"
        >
          <a-option value="eq">等于</a-option>
          <a-option value="ne">不等于</a-option>
          <a-option value="gt">大于</a-option>
          <a-option value="lt">小于</a-option>
          <a-option value="gte">大于等于</a-option>
          <a-option value="lte">小于等于</a-option>
          <a-option value="contains">包含</a-option>
          <a-option value="regex">正则匹配</a-option>
        </a-select>

        <a-input
          v-model="condition.value"
          placeholder="值"
          style="width: 200px"
        />

        <a-select
          v-if="index < conditions.length - 1"
          v-model="condition.logic"
          placeholder="逻辑"
          style="width: 100px"
        >
          <a-option value="and">AND</a-option>
          <a-option value="or">OR</a-option>
        </a-select>

        <a-button
          type="text"
          status="danger"
          @click="removeCondition(index)"
        >
          <template #icon><icon-delete /></template>
        </a-button>
      </a-space>
    </div>

    <a-button type="dashed" @click="addCondition">
      <template #icon><icon-plus /></template>
      添加条件
    </a-button>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import type { RuleCondition } from '@/types/alert-rule';

const props = defineProps<{
  modelValue: RuleCondition[];
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: RuleCondition[]): void;
}>();

const conditions = ref<RuleCondition[]>([]);

watch(
  () => props.modelValue,
  (value) => {
    conditions.value = value.length > 0 ? value : [createEmptyCondition()];
  },
  { immediate: true }
);

watch(
  conditions,
  (value) => {
    emit('update:modelValue', value);
  },
  { deep: true }
);

function createEmptyCondition(): RuleCondition {
  return {
    field: '',
    operator: 'eq',
    value: '',
    logic: 'and',
  };
}

function addCondition() {
  conditions.value.push(createEmptyCondition());
}

function removeCondition(index: number) {
  conditions.value.splice(index, 1);
  if (conditions.value.length === 0) {
    conditions.value.push(createEmptyCondition());
  }
}
</script>

<style scoped lang="scss">
.condition-builder {
  .condition-item {
    margin-bottom: 12px;
  }
}
</style>
