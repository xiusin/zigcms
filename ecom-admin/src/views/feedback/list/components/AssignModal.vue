<template>
  <a-modal
    :visible="visible"
    title="指派反馈"
    :width="400"
    :mask-closable="false"
    @cancel="handleCancel"
    @before-ok="handleBeforeOk"
    @update:visible="(val) => emit('update:visible', val)"
  >
    <a-form ref="formRef" :model="formData" :rules="formRules" layout="vertical">
      <a-form-item field="handler_id" label="指派给" required>
        <a-select
          v-model="formData.handler_id"
          placeholder="请选择处理人"
          allow-clear
          :loading="loading"
        >
          <a-option v-for="user in userList" :key="user.id" :value="user.id">
            <div class="user-option">
              <a-avatar :size="20">
                <img v-if="user.avatar" :src="user.avatar" />
                <span v-else>{{ user.name?.charAt(0) }}</span>
              </a-avatar>
              <span class="user-name">{{ user.name }}</span>
              <span v-if="user.count" class="user-count">({{ user.count }}个待处理)</span>
            </div>
          </a-option>
        </a-select>
      </a-form-item>

      <a-form-item field="remark" label="备注">
        <a-textarea
          v-model="formData.remark"
          placeholder="请输入指派备注（可选）..."
          :rows="3"
          :max-length="200"
          show-word-limit
        />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FormInstance } from '@arco-design/web-vue/es/form';
import { useFeedbackStore } from '@/store/modules/feedback';
import type { AssignFeedbackParams } from '@/api/feedback';

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
  handler_id: undefined as number | undefined,
  remark: '',
});

/** 加载状态 */
const loading = ref(false);

/** 用户列表 */
const userList = ref<Array<{ id: number; name: string; avatar?: string; count?: number }>>([]);

/** 表单校验规则 */
const formRules = {
  handler_id: [{ required: true, message: '请选择处理人' }],
};

/** 加载处理人列表 */
const loadHandlers = async () => {
  loading.value = true;
  try {
    const res = await feedbackStore.fetchHandlerRanking();
    if (res.code === 0) {
      userList.value = res.data.list.map((item: any) => ({
        id: item.id,
        name: item.name,
        avatar: item.avatar,
        count: item.handle_count || 0,
      }));
    }
  } finally {
    loading.value = false;
  }
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
    // 批量指派
    const promises = props.feedbackIds.map((id) => {
      const params: AssignFeedbackParams = {
        id,
        handler_id: formData.value.handler_id!,
        remark: formData.value.remark,
      };
      return feedbackStore.assignFeedback(params);
    });

    const results = await Promise.all(promises);
    const allSuccess = results.every((res) => res.code === 0);

    if (allSuccess) {
      Message.success(`成功指派 ${props.feedbackIds.length} 条反馈`);
      emit('success');
      done(true);
    } else {
      Message.error('部分指派失败，请重试');
      done(false);
    }
  } catch (error) {
    Message.error('指派失败');
    done(false);
  }
};

/** 重置表单 */
const resetForm = () => {
  formData.value = {
    handler_id: undefined,
    remark: '',
  };
  formRef.value?.resetFields();
};

/** 监听 visible 变化 */
watch(
  () => props.visible,
  (newVal) => {
    if (newVal) {
      loadHandlers();
      resetForm();
    }
  }
);
</script>

<style scoped lang="less">
.user-option {
  display: flex;
  align-items: center;
  gap: 8px;

  .user-name {
    flex: 1;
  }

  .user-count {
    font-size: 12px;
    color: var(--color-text-3);
  }
}
</style>
