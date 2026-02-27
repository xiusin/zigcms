<template>
  <d-modal
    v-model:visible="visible"
    :title="title"
    width="900px"
    unmount-on-close
  >
    <base-table :columns-config="columnsConfig" :data-config="dataList">
    </base-table>
  </d-modal>
</template>

<script lang="ts" setup>
  import DModal from '@/components/d-modal/d-modal.vue';
  import BaseTable from '@/components/table/base-table.vue';
  import { computed, ref } from 'vue';

  const props = defineProps({
    title: {
      type: String,
      default: '',
    },
    columnsConfig: {
      type: Array,
      default: () => [],
    },
    list: {
      type: Array,
      default: null,
    },
  });

  const visible = ref(false);
  const listSource = ref(null);

  const dataList = computed(() => props.list || listSource.value || []);
  const show = (data: any) => {
    visible.value = true;
    listSource.value = data;
  };

  defineExpose({
    show,
  });
</script>

<style scoped></style>
