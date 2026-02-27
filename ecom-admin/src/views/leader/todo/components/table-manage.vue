<template>
  <div class="content-box">
    <a-card class="table-wrap" :body-style="{ padding: '10px 0 0 0' }">
      <div style="padding: 0 16px 16px">
        <a-tabs
          v-model="type"
          :destroy-on-hide="true"
          :lazy-load="true"
          @change="handlerTabChange"
        >
          <a-tab-pane :key="1">
            <template #title>
              <a-badge :count="totalTodo" dot>
                <span class="mr-5"> 待审核 </span>
              </a-badge>
            </template>
          </a-tab-pane>
          <a-tab-pane :key="2">
            <template #title>已审核</template>
          </a-tab-pane>
          <a-tab-pane :key="3">
            <template #title>我发起的</template>
          </a-tab-pane>
        </a-tabs>
        <div class="mt-10">
          <SearchForm
            :form-data="formModel"
            :get-default-form-data="generateFormModel"
            :search-rules="searchRules"
            :base-search-rules="baseSearchRules"
            placeholder="请输入货盘期号"
            @hand-submit="handleSubmit"
          ></SearchForm>
        </div>
      </div>
    </a-card>

    <a-card class="table-card">
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
  import TodoHeader from './todo-header.vue';
  import AddEditForm from './add-edit-form.vue';

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '审核类型',
      align: 'left',
      dataIndex: 'type_name',
      fixed: 'left',
    },
    {
      title: '商品编码',
      align: 'left',
      dataIndex: 'product_no',
    },
    {
      title: '品牌',
      align: 'left',
      dataIndex: 'brand_name',
    },
    {
      title: '入库价格',
      align: 'left',
      dataIndex: 'in_warehouse_price',
    },
    {
      title: '商品定价',
      align: 'left',
      dataIndex: 'price',
    },

    {
      title: '发起人',
      align: 'left',
      dataIndex: 'user_name',
    },
    {
      title: '发起时间',
      align: 'left',
      dataIndex: 'created_at',
    },
    {
      title: '审核状态',
      align: 'left',
      dataIndex: 'status_text',
    },
    {
      title: '审核处理人',
      align: 'left',
      dataIndex: 'approval_user_name',
    },
    {
      title: '操作',
      align: 'center',
      dataIndex: 'action',
      fixed: 'right',
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
      field: 'product_name',
      label: '商品名称',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    {
      field: 'product_no',
      label: '商品编码',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'product_no',
      label: '入库编码',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'brand_name',
      label: '品牌',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'user_name',
      label: '发起人',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const totalTodo = ref(0);
  // 顶部tab切换
  const type: any = ref(1);
  // 分类参数不参与重置
  const moduleStr: any = ref('全部');
  const formModel: any = ref(generateFormModel());

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const handlerTabChange = (tab: any) => {
    type.value = tab;
    formModel.value.type = type.value;
    moduleStr.value = '全部';
    formModel.value.module = '全部';
    handleSubmit();
  };
  const handleHeader = (moduleTemp: any) => {
    moduleStr.value = moduleTemp;
    formModel.value.module = moduleTemp;
  };

  const getDataList = (data: any) => {
    return request('/api/approval/list', data);
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
