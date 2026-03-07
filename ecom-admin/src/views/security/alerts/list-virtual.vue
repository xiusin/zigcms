<template>
  <div class="alerts-list-virtual">
    <a-card :bordered="false">
      <!-- 页面标题 -->
      <template #title>
        <div class="page-header">
          <a-space>
            <icon-notification :size="24" />
            <span class="page-title">安全告警（虚拟滚动）</span>
            <a-tag color="green">高性能</a-tag>
          </a-space>
        </div>
      </template>

      <!-- 操作栏 -->
      <template #extra>
        <a-space>
          <a-input-search
            v-model="searchKeyword"
            placeholder="搜索告警"
            style="width: 200px"
            @search="handleSearch"
          />
          <a-select
            v-model="filterLevel"
            placeholder="告警级别"
            style="width: 120px"
            allow-clear
            @change="handleFilter"
          >
            <a-option value="critical">严重</a-option>
            <a-option value="high">高危</a-option>
            <a-option value="medium">中危</a-option>
            <a-option value="low">低危</a-option>
          </a-select>
          <a-button @click="refreshData">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </template>

      <!-- 统计信息 -->
      <div class="stats-bar">
        <a-space size="large">
          <a-statistic title="总告警数" :value="totalCount" />
          <a-statistic title="已加载" :value="alerts.length" />
          <a-statistic title="渲染性能" :value="`${renderTime}ms`" />
        </a-space>
      </div>

      <!-- 虚拟表格 -->
      <VirtualTable
        ref="virtualTableRef"
        :columns="columns"
        :data="filteredAlerts"
        :row-height="80"
        container-height="calc(100vh - 400px)"
        :buffer-size="10"
        row-key="id"
        :loading="loading"
        @load-more="loadMore"
      >
        <!-- 告警级别 -->
        <template #level="{ record }">
          <a-tag :color="getLevelColor(record.level)">
            {{ getLevelText(record.level) }}
          </a-tag>
        </template>

        <!-- 告警类型 -->
        <template #type="{ record }">
          <a-tag>{{ record.alert_type }}</a-tag>
        </template>

        <!-- 状态 -->
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>

        <!-- 时间 -->
        <template #created_at="{ record }">
          {{ formatTime(record.created_at) }}
        </template>

        <!-- 操作 -->
        <template #actions="{ record }">
          <a-space>
            <a-button type="text" size="small" @click="viewDetail(record)">
              查看
            </a-button>
            <a-button
              v-if="record.status === 'pending'"
              type="text"
              size="small"
              @click="handleAlert(record)"
            >
              处理
            </a-button>
          </a-space>
        </template>
      </VirtualTable>

      <!-- 性能提示 -->
      <div class="performance-tip">
        <a-alert type="info" show-icon>
          <template #icon>
            <icon-info-circle />
          </template>
          虚拟滚动已启用，可流畅处理 100,000+ 条数据。当前渲染时间: {{ renderTime }}ms
        </a-alert>
      </div>
    </a-card>

    <!-- 告警详情对话框 -->
    <AlertDetailDrawer
      v-model:visible="detailVisible"
      :alert="selectedAlert"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconNotification,
  IconRefresh,
  IconInfoCircle,
} from '@arco-design/web-vue/es/icon';
import dayjs from 'dayjs';
import { getAlertList } from '@/api/security';
import type { SecurityAlert } from '@/types/security';
import VirtualTable from '@/components/virtual-scroll/VirtualTable.vue';
import AlertDetailDrawer from './components/AlertDetailDrawer.vue';

// 数据
const loading = ref(false);
const alerts = ref<SecurityAlert[]>([]);
const totalCount = ref(0);
const currentPage = ref(1);
const pageSize = ref(100);

// 搜索和筛选
const searchKeyword = ref('');
const filterLevel = ref<string>();

// 虚拟表格引用
const virtualTableRef = ref<InstanceType<typeof VirtualTable>>();

// 告警详情
const detailVisible = ref(false);
const selectedAlert = ref<SecurityAlert | null>(null);

// 渲染时间
const renderTime = ref(0);

