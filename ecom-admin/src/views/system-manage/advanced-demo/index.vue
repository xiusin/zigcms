<template>
  <div class="advanced-demo-container">
    <a-tabs default-active-key="1">
      <!-- 基础功能 -->
      <a-tab-pane key="1" title="基础功能">
        <AmisCrud :config="basicConfig" />
      </a-tab-pane>

      <!-- 行内编辑 + 列配置 -->
      <a-tab-pane key="2" title="行内编辑">
        <AmisCrud :config="inlineEditConfig" />
      </a-tab-pane>

      <!-- 批量操作增强 -->
      <a-tab-pane key="3" title="批量操作">
        <AmisCrud :config="bulkActionsConfig" />
      </a-tab-pane>

      <!-- 关联数据 -->
      <a-tab-pane key="4" title="关联数据">
        <AmisCrud :config="relationConfig" />
      </a-tab-pane>

      <!-- 拖拽排序 -->
      <a-tab-pane key="5" title="拖拽排序">
        <AmisCrud :config="draggableConfig" />
      </a-tab-pane>

      <!-- 数据可视化 -->
      <a-tab-pane key="6" title="数据可视化">
        <AmisCrud :config="visualizationConfig" />
      </a-tab-pane>

      <!-- 树形数据 -->
      <a-tab-pane key="7" title="树形数据">
        <AmisCrud :config="treeConfig" />
      </a-tab-pane>

      <!-- 权限控制 -->
      <a-tab-pane key="8" title="权限控制">
        <AmisCrud :config="permissionConfig" />
      </a-tab-pane>
    </a-tabs>
  </div>
</template>

