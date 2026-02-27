<template>
  <div class="photo-box">
    <base-image-upload
      v-model="goodsInfo.主图"
      :limit="1"
      :send-params="{
        pic_type: '主图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.正面图"
      :limit="1"
      :send-params="{
        pic_type: '正面图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.背面图"
      :limit="1"
      :send-params="{
        pic_type: '背面图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.五金图"
      :limit="1"
      :send-params="{
        pic_type: '五金图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.底面图"
      :limit="1"
      :send-params="{
        pic_type: '底面图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.内衬图"
      :limit="1"
      :send-params="{
        pic_type: '内衬图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.LOGO"
      :limit="1"
      :send-params="{
        pic_type: 'LOGO',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.配件图"
      :limit="1"
      :send-params="{
        pic_type: '配件图',
      }"
      :only-show="onlyShow"
      :disabled="onlyShow"
    ></base-image-upload>
    <base-image-upload
      v-model="goodsInfo.瑕疵图"
      :send-params="{
        pic_type: '瑕疵图',
      }"
      :only-show="onlyShow"
      :need-right="true"
      :limit="props.onlyShow ? goodsInfo.瑕疵图.length : 5"
      :disabled="onlyShow"
    ></base-image-upload>
  </div>
</template>

<script lang="ts" setup>
  import { ref, watch } from 'vue';

  const emit = defineEmits(['update:modelValue', 'change']);

  const props = defineProps({
    modelValue: {
      type: [String, Number, Array, Object],
      default: () => '',
    },
    onlyShow: {
      type: Boolean,
      default: false,
    },
  });
  const goodsInfo: any = ref({
    主图: [],
    正面图: [],
    背面图: [],
    五金图: [],
    底面图: [],
    内衬图: [],
    LOGO: [],
    配件图: [],
    瑕疵图: [],
  });

  // 监听回显的数据 如果回显数据存在且fileList不存在 fileList不一致 则更新fileList
  watch(
    () => props.modelValue,
    (val) => {
      if (JSON.stringify(val) !== goodsInfo.value) {
        goodsInfo.value = val;
      }
    },
    {
      immediate: true,
      deep: true,
    }
  );
  watch(
    () => goodsInfo,
    (val) => {
      if (val.value !== props.modelValue) {
        console.log('我们不一样', val);
        emit('update:modelValue', val);
      }
    },
    {
      immediate: true,
      deep: true,
    }
  );
</script>

<style lang="less" scoped>
  .photo-box {
    display: flex;
    flex-wrap: wrap;
    :deep(.upload-image-box) {
      margin-right: 20px;
    }
    // justify-content: space-between;
  }
</style>
