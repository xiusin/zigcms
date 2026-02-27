<template>
  <a-modal
    :visible="visible"
    title="更改状态"
    :width="400"
    :mask-closable="false"
    @cancel="handleCancel"
    @before-ok="handleBeforeOk"
    @update:visible="(val) => emit('update:visible', val)"
  >
    <a-form ref="formRef" :model="formData" :rules="formRules" layout="vertical">
      <a-form-item field="status" label="新状态" required>
        <a-select v-model="formData.status" placeholder="请选择新状态">
          <a-option
            v-for="item in statusOptions"
            :key="item.value"
            :value="item.value"
          >
            <span class="status-dot" :style="{ backgroundColor: item.color }"></span>
            {{ item.label }}
          </a-option>
        </a-select>
      </a-form-item>

      <a-form-item field="remark" label="备注">
        <a-textarea
          v-model="formData.remark"
          placeholder="请输入状态变更备注（可选）..."
          :rows="3"
          :max-length="200"
          show-word-limit
        />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FormInstance } from '@arco-design/web-vue/es/form';
import { useFeedbackStore } from '@/store/modules/feedback';
import type { UpdateFeedbackStatusParams } from '@/api/feedback';
import { FeedbackStatus } from '@/api/feedback';

/** Props 定义 */
interface Props {
  /** 弹窗可见性 */
  visible: boolean;
  /** 反馈 ID 列表 */
  feedbackIds: number[];
}

const props = defineProps<Props>();

/** Emits 定义 */
const emit = defineEmits<{
  (e: 'update:visible', visible: boolean): void;
  (e: 'success'): void;
}>();

/** Store */
const feedbackStore = useFeedbackStore();

/** 表单引用 */
const formRef = ref<FormInstance>();

/** 表单数据 */
const formData = ref({
  status: undefined as number | undefined,
  remark: '',
});

/** 状态选项 */
const statusOptions = [
  { value: FeedbackStatus.PENDING, label: '待处理', color: '#86909c' },
  { value: FeedbackStatus.PROCESSING, label: '处理中', color: '#165dff' },
  { value: FeedbackStatus.RESOLVED, label: '已解决', color: '#00b42a' },
  { value: FeedbackStatus.CLOSED, label: '已关闭', color: '#86909c' },
  { value: FeedbackStatus.REJECTED, label: '已拒绝', color: '#f53f3f' },
];

/** 表单校验规则 */
const formRules = {
  status: [{ required: true, message: '请选择新状态' }],
};

/** 处理取消 */
const handleCancel = () => {
  emit('update:visible', false);
  resetForm();
};

/** 处理确认前 */
const handleBeforeOk = async (done: (closed: boolean) => void) => {
  const result = await formRef.value?.validate();
  if (result) {
    done(false);
    return;
  }

  if (props.feedbackIds.length === 0) {
    Message.error('未选择反馈');
    done(false);
    return;
  }

  try {
    // 批量更改状态
    const promises = props.feedbackIds.map((id) => {
      const params: UpdateFeedbackStatusParams = {
        id,
        status: formData.value.status!,
        remark: formData.value.remark,
      };
      return feedbackStore.updateFeedbackStatus(params);
    });

    const results = await Promise.all(promises);
    const allSuccess = results.every((res) => res.code === 0);

    if (allSuccess) {
      Message.success(`成功更新 ${props.feedbackIds.length} 条反馈的状态`);
      emit('success');
      done(true);
    } else {
      Message.error('部分更新失败，请重试');
      done(false);
    }
  } catch (error) {
    Message.error('更新失败');
    done(false);
  }
};

/** 重置表单 */
const resetForm = () => {
  formData.value = {
    status: undefined,
    remark: '',
  };
  formRef.value?.resetFields();
};

/** 监听 visible 变化 */
watch(
  () => props.visible,
  (newVal) => {
    if (newVal) {
      resetForm();
    }
  }
);
</script>

<style scoped lang="less">
.status-dot {
  display: inline-block;
  width: 8px;
  height: 8px;
  border-radius: 50%;
  margin-right: 6px;
}
</style>
