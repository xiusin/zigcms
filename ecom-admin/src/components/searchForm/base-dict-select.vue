<template>
  <CommonSelect
    v-model="curVal"
    :data-list="showList"
    :value-key="valueKey"
    :label-key="labelKey"
    :placeholder="placeholder"
    :multiple="multiple"
    :loading="loading"
    :disabled-values="disabledValues"
    :zero-empty="zeroEmpty"
    @change="handleChange"
  ></CommonSelect>
</template>

<script lang="ts" setup>
  import { computed, ref, watch, onMounted } from 'vue';
  import DictConfig from '@/utils/dictionary-config';
  import useLoading from '@/hooks/loading';
  import CommonSelect from './base-select.vue';

  const props = defineProps({
    placeholder: {
      type: String,
      default: () => '请选择',
    },
    dataList: {
      type: Array,
      default: () => [],
    },
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
    // id的键值
    valueKey: {
      type: [String],
      default: () => 'id',
    },
    labelKey: {
      type: [String, Number],
      default: () => 'name',
    },
    multiple: {
      type: Boolean,
      default: () => false,
    },
    sendParams: {
      type: Object,
      default: () => {
        return {};
      },
    },
    // 取字典的值 key
    selectType: {
      type: String,
      default: () => {
        return 'businessType';
      },
    },
    // 需要禁用的值
    disabledValues: {
      type: [Array],
      default: () => [],
    },
    zeroEmpty: {
      type: Boolean,
      default: () => false,
    },
    size: {
      type: String,
      default: 'medium',
    },
  });
  const emit = defineEmits(['input', 'change', 'update:modelValue']);
  const { loading, setLoading } = useLoading(true);
  setLoading(true);

  const curVal = ref<any>('');
  watch(
    () => props.modelValue,
    (newVal) => {
      console.log('watch: ', newVal);
      curVal.value = newVal;
    },
    {
      immediate: true,
    }
  );
  const handleChange = (val: any) => {
    emit('update:modelValue', val);
    emit('change', val);
  };
  const showList = computed(() => {
    if (props.dataList.length > 0) {
      return props.dataList;
    }
    return DictConfig[props.selectType];
  });

  onMounted(() => {
    // getList();
    setLoading(false);
  });
</script>

<style lang="less"></style>
