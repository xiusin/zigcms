<template>
  <div class="security-dashboard">
    <a-page-header title="安全监控" subtitle="实时监控系统安全状态" />
    
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="stats-row">
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="今日安全事件"
            :value="stats.todayEvents"
            :value-style="{ color: '#f53f3f' }"
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
            title="活跃IP数"
            :value="stats.activeIPs"
            :value-style="{ color: '#165dff' }"
          >
            <template #prefix>
              <icon-computer />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="封禁IP数"
            :value="stats.bannedIPs"
            :value-style="{ color: '#ff7d00' }"
          >
            <template #prefix>
              <icon-stop />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="告警次数"
            :value="stats.alertCount"
            :value-style="{ color: '#f7ba1e' }"
          >
            <template #prefix>
              <icon-notification />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>
    
    <!-- 图表区域 -->
    <a-row :gutter="16" class="charts-row">
      <!-- 安全事件趋势（使用交互式图表） -->
      <a-col :span="12">
        <a-card title="安全事件趋势" :bordered="false">
          <InteractiveChart
            :config="eventTrendConfig"
            :export-formats="['png', 'csv']"
            :realtime="true"
            :realtime-interval="30000"
            height="300px"
            @data-update="loadStats"
          />
        </a-card>
      </a-col>
      
      <!-- 事件类型分布（使用交互式图表） -->
      <a-col :span="12">
        <a-card title="事件类型分布" :bordered="false">
          <InteractiveChart
            :config="eventTypeConfig"
            :export-formats="['png', 'csv']"
            height="300px"
          />
        </a-card>
      </a-col>
    </a-row>
    
    <a-row :gutter="16" class="charts-row">
      <!-- 严重程度分布（使用交互式图表） -->
      <a-col :span="12">
        <a-card title="严重程度分布" :bordered="false">
          <InteractiveChart
            :config="severityConfig"
            :export-formats="['png', 'csv']"
            height="300px"
          />
        </a-card>
      </a-col>
      
      <!-- TOP 10 攻击IP（使用交互式图表） -->
      <a-col :span="12">
        <a-card title="TOP 10 攻击IP" :bordered="false">
          <InteractiveChart
            :config="topIPConfig"
            :export-formats="['png', 'csv']"
            height="300px"
            @click="handleIPClick"
          />
        </a-card>
      </a-col>
    </a-row>
    
    <!-- 实时事件列表 -->
    <a-card title="实时安全事件" :bordered="false" class="events-card">
      <template #extra>
        <a-space>
          <a-select v-model="eventFilter" placeholder="事件类型" style="width: 150px" allow-clear>
            <a-option value="login_failed">登录失败</a-option>
            <a-option value="permission_denied">权限拒绝</a-option>
            <a-option value="rate_limit_exceeded">速率限制</a-option>
            <a-option value="sql_injection_attempt">SQL注入</a-option>
            <a-option value="xss_attack_attempt">XSS攻击</a-option>
          </a-select>
          
          <a-button type="primary" @click="refreshEvents">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </template>
      
      <a-table
        :data="events"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
      >
        <template #columns>
          <a-table-column title="时间" data-index="created_at" :width="180">
            <template #cell="{ record }">
              {{ formatTime(record.created_at) }}
            </template>
          </a-table-column>
          
          <a-table-column title="事件类型" data-index="event_type" :width="150">
            <template #cell="{ record }">
              <a-tag :color="getEventTypeColor(record.event_type)">
                {{ getEventTypeName(record.event_type) }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="严重程度" data-index="severity" :width="120">
            <template #cell="{ record }">
              <a-tag :color="getSeverityColor(record.severity)">
                {{ getSeverityName(record.severity) }}
              </a-tag>
            </template>
          </a-table-column>
          
          <a-table-column title="IP地址" data-index="client_ip" :width="150" />
          
          <a-table-column title="用户" data-index="username" :width="120">
            <template #cell="{ record }">
              {{ record.username || '-' }}
            </template>
          </a-table-column>
          
          <a-table-column title="描述" data-index="description" />
          
          <a-table-column title="操作" :width="150" fixed="right">
            <template #cell="{ record }">
              <a-space>
                <a-button type="text" size="small" @click="viewDetails(record)">
                  详情
                </a-button>
                <a-button
                  v-if="!record.is_blocked"
                  type="text"
                  size="small"
                  status="danger"
                  @click="blockIP(record.client_ip)"
                >
                  封禁IP
                </a-button>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-card>
    
    <!-- 事件详情抽屉 -->
    <a-drawer
      v-model:visible="detailsVisible"
      title="事件详情"
      :width="600"
      :footer="false"
    >
      <a-descriptions v-if="selectedEvent" :column="1" bordered>
        <a-descriptions-item label="事件ID">
          {{ selectedEvent.id }}
        </a-descriptions-item>
        <a-descriptions-item label="事件类型">
          <a-tag :color="getEventTypeColor(selectedEvent.event_type)">
            {{ getEventTypeName(selectedEvent.event_type) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="严重程度">
          <a-tag :color="getSeverityColor(selectedEvent.severity)">
            {{ getSeverityName(selectedEvent.severity) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="IP地址">
          {{ selectedEvent.client_ip }}
        </a-descriptions-item>
        <a-descriptions-item label="用户">
          {{ selectedEvent.username || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="请求路径">
          {{ selectedEvent.path }}
        </a-descriptions-item>
        <a-descriptions-item label="请求方法">
          {{ selectedEvent.method }}
        </a-descriptions-item>
        <a-descriptions-item label="描述">
          {{ selectedEvent.description }}
        </a-descriptions-item>
        <a-descriptions-item label="详情">
          <pre>{{ JSON.stringify(JSON.parse(selectedEvent.details), null, 2) }}</pre>
        </a-descriptions-item>
        <a-descriptions-item label="是否阻止">
          <a-tag :color="selectedEvent.is_blocked ? 'red' : 'green'">
            {{ selectedEvent.is_blocked ? '已阻止' : '未阻止' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="时间">
          {{ formatTime(selectedEvent.created_at) }}
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconExclamationCircle,
  IconComputer,
  IconStop,
  IconNotification,
  IconRefresh
} from '@arco-design/web-vue/es/icon';
import InteractiveChart from '@/components/chart/InteractiveChart.vue';
import type { ChartConfig } from '@/composables/useInteractiveChart';

// 统计数据
const stats = ref({
  todayEvents: 0,
  activeIPs: 0,
  bannedIPs: 0,
  alertCount: 0
});

// 事件列表
const events = ref<any[]>([]);
const loading = ref(false);
const eventFilter = ref('');
const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0
});

// 事件详情
const detailsVisible = ref(false);
const selectedEvent = ref<any>(null);

// 自动刷新定时器
let refreshTimer: number;

// 安全事件趋势图表配置
const eventTrendConfig = computed<ChartConfig>(() => ({
  type: 'line',
  title: '安全事件趋势',
  xAxis: {
    type: 'category',
    data: ['00:00', '04:00', '08:00', '12:00', '16:00', '20:00'],
  },
  yAxis: {
    type: 'value',
    name: '事件数',
  },
  series: [
    {
      name: '安全事件',
      type: 'line',
      data: [12, 8, 15, 23, 18, 10],
      smooth: true,
      areaStyle: {
        opacity: 0.3,
      },
    },
  ],
}));

// 事件类型分布图表配置
const eventTypeConfig = computed<ChartConfig>(() => ({
  type: 'pie',
  title: '事件类型分布',
  series: [
    {
      name: '事件类型',
      type: 'pie',
      radius: '50%',
      data: [
        { value: 45, name: '登录失败' },
        { value: 30, name: '权限拒绝' },
        { value: 15, name: '速率限制' },
        { value: 10, name: 'SQL注入' },
      ],
    },
  ],
}));

// 严重程度分布图表配置
const severityConfig = computed<ChartConfig>(() => ({
  type: 'pie',
  title: '严重程度分布',
  series: [
    {
      name: '严重程度',
      type: 'pie',
      radius: ['40%', '70%'],
      data: [
        { value: 50, name: '低' },
        { value: 30, name: '中' },
        { value: 15, name: '高' },
        { value: 5, name: '严重' },
      ],
    },
  ],
}));

// TOP 10 攻击IP图表配置
const topIPConfig = computed<ChartConfig>(() => ({
  type: 'bar',
  title: 'TOP 10 攻击IP',
  xAxis: {
    type: 'value',
    name: '攻击次数',
  },
  yAxis: {
    type: 'category',
    data: ['192.168.1.1', '192.168.1.2', '192.168.1.3'],
  },
  series: [
    {
      name: '攻击次数',
      type: 'bar',
      data: [45, 30, 15],
    },
  ],
}));

onMounted(() => {
  loadStats();
  loadEvents();
  
  // 每30秒自动刷新
  refreshTimer = window.setInterval(() => {
    loadStats();
    loadEvents();
  }, 30000);
});

onUnmounted(() => {
  // 清理定时器
  if (refreshTimer) {
    clearInterval(refreshTimer);
  }
});

// 加载统计数据
async function loadStats() {
  // TODO: 调用API
  stats.value = {
    todayEvents: 156,
    activeIPs: 89,
    bannedIPs: 5,
    alertCount: 12
  };
}

// 加载事件列表
async function loadEvents() {
  loading.value = true;
  
  try {
    // TODO: 调用API
    events.value = [];
    pagination.value.total = 0;
  } finally {
    loading.value = false;
  }
}

// 刷新事件
function refreshEvents() {
  loadEvents();
  Message.success('已刷新');
}

// 分页变化
function handlePageChange(page: number) {
  pagination.value.current = page;
  loadEvents();
}

// 查看详情
function viewDetails(record: any) {
  selectedEvent.value = record;
  detailsVisible.value = true;
}

// 封禁IP
async function blockIP(ip: string) {
  // TODO: 调用API
  Message.success(`已封禁IP: ${ip}`);
  loadEvents();
}

// IP点击事件
function handleIPClick(params: any) {
  console.log('IP点击:', params);
  Message.info(`查看 ${params.name} 详情`);
}

// 格式化时间
function formatTime(time: string) {
  return new Date(time).toLocaleString('zh-CN');
}

// 获取事件类型颜色
function getEventTypeColor(type: string) {
  const colors: Record<string, string> = {
    login_failed: 'orange',
    permission_denied: 'red',
    rate_limit_exceeded: 'gold',
    sql_injection_attempt: 'red',
    xss_attack_attempt: 'red'
  };
  return colors[type] || 'blue';
}

// 获取事件类型名称
function getEventTypeName(type: string) {
  const names: Record<string, string> = {
    login_failed: '登录失败',
    permission_denied: '权限拒绝',
    rate_limit_exceeded: '速率限制',
    sql_injection_attempt: 'SQL注入',
    xss_attack_attempt: 'XSS攻击'
  };
  return names[type] || type;
}

// 获取严重程度颜色
function getSeverityColor(severity: string) {
  const colors: Record<string, string> = {
    low: 'green',
    medium: 'orange',
    high: 'red',
    critical: 'red'
  };
  return colors[severity] || 'blue';
}

// 获取严重程度名称
function getSeverityName(severity: string) {
  const names: Record<string, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '严重'
  };
  return names[severity] || severity;
}
</script>

<style scoped lang="less">
.security-dashboard {
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
  
  .charts-row {
    margin-bottom: 16px;
  }
  
  .events-card {
    pre {
      background: var(--color-fill-2);
      padding: 12px;
      border-radius: 4px;
      font-size: 12px;
      max-height: 300px;
      overflow: auto;
    }
  }
}
</style>
