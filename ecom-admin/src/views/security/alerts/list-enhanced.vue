<template>
  <div class="security-alerts-list">
    <!-- 页面头部 -->
    <div class="page-header">
      <h1>安全告警</h1>
      <a-space>
        <a-button type="primary" @click="handleRefresh">
          <template #icon><icon-refresh /></template>
          刷新
        </a-button>
        <a-button @click="showHelp">
          <template #icon><icon-question-circle /></template>
          快捷键
        </a-button>
      </a-space>
    </div>

    <!-- 统计卡片 -->
    <div class="stats-cards">
      <a-row :gutter="16">
        <a-col :span="6">
          <a-card class="stat-card">
            <a-statistic
              title="今日告警"
              :value="todayAlerts"
              :value-style="{ color: '#f53f3f' }"
            >
              <template #prefix>
                <icon-notification class="stat-icon" />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
        <a-col :span="6">
          <a-card class="stat-card">
            <a-statistic
              title="待处理"
              :value="pendingAlerts"
              :value-style="{ color: '#ff7d00' }"
            >
              <template #prefix>
                <icon-exclamation-circle class="stat-icon" />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
        <a-col :span="6">
          <a-card class="stat-card">
            <a-statistic
              title="严重告警"
              :value="criticalAlerts"
              :value-style="{ color: '#d91ad9' }"
            >
              <template #prefix>
                <icon-fire class="stat-icon" />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
        <a-col :span="6">
          <a-card class="stat-card">
            <a-statistic
              title="已处理"
              :value="resolvedAlerts"
              :value-style="{ color: '#00b42a' }"
            >
              <template #prefix>
                <icon-check-circle class="stat-icon" />
              </template>
            </a-statistic>
          </a-card>
        </a-col>
      </a-row>
    </div>

    <!-- 筛选区域 -->
    <div class="filter-section">
      <a-space>
        <a-select
          v-model="filters.level"
          placeholder="告警级别"
          allow-clear
          style="width: 150px"
          @change="handleFilterChange"
        >
          <a-option value="critical">严重</a-option>
          <a-option value="high">高危</a-option>
          <a-option value="medium">中危</a-option>
          <a-option value="low">低危</a-option>
        </a-select>

        <a-select
          v-model="filters.status"
          placeholder="告警状态"
          allow-clear
          style="width: 150px"
          @change="handleFilterChange"
        >
          <a-option value="pending">待处理</a-option>
          <a-option value="handling">处理中</a-option>
          <a-option value="resolved">已处理</a-option>
          <a-option value="ignored">已忽略</a-option>
        </a-select>

        <a-select
          v-model="filters.type"
          placeholder="告警类型"
          allow-clear
          style="width: 150px"
          @change="handleFilterChange"
        >
          <a-option value="brute_force">暴力破解</a-option>
          <a-option value="sql_injection">SQL注入</a-option>
          <a-option value="xss">XSS攻击</a-option>
          <a-option value="csrf">CSRF攻击</a-option>
          <a-option value="rate_limit">频率限制</a-option>
        </a-select>

        <a-input-search
          ref="searchInputRef"
          v-model="filters.keyword"
          placeholder="搜索告警消息"
          style="width: 300px"
          @search="handleSearch"
        />
      </a-space>
    </div>

    <!-- 批量操作栏 -->
    <BatchOperationBar
      :selected-ids="selectedIds"
      :loading="batchLoading"
      @batch-handle="handleBatchHandle"
      @batch-ignore="handleBatchIgnore"
      @batch-export="handleBatchExport"
      @batch-delete="handleBatchDelete"
      @clear="handleClearSelection"
    />

    <!-- 告警列表 -->
    <div class="alerts-table">
      <a-table
        :data="alerts"
        :loading="loading"
        :pagination="false"
        :row-selection="{
          type: 'checkbox',
          selectedRowKeys: selectedIds,
          onSelect: handleSelect,
          onSelectAll: handleSelectAll,
        }"
        @row-click="handleRowClick"
      >
        <template #columns>
          <a-table-column title="级别" data-index="level" :width="100">
            <template #cell="{ record }">
              <a-tag :color="getLevelColor(record.level)">
                {{ getLevelText(record.level) }}
              </a-tag>
            </template>
          </a-table-column>

          <a-table-column title="类型" data-index="type" :width="120">
            <template #cell="{ record }">
              {{ getTypeText(record.type) }}
            </template>
          </a-table-column>

          <a-table-column title="消息" data-index="message" :width="300" />

          <a-table-column title="状态" data-index="status" :width="100">
            <template #cell="{ record }">
              <a-tag :color="getStatusColor(record.status)">
                {{ getStatusText(record.status) }}
              </a-tag>
            </template>
          </a-table-column>

          <a-table-column title="创建时间" data-index="created_at" :width="180">
            <template #cell="{ record }">
              {{ formatTime(record.created_at) }}
            </template>
          </a-table-column>

          <a-table-column title="操作" :width="200" fixed="right">
            <template #cell="{ record }">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click.stop="handleViewDetail(record)"
                >
                  详情
                </a-button>
                <a-button
                  v-if="record.status === 'pending'"
                  type="text"
                  size="small"
                  status="warning"
                  @click.stop="handleHandle(record)"
                >
                  处理
                </a-button>
                <a-popconfirm
                  content="确定删除这条告警吗？"
                  @ok="handleDelete(record)"
                >
                  <a-button
                    type="text"
                    size="small"
                    status="danger"
                    @click.stop
                  >
                    删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </div>

    <!-- 分页 -->
    <div class="pagination">
      <a-pagination
        v-model:current="pagination.current"
        v-model:page-size="pagination.pageSize"
        :total="pagination.total"
        show-total
        show-jumper
        show-page-size
        @change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      />
    </div>

    <!-- 告警详情抽屉 -->
    <AlertDetailDrawer
      v-model:visible="detailVisible"
      :alert="currentAlert"
      @handle="handleHandle"
    />

    <!-- 处理告警对话框 -->
    <HandleAlertDialog
      v-model:visible="handleVisible"
      :alert="currentAlert"
      @submit="handleSubmitHandle"
    />

    <!-- 快捷键帮助对话框 -->
    <a-modal
      v-model:visible="helpVisible"
      title="键盘快捷键"
      :footer="false"
      width="500px"
    >
      <a-descriptions :column="1" bordered>
        <a-descriptions-item
          v-for="shortcut in shortcuts"
          :key="shortcut.key"
          :label="getShortcutKeys(shortcut)"
        >
          {{ shortcut.description }}
        </a-descriptions-item>
      </a-descriptions>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useSecurityStore } from '@/store/modules/security';
