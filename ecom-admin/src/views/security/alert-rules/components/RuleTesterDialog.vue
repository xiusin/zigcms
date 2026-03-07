<template>
  <a-modal
    v-model:visible="modalVisible"
    title="测试规则"
    width="600px"
    @before-ok="handleTest"
  >
    <a-alert type="info" style="margin-bottom: 16px">
      输入测试数据，验证规则是否能正确匹配
    </a-alert>

    <a-form layout="vertical">
      <a-form-item label="测试数据（JSON格式）">
        <a-textarea
          v-model="testData"
          placeholder='{"event_type": "login_failed", "count": 6, "time_window": 200}'
          :rows="10"
        />
      </a-form-item>
    </a-form>

    <a-divider />

    <div v-if="testResult !== null" class="test-result">
      <a-result
        :status="testResult.matched ? 'success' : 'error'"
        :title="testResult.matched ? '规则匹配成功' : '规则匹配失败'"
      >
        <template #subtitle>
          <div v-if="testResult.matched">
            测试数据满足规则条件，将触发配置的动作
          </div>
          <div v-else>
            测试数据不满足规则条件，不会触发任何动作
          </div>
        </template>
      </a-result>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as alertRuleApi from '@/api/alert-rule';
import type { AlertRule, TestAlertRuleResult } from '@/types/alert-rule';

const props = defineProps<{
  visible: boolean;
  rule: AlertRule | null;
}>();

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void;
}>();

const modalVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value),
});

const testData = ref('');
const testResult = ref<TestAlertRuleResult | null>(null);

const handleTest = async () => {
  if (!props.rule?.id) {
    Message.error('规则ID不存在');
    return false;
  }

  try {
    const data = JSON.parse(testData.value);
    const result = await alertRuleApi.testAlertRule(props.rule.id, {
      test_data: data,
    });
    testResult.value = result;
    return false; // 不关闭对话框
  } catch (error) {
    if (error instanceof SyntaxError) {
      Message.error('JSON 格式错误');
    } else {
      Message.error('测试失败');
    }
    return false;
  }
};
</script>

<style scoped lang="scss">
.test-result {
  margin-top: 20px;
}
</style>
