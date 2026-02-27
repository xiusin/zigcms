<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>日志管理</span>
          <a-tag color="blue">{{ tableTotal }} 条日志</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </template>

      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入操作人搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="exportLogs">
              <template #icon>
                <icon-download />
              </template>
              导出日志
            </a-button>
            <a-button size="small" status="danger" @click="clearLogs">
              <template #icon>
                <icon-delete />
              </template>
              清空日志
            </a-button>
            <a-button size="small" @click="handleStatistics">
              <template #icon>
                <icon-bar-chart />
              </template>
              日志统计
            </a-button>
            <a-button size="small" @click="handleArchive">
              <template #icon>
                <icon-folder />
              </template>
              日志归档
            </a-button>
          </a-space>
        </template>
      </SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #log_type="{ record }">
          <a-tag :color="getTypeColor(record.log_type)">
            {{ getTypeText(record.log_type) }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="record.status === 1 ? 'green' : 'red'">
            {{ record.status === 1 ? '成功' : '失败' }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="viewDetail(record)">
              <template #icon><icon-eye /></template>
              详情
            </a-button>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 日志详情弹窗 -->
    <a-drawer
      v-model:visible="detailVisible"
      title="日志详情"
      :width="600"
      :unmount-on-close="true"
    >
      <a-descriptions v-if="currentLog" :column="1" bordered>
        <a-descriptions-item label="日志ID">
          {{ currentLog.id }}
        </a-descriptions-item>
        <a-descriptions-item label="操作人">
          {{ currentLog.username }}
        </a-descriptions-item>
        <a-descriptions-item label="操作模块">
          {{ currentLog.module }}
        </a-descriptions-item>
        <a-descriptions-item label="操作类型">
          {{ currentLog.log_type }}
        </a-descriptions-item>
        <a-descriptions-item label="操作描述">
          {{ currentLog.description }}
        </a-descriptions-item>
        <a-descriptions-item label="请求方法">
          {{ currentLog.method }}
        </a-descriptions-item>
        <a-descriptions-item label="请求URL">
          {{ currentLog.url }}
        </a-descriptions-item>
        <a-descriptions-item label="请求参数">
          <div class="json-content">{{ currentLog.params }}</div>
        </a-descriptions-item>
        <a-descriptions-item label="响应结果">
          <div class="json-content">{{ currentLog.response }}</div>
        </a-descriptions-item>
        <a-descriptions-item label="IP地址">
          {{ currentLog.ip }}
        </a-descriptions-item>
        <a-descriptions-item label="操作地点">
          {{ currentLog.location }}
        </a-descriptions-item>
        <a-descriptions-item label="浏览器">
          {{ currentLog.user_agent }}
        </a-descriptions-item>
        <a-descriptions-item label="执行时间">
          {{ currentLog.execution_time }}ms
        </a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="currentLog.status === 1 ? 'green' : 'red'">
            {{ currentLog.status === 1 ? '成功' : '失败' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="操作时间">
          {{ currentLog.created_at }}
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed } from 'vue';
  import request from '@/api/request';
  import { Message, Modal } from '@arco-design/web-vue';

  const tableRef = ref();
  const loading = ref(false);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };

  const detailVisible = ref(false);
  const statsVisible = ref(false);
  const currentLog = ref<any>({});
  const logStats = ref<any>({});

  const generateFormModel = () => ({
    username: null,
    module: '',
    log_type: '',
    status: '',
    date: [],
  });

  const formModel = ref(generateFormModel());

  const baseSearchRules = ref([
    { field: 'username', label: '操作人', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'module',
      label: '模块',
      value: null,
      component_name: 'base-select',
      attr: {
        placeholder: '请选择模块',
        options: [
          { label: '用户管理', value: 'user' },
          { label: '订单管理', value: 'order' },
          { label: '系统设置', value: 'system' },
          { label: '商品管理', value: 'product' },
        ],
      },
    },
    {
      field: 'log_type',
      label: '操作类型',
      value: null,
      component_name: 'base-select',
      attr: {
        placeholder: '请选择操作类型',
        options: [
          { label: '登录', value: 'login' },
          { label: '新增', value: 'create' },
          { label: '编辑', value: 'update' },
          { label: '删除', value: 'delete' },
          { label: '查询', value: 'query' },
          { label: '导出', value: 'export' },
          { label: '导入', value: 'import' },
        ],
      },
    },
    {
      field: 'status',
      label: '状态',
      value: null,
      component_name: 'base-select',
      attr: {
        placeholder: '请选择状态',
        options: [
          { label: '成功', value: 1 },
          { label: '失败', value: 0 },
        ],
      },
    },
    {
      field: 'date',
      label: '时间',
      value: null,
      component_name: 'base-date-picker',
      attr: {
        type: 'daterange',
        placeholder: ['开始时间', '结束时间'],
      },
    },
  ]);

  const columns = [
    { title: '日志ID', dataIndex: 'id', width: 80 },
    { title: '操作人', dataIndex: 'username', width: 120 },
    { title: '操作模块', dataIndex: 'module', width: 120 },
    {
      title: '操作类型',
      dataIndex: 'log_type',
      width: 100,
      slotName: 'log_type',
    },
    { title: '操作描述', dataIndex: 'description', ellipsis: true },
    { title: '请求方法', dataIndex: 'method', width: 80 },
    { title: 'IP地址', dataIndex: 'ip', width: 140 },
    { title: '操作地点', dataIndex: 'location', width: 140 },
    { title: '执行时间', dataIndex: 'execution_time', width: 100 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', dataIndex: 'action', width: 100, slotName: 'action' },
  ];

  const getDataList = (data: any) => {
    return request('/api/security/log/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getTypeColor = (type: string) => {
    const colors: any = {
      login: 'blue',
      create: 'green',
      update: 'orange',
      delete: 'red',
      query: 'default',
      export: 'purple',
      import: 'cyan',
    };
    return colors[type] || 'default';
  };

  const getTypeText = (type: string) => {
    const texts: any = {
      login: '登录',
      create: '新增',
      update: '编辑',
      delete: '删除',
      query: '查询',
      export: '导出',
      import: '导入',
    };
    return texts[type] || type;
  };

  const viewDetail = (record: any) => {
    currentLog.value = record;
    detailVisible.value = true;
  };

  const exportLogs = () => {
    Message.success('正在导出日志...');
    request('/api/security/log/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `系统日志_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  const clearLogs = () => {
    Modal.confirm({
      title: '清空日志',
      content: '确定要清空所有日志吗？此操作不可恢复！',
      onOk: () => {
        request('/api/security/log/clear', {})
          .then(() => {
            Message.success('日志已清空');
            tableRef.value?.search();
          })
          .catch(() => {
            Message.error('清空失败');
          });
      },
    });
  };

  // 日志统计
  const handleStatistics = () => {
    statsVisible.value = true;
    // 模拟统计数据
    logStats.value = {
      total: 15680,
      today: 256,
      errorCount: 12,
      warningCount: 45,
      topUsers: [
        { name: 'admin', count: 5200 },
        { name: 'operator', count: 3100 },
        { name: 'viewer', count: 1200 },
      ],
    };
  };

  // 日志归档
  const handleArchive = () => {
    Modal.confirm({
      title: '日志归档',
      content: '确定要将30天前的日志归档吗？',
      onOk: () => {
        request('/api/security/log/archive', {})
          .then(() => {
            Message.success('日志归档成功');
          })
          .catch(() => {
            Message.error('归档失败');
          });
      },
    });
  };
</script>

<style lang="less" scoped>
  .json-content {
    max-height: 200px;
    overflow: auto;
    white-space: pre-wrap;
    word-break: break-all;
    background: var(--color-secondary);
    padding: 8px;
    border-radius: 4px;
  }
</style>