import { Message } from '@arco-design/web-vue';
import { useKeyboardShortcuts } from '@/composables/useKeyboardShortcuts';
import AlertDetailDrawer from './components/AlertDetailDrawer.vue';
import HandleAlertDialog from './components/HandleAlertDialog.vue';
import BatchOperationBar from './components/BatchOperationBar.vue';
import type { SecurityAlert } from '@/types/security';

const securityStore = useSecurityStore();

// 搜索输入框引用
const searchInputRef = ref();

// 加载状态
const loading = ref(false);
const batchLoading = ref(false);

// 筛选条件
const filters = ref({
  level: undefined as string | undefined,
  status: undefined as string | undefined,
  type: undefined as string | undefined,
  keyword: '',
});

// 分页
const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0,
});

// 选中的告警ID
const selectedIds = ref<number[]>([]);

// 当前操作的告警
const currentAlert = ref<SecurityAlert | null>(null);

// 对话框显示状态
const detailVisible = ref(false);
const handleVisible = ref(false);
const helpVisible = ref(false);

// 告警列表
const alerts = computed(() => securityStore.alerts);

// 统计数据
const todayAlerts = computed(() => {
  const today = new Date().toDateString();
  return alerts.value.filter(
    (a) => new Date(a.created_at).toDateString() === today
  ).length;
});

const pendingAlerts = computed(() =>
  alerts.value.filter((a) => a.status === 'pending').length
);

const criticalAlerts = computed(() =>
  alerts.value.filter((a) => a.level === 'critical').length
);

