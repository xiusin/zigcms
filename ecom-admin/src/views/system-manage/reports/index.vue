<template>
  <div class="container">
    <!-- 统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon blue">
              <icon-file />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ reports.length }}</div>
              <div class="stat-label">报表总数</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon orange">
              <icon-loading />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ pendingCount }}</div>
              <div class="stat-label">生成中</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon green">
              <icon-check-circle />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ completedCount }}</div>
              <div class="stat-label">已完成</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon purple">
              <icon-storage />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ totalSize }}</div>
              <div class="stat-label">总存储</div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 快捷操作区 -->
    <a-row :gutter="[16, 16]" class="quick-actions-row">
      <a-col :span="24">
        <a-card class="quick-actions-card" :bordered="false">
          <div class="quick-actions-content">
            <div class="quick-actions-title">
              <icon-thunderbolt />
              <span>快速生成报表</span>
            </div>
            <a-space size="large">
              <a-button type="primary" size="small" @click="generateReport('daily')">
                <icon-calendar /> 生成日报
              </a-button>
              <a-button size="small" @click="generateReport('weekly')">
                <icon-calendar /> 生成周报
              </a-button>
              <a-button size="small" @click="generateReport('monthly')">
                <icon-calendar /> 生成月报
              </a-button>
              <a-divider direction="vertical" />
              <a-button type="outline" size="small" @click="showCustomModal">
                <icon-plus /> 自定义报表
              </a-button>
            </a-space>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 报表列表 -->
    <a-card class="report-list-card" :bordered="false">
      <template #title>
        <div class="card-header">
          <div class="header-title">
            <icon-storage class="header-icon" />
            <span>报表列表</span>
            <a-tag color="arcoblue" size="small">{{ reports.length }}条</a-tag>
          </div>
        </div>
      </template>

      <template #extra>
        <a-space>
          <a-input-search
            v-model="searchKey"
            placeholder="搜索报表名称..."
            size="small"
            style="width: 220px"
            allow-clear
          />
          <a-select
            v-model="filterType"
            placeholder="报表类型"
            size="small"
            style="width: 120px"
            allow-clear
          >
            <a-option value="daily">日报</a-option>
            <a-option value="weekly">周报</a-option>
            <a-option value="monthly">月报</a-option>
            <a-option value="custom">自定义</a-option>
          </a-select>
          <a-select
            v-model="filterStatus"
            placeholder="状态"
            size="small"
            style="width: 100px"
            allow-clear
          >
            <a-option value="pending">生成中</a-option>
            <a-option value="completed">已完成</a-option>
            <a-option value="failed">失败</a-option>
          </a-select>
          <a-button size="small" @click="refreshList">
            <icon-refresh />
          </a-button>
        </a-space>
      </template>

      <a-table
        :columns="columns"
        :data="filteredReports"
        :pagination="pagination"
        size="small"
        class="report-table"
      >
        <template #name="{ record }">
          <div class="report-name-cell">
            <icon-file class="file-icon" />
            <span class="report-name">{{ record.name }}</span>
          </div>
        </template>
        <template #type="{ record }">
          <a-tag :color="getTypeColor(record.type)" size="small">
            {{ getTypeName(record.type) }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-tag
            v-if="record.status === 'pending'"
            color="orange"
            size="small"
          >
            <icon-loading class="spin" /> 生成中
          </a-tag>
          <a-tag
            v-else-if="record.status === 'completed'"
            color="green"
            size="small"
          >
            <icon-check-circle /> 已完成
          </a-tag>
          <a-tag v-else color="red" size="small">
            <icon-close-circle /> 失败
          </a-tag>
        </template>
        <template #file_size="{ record }">
          <span class="file-size">{{ record.file_size }}</span>
        </template>
        <template #actions="{ record }">
          <a-space>
            <a-button
              v-if="record.status === 'completed'"
              size="mini"
              type="text"
              @click="viewReport(record)"
            >
              <icon-eye /> 查看
            </a-button>
            <a-button
              v-if="record.status === 'completed'"
              size="mini"
              type="text"
              @click="downloadReport(record)"
            >
              <icon-download /> 下载
            </a-button>
            <a-button
              size="mini"
              type="text"
              status="danger"
              @click="deleteReport(record)"
            >
              <icon-delete /> 删除
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 自定义报表弹窗 -->
    <a-modal
      v-model:visible="customModalVisible"
      title="自定义报表"
      width="700px"
      @ok="handleCustomReport"
    >
      <a-form :model="customForm" layout="vertical">
        <a-form-item label="报表名称" required>
          <a-input v-model="customForm.name" placeholder="请输入报表名称" />
        </a-form-item>
        <a-form-item label="报表类型" required>
          <a-select v-model="customForm.type" placeholder="请选择报表类型">
            <a-option value="order">订单报表</a-option>
            <a-option value="member">会员报表</a-option>
            <a-option value="finance">财务报表</a-option>
            <a-option value="warehouse">仓库报表</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="时间范围" required>
          <a-range-picker v-model="customForm.dateRange" style="width: 100%" />
        </a-form-item>
        <a-form-item label="包含字段">
          <a-checkbox-group v-model="customForm.fields" direction="vertical">
            <a-checkbox value="id">ID</a-checkbox>
            <a-checkbox value="name">名称</a-checkbox>
            <a-checkbox value="amount">金额</a-checkbox>
            <a-checkbox value="quantity">数量</a-checkbox>
            <a-checkbox value="status">状态</a-checkbox>
            <a-checkbox value="created_at">创建时间</a-checkbox>
          </a-checkbox-group>
        </a-form-item>
        <a-form-item label="导出格式">
          <a-radio-group v-model="customForm.format" type="button">
            <a-radio value="excel">
              <icon-file /> Excel
            </a-radio>
            <a-radio value="pdf">
              <icon-file-pdf /> PDF
            </a-radio>
            <a-radio value="csv">
              <icon-file /> CSV
            </a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 报表预览弹窗 -->
    <a-modal
      v-model:visible="previewModalVisible"
      :title="currentReport?.name"
      width="90%"
      :footer="false"
    >
      <div v-if="currentReport" class="report-preview">
        <div class="report-header">
          <h2>{{ currentReport.name }}</h2>
          <p>生成时间: {{ currentReport.created_at }}</p>
        </div>
        <div class="report-content">
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="报表类型">
              {{ getTypeName(currentReport.type) }}
            </a-descriptions-item>
            <a-descriptions-item label="时间范围">
              {{ currentReport.date_range }}
            </a-descriptions-item>
            <a-descriptions-item label="数据条数">
              {{ currentReport.data_count }}
            </a-descriptions-item>
            <a-descriptions-item label="文件大小">
              {{ currentReport.file_size }}
            </a-descriptions-item>
          </a-descriptions>
          <div class="report-chart" style="margin-top: 20px">
            <div ref="chartRef" style="width: 100%; height: 400px"></div>
          </div>
        </div>
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed, onMounted } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import * as echarts from 'echarts';

  interface Report {
    id: number;
    name: string;
    type: 'daily' | 'weekly' | 'monthly' | 'custom';
    status: 'pending' | 'completed' | 'failed';
    date_range: string;
    data_count: number;
    file_size: string;
    created_at: string;
  }

  const customModalVisible = ref(false);
  const previewModalVisible = ref(false);
  const currentReport = ref<Report | null>(null);
  const chartRef = ref<HTMLElement>();
  const searchKey = ref('');
  const filterType = ref('');
  const filterStatus = ref('');

  const customForm = ref({
    name: '',
    type: '',
    dateRange: [],
    fields: ['id', 'name', 'amount', 'created_at'],
    format: 'excel',
  });

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '报表名称', dataIndex: 'name', slotName: 'name' },
    { title: '类型', dataIndex: 'type', slotName: 'type', width: 100 },
    { title: '时间范围', dataIndex: 'date_range', width: 200 },
    { title: '数据条数', dataIndex: 'data_count', width: 100 },
    { title: '文件大小', dataIndex: 'file_size', slotName: 'file_size', width: 100 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 120 },
    { title: '生成时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', slotName: 'actions', width: 200, fixed: 'right' },
  ];

  const reports = ref<Report[]>([
    {
      id: 1,
      name: '2026年2月日报',
      type: 'daily',
      status: 'completed',
      date_range: '2026-02-24',
      data_count: 156,
      file_size: '2.3 MB',
      created_at: new Date().toLocaleString(),
    },
    {
      id: 2,
      name: '2026年第8周周报',
      type: 'weekly',
      status: 'completed',
      date_range: '2026-02-17 ~ 2026-02-23',
      data_count: 1024,
      file_size: '5.6 MB',
      created_at: new Date(Date.now() - 86400000).toLocaleString(),
    },
    {
      id: 3,
      name: '2026年2月月报',
      type: 'monthly',
      status: 'pending',
      date_range: '2026-02-01 ~ 2026-02-28',
      data_count: 0,
      file_size: '-',
      created_at: new Date().toLocaleString(),
    },
    {
      id: 4,
      name: '订单统计报表',
      type: 'custom',
      status: 'completed',
      date_range: '2026-01-01 ~ 2026-02-24',
      data_count: 3580,
      file_size: '12.5 MB',
      created_at: new Date(Date.now() - 172800000).toLocaleString(),
    },
  ]);

  const pagination = {
    pageSize: 10,
    showTotal: true,
    showJumper: true,
  };

  const pendingCount = computed(
    () => reports.value.filter((r) => r.status === 'pending').length
  );

  const completedCount = computed(
    () => reports.value.filter((r) => r.status === 'completed').length
  );

  const totalSize = computed(() => {
    const size = reports.value
      .filter((r) => r.status === 'completed')
      .reduce((acc, r) => {
        const match = r.file_size.match(/([\d.]+)\s*(MB|KB)/);
        if (match) {
          const value = parseFloat(match[1]);
          const unit = match[2];
          return acc + (unit === 'MB' ? value : value / 1024);
        }
        return acc;
      }, 0);
    return `${size.toFixed(1)} MB`;
  });

  const filteredReports = computed(() => {
    let list = reports.value;

    if (searchKey.value) {
      const key = searchKey.value.toLowerCase();
      list = list.filter((r) => r.name.toLowerCase().includes(key));
    }

    if (filterType.value) {
      list = list.filter((r) => r.type === filterType.value);
    }

    if (filterStatus.value) {
      list = list.filter((r) => r.status === filterStatus.value);
    }

    return list;
  });

  const getTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      daily: 'arcoblue',
      weekly: 'green',
      monthly: 'orange',
      custom: 'purple',
    };
    return colors[type] || 'gray';
  };

  const getTypeName = (type: string) => {
    const names: Record<string, string> = {
      daily: '日报',
      weekly: '周报',
      monthly: '月报',
      custom: '自定义',
      order: '订单',
      member: '会员',
      finance: '财务',
      warehouse: '仓库',
    };
    return names[type] || type;
  };

  const generateReport = (type: string) => {
    Message.loading('正在生成报表...');
    setTimeout(() => {
      const newReport: Report = {
        id: reports.value.length + 1,
        name: `${getTypeName(type)} - ${new Date().toLocaleDateString()}`,
        type: type as any,
        status: 'completed',
        date_range: new Date().toLocaleDateString(),
        data_count: Math.floor(Math.random() * 1000),
        file_size: `${(Math.random() * 10).toFixed(1)} MB`,
        created_at: new Date().toLocaleString(),
      };
      reports.value.unshift(newReport);
      Message.success('报表生成成功');
    }, 2000);
  };

  const showCustomModal = () => {
    customModalVisible.value = true;
  };

  const handleCustomReport = () => {
    if (!customForm.value.name || !customForm.value.type) {
      Message.warning('请填写完整信息');
      return;
    }
    generateReport('custom');
    customModalVisible.value = false;
  };

  const refreshList = () => {
    Message.success('列表已刷新');
  };

  const initChart = () => {
    if (!chartRef.value) return;
    const chart = echarts.init(chartRef.value);
    chart.setOption({
      title: { text: '数据趋势' },
      tooltip: { trigger: 'axis' },
      xAxis: {
        type: 'category',
        data: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
      },
      yAxis: { type: 'value' },
      series: [
        {
          data: [120, 200, 150, 80, 70, 110, 130],
          type: 'line',
          smooth: true,
          areaStyle: {},
        },
      ],
    });
  };

  const viewReport = (record: Report) => {
    currentReport.value = record;
    previewModalVisible.value = true;
    setTimeout(() => {
      initChart();
    }, 100);
  };

  const downloadReport = (record: Report) => {
    Message.success(`正在下载 ${record.name}`);
  };

  const deleteReport = (record: Report) => {
    Modal.confirm({
      title: '确认删除',
      content: `确定要删除报表 "${record.name}" 吗？`,
      onOk: () => {
        const index = reports.value.findIndex((r) => r.id === record.id);
        if (index > -1) {
          reports.value.splice(index, 1);
          Message.success('删除成功');
        }
      },
    });
  };
