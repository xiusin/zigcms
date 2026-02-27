<template>
  <a-form ref="thisFormRef" :model="thisFormData" label-align="right">
    <a-spin :loading="loading">
      <a-row :gutter="12">
        <a-col v-if="!hideFooter" :span="24">
          <a-form-item
            label="入库类型"
            field="in_warehouse_type"
            :rules="requiredRules"
          >
            <a-radio-group
              v-model="thisFormData.in_warehouse_type"
              type="button"
              @change="thisFormData.supplier_id = null"
            >
              <a-radio value="IN_WAREHOUSE_TYPE_SUPPLIER">供应商寄卖</a-radio>
              <a-radio value="IN_WAREHOUSE_TYPE_PERSON">个人寄卖</a-radio>
            </a-radio-group>
          </a-form-item>
          <a-form-item
            v-if="
              thisFormData.in_warehouse_type == 'IN_WAREHOUSE_TYPE_SUPPLIER'
            "
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
        <a-col v-else :span="24">
          <a-form-item label="商品编码" field="brand_id" :rules="requiredRules">
            <!-- <a-input v-model="thisFormData.product_no" readonly></a-input> -->
            {{ thisFormData.product_no }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="品牌" field="brand_id" :rules="requiredRules">
            <span v-if="needOverWright"> {{ thisFormData.brand_name }}</span>
            <base-request-select
              v-else
              v-model="thisFormData.brand_id"
              request-url="/api/brand/list"
              label-key="brand_name"
              :send-params="{ no_page: true }"
            ></base-request-select>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="系列名称" field="style_id" :rules="requiredRules">
            <span v-if="needOverWright"> {{ thisFormData.style_name }}</span>
            <base-request-select
              v-else
              v-model="thisFormData.style_id"
              request-url="/api/dict/list"
              label-key="dict_name"
              :send-params="{
                no_page: true,
                brand_id: thisFormData.brand_id,
                group_key: 'style',
              }"
            ></base-request-select>
          </a-form-item>
        </a-col>

        <a-form-item label="材质" field="element_id" :rules="requiredRules">
          <span v-if="needOverWright"> {{ thisFormData.element_name }}</span>
          <base-request-select
            v-else
            v-model="thisFormData.element_id"
            request-url="/api/dict/list"
            label-key="dict_name"
            :send-params="{
              no_page: true,
              group_key: 'element',
            }"
          ></base-request-select>
        </a-form-item>

        <a-form-item label="颜色" :field="`color_id`" :rules="requiredRules">
          <span v-if="needOverWright"> {{ thisFormData.color_name }}</span>
          <base-request-select
            v-else
            v-model="thisFormData.color_id"
            request-url="/api/dict/list"
            label-key="dict_name"
            :send-params="{
              no_page: true,
              group_key: 'color',
            }"
          ></base-request-select>
        </a-form-item>

        <a-col :span="24">
          <a-form-item label="商品规格" field="size_id" :rules="requiredRules">
            <span v-if="needOverWright"> {{ thisFormData.size_name }}</span>
            <base-request-select
              v-else
              v-model="thisFormData.size_id"
              request-url="/api/dict/list"
              label-key="dict_name"
              :send-params="{
                no_page: true,
                group_key: 'size',
              }"
            ></base-request-select>
          </a-form-item>
        </a-col>

        <a-col :span="24">
          <a-form-item label="商品名称" field="product_name">
            <a-input
              v-model="thisFormData.product_name"
              placeholder="请输入"
              allow-clear
            />
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="成色" field="quality_id" :rules="requiredRules">
            <base-request-select
              v-model="thisFormData.quality_id"
              request-url="/api/dict/list"
              label-key="dict_name"
              :send-params="{
                no_page: true,
                group_key: 'quality',
              }"
            ></base-request-select>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="配件" field="accessories" :rules="requiredRules">
            <a-checkbox-group v-model="thisFormData.accessories">
              <a-checkbox
                v-for="(item, index) in typeDict"
                :key="index"
                :value="item.value"
              >
                {{ item.title }}</a-checkbox
              >
            </a-checkbox-group>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="配件备注" field="accessories_instruction">
            <a-input
              v-model="thisFormData.accessories_instruction"
              placeholder="请输入"
              allow-clear
            />
          </a-form-item>
        </a-col>

        <a-col :span="24">
          <a-form-item label="尺寸" field="dimension" :rules="requiredRules">
            <a-input-group>
              <a-input-number
                v-model="thisFormData.dimension_length"
                :style="{ width: '120px' }"
                placeholder="长"
                class="mr-10"
                hide-button
                @change="dimensionChange"
              >
                <template #append> cm </template>
              </a-input-number>
              <span class="mr-10"> ✖️ </span>
              <a-input-number
                v-model="thisFormData.dimension_height"
                :style="{ width: '120px' }"
                class="mr-10"
                placeholder="高"
                hide-button
                @change="dimensionChange"
              >
                <template #append> cm </template>
              </a-input-number>
              <span class="mr-10"> ✖️ </span>
              <a-input-number
                v-model="thisFormData.dimension_width"
                class="mr-10"
                :style="{ width: '120px' }"
                placeholder="宽"
                hide-button
                @change="dimensionChange"
              >
                <template #append> cm </template>
              </a-input-number>
            </a-input-group>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="公价" field="public_price" :rules="requiredRules">
            <a-input-number
              v-model="thisFormData.public_price"
              placeholder="请输入"
              allow-clear
            />
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="商品定价" field="price" :rules="requiredRules">
            <a-input-number
              v-model="thisFormData.price"
              placeholder="请输入"
              allow-clear
            />
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="入库价格"
            field="in_warehouse_price"
            :rules="requiredRules"
          >
            <a-input-number
              v-model="thisFormData.in_warehouse_price"
              placeholder="请输入"
              allow-clear
            />
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="商品图片"
            field="platform"
            :rules="{
              required: true,
              message: '请上传',
            }"
          >
            <a-image
              v-if="thisFormData.main_imgurl"
              height="120"
              width="120"
              :src="thisFormData.main_imgurl"
              :preview="true"
              style="margin: 0 20px 20px 0"
              show-loader
            ></a-image>
            <base-image-upload
              v-model="thisFormData.image_urls"
              :send-params="{}"
              :limit="5"
              @change="validateFieldFn"
            ></base-image-upload>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="商品细节图" field="detail_image_urls">
            <upload-photos
              v-model="thisFormData.detail_image_urls"
            ></upload-photos>
          </a-form-item>
        </a-col>
        <a-col v-if="hideFooter" :span="24">
          <a-form-item label="商品详情图" field="detail_image_url">
            <a-image
              height="120"
              width="120"
              :src="detail_image_preview_url"
              :preview="true"
              show-loader
            ></a-image>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="生产年份"
            field="product_at"
            :rules="requiredRules"
          >
            <a-year-picker
              v-model="product_at"
              style="width: 200px"
              allow-clear
              :disabled="isXP || isNull"
            />
            <a-checkbox
              :model-value="isXP"
              value="芯片"
              style="margin-left: 50px"
              @click="isXP = !isXP"
            >
              芯片
            </a-checkbox>
            <a-checkbox
              :model-value="isNull"
              value="无"
              style="margin-left: 50px"
              @click="isNull = !isNull"
            >
              无
            </a-checkbox>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="瑕疵说明" field="flaw_remark">
            <a-input
              v-model="thisFormData.flaw_remark"
              placeholder="请输入"
              allow-clear
            />
          </a-form-item>
        </a-col>
        <a-col v-if="!hideFooter" :span="24" class="footer-wrap">
          <a-form-item label="">
            <div class="button-box">
              <a-button size="small" type="primary" long @click="sendInfo">
                提交入库
              </a-button>
            </div>
          </a-form-item>
        </a-col>
      </a-row>
    </a-spin>
  </a-form>
