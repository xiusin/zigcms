<template>
  <a-select
    v-model="curVal"
    :loading="loading"
    :multiple="multiple || theMultiple"
    :placeholder="placeholder"
    :allow-clear="allowClear"
    :allow-search="allowSearch"
    :disabled="disabled"
    :size="size"
    :max-tag-count="maxTagCount"
    :virtual-list-props="virtualList"
    :options="showList"
    :field-names="fieldNames"
    :value-key="valueKey"
    @change="handleChange"
  >
  </a-select>
</template>

<script lang="ts" setup>
  import { watch, ref, PropType, computed } from 'vue';

  type sizeType = 'mini' | 'small' | 'medium' | 'large' | undefined;

  interface optionItem {
    [key: string]: any;
  }

  const props = defineProps({
    placeholder: {
      type: String,
      default: () => '请选择',
    },
    dataList: {
      type: Array as PropType<optionItem[]>,
      default: () => [],
    },
    modelValue: {
      type: [String, Number, Array, Object],
      default: () => null,
    },
    // id的键值
    valueKey: {
      type: [String],
      default: () => 'id',
    },
    labelKey: {
      type: [String, Number],
      default: () => 'label',
    },
    maxTagCount: {
      type: Number,
      default: 0,
    },
    getLabel: {
      type: Function,
      default: null,
    },
    allowClear: {
      type: [Boolean],
      default: () => true,
    },
    multiple: {
      type: [Boolean],
      default: () => false,
    },
    needCheckItems: {
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
    // 虚拟滚动列表
    virtualListProps: {
      type: Object,
      default: null,
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);

  const virtualList: any = computed(() => {
    if (props.virtualListProps) {
      return props.virtualListProps;
    }
    if (props.dataList?.length > 20) {
      return {
        height: 360,
        threshold: 100,
        fixedSize: true,
        buffer: 10,
      };
    }
    return null;
  });

  // 使用虚拟列表时不生效
  const formatLabel = (item: any) => {
    if (props.getLabel) {
      return props.getLabel(item);
    }
    return item[props.labelKey];
  };

  const showList = computed(() =>
    props.dataList.map((item: any) => ({
      ...item,
      [props.labelKey]: formatLabel(item),
      disabled: props.disabledValues?.includes(item[props.valueKey]),
    }))
  );
  const fieldNames: any = computed(() => ({
    value: props.valueKey,
    label: props.labelKey,
    disabled: 'disabled',
    tagProps: 'tagProps',
    render: 'render',
  }));

  const curVal = ref<any>('');
  const theMultiple = ref<any>('');
  watch(
    () => props.modelValue,
    (newVal) => {
      // 根据传值类型判断是否需要多选，如是数组则为多选，否则为单选
      theMultiple.value = !!Array.isArray(newVal);
      if (!newVal && props.zeroEmpty) {
        curVal.value = null;
      } else {
        curVal.value = newVal;
      }
    },
    {
      immediate: true,
    }
  );

  const handleChange = (val: any) => {
    emit('update:modelValue', val || null);
    if ((props.multiple || theMultiple.value) && props.needCheckItems) {
      emit(
        'change',
        val || null,
        props.dataList?.filter((item: any) =>
          val?.includes(item[props.valueKey])
        )
      );
    } else {
      emit(
        'change',
        val || null,
        props.dataList.find((item: any) => item[props.valueKey] === val)
      );
    }
  };
</script>

<style lang="less"></style>
