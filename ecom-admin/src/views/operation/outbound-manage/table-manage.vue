<template>
  <div class="content-box">
    <a-card class="generate-card no-padding">
      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入商品ID"
        @hand-submit="handleSubmit"
        @change-cache-form-data="changeCacheFormData"
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
        <template #accessories="{ record }">
          <div> {{ record.accessories.join('，') }} </div>
        </template>
        <template #action="{ record }">
          <a-link :disabled="!!record.express_no" @click="saveAction(record)">
            <icon-printer />
            出库
          </a-link>
          <a-divider direction="vertical" />
          <a-popconfirm
            :content="`确定要将此商品退货处理吗?`"
            position="left"
            @ok="returnGoods(record)"
          >
            <a-link>
              <icon-reply />
              退货
            </a-link>
          </a-popconfirm>
        </template>
      </base-table>
    </a-card>
    <AddEditForm ref="saveRef" @create-over="handleSubmit()" />
  </div>
</template>

<script setup lang="ts">
  import { computed, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from './add-edit-form.vue';
  import { Message } from '@arco-design/web-vue';
  import { useRoute } from 'vue-router';

  const route = useRoute();

  const user = useUserStore();

  const tableRef = ref();
  const saveRef = ref();
  const loading = ref(false);
  const columns = ref([
    {
      title: '商品ID',
      align: 'left',
      dataIndex: 'product_no',
      fixed: 'left',
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
      title: '成色',
      align: 'left',
      dataIndex: 'quality_name',
    },
    {
      title: '配件',
      align: 'left',
      dataIndex: 'accessories',
    },
    {
      title: '备注',
      align: 'left',
      dataIndex: 'remark',
    },

    {
      title: '尺寸',
      align: 'left',
      dataIndex: 'dimension',
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
      title: '入库时间',
      align: 'left',
      dataIndex: 'in_warehouse_time',
    },
    {
      title: '最后修改时间',
      align: 'left',
      dataIndex: 'updated_at',
    },
    {
      title: '公价',
      align: 'left',
      dataIndex: 'public_price',
    },
    {
      title: '商品定价',
      align: 'left',
      dataIndex: 'price',
    },
    {
      title: '入库价格',
      align: 'left',
      dataIndex: 'in_warehouse_price',
    },
    {
      title: '实际出库价',
      align: 'left',
      dataIndex: 'outbound_price',
    },
    {
      title: '收货人姓名',
      align: 'left',
      dataIndex: 'receiver_name',
    },
    {
      title: '收货人电话',
      align: 'left',
      dataIndex: 'receiver_mobile',
    },
    {
      title: '收货人地址',
      align: 'left',
      dataIndex: 'receiver_address',
    },
    {
      title: '物流运单号',
      align: 'left',
      dataIndex: 'express_no',
    },
    {
      title: '售出渠道',
      align: 'left',
      dataIndex: 'sale_channel_text',
    },
    {
      title: '售出人员',
      align: 'left',
      dataIndex: 'sale_persons',
    },
    // {
    //   title: '场控',
    //   align: 'left',
    //   dataIndex: 'sec_anchor_name',
    // },
    {
      title: '操作',
      align: 'center',
      dataIndex: 'action',
      fixed: 'right',
    },
  ]);

  const generateFormModel = () => {
    return {
      // 基础查询条件
      name: '',
      user_id: '',
      is_open_saas: '',
      is_open_saas_d: '',
      user_name: '',
      updated_at: route.params.date || null,
      brand_id: '',
      style_id: '',
      supplier_id: '',
      express_no: '',
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'product_no',
      label: '商品ID',
      value: null,
      width: '160px',
    },
  ]);
  const formModel: any = ref(generateFormModel());
  const cacheFormData = ref();
  const searchRules: any = computed(() => [
    {
      field: 'user_id',
      label: '理货人',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'updated_at',
      label: '最后修改时间',
      width: '220px',
      searchWidth: '250px',
      value: null,
      component_name: 'c-range-picker',
      attr: {
        mode: 'date',
        needDefault: false,
      },
    },
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
      field: 'express_no',
      label: '物流运单号',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const changeCacheFormData = (cacheformdata: any) => {
    cacheFormData.value = cacheformdata;
  };

  const getDataList = (data: any) => {
    return request('/api/warehouse/product/outbound-list', data);
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

  function returnGoods(record: any) {
    loading.value = true;
    request('/api/warehouse/product/refund', {
      id: record.id,
    })
      .then(() => {
        Message.success('操作成功');
        handleSubmit();
      })
      .catch(() => {
        loading.value = false;
      });
  }

  const userStore = useUserStore();
  const { role_ids } = userStore;

  const isMainAnchor = ref(
    (role_ids.includes(6) || role_ids.includes(18)) && role_ids.length === 1
  );
  if (isMainAnchor.value) {
    const filterKeys = ['in_warehouse_price'];
    columns.value = columns.value.filter((item) => {
      return !filterKeys.includes(item.dataIndex);
    });
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
