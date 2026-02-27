<template>
  <d-drawer
    :title="isEditFlag ? '编辑商品码表' : '新建商品码表'"
    :ok-loading="loading"
    :visible="visible"
    :unmount-on-close="true"
    width="640px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" layout="vertical">
      <a-spin :loading="loading">
        <a-row :gutter="12">
          <a-col :span="24">
            <a-form-item label="品牌" field="brand_id" :rules="requiredRules">
              <base-request-select
                v-model="thisFormData.brand_id"
                request-url="/api/brand/list"
                label-key="brand_name"
                :send-params="{ no_page: true }"
                :disabled="isEditFlag"
                @change="changeBrand"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item
              label="系列名称"
              field="style_id"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.style_id"
                request-url="/api/dict/list"
                label-key="dict_name"
                :disabled="isEditFlag"
                :send-params="{
                  no_page: true,
                  brand_id: thisFormData.brand_id,
                  group_key: 'style',
                }"
              ></base-request-select>
            </a-form-item>
          </a-col>

          <a-form-item label="材质" field="element_id" :rules="requiredRules">
            <base-request-select
              v-model="thisFormData.element_id"
              request-url="/api/dict/list"
              label-key="dict_name"
              :disabled="isEditFlag"
              :send-params="{
                no_page: true,
                group_key: 'element',
              }"
            ></base-request-select>
          </a-form-item>

          <a-form-item label="颜色" :field="`color_id`" :rules="requiredRules">
            <base-request-select
              v-model="thisFormData.color_id"
              request-url="/api/dict/list"
              label-key="dict_name"
              :disabled="isEditFlag"
              :send-params="{
                no_page: true,
                group_key: 'color',
              }"
            ></base-request-select>
          </a-form-item>

          <a-col :span="24">
            <a-form-item
              label="商品规格"
              field="size_id"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.size_id"
                request-url="/api/dict/list"
                label-key="dict_name"
                :disabled="isEditFlag"
                :send-params="{
                  no_page: true,
                  group_key: 'size',
                }"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item
              label="商品图片"
              field="imgurl"
              :rules="{
                required: true,
                message: '请上传',
              }"
            >
              <base-image-upload
                v-model="thisFormData.imgurl"
                :limit="1"
                @change="validateFieldFn"
              ></base-image-upload>
            </a-form-item>
          </a-col>
        </a-row>
      </a-spin>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref, reactive } from 'vue';
  import request from '@/api/request';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    brand_id: null,
    style_id: null,
    size_id: null,
    color_id: null,
    element_id: null,
    imgurl: null,
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

  function changeBrand() {
    thisFormData.value.style_id = null;
  }

  const validateFieldFn = () => {
    thisFormRef.value.validateField('imgurl');
  };

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
        // 转码商品图片
        if (params.imgurl && params.imgurl.length > 0) {
          params.imgurl = params.imgurl[0].url;
        }

        loading.value = true;
        request('/api/template/save', params)
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
      if (thisFormData.value.imgurl) {
        thisFormData.value.imgurl = [
          {
            url: item.imgurl,
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
