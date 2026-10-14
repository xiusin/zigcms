<template>
  <d-modal
    :visible="visible"
    unmount-on-close
    :simple="false"
    :title="title"
    :mask-closable="false"
    title-align="start"
    :ok-loading="okLoading"
    width="460px"
    @cancel="handleCancel"
    @ok="handleBeforeOk"
  >
    <a-form ref="formRef" class="mt-10" :model="formModel" auto-label-width>
      <a-form-item
        field="dir_name"
        label="文件夹名称"
        :rules="[{ required: true, message: '请输入' }]"
      >
        <a-input
          v-model="formModel.dir_name"
          autocomplete="off"
          placeholder="请输入"
        />
      </a-form-item>

      <a-form-item
        field="parent_id"
        label="上级文件夹"
        :rules="[{ required: false, message: '请选择上级文件夹' }]"
      >
        <folder-tree-select
          v-model="formModel.parent_id"
          :tree-data="treeData"
        ></folder-tree-select>
      </a-form-item>
    </a-form>
  </d-modal>
</template>

<script lang="ts" setup>
  import { computed, ref, watch } from 'vue';
  import { FormInstance } from '@arco-design/web-vue/es/form';
  import DModal from '@/components/d-modal/d-modal.vue';
  import request from '@/api/request';
  import FolderTreeSelect from '@/components/fold-tree/folder-tree-select.vue';

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
    treeData: {
      type: [Array],
      default: null,
    },
  });
  const emit = defineEmits(['update:modelValue', 'refresh']);
  const formRef = ref<FormInstance>();

  const generateFormModel = () => {
    return {
      dir_name: '',
      parent_id: 0,
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
      request(props.api, { ...formModel.value, ...props.sendParams })
        .then(() => {
          handleCancel();
          emit('refresh');
        })
        .finally(() => {
          okLoading.value = false;
        });
    }
  };
  const title = computed(() => {
    return `${formModel.value.id ? '编辑' : '添加'}文件夹`;
  });
  defineExpose({
    show,
  });
</script>

<style lang="less"></style>
