<template>
  <div class="dashboard-container">
    <!-- 欢迎横幅 -->
    <div class="welcome-banner">
      <div class="welcome-content">
        <h1>欢迎回来，管理员 👋</h1>
        <p>今天是 {{ currentDate }}，祝您工作愉快</p>
      </div>
      <div class="quick-actions">
        <a-button type="primary" size="small">
          <template #icon><icon-plus /></template>
          新建订单
        </a-button>
        <a-button size="small">
          <template #icon><icon-user-add /></template>
          添加会员
        </a-button>
        <a-button size="small">
          <template #icon><icon-file /></template>
          查看报表
        </a-button>
      </div>
    </div>

    <!-- KPI 卡片 -->
    <a-row :gutter="16" class="kpi-cards">
      <a-col :xs="24" :sm="12" :md="6">
        <div class="stat-card">
          <div class="stat-header">
            <div class="stat-icon primary">
              <icon-trophy />
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">总收入</div>
            <div class="stat-value"
              >¥{{ formatNumber(metrics.totalRevenue) }}</div
            >
            <div class="stat-trend up">
              <icon-arrow-up /> {{ metrics.revenueGrowth }}% 较上月
            </div>
          </div>
        </div>
      </a-col>

      <a-col :xs="24" :sm="12" :md="6">
        <div class="stat-card">
          <div class="stat-header">
            <div class="stat-icon success">
              <icon-file-text />
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">总订单</div>
            <div class="stat-value">{{
              formatNumber(metrics.totalOrders)
            }}</div>
            <div class="stat-trend up">
              <icon-arrow-up /> {{ metrics.orderGrowth }}% 较上月
            </div>
          </div>
        </div>
      </a-col>

      <a-col :xs="24" :sm="12" :md="6">
        <div class="stat-card">
          <div class="stat-header">
            <div class="stat-icon warning">
              <icon-user-group />
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">总会员</div>
            <div class="stat-value">{{
              formatNumber(metrics.totalMembers)
            }}</div>
            <div class="stat-trend up">
              <icon-arrow-up /> {{ metrics.memberGrowth }}% 较上月
            </div>
          </div>
        </div>
      </a-col>

      <a-col :xs="24" :sm="12" :md="6">
        <div class="stat-card">
          <div class="stat-header">
            <div class="stat-icon danger">
              <icon-fire />
            </div>
          </div>
          <div class="stat-content">
            <div class="stat-label">活跃会员</div>
            <div class="stat-value">{{
              formatNumber(metrics.activeMembers)
            }}</div>
            <div class="stat-trend">
              今日 {{ metrics.todayActive }} 人在线
            </div>
          </div>
        </div>
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <a-col :xs="24" :lg="16">
        <a-card :bordered="false">
          <template #title>
            <a-space>
              <span>收入趋势</span>
              <a-tag color="blue">近7天</a-tag>
            </a-space>
          </template>
          <template #extra>
            <a-radio-group v-model="chartPeriod" type="button" size="small">
              <a-radio value="week">周</a-radio>
              <a-radio value="month">月</a-radio>
              <a-radio value="year">年</a-radio>
            </a-radio-group>
          </template>
          <div ref="revenueChart" style="height: 350px"></div>
        </a-card>
      </a-col>

      <a-col :xs="24" :lg="8">
        <a-card :bordered="false">
          <template #title>订单状态分布</template>
          <div ref="orderChart" style="height: 350px"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 数据表格 -->
    <a-row :gutter="16" style="margin-top: 16px">
      <a-col :xs="24">
        <a-card :bordered="false">
          <template #title>
            <a-space>
              <span>最近订单</span>
              <a-tag color="green">实时更新</a-tag>
            </a-space>
          </template>
          <template #extra>
            <a-link>查看全部 →</a-link>
          </template>
          <a-table
            :data="recentOrders"
            :columns="orderColumns"
            :pagination="false"
            size="small"
          >
            <template #status="{ record }">
              <a-tag :color="getStatusColor(record.status)">
                {{ record.status }}
              </a-tag>
            </template>
            <template #amount="{ record }">
              <span style="font-weight: 500; color: var(--color-primary)">
                ¥{{ record.amount }}
              </span>
            </template>
          </a-table>
        </a-card>
      </a-col>
    </a-row>
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted, computed } from 'vue';
  import * as echarts from 'echarts';

  const chartPeriod = ref('week');

  const currentDate = computed(() => {
    const date = new Date();
    const options: Intl.DateTimeFormatOptions = {
      year: 'numeric',
      month: 'long',
      day: 'numeric',
      weekday: 'long',
    };
    return date.toLocaleDateString('zh-CN', options);
  });

  // KPI 指标
  const metrics = ref({
    totalRevenue: 1234567.89,
    todayRevenue: 12345.67,
    totalOrders: 8765,
    todayOrders: 123,
    totalMembers: 45678,
    activeMembers: 12345,
    todayActive: 567,
    revenueGrowth: 15.8,
    orderGrowth: 12.3,
    memberGrowth: 8.5,
  });

  // 格式化数字
  const formatNumber = (num: number) => {
    return num.toLocaleString('zh-CN', { maximumFractionDigits: 2 });
  };

  // 图表引用
  const revenueChart = ref();
  const orderChart = ref();

  // 最近订单
  const recentOrders = ref([
    {
      id: 1,
      orderNo: 'ORD20240224001',
      member: '张三',
      amount: 299.0,
      status: '已完成',
      createTime: '2024-02-24 10:30:00',
    },
    {
      id: 2,
      orderNo: 'ORD20240224002',
      member: '李四',
      amount: 599.0,
      status: '待发货',
      createTime: '2024-02-24 10:25:00',
    },
    {
      id: 3,
      orderNo: 'ORD20240224003',
      member: '王五',
      amount: 199.0,
      status: '已完成',
      createTime: '2024-02-24 10:20:00',
    },
  ]);

  const orderColumns = [
    { title: '订单号', dataIndex: 'orderNo', width: 180 },
    { title: '会员', dataIndex: 'member', width: 120 },
    { title: '金额', dataIndex: 'amount', slotName: 'amount', width: 120 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 100 },
    { title: '创建时间', dataIndex: 'createTime' },
  ];

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      已完成: 'green',
      待发货: 'orange',
      待支付: 'red',
      已取消: 'gray',
    };
    return colors[status] || 'blue';
  };

  // 初始化图表
  const initCharts = () => {
    // 收入趋势图
    const revenueChartInstance = echarts.init(revenueChart.value);
    revenueChartInstance.setOption({
      tooltip: { trigger: 'axis' },
      grid: { left: 50, right: 20, top: 30, bottom: 30 },
      xAxis: {
        type: 'category',
        data: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
        axisLine: { lineStyle: { color: '#e5e6eb' } },
        axisLabel: { color: '#86909c' },
      },
      yAxis: {
        type: 'value',
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: { lineStyle: { color: '#f2f3f5', type: 'dashed' } },
        axisLabel: { color: '#86909c' },
      },
      series: [
        {
          name: '收入',
          type: 'line',
          smooth: true,
          data: [12000, 15000, 13000, 17000, 16000, 19000, 21000],
          itemStyle: { color: '#6366F1' },
          areaStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(99, 102, 241, 0.3)' },
              { offset: 1, color: 'rgba(99, 102, 241, 0.05)' },
            ]),
          },
        },
      ],
    });

    // 订单状态饼图
    const orderChartInstance = echarts.init(orderChart.value);
    orderChartInstance.setOption({
      tooltip: { trigger: 'item' },
      series: [
        {
          type: 'pie',
          radius: ['40%', '70%'],
          data: [
            { value: 335, name: '已完成', itemStyle: { color: '#10B981' } },
            { value: 234, name: '待发货', itemStyle: { color: '#3B82F6' } },
            { value: 135, name: '待付款', itemStyle: { color: '#F59E0B' } },
            { value: 48, name: '已取消', itemStyle: { color: '#EF4444' } },
          ],
        },
      ],
    });
  };

  onMounted(() => {
    initCharts();
  });
