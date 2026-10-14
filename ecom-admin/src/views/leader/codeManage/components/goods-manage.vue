<template>
  <div class="content-box">
    <a-card class="table-card">
      <div class="mb-10">
        <SearchForm
          :form-data="formModel"
          :get-default-form-data="generateFormModel"
          :search-rules="searchRules"
          :base-search-rules="baseSearchRules"
          placeholder="请输入品牌名称"
          @hand-submit="handleSubmit"
          @change-cache-form-data="changeCacheFormData"
        ></SearchForm>
      </div>
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
        <template #imgurl="{ record }">
          <span v-if="!record.imgurl"> - </span>
          <a-image
            v-else
            height="80"
            width="80"
            :src="`${record.imgurl}?x-oss-process=image/auto-orient,1/resize,p_50/quality,q_90`"
            :preview="true"
            show-loader
          ></a-image>
        </template>
      </base-table>
    </a-card>
    <AddEditForm
      ref="saveRef"
      :hide-footer="type !== 1"
      @create-over="refreshTable()"
    />
  </div>
</template>

<script setup lang="ts">
  import { computed, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from './good-code-form.vue';

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
      title: '图片',
      align: 'center',
      dataIndex: 'imgurl',
    },
    {
      title: '品牌',
      align: 'left',
      dataIndex: 'brand_name',
    },
    {
      title: '系列名称',
      align: 'left',
      dataIndex: 'style_name',
    },
    {
      title: '商品规格',
      align: 'left',
      dataIndex: 'size_name',
    },
    {
      title: '颜色',
      align: 'left',
      dataIndex: 'color_name',
    },
    {
      title: '材质',
      align: 'left',
      dataIndex: 'element_name',
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
      brand_name: '',
      style_name: '',
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
  // 分类参数不参与重置
  const formModel: any = ref(generateFormModel());
  const cacheFormData = ref();
  const searchRules: any = computed(() => {
    return [
      {
        field: 'brand_id',
        label: '品牌',
        value: null,
        component_name: 'base-request-select',
        watch: true,
        attr: {
          requestUrl: '/api/brand/list',
          labelKey: 'brand_name',
          sendParams: {
            no_page: true,
          },
        },
      },
      {
        field: 'style_id',
        label: '系列名称',
        value: null,
        component_name: 'base-request-select',
        attr: {
          requestUrl: '/api/dict/list',
          labelKey: 'dict_name',
          sendParams: {
            no_page: true,
            brand_id: cacheFormData.value?.brand_id || formModel.value.brand_id,
            group_key: 'style',
          },
        },
      },
    ];
  });

  const changeCacheFormData = (cacheformdata: any) => {
    cacheFormData.value = cacheformdata;
  };

  // 顶部tab切换
  const type: any = ref(1);

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    setTimeout(() => {
      tableRef.value?.search();
    }, 200);
  };

  const refreshTable = () => {
    tableRef.value?.fetchData();
  };

  const getDataList = (data: any) => {
    return request('/api/template/list', data);
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
