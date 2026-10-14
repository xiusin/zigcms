<template>
  <a-cascader
    :options="citys"
    placeholder="请选择"
    :field-names="{ label: 'label', value: 'label', children: 'children' }"
    :model-value="selectData"
    path-mode
    @change="onChange"
  />
</template>

<script lang="ts" setup>
  import citys from '@/assets/city.json';
  import { computed } from 'vue';

  const props = defineProps({
    modelValue: {
      type: Object,
      default: () => ({}),
    },
  });

  const emits = defineEmits(['update:modelValue']);
  const selectData = computed(() => {
    if (props.modelValue?.area) {
      return [
        props.modelValue.province,
        props.modelValue.city,
        props.modelValue.area,
      ];
    }
    return [];
  });
  function onChange(value: any) {
    emits('update:modelValue', {
      ...props.modelValue,
      province: value[0] || '',
      city: value[1] || '',
      area: value[2] || '',
    });
  }
</script>
