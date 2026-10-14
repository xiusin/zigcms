<template>
  <d-modal
    :visible="visible"
    unmount-on-close
    :simple="false"
    :mask-closable="false"
    title-align="start"
    :ok-loading="okLoading"
    :title="title"
    width="460px"
    @cancel="handleCancel"
    @ok="handleBeforeOk"
  >
    <a-form ref="formRef" class="mt-10" :model="formModel" auto-label-width>
      <a-form-item
        field="share_user_ids"
        label="用户"
        :rules="[{ required: true, type: 'array', message: '请选择' }]"
      >
        <request-select
          v-model="formModel.share_user_ids"
          api="user"
          :send-params="{ has_assistant: true, is_about_me: 0 }"
          multiple
        />
      </a-form-item>
    </a-form>
  </d-modal>
</template>

<script lang="ts" setup>
  import { computed, ref, watch } from 'vue';
  import { FormInstance } from '@arco-design/web-vue/es/form';
  import DModal from '@/components/d-modal/d-modal.vue';
  import request from '@/api/request';
  import RequestSelect from '@/components/select/request-select.vue';
  import { Message } from '@arco-design/web-vue';

  const props = defineProps({
    api: {
      type: String,
      default: null,
      required: true,
    },
    sendParams: {
      type: [Object],
      default: null,
    },
  });
  const emit = defineEmits(['update:modelValue', 'refresh']);
  const formRef = ref<FormInstance>();

  const generateFormModel = () => {
    return {
      dir_name: '',
      dir_id: '',
      share_user_ids: [],
    };
  };
  const formModel: any = ref(generateFormModel());

  const visible = ref(false);
  const okLoading = ref(false);
  const show = (data: any = {}) => {
    Object.assign(formModel.value, data);
    visible.value = true;
    okLoading.value = false;
  };

  const handleCancel = () => {
    visible.value = false;
    formModel.value = generateFormModel();
    formRef.value?.clearValidate();
  };
  const handleBeforeOk = async () => {
    const res = await formRef.value?.validate();
    if (!res) {
      okLoading.value = true;
      request(props.api, {
        ...formModel.value,
        ...props.sendParams,
        share_user_id: formModel.value.share_user_ids
          ? formModel.value.share_user_ids.join(',')
          : '',
      })
        .then(() => {
          Message.success('分享成功');
          handleCancel();
        })
        .finally(() => {
          okLoading.value = false;
        });
    }
  };
  const title = computed(() => {
    return `分享文件夹[${formModel.value.dir_name}]`;
  });
  defineExpose({
    show,
  });
</script>

<style lang="less"></style>
