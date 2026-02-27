<template>
  <a-date-picker
    v-model="modelVal"
    style="width: 100%"
    :day-start-of-week="5"
    :allow-clear="allowClear"
    :placeholder="placeholder"
    :disabled-date="disabledDate"
    @change="handleChange"
  />
</template>

<script lang="ts" setup>
  import { ref, watch } from 'vue';

  const emit = defineEmits(['update:modelValue', 'change']);

  const props = defineProps({
    modelValue: {
      type: [String],
      default: () => '',
    },
    placeholder: {
      type: String,
      default: '请选择日期',
    },
    allowClear: {
      type: Boolean,
      default: true,
    },
    disabledDate: {
      type: Function as unknown as () => (
        current?: Date | undefined
      ) => boolean,
      default: () => {
        return false;
      },
    },
    showNowBtn: {
      type: Boolean,
      default: true,
    },
  });
  const modelVal: any = ref('');
  watch(
    () => props.modelValue,
    (newVal) => {
      modelVal.value = newVal;
    },
    {
      immediate: true,
    }
  );
  const handleChange = (val: any) => {
    emit('update:modelValue', val);
    emit('change', val);
  };
</script>

<style lang="less" scoped></style>
