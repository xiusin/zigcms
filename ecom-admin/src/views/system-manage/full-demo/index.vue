<template>
  <div class="full-demo">
    <a-card title="🚀 CRUD 完整功能演示" :bordered="false">
      <a-alert type="info" :closable="false" style="margin-bottom: 16px">
        <template #icon><icon-trophy /></template>
        已启用 <strong>22</strong> 项高级功能
      </a-alert>

      <a-tabs default-active-key="1">
        <!-- 插件系统 -->
        <a-tab-pane key="1" title="🔌 插件系统">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-card title="插件配置" size="small">
              <a-checkbox-group
                v-model="selectedPlugins"
                @change="applyPlugins"
              >
                <a-space direction="vertical">
                  <a-checkbox value="auditLog"
                    >审计日志 - 自动记录创建人/修改人</a-checkbox
                  >
                  <a-checkbox value="softDelete"
                    >软删除 - 标记删除+恢复功能</a-checkbox
                  >
                  <a-checkbox value="mask"
                    >字段脱敏 - 手机号/邮箱脱敏</a-checkbox
                  >
                </a-space>
              </a-checkbox-group>
            </a-card>
            <AmisCrud id="plugin_crud" :config="pluginConfig" />
          </a-space>
        </a-tab-pane>

        <!-- 导入导出 -->
        <a-tab-pane key="2" title="📥📤 导入导出">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-space>
              <a-button size="small" type="primary" @click="handleExport">
                <template #icon><icon-download /></template>
                导出 Excel
              </a-button>
              <a-upload :custom-request="handleImport" :show-file-list="false">
                <a-button>
                  <template #icon><icon-upload /></template>
                  导入数据
                </a-button>
              </a-upload>
              <a-button size="small" @click="downloadTemplate">
                <template #icon><icon-file /></template>
                下载模板
              </a-button>
            </a-space>
            <AmisCrud id="import_crud" :config="importConfig" />
          </a-space>
        </a-tab-pane>

        <!-- 性能优化 -->
        <a-tab-pane key="3" title="⚡ 性能优化">
          <a-card title="性能指标" size="small" style="margin-bottom: 16px">
            <a-row :gutter="16">
              <a-col :span="6">
                <a-statistic title="虚拟滚动" value="10000" suffix="条" />
              </a-col>
              <a-col :span="6">
                <a-statistic title="请求合并" value="5" suffix="次节省" />
              </a-col>
              <a-col :span="6">
                <a-statistic title="响应时间" value="120" suffix="ms" />
              </a-col>
              <a-col :span="6">
                <a-statistic title="缓存命中" value="85" suffix="%" />
              </a-col>
            </a-row>
          </a-card>
          <AmisCrud id="performance_crud" :config="performanceConfig" />
        </a-tab-pane>

        <!-- 业务交互 -->
        <a-tab-pane key="4" title="🔗 业务交互">
          <a-row :gutter="16">
            <a-col :span="8">
              <a-card title="部门列表" size="small">
                <AmisCrud id="dept_crud" :config="deptConfig" />
              </a-card>
            </a-col>
            <a-col :span="16">
              <a-card title="部门用户" size="small">
                <AmisCrud id="user_crud" :config="userConfig" />
              </a-card>
            </a-col>
          </a-row>
        </a-tab-pane>

        <!-- 数据可视化 -->
        <a-tab-pane key="5" title="📊 数据可视化">
          <AmisCrud id="visual_crud" :config="visualConfig" />
        </a-tab-pane>

        <!-- 树形数据 -->
        <a-tab-pane key="6" title="🌲 树形数据">
          <AmisCrud id="tree_crud" :config="treeConfig" />
        </a-tab-pane>

        <!-- 权限控制 -->
        <a-tab-pane key="7" title="🔐 权限控制">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-card title="角色切换" size="small">
              <a-space>
                <a-tag color="blue">当前角色: {{ currentRole }}</a-tag>
                <a-button size="small" @click="currentRole = 'admin'"
                  >管理员</a-button
                >
                <a-button size="small" @click="currentRole = 'user'"
                  >普通用户</a-button
                >
              </a-space>
            </a-card>
            <AmisCrud id="permission_crud" :config="permissionConfig" />
          </a-space>
        </a-tab-pane>

        <!-- 完整功能 -->
        <a-tab-pane key="8" title="🎯 完整功能">
          <AmisCrud id="full_crud" :config="fullConfig" />
        </a-tab-pane>
      </a-tabs>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { ref } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import AmisCrud from '@/components/amis-crud/index.vue';
  import { crudPluginManager } from '@/utils/crud-plugins';
  import {
    exportData,
    importData,
    generateImportTemplate,
  } from '@/utils/crud-import-export';
  import { crudInstanceManager } from '@/utils/crud-event-bus';
  import type { CrudConfig } from '@/utils/amis-crud-generator';

  const selectedPlugins = ref(['auditLog', 'mask']);
  const currentRole = ref('admin');

  // 插件系统配置
  const baseConfig: CrudConfig = {
    title: '用户管理（插件演示）',
    api: '/api/member/list',
    fields: [
      { name: 'id', label: 'ID', type: 'number', width: 80 },
      {
        name: 'username',
        label: '用户名',
        type: 'text',
        required: true,
        editable: true,
      },
      { name: 'mobile', label: '手机号', type: 'phone', editable: true },
      { name: 'email', label: '邮箱', type: 'email', editable: true },
      { name: 'status', label: '状态', type: 'switch', quickEdit: true },
    ],
    enableAdd: true,
    enableEdit: true,
    enableDelete: true,
  };

  const pluginConfig = ref(
    crudPluginManager.apply(baseConfig, selectedPlugins.value)
  );

  const applyPlugins = () => {
    pluginConfig.value = crudPluginManager.apply(
      baseConfig,
      selectedPlugins.value
    );
    Message.success('插件配置已更新');
  };

  // 导入导出配置
  const importConfig: CrudConfig = {
    title: '商品管理（导入导出演示）',
    api: '/api/product/list',
    fields: [
      { name: 'name', label: '商品名称', type: 'text', required: true },
      { name: 'price', label: '价格', type: 'number', required: true },
      { name: 'stock', label: '库存', type: 'number' },
      {
        name: 'category',
        label: '分类',
        type: 'select',
        dictOptions: [
          { label: '电子产品', value: 'electronics' },
          { label: '服装', value: 'clothing' },
        ],
      },
    ],
    enableAdd: true,
  };

  const handleExport = async () => {
    await exportData('/api/product/export', {
      format: 'excel',
      filename: 'products',
    });
    Message.success('导出成功');
  };

  const handleImport = async ({ file }: any) => {
    const result = await importData(file, {
      format: 'excel',
      fields: importConfig.fields,
    });
    Message.success(`导入完成: 成功${result.success}条`);
    crudInstanceManager.refresh('import_crud');
  };

  const downloadTemplate = () => {
    generateImportTemplate(importConfig.fields, 'excel');
  };

  // 性能优化配置
  const performanceConfig: CrudConfig = {
    title: '大数据列表（性能优化演示）',
    api: '/api/sales/list',
    fields: [
      { name: 'id', label: 'ID', type: 'number', width: 80 },
      { name: 'order_no', label: '订单号', type: 'text' },
      { name: 'amount', label: '金额', type: 'number' },
      { name: 'created_at', label: '时间', type: 'datetime' },
    ],
    virtual: true,
    virtualThreshold: 100,
    pageSize: 50,
  };

  // 业务交互配置
  const deptConfig: CrudConfig = {
    title: '部门列表',
    api: '/api/department/tree',
    fields: [
      { name: 'name', label: '部门名称', type: 'text' },
      { name: 'code', label: '部门编码', type: 'text' },
    ],
    tree: { enabled: true },
    events: {
      onRowClick: () => {
        crudInstanceManager.refresh('user_crud');
      },
    },
  };

  const userConfig: CrudConfig = {
    title: '部门用户',
    api: '/api/member/list',
    fields: [
      { name: 'username', label: '用户名', type: 'text' },
      { name: 'mobile', label: '手机号', type: 'phone' },
    ],
  };

  // 数据可视化配置
  const visualConfig: CrudConfig = {
    title: '销售数据（可视化演示）',
    api: '/api/sales/list',
    fields: [
      { name: 'product_name', label: '商品', type: 'text' },
      { name: 'amount', label: '金额', type: 'number' },
    ],
    statistics: [
      { label: '总销售额', field: 'amount', type: 'sum', format: 'money' },
      { label: '订单数', field: 'id', type: 'count' },
    ],
    charts: { enabled: true, types: ['line', 'bar'] },
  };

  // 树形数据配置
  const treeConfig: CrudConfig = {
    title: '部门树（树形数据演示）',
    api: '/api/department/tree',
    fields: [
      { name: 'name', label: '部门名称', type: 'text' },
      { name: 'status', label: '状态', type: 'switch' },
    ],
    tree: { enabled: true, expandLevel: 2 },
  };

  // 权限控制配置
  const permissionConfig: CrudConfig = {
    title: '用户管理（权限控制演示）',
    api: '/api/member/list',
    fields: [
      { name: 'username', label: '用户名', type: 'text' },
      { name: 'role', label: '角色', type: 'text' },
    ],
    permissions: {
      add: 'btn:add',
      edit: 'btn:edit',
      delete: 'btn:delete',
    },
  };

  // 完整功能配置
  const fullConfig: CrudConfig = {
    title: '完整功能演示',
    api: '/api/member/list',
    fields: [
      { name: 'username', label: '用户名', type: 'text', editable: true },
      { name: 'mobile', label: '手机号', type: 'phone', editable: true },
      { name: 'status', label: '状态', type: 'switch', quickEdit: true },
    ],
    enableAdd: true,
    enableEdit: true,
    enableDelete: true,
    enableBulk: true,
    columnSettings: true,
    export: { enabled: true, formats: ['excel', 'csv'] },
    import: { enabled: true },
    virtual: true,
    draggable: true,
    responsive: true,
  };
</script>

<style scoped lang="less">
  .full-demo {
    padding: 16px;
  }
</style>
