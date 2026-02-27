<template>
  <a-drawer v-if="isMounted" v-bind="$attrs" :mask-closable="false">
    <template v-for="(slotItem, slotKey) in $slots" :key="slotKey" #[slotKey]>
      <slot :name="slotKey"></slot>
    </template>
  </a-drawer>
</template>

<script setup lang="ts">
  import { ref, useAttrs, watch } from 'vue';

  const atts = useAttrs();
  const isMounted = ref(false);
  watch(
    () => atts.visible,
    (val) => {
      if (val && !isMounted.value) {
        isMounted.value = true;
      }
    }
  );
</script>

<style scoped>
  :deep(.arco-drawer-header) {
    padding: 16px 20px;
  }
  :deep(.arco-drawer-title) {
    text-align: left;
  }
  :deep(.arco-drawer-body) {
    font-size: 12px;
  }
</style>
