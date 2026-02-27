<template>
  <a-modal
    :title="isEditFlag ? '编辑商品详情' : '新建商品详情'"
    :ok-loading="loading"
    :visible="visible"
    width="520px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" auto-label-width>
      <a-spin :loading="loading">
        <a-row :gutter="12">
          <a-col :span="24">
            <a-form-item label="排序" field="sort">
              <a-input
                v-model="thisFormData.sort"
                placeholder="请输入"
                allow-clear
              />
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item label="组件名称" field="title" :rules="requiredRules">
              <a-input
                v-model="thisFormData.title"
                placeholder="请输入"
                allow-clear
              />
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item
              label="组件内容"
              field="url"
              :rules="{
                required: true,
                message: '上传组件内容',
              }"
            >
              <base-image-upload
                v-model="thisFormData.url"
                :limit="1"
              ></base-image-upload>
            </a-form-item>
          </a-col>
        </a-row>
      </a-spin>
    </a-form>
  </a-modal>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import request from '@/api/request';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    title: '',
    sort: '',
    url: [],
  });
  const requiredRules: FieldRule = {
    required: true,
    message: '请填写',
  };
  const thisFormData: any = ref(defaultForm());
  const loading = ref(false);
  const isEditFlag = ref(false);
  const visible = ref(false);
  const thisFormRef = ref();
  const emits = defineEmits(['createOver']);

  // 重置表单
  function resetThisForm() {
    // 移除表单项的校验结果
    thisFormRef.value.clearValidate();
    thisFormData.value = defaultForm();
  }

  const route = useRoute();

  // 关闭回调
  function onClose() {
    visible.value = false;
    resetThisForm();
  }
  function sendInfo() {
    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        const unParams: any = unref(thisFormData);
        let params: any = JSON.parse(JSON.stringify(unParams));
        if (params.url && params.url.length > 0) {
          params.content = {
            data: {
              url: params.url[0].url,
            },
            type: 'image',
          };
          delete params.url;
        }

        loading.value = true;
        request('/api/product/detail/option/save', params)
          .then(() => {
            onClose();
            emits('createOver');
            Message.success('操作成功');
          })
          .finally(() => {
            loading.value = false;
          });
      }
    });
  }

  // 打开抽屉
  async function show(item: any) {
    visible.value = true;
    isEditFlag.value = false;

    if (item && item.id) {
      isEditFlag.value = true;
      Object.assign(thisFormData.value, item);
      if (item?.content?.data?.url) {
        thisFormData.value.url = [
          {
            url: item?.content?.data?.url || '',
          },
        ];
      }
    } else {
      thisFormData.value = defaultForm();
    }
  }

  onMounted(() => {
    if (route.query.add) {
      show({});
    }
  });

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
    // min-height: 300px;
    border-radius: 10px;
    margin-bottom: 20px;
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
    }
  }
  .dis-flex {
    display: flex;
    align-items: center;
  }
</style>
