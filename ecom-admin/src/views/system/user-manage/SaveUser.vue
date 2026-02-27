<template>
  <d-drawer
    :title="isEditFlag ? '编辑用户' : '新建用户'"
    :ok-loading="loading"
    :visible="visible"
    width="560px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" layout="vertical">
      <a-spin :loading="loading">
        <a-row :gutter="16">
          <a-col :span="24">
            <a-form-item
              label="成员名称"
              field="username"
              :rules="requiredRules"
            >
              <a-input
                v-model="thisFormData.username"
                placeholder="请输入"
                allow-clear
              />
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item
              label="授权角色"
              field="role_ids"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.role_ids"
                request-url="/api/common/roles"
                label-key="role_name"
                :multiple="true"
                value-key="id"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-form-item
            v-if="thisFormData.role_ids && thisFormData.role_ids.includes(19)"
            label="供应商"
            field="supplier_id"
            :rules="requiredRules"
          >
            <base-request-select
              v-model="thisFormData.supplier_id"
              request-url="/api/supplier/list"
              label-key="supplier_name"
              value-key="id"
              :send-params="{ no_page: true }"
            ></base-request-select>
          </a-form-item>
          <a-col :span="24">
            <a-form-item label="手机号码" field="mobile" :rules="requiredRules">
              <a-input
                v-model="thisFormData.mobile"
                placeholder="请输入"
                allow-clear
              />
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item label="邮箱" field="email" :rules="requiredRules">
              <a-input
                v-model:model-value="thisFormData.email"
                allow-clear
                placeholder="请输入"
                autocomplete="off"
              />
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item label="密码" field="password" :rules="requiredRules">
              <a-input
                v-model="thisFormData.password"
                placeholder="请输入"
                allow-clear
                autocomplete="new-password"
              ></a-input>
            </a-form-item>
          </a-col>
        </a-row>
      </a-spin>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import request from '@/api/request';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    id: '',
    username: null,
    role_ids: null,
    supplier_id: null,
    mobile: null,
    email: null,
    password: null,
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
  }

  const route = useRoute();
  const router = useRouter();
  // 关闭回调
  function onClose() {
    if (route.query.add) {
      router.replace({ query: {} });
    }
    visible.value = false;
    resetThisForm();
  }
  function sendInfo() {
    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        const params: any = unref(thisFormData);
        if (isEditFlag.value) {
          // delete params.password;
        } else {
          delete params.id;
        }
        loading.value = true;

        request('/api/member/save', params)
          .then(() => {
            Message.success('操作成功');
            onClose();
            emits('createOver');
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
    thisFormData.value = defaultForm();
    if (item && item.id) {
      isEditFlag.value = true;
      Object.assign(thisFormData.value, item);
      // loading.value = true;
      // let resData = await request('/api/userInfo', { id: item.id });
      // loading.value = false;
      // let userData = resData.data;
      // // 根据map取值
      // let lastResData: any = {};
      // let defaultVal = null;
      // Object.keys(defaultForm()).forEach((key) => {
      //   defaultVal = thisFormData.value[key as keyof typeof thisFormData.value];
      //   if (key === 'password') {
      //     defaultVal = '******';
      //   }
      //   lastResData[key] = userData[key] ?? defaultVal;
      // });
      // thisFormData.value = lastResData;
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
</style>