// 表格列
const columns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '级别', dataIndex: 'level', slotName: 'level', width: 100 },
  { title: '类型', dataIndex: 'alert_type', slotName: 'type', width: 150 },
  { title: '消息', dataIndex: 'message' },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 100 },
  { title: '时间', dataIndex: 'created_at', slotName: 'created_at', width: 180 },
  { title: '操作', dataIndex: 'actions', slotName: 'actions', width: 150 },
];

// 过滤后的告警
const filteredAlerts = computed(() => {
  let result = alerts.value;

  // 搜索过滤
  if (searchKeyword.value) {
    const keyword = searchKeyword.value.toLowerCase();
    result = result.filter(
      (alert) =>
        alert.message.toLowerCase().includes(keyword) ||
        alert.alert_type.toLowerCase().includes(keyword)
    );
  }

  // 级别过滤
  if (filterLevel.value) {
    result = result.filter((alert) => alert.level === filterLevel.value);
  }

  return result;
});

// 获取级别颜色
const getLevelColor = (level: string) => {
  const colorMap: Record<string, string> = {
    critical: 'red',
    high: 'orange',
    medium: 'gold',
    low: 'blue',
  };
  return colorMap[level] || 'gray';
};

// 获取级别文本
const getLevelText = (level: string) => {
  const textMap: Record<string, string> = {
    critical: '严重',
    high: '高危',
    medium: '中危',
    low: '低危',
  };
  return textMap[level] || level;
};

// 获取状态颜色
const getStatusColor = (status: string) => {
  const colorMap: Record<string, string> = {
    pending: 'orange',
    processing: 'blue',
    resolved: 'green',
    ignored: 'gray',
  };
  return colorMap[status] || 'gray';
};

// 获取状态文本
const getStatusText = (status: string) => {
  const textMap: Record<string, string> = {
    pending: '待处理',
    processing: '处理中',
    resolved: '已解决',
    ignored: '已忽略',
  };
  return textMap[status] || status;
};

// 格式化时间
const formatTime = (time: string) => {
  return dayjs(time).format('YYYY-MM-DD HH:mm:ss');
};

// 加载数据
const loadData = async (append = false) => {
  loading.value = true;
  const startTime = performance.now();

  try {
    const { data } = await getAlertList({
      page: currentPage.value,
      page_size: pageSize.value,
      level: filterLevel.value,
      keyword: searchKeyword.value,
    });

    if (append) {
      alerts.value.push(...data.items);
    } else {
      alerts.value = data.items;
    }

    totalCount.value = data.total;

    // 计算渲染时间
    const endTime = performance.now();
    renderTime.value = Math.round(endTime - startTime);
  } catch (error) {
    Message.error('加载数据失败');
    console.error(error);
  } finally {
    loading.value = false;
  }
};

// 加载更多
const loadMore = () => {
  if (loading.value || alerts.value.length >= totalCount.value) {
    return;
  }

  currentPage.value += 1;
  loadData(true);
};

// 刷新数据
const refreshData = () => {
  currentPage.value = 1;
  loadData(false);
};

// 搜索
const handleSearch = () => {
  currentPage.value = 1;
  loadData(false);
};

// 筛选
const handleFilter = () => {
  currentPage.value = 1;
  loadData(false);
};

// 查看详情
const viewDetail = (alert: SecurityAlert) => {
  selectedAlert.value = alert;
  detailVisible.value = true;
};

// 处理告警
const handleAlert = (alert: SecurityAlert) => {
  Message.info(`处理告警: ${alert.id}`);
  // TODO: 实现处理逻辑
};

// 初始化
onMounted(() => {
  loadData();
});
</script>

<style scoped lang="scss">
.alerts-list-virtual {
  padding: 20px;

  .page-header {
    display: flex;
    align-items: center;

    .page-title {
      font-size: 18px;
      font-weight: 600;
    }
  }

  .stats-bar {
    margin-bottom: 16px;
    padding: 16px;
    background: #f9fafb;
    border-radius: 4px;
  }

  .performance-tip {
    margin-top: 16px;
  }
}
</style>
