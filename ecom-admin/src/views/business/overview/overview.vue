<template>
  <div class="content-box">
    <!-- 数据概览标题 -->
    <div class="section-title">
      <span>数据概览</span>
    </div>

    <!-- 主内容区域：左侧（统计卡片+销售趋势）和右侧（订单占比） -->
    <a-row :gutter="[16, 16]" class="main-content-row">
      <!-- 左侧容器：统计卡片 + 销售趋势 -->
      <a-col :xs="24" :lg="16">
        <a-card class="left-container" :bordered="false">
          <!-- 统计卡片区域 -->
          <a-row :gutter="[16, 16]" class="stats-row">
            <a-col
              v-for="item in statsCards"
              :key="item.key"
              :xs="12"
              :sm="12"
              :md="6"
            >
              <div class="stat-item">
                <div class="stat-icon-box" :style="{ background: item.bgColor }">
                  <component :is="item.icon" :style="{ color: item.iconColor }" />
                </div>
                <div class="stat-info-simple">
                  <div class="stat-label-simple">{{ item.label }}</div>
                  <div class="stat-value-simple">{{ item.value }}</div>
                </div>
              </div>
            </a-col>
          </a-row>

          <!-- 销售趋势图表 -->
          <div class="trend-chart-section">
            <div class="chart-header">
              <div class="chart-title">销售趋势</div>
              <a-radio-group v-model="trendType" type="button" size="small">
                <a-radio value="week">近7天</a-radio>
                <a-radio value="month">近30天</a-radio>
                <a-radio value="year">近一年</a-radio>
              </a-radio-group>
            </div>
            <div ref="trendChartRef" class="trend-chart-container"></div>
          </div>
        </a-card>
      </a-col>

      <!-- 右侧：订单占比 + 业务指标 -->
      <a-col :xs="24" :lg="8">
        <a-card class="chart-card" :bordered="false">
          <a-tabs v-model:active-key="rightChartTab" class="chart-tabs" @change="handleTabChange">
            <a-tab-pane key="pie" title="订单占比">
              <div ref="pieChartRef" class="pie-chart-container"></div>
            </a-tab-pane>
            <a-tab-pane key="radar" title="业务指标">
              <div ref="radarChartRef" class="radar-chart-container"></div>
            </a-tab-pane>
          </a-tabs>
        </a-card>
      </a-col>
    </a-row>

    <!-- 底部指标卡片 -->
    <a-row :gutter="[16, 16]" class="metric-cards">
      <a-col :xs="12" :sm="12" :md="6" v-for="(item, index) in metricCards" :key="index">
        <a-card class="metric-card" :bordered="false">
          <div class="metric-header">
            <div class="metric-icon-box" :style="{ background: item.bgColor }">
              <component :is="item.icon" :style="{ color: item.iconColor }" />
            </div>
            <span class="metric-name">{{ item.name }}</span>
          </div>
          <div class="metric-value">{{ item.value }}</div>
          <div :ref="el => { if (el) sparklineRefs[index] = el }" class="sparkline-chart"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 详细数据表格 -->
    <a-card class="table-card" :bordered="false">
      <template #title>
        <div class="table-header">
          <span>实时订单</span>
          <a-tag color="arcoblue" size="small">{{ tableTotal }} 个订单</a-tag>
        </div>
      </template>
      <template #extra>
        <a-space>
          <a-button type="primary" size="small">
            <template #icon>
              <icon-download />
            </template>
            导出数据
          </a-button>
          <a-button size="small" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </template>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :no-pagination="true"
      >
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)" size="small">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <a-link @click="viewDetail(record)">查看详情</a-link>
        </template>
      </base-table>
    </a-card>
  </div>
</template>

