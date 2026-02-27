<template>
  <a-input
    v-model="curVal"
    :placeholder="placeholder"
    :allow-clear="allowClear"
    :disabled="disabled"
    @input="handleChange"
  />
</template>

<script lang="ts" setup>
  import { watch, ref, PropType } from 'vue';
  import { useDebounceFn } from '@vueuse/core';

  interface optionItem {
    // new
    [key: string]: any;
  }

  type sizeType = 'mini' | 'small' | 'medium' | 'large' | undefined;

  const props = defineProps({
    placeholder: {
      type: String,
      default: () => '请输入',
    },
    dataList: {
      type: Array as PropType<optionItem[]>,
      default: () => [],
    },
    modelValue: {
      type: [String, Number, Array, Object],
      default: () => '',
    },
    // id的键值
    allowClear: {
      type: [Boolean],
      default: () => true,
    },
    multiple: {
      type: [Boolean],
      default: () => false,
    },
    allowSearch: {
      type: Boolean,
      default: () => true,
    },
    loading: {
      type: Boolean,
      default: () => false,
    },
    disabled: {
      type: Boolean,
      default: () => false,
    },
    // 需要禁用的值
    disabledValues: {
      type: Array,
      default: () => [],
    },
    // 遇到零是否需要重置为空
    zeroEmpty: {
      type: Boolean,
      default: () => true,
    },
    // 选择框大小
    size: {
      type: String as PropType<sizeType>,
      default: 'medium',
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);

  const curVal = ref<any>('');
  watch(
    () => props.modelValue,
    (newVal) => {
      if (!newVal && props.zeroEmpty) {
        curVal.value = '';
      } else {
        curVal.value = newVal;
      }
    },
    {
      immediate: true,
    }
  );

  function changeFn() {
    if (curVal.value) {
      emit('change', curVal.value);
    }
  }
  const debounceFn = useDebounceFn(changeFn, 800);

  const handleChange = (val: any) => {
    emit('update:modelValue', val);

    debounceFn();
  };
</script>

<style lang="less"></style>
