<template>
  <div class="content-box">
    <a-card class="generate-card no-padding">
      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入流水码"
        @hand-submit="handleSubmit"
      ></SearchForm>
    </a-card>

    <a-card class="table-card">
      <!--示例布局 暂时保留-->
      <div class="c-table-tool">
        <a-space class="c-table-tool-item"> </a-space>
        <a-space class="c-table-tool-item">
          <a-button-group>
            <a-button
              size="small"
              :loading="exportLoading"
              @click="exportHandler"
            >
              <template #icon>
                <icon-export />
              </template>
              导出
            </a-button>
          </a-button-group>
        </a-space>
      </div>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #company_id>
          <div> 鹏景 </div>
        </template>
        <template #department_id>
          <div> 实物电商A部 </div>
        </template>
      </base-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';

  const user = useUserStore();

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '流水码',
      align: 'left',
      dataIndex: 'serial_id',
      fixed: 'left',
    },
    {
      title: '流水子码',
      align: 'left',
      dataIndex: 'sub_serial_id',
    },
    {
      title: '事件ID',
      align: 'left',
      dataIndex: 'desc',
    },
    {
      title: '商品ID',
      align: 'left',
      dataIndex: 'product_no',
    },
    {
      title: '操作说明',
      align: 'left',
      dataIndex: 'mark',
    },
    {
      title: '操作人',
      align: 'left',
      dataIndex: 'user_name',
    },
    {
      title: '操作时间',
      align: 'center',
      dataIndex: 'created_at',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
      user_name: '',
      event_code: null,
      serial_id: null,
      sub_serial_id: null,
      product_no: null,
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'serial_id',
      label: '流水码',
      value: null,
      width: '160px',
    },
  ]);
  const searchRules: any = ref([
    // {
    //   field: 'event_code',
    //   label: '事件码',
    //   value: null,
    //   component_name: 'base-dict-select',
    //   attr: {
    //     selectType: 'flowsDict',
    //   },
    // },
    {
      field: 'sub_serial_id',
      label: '流水子码',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'product_no',
      label: '商品ID',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'user_name',
      label: '操作人',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/flow/list', data);
  };

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  function saveAction(record: any) {
    saveRef.value?.show(record);
  }

  // 导出
  const exportLoading = ref(false);
  const exportHandler = async () => {
    exportLoading.value = true;
    try {
      await tableRef.value.exportTable();
      exportLoading.value = false;
    } catch (err) {
      exportLoading.value = false;
    }
  };
</script>

<style scoped lang="less">
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }

  :deep(.arco-table-element thead) {
    position: sticky;
    top: 0px;
    z-index: 100;
  }

  :deep(
      .arco-scrollbar-container.arco-table-content.arco-table-content-scroll-x
    ) {
    overflow: scroll;
    height: calc(100vh - 280px);
    min-height: 300px;
  }
</style>
