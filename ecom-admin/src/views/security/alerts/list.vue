<template>
  <div class="alerts-list-page">
    <a-page-header title="安全告警" subtitle="实时监控和处理安全告警" />
    
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="stats-row">
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="今日告警"
            :value="stats.todayAlerts"
            :value-style="{ color: '#f53f3f' }"
          >
            <template #prefix>
              <icon-notification />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="待处理"
            :value="stats.pendingAlerts"
            :value-style="{ color: '#ff7d00' }"
          >
            <template #prefix>
              <icon-exclamation-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="严重告警"
            :value="stats.criticalAlerts"
            :value-style="{ color: '#d91ad9' }"
          >
            <template #prefix>
              <icon-fire />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="已处理"
            :value="stats.resolvedAlerts"
            :value-style="{ color: '#00b42a' }"
          >
            <template #prefix>
              <icon-check-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>
    
    <!-- 筛选和操作 -->
    <a-card :bordered="false" class="filter-card">
      <a-row :gutter="16">
        <a-col :span="6">
          <a-select
            v-model="filters.level"
            placeholder="告警级别"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="info">信息</a-option>
            <a-option value="warning">警告</a-option>
            <a-option value="error">错误</a-option>
            <a-option value="critical">严重</a-option>
          </a-select>
        </a-col>

        <a-col :span="6">
          <a-select
            v-model="filters.status"
            placeholder="处理状态"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="pending">待处理</a-option>
            <a-option value="resolved">已处理</a-option>
            <a-option value="ignored">已忽略</a-option>
          </a-select>
        </a-col>
        
        <a-col :span="6">
          <a-select
            v-model="filters.type"
            placeholder="告警类型"
            allow-clear
            @change="handleSearch"
          >
            <a-option value="login_failed">登录失败</a-option>
            <a-option value="permission_denied">权限拒绝</a-option>
            <a-option value="rate_limit_exceeded">速率限制</a-option>
            <a-option value="sql_injection_attempt">SQL注入</a-option>
            <a-option value="xss_attack_attempt">XSS攻击</a-option>
          </a-select>
        </a-col>
        
        <a-col :span="6">
          <a-space>
            <a-button type="primary" @click="handleSearch">
              <icon-search />
              搜索
            </a-button>
            <a-button @click="handleReset">
              <icon-refresh />
              重置
            </a-button>
          </a-space>
        </a-col>
      </a-row>
    </a-card>
    
    <!-- 批量操作栏 -->
    <BatchOperationBar
      :selected-ids="selectedAlertIds"
      @clear="selectedAlertIds = []"
      @success="handleBatchSuccess"
    />
    
    <!-- 告警列表 -->
    <a-card :bordered="false" class="table-card">
      <a-table
        :data="alerts"
        :loading="loading"
        :pagination="pagination"
        :row-selection="rowSelection"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #columns>
          <a-table-column title="ID" data-index="id" :width="80" />
          
          <a-table-column title="级别" data-index="level" :width="100">
            <template #cell="{ record }">
              <a-tag :color="getLevelColor(record.level)">
                {{ getLevelText(record.level) }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="类型" data-index="type" :width="150">
            <template #cell="{ record }">
              {{ getTypeText(record.type) }}
            </template>
          </a-table-column>
          
          <a-table-column title="消息" data-index="message" :ellipsis="true" :tooltip="true" />
          
          <a-table-column title="状态" data-index="status" :width="100">
            <template #cell="{ record }">
              <a-tag :color="getStatusColor(record.status)">
                {{ getStatusText(record.status) }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="触发时间" data-index="created_at" :width="180">
            <template #cell="{ record }">
              {{ formatTime(record.created_at) }}
            </template>
          </a-table-column>
          
          <a-table-column title="操作" :width="200" fixed="right">
            <template #cell="{ record }">
              <a-space>
                <a-button type="text" size="small" @click="viewDetail(record)">
                  详情
                </a-button>
                <a-button
                  v-if="record.status === 'pending'"
                  type="text"
                  size="small"
                  @click="handleSingleAlert(record)"
                >
                  处理
                </a-button>
                <a-popconfirm
                  content="确定删除此告警吗？"
                  @ok="handleDelete(record.id)"
                >
                  <a-button type="text" size="small" status="danger">
                    删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
    
    <!-- 告警详情抽屉 -->
    <AlertDetailDrawer
      v-model="detailVisible"
      :alert="selectedAlert"
      @handle="handleSingleAlert"
    />
    
    <!-- 处理告警对话框 -->
    <HandleAlertDialog
      v-model="handleVisible"
      :alert="selectedAlert"
      @success="handleSuccess"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconNotification,
  IconExclamationCircle,
  IconFire,
  IconCheckCircle,
  IconSearch,
  IconRefresh
} from '@arco-design/web-vue/es/icon';
import { useSecurityStore } from '@/store/modules/security';
import type { Alert } from '@/types/security';
import { ALERT_LEVEL_LABELS, ALERT_LEVEL_COLORS, ALERT_TYPE_LABELS, ALERT_STATUS_LABELS, ALERT_STATUS_COLORS } from '@/types/security.ts';
import BatchOperationBar from './components/BatchOperationBar.vue';
import AlertDetailDrawer from './components/AlertDetailDrawer.vue';
import HandleAlertDialog from './components/HandleAlertDialog.vue';

const securityStore = useSecurityStore();

// 统计数据
const stats = computed(() => {
  const today = new Date().toDateString();
  return {
    todayAlerts: securityStore.alerts.filter(a => 
      new Date(a.created_at).toDateString() === today
    ).length,
    pendingAlerts: securityStore.pendingAlertsCount,
    criticalAlerts: securityStore.criticalAlertsCount,
    resolvedAlerts: securityStore.alerts.filter(a => a.status === 'resolved').length
  };
});

// 筛选条件
const filters = reactive({
  level: '',
  status: '',
  type: ''
});

// 列表数据
const loading = ref(false);
const alerts = computed(() => securityStore.alerts);
const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: computed(() => securityStore.alertsTotal),
  showTotal: true,
  showPageSize: true
});

