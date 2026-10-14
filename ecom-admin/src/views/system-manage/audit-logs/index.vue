<template>
  <div class="container">
    <a-card title="操作审计">
      <template #extra>
        <a-space>
          <a-range-picker
            v-model="dateRange"
            size="small"
            @change="handleSearch"
          />
          <a-select
            v-model="filterType"
            placeholder="操作类型"
            size="small"
            style="width: 120px"
            @change="handleSearch"
          >
            <a-option value="">全部</a-option>
            <a-option value="create">新增</a-option>
            <a-option value="update">修改</a-option>
            <a-option value="delete">删除</a-option>
            <a-option value="permission">权限变更</a-option>
          </a-select>
          <a-button size="small" @click="exportLogs">
            <template #icon><icon-export /></template>
            导出日志
          </a-button>
        </a-space>
      </template>

      <a-table
        :columns="columns"
        :data="logs"
        :pagination="pagination"
        size="small"
      >
        <template #action="{ record }">
          <a-tag :color="getActionColor(record.action)">{{
            getActionName(record.action)
          }}</a-tag>
        </template>
        <template #status="{ record }">
          <a-tag v-if="record.status === 'success'" color="green">成功</a-tag>
          <a-tag v-else color="red">失败</a-tag>
        </template>
        <template #details="{ record }">
          <a-button size="mini" type="text" @click="viewDetails(record)"
            >查看详情</a-button
          >
        </template>
      </a-table>
    </a-card>

    <!-- 详情弹窗 -->
    <a-modal
      v-model:visible="detailsVisible"
      title="操作详情"
      width="700px"
      :footer="false"
    >
      <a-descriptions v-if="currentLog" :column="2" bordered>
        <a-descriptions-item label="操作人">{{
          currentLog.username
        }}</a-descriptions-item>
        <a-descriptions-item label="操作类型">
          {{ getActionName(currentLog.action) }}
        </a-descriptions-item>
        <a-descriptions-item label="操作模块">{{
          currentLog.module
        }}</a-descriptions-item>
        <a-descriptions-item label="IP地址">{{
          currentLog.ip
        }}</a-descriptions-item>
        <a-descriptions-item label="操作时间" :span="2">
          {{ currentLog.created_at }}
        </a-descriptions-item>
        <a-descriptions-item label="请求参数" :span="2">
          <pre style="max-height: 200px; overflow: auto">{{
            currentLog.params
          }}</pre>
        </a-descriptions-item>
        <a-descriptions-item label="响应结果" :span="2">
          <pre style="max-height: 200px; overflow: auto">{{
            currentLog.response
          }}</pre>
        </a-descriptions-item>
      </a-descriptions>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import * as XLSX from 'xlsx';

  interface AuditLog {
    id: number;
    username: string;
    action: 'create' | 'update' | 'delete' | 'permission';
    module: string;
    ip: string;
    status: 'success' | 'failed';
    params: string;
    response: string;
    created_at: string;
  }

  const dateRange = ref([]);
  const filterType = ref('');
  const detailsVisible = ref(false);
  const currentLog = ref<AuditLog | null>(null);

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '操作人', dataIndex: 'username', width: 120 },
    { title: '操作类型', dataIndex: 'action', slotName: 'action', width: 100 },
    { title: '操作模块', dataIndex: 'module', width: 150 },
    { title: 'IP地址', dataIndex: 'ip', width: 140 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
    { title: '操作时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', slotName: 'details', width: 100 },
  ];

  const logs = ref<AuditLog[]>([
    {
      id: 1,
      username: 'admin',
      action: 'permission',
      module: '角色管理',
      ip: '192.168.1.100',
      status: 'success',
      params: JSON.stringify(
        { role_id: 1, permissions: ['btn:add', 'btn:edit'] },
        null,
        2
      ),
      response: JSON.stringify({ code: 200, message: '权限更新成功' }, null, 2),
      created_at: new Date().toLocaleString(),
    },
    {
      id: 2,
      username: 'admin',
      action: 'delete',
      module: '用户管理',
      ip: '192.168.1.100',
      status: 'success',
      params: JSON.stringify({ user_id: 123 }, null, 2),
      response: JSON.stringify({ code: 200, message: '删除成功' }, null, 2),
      created_at: new Date(Date.now() - 3600000).toLocaleString(),
    },
    {
      id: 3,
      username: 'operator',
      action: 'update',
      module: '订单管理',
      ip: '192.168.1.101',
      status: 'success',
      params: JSON.stringify({ order_id: 456, status: 'completed' }, null, 2),
      response: JSON.stringify({ code: 200, message: '更新成功' }, null, 2),
      created_at: new Date(Date.now() - 7200000).toLocaleString(),
    },
  ]);

  const pagination = {
    pageSize: 20,
    showTotal: true,
  };

  const getActionColor = (action: string) => {
    const colors: Record<string, string> = {
      create: 'green',
      update: 'blue',
      delete: 'red',
      permission: 'orange',
    };
    return colors[action] || 'gray';
  };

  const getActionName = (action: string) => {
    const names: Record<string, string> = {
      create: '新增',
      update: '修改',
      delete: '删除',
      permission: '权限变更',
    };
    return names[action] || action;
  };

  const handleSearch = () => {
    Message.info('搜索功能');
  };

  const viewDetails = (record: AuditLog) => {
    currentLog.value = record;
    detailsVisible.value = true;
  };

  const exportLogs = () => {
    const exportData = logs.value.map((log) => ({
      ID: log.id,
      操作人: log.username,
      操作类型: getActionName(log.action),
      操作模块: log.module,
      IP地址: log.ip,
      状态: log.status === 'success' ? '成功' : '失败',
      操作时间: log.created_at,
    }));

    const ws = XLSX.utils.json_to_sheet(exportData);
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, ws, '操作日志');
    XLSX.writeFile(wb, `audit_logs_${Date.now()}.xlsx`);

    Message.success('导出成功');
  };
</script>

<style scoped lang="less">
  .container {
    padding: 20px;
  }

  pre {
    background: var(--color-fill-2);
    padding: 12px;
    border-radius: 4px;
    font-size: 11px;
    margin: 0;
  }
</style>
