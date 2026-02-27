<template>
  <d-drawer
    :title="isEditFlag ? '编辑提货单' : '新建提货单'"
    :ok-loading="loading"
    :visible="visible"
    width="1060px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" layout="vertical">
      <a-spin :loading="loading">
        <a-row :gutter="12">
          <a-col :span="12">
            <a-form-item
              label="货盘期号"
              field="demand_no"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.demand_no"
                request-url="/api/demand/list"
                label-key="demand_no"
                value-key="demand_no"
                :send-params="{ no_page: true }"
                @change="getInfoFn"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item
              label="供应商"
              field="supplier_id"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.supplier_id"
                request-url="/api/supplier/list"
                label-key="supplier_name"
                value-key="id"
                :send-params="{ no_page: true }"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item
              label="提货单位"
              field="company_id"
              :rules="requiredRules"
            >
              <base-dict-select
                v-model="thisFormData.company_id"
                select-type="companyDict"
                :read-only="true"
                :allow-clear="false"
              ></base-dict-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item
              label="提货人"
              field="receive_user_id"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.receive_user_id"
                request-url="/api/member/list"
                label-key="username"
                value-key="id"
                :send-params="{ no_page: true }"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item
              label="提货时间"
              field="pickup_time"
              :rules="requiredRules"
            >
              <base-date-picker
                v-model="thisFormData.pickup_time"
                :allow-clear="false"
              ></base-date-picker>
            </a-form-item>
          </a-col>
        </a-row>
        <a-card title="选择商品">
          <a-row :gutter="12">
            <div class="shop-card">
              <!--table 区域-->
              <base-table
                ref="theTable"
                v-model:loading="loading"
                :data="thisFormData.products"
                :columns-config="columnsConfig"
                :row-selection="rowSelection"
                :pagination="false"
                row-key="id"
                @selection-change="selectionChange"
                @table-change="changeHandler"
              >
                <template #pickupNum="{ record }">
                  <div
                    v-if="rowSelection.selectedRowKeys.includes(record.id)"
                    class="dis-flex"
                  >
                    <span class="error_text pr-5">*</span>
                    <a-input-number
                      v-model="record.pickup_num"
                      :max="record.remain_num"
                      placeholder="请输入"
                    ></a-input-number>
                  </div>

                  <span v-else> - </span>
                </template>

                <template
                  #name-filter="{
                    filterValue,
                    setFilterValue,
                    handleFilterConfirm,
                    handleFilterReset,
                  }"
                >
                  <div class="custom-filter">
                    <a-space direction="vertical">
                      <a-input
                        :model-value="filterValue[0]"
                        @input="(value) => setFilterValue([value])"
                      />
                      <div class="custom-filter-footer">
                        <a-button size="small" @click="handleFilterConfirm"
                          >确定</a-button
                        >
                        <a-button size="small" @click="handleFilterReset"
                          >Reset</a-button
                        >
                      </div>
                    </a-space>
                  </div>
                </template>
              </base-table>
            </div>
          </a-row>
        </a-card>
      </a-spin>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref, reactive, h, computed } from 'vue';
  import request from '@/api/request';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    demand_id: null,
    demand_no: null,
    company_id: 1,
    supplier_id: null,
    receive_user_id: null,
    pickup_time: null,
    products: [],
  });
  const requiredRules: FieldRule = {
    required: true,
    message: '请填写',
  };
  const thisFormData: any = ref(defaultForm());
  const loading = ref(false);
  const isEditFlag = ref(false);
  const visible = ref(false);
  const thisFormRef = ref();
  const emits = defineEmits(['createOver']);

  // 重置表单
  function resetThisForm() {
    // 移除表单项的校验结果
    thisFormRef.value.clearValidate();
    thisFormData.value = defaultForm();
  }

  const route = useRoute();
  const router = useRouter();

  /**
   * 表格基本盘
   * (生成loading加载标识，table挂载数据、分页参数、动态汇总查询条件）
   */

  const columnsConfig: any = computed(() => [
    {
      title: '品牌',
      dataIndex: 'brand_name',
      fixed: 'left',
      filterable: {
        filters: thisFormData.value.products
          .map((item: any) => {
            return {
              text: item.brand_name,
              value: item.brand_name,
            };
          })
          .filter(
            (obj: any, index: any, self: any) =>
              index === self.findIndex((o: any) => o.text === obj.text)
          ),
        multiple: true,
        filter: (value: any, row: any) => value.includes(row.brand_name),
      },
    },
    {
      title: '系列名称',
      dataIndex: 'style_name',
      align: 'center',
      filterable: {
        filters: thisFormData.value.products
          .map((item: any) => {
            return {
              text: item.style_name,
              value: item.style_name,
            };
          })
          .filter(
            (obj: any, index: any, self: any) =>
              index === self.findIndex((o: any) => o.text === obj.text)
          ),
        multiple: true,
        filter: (value: any, row: any) => {
          // return row.style_name.includes(value);
          return value.includes(row.style_name);
        },
      },
    },
    {
      title: '商品规格',
      dataIndex: 'size_name',
      align: 'center',
    },
    {
      title: '颜色',
      dataIndex: 'color_name',
      align: 'center',
    },
    {
      title: '材质',
      dataIndex: 'element_name',
      align: 'center',
    },
    {
      title: '备注',
      dataIndex: 'remark',
      align: 'center',
    },
    {
      title: '商品需求数量',
      dataIndex: 'num',
      align: 'center',
    },
    {
      title: '提货申请表剩余额度',
      dataIndex: 'remain_num',
      align: 'center',
    },
    {
      title: '需求数量',
      dataIndex: 'pickup_num',
      width: 140,
      // align: 'center',
      slotName: 'pickupNum',
    },
  ]);

  // 表单的滚动设置
  let rowSelection: any = reactive({
    type: 'checkbox',
    showCheckedAll: true,
    selectedRowKeys: [] as any[],
    selectedRows: [],
  });

  const selectionChange = (selectedRowKeys: any) => {
    rowSelection.selectedRowKeys = selectedRowKeys;
  };

  // table渲染完成回调
  const changeHandler = (tableData: any) => {
    loading.value = false;
  };

  // 关闭回调
  function onClose() {
    visible.value = false;
    resetThisForm();
  }
  function sendInfo() {
    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        const unParams: any = unref(thisFormData);
        let params = JSON.parse(JSON.stringify(unParams));
        // 开始校验
        if (rowSelection.selectedRowKeys?.length === 0) {
          Message.warning('至少选择一件商品！');
          return;
        }
        params.products = params.products.filter((item: any) => {
          return (
            rowSelection.selectedRowKeys.includes(item.id) && item.pickup_num
          );
        });
        if (params.products?.length === 0) {
          Message.warning('请填写商品需求数量！');
          return;
        }

        loading.value = true;
        request('/api/pickup/save', params)
          .then(() => {
            onClose();
            emits('createOver');
            Message.success('操作成功');
          })
          .finally(() => {
            loading.value = false;
          });
      }
    });
  }

  const getInfoFn = async (item: any, record: any) => {
    loading.value = true;
    thisFormData.value.demand_id = record.id || null;
    request('/api/demand/products', {
      id: record.id,
    })
      .then((res) => {
        if (res.code && res.code === 200) {
          thisFormData.value.products = res.data || [];
        }
        loading.value = false;
      })
      .finally(() => {
        loading.value = false;
      });
  };

  // 打开抽屉
  async function show(item: any) {
    visible.value = true;
    isEditFlag.value = false;
    thisFormData.value = defaultForm();
    rowSelection.selectedRowKeys = [];

    if (item && item.id) {
      isEditFlag.value = true;
      Object.assign(thisFormData.value, item);
      // getInfoFn(item);
    }
  }

  // 查询品牌名
  const queryTemplateImg = async (item: any) => {
    request('/api/demand/template', {
      ...item,
    }).then((res) => {
      if (res.code && res.code === 200) {
        Object.assign(thisFormData.value, res.data);
      }
    });
  };

  onMounted(() => {
    if (route.query.add) {
      show({});
    }
  });

  defineExpose({
    show,
  });
</script>

<style lang="less" scoped>
  .drawer-card {
    :deep(.arco-card-header) {
      padding-top: 0;
    }
  }

  .shop-card {
    border: 1px solid var(--color-border-1);
    width: 100%;
    // min-height: 300px;
    border-radius: 10px;
    margin-bottom: 20px;
    .shop-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 10px 20px 5px;
      font-size: 16px;
      border-bottom: 1px solid var(--color-border-1);
      margin-bottom: 5px;
    }
    .shop-body {
      padding: 5px 20px;
    }
    .wrap-box {
      display: flex;
      align-items: center;
      justify-content: center;
      height: 400px;
      width: 100%;
      background: var(--color-fill-1);
      border-radius: 8px;
    }
  }
  .dis-flex {
    display: flex;
    align-items: center;
  }
</style>