</script>

<style scoped lang="less">
  .dashboard-container {
    background: var(--color-bg-1);
  }

  .welcome-banner {
    background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
    border-radius: 16px;
    padding: 32px;
    margin-bottom: 20px;
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: white;
    box-shadow: 0 8px 24px rgba(102, 126, 234, 0.3);

    .welcome-content {
      h1 {
        font-size: 28px;
        font-weight: 700;
        margin: 0 0 8px;
      }

      p {
        font-size: 14px;
        opacity: 0.9;
        margin: 0;
      }
    }

    .quick-actions {
      display: flex;
      gap: 12px;

      :deep(.arco-btn) {
        background: rgba(255, 255, 255, 0.2);
        border: 1px solid rgba(255, 255, 255, 0.3);
        color: white;
        backdrop-filter: blur(10px);

        &:hover {
          background: rgba(255, 255, 255, 0.3);
          border-color: rgba(255, 255, 255, 0.5);
        }

        &.arco-btn-primary {
          background: white;
          color: #667eea;
          border: none;

          &:hover {
            background: rgba(255, 255, 255, 0.9);
          }
        }
      }
    }
  }

  .kpi-cards {
    margin-bottom: 16px;
  }

  .stat-card {
    background: white;
    border-radius: 16px;
    padding: 24px;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    transition: all 0.3s ease;
    border: 1px solid var(--color-border-1);
    height: 100%;

    &:hover {
      transform: translateY(-4px);
      box-shadow: 0 8px 24px rgba(0, 0, 0, 0.12);
    }

    .stat-header {
      display: flex;
      justify-content: space-between;
      align-items: flex-start;
      margin-bottom: 16px;
    }

    .stat-icon {
      width: 48px;
      height: 48px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      background: linear-gradient(
        135deg,
        var(--gradient-start),
        var(--gradient-end)
      );
      color: white;
      box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);

      &.primary {
        --gradient-start: #667eea;
        --gradient-end: #764ba2;
      }

      &.success {
        --gradient-start: #10b981;
        --gradient-end: #059669;
      }

      &.warning {
        --gradient-start: #f59e0b;
        --gradient-end: #d97706;
      }

      &.danger {
        --gradient-start: #ef4444;
        --gradient-end: #dc2626;
      }
    }

    .stat-content {
      .stat-label {
        font-size: 13px;
        color: var(--color-text-3);
        margin-bottom: 8px;
      }

      .stat-value {
        font-size: 32px;
        font-weight: 700;
        color: var(--color-text-1);
        margin-bottom: 8px;
      }

      .stat-trend {
        font-size: 12px;
        display: flex;
        align-items: center;
        gap: 4px;
        color: var(--color-text-3);

        &.up {
          color: var(--color-success);
        }

        &.down {
          color: var(--color-danger);
        }
      }
    }
  }

  @media (max-width: 768px) {
    .welcome-banner {
      flex-direction: column;
      gap: 20px;
      text-align: center;

      .quick-actions {
        width: 100%;
        flex-direction: column;
      }
    }

    .stat-card {
      margin-bottom: 12px;
    }
  }
</style>
