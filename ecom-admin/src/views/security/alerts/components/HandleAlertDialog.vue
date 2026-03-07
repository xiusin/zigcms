<template>
  <a-modal
    v-model:visible="visible"
    title="处理告警"
    :width="600"
    @ok="handleSubmit"
    @cancel="handleCancel"
  >
    <a-form :model="form" layout="vertical">
      <a-form-item label="处理结果" required>
        <a-radio-group v-model="form.action">
          <a-radio value="resolve">标记已处理</a-radio>
          <a-radio value="ignore">忽略</a-radio>
          <a-radio value="escalate">升级</a-radio>
        </a-radio-group>
      </a-form-item>
      
      <a-form-item label="处理说明" required>
        <a-textarea
          v-model="form.comment"
          placeholder="请输入处理说明"
          :rows="4"
          :max-length="500"
          show-word-limit
        />
      </a-form-item>
      
      <a-form-item v-if="form.action === 'escalate'" label="升级至">
        <a-select v-model="form.escalateTo" placeholder="选择升级对象">
          <a-option value="security_team">安全团队</a-option>
          <a-option value="ops_team">运维团队</a-option>
          <a-option value="dev_team">开发团队</a-option>
        </a-select>
      </a-form-item>
      
      <a-form-item label="附件">
        <a-upload
          action="/api/upload"
          :file-list="form.attachments"
          @change="handleFileChange"
        >
          <template #upload-button>
            <a-button>
              <icon-upload />
              上传附件
            </a-button>
          </template>
        </a-upload>
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import { IconUpload } from '@arco-design/web-vue/es/icon';
import type { Alert, HandleAlertDto } from '@/types/security';
import { useSecurityStore } from '@/store/modules/security';

const props = defineProps<{
  modelValue: boolean;
  alert: Alert | null;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', value: boolean): void;
  (e: 'success'): void;
}>();

const securityStore = useSecurityStore();
const visible = ref(props.modelValue);

const form = reactive({
  action: 'resolve' as 'resolve' | 'ignore' | 'escalate',
  comment: '',
  escalateTo: '',
  attachments: [] as any[]
});

watch(() => props.modelValue, (val) => {
  visible.value = val;
});

watch(visible, (val) => {
  emit('update:modelValue', val);
});

const handleFileChange = (fileList: any[]) => {
  form.attachments = fileList;
};

const handleSubmit = async () => {
  if (!props.alert) return;
  
  if (!form.comment.trim()) {
    Message.warning('请输入处理说明');
    return;
  }
  
  if (form.action === 'escalate' && !form.escalateTo) {
    Message.warning('请选择升级对象');
    return;
  }
  
  try {
    const dto: HandleAlertDto = {
      action: form.action,
      comment: form.comment,
      escalate_to: form.action === 'escalate' ? form.escalateTo : undefined
    };
    
    await securityStore.handleAlert(props.alert.id!, dto);
    Message.success('处理成功');
    emit('success');
    handleCancel();
  } catch (error) {
    Message.error('处理失败');
  }
};

const handleCancel = () => {
  visible.value = false;
  form.action = 'resolve';
  form.comment = '';
  form.escalateTo = '';
  form.attachments = [];
};
</script>

<style scoped lang="less">
// 样式
</style>
