<template>
  <!--通用组件：部门列表-->
  <a-tree-select
    :model-value="modelValue"
    :dropdown-style="{ maxHeight: '300px', overflow: 'auto' }"
    :max-tag-count="maxTagCount"
    :multiple="multiple"
    :field-names="{
      children: 'child',
      title: 'department_name',
      key: 'id',
      value: 'id',
    }"
    :tree-checkable="treeCheckable"
    :data="listData"
    allow-clear
    placeholder="请选择"
    show-search
    style="width: 100%"
    tree-default-expand-all
    tree-node-filter-prop="title"
    @change="handleChange"
  >
  </a-tree-select>
</template>

<script lang="ts" setup>
  import { onBeforeMount, ref } from 'vue';
  import request from '@/api/request';

  const props = defineProps({
    disabled: {
      default: false,
      type: Boolean,
    },
    modelValue: {
      type: [String, Number, Array],
      default: undefined,
    },
    multiple: {
      default: false,
      type: Boolean,
    },
    treeCheckable: {
      default: false,
      type: Boolean,
    },
    maxTagCount: {
      default: -1,
      type: Number,
    },
    selectFirst: {
      value: false,
      type: Boolean,
    },
  });

  const listData = ref<any>([]);
  const loading = ref(false);

  const emits = defineEmits(['update:modelValue']);

  const getDatalist = async () => {
    loading.value = true;
    let resData = await request('/api/department/list');
    loading.value = false;
    listData.value = resData.data;
    if (props.selectFirst && listData.value.length) {
      emits('update:modelValue', listData.value[0].id);
    }
  };
  const handleChange = (val: any) => {
    emits('update:modelValue', val);
  };

  onBeforeMount(() => {
    getDatalist();
  });
</script>
