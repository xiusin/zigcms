<template>
  <div class="content-box">
    <a-card class="table-wrap" :body-style="{ padding: '10px 0 0 0' }">
      <div style="padding: 0 16px 16px">
        <a-tabs :active-key="formModel.status" @change="handlerTabChange">
          <a-tab-pane :key="0">
            <template #title>全部</template>
          </a-tab-pane>
          <a-tab-pane :key="4">
            <template #title>上架中</template>
          </a-tab-pane>
          <a-tab-pane :key="1">
            <template #title>库存中</template>
          </a-tab-pane>
          <a-tab-pane :key="2">
            <template #title>待出库</template>
          </a-tab-pane>
          <a-tab-pane :key="3">
            <template #title>运输中</template>
          </a-tab-pane>
          <!-- <a-tab-pane :key="5">
            <template #title>已完成</template>
          </a-tab-pane> -->
        </a-tabs>
        <div class="mt-10">
          <SearchForm
            :form-data="formModel"
            :get-default-form-data="generateFormModel"
            :search-rules="searchRules"
            :base-search-rules="baseSearchRules"
            placeholder="请输入商品ID"
            @hand-submit="handleSubmit"
            @change-cache-form-data="changeCacheFormData"
          ></SearchForm>
        </div>
      </div>
    </a-card>

    <a-card class="table-card">
      <a-space v-if="!isSupplierRole" class="c-table-tool-item">
        <a-button
          size="small"
          type="primary"
          :loading="multiDownloadLoading"
          :disabled="rowSelection.selectedRowKeys.length === 0"
          @click="multiDownload()"
        >
          <template #icon>
            <icon-rotate-right />
          </template>
          批量图片导出
        </a-button>
        <a-button
          size="small"
          type="primary"
          :loading="modifyPositionLoading"
          :disabled="rowSelection.selectedRowKeys.length === 0"
          @click="modifyPosition()"
        >
          <template #icon>
            <icon-rotate-right />
          </template>
          批量借调
        </a-button>
        <a-button
          v-if="formModel.status === 1"
          size="small"
          type="primary"
          :loading="refundTableLoading"
          :disabled="rowSelection.selectedRowKeys.length === 0"
          @click="refundTable()"
        >
          <template #icon>
            <icon-rotate-right />
          </template>
          提交返货单
        </a-button>
        <template v-if="rowSelection.selectedRowKeys.length != 0">
          <span class="title-box">
            已选择
            <a-tag>{{ rowSelection.selectedRowKeys.length }}</a-tag>
            个商品
          </span>
          <icon-close-circle class="cur-por" @click="resetHandler" />
        </template>
      </a-space>
      <!--示例布局 暂时保留-->
      <div class="c-table-tool">
        <a-space class="c-table-tool-item"> </a-space>
        <a-space class="c-table-tool-item">
          <a-button-group>
            <a-button
              v-if="!isSupplierRole"
              size="small"
              :loading="exportLoading"
              @click="exportHandler"
            >
              <template #icon>
                <icon-export />
              </template>
              导出
            </a-button>
            <br v-else />
          </a-button-group>
        </a-space>
      </div>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
        :row-selection="rowSelection"
        :data-handle="dataHandle"
        @sorter-change="sortChangeHandler"
        @selection-change="selectionChange"
      >
        <template #company_id>
          <div> 鹏景 </div>
        </template>
        <template #department_id>
          <div> 实物电商A部 </div>
        </template>

        <template #accessories="{ record }">
          <div> {{ record.accessories && record.accessories.join('，') }} </div>
        </template>

        <template #image_urls="{ record }">
          <span v-if="!record.image_urls || record.image_urls.length == 0">
            -
          </span>
          <a-image
            v-else
            height="80"
            width="80"
            :src="`${
              record.main_imgurl || record.image_urls[0].url
            }?x-oss-process=image/auto-orient,1/resize,p_50/quality,q_90`"
            :preview="true"
            show-loader
          ></a-image>
        </template>

        <template #detail_image_urls="{ record }">
          <a-image
            v-if="
              record.detail_image_urls &&
              (record.detail_image_urls['LOGO'][0]?.url ||
                record.detail_image_urls['主图'][0]?.url ||
                record.detail_image_urls['正面图'][0]?.url ||
                record.detail_image_urls['背面图'][0]?.url ||
                record.detail_image_urls['五金图'][0]?.url ||
                record.detail_image_urls['底面图'][0]?.url ||
                record.detail_image_urls['内衬图'][0]?.url ||
                record.detail_image_urls['配件图'][0]?.url ||
                record.detail_image_urls['瑕疵图'][0]?.url)
            "
            height="80"
            width="80"
            show-loader
            :src="
              record.detail_image_urls['LOGO'][0]?.url ||
              record.detail_image_urls['主图'][0]?.url ||
              record.detail_image_urls['正面图'][0]?.url ||
              record.detail_image_urls['背面图'][0]?.url ||
              record.detail_image_urls['五金图'][0]?.url ||
              record.detail_image_urls['底面图'][0]?.url ||
              record.detail_image_urls['内衬图'][0]?.url ||
              record.detail_image_urls['配件图'][0]?.url ||
              record.detail_image_urls['瑕疵图'][0]?.url
            "
            :preview="false"
            @click="previewImgDetailClick(record.detail_image_urls)"
          ></a-image>
          <span v-else>-</span>
        </template>

        <template #action="{ record }">
          <template v-if="record.status_text == '库存中' && !isSupplierRole">
            <a-link @click="showProductProfileForm(record)">
              <icon-book />
              档案
            </a-link>
            <a-divider direction="vertical" />
            <a-link
              :disabled="record.is_shelve == 1"
              @click="shelveAction(record, false)"
            >
              <icon-gift />
              上架
            </a-link>
            <br />
            <a-link
              :disabled="record.pickup_num"
              @click="saveAction(record, false)"
            >
              <icon-printer />
              出库申请
            </a-link>
            <br />
            <a-link
              v-permission="[1, 12, 14]"
              :disabled="record.pickup_num"
              @click="saveAction(record, true)"
            >
              <icon-edit />
              编辑
            </a-link>
            <a-divider direction="vertical" />
            <a-link @click="editAction(record)">
              <icon-storage />
              借调
            </a-link>
          </template>

          <a-link :disabled="record.pickup_num" @click="downloadAction(record)">
            <icon-file-image />
            图片下载
          </a-link>
        </template>
      </base-table>
    </a-card>
    <AddEditForm ref="saveRef" @create-over="handleSubmit()" />
    <ShelveEditForm ref="shelveRef" @create-over="handleSubmit()" />
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
    <PositionEditForm
      ref="positionEditFormRef"
      @create-over="handleSubmit()"
    ></PositionEditForm>
    <PositionEditIdsForm
      ref="positionEditIdsFormRef"
      @create-over="handleSubmit()"
    ></PositionEditIdsForm>
    <ModalPreviewForm
      ref="ModalPreviewFormRef"
      @submit-success="submitSuccess()"
    ></ModalPreviewForm>
    <ProductProfileForm ref="ProductProfileFormRef"></ProductProfileForm>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref, computed } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import AddEditForm from './add-edit-form.vue';
  import ShelveEditForm from './shelve-edit-form.vue';
  import PositionEditForm from './position-eidt-form.vue';
  import PositionEditIdsForm from './position-eidtIds-form.vue';
  import ModalPreviewForm from './modal-preview-form.vue';
  import ProductProfileForm from './product-profile-form.vue';
  import { Message } from '@arco-design/web-vue';
  import { useRoute } from 'vue-router';

  const route = useRoute();

  const userStore = useUserStore();
  const { role_ids } = userStore;

  const visible = ref(false);
  const current = ref(0);
  const previewImageList = ref([]);
  // 角标字典翻译
  const previewDict: any = ref({});
  const previewImgClick = (imgList: any) => {
    current.value = 0;
    visible.value = true;
    previewDict.value = {};
    previewImageList.value = imgList.map((item: any) => {
      previewDict.value[item.url] = '商品图';
      return item.url;
    });
  };
  // 预览商品细节图
  const previewImgDetailClick = (imgList: any) => {
    current.value = 0;
    visible.value = true;
    let imgArr: any = [];
    previewDict.value = {};
    Object.keys(imgList).forEach((key: any) => {
      imgList[key].forEach((ele: any) => {
        previewDict.value[ele.url] = key;
        imgArr.push(ele.url);
      });
    });
    previewImageList.value = imgArr;
  };

  const tableRef = ref();
  const saveRef = ref();
  const shelveRef = ref();
  const loading = ref(false);
  const columns = ref([
    {
      title: '商品ID',
      align: 'left',
      dataIndex: 'product_no',
      fixed: 'left',
      width: 180,
    },
    {
      title: '商品图片',
      align: 'left',
      fixed: 'left',
      dataIndex: 'image_urls',
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
      title: '公价',
      align: 'left',
      dataIndex: 'public_price',
    },
    {
      title: '入库价格',
      align: 'left',
      dataIndex: 'in_warehouse_price',
      sortable: {
        sorter: true,
        sortDirections: ['ascend', 'descend'],
      },
    },
    {
      title: '商品定价',
      align: 'left',
      dataIndex: 'price',
      sortable: {
        sorter: true,
        sortDirections: ['ascend', 'descend'],
      },
    },
    {
      title: '商品底价',
      align: 'left',
      dataIndex: 'recommend_price',
      headerCellClass: 'SPDJ',
    },
    {
      title: '商品规格',
      align: 'left',
      dataIndex: 'size_name',
    },
    {
      title: '商品名称',
      align: 'left',
      dataIndex: 'product_name',
    },
    {
      title: '配件',
      align: 'left',
      dataIndex: 'accessories',
    },
    {
      title: '配件备注',
      align: 'left',
      dataIndex: 'accessories_instruction',
    },
    {
      title: '入库类型',
      align: 'left',
      dataIndex: 'in_warehouse_type_text',
    },
    {
      title: '商品细节图',
      align: 'left',
      dataIndex: 'detail_image_urls',
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
      title: '上架平台',
      align: 'left',
      dataIndex: 'shelve_platforms_text',
    },
    {
      title: '所在位置',
      align: 'left',
      dataIndex: 'position_text',
    },
    {
      title: '入库人员',
      align: 'left',
      dataIndex: 'in_warehouse_user_name',
    },
    {
      title: '生产年份',
      align: 'left',
      dataIndex: 'product_at',
    },
    {
      title: '瑕疵说明',
      align: 'left',
      dataIndex: 'flaw_remark',
    },
    {
      title: '入库时间',
      align: 'left',
      dataIndex: 'in_warehouse_time',
    },
    {
      title: '最后修改人',
      align: 'left',
      dataIndex: 'updated_user_name',
    },
    {
      title: '最后修改时间',
      align: 'left',
      dataIndex: 'updated_at',
    },
    {
      title: '状态',
      align: 'left',
      fixed: 'right',
      width: 80,
      dataIndex: 'status_text',
    },
    {
      title: '操作',
      align: 'center',
      dataIndex: 'action',
      width: 160,
      fixed: 'right',
    },
  ]);

  // 如果是供应商
  const isSupplierRole = ref(role_ids.includes(19) && role_ids.length === 1);
  if (isSupplierRole.value) {
    const filterKeys = [
      'public_price',
      'in_warehouse_price',
      'price',
      'recommend_price',
      'in_warehouse_type_text',
      'shelve_platforms_text',
      'position_text',
      'action',
    ];
    columns.value = columns.value.filter((item) => {
      return !filterKeys.includes(item.dataIndex);
    });
  }
  if (
    role_ids.filter((id) => {
      return ![4, 5, 6, 11, 18, 19, 20, 21, 22, 23, 24].includes(id);
    }).length === 0
  ) {
    const filterKeys = ['in_warehouse_price'];
    columns.value = columns.value.filter((item) => {
      return !filterKeys.includes(item.dataIndex);
    });
    columns.value.forEach((element) => {
      if (element.title === '商品底价') {
        element.headerCellClass = '';
      }
    });
  }

  const generateFormModel = () => {
    return {
      // 基础查询条件
      name: '',
      user_id: '',
      is_open_saas: '',
      is_open_saas_d: '',
      user_name: '',
      brand_id: null,
      style_id: null,
      date: route.params.date || null,
      status: 1,
      position: null,
      supplier_name: null,
      product_no: route.params.product_no || null,
      // content: route.params.product_no || null,
    };
  };

  const formModel: any = ref(generateFormModel());

  const baseSearchRules: any = ref([
    {
      field: 'product_no',
      label: '商品ID',
      value: null,
      width: '160px',
    },
  ]);

  const cacheFormData = ref();
  const searchRules: any = computed(() => {
    let ret = [
      {
        field: 'date',
        label: '入库时间',
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
        field: 'product_name',
        label: '商品名称',
        value: null,
        component_name: 'base-input',
      },
      {
        field: 'in_warehouse_user_name',
        label: '入库人员',
        value: null,
        component_name: 'base-input',
      },
      {
        field: 'position',
        label: '所在位置',
        value: null,
        component_name: 'base-dict-select',
        attr: {
          selectType: 'positionDict',
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
    ];
    if (formModel.value.status === 1) {
      // ret.push({
      //   field: 'product_status',
      //   label: '状态',
      //   value: null,
      //   component_name: 'base-dict-select',
      //   attr: {
      //     selectType: 'productStatus',
      //   },
      // });
    }
    return ret;
  });

  const downloadAction = (data: any) => {
    loading.value = true;
    request('/api/warehouse/product/download', {
      id: data.id,
      export: true,
      export_now: true,
    })
      .then(() => {
        loading.value = false;
      })
      .catch(() => {
        loading.value = false;
      });
  };

  const getDataList = (data: any) => {
    if (formModel.value.status === 1) {
      data.product_status = 1;
    }

    if (formModel.value.status === 4) {
      data.status = 1;
      data.product_status = 2;
    }
    return request('/api/warehouse/product/detail-list', data);
  };

  const dataHandle = (list: any) => {
    return list.map((item: any) => {
      // item.disabled = item.is_shelve === 1;
      return item;
    });
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

  function saveAction(record: any, canOverWright: any) {
    saveRef.value?.show({ ...record, canOverWright });
  }

  function shelveAction(record: any, canOverWright: any) {
    shelveRef.value?.show({ ...record, canOverWright });
  }

  const positionEditFormRef = ref();
  function editAction(record: any) {
    positionEditFormRef.value?.show({ ...record });
  }

  const positionEditIdsFormRef = ref();

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

  const ModalPreviewFormRef = ref();
  const showPreviewRecord = (record: any) => {
    ModalPreviewFormRef.value.show(record);
  };

  const ProductProfileFormRef = ref();
  const showProductProfileForm = (record: any) => {
    ProductProfileFormRef.value.show(record);
  };

  let rowSelection: any = reactive({
    type: 'checkbox',
    showCheckedAll: true,
    selectedRowKeys: [] as any[],
    selectedRows: [],
  });

  const selectionChange = (selectedRowKeys: any) => {
    rowSelection.selectedRowKeys = selectedRowKeys;
  };
  // 重置
  const resetHandler = () => {
    rowSelection.selectedRowKeys = [];
  };

  const multiDownloadLoading = ref(false);
  const multiDownload = () => {
    multiDownloadLoading.value = true;
    request('/api/warehouse/product/multi-download', {
      ids: rowSelection.selectedRowKeys,
      export: true,
      export_now: true,
    })
      .then(() => {
        multiDownloadLoading.value = false;
      })
      .catch(() => {
        multiDownloadLoading.value = false;
      });
  };

  const modifyPositionLoading = ref(false);
  const modifyPosition = () => {
    modifyPositionLoading.value = true;
    positionEditIdsFormRef.value?.show({
      ...{
        ids: rowSelection.selectedRowKeys,
      },
    });
    modifyPositionLoading.value = false;
  };

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
    // resetHandler();
  };

  const changeCacheFormData = (cacheformdata: any) => {
    cacheFormData.value = cacheformdata;
  };

  const handlerTabChange = (val: any) => {
    formModel.value.status = val;
    handleSubmit();
  };

  const refundTableLoading = ref(false);
  const refundTable = () => {
    refundTableLoading.value = true;
    request('/api/refund/table', { ids: rowSelection.selectedRowKeys })
      .then((resData) => {
        refundTableLoading.value = false;
        showPreviewRecord(resData.data);
      })
      .catch(() => {
        refundTableLoading.value = false;
      });
  };
  const submitSuccess = () => {
    handleSubmit();
    resetHandler();
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
  :deep(.SPDJ div) {
    position: relative;
    display: inline-block;
    &::after {
      display: inline-block;
      content: ' ';
      background-image: url('./i.svg');
      background-size: 16px 16px;
      height: 16px;
      width: 16px;
    }
    &::before {
      position: absolute;
      width: 180px;
      background-color: #555;
      color: #fff;
      text-align: center;
      padding: 5px 0;
      border-radius: 6px;
      z-index: 100;
      opacity: 0;
      transition: opacity 0.6s;

      bottom: -160%;
      left: 80%;
      margin-left: -60px;

      content: '（商品进价+450）*1.05';
      visibility: hidden;
    }
    &:hover::before {
      visibility: visible;
      opacity: 1;
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
    height: calc(100vh - 400px);
    min-height: 400px;
  }
</style>
