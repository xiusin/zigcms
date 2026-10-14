<template>
  <a-form ref="thisFormRef" :model="thisFormData" label-align="right">
    <a-spin :loading="loading">
      <a-row :gutter="12">
        <a-col :span="24">
          <a-form-item label="商品编码" field="brand_id" :rules="requiredRules">
            {{ thisFormData.product_no || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="供应商" field="supplier_name">
            {{ thisFormData.supplier_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="品牌" field="brand_id" :rules="requiredRules">
            {{ thisFormData.brand_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="系列名称" field="style_id" :rules="requiredRules">
            {{ thisFormData.style_name || '-' }}
          </a-form-item>
        </a-col>

        <a-form-item label="材质" field="element_id" :rules="requiredRules">
          {{ thisFormData.element_name || '-' }}
        </a-form-item>

        <a-form-item label="颜色" :field="`color_id`" :rules="requiredRules">
          {{ thisFormData.color_name || '-' }}
        </a-form-item>

        <a-col :span="24">
          <a-form-item label="商品规格" field="size_id" :rules="requiredRules">
            {{ thisFormData.size_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="商品名称" field="product_name">
            <a-input
              v-if="canOverWright"
              v-model="thisFormData.product_name"
              placeholder="请输入"
            ></a-input>
            <span v-else>
              {{ thisFormData.product_name || '-' }}
            </span>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="成色" field="quality_id" :rules="requiredRules">
            <base-request-select
              v-if="canOverWright"
              v-model="thisFormData.quality_id"
              request-url="/api/dict/list"
              label-key="dict_name"
              :send-params="{
                no_page: true,
                group_key: 'quality',
              }"
            ></base-request-select>
            <span v-else>
              {{ thisFormData.quality_name || '-' }}
            </span>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="配件" field="accessories" :rules="requiredRules">
            <a-checkbox-group
              v-if="canOverWright"
              v-model="thisFormData.accessories"
            >
              <a-checkbox
                v-for="(item, index) in typeDict"
                :key="index"
                :value="item.value"
              >
                {{ item.title }}</a-checkbox
              >
            </a-checkbox-group>
            <span v-else>
              {{
                thisFormData.accessories
                  ? thisFormData.accessories.join('，')
                  : '-'
              }}{{
                thisFormData.accessories_instruction
                  ? `(${thisFormData.accessories_instruction})`
                  : ''
              }}
            </span>
          </a-form-item>
        </a-col>
        <a-col v-if="canOverWright" :span="24">
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
            <a-input-group v-if="canOverWright">
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
            <span v-else>
              {{ thisFormData.dimension || '-' }}
            </span>
          </a-form-item>
        </a-col>

        <a-col :span="24">
          <a-form-item label="公价" field="public_price" :rules="requiredRules">
            <a-input-number
              v-if="canOverWright"
              v-model="thisFormData.public_price"
              placeholder="请输入"
              allow-clear
            />
            <span v-else> ¥{{ thisFormData.public_price || '-' }} </span>
          </a-form-item>
        </a-col>

        <a-col :span="24">
          <a-form-item label="商品定价" field="price" :rules="requiredRules">
            <a-input-number
              v-if="canOverWright"
              v-model="thisFormData.price"
              placeholder="请输入"
              allow-clear
            />
            <span v-else> ¥{{ thisFormData.price || '-' }} </span>
          </a-form-item>
        </a-col>
        <a-col v-if="show_in_warehouse_price" :span="24">
          <a-form-item
            label="入库价格"
            field="in_warehouse_price"
            :rules="requiredRules"
          >
            <a-input-number
              v-if="canOverWright"
              v-model="thisFormData.in_warehouse_price"
              placeholder="请输入"
              allow-clear
            />
            <span v-else> ¥{{ thisFormData.in_warehouse_price || '-' }} </span>
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
              :limit="canOverWright ? 5 : thisFormData.image_urls?.length"
              :only-show="!canOverWright"
              @change="validateFieldFn"
            ></base-image-upload>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="商品细节图"
            field="detail_image_urls"
            :rules="requiredRules"
          >
            <upload-photos
              v-model="thisFormData.detail_image_urls"
              :only-show="!canOverWright"
            ></upload-photos>
          </a-form-item>
        </a-col>
        <a-col :span="24">
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
            v-if="canOverWright"
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
          <a-form-item v-else label="生产年份" field="product_at">
            <span> {{ thisFormData.product_at || '-' }} </span>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="瑕疵说明" field="flaw_remark">
            <a-input
              v-if="canOverWright"
              v-model="thisFormData.flaw_remark"
              placeholder="请输入"
              allow-clear
            />
            <span v-else> {{ thisFormData.flaw_remark || '-' }} </span>
          </a-form-item>
        </a-col>
        <template v-if="!canOverWright">
          <a-col :span="24">
            <a-form-item
              label="实际出库价"
              field="outbound_price"
              :rules="requiredRules"
            >
              <a-input-number
                v-model="thisFormData.outbound_price"
                placeholder="请输入"
              ></a-input-number>
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item label="出库说明" field="instruction">
              <a-input
                v-model="thisFormData.instruction"
                placeholder="请输入"
              ></a-input>
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item
              label="售出渠道"
              field="sale_channel"
              :rules="requiredRules"
            >
              <base-dict-select
                v-model="thisFormData.sale_channel"
                select-type="saleChannel"
              ></base-dict-select>
            </a-form-item>
          </a-col>
          <a-col :span="24">
            <a-form-item
              :label="
                ({
                  SALE_CHANNEL_LIVE_ROOM: '主播',
                  SALE_CHANNEL_XHS: '小红书运营',
                  SALE_CHANNEL_PRIVATE: '私域运营',
                  SALE_CHANNEL_PROCURE: '采购',
                } as any )[thisFormData.sale_channel]
              "
              field="main_anchor_id"
              :rules="requiredRules"
            >
              <base-request-select
                v-model="thisFormData.main_anchor_id"
                request-url="/api/member/list"
                label-key="username"
                :send-params="{
                  no_page: true,
                  role_id: ({
                    SALE_CHANNEL_LIVE_ROOM: 6,
                    SALE_CHANNEL_XHS: 21,
                    SALE_CHANNEL_PRIVATE: 20,
                    SALE_CHANNEL_PROCURE: 12,
                  } as any )[thisFormData.sale_channel],
                }"
              ></base-request-select>
            </a-form-item>
          </a-col>
          <a-col
            v-if="thisFormData.sale_channel === 'SALE_CHANNEL_LIVE_ROOM'"
            :span="24"
          >
            <a-form-item
              label="场控"
              field="sec_anchor_id"
              :rules="[
                {
                  required:
                    thisFormData.sale_channel === 'SALE_CHANNEL_LIVE_ROOM',
                  message: '请输入',
                },
              ]"
            >
              <base-request-select
                v-model="thisFormData.sec_anchor_id"
                request-url="/api/member/list"
                label-key="username"
                :send-params="{
                  no_page: true,
                  role_id: 24,
                }"
              ></base-request-select>
            </a-form-item>
          </a-col>
        </template>
      </a-row>
    </a-spin>
  </a-form>
</template>

<script setup lang="ts">
  import { reactive, ref, watch, computed } from 'vue';
  import request from '@/api/request';
  import uploadPhotos from '@/views/operation/consignment-manage/upload-photos.vue';
  import { Message } from '@arco-design/web-vue';
  import { useUserStore } from '@/store';

  const userStore = useUserStore();
  const { role_ids } = userStore;
  const show_in_warehouse_price = ref(
    role_ids.filter((id) => {
      return ![4, 5, 6, 11, 18, 19, 20, 21, 22, 23, 24].includes(id);
    }).length > 0
  );

  const props = defineProps({
    hideFooter: {
      type: Boolean,
      default: () => false,
    },
    initData: {
      type: Object,
      default: () => {},
    },
    canOverWright: {
      type: Boolean,
      default: () => false,
    },
  });

  const emit = defineEmits(['submitSuccess']);

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

  const loading = ref(false);
  const defaultForm = () => ({
    product_name: null,
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
    receiver_name: null,
    receiver_mobile: null,
    receiver_address: null,
    outbound_price: null,
    instruction: null,
    sale_channel: null,
    main_anchor_id: null,
    sec_anchor_id: null,
    dimension: null,
    dimension_length: null,
    dimension_height: null,
    dimension_width: null,

    product_at: '',
  });
  const requiredRules: any = {
    required: true,
    message: '请填写',
  };
  const thisFormData: any = ref(defaultForm());
  const thisFormRef = ref();

  const baseURL = import.meta.env.VITE_BASE_URL as string;
  const detail_image_preview_url = computed(() => {
    return `${baseURL}/be/api/warehouse/product/image?id=${thisFormData.value.id}`;
  });

  const validateFieldFn = () => {
    thisFormRef.value.validateField('image_urls');
  };

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
    // 校验图片上传的逻辑
    // if (thisFormData.value.image_urls?.length === 0) {
    //   Message.warning('请上传商品图片！');
    //   return;
    // }
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
        request('/api/warehouse/product/update-receiver', thisFormData.value)
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

  function editInfo() {
    if (
      !thisFormData.value.dimension_length ||
      !thisFormData.value.dimension_height ||
      !thisFormData.value.dimension_width
    ) {
      thisFormData.value.dimension = '';
    }
    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        loading.value = true;
        delete thisFormData.value.status;
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

  const isNull = ref(false);
  const isXP = ref(false);
  const product_at = ref('');
  watch(
    [isNull, isXP, product_at],
    ([isNullv, isXPv, product_atv], [isNullOldv, isXPOldv, product_atOldv]) => {
      thisFormData.value.product_at =
        (isNullv && '无') || (isXPv && '芯片') || product_atv;
      thisFormRef.value?.validateField('product_at');
    }
  );
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

  watch(
    thisFormData,
    (v) => {
      console.log('watch thisFormData: ', v);
    },
    {
      deep: true,
    }
  );

  watch(
    () => props.initData,
    (newVal) => {
      if (newVal) {
        console.log('我的值', newVal);
        let tmpObj = JSON.parse(JSON.stringify(newVal));
        Object.assign(thisFormData.value, tmpObj);
        Object.assign(thisFormData.value, {
          price: Number(tmpObj.price) || null,
          in_warehouse_price: Number(tmpObj.in_warehouse_price) || null,
          outbound_price: Number(tmpObj.outbound_price) || null,
          public_price: Number(tmpObj.public_price) || null,
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

        isXP.value = false;
        isNull.value = false;
        product_at.value = '';
        switch (thisFormData.value.product_at) {
          case '芯片':
            isXP.value = true;
            break;
          case '无':
            isNull.value = true;
            break;
          default:
            product_at.value = thisFormData.value.product_at;
            break;
        }
        console.log('最后的值', thisFormData.value);
      }
    },
    {
      immediate: true,
    }
  );

  defineExpose({ sendInfo, editInfo });
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
