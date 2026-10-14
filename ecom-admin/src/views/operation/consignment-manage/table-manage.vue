<template>
  <div class="content-box">
    <a-card class="generate-card">
      <template v-if="!successFlag">
        <div class="form-title"> 新增入库单 </div>
        <a-divider class="mb-10" />
        <div class="form-body">
          <ConsignmentForm @submit-success="submitSuccess"></ConsignmentForm>
        </div>
      </template>

      <a-result v-else class="result-box" status="success" title="入库单已提交">
        <template #extra>
          <a-space>
            <a-button size="small" type="primary" @click="goStock"
              >确定</a-button
            >
          </a-space>
        </template>
      </a-result>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import ConsignmentForm from '@/views/operation/consignment-manage/consignment-form.vue';
  import router from '@/router';

  const loading = ref(false);
  const emit = defineEmits(['update:modelValue', 'refresh']);
  const successFlag = ref(false);

  const goStock = () => {
    router.push({
      name: 'stockDetailsManage',
    });
  };

  async function submitSuccess() {
    loading.value = true;
    successFlag.value = true;
  }
</script>

<style scoped lang="less">
  .form-title {
    padding: 10px;
    display: flex;
    justify-content: center;
    font-size: 18px;
    font-weight: bold;
    margin-bottom: 10px;
  }
  .form-body {
    margin: 20px 10%;
    .footer-wrap {
      display: flex;
      justify-content: center;
      .button-box {
        width: 100%;
        margin-top: 20px;
      }
    }
  }

  :deep(.arco-checkbox-group .arco-checkbox) {
    margin-bottom: 12px;
  }

  .generate-card {
    min-height: 70vh;
    .result-box {
      margin-top: 20vh;
    }
  }
</style>
