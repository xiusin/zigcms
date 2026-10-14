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
      <!-- <div class="table-card-header">
        <a-space>
          <a-button size="small" type="primary" @click="saveAction(null)">
            <template #icon>
              <icon-plus />
            </template>
            新增
          </a-button>
        </a-space>
        <a-space class="c-table-tool-item"> </a-space>
      </div> -->
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
  import AddEditForm from '@/views/operation/return-lading-manage/add-edit-form.vue';
  import ModalPreviewForm from './modal-preview-form.vue';
  import ModalDownPrintForm from './modal-down-print-form.vue';
  import { useRoute } from 'vue-router';

  const route = useRoute();
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
      title: '返货单编码',
      align: 'center',
      dataIndex: 'refund_no',
      fixed: 'left',
    },
    {
      title: '供应商',
      align: 'center',
      dataIndex: 'supplier_name',
    },
    {
      title: '供应商地点',
      align: 'left',
      dataIndex: 'address',
    },
    {
      title: '供应商联系人',
      align: 'center',
      dataIndex: 'person',
    },
    {
      title: '供应商联系电话',
      align: 'center',
      dataIndex: 'mobile',
    },
    {
      title: '返货单位',
      align: 'center',
      dataIndex: 'refund_unit',
    },
    {
      title: '返货人',
      align: 'center',
      dataIndex: 'user_name',
    },
    {
      title: '返货人电话',
      align: 'center',
      dataIndex: 'user_mobile',
    },
    {
      title: '返货时间',
      align: 'center',
      dataIndex: 'refund_date',
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
      date: route.params.date || null,
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'refund_no',
      label: '返货单编码',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    {
      field: 'supplier_id',
      label: '供应商',
      value: null,
      component_name: 'base-request-select',
      attr: {
        requestUrl: '/api/supplier/list',
        labelKey: 'supplier_name',
        sendParams: {
          no_page: true,
        },
      },
    },
    {
      field: 'user_name',
      label: '返货人',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'date',
      label: '返货时间',
      width: '220px',
      searchWidth: '250px',
      value: null,
      component_name: 'c-range-picker',
      attr: {
        mode: 'date',
        needDefault: false,
      },
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/refund/list', data);
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
