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

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :hoverable="false"
        :server-pagination="false"
        :send-params="{
          ...formModel,
          tab_type: type,
        }"
      >
        <template #brand_name="{ record }">
          <div> {{ record.brand_en_name }}-{{ record.brand_name }} </div>
        </template>
        <template #styles="{ record }">
          <div class="styles-box">
            <span
              v-for="(item, index) in record.styles"
              :key="index"
              class="single-box"
            >
              <a-tag
                class="mb-10 cur-por"
                :color="
                  item.dict_data.same_style &&
                  item.dict_data.selling_point &&
                  item.dict_data.style_history &&
                  item.dict_data.usage_scenario &&
                  item.dict_data.trial_population &&
                  'green'
                "
                @click="saveAction(record, item)"
              >
                <template #icon>
                  <icon-eye
                    v-if="
                      item.dict_data.same_style &&
                      item.dict_data.selling_point &&
                      item.dict_data.style_history &&
                      item.dict_data.usage_scenario &&
                      item.dict_data.trial_population
                    "
                  />
                  <icon-edit v-else />
                </template>
                {{ item.dict_name }}
              </a-tag>
            </span>
            <span class="single-box">
              <a-tag
                class="mb-10 cur-por"
                color="arcoblue"
                @click="saveAction(record)"
              >
                <template #icon>
                  <icon-plus />
                </template>
                新增
              </a-tag>
            </span>
          </div>
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
  import { computed, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from './style-code-form.vue';

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '品牌名称',
      align: 'left',
      dataIndex: 'brand_name',
    },
    {
      title: '系列',
      align: 'left',
      dataIndex: 'styles',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
      brand_name: '',
      brand_id: '',
      style_id: '',
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
    tableRef.value?.search();
  };

  const getDataList = (data: any) => {
    return request('/api/dict/styles', data);
  };

  function saveAction(record: any, item: any = {}) {
    saveRef.value?.show(
      JSON.parse(
        JSON.stringify({
          ...record,
          ...item,
        })
      )
    );
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

  .styles-box {
    padding: 5px 0;
    max-width: 900px;
    .single-box {
      padding: 5px 5px 5px 0;
      margin-bottom: 5px;
    }
  }
</style>
