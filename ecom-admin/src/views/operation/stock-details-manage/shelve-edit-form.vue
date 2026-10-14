<template>
  <d-drawer
    title="
      上架申请单
    "
    :ok-loading="loading"
    :visible="visible"
    ok-text="提交上架"
    width="860px"
    @cancel="onClose"
  >
    <OutShelveForm
      ref="outConsignmentFormRef"
      :hide-footer="true"
      :init-data="thisFormData"
      :can-over-wright="thisFormData.canOverWright"
      @submit-success="submitSuccess"
    ></OutShelveForm>
    <template #footer>
      <a-space>
        <a-button size="small" @click="onClose"> 取消 </a-button>
        <a-button size="small" type="primary" @click="sendInfo">
          提交上架
        </a-button>
      </a-space>
    </template>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref } from 'vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import OutShelveForm from '@/views/operation/stock-details-manage/out-shelve-form.vue';

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
    canOverWright: false,
  });
  const thisFormData: any = ref(defaultForm());
  const loading = ref(false);
  const isEditFlag = ref(false);
  const visible = ref(false);
  const emits = defineEmits(['createOver']);
  const outConsignmentFormRef = ref();

  const route = useRoute();
  // 关闭回调
  function onClose() {
    visible.value = false;
  }

  const sendInfo = () => {
    outConsignmentFormRef.value.sendInfo();
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
