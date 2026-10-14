<template>
  <d-drawer
    title="
      提交入库
    "
    :ok-loading="loading"
    :visible="visible"
    ok-text="提交入库"
    width="860px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <ConsignmentForm
      ref="consignmentFormRef"
      :hide-footer="true"
      :init-data="thisFormData"
      @submit-success="submitSuccess"
    ></ConsignmentForm>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import ConsignmentForm from '@/views/operation/consignment-manage/consignment-form.vue';

  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    id: null,
    company_id: 1,
    department_id: 1,
    delete_ids: [],
    products: [
      {
        brand_id: null,
        style_id: null,
        size_id: null,
        color_id: null,
        element_id: null,
        num: null,
        remark: null,
        anchor_id: null,
        price: null,
        imgurl: null,
      },
    ],
  });

  const thisFormData: any = ref(defaultForm());
  const loading = ref(false);
  const isEditFlag = ref(false);
  const visible = ref(false);
  const consignmentFormRef = ref();
  const emits = defineEmits(['createOver']);

  const route = useRoute();
  const router = useRouter();
  // 关闭回调
  function onClose() {
    visible.value = false;
  }
  function sendInfo() {
    consignmentFormRef.value.sendInfo();
  }

  const submitSuccess = () => {
    emits('createOver');
    onClose();
  };

  // 打开抽屉
  async function show(item: any) {
    visible.value = true;
    isEditFlag.value = false;
    thisFormData.value = defaultForm();
    if (item && item.id) {
      isEditFlag.value = true;
      Object.assign(thisFormData.value, item);
    }
  }

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

  .shop-card {
    border: 1px solid var(--color-border-1);
    width: 100%;
    min-height: 300px;
    border-radius: 10px;
    margin-bottom: 20px;
    // &.warning {
    //   border-color: rgb(var(--warning-6));
    // }
    // &.success {
    //   border-color: rgb(var(--success-6));
    // }
    .shop-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 20px 5px;
      font-size: 16px;
      border-bottom: 1px solid var(--color-border-1);
      margin-bottom: 5px;
    }
    .shop-body {
      padding: 5px 20px;
    }
    .wrap-box {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 400px;
      width: 100%;
      background: var(--color-fill-1);
      border-radius: 8px;
      &.warning {
        border: 1px solid rgb(var(--warning-6));
      }
      &.success {
        border: 1px solid rgb(var(--success-6));
      }
    }
  }
</style>
