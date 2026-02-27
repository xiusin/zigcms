<template>
  <div class="content-box">
    <a-card class="table-card">
      <!-- <div class="mb-10">
        <SearchForm
          :form-data="formModel"
          :get-default-form-data="generateFormModel"
          :search-rules="searchRules"
          :base-search-rules="baseSearchRules"
          placeholder="请输入品牌名称"
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
            <icon-edit />
            编辑
          </a-link>
        </template>
        <template #brand_icon="{ record }">
          <span v-if="!record.brand_icon"> - </span>
          <a-image
            v-else
            height="80"
            width="80"
            :src="record.brand_icon"
            :preview="true"
          ></a-image>
        </template>
        <template #content="{ record }">
          <a-typography-paragraph
            :ellipsis="{
              suffix: '',
              rows: 3,
              expandable: true,
            }"
            >{{ record.content }}
          </a-typography-paragraph>
        </template>
      </base-table>
    </a-card>
    <AddEditForm
      ref="saveRef"
      :hide-footer="type !== 1"
      @create-over="handleSubmit()"
    />
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from './brand-code-form.vue';

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
      title: '品牌中文',
      align: 'left',
      dataIndex: 'brand_name',
    },
    {
      title: '品牌英文',
      align: 'left',
      dataIndex: 'brand_en_name',
      width: 180,
    },
    {
      title: 'logo',
      align: 'center',
      dataIndex: 'brand_icon',
    },
    {
      title: '品牌介绍',
      align: 'left',
      dataIndex: 'content',
      width: 240,
    },
    {
      title: '操作',
      align: 'left',
      dataIndex: 'action',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
      name: '',
      user_id: '',
      is_open_saas: '',
      is_open_saas_d: '',
      user_name: '',
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'brand_name',
      label: '品牌名称',
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
    return request('/api/brand/list', data);
  };

  function saveAction(record: any) {
    saveRef.value?.show({
      ...record,
      brand_icon: [{ url: record.brand_icon }],
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