const resolvedAlerts = computed(() =>
  alerts.value.filter((a) => a.status === 'resolved').length
);

// 键盘快捷键
const shortcuts = [
  {
    key: 'f',
    ctrl: true,
    description: '聚焦搜索框',
    handler: () => {
      searchInputRef.value?.focus();
    },
  },
  {
    key: 'r',
    ctrl: true,
    description: '刷新列表',
    handler: () => {
      handleRefresh();
    },
  },
  {
    key: 'a',
    ctrl: true,
    description: '全选',
    handler: () => {
      handleSelectAll(true);
    },
  },
  {
    key: 'Escape',
    description: '取消选择',
    handler: () => {
      handleClearSelection();
    },
  },
  {
    key: 'Delete',
    description: '删除选中项',
    handler: () => {
      if (selectedIds.value.length > 0) {
        handleBatchDelete();
      }
    },
  },
  {
    key: 'ArrowLeft',
    alt: true,
    description: '上一页',
    handler: () => {
      if (pagination.value.current > 1) {
        pagination.value.current--;
        loadAlerts();
      }
    },
  },
  {
    key: 'ArrowRight',
    alt: true,
    description: '下一页',
    handler: () => {
      const maxPage = Math.ceil(
        pagination.value.total / pagination.value.pageSize
      );
      if (pagination.value.current < maxPage) {
        pagination.value.current++;
        loadAlerts();
      }
    },
  },
  {
    key: '?',
    shift: true,
    description: '显示快捷键帮助',
    handler: () => {
      showHelp();
    },
  },
];

useKeyboardShortcuts(shortcuts);

// 加载告警列表
const loadAlerts = async () => {
  loading.value = true;
  try {
    await securityStore.fetchAlerts({
      page: pagination.value.current,
      page_size: pagination.value.pageSize,
      ...filters.value,
    });
    pagination.value.total = securityStore.alerts.length;
  } catch (error) {
    Message.error('加载告警列表失败');
  } finally {
    loading.value = false;
  }
};

// 刷新列表
const handleRefresh = () => {
  loadAlerts();
  Message.success('已刷新');
};

// 筛选变化
const handleFilterChange = () => {
  pagination.value.current = 1;
  loadAlerts();
};

// 搜索
const handleSearch = () => {
  pagination.value.current = 1;
  loadAlerts();
};

// 选择行
const handleSelect = (rowKeys: number[]) => {
  selectedIds.value = rowKeys;
};

// 全选
const handleSelectAll = (checked: boolean) => {
  if (checked) {
    selectedIds.value = alerts.value.map((a) => a.id);
  } else {
    selectedIds.value = [];
  }
};

// 清空选择
const handleClearSelection = () => {
  selectedIds.value = [];
};

// 行点击
const handleRowClick = (record: SecurityAlert) => {
  handleViewDetail(record);
};

// 查看详情
const handleViewDetail = (alert: SecurityAlert) => {
  currentAlert.value = alert;
  detailVisible.value = true;
};

// 处理告警
const handleHandle = (alert: SecurityAlert) => {
  currentAlert.value = alert;
  handleVisible.value = true;
};

// 提交处理
const handleSubmitHandle = async (data: any) => {
  try {
    await securityStore.handleAlert(currentAlert.value!.id, data);
    Message.success('处理成功');
    handleVisible.value = false;
    loadAlerts();
  } catch (error) {
    Message.error('处理失败');
  }
};

// 删除告警
const handleDelete = async (alert: SecurityAlert) => {
  try {
    await securityStore.deleteAlert(alert.id);
    Message.success('删除成功');
    loadAlerts();
  } catch (error) {
    Message.error('删除失败');
  }
};

// 批量处理
const handleBatchHandle = async () => {
  batchLoading.value = true;
  try {
    await securityStore.batchHandleAlerts(selectedIds.value, {
      action: 'resolve',
      comment: '批量处理',
    });
    Message.success('批量处理成功');
    selectedIds.value = [];
    loadAlerts();
  } catch (error) {
    Message.error('批量处理失败');
  } finally {
    batchLoading.value = false;
  }
};

