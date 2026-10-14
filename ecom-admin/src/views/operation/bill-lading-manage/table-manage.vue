<template>
  <div class="content-box">
    <a-card class="generate-card no-padding">
      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入货盘期号"
        @hand-submit="handleSubmit"
      ></SearchForm>
    </a-card>

    <a-card class="table-card">
      <div class="table-card-header">
        <a-space>
          <a-button size="small" type="primary" @click="saveAction(null)">
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
        :send-params="formModel"
      >
        <template #company_id>
          <div> 鹏景 </div>
        </template>
        <template #department_id>
          <div> 实物电商A部 </div>
        </template>
        <template #action="{ record }">
          <a-link @click="showPreviewRecord(record)">
            <icon-eye />
            预览
          </a-link>
          <a-divider direction="vertical" />
          <a-link @click="showPreviewDownloadRecord(record)">
            <icon-download />
            下载
          </a-link>
        </template>
      </base-table>
    </a-card>
    <AddEditForm ref="saveRef" @create-over="handleSubmit()" />
    <ModalPreviewForm ref="ModalPreviewFormRef"></ModalPreviewForm>
    <ModalDownPrintForm ref="ModalDownPrintFormRef"></ModalDownPrintForm>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from '@/views/operation/bill-lading-manage/add-edit-form.vue';
  import ModalPreviewForm from './modal-preview-form.vue';
  import ModalDownPrintForm from './modal-down-print-form.vue';

  const user = useUserStore();

  const ModalPreviewFormRef = ref();
  const showPreviewRecord = (record: any) => {
    ModalPreviewFormRef.value.show(record);
  };

  // 下载打印表 版本
  const ModalDownPrintFormRef = ref();
  const showPreviewDownloadRecord = (record: any) => {
    ModalDownPrintFormRef.value.show(record);
  };

  const tableRef = ref();
  const saveRef = ref();
  const saveAccountRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '提货表编码',
      align: 'center',
      dataIndex: 'pickup_no',
      fixed: 'left',
    },
    {
      title: '货盘期号',
      align: 'center',
      dataIndex: 'demand_no',
    },
    {
      title: '供应商',
      align: 'center',
      dataIndex: 'supplier_name',
    },
    {
      title: '供应商地点',
      align: 'left',
      dataIndex: 'supplier_address',
    },
    {
      title: '供应商联系人',
      align: 'center',
      dataIndex: 'supplier_person',
    },
    {
      title: '供应商联系电话',
      align: 'center',
      dataIndex: 'supplier_mobile',
    },
    {
      title: '提货单位',
      align: 'center',
      dataIndex: 'company_id',
    },
    {
      title: '提货人',
      align: 'center',
      dataIndex: 'receiver_name',
    },
    {
      title: '提货人电话',
      align: 'center',
      dataIndex: 'receiver_mobile',
    },
    {
      title: '提货时间',
      align: 'center',
      dataIndex: 'pickup_time',
    },
    {
      title: '货盘需求表创建时间',
      align: 'center',
      dataIndex: 'created_at',
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
      field: 'demand_no',
      label: '货盘期号',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    // {
    //   field: 'demand_no',
    //   label: '货盘期号',
    //   value: null,
    //   component_name: 'base-input',
    // },
    // {
    //   field: 'is_open_saas_d',
    //   label: '货盘需求单位',
    //   value: null,
    //   component_name: 'base-dict-select',
    //   attr: {
    //     selectType: 'openSass',
    //   },
    // },
    // {
    //   field: 'is_open_saas_d',
    //   label: '货盘需求部门',
    //   value: null,
    //   component_name: 'base-dict-select',
    //   attr: {
    //     selectType: 'openSass',
    //   },
    // },
    {
      field: 'user_id',
      label: '理货人',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/pickup/list', data);
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
</script>

<style scoped lang="less">
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }
</style>