</script>

<style scoped lang="less">
  .container {
    padding: 20px;
  }

  .stat-row {
    margin-bottom: 16px;
  }

  .stat-card {
    border-radius: 8px;
    background: var(--color-bg-2);

    :deep(.arco-card-body) {
      padding: 16px;
    }
  }

  .stat-content {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .stat-icon {
    width: 48px;
    height: 48px;
    border-radius: 10px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 24px;

    &.blue {
      background: linear-gradient(135deg, #e6f4ff 0%, #bae0ff 100%);
      color: #1677ff;
    }

    &.orange {
      background: linear-gradient(135deg, #fff7e6 0%, #ffd591 100%);
      color: #fa8c16;
    }

    &.green {
      background: linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%);
      color: #52c41a;
    }

    &.purple {
      background: linear-gradient(135deg, #f9f0ff 0%, #efdbff 100%);
      color: #722ed1;
    }
  }

  .stat-info {
    flex: 1;
  }

  .stat-value {
    font-size: 24px;
    font-weight: 600;
    color: var(--color-text-1);
    line-height: 1.2;
  }

  .stat-label {
    font-size: 13px;
    color: var(--color-text-3);
    margin-top: 4px;
  }

  .quick-actions-row {
    margin-bottom: 16px;
  }

  .quick-actions-card {
    border-radius: 8px;
    background: linear-gradient(135deg, rgba(var(--arcoblue-1), 0.5) 0%, rgba(var(--arcoblue-2), 0.3) 100%);

    :deep(.arco-card-body) {
      padding: 16px 20px;
    }
  }

  .quick-actions-content {
    display: flex;
    align-items: center;
    gap: 24px;
  }

  .quick-actions-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 15px;
    font-weight: 600;
    color: var(--color-text-1);
    white-space: nowrap;

    :deep(.arco-icon) {
      font-size: 18px;
      color: rgb(var(--arcoblue-6));
    }
  }

  .report-list-card {
    border-radius: 8px;

    :deep(.arco-card-header) {
      padding: 16px 20px;
      border-bottom: 1px solid var(--color-border-2);
    }

    :deep(.arco-card-body) {
      padding: 0;
    }
  }

  .card-header {
    display: flex;
    align-items: center;
    gap: 12px;
  }

  .header-title {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 16px;
    font-weight: 600;
    color: var(--color-text-1);

    .header-icon {
      font-size: 20px;
      color: rgb(var(--arcoblue-6));
    }
  }

  .report-table {
    :deep(.arco-table-th) {
      background: var(--color-fill-2);
      font-weight: 600;
    }

    :deep(.arco-table-cell) {
      padding: 12px 16px;
    }

    :deep(.arco-table-td) {
      border-bottom: 1px solid var(--color-border-2);
    }

    :deep(.arco-table-tr:last-child .arco-table-td) {
      border-bottom: none;
    }
  }

  .report-name-cell {
    display: flex;
    align-items: center;
    gap: 8px;

    .file-icon {
      font-size: 16px;
      color: rgb(var(--arcoblue-6));
    }

    .report-name {
      color: var(--color-text-1);
    }
  }

  .file-size {
    color: var(--color-text-3);
    font-size: 13px;
  }

  .spin {
    animation: spin 1s linear infinite;
  }

  @keyframes spin {
    from {
      transform: rotate(0deg);
    }
    to {
      transform: rotate(360deg);
    }
  }

  .report-preview {
    .report-header {
      text-align: center;
      margin-bottom: 20px;

      h2 {
        margin: 0;
        font-size: 20px;
      }

      p {
        margin: 8px 0 0;
        color: var(--color-text-3);
        font-size: 12px;
      }
    }
  }
</style>
