<template>
  <router-view v-slot="{ Component, route }">
    <transition name="fade" mode="out-in" appear>
      <component
        :is="Component"
        v-if="route.meta.ignoreCache"
        :key="route.fullPath"
        class="box"
      />
      <keep-alive v-else :include="cacheList">
        <component :is="Component" :key="route.fullPath" class="box" />
      </keep-alive>
    </transition>
  </router-view>
</template>

<script lang="ts" setup>
  import { computed, ref, onMounted } from 'vue';
  import { useTabBarStore } from '@/store';

  const tabBarStore = useTabBarStore();
  const boxMainRef = ref();

  const cacheList = computed(() => tabBarStore.getCacheList);
</script>

<style scoped lang="less">
  .box {
    min-height: calc(100vh - 120px);
    margin: 0 20px 20px 20px;
  }
  :deep(.arco-card-body) {
    // padding-bottom: 6px !important;
  }
</style>
