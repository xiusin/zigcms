<template>
  <d-drawer
    :title="isEditFlag ? '编辑服务商' : '创建服务商'"
    :ok-loading="loading"
    :visible="visible"
    width="560px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" layout="vertical">
      <a-spin :loading="loading">
        <a-card title="基本信息" class="drawer-card">
          <a-row :gutter="12">
            <a-col :span="12">
              <a-form-item
                label="服务商名称"
                field="name"
                :rules="requiredRules"
              >
                <a-input
                  v-model="thisFormData.name"
                  placeholder="请输入"
                  allow-clear
                />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="销售负责人">
                <request-select
                  v-model="thisFormData.business_user_id"
                  api="user"
                  label-key="realname"
                  :send-param="{ role_id: 2, state: 1, is_about_me: false }"
                ></request-select>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="网址">
                <a-input
                  v-model="thisFormData.website"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="24">
              <a-form-item label="备注">
                <a-textarea
                  v-model="thisFormData.remark"
                  placeholder="请输入"
                  allow-clear
                ></a-textarea>
              </a-form-item>
            </a-col>
          </a-row>
        </a-card>
        <a-card class="mt-10" title="地区定位">
          <a-row :gutter="12">
            <a-col :span="24">
              <a-form-item label="省市区">
                <city-select v-model="thisFormData.area"></city-select>
              </a-form-item>
            </a-col>
            <a-col :span="24">
              <a-form-item label="详细地址">
                <a-input
                  v-model="thisFormData.address"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
          </a-row>
        </a-card>

        <a-card class="mt-10" title="第一联系人">
          <a-row :gutter="12">
            <a-col :span="12">
              <a-form-item label="姓名">
                <a-input
                  v-model="thisFormData.contacts[0].username"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="角色职务">
                <a-input
                  v-model="thisFormData.contacts[0].role_name"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="邮件">
                <a-input
                  v-model="thisFormData.contacts[0].email"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="手机联系方式">
                <a-input
                  v-model="thisFormData.contacts[0].phone"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="微信">
                <a-input
                  v-model="thisFormData.contacts[0].wechat"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="生日">
                <a-date-picker
                  v-model="thisFormData.contacts[0].birthday"
                  format="YYYY-MM-DD"
                  value-format="YYYY-MM-DD"
                ></a-date-picker>
              </a-form-item>
            </a-col>
            <a-col :span="24">
              <a-form-item label="寄件地址">
                <a-input
                  v-model="thisFormData.contacts[0].address"
                  placeholder="请输入"
                  allow-clear
                ></a-input>
              </a-form-item>
            </a-col>
            <a-col :span="24">
              <a-form-item label="名片">
                <upload-image-file
                  v-model="thisFormData.contacts[0].cards"
                  :send-params="{ type: 'product_logo' }"
                  multiple
                  file-type="image/*"
                ></upload-image-file>
              </a-form-item>
            </a-col>
            <a-col :span="24">
              <a-form-item label="备注">
                <a-textarea
                  v-model="thisFormData.contacts[0].remark"
                  placeholder="请输入"
                  allow-clear
                ></a-textarea>
              </a-form-item>
            </a-col>
          </a-row>
        </a-card>
      </a-spin>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import request from '@/api/request';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import RequestSelect from '@/components/select/request-select.vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import CitySelect from '@/components/select/city-select.vue';
  import UploadImageFile from '@/components/upload-file/upload-image-file.vue';
  import { cloneDeep } from 'lodash';
  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    id: '',
    business_user_id: '',
    short_name: '',
    name: '',
    website: '',
    address: '',
    business_type: '',
    remark: '',
    area: {
      country: '中国',
      province: '',
      city: '',
      area: '',
    },
    contacts: [
      {
        username: '',
        media_type: '',
        agent_type: '',
        sex: '',
        role_name: '',
        email: '',
        phone: '',
        wechat: '',
        birthday: '',
        address: '',
        cards: [],
        remark: '',
      },
    ],
  });
  const requiredRules: FieldRule = {
    required: true,
    message: '请填写',
  };
  const thisFormData = ref(defaultForm());
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
        if (!isEditFlag.value) {
          delete params.id;
        }
        loading.value = true;

        request('/api/supplierSave', params)
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
      // 根据map取值
      let lastResData: any = {};
      Object.keys(defaultForm()).forEach((key) => {
        let defaultVal =
          thisFormData.value[key as keyof typeof thisFormData.value];
        lastResData[key] = item[key] ?? defaultVal;
      });
      thisFormData.value = cloneDeep(lastResData);
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
