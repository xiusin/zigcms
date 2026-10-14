<template>
  <div class="content-box">
    <a-card class="table-card">
      <!-- <div class="mb-10">
        <SearchForm
          :form-data="formModel"
          :get-default-form-data="generateFormModel"
          :search-rules="searchRules"
          :base-search-rules="baseSearchRules"
          placeholder="请输入颜色名称"
          @hand-submit="handleSubmit"
        ></SearchForm>
      </div> -->
      <div class="table-card-header">
        <a-space>
          <a-button size="small" type="primary" @click="saveAction({})">
            <template #icon>
              <icon-plus />
            </template>
            新增
          </a-button>
        </a-space>
        <a-space class="c-table-tool-item"> </a-space>
      </div>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="{
          ...formModel,
          tab_type: type,
        }"
      >
        <template #action="{ record }">
          <a-link :disabled="record.pickup_num" @click="saveAction(record)">
            <icon-printer />
            详情
          </a-link>
        </template>
      </base-table>
    </a-card>
    <AddEditForm ref="saveRef" @create-over="handleSubmit()" />
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import AddEditForm from './color-code-form.vue';

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: 'ID',
      align: 'left',
      dataIndex: 'id',
      fixed: 'left',
    },
    {
      title: '颜色名称',
      align: 'left',
      dataIndex: 'dict_name',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
      group_key: 'color',
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'brand_name',
      label: '颜色名称',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    {
      field: 'brand_name',
      label: '品牌',
      value: null,
      component_name: 'base-input',
    },
  ]);

  // 顶部tab切换
  const type: any = ref(1);
  // 分类参数不参与重置
  const formModel: any = ref(generateFormModel());

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const getDataList = (data: any) => {
    return request('/api/dict/list', data);
  };

  function saveAction(record: any) {
    saveRef.value?.show({
      ...record,
    });
  }
</script>

<style scoped lang="less">
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }
  :deep(.arco-tabs-tab-title) {
    font-size: 15px;
  }
</style>