<script setup lang="ts">
  import AmisCrud from '@/components/amis-crud/index.vue';
  import type { CrudConfig } from '@/utils/amis-crud-generator';

  // 1. 基础功能
  const basicConfig: CrudConfig = {
    title: '用户',
    api: '/api/mock/users',
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      {
        name: 'username',
        label: '用户名',
        type: 'text',
        required: true,
        searchable: true,
      },
      { name: 'email', label: '邮箱', type: 'email', required: true },
      { name: 'status', label: '状态', type: 'switch', quickEdit: true },
    ],
  };

  // 2. 行内编辑 + 列配置 + 导入导出
  const inlineEditConfig: CrudConfig = {
    title: '商品',
    api: '/api/mock/products',
    editMode: 'drawer',
    columnSettings: true,
    export: {
      enabled: true,
      formats: ['excel', 'csv'],
    },
    import: {
      enabled: true,
      template: '/api/template/products.xlsx',
    },
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      {
        name: 'name',
        label: '商品名称',
        type: 'text',
        required: true,
        searchable: true,
        editable: true, // 行内编辑
      },
      {
        name: 'price',
        label: '价格',
        type: 'number',
        required: true,
        editable: true, // 行内编辑
      },
      {
        name: 'category',
        label: '分类',
        type: 'select',
        dict: 'product_category',
        searchable: true,
        editable: true, // 行内编辑（字典）
      },
      { name: 'status', label: '上架', type: 'switch', quickEdit: true },
    ],
  };

  // 3. 批量操作增强
  const bulkActionsConfig: CrudConfig = {
    title: '订单',
    api: '/api/mock/orders',
    fields: [
      { name: 'order_no', label: '订单号', type: 'text', searchable: true },
      { name: 'user_name', label: '用户', type: 'text', searchable: true },
      { name: 'amount', label: '金额', type: 'number' },
      {
        name: 'status',
        label: '状态',
        type: 'select',
        dict: 'order_status',
        searchable: true,
      },
    ],
    enableAdd: false,
    enableEdit: false,
    bulkActions: [
      {
        label: '批量删除',
        action: 'delete',
        confirm: true,
        api: 'delete:/api/mock/orders/batch',
      },
      {
        label: '批量导出',
        action: 'export',
        api: 'post:/api/mock/orders/export',
      },
      {
        label: '批量修改状态',
        action: 'updateStatus',
        form: [
          {
            name: 'status',
            label: '状态',
            type: 'select',
            dict: 'order_status',
            required: true,
          },
        ],
      },
      {
        label: '批量分配',
        action: 'assign',
        form: [
          {
            name: 'user_id',
            label: '分配给',
            type: 'select',
            dict: 'users',
            required: true,
          },
        ],
      },
    ],
  };

  // 4. 关联数据（远程搜索）
  const relationConfig: CrudConfig = {
    title: '文章',
    api: '/api/mock/articles',
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      {
        name: 'title',
        label: '标题',
        type: 'text',
        required: true,
        searchable: true,
      },
      {
        name: 'author_id',
        label: '作者',
        type: 'select',
        required: true,
        relation: {
          api: '/api/mock/users',
          labelField: 'username',
          valueField: 'id',
          searchable: true, // 支持远程搜索
        },
      },
      {
        name: 'category_id',
        label: '分类',
        type: 'select',
        required: true,
        relation: {
          api: '/api/mock/categories',
          labelField: 'name',
          valueField: 'id',
        },
      },
      { name: 'status', label: '发布', type: 'switch', quickEdit: true },
    ],
  };

  // 5. 拖拽排序
  const draggableConfig: CrudConfig = {
    title: '菜单',
    api: '/api/mock/menus',
    draggable: true, // 启用拖拽
    dragHandle: true, // 显示拖拽手柄
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      { name: 'name', label: '菜单名称', type: 'text', required: true },
      { name: 'icon', label: '图标', type: 'text' },
      { name: 'sort', label: '排序', type: 'number', editable: true },
      { name: 'status', label: '启用', type: 'switch', quickEdit: true },
    ],
  };

  // 6. 数据可视化（统计 + 图表）
  const visualizationConfig: CrudConfig = {
    title: '销售数据',
    api: '/api/mock/sales',
    statistics: [
      {
        label: '总销售额',
        field: 'total_amount',
        type: 'sum',
        format: 'money',
      },
      { label: '订单数', field: 'order_count', type: 'count' },
      {
        label: '平均客单价',
        field: 'avg_amount',
        type: 'avg',
        format: 'money',
      },
      { label: '最高单笔', field: 'max_amount', type: 'max', format: 'money' },
    ],
    charts: {
      enabled: true,
      types: ['line', 'bar', 'pie'],
      position: 'top',
    },
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      { name: 'date', label: '日期', type: 'date', searchable: true },
      { name: 'product', label: '商品', type: 'text', searchable: true },
      { name: 'amount', label: '金额', type: 'number' },
      { name: 'quantity', label: '数量', type: 'number' },
    ],
  };

  // 7. 树形数据
  const treeConfig: CrudConfig = {
    title: '部门',
    api: '/api/mock/departments',
    tree: {
      enabled: true,
      parentField: 'parent_id',
      childrenField: 'children',
      expandLevel: 2,
    },
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      { name: 'name', label: '部门名称', type: 'text', required: true },
      { name: 'manager', label: '负责人', type: 'text' },
      { name: 'employee_count', label: '人数', type: 'number' },
      { name: 'status', label: '启用', type: 'switch', quickEdit: true },
    ],
  };

  // 8. 权限控制
  const permissionConfig: CrudConfig = {
    title: '文档',
    api: '/api/mock/documents',
    permissions: {
      add: 'btn:add',
      edit: 'btn:edit',
      delete: 'btn:delete',
      export: 'btn:export',
      import: 'btn:import',
    },
    fields: [
      { name: 'id', label: 'ID', type: 'number', hideInForm: true },
      {
        name: 'title',
        label: '标题',
        type: 'text',
        required: true,
        searchable: true,
      },
      { name: 'author', label: '作者', type: 'text' },
      {
        name: 'created_at',
        label: '创建时间',
        type: 'datetime',
        hideInForm: true,
      },
      { name: 'status', label: '状态', type: 'switch', quickEdit: true },
    ],
  };
</script>

<style scoped>
  .advanced-demo-container {
    padding: 20px;
    background: var(--color-bg-1);
    min-height: calc(100vh - 60px);
  }

  :deep(.arco-tabs-content) {
    padding-top: 20px;
  }
</style>
