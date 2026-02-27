<template>
  <div class="content-box">
    <a-card class="table-wrap" :body-style="{ padding: '10px 0 0 0' }">
      <div style="padding: 0 16px 16px">
        <a-tabs :destroy-on-hide="true" :lazy-load="true">
          <a-tab-pane :key="1">
            <template #title>商品码表</template>
            <GoodsManage></GoodsManage>
          </a-tab-pane>
          <a-tab-pane :key="2">
            <template #title>品牌</template>
            <BrandManage></BrandManage>
          </a-tab-pane>
          <a-tab-pane :key="3">
            <template #title>系列</template>
            <StyleManage></StyleManage>
          </a-tab-pane>
          <a-tab-pane :key="4">
            <template #title>规格</template>
            <SizeManage></SizeManage>
          </a-tab-pane>
          <a-tab-pane :key="5">
            <template #title>颜色</template>
            <ColorManage></ColorManage>
          </a-tab-pane>
          <a-tab-pane :key="6">
            <template #title>材质</template>
            <ElementManage></ElementManage>
          </a-tab-pane>
        </a-tabs>
      </div>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import GoodsManage from './goods-manage.vue';
  import BrandManage from './brand-manage.vue';
  import StyleManage from './style-manage.vue';
  import SizeManage from './size-manage.vue';
  import ColorManage from './color-manage.vue';
  import ElementManage from './element-manage.vue';
</script>

<style scoped lang="less">
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }
  :deep(.arco-tabs-tab-title) {
    font-size: 15px;
  }
  :deep(.arco-tabs-content) {
    padding-top: 0;
  }
</style>