<script setup lang="ts">
  import { ref, onMounted, reactive, computed } from 'vue';
  import { useRouter } from 'vue-router';
  import request from '@/api/request';
  import * as echarts from 'echarts';

  const router = useRouter();

  const loading = ref(false);
  const trendType = ref('week');
  const rightChartTab = ref('pie');
  const trendChartRef = ref();
  const pieChartRef = ref();
  const radarChartRef = ref();
  const tableRef = ref();
  const sparklineRefs = ref<any[]>([]);
  const sparklineCharts = ref<any[]>([]);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };

  // 顶部统计卡片 - 参考图2风格：浅色背景图标+大数字
  const statsCards = reactive([
    {
      key: 'users',
      label: '用户数',
      value: '1,902',
      icon: 'IconUser',
      iconColor: '#fa8c16',
      bgColor: '#fff7e6',
    },
    {
      key: 'conversations',
      label: '总对话数',
      value: '2,445',
      icon: 'IconMessage',
      iconColor: '#13c2c2',
      bgColor: '#e6fffb',
    },
    {
      key: 'copied',
      label: '被复制对话数',
      value: '3,034',
      icon: 'IconCopy',
      iconColor: '#1677ff',
      bgColor: '#e6f4ff',
    },
    {
      key: 'likes',
      label: '点赞数',
      value: '1,275',
      icon: 'IconThumbUp',
      iconColor: '#722ed1',
      bgColor: '#f9f0ff',
    },
  ]);

  // 底部指标卡片
  const metricCards = reactive([
    {
      name: '对话满意度趋势',
      value: '2,270',
      icon: 'IconRobot',
      bgColor: '#e6f4ff',
      iconColor: '#1677ff',
      sparkColor: '#1677ff',
      data: [30, 45, 35, 50, 40, 55, 45],
    },
    {
      name: '用户消费趋势',
      value: '1,119',
      icon: 'IconUserGroup',
      bgColor: '#f6ffed',
      iconColor: '#52c41a',
      sparkColor: '#52c41a',
      data: [40, 30, 45, 35, 50, 40, 45],
    },
    {
      name: '用户分享趋势',
      value: '1,455',
      icon: 'IconShareInternal',
      bgColor: '#fff7e6',
      iconColor: '#fa8c16',
      sparkColor: '#fa8c16',
      data: [35, 40, 30, 45, 35, 50, 40],
    },
    {
      name: '用户增长量',
      value: '2,330',
      icon: 'IconUserAdd',
      bgColor: '#f9f0ff',
      iconColor: '#722ed1',
      sparkColor: '#722ed1',
      data: [25, 35, 40, 30, 45, 35, 50],
    },
  ]);

  const columns = [
    { title: '订单编号', dataIndex: 'order_no', width: 180 },
    { title: '商品名称', dataIndex: 'product_name' },
    { title: '会员名称', dataIndex: 'member_name', width: 120 },
    { title: '订单金额', dataIndex: 'total_amount', width: 120 },
    { title: '支付方式', dataIndex: 'pay_type', width: 100 },
    { title: '订单状态', dataIndex: 'status', width: 100, slotName: 'status' },
    { title: '下单时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', dataIndex: 'action', width: 100, slotName: 'action' },
  ];

  const getDataList = (data: any) => {
    return request('/api/business/overview/orderList', data);
  };

  const getStatusColor = (status: number) => {
    const colors = ['red', 'orange', 'green', 'blue', 'gray'];
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = ['待支付', '已支付', '已完成', '已取消', '已退款'];
    return texts[status] || '未知';
  };

  const viewDetail = (record: any) => {
    router.push({
      path: '/business/order',
      query: { orderId: record.id },
    });
  };

  // 初始化迷你折线图
  const initSparklines = () => {
    metricCards.forEach((item, index) => {
      const el = sparklineRefs.value[index];
      if (!el) return;
      
      const chart = echarts.init(el);
      const option = {
        grid: {
          left: 0,
          right: 0,
          top: 5,
          bottom: 5,
        },
        xAxis: {
          type: 'category',
          show: false,
          data: ['1', '2', '3', '4', '5', '6', '7'],
        },
        yAxis: {
          type: 'value',
          show: false,
        },
        series: [
          {
            type: 'line',
            smooth: true,
            symbol: 'none',
            lineStyle: {
              width: 2,
              color: item.sparkColor,
            },
            areaStyle: {
              color: new (echarts as any).graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: item.sparkColor + '40' },
                { offset: 1, color: item.sparkColor + '05' },
              ]),
            },
            data: item.data,
          },
        ],
      };
      chart.setOption(option);
      sparklineCharts.value.push(chart);
    });
  };

  // 初始化趋势图表 - 参考图风格：柔和的面积图
  const initTrendChart = () => {
    if (!trendChartRef.value) return;
    const chart = echarts.init(trendChartRef.value);
    const option = {
      tooltip: {
        trigger: 'axis',
        backgroundColor: 'rgba(255, 255, 255, 0.95)',
        borderColor: '#f0f0f0',
        borderWidth: 1,
        textStyle: { color: '#333' },
        extraCssText: 'box-shadow: 0 4px 12px rgba(0,0,0,0.1);',
      },
      legend: {
        data: ['订单数', '销售额', '转化率', '访问量'],
        bottom: 0,
        icon: 'circle',
        itemGap: 20,
      },
      grid: {
        left: '2%',
        right: '2%',
        bottom: '12%',
        top: '5%',
        containLabel: true,
      },
      xAxis: {
        type: 'category',
        boundaryGap: false,
        data: ['12.10', '12.11', '12.12', '12.13', '12.14', '12.15', '12.16', '12.17'],
        axisLine: { show: false },
        axisTick: { show: false },
        axisLabel: { color: '#999', fontSize: 12 },
      },
      yAxis: {
        type: 'value',
        axisLine: { show: false },
        axisTick: { show: false },
        splitLine: {
          show: false,
        },
        axisLabel: { color: '#999', fontSize: 12 },
      },
      series: [
        {
          name: '订单数',
          type: 'line',
          smooth: true,
          symbol: 'none',
          lineStyle: { width: 2, color: '#1677ff' },
          areaStyle: {
            color: new (echarts as any).graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(22, 119, 255, 0.2)' },
              { offset: 1, color: 'rgba(22, 119, 255, 0.02)' },
            ]),
          },
          data: [8200, 9320, 9010, 14340, 12900, 13300, 13200, 12500],
        },
        {
          name: '销售额',
          type: 'line',
          smooth: true,
          symbol: 'none',
          lineStyle: { width: 2, color: '#13c2c2' },
          areaStyle: {
            color: new (echarts as any).graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(19, 194, 194, 0.2)' },
              { offset: 1, color: 'rgba(19, 194, 194, 0.02)' },
            ]),
          },
          data: [6200, 7320, 7010, 10340, 9900, 10300, 10200, 9500],
        },
        {
          name: '转化率',
          type: 'line',
          smooth: true,
          symbol: 'none',
          lineStyle: { width: 2, color: '#fa8c16' },
          areaStyle: {
            color: new (echarts as any).graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(250, 140, 22, 0.2)' },
              { offset: 1, color: 'rgba(250, 140, 22, 0.02)' },
            ]),
          },
          data: [4200, 5320, 5010, 6340, 5900, 6300, 6200, 5500],
        },
        {
          name: '访问量',
          type: 'line',
          smooth: true,
          symbol: 'none',
          lineStyle: { width: 2, color: '#722ed1' },
          areaStyle: {
            color: new (echarts as any).graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(114, 46, 209, 0.2)' },
              { offset: 1, color: 'rgba(114, 46, 209, 0.02)' },
            ]),
          },
          data: [2200, 3320, 3010, 4340, 3900, 4300, 4200, 3500],
        },
      ],
    };
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
  };

  // 初始化饼图
  const initPieChart = () => {
    if (!pieChartRef.value) return;
    const chart = echarts.init(pieChartRef.value);
    const option = {
      tooltip: {
        trigger: 'item',
        backgroundColor: 'rgba(255, 255, 255, 0.95)',
        borderColor: '#f0f0f0',
        borderWidth: 1,
        textStyle: { color: '#333' },
        extraCssText: 'box-shadow: 0 4px 12px rgba(0,0,0,0.1);',
      },
      legend: {
        orient: 'vertical',
        right: '5%',
        top: 'center',
        itemGap: 15,
        textStyle: { color: '#666', fontSize: 12 },
      },
      series: [
        {
          type: 'pie',
          radius: ['45%', '70%'],
          center: ['35%', '50%'],
          avoidLabelOverlap: false,
          itemStyle: {
            borderRadius: 8,
            borderColor: '#fff',
            borderWidth: 2,
          },
          label: { show: false },
          emphasis: {
            label: { show: true, fontSize: 14, fontWeight: 'bold' },
          },
          labelLine: { show: false },
          data: [
            { value: 1048, name: '已完成', itemStyle: { color: '#1677ff' } },
            { value: 735, name: '待支付', itemStyle: { color: '#faad14' } },
            { value: 580, name: '已取消', itemStyle: { color: '#ff4d4f' } },
            { value: 484, name: '已退款', itemStyle: { color: '#52c41a' } },
            { value: 300, name: '处理中', itemStyle: { color: '#13c2c2' } },
          ],
        },
      ],
    };
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
  };

  // 初始化雷达图
  const initRadarChart = () => {
    if (!radarChartRef.value) return;
    const chart = echarts.init(radarChartRef.value);
    const option = {
      tooltip: {
        backgroundColor: 'rgba(255, 255, 255, 0.95)',
        borderColor: '#f0f0f0',
        borderWidth: 1,
        textStyle: { color: '#333' },
        extraCssText: 'box-shadow: 0 4px 12px rgba(0,0,0,0.1);',
      },
      legend: {
        data: ['本月指标', '上月指标'],
        bottom: 0,
        icon: 'circle',
        itemGap: 20,
      },
      radar: {
        indicator: [
          { name: '订单转化率', max: 100 },
          { name: '客户满意度', max: 100 },
          { name: '库存周转率', max: 100 },
          { name: '物流时效', max: 100 },
          { name: '售后处理', max: 100 },
          { name: '营销ROI', max: 100 },
        ],
        radius: '65%',
        center: ['50%', '45%'],
        axisName: {
          color: '#666',
          fontSize: 12,
        },
        splitArea: {
          areaStyle: {
            color: ['rgba(22, 119, 255, 0.02)', 'rgba(22, 119, 255, 0.05)'],
          },
        },
        axisLine: {
          lineStyle: { color: 'rgba(0,0,0,0.1)' },
        },
        splitLine: {
          lineStyle: { color: 'rgba(0,0,0,0.1)' },
        },
      },
      series: [
        {
          type: 'radar',
          data: [
            {
              value: [85, 90, 78, 88, 82, 75],
              name: '本月指标',
              areaStyle: {
                color: 'rgba(22, 119, 255, 0.2)',
              },
              lineStyle: {
                color: '#1677ff',
                width: 2,
              },
              itemStyle: {
                color: '#1677ff',
              },
            },
            {
              value: [72, 85, 80, 75, 78, 70],
              name: '上月指标',
              areaStyle: {
                color: 'rgba(19, 194, 194, 0.2)',
              },
              lineStyle: {
                color: '#13c2c2',
                width: 2,
              },
              itemStyle: {
                color: '#13c2c2',
              },
            },
          ],
        },
      ],
    };
    chart.setOption(option);
    window.addEventListener('resize', () => chart.resize());
  };

  // Tab 切换处理
  const handleTabChange = (key: string) => {
    if (key === 'radar') {
      setTimeout(() => {
        initRadarChart();
      }, 100);
    }
  };

  onMounted(() => {
    initTrendChart();
    initPieChart();
    setTimeout(() => {
      initSparklines();
    }, 100);
  });