// 批量忽略
const handleBatchIgnore = async () => {
  batchLoading.value = true;
  try {
    await securityStore.batchHandleAlerts(selectedIds.value, {
      action: 'ignore',
      comment: '批量忽略',
    });
    Message.success('批量忽略成功');
    selectedIds.value = [];
    loadAlerts();
  } catch (error) {
    Message.error('批量忽略失败');
  } finally {
    batchLoading.value = false;
  }
};

// 批量导出
const handleBatchExport = () => {
  const selectedAlerts = alerts.value.filter((a) =>
    selectedIds.value.includes(a.id)
  );
  const json = JSON.stringify(selectedAlerts, null, 2);
  const blob = new Blob([json], { type: 'application/json' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `alerts_${Date.now()}.json`;
  a.click();
  URL.revokeObjectURL(url);
  Message.success('导出成功');
};

// 批量删除
const handleBatchDelete = async () => {
  batchLoading.value = true;
  try {
    await Promise.all(
      selectedIds.value.map((id) => securityStore.deleteAlert(id))
    );
    Message.success('批量删除成功');
    selectedIds.value = [];
    loadAlerts();
  } catch (error) {
    Message.error('批量删除失败');
  } finally {
    batchLoading.value = false;
  }
};

// 分页变化
const handlePageChange = (page: number) => {
  pagination.value.current = page;
  loadAlerts();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.value.pageSize = pageSize;
  pagination.value.current = 1;
  loadAlerts();
};

// 显示帮助
const showHelp = () => {
  helpVisible.value = true;
};

// 获取快捷键文本
const getShortcutKeys = (shortcut: any) => {
  const keys = [];
  if (shortcut.ctrl) keys.push('Ctrl');
  if (shortcut.shift) keys.push('Shift');
  if (shortcut.alt) keys.push('Alt');
  if (shortcut.meta) keys.push('Meta');
  keys.push(shortcut.key);
  return keys.join(' + ');
};

// 工具函数
const getLevelColor = (level: string) => {
  const colors: Record<string, string> = {
    critical: 'red',
    high: 'orangered',
    medium: 'orange',
    low: 'blue',
  };
  return colors[level] || 'gray';
};

const getLevelText = (level: string) => {
  const texts: Record<string, string> = {
    critical: '严重',
    high: '高危',
    medium: '中危',
    low: '低危',
  };
  return texts[level] || level;
};

const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pending: 'orange',
    handling: 'blue',
    resolved: 'green',
    ignored: 'gray',
  };
  return colors[status] || 'gray';
};

const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    pending: '待处理',
    handling: '处理中',
    resolved: '已处理',
    ignored: '已忽略',
  };
  return texts[status] || status;
};

const getTypeText = (type: string) => {
  const texts: Record<string, string> = {
    brute_force: '暴力破解',
    sql_injection: 'SQL注入',
    xss: 'XSS攻击',
    csrf: 'CSRF攻击',
    rate_limit: '频率限制',
  };
  return texts[type] || type;
};

const formatTime = (time: string) => {
  return new Date(time).toLocaleString('zh-CN');
};

// 初始化
onMounted(() => {
  loadAlerts();
});
</script>

<style scoped lang="scss">
.security-alerts-list {
  padding: 20px;

  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;

    h1 {
      font-size: 24px;
      font-weight: 600;
      margin: 0;
    }
  }

  .stats-cards {
    margin-bottom: 20px;

    .stat-card {
      :deep(.arco-card-body) {
        padding: 20px;
      }

      .stat-icon {
        font-size: 32px;
      }
    }
  }

  .filter-section {
    margin-bottom: 20px;
  }

  .alerts-table {
    background: #fff;
    border-radius: 4px;
    padding: 20px;

    :deep(.arco-table-tr) {
      cursor: pointer;

      &:hover {
        background: #f7f8fa;
      }
    }
  }

  .pagination {
    margin-top: 20px;
    display: flex;
    justify-content: flex-end;
  }
}
</style>

<style scoped lang="scss" src="./list.mobile.scss"></style>
