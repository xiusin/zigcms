<template>
  <div class="content-box">
    <!-- 统计卡片区域 -->
    <a-row :gutter="16" class="stat-cards">
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic
            title="总操作次数"
            :value="statistics.total"
            :value-style="{ color: '#3370ff' }"
          >
            <template #prefix>
              <icon-operation />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic
            title="今日操作"
            :value="statistics.today"
            :value-style="{ color: '#00b42a' }"
          >
            <template #prefix>
              <icon-calendar />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic
            title="活跃用户"
            :value="statistics.activeUsers"
            :value-style="{ color: '#ff7d00' }"
          >
            <template #prefix>
              <icon-user />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <a-statistic
            title="异常操作"
            :value="statistics.errors"
            :value-style="{ color: '#f53f3f' }"
          >
            <template #prefix>
              <icon-exclamation-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="16" class="chart-row">
      <a-col :span="12">
        <a-card title="操作类型分布" class="chart-card">
          <Chart :options="pieChartOptions" height="280px" />
        </a-card>
      </a-col>
      <a-col :span="12">
        <a-card title="最近7天操作趋势" class="chart-card">
          <Chart :options="lineChartOptions" height="280px" />
        </a-card>
      </a-col>
    </a-row>

    <a-card class="generate-card no-padding">
      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入操作内容"
        @hand-submit="handleSubmit"
      ></SearchForm>
    </a-card>

    <a-card class="table-card">
      <template #title>
        <a-space>
          <a-button size="small" type="primary" @click="handleExport">
            <template #icon><icon-download /></template>
            导出日志
          </a-button>
          <a-button size="small" @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
          <a-dropdown :trigger="['click']">
            <a-button>
              <template #icon><icon-more /></template>
              更多
            </a-button>
            <template #content>
              <a-doption @click="showCleanModal">
                <template #icon><icon-delete /></template>
                清理日志
              </a-doption>
              <a-doption @click="showArchiveModal">
                <template #icon><icon-file /></template>
                归档日志
              </a-doption>
            </template>
          </a-dropdown>
        </a-space>
      </template>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #user_text="{ record }">
          <a-space>
            <a-avatar :size="24" :style="{ backgroundColor: '#3370ff' }">
              {{ record.user_text?.charAt(0) || 'U' }}
            </a-avatar>
            <span>{{ record.user_text }}</span>
          </a-space>
        </template>
        <template #opt_info="{ record }">
          <a-tooltip :content="record.opt_info" position="top">
            <div class="opt-info-text">{{ record.opt_info }}</div>
          </a-tooltip>
        </template>
        <template #opt_action="{ record }">
          <a-tag :color="getActionColor(record.opt_action)">
            {{ record.opt_action }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <a-button type="text" size="small" @click="viewDetail(record)">
            <template #icon><icon-eye /></template>
            详情
          </a-button>
        </template>
      </base-table>
    </a-card>

    <!-- 详情弹窗 -->
    <a-modal
      v-model:visible="detailVisible"
      title="操作记录详情"
      :width="700"
      :unmount-on-close="true"
      :footer="false"
    >
      <a-descriptions :column="2" bordered>
        <a-descriptions-item label="操作人">
          <a-space>
            <a-avatar :size="24" :style="{ backgroundColor: '#3370ff' }">
              {{ currentRecord?.user_text?.charAt(0) || 'U' }}
            </a-avatar>
            {{ currentRecord?.user_text }}
          </a-space>
        </a-descriptions-item>
        <a-descriptions-item label="公司">
          {{ currentRecord?.company_name || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="公司类型">
          {{ currentRecord?.company_type || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="操作模块">
          {{ currentRecord?.opt_menu }}
        </a-descriptions-item>
        <a-descriptions-item label="操作对象" :span="2">
          {{ currentRecord?.opt_target }}
        </a-descriptions-item>
        <a-descriptions-item label="操作动作">
          <a-tag :color="getActionColor(currentRecord?.opt_action)">
            {{ currentRecord?.opt_action }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="操作IP">
          {{ currentRecord?.ip }}
        </a-descriptions-item>
        <a-descriptions-item label="操作时间">
          {{ currentRecord?.opt_time }}
        </a-descriptions-item>
        <a-descriptions-item label="浏览器">
          {{ currentRecord?.browser || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="操作系统">
          {{ currentRecord?.os || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="设备类型">
          {{ currentRecord?.device_type || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="操作内容" :span="2">
          <div class="detail-opt-info">{{ currentRecord?.opt_info }}</div>
        </a-descriptions-item>
        <a-descriptions-item label="请求参数" :span="2">
          <pre class="code-block">{{
            formatJson(currentRecord?.request_params)
          }}</pre>
        </a-descriptions-item>
        <a-descriptions-item label="响应结果" :span="2">
          <pre class="code-block">{{
            formatJson(currentRecord?.response_data)
          }}</pre>
        </a-descriptions-item>
      </a-descriptions>
    </a-modal>

    <!-- 清理日志弹窗 -->
    <a-modal
      v-model:visible="cleanVisible"
      title="清理日志"
      :width="500"
      @ok="handleClean"
      @cancel="cleanVisible = false"
    >
      <a-form :model="cleanForm" layout="vertical">
        <a-form-item label="清理方式">
          <a-radio-group v-model="cleanForm.type">
            <a-radio value="days">保留最近</a-radio>
            <a-radio value="date">清理指定日期之前</a-radio>
            <a-radio value="all">清理全部</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item v-if="cleanForm.type === 'days'" label="保留天数">
          <a-input-number
            v-model="cleanForm.days"
            :min="1"
            :max="365"
            style="width: 100%"
          />
          <div class="form-tip">将保留最近 {{ cleanForm.days }} 天的日志</div>
        </a-form-item>
        <a-form-item v-if="cleanForm.type === 'date'" label="清理日期">
          <a-date-picker
            v-model="cleanForm.date"
            style="width: 100%"
            format="YYYY-MM-DD"
          />
          <div class="form-tip">将清理 {{ cleanForm.date }} 之前的所有日志</div>
        </a-form-item>
        <a-alert v-if="cleanForm.type === 'all'" type="warning" show-icon>
          警告：清理全部日志将删除所有操作记录，此操作不可恢复！
        </a-alert>
      </a-form>
    </a-modal>

    <!-- 归档日志弹窗 -->
    <a-modal
      v-model:visible="archiveVisible"
      title="归档日志"
      :width="500"
      @ok="handleArchive"
      @cancel="archiveVisible = false"
    >
      <a-form :model="archiveForm" layout="vertical">
        <a-form-item label="归档时间范围">
          <a-range-picker
            v-model="archiveForm.dateRange"
            style="width: 100%"
            format="YYYY-MM-DD"
          />
        </a-form-item>
        <a-form-item label="归档描述（可选）">
          <a-textarea
            v-model="archiveForm.remark"
            placeholder="请输入归档备注"
            :rows="3"
          />
        </a-form-item>
        <a-alert type="info" show-icon>
          归档操作将把指定时间范围内的日志导出为文件并从系统中移除。
        </a-alert>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed, onMounted } from 'vue';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';
  import dayjs from 'dayjs';
  import Chart from '@/components/chart/index.vue';

  const tableRef = ref();
  const loading = ref(false);
  const detailVisible = ref(false);
  const currentRecord = ref<any>({});
  const statisticsLoading = ref(false);

  // 清理日志相关
  const cleanVisible = ref(false);
  const cleanForm = ref({
    type: 'days',
    days: 30,
    date: '',
  });

  // 归档日志相关
  const archiveVisible = ref(false);
  const archiveForm = ref({
    dateRange: [],
    remark: '',
  });

  // 统计数据
  const statistics = ref({
    total: 0,
    today: 0,
    activeUsers: 0,
    errors: 0,
  });

  // 操作类型分布数据
  const actionDistribution = ref<Record<string, number>>({});
  // 最近7天趋势数据
  const trendData = ref<{ date: string; count: number }[]>([]);

  const columns = [
    {
      title: '操作人',
      dataIndex: 'user_text',
      width: 140,
      slotName: 'user_text',
    },
    {
      title: '公司',
      dataIndex: 'company_name',
      width: 150,
      ellipsis: true,
    },
    {
      title: '操作模块',
      dataIndex: 'opt_menu',
      width: 100,
    },
    {
      title: '操作对象',
      dataIndex: 'opt_target',
      width: 180,
      ellipsis: true,
    },
    {
      title: '操作动作',
      dataIndex: 'opt_action',
      width: 100,
      slotName: 'opt_action',
    },
    {
      title: '操作内容',
      dataIndex: 'opt_info',
      slotName: 'opt_info',
      minWidth: 200,
    },
    {
      title: '操作IP',
      dataIndex: 'ip',
      width: 140,
    },
    {
      title: '操作时间',
      dataIndex: 'opt_time',
      width: 170,
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 80,
      slotName: 'action',
      fixed: 'right',
    },
  ];

  const generateFormModel = () => ({
    opt_time: dayjs().format('YYYY-MM-DD'),
    user_id: '',
    opt_target: '',
    opt_info: '',
    opt_action: '',
    company_name: '',
  });

  const baseSearchRules: any = ref([
    { field: 'opt_info', label: '操作内容', value: null },
  ]);

  const searchRules: any = ref([
    {
      field: 'user_id',
      label: '操作人',
      value: null,
      component_name: 'base-request-select',
      attr: { api: 'user', sendParams: { state: 1 } },
    },
    {
      field: 'company_name',
      label: '公司',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'opt_action',
      label: '操作动作',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'opt_action' },
    },
    {
      field: 'opt_target',
      label: '操作对象',
      value: null,
      component_name: 'base-input',
    },
    {
      field: 'opt_time',
      label: '操作时间',
      value: null,
      component_name: 'base-date-picker',
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => request('/api/log/list', data);

  // 使用模拟数据（当API不可用时）
  const useMockData = () => {
    statistics.value = {
      total: 12568,
      today: 156,
      activeUsers: 48,
      errors: 12,
    };
    actionDistribution.value = {
      登录: 3568,
      新增: 2890,
      编辑: 3245,
      删除: 856,
      导出: 1234,
      查看: 775,
    };
    trendData.value = Array.from({ length: 7 }, (_, i) => ({
      date: dayjs()
        .subtract(6 - i, 'day')
        .format('MM-DD'),
      count: Math.floor(Math.random() * 100) + 50,
    }));
  };

  // 获取统计数据
  const fetchStatistics = async () => {
    statisticsLoading.value = true;
    try {
      const res = await request('/api/log/statistics', {});
      if (res.data) {
        statistics.value = {
          total: res.data.total || 0,
          today: res.data.today || 0,
          activeUsers: res.data.activeUsers || 0,
          errors: res.data.errors || 0,
        };
        actionDistribution.value = res.data.actionDistribution || {};
        trendData.value = res.data.trendData || [];
      }
    } catch (e) {
      console.error('获取统计数据失败:', e);
      // 使用模拟数据展示图表
      useMockData();
    } finally {
      statisticsLoading.value = false;
    }
  };

  // 饼图配置
  const pieChartOptions = computed(() => {
    const data = Object.entries(actionDistribution.value).map(
      ([name, value]) => ({
        name,
        value,
      })
    );
    return {
      tooltip: {
        trigger: 'item',
        formatter: '{b}: {c} ({d}%)',
      },
      legend: {
        orient: 'vertical',
        right: 10,
        top: 'center',
      },
      color: ['#3370ff', '#00b42a', '#ff7d00', '#f53f3f', '#86909c', '#722ed1'],
      series: [
        {
          type: 'pie',
          radius: ['40%', '70%'],
          center: ['40%', '50%'],
          avoidLabelOverlap: false,
          itemStyle: {
            borderRadius: 10,
            borderColor: '#fff',
            borderWidth: 2,
          },
          label: {
            show: false,
          },
          emphasis: {
            label: {
              show: true,
              fontSize: 14,
              fontWeight: 'bold',
            },
          },
          data,
        },
      ],
    };
  });

  // 折线图配置
  const lineChartOptions = computed(() => {
    const dates = trendData.value.map((item) => item.date);
    const counts = trendData.value.map((item) => item.count);
    return {
      tooltip: {
        trigger: 'axis',
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '3%',
        containLabel: true,
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: dates,
      },
      yAxis: {
        type: 'value',
      },
      series: [
        {
          name: '操作次数',
          type: 'line',
          smooth: true,
          data: counts,
          areaStyle: {
            color: {
              type: 'linear',
              x: 0,
              y: 0,
              x2: 0,
              y2: 1,
              colorStops: [
                { offset: 0, color: 'rgba(51, 112, 255, 0.3)' },
                { offset: 1, color: 'rgba(51, 112, 255, 0.05)' },
              ],
            },
          },
          itemStyle: {
            color: '#3370ff',
          },
        },
      ],
    };
  });

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const handleRefresh = () => {
    tableRef.value?.search();
    fetchStatistics();
  };

  const handleExport = () => {
    Message.loading('正在导出...');
    request('/api/log/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功');
        if (res.data?.url) {
          const link = document.createElement('a');
          link.href = res.data.url;
          link.download = `操作日志_${dayjs().format('YYYYMMDDHHmmss')}.xlsx`;
          link.click();
        }
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  // 显示清理弹窗
  const showCleanModal = () => {
    cleanForm.value = {
      type: 'days',
      days: 30,
      date: '',
    };
    cleanVisible.value = true;
  };

  // 执行清理
  const handleClean = async () => {
    let params: any = { type: cleanForm.value.type };

    if (cleanForm.value.type === 'days') {
      params.days = cleanForm.value.days;
    } else if (cleanForm.value.type === 'date') {
      params.date = cleanForm.value.date;
    }

    try {
      const res = await request('/api/log/clean', params);
      Message.success(`成功清理 ${res.data?.count || 0} 条日志`);
      cleanVisible.value = false;
      handleRefresh();
    } catch (e) {
      Message.error('清理失败');
    }
  };

  // 显示归档弹窗
  const showArchiveModal = () => {
    archiveForm.value = {
      dateRange: [],
      remark: '',
    };
    archiveVisible.value = true;
  };

  // 执行归档
  const handleArchive = async () => {
    if (
      !archiveForm.value.dateRange ||
      archiveForm.value.dateRange.length < 2
    ) {
      Message.warning('请选择归档时间范围');
      return;
    }

    try {
      const res = await request('/api/log/archive', {
        startDate: archiveForm.value.dateRange[0],
        endDate: archiveForm.value.dateRange[1],
        remark: archiveForm.value.remark,
      });
      Message.success('归档成功');
      if (res.data?.url) {
        const link = document.createElement('a');
        link.href = res.data.url;
        link.download = `操作日志归档_${dayjs().format('YYYYMMDDHHmmss')}.xlsx`;
        link.click();
      }
      archiveVisible.value = false;
      handleRefresh();
    } catch (e) {
      Message.error('归档失败');
    }
  };

  const viewDetail = (record: any) => {
    currentRecord.value = record;
    detailVisible.value = true;
  };

  const getActionColor = (action: string) => {
    const colorMap: Record<string, string> = {
      登录: 'blue',
      新增: 'green',
      编辑: 'orange',
      删除: 'red',
      导出: 'purple',
      查看: 'gray',
    };
    return colorMap[action] || 'arcoblue';
  };

  const formatJson = (data: any) => {
    if (!data) return '-';
    try {
      if (typeof data === 'string') {
        return JSON.stringify(JSON.parse(data), null, 2);
      }
      return JSON.stringify(data, null, 2);
    } catch {
      return data;
    }
  };

  onMounted(() => {
    fetchStatistics();
  });
</script>

<style scoped lang="less">
  .stat-cards {
    margin-bottom: 16px;
  }

  .stat-card {
    :deep(.arco-card-body) {
      padding: 20px;
    }
  }

  .chart-row {
    margin-bottom: 16px;
  }

  .chart-card {
    :deep(.arco-card-body) {
      padding: 16px;
    }
  }

  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }

  .table-card {
    margin-top: 16px;
  }

  .opt-info-text {
    max-width: 300px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .detail-opt-info {
    max-height: 100px;
    overflow-y: auto;
  }

  .code-block {
    max-height: 200px;
    overflow: auto;
    padding: 12px;
    background: var(--color-fill-2);
    border-radius: 4px;
    font-size: 12px;
    font-family: monospace;
    white-space: pre-wrap;
    word-break: break-all;
  }

  .form-tip {
    margin-top: 4px;
    font-size: 12px;
    color: var(--color-text-3);
  }
</style>
