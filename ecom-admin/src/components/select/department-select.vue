<template>
  <!--通用组件：部门树选择器-->
  <a-tree-select
    :model-value="modelValue"
    :dropdown-style="{ maxHeight: '300px', overflow: 'auto' }"
    :max-tag-count="maxTagCount"
    :multiple="multiple"
    :field-names="{
      children: 'children',
      title: 'title',
      key: 'key',
      value: 'value',
    }"
    :tree-checkable="treeCheckable"
    :data="treeData"
    :loading="loading"
    :disabled="disabled"
    allow-clear
    :placeholder="placeholder"
    show-search
    style="width: 100%"
    tree-default-expand-all
    tree-node-filter-prop="title"
    @change="handleChange"
  >
  </a-tree-select>
</template>

<script lang="ts" setup>
  import { onBeforeMount, ref, watch } from 'vue';
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
      default: false,
      type: Boolean,
    },
    placeholder: {
      default: '请选择部门',
      type: String,
    },
  });

  const treeData = ref<any[]>([]);
  const loading = ref(false);

  const emits = defineEmits(['update:modelValue']);

  /** 构建树形结构 */
  const buildTree = (list: any[]): any[] => {
    if (!Array.isArray(list)) return [];
    const map = new Map<number, any>();
    list.forEach((item) => {
      const id = Number(item.id);
      map.set(id, {
        ...item,
        key: id,
        value: id,
        title: item.dept_name || item.title || '',
        children: [],
      });
    });
    const roots: any[] = [];
    list.forEach((item) => {
      const id = Number(item.id);
      const parentId = Number(item.parent_id || 0);
      const node = map.get(id);
      if (!node) return;
      if (parentId > 0 && map.has(parentId)) {
        map.get(parentId)!.children.push(node);
      } else {
        roots.push(node);
      }
    });
    return roots;
  };

  const getDatalist = async () => {
    loading.value = true;
    try {
      const resData = await request('/api/system/dept/tree');
      const raw = resData?.data;
      const list = Array.isArray(raw)
        ? raw
        : Array.isArray(raw?.list)
          ? raw.list
          : Array.isArray(raw?.items)
            ? raw.items
            : [];
      treeData.value = buildTree(list);
      if (props.selectFirst && treeData.value.length && !props.modelValue) {
        emits('update:modelValue', treeData.value[0].value);
      }
    } catch (e) {
      console.error('[DepartmentSelect] 获取部门树失败', e);
      treeData.value = [];
    } finally {
      loading.value = false;
    }
  };

  const handleChange = (val: any) => {
    emits('update:modelValue', val);
  };

  onBeforeMount(() => {
    getDatalist();
  });

  // 暴露刷新方法供外部调用
  defineExpose({ refresh: getDatalist });
</script>
