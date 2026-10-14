<template>
  <div class="content-box">
    <a-card class="table-wrap" :body-style="{ padding: '10px 0 0 0' }">
      <div style="padding: 0 16px 16px">
        <a-tabs :active-key="formModel.status" @change="handlerTabChange">
          <a-tab-pane :key="1">
            <template #title>未支付订单</template>
          </a-tab-pane>
          <a-tab-pane :key="2">
            <template #title>已支付&发货订单</template>
          </a-tab-pane>
          <a-tab-pane :key="3">
            <template #title>已取消需退款订单</template>
          </a-tab-pane>
          <a-tab-pane :key="4">
            <template #title>已签收&已完成订单</template>
          </a-tab-pane>
        </a-tabs>
        <div class="mt-10">
          <SearchForm
            :form-data="formModel"
            :get-default-form-data="generateFormModel"
            :search-rules="searchRules"
            :base-search-rules="baseSearchRules"
            placeholder="请输入订单编号"
            @hand-submit="handleSubmit"
          ></SearchForm>
        </div>
      </div>
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
        :columns-config="showColumns"
        :data-config="getDataList"
        :send-params="formModel"
        @sorter-change="sortChangeHandler"
      >
        <template #main_imgurl="{ record }">
          <span v-if="!record.main_imgurl"> - </span>
          <a-image
            v-else
            height="80"
            width="80"
            :src="`${record.main_imgurl}?x-oss-process=image/auto-orient,1/resize,p_50/quality,q_90`"
            :preview="true"
            show-loader
          ></a-image>
        </template>
      </base-table>
    </a-card>
    <a-image-preview-group
      v-model:visible="visible"
      v-model:current="current"
      infinite
      :src-list="previewImageList"
    >
      <template #actions>
        <a-image-preview-action
          :name="`当前图片为${previewDict[previewImageList[current]]}`"
        >
          {{ previewDict[previewImageList[current]] }}</a-image-preview-action
        >
      </template>
    </a-image-preview-group>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref, computed } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';

  const user = useUserStore();

  const visible = ref(false);
  const current = ref(0);
  const previewImageList = ref([]);
  // 角标字典翻译
  const previewDict: any = ref({});

  const tableRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '订单编号',
      align: 'left',
      dataIndex: 'order_no',
      fixed: 'left',
      width: 180,
    },
    {
      title: '商品编号',
      align: 'left',
      fixed: 'left',
      dataIndex: 'product_no',
    },
    {
      title: '商品名称',
      align: 'left',
      dataIndex: 'product_name',
    },
    {
      title: '商品首图',
      align: 'left',
      dataIndex: 'main_imgurl',
    },
    {
      title: '用户编号',
      align: 'left',
      dataIndex: 'app_user_no',
    },
    {
      title: '商品售价',
      align: 'left',
      dataIndex: 'price',
    },
    {
      title: '优惠&折扣价格',
      align: 'left',
      dataIndex: 'profit_price',
    },

    {
      title: '实收金额(元)',
      align: 'left',
      dataIndex: 'order_price',
    },
    {
      title: '下单时间',
      align: 'left',
      dataIndex: 'created_at',
    },
    {
      title: '订单状态',
      align: 'left',
      dataIndex: 'status_text',
    },
    {
      title: '支付发起时间',
      align: 'left',
      dataIndex: 'payment_time',
    },
    {
      title: '支付完成时间',
      align: 'left',
      dataIndex: 'end_payment_time',
    },
    {
      title: '支付时间',
      align: 'left',
      dataIndex: 'payment_time',
    },

    {
      title: '签收人',
      align: 'left',
      dataIndex: 'address_name',
    },
    {
      title: '签收电话',
      align: 'left',
      dataIndex: 'address_mobile',
    },
    {
      title: '签收地址',
      align: 'left',
      dataIndex: 'address_info',
    },
    {
      title: '物流运单号',
      align: 'left',
      dataIndex: 'express_no',
    },

    {
      title: '发货单号',
      align: 'left',
      dataIndex: 'express_no',
    },
    {
      title: '发货人',
      align: 'left',
      dataIndex: 'express_user_name',
    },
    {
      title: '退货单号',
      align: 'left',
      dataIndex: 'refund_express_no',
    },
    {
      title: '退货状态',
      align: 'left',
      dataIndex: 'refund_status_text',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
      order_no: '',
      user_id: '',
      product_no: '',
      product_name: '',
      created_at: null,
      status: 1,
    };
  };

  const formModel: any = ref(generateFormModel());
  const showColumns = computed(() => {
    let statusColumns: any = {
      1: [
        '订单编号',
        '商品编号',
        '商品名称',
        '商品首图',
        '用户编号',
        '商品售价',
        '优惠&折扣价格',
        '实收金额(元)',
        '下单时间',
        '订单状态',
        '签收人',
        '签收电话',
        '签收地址',
      ],
      2: [
        '订单编号',
        '商品编号',
        '商品名称',
        '商品首图',
        '用户编号',
        '商品售价',
        '优惠&折扣价格',
        '实收金额(元)',
        '下单时间',
        '订单状态',
        '支付发起时间',
        '支付完成时间',
        '签收人',
        '签收电话',
        '签收地址',
        '物流运单号',
        '发货人',
      ],
      3: [
        '订单编号',
        '商品编号',
        '商品名称',
        '商品首图',
        '用户编号',
        '实收金额(元)',
        '下单时间',
        '订单状态',
        '支付时间',
        '签收人',
        '签收电话',
        '签收地址',
        '发货单号',
        '发货人',
        '退货单号',
        '退货状态',
      ],
      4: [
        '订单编号',
        '商品编号',
        '商品名称',
        '商品首图',
        '用户编号',
        '商品售价',
        '优惠&折扣价格',
        '实收金额(元)',
        '下单时间',
        '支付发起时间',
        '支付完成时间',
        '订单状态',
        '签收人',
        '签收电话',
        '签收地址',
        '物流运单号',
        '发货人',
        '退货单号',
      ],
    };
    let chooseColumns = statusColumns[formModel.value.status];
    let ret: any = [];
    columns.forEach((element) => {
      if (chooseColumns.includes(element.title)) {
        ret.push(element);
      }
    });
    return ret;
  });
  const baseSearchRules: any = ref([
    {
      field: 'order_no',
      label: '订单编号',
      value: null,
      width: '100px',
    },
  ]);

  const searchRules: any = ref([
    {
      field: 'product_no',
      label: '商品编号',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'product_name',
      label: '商品名称',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'user_id',
      label: '用户编号',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'created_at',
      label: '下单时间',
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

  const getDataList = (data: any) => {
    return request('/api/order/list', data);
  };

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const handlerTabChange = (val: any) => {
    formModel.value.status = val;
    handleSubmit();
  };

  // 排序发生变化
  // todo
  const sortChangeHandler = (field: any, direction: any) => {
    // let setSorter = {
    //   direction: direction || '',
    //   field: field || '',
    // };
    // Object.assign(formModel.value, setSorter);
    // handleSubmit();
    // emits('sorterChange', dataIndex, direction); // 排序统一在组件内部处理
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

  /*table:lqy*/
  .c-table-tool {
    margin-bottom: 8px;
    display: grid;
    grid-template-columns: 50% 50%;

    &-item:nth-child(2) {
      display: flex;
      justify-content: flex-end;
    }
  }
  /*table end*/

  :deep(.arco-tabs-tab-title) {
    font-size: 15px;
  }
</style>
