<template>
  <BaseSelect
    v-model="curVal"
    :data-list="dataList"
    :value-key="valueKey"
    :label-key="curlabelKey"
    :placeholder="placeholder"
    :loading="loading"
    :multiple="multiple"
    :max-tag-count="maxTagCount"
    @change="handleChange"
  ></BaseSelect>
</template>

<script lang="ts" setup>
  import { computed, onMounted, ref, watch } from 'vue';
  import request from '@/api/request';
  import { cloneDeep } from 'lodash';
  import BaseSelect from './base-select.vue';

  const props = defineProps({
    placeholder: {
      type: String,
      default: () => '请选择',
    },
    getDataList: {
      type: Function,
      default: null,
    },
    modelValue: {
      type: [String, Number, Array, Object],
      default: () => '',
    },
    valueKey: {
      type: [String],
      default: () => 'id',
    },
    labelKey: {
      type: [String],
      default: () => 'name',
    },
    sendParams: {
      type: Object,
      default: () => {
        return {};
      },
    },
    multiple: {
      type: Boolean,
      default: () => false,
    },
    maxTagCount: {
      type: [Number],
      default: () => 0,
    },
    requestUrl: {
      type: String,
      default: () => '',
    },
    api: {
      type: String,
      default: () => '',
    },
    selectFirst: {
      type: Boolean,
      default: () => false,
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);
  const loading = ref(false);
  const curVal = ref<any>('');
  const curParams = ref({});
  const initFlag = ref(false);
  watch(
    () => props.modelValue,
    (newVal) => {
      if (!newVal) {
        curVal.value = '';
      } else {
        curVal.value = newVal;
      }
    },
    {
      immediate: true,
    }
  );
  const dataList = ref([]);
  const handleChange = (val: any, item: any) => {
    emit('update:modelValue', val);
    emit('change', val, item);
  };

  const apis: any = {
    user: {
      url: '/api/userList',
      labelKey: 'realname',
    },
    product: {
      url: '/api/productList',
      labelKey: 'product_name',
    },
    role: {
      url: '/api/roleList',
      labelKey: 'role_name',
    },
    actor: {
      url: '/api/actor/selectList',
      labelKey: 'name',
    },
  };
  const apiUrl = computed(() => props.requestUrl || apis[props.api]?.url);
  const curlabelKey = computed(
    () => apis[props.api]?.labelKey || props.labelKey
  );
  const getList = async () => {
    if (!apiUrl.value) return null;
    loading.value = true;
    const res = await request(apiUrl.value, props.sendParams);
    if (props.getDataList) {
      dataList.value = props.getDataList(res.data);
    } else {
      dataList.value = res.data.data || res.data;
    }
    if (
      props.selectFirst &&
      dataList.value?.length &&
      (!props.modelValue ||
        (Array.isArray(props.modelValue) && !props.modelValue.length))
    ) {
      if (props.multiple || Array.isArray(props.modelValue)) {
        handleChange(
          [dataList.value[0]?.[props.valueKey]],
          [dataList.value[0]]
        );
      } else {
        handleChange(dataList.value[0]?.[props.valueKey], dataList.value[0]);
      }
    }

    loading.value = false;
  };
  watch(
    () => props.sendParams,
    (newVal) => {
      // 如果和curParams不同或者没有初始化 发起请求 缓存当前的新值
      if (
        JSON.stringify(newVal) !== JSON.stringify(curParams.value) ||
        !initFlag.value
      ) {
        curParams.value = cloneDeep(newVal);
        initFlag.value = true;
        getList();
      }
    },
    {
      immediate: true,
      deep: true,
    }
  );

  onMounted(() => {
    getList();
  });
</script>

<style lang="less"></style>
