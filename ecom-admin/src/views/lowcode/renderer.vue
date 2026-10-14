<template>
  <div class="lowcode-renderer">
    <AmisRenderer v-if="schema" :schema="schema" />
    <a-empty v-else description="暂无页面配置" />
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted, watch } from 'vue';
  import { useRoute } from 'vue-router';
  import { AmisRenderer } from '@/components/amis';
  import type { AmisSchema } from '@/types/amis.d';

  const route = useRoute();
  const schema = ref<AmisSchema | null>(null);

  // 加载页面配置
  const loadPageConfig = async () => {
    const pageCode =
      (route.query.code as string) || (route.params.code as string);

    if (!pageCode) {
      // 如果没有传入code，尝试从路由meta获取
      const meta = route.meta as any;
      if (meta?.schema) {
        schema.value = meta.schema;
      }
      return;
    }

    try {
      // 模拟从接口获取页面配置
      // 实际项目中应调用: request(`/api/system/page-config/${pageCode}`)

      // 模拟数据
      const mockConfigs: Record<string, AmisSchema> = {
        user_list: {
          type: 'page',
          title: '用户列表',
          body: {
            type: 'crud',
            api: '/api/member/list',
            columns: [
              { name: 'id', label: 'ID', width: 60 },
              { name: 'username', label: '用户名' },
              { name: 'nickname', label: '昵称' },
              { name: 'mobile', label: '手机号' },
              { name: 'email', label: '邮箱' },
              {
                name: 'status',
                label: '状态',
                map: { 0: '禁用', 1: '正常' },
              },
              {
                name: 'created_at',
                label: '创建时间',
                width: 180,
              },
            ],
            toolbar: [
              {
                type: 'button',
                label: '新增用户',
                icon: 'plus',
                actionType: 'dialog',
                dialog: {
                  title: '新增用户',
                  body: {
                    type: 'form',
                    mode: 'horizontal',
                    api: '/api/member/save',
                    body: [
                      {
                        type: 'input-text',
                        name: 'username',
                        label: '用户名',
                        required: true,
                      },
                      { type: 'input-text', name: 'nickname', label: '昵称' },
                      { type: 'input-text', name: 'mobile', label: '手机号' },
                      { type: 'input-text', name: 'email', label: '邮箱' },
                    ],
                  },
                },
              },
              { type: 'reload', icon: 'refresh', label: '刷新' },
              { type: 'export-excel', icon: 'download', label: '导出' },
            ],
          },
        },
        order_list: {
          type: 'page',
          title: '订单列表',
          body: {
            type: 'crud',
            api: '/api/order/list',
            columns: [
              { name: 'order_no', label: '订单号', width: 200 },
              { name: 'product_name', label: '商品名称' },
              { name: 'price', label: '单价' },
              { name: 'num', label: '数量' },
              { name: 'total_price', label: '总金额' },
              {
                name: 'status',
                label: '状态',
                map: { 1: '待付款', 2: '待发货', 3: '待收货', 4: '已完成' },
              },
              { name: 'created_at', label: '下单时间', width: 180 },
            ],
            filters: [
              {
                type: 'input-text',
                name: 'order_no',
                label: '订单号',
                placeholder: '请输入订单号',
              },
              {
                type: 'select',
                name: 'status',
                label: '订单状态',
                options: [
                  { label: '待付款', value: 1 },
                  { label: '待发货', value: 2 },
                  { label: '待收货', value: 3 },
                  { label: '已完成', value: 4 },
                ],
              },
              { type: 'date-range', name: 'created_at', label: '下单时间' },
            ],
          },
        },
      };

      schema.value = mockConfigs[pageCode] || null;
    } catch (error) {
      console.error('加载页面配置失败:', error);
    }
  };

  watch(() => route.fullPath, loadPageConfig);

  onMounted(() => {
    loadPageConfig();
  });
</script>

<style scoped>
  .lowcode-renderer {
    width: 100%;
    min-height: 500px;
  }
</style>
