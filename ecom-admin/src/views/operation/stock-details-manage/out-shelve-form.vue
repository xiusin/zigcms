<template>
  <a-form ref="thisFormRef" :model="thisFormData" label-align="right">
    <a-spin :loading="loading">
      <a-row :gutter="12">
        <a-col :span="24">
          <a-form-item label="商品编码" field="brand_id">
            {{ thisFormData.product_no || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="品牌" field="brand_id">
            {{ thisFormData.brand_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="系列名称" field="style_id">
            {{ thisFormData.style_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="入库价格" field="in_warehouse_price">
            <span> ¥{{ thisFormData.in_warehouse_price || '-' }} </span>
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
            label="上架平台"
            field="accessories"
            :rules="requiredRules"
          >
            <a-checkbox-group v-model="thisFormData.shelve_platforms">
              <a-checkbox
                v-for="(item, index) in platforms"
                :key="index"
                :value="item.value"
              >
                {{ item.title }}
              </a-checkbox>
            </a-checkbox-group>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="商品图片" field="platform" :rules="requiredRules">
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
          <a-form-item
            label="商品细节图"
            field="detail_image_urls"
            :rules="requiredRules"
          >
            <upload-photos
              v-model="thisFormData.detail_image_urls"
            ></upload-photos>
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="商品规格" field="size_id" :rules="requiredRules">
            <base-request-select
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
          <a-form-item
            label="商品名称"
            field="product_name"
            :rules="requiredRules"
          >
            <a-input
              v-model="thisFormData.product_name"
              placeholder="请输入"
            ></a-input>
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
          <a-form-item
            label="商品详情配置"
            field="accessories"
            :rules="requiredRules"
          >
            <a-checkbox-group v-model="thisFormData.detail_options">
              <a-checkbox
                v-for="(item, index) in detailList_option"
                :key="index"
                :value="item.value"
              >
                {{ item.title }}</a-checkbox
              >
            </a-checkbox-group>
          </a-form-item>
        </a-col>
      </a-row>
    </a-spin>
  </a-form>
</template>

<script setup lang="ts">
  import { reactive, ref, watch, computed, onMounted } from 'vue';
  import request from '@/api/request';
  import uploadPhotos from '@/views/operation/consignment-manage/upload-photos.vue';
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
      title: '皮带',
      value: '皮带',
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

  const platforms = [
    {
      title: 'APP',
      value: 'PLATFORM_APP',
    },
    {
      title: '抖店',
      value: 'PLATFORM_DOUDIAN',
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
    main_anchor_id: null,
    sec_anchor_id: null,
    dimension: null,
    dimension_length: null,
    dimension_height: null,
    dimension_width: null,
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
    if (thisFormData.value.image_urls?.length === 0) {
      Message.warning('请上传商品图片！');
      return;
    }
    let no_img_str: any = '';
    let keysArr = Object.keys(thisFormData.value.detail_image_urls);
    let hasoneimg = false;
    keysArr.forEach((element: any) => {
      if (thisFormData.value.detail_image_urls[element].length === 0) {
        no_img_str += `${element}、`;
      } else {
        hasoneimg = true;
      }
    });
    if (no_img_str && !hasoneimg) {
      Message.warning(`请上传商品${no_img_str}！`);
      return;
    }

    console.log('thisFormData.value: ', thisFormData.value);

    thisFormRef.value.validate(async (errorInfo: any) => {
      if (!errorInfo) {
        loading.value = true;
        request('/api/warehouse/product/shelve', thisFormData.value)
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

  const detailList = ref([]);
  const detailList_option = computed(() => {
    return detailList.value.map(({ title, id }) => {
      return {
        title,
        value: id,
      };
    });
  });

  onMounted(async () => {
    const detailList_data = await request('/api/product/detail/option/list', {
      no_page: true,
    });
    detailList.value = detailList_data.data;
    console.log('detailList: ', detailList.value);
  });
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
