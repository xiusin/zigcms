<template>
  <a-radio-group
    v-model="curVal"
    size="large"
    :disabled="disabled"
    @change="handleChange"
  >
    <a-radio
      v-for="item in showList"
      :key="item[valueKey]"
      :value="item[valueKey]"
      :disabled="
        disabledValues.includes(item[valueKey]) ||
        Boolean(
          enabledValues?.length && !enabledValues.includes(item[valueKey])
        )
      "
    >
      {{ getLabel ? getLabel(item) : getItemLabel(item) }}
      <div v-if="item.tips" style="white-space: nowrap">{{ item.tips }}</div>
    </a-radio>
  </a-radio-group>
</template>

<script lang="ts" setup>
  import { computed, ref, watch } from 'vue';
  import DictConfig from '@/utils/dictionary-config';

  const props = defineProps({
    modelValue: {
      type: [String, Number],
      default: () => '',
    },
    valueKey: {
      type: [String, Number],
      default: () => 'id',
    },
    labelKey: {
      type: [String, Number],
      default: () => 'name',
    },
    labelsKey: {
      type: [String, Number],
      default: () => 'labels',
    },
    dataList: {
      type: Array,
      default: () => [],
    },
    // 取字典的值 key
    selectType: {
      type: String,
      default: () => {
        return 'businessType';
      },
    },
    typeKey: {
      type: String,
      default: '',
    },
    // 需要禁用的值
    disabledValues: {
      type: Array,
      default: () => [],
    },
    // 需要启用的值
    enabledValues: {
      type: Array,
      default: () => [],
    },
    // 列表范围
    dataScope: {
      type: Array,
      default: null,
    },
    getLabel: {
      type: Function,
      default: null,
    },
    disabled: {
      type: Boolean,
      default: () => false,
    },
    type: {
      type: String,
      default: 'button',
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);
  const curVal = ref<string | number>('');

  // const showList: any = computed(() =>
  //   props.dataScope?.length
  //     ? props.dataList?.filter((item: any) =>
  //         props.dataScope?.includes(item[props.valueKey])
  //       )
  //     : props.dataList || []
  // );
  const getItemLabel = (item: any) => {
    if (props.typeKey && item[props.labelsKey]?.[props.typeKey]) {
      return item[props.labelsKey][props.typeKey];
    }
    return item[props.labelKey];
  };

  watch(
    () => props.modelValue,
    (newVal) => {
      curVal.value = newVal;
    },
    {
      immediate: true,
    }
  );
  const showList = computed(() => {
    if (props.dataList.length > 0) {
      return props.dataList;
    }
    return DictConfig[props.selectType];
  });
  const handleChange = (val: any) => {
    emit('update:modelValue', val);
    emit('change', val);
  };
</script>

<style scoped></style>
