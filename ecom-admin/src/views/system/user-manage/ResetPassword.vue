<template>
  <d-drawer
    :visible="visible"
    :ok-loading="loading"
    title="重置密码"
    width="360px"
    @ok="saveThisInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" layout="vertical">
      <a-form-item label="账号" field="username">
        <a-input
          v-model:model-value="thisFormData.username"
          :disabled="true"
          allow-clear
        />
      </a-form-item>
      <a-form-item label="密码" field="password" :rules="requiredRules">
        <a-input-password
          v-model="thisFormData.password"
          allow-clear
        ></a-input-password>
      </a-form-item>
      <a-form-item label="确认密码" field="rpassword" :rules="requiredRules">
        <a-input-password
          v-model="thisFormData.rpassword"
          allow-clear
        ></a-input-password>
      </a-form-item>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { ref } from 'vue';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import request from '@/api/request';
  import DDrawer from '@/components/d-modal/d-drawer.vue';

  const defaultForm = () => ({
    id: '',
    username: undefined,
    password: '',
    rpassword: '',
  });
  const requiredRules: FieldRule = {
    required: true,
    message: '请填写',
  };
  const thisFormData = ref(defaultForm());
  const loading = ref(false);
  const visible = ref(false);
  const thisFormRef = ref();

  // 重置表单
  function resetThisForm() {
    thisFormData.value = defaultForm();
    // 移除表单项的校验结果
    thisFormRef.value.clearValidate();
  }

  // 关闭回调
  function onClose() {
    visible.value = false;
    resetThisForm();
  }

  // 提交信息
  function saveThisInfo() {
    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        if (thisFormData.value.password !== thisFormData.value.rpassword) {
          Message.error('两次输入的密码不一致');
          return null;
        }
        thisFormData.value.username = undefined;
        loading.value = true;
        request('/api/system/admin/resetPassword', thisFormData.value)
          .then(() => {
            onClose();
            Message.success('操作成功');
          })
          .finally(() => {
            loading.value = false;
          });
      }
    });
  }
  // 打开抽屉
  function show(item: any) {
    if (item && item.id) {
      thisFormData.value.id = item.id;
      thisFormData.value.username = item.username;
    }
    visible.value = true;
  }

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped></style>
