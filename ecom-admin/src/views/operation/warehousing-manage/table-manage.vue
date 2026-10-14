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
        <template #action="{ record }">
          <a-link :disabled="record.pickup_num" @click="saveAction(record)">
            <icon-printer />
            入库
          </a-link>
          <a-divider direction="vertical" />
          <a-popconfirm
            :content="`确定要废弃这条数据吗?`"
            position="left"
            @ok="deleteItem(record)"
          >
            <a-link> <icon-folder-delete /> 废弃 </a-link>
          </a-popconfirm>
        </template>
      </base-table>
    </a-card>
    <AddEditForm ref="saveRef" @create-over="handleSubmit()" />
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from '@/views/operation/warehousing-manage/add-edit-form.vue';
  import { Message } from '@arco-design/web-vue';

  const user = useUserStore();

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '货盘期号',
      align: 'left',
      dataIndex: 'demand_no',
      fixed: 'left',
    },
    {
      title: '商品ID',
      align: 'left',
      dataIndex: 'product_no',
    },
    {
      title: '品牌',
      align: 'left',
      dataIndex: 'brand_name',
    },
    {
      title: '商品来源',
      align: 'left',
      dataIndex: 'in_warehouse_type_text',
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
      title: '备注',
      align: 'left',
      dataIndex: 'remark',
    },
    {
      title: '供应商',
      align: 'left',
      dataIndex: 'supplier_name',
    },
    {
      title: '入库人员',
      align: 'left',
      dataIndex: 'in_warehouse_user_name',
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
      demand_no: '',
      product_no: '',
      brand_name: '',
      style_name: '',
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
    {
      field: 'product_no',
      label: '商品ID',
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
      field: 'style_name',
      label: '系列名称',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'in_warehouse_user_name',
      label: '入库人员',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/warehouse/product/list', data);
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

  const deleteItem = async (record: any) => {
    record.loading = true;
    request('/api/warehouse/product/delete', {
      id: record.id,
    })
      .then(() => {
        Message.success('废弃成功');
        handleSubmit();
      })
      .finally(() => {
        record.loading = false;
      });
  };

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
</style>
