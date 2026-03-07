<template>
  <a-modal
    v-model:visible="modalVisible"
    :title="isEdit ? '编辑规则' : '新建规则'"
    width="800px"
    @before-ok="handleSubmit"
    @cancel="handleCancel"
  >
    <a-form :model="form" layout="vertical">
      <a-form-item label="规则名称" required>
        <a-input v-model="form.name" placeholder="请输入规则名称" />
      </a-form-item>

      <a-form-item label="规则描述">
        <a-textarea
          v-model="form.description"
          placeholder="请输入规则描述"
          :rows="3"
        />
      </a-form-item>

      <a-row :gutter="16">
        <a-col :span="8">
          <a-form-item label="规则类型" required>
            <a-select v-model="form.rule_type" placeholder="请选择规则类型">
              <a-option value="brute_force">暴力破解</a-option>
              <a-option value="sql_injection">SQL注入</a-option>
              <a-option value="xss">XSS攻击</a-option>
              <a-option value="csrf">CSRF攻击</a-option>
              <a-option value="rate_limit">频率限制</a-option>
              <a-option value="abnormal_access">异常访问</a-option>
              <a-option value="custom">自定义</a-option>
            </a-select>
          </a-form-item>
        </a-col>

        <a-col :span="8">
          <a-form-item label="告警级别" required>
            <a-select v-model="form.level" placeholder="请选择告警级别">
              <a-option value="critical">严重</a-option>
              <a-option value="high">高危</a-option>
              <a-option value="medium">中危</a-option>
              <a-option value="low">低危</a-option>
            </a-select>
          </a-form-item>
        </a-col>

        <a-col :span="8">
          <a-form-item label="优先级">
            <a-input-number
              v-model="form.priority"
              :min="0"
              :max="1000"
              placeholder="数字越大优先级越高"
            />
          </a-form-item>
        </a-col>
      </a-row>

      <a-form-item label="规则条件" required>
        <ConditionBuilder v-model="form.conditions" />
      </a-form-item>

      <a-form-item label="触发动作" required>
        <ActionConfig v-model="form.actions" />
      </a-form-item>

      <a-form-item label="启用规则">
        <a-switch v-model="form.enabled" />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as alertRuleApi from '@/api/alert-rule';
import type { AlertRule, RuleCondition, RuleAction } from '@/types/alert-rule';
import ConditionBuilder from './ConditionBuilder.vue';
import ActionConfig from './ActionConfig.vue';

const props = defineProps<{
  visible: boolean;
  rule: AlertRule | null;
}>();

const emit = defineEmits<{
  (e: 'update:visible', value: boolean): void;
  (e: 'success'): void;
}>();

const modalVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value),
});

const isEdit = computed(() => !!props.rule?.id);

const form = ref({
  name: '',
  description: '',
  rule_type: '',
  level: 'medium' as any,
  conditions: [] as RuleCondition[],
  actions: [] as RuleAction[],
  enabled: true,
  priority: 100,
});

// 监听 rule 变化
watch(
  () => props.rule,
  (rule) => {
    if (rule) {
      form.value = {
        name: rule.name,
        description: rule.description,
        rule_type: rule.rule_type,
        level: rule.level,
        conditions: typeof rule.conditions === 'string'
          ? JSON.parse(rule.conditions)
          : rule.conditions,
        actions: typeof rule.actions === 'string'
          ? JSON.parse(rule.actions)
          : rule.actions,
        enabled: rule.enabled,
        priority: rule.priority,
      };
    } else {
      form.value = {
        name: '',
        description: '',
        rule_type: '',
        level: 'medium',
        conditions: [],
        actions: [],
        enabled: true,
        priority: 100,
      };
    }
  },
  { immediate: true }
);

const handleSubmit = async () => {
  try {
    if (isEdit.value) {
      await alertRuleApi.updateAlertRule(props.rule!.id!, form.value);
      Message.success('更新成功');
    } else {
      await alertRuleApi.createAlertRule(form.value);
      Message.success('创建成功');
    }
    emit('success');
    return true;
  } catch (error) {
    Message.error('操作失败');
    return false;
  }
};

const handleCancel = () => {
  modalVisible.value = false;
};
</script>
