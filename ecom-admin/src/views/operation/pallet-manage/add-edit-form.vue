<template>
  <d-drawer
    :title="
      isEditFlag
        ? `编辑货盘需求表【${thisFormData.demand_no}】`
        : `新建货盘需求表`
    "
    :ok-loading="loading"
    :visible="visible"
    width="860px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form ref="thisFormRef" :model="thisFormData" layout="vertical">
      <a-spin :loading="loading">
        <a-row :gutter="12">
          <a-col v-if="isEditFlag" :span="24">
            <a-form-item
              label="货盘期号"
              field="demand_no"
              :rules="requiredRules"
            >
              <a-input
                v-model="thisFormData.demand_no"
                placeholder="请输入"
                readonly
                :allow-clear="false"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item
              label="货盘需求单位"
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
              label="货盘需求部门"
              field="department_id"
              :rules="requiredRules"
            >
              <base-dict-select
                v-model="thisFormData.department_id"
                select-type="departmentDict"
                :allow-clear="false"
              ></base-dict-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-card title="商品需求详情">
          <a-row :gutter="12">
            <div
              v-for="(item, index) in thisFormData.products"
              :key="index"
              class="shop-card"
            >
              <div class="shop-header">
                <div class="primary_text">
                  <icon-skin /> 商品 {{ index + 1 }}
                </div>
                <div class="button-box">
                  <a-button
                    size="small"
                    type="primary"
                    class="mr-10"
                    shape="circle"
                    @click="addGoods(index)"
                  >
                    <icon-plus />
                  </a-button>
                  <a-button
                    v-if="thisFormData.products.length > 1"
                    size="small"
                    status="danger"
                    shape="circle"
                    @click="delGoods(index, item)"
                  >
                    <icon-delete />
                  </a-button>
                </div>
              </div>
              <a-row :gutter="12" class="shop-body">
                <a-col :span="8">
                  <a-form-item
                    label="品牌"
                    :field="`products.${index}.brand_id`"
                    :rules="requiredRules"
                  >
                    <base-request-select
                      v-model="item.brand_id"
                      request-url="/api/brand/list"
                      label-key="brand_name"
                      :send-params="{ no_page: true }"
                      @change="changeBrand(item)"
                    ></base-request-select>
                  </a-form-item>
                  <a-form-item
                    label="商品规格"
                    :field="`products.${index}.size_id`"
                    :rules="requiredRules"
                  >
                    <base-request-select
                      v-model="item.size_id"
                      request-url="/api/dict/list"
                      label-key="dict_name"
                      :send-params="{
                        no_page: true,
                        group_key: 'size',
                      }"
                      @change="queryTemplateImg(item)"
                    ></base-request-select>
                  </a-form-item>
                  <a-form-item
                    label="材质"
                    :field="`products.${index}.element_id`"
                    :rules="requiredRules"
                  >
                    <base-request-select
                      v-model="item.element_id"
                      request-url="/api/dict/list"
                      label-key="dict_name"
                      :send-params="{
                        no_page: true,
                        group_key: 'element',
                      }"
                      @change="queryTemplateImg(item)"
                    ></base-request-select>
                  </a-form-item>

                  <a-form-item
                    label="大盘参考价"
                    :field="`products.${index}.price`"
                    :rules="requiredRules"
                  >
                    <a-input
                      v-model="item.price"
                      placeholder="请输入"
                      allow-clear
                    />
                  </a-form-item>
                  <a-form-item label="备注" :field="`products.${index}.remark`">
                    <a-input
                      v-model="item.remark"
                      placeholder="请输入"
                      allow-clear
                    />
                  </a-form-item>
                </a-col>
                <a-col :span="8">
                  <a-form-item
                    label="系列名称"
                    :field="`products.${index}.style_id`"
                    :rules="requiredRules"
                  >
                    <base-request-select
                      v-model="item.style_id"
                      request-url="/api/dict/list"
                      label-key="dict_name"
                      :send-params="{
                        no_page: true,
                        brand_id: item.brand_id,
                        group_key: 'style',
                      }"
                      @change="queryTemplateImg(item)"
                    ></base-request-select>
                  </a-form-item>
                  <a-form-item
                    label="颜色"
                    :field="`products.${index}.color_id`"
                    :rules="requiredRules"
                  >
                    <base-request-select
                      v-model="item.color_id"
                      request-url="/api/dict/list"
                      label-key="dict_name"
                      :send-params="{
                        no_page: true,
                        group_key: 'color',
                      }"
                      @change="queryTemplateImg(item)"
                    ></base-request-select>
                  </a-form-item>
                  <a-form-item
                    label="商品数量"
                    :field="`products.${index}.num`"
                    :rules="requiredRules"
                  >
                    <a-input-number
                      v-model="item.num"
                      placeholder="请输入"
                      :allow-clear="false"
                      :min="0"
                    />
                  </a-form-item>
                  <!-- <a-form-item
                    label="需求主播"
                    :field="`products.${index}.anchor_id`"
                    :rules="requiredRules"
                  >
                    <base-request-select
                      v-model="item.anchor_id"
                      request-url="/api/member/list"
                      label-key="username"
                      :send-params="{
                        no_page: true,
                        role_id: 6,
                      }"
                    ></base-request-select>
                  </a-form-item> -->
                  <a-form-item
                    label="需求直播间"
                    :field="`products.${index}.position`"
                    :rules="requiredRules"
                  >
                    <base-dict-select
                      v-model="item.position"
                      select-type="demandLiveRoom"
                      :allow-clear="false"
                    ></base-dict-select>
                  </a-form-item>
                </a-col>
                <a-col :span="8">
                  <div
                    class="wrap-box"
                    :class="[item.template_id ? 'success' : 'warning']"
                  >
                    <a-image
                      v-if="item.imgurl"
                      height="300"
                      width="200"
                      fit="contain"
                      :src="item.imgurl"
                      show-loader
                    >
                    </a-image>
                    <span v-else><icon-empty /> 暂无商品预览图</span>
                  </div>
                </a-col>
              </a-row>
            </div>
          </a-row>
        </a-card>
      </a-spin>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { onMounted, ref, unref } from 'vue';
  import request from '@/api/request';
  import { FieldRule, Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';
  // import UploadImageFile from '@/components/upload-file/upload-image-file.vue';
  import { useRoute, useRouter } from 'vue-router';

  const defaultForm = () => ({
    id: null,
    company_id: 1,
    department_id: 1,
    delete_ids: [],
    products: [
      {
        brand_id: null,
        style_id: null,
        size_id: null,
        color_id: null,
        element_id: null,
        num: null,
        remark: null,
        anchor_id: null,
        price: null,
        imgurl: null,
        position: null,
      },
    ],
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
  // 关闭回调
  function onClose() {
    visible.value = false;
    thisFormRef.value.clearValidate();
    // resetThisForm();
  }
  function sendInfo() {
    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        let unParams: any = unref(thisFormData);
        let params = JSON.parse(JSON.stringify(unParams));
        if (!isEditFlag.value) {
          delete params.id;
        }
        // 开始校验
        let noMatchIndex = params.products.findIndex((item: any) => {
          return !item.template_id;
        });
        if (noMatchIndex !== -1) {
          Message.warning(`未匹配到商品${noMatchIndex + 1}，请完善后重试！`);
          return;
        }
        loading.value = true;
        request('/api/demand/save', params)
          .then(() => {
            emits('createOver');
            Message.success('操作成功');
            onClose();
          })
          .finally(() => {
            loading.value = false;
          });
      }
    });
  }

  // 查询品牌名
  const queryTemplateImg = async (item: any) => {
    if (
      item.brand_id &&
      item.size_id &&
      item.style_id &&
      item.element_id &&
      item.color_id
    ) {
      request('/api/demand/template', {
        ...item,
      }).then((res) => {
        if (res.code && res.code === 200) {
          item.template_id = res.data.id;
          item.imgurl = res.data.imgurl;
        }
      });
    }
  };

  const getInfoFn = async (item: any) => {
    loading.value = true;
    request('/api/demand/info', {
      id: item.id,
    })
      .then((res) => {
        if (res.code && res.code === 200) {
          Object.assign(thisFormData.value, res.data);
          thisFormData.value.products.forEach((element: any) => {
            queryTemplateImg(element);
          });
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
    if (item && item.id) {
      isEditFlag.value = true;
      Object.assign(thisFormData.value, item);
      getInfoFn(item);
    }
  }

  function changeBrand(item: any) {
    Object.assign(item, {
      style_id: null,
    });
    queryTemplateImg(item);
  }

  // 新增商品需求
  const addGoods = (index: any) => {
    thisFormData.value.products.splice(index + 1, 0, {
      brand_id: null,
      style_id: null,
      size_id: null,
      color_id: null,
      element_id: null,
      num: null,
      remark: null,
      position: null,
      price: null,
      imgurl: null,
    });
    Message.success('添加成功');
  };

  const delGoods = (index: any, item: any) => {
    thisFormData.value.products.splice(index, 1);
    if (item.id) {
      thisFormData.value.delete_ids.push(item.id);
    }
    Message.success('删除成功');
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
    min-height: 300px;
    border-radius: 10px;
    margin-bottom: 20px;
    // &.warning {
    //   border-color: rgb(var(--warning-6));
    // }
    // &.success {
    //   border-color: rgb(var(--success-6));
    // }
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
      &.warning {
        border: 1px solid rgb(var(--warning-6));
      }
      &.success {
        border: 1px solid rgb(var(--success-6));
      }
    }
  }
</style>