</template>

<script setup lang="ts">
  import { unref, ref, watch, computed } from 'vue';
  import request from '@/api/request';
  import uploadPhotos from './upload-photos.vue';
  import { Message } from '@arco-design/web-vue';

  const props = defineProps({
    hideFooter: {
      type: Boolean,
      default: () => false,
    },
    initData: {
      type: Object,
      default: () => {},
    },
  });

  const isNull = ref(false);
  const isXP = ref(false);
  const product_at = ref('');

  const emit = defineEmits(['submitSuccess']);

  const loading = ref(false);
  const defaultForm = () => ({
    // product_name: null,
    brand_id: null,
    brand_name: null,
    color_id: null,
    color_name: null,
    size_id: null,
    size_name: null,
    style_id: null,
    style_name: null,
    anchor_id: null,
    anchor_name: null,
    element_id: null,
    element_name: null,
    quality_id: null,
    in_warehouse_type: 'IN_WAREHOUSE_TYPE_SUPPLIER',
    in_warehouse_price: null,
    price: null,
    platform: 'PLATFORM_APP',
    image_urls: [],
    detail_image_urls: {
      主图: [],
      正面图: [],
      背面图: [],
      五金图: [],
      底面图: [],
      内衬图: [],
      LOGO: [],
      配件图: [],
      瑕疵图: [],
    },
    accessories: [],
    accessories_instruction: '',
    dimension: null,
    dimension_length: null,
    dimension_height: null,
    dimension_width: null,

    product_at: '',
    flaw_remark: '',
  });
  const requiredRules: any = {
    required: true,
    message: '请填写',
  };
  const thisFormData: any = ref(defaultForm());
  const thisFormRef = ref();
  watch([isNull, isXP, product_at], ([isNullv, isXPv, product_atv]) => {
    thisFormData.value.product_at =
      (isNullv && '无') || (isXPv && '芯片') || product_atv;
    thisFormRef.value.validateField('product_at');
  });
  watch(isNull, (isNullv) => {
    if (isNullv) {
      isXP.value = false;
    }
  });
  watch(isXP, (isXPv) => {
    if (isXPv) {
      isNull.value = false;
    }
  });

  const typeDict = [
    {
      title: '盒子',
      value: '盒子',
    },
    {
      title: '防尘袋',
      value: '防尘袋',
    },
    {
      title: '购物袋',
      value: '购物袋',
    },
    {
      title: '钥匙',
      value: '钥匙',
    },
    {
      title: '锁',
      value: '锁',
    },
    {
      title: '小票',
      value: '小票',
    },
    {
      title: '镜子',
      value: '镜子',
    },
    {
      title: '身份卡',
      value: '身份卡',
    },
    {
      title: '皮牌',
      value: '皮牌',
    },
    {
      title: '肩带',
      value: '肩带',
    },
    {
      title: '子袋',
      value: '子袋',
    },
    {
      title: '羊毛毡',
      value: '羊毛毡',
    },
    {
      title: 'CCIC',
      value: 'CCIC',
    },
    {
      title: '/',
      value: '/',
    },
  ];

  const validateFieldFn = () => {
    thisFormRef.value.validateField('image_urls');
  };

  const baseURL = import.meta.env.VITE_BASE_URL as string;
  const detail_image_preview_url = computed(() => {
    return `${baseURL}/be/api/warehouse/product/image?id=${thisFormData.value.id}`;
  });

  const dimensionChange = () => {
    if (
      thisFormData.value.dimension_length &&
      thisFormData.value.dimension_height &&
      thisFormData.value.dimension_width
    ) {
      thisFormData.value.dimension = `长${thisFormData.value.dimension_length}cm*高${thisFormData.value.dimension_height}cm*宽${thisFormData.value.dimension_width}cm`;
    } else {
      thisFormData.value.dimension = '缺少数据';
    }
  };

  function sendInfo() {
    if (
      !thisFormData.value.dimension_length ||
      !thisFormData.value.dimension_height ||
      !thisFormData.value.dimension_width
    ) {
      thisFormData.value.dimension = '';
    }
    // 校验图片上传的逻辑
    if (
      !thisFormData.value.image_urls ||
      thisFormData.value.image_urls?.length === 0
    ) {
      Message.warning('请上传商品图片！');
      return;
    }

    // let no_img_str: any = '';
    // let keysArr = Object.keys(thisFormData.value.detail_image_urls);
    // keysArr.forEach((element: any) => {
    //   if (thisFormData.value.detail_image_urls[element].length === 0) {
    //     no_img_str += `${element}、`;
    //   }
    // });
    // if (no_img_str) {
    //   Message.warning(`请上传商品${no_img_str}！`);
    //   return;
    // }

    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        loading.value = true;
        request('/api/warehouse/product/save', thisFormData.value)
          .then((resData) => {
            Message.success('操作成功');
            emit('submitSuccess');
          })
          .finally(() => {
            loading.value = false;
          });
      }
    });
  }

  const needOverWright = ref(false);
  watch(
    () => props.initData,
    (newVal) => {
      if (newVal) {
        console.log('我的值', newVal);
        needOverWright.value = true;
        let tmpObj = JSON.parse(JSON.stringify(newVal));
        Object.assign(thisFormData.value, tmpObj);
        Object.assign(thisFormData.value, {
          price: Number(tmpObj.price) || null,
          in_warehouse_price: Number(tmpObj.in_warehouse_price) || null,
          platform: tmpObj.platform || 'PLATFORM_APP',
          detail_image_urls: tmpObj.detail_image_urls
            ? tmpObj.detail_image_urls
            : {
                主图: [],
                正面图: [],
                背面图: [],
                五金图: [],
                底面图: [],
                内衬图: [],
                LOGO: [],
                配件图: [],
                瑕疵图: [],
              },
        });
        console.log('最后的值', thisFormData.value);
      }
    },
    {
      immediate: true,
    }
  );

  defineExpose({ sendInfo });
</script>

<style scoped lang="less">
  .form-body {
    margin: 20px 10%;
    .footer-wrap {
      display: flex;
      justify-content: center;
      .button-box {
        width: 100%;
        margin-top: 20px;
      }
    }
  }

  :deep(.arco-checkbox-group .arco-checkbox) {
    margin-bottom: 12px;
  }
</style>
