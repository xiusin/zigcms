<template>
  <a-modal v-if="isMounted" v-bind="$attrs">
    <template v-for="(slotItem, slotKey) in $slots" :key="slotKey" #[slotKey]>
      <slot :name="slotKey"></slot>
    </template>
  </a-modal>
</template>

<script setup lang="ts">
  import { ref, useAttrs, useSlots, watch } from 'vue';

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
  :deep(.arco-modal-header) {
    padding: 16px 20px;
  }
  :deep(.arco-modal-title) {
    text-align: left;
  }
  :deep(.arco-modal-body) {
    font-size: 12px;
  }
</style>
