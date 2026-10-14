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
            {{ thisFormData.product_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="成色" field="quality_id" :rules="requiredRules">
            {{ thisFormData.quality_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="配件" field="accessories" :rules="requiredRules">
            {{ thisFormData.accessories.join('，')
            }}{{
              thisFormData.accessories_instruction
                ? `(${thisFormData.accessories_instruction})`
                : ''
            }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="尺寸" field="dimension" :rules="requiredRules">
            {{ thisFormData.dimension || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24" :rules="requiredRules">
          <a-form-item label="公价" field="public_price" :rules="requiredRules">
            ¥{{ thisFormData.public_price || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="商品定价" field="price" :rules="requiredRules">
            ¥{{ thisFormData.price || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="入库价格"
            field="in_warehouse_price"
            :rules="requiredRules"
          >
            ¥{{ thisFormData.in_warehouse_price || '-' }}
          </a-form-item>
        </a-col>

        <a-col :span="24">
          <a-form-item
            label="实际出库价"
            field="outbound_price"
            :rules="requiredRules"
          >
            ¥{{ thisFormData.outbound_price || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="出库说明" field="instruction">
            {{ thisFormData.instruction || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="入库渠道"
            field="accessories"
            :rules="requiredRules"
          >
            {{ thisFormData.in_warehouse_type_text || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="备注" field="remark">
            {{ thisFormData.remark || '-' }}
          </a-form-item>
        </a-col>

        <a-col :span="24">
          <a-form-item label="申请人" field="user_name" :rules="requiredRules">
            {{ thisFormData.user_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item label="售出渠道" field="sale_channel_text">
            {{ thisFormData.sale_channel_text || '-' }}
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
            field="main_anchor_name"
          >
            {{ thisFormData.main_anchor_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col
          v-if="thisFormData.sale_channel === 'SALE_CHANNEL_LIVE_ROOM'"
          :span="24"
        >
          <a-form-item label="场控" field="sec_anchor_name">
            {{ thisFormData.sec_anchor_name || '-' }}
          </a-form-item>
        </a-col>
        <a-col :span="24">
          <a-form-item
            label="申请时间"
            field="created_at"
            :rules="requiredRules"
          >
            {{ thisFormData.created_at || '-' }}
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
              :limit="thisFormData.image_urls.length"
              :only-show="true"
              :disabled="true"
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
              :only-show="true"
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
      </a-row>
    </a-spin>
  </a-form>
</template>

<script setup lang="ts">
  import { reactive, ref, watch, computed } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
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
  });

  const emit = defineEmits(['submitSuccess']);

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
    express_no: null,
    approval_id: null,
    remark: null,
  });
  const requiredRules: any = {
    required: true,
    message: '请填写',
  };
  const thisFormData: any = ref(defaultForm());
  const thisFormRef = ref();

  const validateFieldFn = () => {
    thisFormRef.value.validateField('image_urls');
  };

  const baseURL = import.meta.env.VITE_BASE_URL as string;
  const detail_image_preview_url = computed(() => {
    return `${baseURL}/be/api/warehouse/product/image?id=${thisFormData.value.product_id}`;
  });

  function sendInfo() {
    loading.value = true;
    request('/api/approval/save', {
      id: thisFormData.value.approval_id,
      status: 'APPROVAL_STATUS_OK',
    })
      .then((resData) => {
        Message.success('操作成功');
        emit('submitSuccess');
      })
      .finally(() => {
        loading.value = false;
      });
  }

  function denyInfo() {
    loading.value = true;
    request('/api/approval/save', {
      id: thisFormData.value.approval_id,
      status: 'APPROVAL_STATUS_DENY',
    })
      .then((resData) => {
        Message.success('操作成功');
        emit('submitSuccess');
      })
      .finally(() => {
        loading.value = false;
      });
  }

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
          platform: tmpObj.platform || 'PLATFORM_APP',
          detail_image_urls:
            tmpObj.detail_image_urls && tmpObj.detail_image_urls.主图
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

  defineExpose({ sendInfo, denyInfo });
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
