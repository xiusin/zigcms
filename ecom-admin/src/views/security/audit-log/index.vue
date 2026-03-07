<template>
  <div class="audit-log-page">
    <a-page-header title="审计日志" subtitle="查看系统操作记录" />
    
    <!-- 搜索表单 -->
    <a-card :bordered="false" class="search-card">
      <a-form :model="searchForm" layout="inline">
        <a-form-item label="用户">
          <a-input
            v-model="searchForm.username"
            placeholder="请输入用户名"
            style="width: 200px"
            allow-clear
          />
        </a-form-item>
        
        <a-form-item label="操作类型">
          <a-select
            v-model="searchForm.action"
            placeholder="请选择操作类型"
            style="width: 200px"
            allow-clear
          >
            <a-option value="创建测试用例">创建测试用例</a-option>
            <a-option value="更新测试用例">更新测试用例</a-option>
            <a-option value="删除测试用例">删除测试用例</a-option>
            <a-option value="创建项目">创建项目</a-option>
            <a-option value="更新项目">更新项目</a-option>
            <a-option value="删除项目">删除项目</a-option>
            <a-option value="导出数据">导出数据</a-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="资源类型">
          <a-select
            v-model="searchForm.resource_type"
            placeholder="请选择资源类型"
            style="width: 200px"
            allow-clear
          >
            <a-option value="test_case">测试用例</a-option>
            <a-option value="project">项目</a-option>
            <a-option value="module">模块</a-option>
            <a-option value="requirement">需求</a-option>
            <a-option value="feedback">反馈</a-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="状态">
          <a-select
            v-model="searchForm.status"
            placeholder="请选择状态"
            style="width: 150px"
            allow-clear
          >
            <a-option value="success">成功</a-option>
            <a-option value="failure">失败</a-option>
          </a-select>
        </a-form-item>
        
        <a-form-item label="时间范围">
          <a-range-picker
            v-model="searchForm.dateRange"
            style="width: 300px"
            show-time
          />
        </a-form-item>
        
        <a-form-item>
          <a-space>
            <a-button type="primary" @click="handleSearch">
              <template #icon><icon-search /></template>
              搜索
            </a-button>
            <a-button @click="handleReset">
              <template #icon><icon-refresh /></template>
              重置
            </a-button>
            <a-button @click="handleExport">
              <template #icon><icon-download /></template>
              导出
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-card>
    
    <!-- 审计日志表格 -->
    <a-card :bordered="false" class="table-card">
      <a-table
        :data="logs"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #columns>
          <a-table-column title="时间" data-index="created_at" :width="180">
            <template #cell="{ record }">
              {{ formatTime(record.created_at) }}
            </template>
          </a-table-column>
          
          <a-table-column title="用户" data-index="username" :width="120" />
          
          <a-table-column title="操作" data-index="action" :width="150">
            <template #cell="{ record }">
              <a-tag :color="getActionColor(record.action)">
                {{ record.action }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="资源类型" data-index="resource_type" :width="120">
            <template #cell="{ record }">
              {{ getResourceTypeName(record.resource_type) }}
            </template>
          </a-table-column>
          
          <a-table-column title="资源名称" data-index="resource_name" :width="200" />
          
          <a-table-column title="描述" data-index="description" />
          
          <a-table-column title="IP地址" data-index="client_ip" :width="150" />
          
          <a-table-column title="状态" data-index="status" :width="100">
            <template #cell="{ record }">
              <a-tag :color="record.status === 'success' ? 'green' : 'red'">
                {{ record.status === 'success' ? '成功' : '失败' }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="操作" :width="120" fixed="right">
            <template #cell="{ record }">
              <a-button type="text" size="small" @click="viewDetails(record)">
                详情
              </a-button>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
    
    <!-- 详情抽屉 -->
    <a-drawer
      v-model:visible="detailsVisible"
      title="审计日志详情"
      :width="700"
      :footer="false"
    >
      <a-descriptions v-if="selectedLog" :column="1" bordered>
        <a-descriptions-item label="日志ID">
          {{ selectedLog.id }}
        </a-descriptions-item>
        <a-descriptions-item label="用户ID">
          {{ selectedLog.user_id }}
        </a-descriptions-item>
        <a-descriptions-item label="用户名">
          {{ selectedLog.username }}
        </a-descriptions-item>
        <a-descriptions-item label="操作">
          <a-tag :color="getActionColor(selectedLog.action)">
            {{ selectedLog.action }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="资源类型">
          {{ getResourceTypeName(selectedLog.resource_type) }}
        </a-descriptions-item>
        <a-descriptions-item label="资源ID">
          {{ selectedLog.resource_id }}
        </a-descriptions-item>
        <a-descriptions-item label="资源名称">
          {{ selectedLog.resource_name }}
        </a-descriptions-item>
        <a-descriptions-item label="描述">
          {{ selectedLog.description }}
        </a-descriptions-item>
        <a-descriptions-item label="IP地址">
          {{ selectedLog.client_ip }}
        </a-descriptions-item>
        <a-descriptions-item label="User-Agent">
          {{ selectedLog.user_agent }}
        </a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="selectedLog.status === 'success' ? 'green' : 'red'">
            {{ selectedLog.status === 'success' ? '成功' : '失败' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item v-if="selectedLog.error_message" label="错误信息">
          <a-alert type="error" :message="selectedLog.error_message" />
        </a-descriptions-item>
        <a-descriptions-item v-if="selectedLog.data_before" label="操作前数据">
          <pre class="json-pre">{{ formatJSON(selectedLog.data_before) }}</pre>
        </a-descriptions-item>
        <a-descriptions-item v-if="selectedLog.data_after" label="操作后数据">
          <pre class="json-pre">{{ formatJSON(selectedLog.data_after) }}</pre>
        </a-descriptions-item>
        <a-descriptions-item label="时间">
          {{ formatTime(selectedLog.created_at) }}
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconSearch,
  IconRefresh,
  IconDownload
} from '@arco-design/web-vue/es/icon';

// 搜索表单
const searchForm = reactive({
  username: '',
  action: '',
  resource_type: '',
  status: '',
  dateRange: []
});

// 审计日志列表
const logs = ref<any[]>([]);
const loading = ref(false);
const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
  showTotal: true,
  showPageSize: true
});

// 详情
const detailsVisible = ref(false);
const selectedLog = ref<any>(null);

onMounted(() => {
  loadLogs();
});

// 加载审计日志
async function loadLogs() {
  loading.value = true;
  
  try {
    // TODO: 调用API
    // const response = await auditLogApi.list({
    //   ...searchForm,
    //   page: pagination.current,
    //   page_size: pagination.pageSize
    // });
    // logs.value = response.data.items;
    // pagination.total = response.data.total;
    
    // 模拟数据
    logs.value = [];
    pagination.total = 0;
  } catch (error) {
    Message.error('加载审计日志失败');
  } finally {
    loading.value = false;
  }
}

// 搜索
function handleSearch() {
  pagination.current = 1;
  loadLogs();
}

// 重置
function handleReset() {
  Object.assign(searchForm, {
    username: '',
    action: '',
    resource_type: '',
    status: '',
    dateRange: []
  });
  pagination.current = 1;
  loadLogs();
}

// 导出
async function handleExport() {
  try {
    // TODO: 调用导出API
    Message.success('导出成功');
  } catch (error) {
    Message.error('导出失败');
  }
}

// 分页变化
function handlePageChange(page: number) {
  pagination.current = page;
  loadLogs();
}

function handlePageSizeChange(pageSize: number) {
  pagination.pageSize = pageSize;
  pagination.current = 1;
  loadLogs();
}

// 查看详情
function viewDetails(record: any) {
  selectedLog.value = record;
  detailsVisible.value = true;
}

// 格式化时间
function formatTime(time: string) {
  return new Date(time).toLocaleString('zh-CN');
}

// 格式化 JSON
function formatJSON(json: string) {
  try {
    return JSON.stringify(JSON.parse(json), null, 2);
  } catch {
    return json;
  }
}

// 获取操作颜色
function getActionColor(action: string) {
  if (action.includes('创建')) return 'green';
  if (action.includes('更新')) return 'blue';
  if (action.includes('删除')) return 'red';
  if (action.includes('导出')) return 'orange';
  return 'gray';
}

// 获取资源类型名称
function getResourceTypeName(type: string) {
  const names: Record<string, string> = {
    test_case: '测试用例',
    project: '项目',
    module: '模块',
    requirement: '需求',
    feedback: '反馈'
  };
  return names[type] || type;
}
</script>

<style scoped lang="less">
.audit-log-page {
  padding: 20px;
  
  .search-card {
    margin-bottom: 16px;
  }
  
  .json-pre {
    background: var(--color-fill-2);
    padding: 12px;
    border-radius: 4px;
    font-size: 12px;
    max-height: 400px;
    overflow: auto;
  }
}
</style>
