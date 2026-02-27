<template>
  <a-cascader
    :model-value="modelValue"
    :placeholder="placeholder"
    :field-names="fieldNames"
    :allow-clear="allowClear"
    :options="showData"
    :format-label="format"
    :check-strictly="checkStrictly"
    allow-search
    v-bind="$attrs"
    @change="handleChange"
  >
  </a-cascader>
</template>

<script lang="ts" setup>
  import { computed, onMounted, ref } from 'vue';
  import { isArray } from 'lodash';
  import request from '@/api/request';

  const props = defineProps({
    placeholder: {
      type: String,
      default: '请选择',
    },
    treeData: {
      type: Array,
      default: () => [],
    },
    apiUrl: {
      type: String,
      default: '',
    },
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
    // id的键值
    valueKey: {
      type: [String, Number],
      default: () => 'key',
    },
    // label的值
    labelKey: {
      type: [String, Number],
      default: () => 'title',
    },
    allowClear: {
      type: [Boolean],
      default: () => true,
    },
    checkStrictly: {
      type: Boolean,
      default: () => true,
    },
    sendParams: {
      type: Object,
      default: null,
    },
  });
  const emit = defineEmits(['change', 'update:modelValue']);
  const fieldNames: any = computed(() => ({
    value: props.valueKey,
    label: props.labelKey,
  }));
  const dirList = ref<any[]>([]);
  const showData = computed(
    () => (props.treeData?.length ? props.treeData : dirList.value) || []
  );

  onMounted(() => {
    if (props.apiUrl) {
      request(props.apiUrl, props.sendParams).then((resData) => {
        dirList.value = isArray(resData.data) ? resData.data : [resData.data];
      });
    }
  });
  const format = (options: any) => {
    const labels = options.slice(-1)[0].label;
    return labels;
  };
  const handleChange = (val: any) => {
    emit('update:modelValue', val);
    emit('change', val);
  };
</script>

<style lang="less"></style>