</script>

<style lang="less" scoped>
  .section-title {
    font-size: 18px;
    font-weight: 600;
    color: var(--color-text-1);
    margin-bottom: 20px;
    padding-left: 4px;
  }

  // 主内容行
  .main-content-row {
    margin-bottom: 8px !important;
  }

  // 左侧容器（统计卡片 + 销售趋势）
  .left-container {
    border-radius: 12px;
    background: #fff;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    height: 100%;

    :deep(.arco-card-body) {
      padding: 24px;
    }

    // 统计卡片行
    .stats-row {
      margin-bottom: 32px;
    }

    .stat-item {
      display: flex;
      align-items: center;
      gap: 16px;
      padding: 8px 0;

      .stat-icon-box {
        width: 48px;
        height: 48px;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 24px;
        flex-shrink: 0;
      }

      .stat-info-simple {
        display: flex;
        flex-direction: column;
        gap: 8px;

        .stat-label-simple {
          font-size: 13px;
          color: var(--color-text-2);
          font-weight: 600;
        }

        .stat-value-simple {
          font-size: 26px;
          font-weight: 700;
          color: var(--color-text-1);
          line-height: 1;
          letter-spacing: -0.5px;
        }
      }
    }

    // 销售趋势图表区域
    .trend-chart-section {
      .chart-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: 16px;

        .chart-title {
          font-size: 15px;
          font-weight: 500;
          color: var(--color-text-1);
        }
      }

      .trend-chart-container {
        height: 360px;
      }
    }
  }

  // 右侧订单占比卡片
  .chart-card {
    border-radius: 12px;
    background: #fff;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);
    height: 100%;

    :deep(.arco-card-header) {
      padding: 24px 24px 16px;
      border-bottom: none;
    }

    :deep(.arco-card-body) {
      padding: 0 24px 24px;
    }

    .chart-title {
      font-size: 15px;
      font-weight: 500;
      color: var(--color-text-1);
    }

    .pie-chart-container {
      height: 400px;
    }

    .radar-chart-container {
      height: 400px;
    }

    // Tab 样式
    :deep(.chart-tabs) {
      .arco-tabs-nav {
        padding: 16px 24px 0;
        margin-bottom: 0;

        &::before {
          display: none;
        }
      }

      .arco-tabs-nav-ink {
        background-color: rgb(var(--arcoblue-6));
        height: 2px;
        bottom: -1px;
      }

      .arco-tabs-tab {
        padding: 8px 0;
        margin: 0 24px 0 0;
        font-size: 14px;
        color: var(--color-text-2);

        &:hover {
          color: rgb(var(--arcoblue-6));
        }
      }

      .arco-tabs-tab-active {
        color: rgb(var(--arcoblue-6));
        font-weight: 500;
      }

      .arco-tabs-content {
        padding: 16px 24px 24px;
      }
    }
  }

  // 底部指标卡片
  .metric-cards {
    margin-top: 0 !important;
    margin-bottom: 8px !important;
  }

  .metric-card {
    border-radius: 12px;
    background: #fff;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);

    :deep(.arco-card-body) {
      padding: 20px;
    }

    .metric-header {
      display: flex;
      align-items: center;
      gap: 10px;
      margin-bottom: 12px;

      .metric-icon-box {
        width: 36px;
        height: 36px;
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 18px;
        flex-shrink: 0;
      }

      .metric-name {
        font-size: 13px;
        color: var(--color-text-2);
        font-weight: 600;
      }
    }

    .metric-value {
      font-size: 20px;
      font-weight: 600;
      color: var(--color-text-1);
      margin-bottom: 12px;
    }

    .sparkline-chart {
      height: 50px;
      width: 100%;
    }
  }

  // 表格卡片
  .table-card {
    border-radius: 12px;
    background: #fff;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.04);

    :deep(.arco-card-header) {
      padding: 16px 20px;
      border-bottom: 1px solid var(--color-border-2);
    }

    :deep(.arco-card-body) {
      padding: 0;
    }

    .table-header {
      display: flex;
      align-items: center;
      gap: 8px;
      font-size: 15px;
      font-weight: 500;
      color: var(--color-text-1);
    }
  }
</style>