// 批量选择
const selectedAlertIds = ref<number[]>([]);
const rowSelection = reactive({
  type: 'checkbox',
  selectedRowKeys: selectedAlertIds,
  onSelect: (rowKeys: number[]) => {
    selectedAlertIds.value = rowKeys;
  }
});

// 详情和处理
const detailVisible = ref(false);
const handleVisible = ref(false);
const selectedAlert = ref<Alert | null>(null);

onMounted(() => {
  loadAlerts();
});

const loadAlerts = async () => {
  loading.value = true;
  try {
    await securityStore.fetchAlerts({
      page: pagination.current,
      page_size: pagination.pageSize,
      level: filters.level || undefined,
      status: filters.status || undefined,
      type: filters.type || undefined
    });
  } finally {
    loading.value = false;
  }
};

const handleSearch = () => {
  pagination.current = 1;
  loadAlerts();
};

const handleReset = () => {
  filters.level = '';
  filters.status = '';
  filters.type = '';
  handleSearch();
};

const handlePageChange = (page: number) => {
  pagination.current = page;
  loadAlerts();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.pageSize = pageSize;
  pagination.current = 1;
  loadAlerts();
};

const viewDetail = (alert: Alert) => {
  selectedAlert.value = alert;
  detailVisible.value = true;
};

const handleSingleAlert = (alert: Alert) => {
  selectedAlert.value = alert;
  handleVisible.value = true;
  detailVisible.value = false;
};

const handleDelete = async (id: number) => {
  try {
    await securityStore.deleteAlert(id);
    Message.success('删除成功');
    loadAlerts();
  } catch (error) {
    Message.error('删除失败');
  }
};

const handleSuccess = () => {
  loadAlerts();
  selectedAlertIds.value = [];
};

const handleBatchSuccess = () => {
  handleSuccess();
};

const getLevelColor = (level: string) => {
  return ALERT_LEVEL_COLORS[level] || 'blue';
};

const getLevelText = (level: string) => {
  return ALERT_LEVEL_LABELS[level] || level;
};

const getTypeText = (type: string) => {
  return ALERT_TYPE_LABELS[type] || type;
};

const getStatusColor = (status: string) => {
  return ALERT_STATUS_COLORS[status] || 'blue';
};

const getStatusText = (status: string) => {
  return ALERT_STATUS_LABELS[status] || status;
};

const formatTime = (time: string) => {
  return new Date(time).toLocaleString('zh-CN');
};
</script>

<style scoped lang="less">
.alerts-list-page {
  padding: 20px;
  
  .stats-row {
    margin-bottom: 16px;
    
    .stat-card {
      :deep(.arco-statistic-title) {
        font-size: 14px;
        color: var(--color-text-2);
      }
      
      :deep(.arco-statistic-value) {
        font-size: 28px;
        font-weight: 600;
      }
    }
  }
  
  .filter-card {
    margin-bottom: 16px;
  }
  
  .table-card {
    :deep(.arco-table-th) {
      background: var(--color-fill-2);
    }
  }
}
</style>
