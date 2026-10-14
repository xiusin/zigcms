<template>
  <d-drawer
    title="
      出库申请单
    "
    :ok-loading="loading"
    :visible="visible"
    ok-text="同意申请"
    cancel-text="拒绝申请"
    width="860px"
    :esc-to-close="false"
    :cancel-button-props="{
      type: 'primary',
      status: 'danger',
    }"
    :footer="!hideFooter"
    @ok="sendInfo"
    @cancel="denyInfo"
  >
    <a-spin :loading="loading">
      <ApprovalConsignmentForm
        ref="approvalConsignmentFormRef"
        :hide-footer="true"
        :init-data="thisFormData"
        @submit-success="submitSuccess"
      ></ApprovalConsignmentForm>
    </a-spin>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { ref } from 'vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import ApprovalConsignmentForm from './approval-consignment-form.vue';
  import request from '@/api/request';

  const props = defineProps({
    hideFooter: {
      type: Boolean,
      default: () => false,
    },
  });

  const defaultForm = () => ({
    product_id: null,
  });
  const thisFormData: any = ref(defaultForm());
  const loading = ref(true);
  const isEditFlag = ref(false);
  const visible = ref(false);
  const emits = defineEmits(['createOver']);
  const approvalConsignmentFormRef = ref();

  // 关闭回调
  function onClose() {
    visible.value = false;
  }

  // 拒绝信息
  const denyInfo = (e: any) => {
    if (e.currentTarget.innerText) {
      approvalConsignmentFormRef.value.denyInfo();
    } else {
      onClose();
    }
  };

  const sendInfo = () => {
    approvalConsignmentFormRef.value.sendInfo();
  };

  // 查询详情
  const getInfoFn = async () => {
    loading.value = true;
    request('/api/warehouse/product/info', {
      id: thisFormData.value.product_id,
    }).then((res: any) => {
      if (res.code && res.code === 200) {
        res.data.created_at = thisFormData.value.created_at;
        res.data.user_name = thisFormData.value.user_name;
        thisFormData.value = res.data;
      }
      loading.value = false;
    });
  };

  // 打开抽屉
  async function show(item: any) {
    visible.value = true;
    isEditFlag.value = false;
    thisFormData.value = defaultForm();
    if (item && item.id) {
      isEditFlag.value = true;
      thisFormData.value.approval_id = item.id;
      thisFormData.value.product_id = item.product_id;
      thisFormData.value.created_at = item.created_at;
      thisFormData.value.user_name = item.user_name;
      getInfoFn();
    }
  }

  const submitSuccess = () => {
    emits('createOver');
    onClose();
  };

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped>
  .drawer-card {
    :deep(.arco-card-header) {
      padding-top: 0;
    }
  }
</style>
