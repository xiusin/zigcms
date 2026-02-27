<template>
  <div class="content-box">
    <a-card class="table-wrap" :body-style="{ padding: '10px 0 0 0' }">
      <div style="padding: 0 16px 16px">
        <div class="mt-10">
          <SearchForm
            :form-data="formModel"
            :get-default-form-data="generateFormModel"
            :search-rules="searchRules"
            :base-search-rules="baseSearchRules"
            placeholder="请输入商品ID"
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
        :send-params="formModel"
        @sorter-change="sortChangeHandler"
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
          <a-link
            v-permission="[1, 14]"
            :disabled="record.pickup_num"
            @click="shelveAction(record, true)"
          >
            <icon-edit />
            编辑
          </a-link>
          <a-divider direction="vertical" />
          <a-popconfirm
            :content="`确定下架【${record.product_no}】吗?`"
            @ok="offAction(record)"
          >
            <a-link>
              <icon-storage />
              下架
            </a-link>
          </a-popconfirm>
        </template>
      </base-table>
    </a-card>
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
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import ShelveEditForm from './shelve-edit-form.vue';

  const user = useUserStore();

  const visible = ref(false);
  const current = ref(0);
  const previewImageList = ref([]);
  // 角标字典翻译
  const previewDict: any = ref({});
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
  const columns = [
    {
      title: '商品ID',
      align: 'left',
      dataIndex: 'product_no',
      fixed: 'left',
      width: 180,
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
      title: '商品名称',
      align: 'left',
      dataIndex: 'product_name',
    },
    {
      title: '上架平台',
      align: 'left',
      dataIndex: 'shelve_platforms_text',
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
      sortable: {
        sorter: true,
        sortDirections: ['ascend', 'descend'],
      },
    },
    {
      title: '商品图片',
      align: 'left',
      fixed: 'left',
      dataIndex: 'image_urls',
    },
    {
      title: '商品细节图',
      align: 'left',
      dataIndex: 'detail_image_urls',
    },
    {
      title: '尺寸',
      align: 'left',
      dataIndex: 'dimension',
    },
    {
      title: '配件',
      align: 'left',
      dataIndex: 'accessories',
    },
    {
      title: '商品详情配置',
      align: 'left',
      dataIndex: 'detail_options_text',
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
      title: '操作',
      align: 'center',
      dataIndex: 'action',
      width: 160,
      fixed: 'right',
    },
  ];

  const generateFormModel = () => {
    return {
      // 基础查询条件
      product_no: '',
      product_name: '',
      brand_id: '',
      // min_price: '',
      // max_price: '',
      range_price: [],
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'product_no',
      label: '商品ID',
      value: null,
      width: '100px',
    },
  ]);
  const formModel: any = ref(generateFormModel());

  const searchRules: any = ref([
    // {
    //   field: 'product_no',
    //   label: '商品ID',
    //   value: null,
    //   component_name: 'base-input',
    // },
    {
      field: 'product_name',
      label: '商品名称',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'brand_id',
      label: '品牌',
      value: null,
      component_name: 'base-request-select',
      attr: {
        requestUrl: '/api/brand/list',
        labelKey: 'brand_name',
        sendParams: {
          no_page: true,
        },
      },
    },
    {
      field: 'range_price',
      label: '商品定价',
      value: null,
      component_name: 'base-input-group',
      attr: {
        placeholderL: '最低价格',
        placeholderR: '最高价格',
      },
    },
    {
      field: 'shelve_platforms',
      label: '上架平台',
      value: null,
      component_name: 'base-dict-select',
      attr: {
        selectType: 'shelvePlatforms',
      },
    },
  ]);

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const offAction = (data: any) => {
    loading.value = true;
    request('/api/warehouse/product/off-shelf', {
      id: data.id,
    })
      .then(() => {
        handleSubmit();
        loading.value = false;
      })
      .catch(() => {
        loading.value = false;
      });
  };

  const getDataList = (data: any) => {
    if (data.range_price) {
      data.min_price = data.range_price?.[0];
      data.max_price = data.range_price?.[1];
      delete data.range_price;
    }
    return request('/api/warehouse/product/shelve-list', data);
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

  function shelveAction(record: any, canOverWright: any) {
    shelveRef.value?.show({ ...record, canOverWright });
  }

  const positionEditFormRef = ref();

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
