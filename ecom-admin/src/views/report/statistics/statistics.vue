<template>
  <div class="content-box">
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="statistics-row">
      <a-col :span="6">
        <a-card class="stat-card">
          <div class="stat-item clickable" @click="goToOrder">
            <div
              class="stat-icon"
              style="
                background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
              "
            >
              <icon-shopping-cart :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">
                总订单数
                <a-link><icon-export :size="12" /></a-link>
              </div>
              <div class="stat-value">{{ statistics.total_order }}</div>
              <div class="stat-change">
                <span>较昨日</span>
                <span
                  :class="
                    statistics.today_order >= statistics.yesterday_order
                      ? 'up'
                      : 'down'
                  "
                >
                  {{
                    statistics.today_order >= statistics.yesterday_order
                      ? '+'
                      : ''
                  }}{{
                    calculateGrowth(
                      statistics.today_order,
                      statistics.yesterday_order
                    )
                  }}%
                </span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <div class="stat-item clickable" @click="goToIncome">
            <div
              class="stat-icon"
              style="
                background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
              "
            >
              <icon-money :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">
                总收入(元)
                <a-link><icon-export :size="12" /></a-link>
              </div>
              <div class="stat-value"
                >¥{{ formatMoney(statistics.total_amount) }}</div
              >
              <div class="stat-change">
                <span>较昨日</span>
                <span
                  :class="
                    statistics.today_amount >= statistics.yesterday_amount
                      ? 'up'
                      : 'down'
                  "
                >
                  {{
                    statistics.today_amount >= statistics.yesterday_amount
                      ? '+'
                      : ''
                  }}{{
                    calculateGrowth(
                      statistics.today_amount,
                      statistics.yesterday_amount
                    )
                  }}%
                </span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <div class="stat-item clickable" @click="goToMember">
            <div
              class="stat-icon"
              style="
                background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
              "
            >
              <icon-user :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">
                总会员数
                <a-link><icon-export :size="12" /></a-link>
              </div>
              <div class="stat-value">{{ statistics.total_user }}</div>
              <div class="stat-change">
                <span>较昨日</span>
                <span class="up">+{{ statistics.growth || 0 }}%</span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :span="6">
        <a-card class="stat-card">
          <div class="stat-item clickable" @click="goToMachine">
            <div
              class="stat-icon"
              style="
                background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);
              "
            >
              <icon-user-group :size="24" />
            </div>
            <div class="stat-content">
              <div class="stat-label">
                活跃会员
                <a-link><icon-export :size="12" /></a-link>
              </div>
              <div class="stat-value">{{ statistics.active_user }}</div>
              <div class="stat-change">
                <span>较昨日</span>
                <span class="up">+5.2%</span>
              </div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 筛选条件 -->
    <a-card class="filter-card">
      <div class="filter-bar">
        <a-space>
          <a-radio-group
            v-model="dateType"
            type="button"
            size="small"
            @change="handleDateTypeChange"
          >
            <a-radio value="today">今日</a-radio>
            <a-radio value="yesterday">昨日</a-radio>
            <a-radio value="week">本周</a-radio>
            <a-radio value="month">本月</a-radio>
            <a-radio value="custom">自定义</a-radio>
          </a-radio-group>
          <a-range-picker
            v-if="dateType === 'custom'"
            v-model="dateRange"
            style="width: 240px"
            @change="handleDateRangeChange"
          />
        </a-space>
        <a-space>
          <a-select v-model="groupBy" style="width: 120px" @change="fetchData">
            <a-option value="day">按天</a-option>
            <a-option value="week">按周</a-option>
            <a-option value="month">按月</a-option>
          </a-select>
          <a-button size="small" @click="exportData">
            <template #icon>
              <icon-download />
            </template>
            导出数据
          </a-button>
          <a-button size="small" @click="handleYoY">
            <template #icon>
              <icon-line-chart />
            </template>
            同比分析
          </a-button>
          <a-button size="small" @click="handleMoM">
            <template #icon>
              <icon-bar-chart />
            </template>
            环比分析
          </a-button>
        </a-space>
      </div>
    </a-card>

    <!-- 图表区域 -->
    <a-row :gutter="16">
      <a-col :span="16">
        <a-card class="chart-card">
          <template #title>
            <div class="chart-title">订单趋势</div>
          </template>
          <div ref="orderChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
      <a-col :span="8">
        <a-card class="chart-card">
          <template #title>
            <div class="chart-title">订单占比</div>
          </template>
          <div ref="pieChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
    </a-row>

    <a-row :gutter="16" style="margin-top: 16px">
      <a-col :span="12">
        <a-card class="chart-card">
          <template #title>
            <div class="chart-title">地域分布 TOP10</div>
          </template>
          <div ref="regionChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
      <a-col :span="12">
        <a-card class="chart-card">
          <template #title>
            <div class="chart-title">功能模块使用情况</div>
          </template>
          <div ref="moduleChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 数据表格 -->
    <a-card class="table-card" style="margin-top: 16px">
      <template #title>
        <div class="chart-title">订单明细</div>
      </template>
      <a-tabs v-model="activeTab" @change="fetchTableData">
        <a-tab-pane key="order" title="订单明细" />
        <a-tab-pane key="product" title="商品销售" />
        <a-tab-pane key="region" title="地域数据" />
        <a-tab-pane key="module" title="模块数据" />
      </a-tabs>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="tableColumns"
        :data-config="getTableData"
        :no-pagination="false"
      >
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
      </base-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted, nextTick } from 'vue';
  import request from '@/api/request';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import * as echarts from 'echarts';

  const router = useRouter();

  const dateType = ref('today');
  const dateRange = ref([]);
  const groupBy = ref('day');
  const activeTab = ref('order');
  const loading = ref(false);
  const tableRef = ref();

  const orderChartRef = ref();
  const pieChartRef = ref();
  const regionChartRef = ref();
  const moduleChartRef = ref();

  // 同比环比分析
  const yoyVisible = ref(false);
  const momVisible = ref(false);
  const yoyData = ref<any>({});
  const momData = ref<any>({});

  const statistics = reactive({
    total_order: 12580,
    total_amount: 2580000,
    total_user: 8560,
    today_order: 156,
    today_amount: 28000,
    yesterday_order: 142,
    yesterday_amount: 25000,
    active_user: 3250,
    growth: 9.86,
  });

  const tableColumns = ref<any[]>([
    { title: '订单号', dataIndex: 'order_no', width: 180 },
    { title: '商品名称', dataIndex: 'product_name', ellipsis: true },
    { title: '单价', dataIndex: 'price', width: 100 },
    { title: '数量', dataIndex: 'num', width: 80 },
    { title: '总价', dataIndex: 'total_price', width: 120 },
    { title: '会员', dataIndex: 'user_name', width: 100 },
    { title: '联系方式', dataIndex: 'user_phone', width: 130 },
    { title: '下单时间', dataIndex: 'created_at', width: 180 },
    { title: '状态', dataIndex: 'status', width: 100, slotName: 'status' },
  ]);

  const calculateGrowth = (current: number, previous: number) => {
    if (!previous) return 0;
    return (((current - previous) / previous) * 100).toFixed(2);
  };

  const formatMoney = (value: number) => {
    return value.toLocaleString('zh-CN', { minimumFractionDigits: 2 });
  };

  // 跳转到订单管理
  const goToOrder = () => {
    router.push('/business/order');
  };

  // 跳转到收入管理
  const goToIncome = () => {
    router.push('/business/income');
  };

  // 跳转到会员管理
  const goToMember = () => {
    router.push('/business/member');
  };

  // 跳转到机器管理
  const goToMachine = () => {
    router.push('/business/machine');
  };

  const getStatusColor = (status: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'red', 'purple', 'gray'];
    return colors[status] || 'default';
  };

  const getStatusText = (status: number) => {
    const texts = [
      '',
      '待支付',
      '已支付',
      '已发货',
      '已完成',
      '已取消',
      '已退款',
    ];
    return texts[status] || '未知';
  };

  // 初始化图表
  const initCharts = () => {
    // 订单趋势图
    if (orderChartRef.value) {
      const orderChart = echarts.init(orderChartRef.value);
      orderChart.setOption({
        tooltip: { trigger: 'axis' },
        legend: { data: ['订单数', '金额'] },
        xAxis: {
          type: 'category',
          data: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
        },
        yAxis: [
          { type: 'value', name: '订单数' },
          { type: 'value', name: '金额(元)' },
        ],
        series: [
          {
            name: '订单数',
            type: 'line',
            data: [120, 132, 101, 134, 90, 230, 210],
            smooth: true,
            areaStyle: { opacity: 0.3 },
          },
          {
            name: '金额',
            type: 'line',
            yAxisIndex: 1,
            data: [2200, 1820, 1910, 2340, 2900, 3300, 3200],
            smooth: true,
            areaStyle: { opacity: 0.3 },
          },
        ],
      });
    }

    // 订单占比饼图
    if (pieChartRef.value) {
      const pieChart = echarts.init(pieChartRef.value);
      pieChart.setOption({
        tooltip: { trigger: 'item' },
        series: [
          {
            type: 'pie',
            radius: ['40%', '70%'],
            data: [
              { value: 335, name: '待支付' },
              { value: 310, name: '已支付' },
              { value: 234, name: '已发货' },
              { value: 135, name: '已完成' },
              { value: 154, name: '已取消' },
            ],
          },
        ],
      });
    }

    // 地域分布图
    if (regionChartRef.value) {
      const regionChart = echarts.init(regionChartRef.value);
      regionChart.setOption({
        tooltip: { trigger: 'axis' },
        xAxis: { type: 'value' },
        yAxis: {
          type: 'category',
          data: ['广东', '北京', '上海', '浙江', '江苏'],
        },
        series: [{ type: 'bar', data: [182, 132, 101, 94, 90] }],
      });
    }

    // 模块分布图
    if (moduleChartRef.value) {
      const moduleChart = echarts.init(moduleChartRef.value);
      moduleChart.setOption({
        tooltip: { trigger: 'item' },
        series: [
          {
            type: 'pie',
            radius: ['40%', '70%'],
            data: [
              { value: 1048, name: '商品销售' },
              { value: 735, name: '会员订阅' },
              { value: 580, name: '工具箱' },
              { value: 484, name: '增值服务' },
              { value: 300, name: '其他' },
            ],
          },
        ],
      });
    }
  };

  // 获取统计数据
  const fetchData = () => {
    request('/api/report/statistics', {
      date_type: dateType.value,
      date_range: dateRange.value,
      group_by: groupBy.value,
    }).then((res: any) => {
      if (res.data) {
        Object.assign(statistics, res.data);
      }
      nextTick(() => {
        initCharts();
      });
    });
  };

  const handleDateTypeChange = () => {
    fetchData();
  };

  const handleDateRangeChange = () => {
    fetchData();
  };

  const fetchTableData = () => {
    tableRef.value?.search();
  };

  const getTableData = (data: any) => {
    let api = '/api/report/order/list';
    if (activeTab.value === 'product') api = '/api/report/product/list';
    if (activeTab.value === 'region') api = '/api/report/region/list';
    if (activeTab.value === 'module') api = '/api/report/module/list';
    return request(api, data);
  };

  const exportData = () => {
    Message.success('正在导出数据...');
    request('/api/report/statistics/export', { type: activeTab.value })
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `报表统计_${
          activeTab.value
        }_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  // 同比分析
  const handleYoY = () => {
    yoyVisible.value = true;
    // 计算同比数据
    yoyData.value = {
      current: { label: '本期', value: 156800 },
      lastYear: { label: '去年同期', value: 125600 },
      growth: { label: '同比增长', value: '+24.8%', trend: 'up' },
    };
  };

  // 环比分析
  const handleMoM = () => {
    momVisible.value = true;
    // 计算环比数据
    momData.value = {
      current: { label: '本期', value: 156800 },
      lastPeriod: { label: '上期', value: 142500 },
      growth: { label: '环比增长', value: '+10.0%', trend: 'up' },
    };
  };

  onMounted(() => {
    fetchData();
    window.addEventListener('resize', () => {
      initCharts();
    });
  });
</script>

<style lang="less" scoped>
  .statistics-row {
    margin-bottom: 16px;
  }

  .stat-card {
    :deep(.arco-card-body) {
      padding: 20px;
    }
  }

  .stat-item {
    display: flex;
    align-items: center;
    gap: 16px;

    &.clickable {
      cursor: pointer;
      transition: transform 0.2s;

      &:hover {
        transform: translateY(-2px);
      }
    }

    .stat-icon {
      width: 56px;
      height: 56px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      color: #fff;
    }

    .stat-content {
      flex: 1;

      .stat-label {
        font-size: 14px;
        color: var(--color-text-2);
        margin-bottom: 8px;
        display: flex;
        align-items: center;
        gap: 4px;

        .arco-link {
          font-size: 12px;
        }
      }

      .stat-value {
        font-size: 24px;
        font-weight: 600;
        color: var(--color-text-1);
        margin-bottom: 4px;
      }

      .stat-change {
        font-size: 12px;
        color: var(--color-text-3);

        .up {
          color: #00b42a;
        }

        .down {
          color: #f53f3f;
        }
      }
    }
  }

  .filter-card {
    margin-bottom: 16px;

    .filter-bar {
      display: flex;
      justify-content: space-between;
      align-items: center;
    }
  }

  .chart-card {
    .chart-title {
      font-size: 16px;
      font-weight: 500;
    }

    .chart-container {
      height: 300px;
    }
  }
</style>
