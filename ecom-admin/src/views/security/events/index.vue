<template>
  <div class="security-events-page">
    <a-card title="安全事件" :bordered="false">
      <!-- 筛选器 -->
      <div class="filter-section">
        <a-form :model="filterForm" layout="inline">
          <a-form-item label="事件类型">
            <a-select
              v-model="filterForm.type"
              placeholder="全部"
              style="width: 150px"
              allow-clear
            >
              <a-option value="rate_limit">频率限制</a-option>
              <a-option value="suspicious_activity">可疑活动</a-option>
              <a-option value="brute_force">暴力破解</a-option>
              <a-option value="sql_injection">SQL注入</a-option>
              <a-option value="xss">XSS攻击</a-option>
              <a-option value="csrf">CSRF攻击</a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="事件级别">
            <a-select
              v-model="filterForm.level"
              placeholder="全部"
              style="width: 120px"
              allow-clear
            >
              <a-option value="info">信息</a-option>
              <a-option value="warning">警告</a-option>
              <a-option value="error">错误</a-option>
              <a-option value="critical">严重</a-option>
            </a-select>
          </a-form-item>

          <a-form-item label="用户名">
            <a-input
              v-model="filterForm.username"
              placeholder="请输入用户名"
              style="width: 150px"
              allow-clear
            />
          </a-form-item>

          <a-form-item label="IP地址">
            <a-input
              v-model="filterForm.ip"
              placeholder="请输入IP"
              style="width: 150px"
              allow-clear
            />
          </a-form-item>

          <a-form-item label="时间范围">
            <a-range-picker
              v-model="filterForm.timeRange"
              style="width: 300px"
              show-time
            />
          </a-form-item>

          <a-form-item>
            <a-space>
              <a-button type="primary" @click="handleSearch">
                <template #icon><icon-search /></template>
                查询
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
      </div>

      <!-- 事件列表 -->
      <a-table
        :columns="columns"
        :data="events"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
        row-key="id"
      >
        <template #level="{ record }">
          <a-tag :color="getLevelColor(record.level)">
            {{ getLevelLabel(record.level) }}
          </a-tag>
        </template>

        <template #blocked="{ record }">
          <a-tag :color="record.blocked ? 'red' : 'green'">
            {{ record.blocked ? '已拦截' : '已放行' }}
          </a-tag>
        </template>

        <template #risk_score="{ record }">
          <a-progress
            :percent="record.risk_score || 0"
            :color="getRiskColor(record.risk_score || 0)"
            :show-text="false"
            size="small"
          />
          <span style="margin-left: 8px">{{ record.risk_score || 0 }}</span>
        </template>

        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleViewDetail(record)"
            >
              详情
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 事件详情抽屉 -->
    <a-drawer
      v-model:visible="detailVisible"
      title="事件详情"
      :width="600"
      :footer="false"
    >
      <a-descriptions
        v-if="currentEvent"
        :column="1"
        bordered
      >
        <a-descriptions-item label="事件ID">
          {{ currentEvent.id }}
        </a-descriptions-item>
        <a-descriptions-item label="事件类型">
          {{ currentEvent.type }}
        </a-descriptions-item>
        <a-descriptions-item label="事件级别">
          <a-tag :color="getLevelColor(currentEvent.level)">
            {{ getLevelLabel(currentEvent.level) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="用户">
          {{ currentEvent.username || '未知' }} (ID: {{ currentEvent.user_id || '-' }})
        </a-descriptions-item>
        <a-descriptions-item label="IP地址">
          {{ currentEvent.ip }}
        </a-descriptions-item>
        <a-descriptions-item label="User Agent">
          {{ currentEvent.user_agent }}
        </a-descriptions-item>
        <a-descriptions-item label="请求路径">
          {{ currentEvent.request_path }}
        </a-descriptions-item>
        <a-descriptions-item label="请求方法">
          <a-tag>{{ currentEvent.request_method }}</a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="响应状态">
          <a-tag :color="currentEvent.response_status >= 400 ? 'red' : 'green'">
            {{ currentEvent.response_status }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="风险评分">
          <a-progress
            :percent="currentEvent.risk_score || 0"
            :color="getRiskColor(currentEvent.risk_score || 0)"
            size="small"
          />
        </a-descriptions-item>
        <a-descriptions-item label="是否拦截">
          <a-tag :color="currentEvent.blocked ? 'red' : 'green'">
            {{ currentEvent.blocked ? '已拦截' : '已放行' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="详细信息">
          <pre style="max-height: 300px; overflow: auto">{{ currentEvent.details }}</pre>
        </a-descriptions-item>
        <a-descriptions-item label="发生时间">
          {{ currentEvent.created_at }}
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue';
import { useRouter } from 'vue-router';
import { useSecurityStore } from '@/store/modules/security';
import { EventLevelLabels } from '@/types/security.ts';
import type { SecurityEvent, SearchEventsQuery } from '@/types/security';
import {
  IconSearch,
  IconRefresh,
  IconDownload,
} from '@arco-design/web-vue/es/icon';
import { Message } from '@arco-design/web-vue';
import { exportEvents } from '@/api/security';

const router = useRouter();
const securityStore = useSecurityStore();

// 状态
const loading = ref(false);
const detailVisible = ref(false);
const currentEvent = ref<SecurityEvent | null>(null);

// 筛选表单
const filterForm = reactive({
  type: '',
  level: '',
  username: '',
  ip: '',
  timeRange: [] as string[],
});

// 分页
const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
  showTotal: true,
  showPageSize: true,
});

// 计算属性
const events = computed(() => securityStore.events);

// 表格列
const columns = [
  {
    title: 'ID',
    dataIndex: 'id',
    width: 80,
  },
  {
    title: '事件类型',
    dataIndex: 'type',
    width: 120,
  },
  {
    title: '级别',
    dataIndex: 'level',
    slotName: 'level',
    width: 80,
  },
  {
    title: '用户',
    dataIndex: 'username',
    width: 120,
  },
  {
    title: 'IP地址',
    dataIndex: 'ip',
    width: 140,
  },
  {
    title: '请求路径',
    dataIndex: 'request_path',
    ellipsis: true,
    tooltip: true,
  },
  {
    title: '风险评分',
    dataIndex: 'risk_score',
    slotName: 'risk_score',
    width: 120,
  },
  {
    title: '状态',
    dataIndex: 'blocked',
    slotName: 'blocked',
    width: 100,
  },
  {
    title: '发生时间',
    dataIndex: 'created_at',
    width: 180,
  },
  {
    title: '操作',
    slotName: 'actions',
    width: 100,
    fixed: 'right',
  },
];

// 方法
const getLevelLabel = (level: string) => {
  return EventLevelLabels[level as keyof typeof EventLevelLabels] || level;
};

const getLevelColor = (level: string) => {
  const colors: Record<string, string> = {
    info: '#1890ff',
    warning: '#faad14',
    error: '#ff7a45',
    critical: '#f5222d',
  };
  return colors[level] || '#d9d9d9';
};

const getRiskColor = (score: number) => {
  if (score >= 80) return '#f5222d';
  if (score >= 60) return '#ff7a45';
  if (score >= 40) return '#faad14';
  return '#52c41a';
};

const fetchData = async () => {
  loading.value = true;
  try {
    const query: SearchEventsQuery = {
      page: pagination.current,
      pageSize: pagination.pageSize,
      type: filterForm.type || undefined,
      level: filterForm.level || undefined,
      username: filterForm.username || undefined,
      ip: filterForm.ip || undefined,
      start_time: filterForm.timeRange[0] || undefined,
      end_time: filterForm.timeRange[1] || undefined,
    };

    await securityStore.fetchEvents(query);
    pagination.total = securityStore.eventsTotal;
  } catch (error) {
    Message.error('获取事件列表失败');
  } finally {
    loading.value = false;
  }
};

const handleSearch = () => {
  pagination.current = 1;
  fetchData();
};

const handleReset = () => {
  filterForm.type = '';
  filterForm.level = '';
  filterForm.username = '';
  filterForm.ip = '';
  filterForm.timeRange = [];
  handleSearch();
};

const handlePageChange = (page: number) => {
  pagination.current = page;
  fetchData();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.pageSize = pageSize;
  pagination.current = 1;
  fetchData();
};

const handleViewDetail = async (record: SecurityEvent) => {
  try {
    await securityStore.fetchEvent(record.id);
    currentEvent.value = securityStore.currentEvent;
    detailVisible.value = true;
  } catch (error) {
    Message.error('获取事件详情失败');
  }
};

const handleExport = async () => {
  try {
    const query: SearchEventsQuery = {
      type: filterForm.type || undefined,
      level: filterForm.level || undefined,
      username: filterForm.username || undefined,
      ip: filterForm.ip || undefined,
      start_time: filterForm.timeRange[0] || undefined,
      end_time: filterForm.timeRange[1] || undefined,
    };

    const blob = await exportEvents(query);
    const url = window.URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `security-events-${Date.now()}.xlsx`;
    a.click();
    window.URL.revokeObjectURL(url);
    
    Message.success('导出成功');
  } catch (error) {
    Message.error('导出失败');
  }
};

// 生命周期
onMounted(() => {
  fetchData();
});
</script>

<style scoped lang="less">
.security-events-page {
  padding: 20px;
}

.filter-section {
  margin-bottom: 16px;
}
</style>
