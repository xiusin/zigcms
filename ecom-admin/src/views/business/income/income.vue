<template>
  <div class="content-box">
    <!-- 统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon green">
              <icon-money-circle />
            </div>
            <div class="stat-info">
              <div class="stat-label">今日收入</div>
              <div class="stat-value">¥{{ stats.todayIncome }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon blue">
              <icon-calendar />
            </div>
            <div class="stat-info">
              <div class="stat-label">本月收入</div>
              <div class="stat-value">¥{{ stats.monthIncome }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon purple">
              <icon-history />
            </div>
            <div class="stat-info">
              <div class="stat-label">总收入</div>
              <div class="stat-value">¥{{ stats.totalIncome }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon orange">
              <icon-user />
            </div>
            <div class="stat-info">
              <div class="stat-label">付费用户</div>
              <div class="stat-value">{{ stats.paidUser }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 图表区域 -->
    <a-row :gutter="[16, 16]" class="chart-row">
      <a-col :xs="24" :lg="16">
        <a-card>
          <template #title>
            <div class="chart-header">
              <span>收入趋势</span>
              <a-radio-group v-model="trendType" type="button" size="small" @change="updateTrendChart">
                <a-radio value="week">近7天</a-radio>
                <a-radio value="month">近30天</a-radio>
                <a-radio value="year">近一年</a-radio>
              </a-radio-group>
            </div>
          </template>
          <div ref="trendChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
      <a-col :xs="24" :lg="8">
        <a-card>
          <template #title>
            <div class="chart-header">
              <span>收入来源</span>
              <a-select
                v-model="sourceType"
                size="small"
                style="width: 100px"
                @change="updateSourceChart"
              >
                <a-option value="type">收入类型</a-option>
                <a-option value="platform">平台来源</a-option>
                <a-option value="channel">支付渠道</a-option>
                <a-option value="region">地区分布</a-option>
              </a-select>
            </div>
          </template>
          <div ref="sourceChartRef" class="chart-container"></div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 地域分析 -->
    <a-row :gutter="[16, 16]" class="chart-row">
      <a-col :span="24">
        <a-card>
          <template #title>
            <div class="chart-header">
              <span>地域热力分析</span>
              <a-radio-group v-model="regionType" type="button" size="small" @change="updateRegionChart">
                <a-radio value="income">收入热力</a-radio>
                <a-radio value="order">订单热力</a-radio>
                <a-radio value="user">用户热力</a-radio>
              </a-radio-group>
            </div>
          </template>
          <div ref="regionChartRef" class="region-chart-container"></div>
        </a-card>
      </a-col>
    </a-row>

    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>收入明细</span>
          <a-tag color="blue">{{ tableTotal }} 条记录</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="handleExport">
            <template #icon>
              <icon-download />
            </template>
            导出报表
          </a-button>
          <a-button size="small" @click="handleRefresh">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </template>

      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入会员名称、订单号搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="handleReconciliation">
              <template #icon>
                <icon-check-circle />
              </template>
              对账
            </a-button>
            <a-button size="small" @click="handleSummary">
              <template #icon>
                <icon-file />
              </template>
              汇总报表
            </a-button>
            <a-button size="small" @click="handleWithdraw">
              <template #icon>
                <icon-export />
              </template>
              提现
            </a-button>
          </a-space>
        </template>
      </SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #income_type="{ record }">
          <a-tag :color="getTypeColor(record.income_type)">
            {{ getTypeText(record.income_type) }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="record.status === 1 ? 'green' : 'red'">
            {{ record.status === 1 ? '已到账' : '待确认' }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="viewDetail(record)">
              <template #icon><icon-eye /></template>
              查看
            </a-button>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 详情弹窗 -->
    <a-drawer
      v-model:visible="detailVisible"
      :title="`收入详情 - ${currentRecord?.order_no}`"
      :width="500"
      :unmount-on-close="true"
    >
      <a-descriptions :column="1" bordered>
        <a-descriptions-item label="订单编号"> </a-descriptions-item>
        <a-descriptions-item label="会员名称">
          <a-link @click="goToMember(currentRecord)">{{
            currentRecord?.member_name
          }}</a-link>
          {{ currentRecord?.member_name }}
        </a-descriptions-item>
        <a-descriptions-item label="收入类型">
          <a-tag :color="getTypeColor(currentRecord?.income_type)">
            {{ getTypeText(currentRecord?.income_type) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="商品名称">
          {{ currentRecord?.product_name }}
        </a-descriptions-item>
        <a-descriptions-item label="订单金额">
          ¥{{ currentRecord?.order_amount }}
        </a-descriptions-item>
        <a-descriptions-item label="收入金额">
          <span class="income-amount">¥{{ currentRecord?.income_amount }}</span>
        </a-descriptions-item>
        <a-descriptions-item label="费率">
          {{ currentRecord?.rate }}%
        </a-descriptions-item>
        <a-descriptions-item label="到账状态">
          <a-tag :color="currentRecord?.status === 1 ? 'green' : 'red'">
            {{ currentRecord?.status === 1 ? '已到账' : '待确认' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="支付时间">
          {{ currentRecord?.pay_time }}
        </a-descriptions-item>
        <a-descriptions-item label="到账时间">
          {{ currentRecord?.settle_time || '-' }}
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>

    <!-- 对账弹窗 -->
    <a-modal
      v-model:visible="reconciliationVisible"
      title="对账结果"
      :width="600"
      :unmount-on-close="true"
    >
      <a-result
        :status="reconciliationResult.status"
        :title="
          reconciliationResult.status === 'success' ? '对账成功' : '对账失败'
        "
        :sub-title="`对账时间: ${reconciliationResult.reconcile_time}`"
      >
        <template #extra>
          <a-descriptions :column="2" bordered size="small">
            <a-descriptions-item label="订单总数">
              {{ reconciliationResult.total_order }}
            </a-descriptions-item>
            <a-descriptions-item label="订单总金额">
              ¥{{ reconciliationResult.total_amount }}
            </a-descriptions-item>
            <a-descriptions-item label="成功笔数">
              <a-tag color="green">{{
                reconciliationResult.success_count
              }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="成功金额">
              ¥{{ reconciliationResult.success_amount }}
            </a-descriptions-item>
            <a-descriptions-item label="失败笔数">
              <a-tag color="red">{{ reconciliationResult.fail_count }}</a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="失败金额">
              ¥{{ reconciliationResult.fail_amount }}
            </a-descriptions-item>
          </a-descriptions>
        </template>
      </a-result>
    </a-modal>

    <!-- 汇总报表弹窗 -->
    <a-modal
      v-model:visible="summaryVisible"
      title="收入汇总报表"
      :width="700"
      :unmount-on-close="true"
    >
      <a-descriptions :column="2" bordered title="今日数据">
        <a-descriptions-item label="订单数">
          {{ summaryData.today?.order }}
        </a-descriptions-item>
        <a-descriptions-item label="收入金额">
          ¥{{ summaryData.today?.amount }}
        </a-descriptions-item>
      </a-descriptions>
      <a-divider />
      <a-descriptions :column="2" bordered title="昨日数据">
        <a-descriptions-item label="订单数">
          {{ summaryData.yesterday?.order }}
        </a-descriptions-item>
        <a-descriptions-item label="收入金额">
          ¥{{ summaryData.yesterday?.amount }}
        </a-descriptions-item>
      </a-descriptions>
      <a-divider />
      <a-descriptions :column="2" bordered title="本月数据">
        <a-descriptions-item label="订单数">
          {{ summaryData.this_month?.order }}
        </a-descriptions-item>
        <a-descriptions-item label="收入金额">
          ¥{{ summaryData.this_month?.amount }}
        </a-descriptions-item>
      </a-descriptions>
      <a-divider />
      <a-descriptions :column="2" bordered title="本年数据">
        <a-descriptions-item label="订单数">
          {{ summaryData.this_year?.order }}
        </a-descriptions-item>
        <a-descriptions-item label="收入金额">
          ¥{{ summaryData.this_year?.amount }}
        </a-descriptions-item>
      </a-descriptions>
    </a-modal>

    <!-- 提现弹窗 -->
    <a-modal
      v-model:visible="withdrawVisible"
      title="提现申请"
      :width="500"
      :unmount-on-close="true"
      @ok="handleWithdrawConfirm"
    >
      <a-form :model="withdrawForm" layout="vertical">
        <a-form-item label="可提现金额">
          <a-input-number
            :model-value="stats.totalIncome"
            disabled
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="提现金额">
          <a-input-number
            v-model="withdrawForm.amount"
            :min="0"
            :max="stats.totalIncome"
            :precision="2"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="账户类型">
          <a-select v-model="withdrawForm.account_type">
            <a-option value="bank">银行卡</a-option>
            <a-option value="alipay">支付宝</a-option>
            <a-option value="wechat">微信</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="账户姓名">
          <a-input
            v-model="withdrawForm.account_name"
            placeholder="请输入账户姓名"
          />
        </a-form-item>
        <a-form-item label="账号/卡号">
          <a-input
            v-model="withdrawForm.account_no"
            placeholder="请输入账号或卡号"
          />
        </a-form-item>
        <a-form-item v-if="withdrawForm.account_type === 'bank'" label="开户行">
          <a-input
            v-model="withdrawForm.bank_name"
            placeholder="请输入开户行"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted, computed } from 'vue';
  import { useRouter, useRoute } from 'vue-router';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';
  import * as echarts from 'echarts';

  const router = useRouter();
  const route = useRoute();

  const tableRef = ref();
  const loading = ref(false);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };
  const detailVisible = ref(false);
  const currentRecord = ref<any>({});
  const trendType = ref('month');
  const sourceType = ref('type');
  const regionType = ref('income');
  const trendChartRef = ref();
  const sourceChartRef = ref();
  const regionChartRef = ref();
  let trendChart: any = null;
  let sourceChart: any = null;
  let regionChart: any = null;

  const stats = reactive({
    todayIncome: '28,560',
    monthIncome: '856,000',
    totalIncome: '12,580,000',
    paidUser: '8,560',
  });

  const columns = [
    { title: '订单编号', dataIndex: 'order_no', width: 180 },
    { title: '会员名称', dataIndex: 'member_name', width: 120 },
    {
      title: '收入类型',
      dataIndex: 'income_type',
      width: 100,
      slotName: 'income_type',
    },
    { title: '商品名称', dataIndex: 'product_name', ellipsis: true },
    { title: '订单金额', dataIndex: 'order_amount', width: 120 },
    { title: '收入金额', dataIndex: 'income_amount', width: 120 },
    { title: '费率', dataIndex: 'rate', width: 80 },
    { title: '状态', dataIndex: 'status', width: 100, slotName: 'status' },
    { title: '到账时间', dataIndex: 'settle_time', width: 180 },
    { title: '操作', dataIndex: 'action', width: 100, slotName: 'action' },
  ];

  const generateFormModel = () => ({
    keyword: null,
    income_type: '',
    status: '',
    date: [],
  });

  const baseSearchRules = ref([
    { field: 'keyword', label: '关键词', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'income_type',
      label: '收入类型',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'income_type' },
    },
    {
      field: 'status',
      label: '状态',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'settle_status' },
    },
    {
      field: 'date',
      label: '时间',
      value: [],
      component_name: 'base-date-picker',
      attr: { type: 'daterange' },
    },
  ]);

  const formModel = ref(generateFormModel());

  // 页面加载时检查路由参数
  onMounted(() => {
    const { memberId } = route.query;
    const { machineId } = route.query;
    if (memberId) {
      formModel.value.member_id = Number(memberId);
      tableRef.value?.search();
      // 清除路由参数
      router.replace({ path: '/business/income' });
    } else if (machineId) {
      formModel.value.machine_id = Number(machineId);
      tableRef.value?.search();
      // 清除路由参数
      router.replace({ path: '/business/income' });
    }
  });

  const getDataList = (data: any) => {
    return request('/api/business/income/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'purple'];
    return colors[type] || 'default';
  };

  const getTypeText = (type: number) => {
    const texts = ['', '商品销售', '会员订阅', '工具箱', '增值服务', '其他'];
    return texts[type] || '-';
  };

  const viewDetail = (record: any) => {
    currentRecord.value = record;
    detailVisible.value = true;
  };

  const goToOrder = (record: any) => {
    if (record?.order_id) {
      router.push({
        path: '/business/order',
        query: { orderId: record.order_id },
      });
    }
  };

  const goToMember = (record: any) => {
    if (record?.member_id) {
      router.push({
        path: '/business/member',
        query: { memberId: record.member_id },
      });
    }
  };

  // 不同时间维度的数据
  const trendDataMap = {
    week: {
      xAxis: ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
      income: [820, 932, 901, 934, 1290, 1330, 1320],
      orders: [220, 182, 191, 234, 290, 330, 310],
    },
    month: {
      xAxis: ['1日', '5日', '10日', '15日', '20日', '25日', '30日'],
      income: [820, 932, 901, 934, 1290, 1330, 1450],
      orders: [220, 182, 191, 234, 290, 330, 350],
    },
    year: {
      xAxis: ['1月', '2月', '3月', '4月', '5月', '6月', '7月', '8月', '9月', '10月', '11月', '12月'],
      income: [820, 932, 901, 934, 1290, 1330, 1320, 1450, 1200, 1100, 1250, 1400],
      orders: [220, 182, 191, 234, 290, 330, 310, 350, 320, 280, 310, 360],
    },
  };

  const initTrendChart = () => {
    if (!trendChartRef.value) return;
    trendChart = echarts.init(trendChartRef.value);
    updateTrendChart();
    window.addEventListener('resize', () => trendChart.resize());
  };

  const updateTrendChart = () => {
    if (!trendChart) return;
    const data = trendDataMap[trendType.value as keyof typeof trendDataMap];
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
        data: ['收入', '订单数'],
        bottom: 0,
        icon: 'circle',
        itemGap: 20,
      },
      grid: {
        left: '3%',
        right: '4%',
        bottom: '10%',
        top: '8%',
        containLabel: true,
      },
      xAxis: {
        type: 'category',
        data: data.xAxis,
        axisLine: { show: false },
        axisTick: { show: false },
        axisLabel: { color: '#999', fontSize: 12 },
      },
      yAxis: [
        {
          type: 'value',
          name: '收入(元)',
          axisLine: { show: false },
          axisTick: { show: false },
          splitLine: { show: false },
          axisLabel: { color: '#999', fontSize: 12 },
        },
        {
          type: 'value',
          name: '订单数',
          axisLine: { show: false },
          axisTick: { show: false },
          splitLine: { show: false },
          axisLabel: { color: '#999', fontSize: 12 },
        },
      ],
      series: [
        {
          name: '收入',
          type: 'bar',
          barWidth: '40%',
          data: data.income,
          itemStyle: {
            borderRadius: [6, 6, 0, 0],
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: '#4facfe' },
              { offset: 1, color: '#00f2fe' },
            ]),
          },
          emphasis: {
            itemStyle: {
              color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
                { offset: 0, color: '#3d9cf5' },
                { offset: 1, color: '#00d9e9' },
              ]),
            },
          },
        },
        {
          name: '订单数',
          type: 'line',
          yAxisIndex: 1,
          data: data.orders,
          smooth: true,
          symbol: 'circle',
          symbolSize: 8,
          lineStyle: {
            width: 3,
            color: '#00b42a',
            shadowColor: 'rgba(0, 180, 42, 0.3)',
            shadowBlur: 10,
            shadowOffsetY: 5,
          },
          itemStyle: {
            color: '#00b42a',
            borderWidth: 2,
            borderColor: '#fff',
          },
          areaStyle: {
            color: new echarts.graphic.LinearGradient(0, 0, 0, 1, [
              { offset: 0, color: 'rgba(0, 180, 42, 0.2)' },
              { offset: 1, color: 'rgba(0, 180, 42, 0.02)' },
            ]),
          },
        },
      ],
    };
    trendChart.setOption(option, true);
  };

  // 不同维度的收入来源数据
  const sourceDataMap = {
    type: {
      data: [
        { value: 6500000, name: '商品销售', itemStyle: { color: '#4facfe' } },
        { value: 2800000, name: '会员订阅', itemStyle: { color: '#43e97b' } },
        { value: 1800000, name: '工具箱', itemStyle: { color: '#fa709a' } },
        { value: 800000, name: '增值服务', itemStyle: { color: '#667eea' } },
        { value: 680000, name: '其他', itemStyle: { color: '#feca57' } },
      ],
    },
    platform: {
      data: [
        { value: 8500000, name: 'Web端', itemStyle: { color: '#4facfe' } },
        { value: 3200000, name: '移动端', itemStyle: { color: '#43e97b' } },
        { value: 1800000, name: '小程序', itemStyle: { color: '#fa709a' } },
        { value: 1200000, name: 'APP', itemStyle: { color: '#667eea' } },
        { value: 500000, name: '第三方', itemStyle: { color: '#feca57' } },
      ],
    },
    channel: {
      data: [
        { value: 5500000, name: '微信支付', itemStyle: { color: '#4facfe' } },
        { value: 4200000, name: '支付宝', itemStyle: { color: '#43e97b' } },
        { value: 2800000, name: '银行卡', itemStyle: { color: '#fa709a' } },
        { value: 1500000, name: '信用卡', itemStyle: { color: '#667eea' } },
        { value: 1200000, name: '其他', itemStyle: { color: '#feca57' } },
      ],
    },
    region: {
      data: [
        { value: 5200000, name: '华东地区', itemStyle: { color: '#4facfe' } },
        { value: 3800000, name: '华南地区', itemStyle: { color: '#43e97b' } },
        { value: 2900000, name: '华北地区', itemStyle: { color: '#fa709a' } },
        { value: 2100000, name: '西南地区', itemStyle: { color: '#667eea' } },
        { value: 1200000, name: '其他地区', itemStyle: { color: '#feca57' } },
      ],
    },
  };

  const initSourceChart = () => {
    if (!sourceChartRef.value) return;
    sourceChart = echarts.init(sourceChartRef.value);
    updateSourceChart();
    window.addEventListener('resize', () => sourceChart.resize());
  };

  const updateSourceChart = () => {
    if (!sourceChart) return;
    const data = sourceDataMap[sourceType.value as keyof typeof sourceDataMap];
    const option = {
      tooltip: {
        trigger: 'item',
        backgroundColor: 'rgba(255, 255, 255, 0.95)',
        borderColor: '#f0f0f0',
        borderWidth: 1,
        textStyle: { color: '#333' },
        extraCssText: 'box-shadow: 0 4px 12px rgba(0,0,0,0.1);',
        formatter: '{b}: {c} ({d}%)',
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
            itemStyle: {
              shadowBlur: 10,
              shadowOffsetX: 0,
              shadowColor: 'rgba(0, 0, 0, 0.2)',
            },
          },
          labelLine: { show: false },
          data: data.data,
        },
      ],
    };
    sourceChart.setOption(option, true);
  };

  // 地域热力图数据 - 省份数据
  const regionHeatmapData = {
    income: [
      ['广东', 850], ['江苏', 720], ['浙江', 680], ['山东', 590], ['河南', 520],
      ['四川', 480], ['湖北', 450], ['湖南', 420], ['河北', 390], ['福建', 360],
      ['上海', 340], ['北京', 320], ['安徽', 310], ['陕西', 280], ['江西', 260],
      ['重庆', 240], ['辽宁', 220], ['云南', 200], ['广西', 180], ['山西', 160],
      ['吉林', 140], ['贵州', 130], ['新疆', 120], ['内蒙古', 110], ['天津', 100],
      ['黑龙江', 90], ['甘肃', 80], ['海南', 70], ['宁夏', 50], ['青海', 40], ['西藏', 30],
    ],
    order: [
      ['广东', 1520], ['江苏', 1280], ['浙江', 1150], ['山东', 980], ['河南', 860],
      ['四川', 790], ['湖北', 720], ['湖南', 680], ['河北', 620], ['福建', 580],
      ['上海', 540], ['北京', 510], ['安徽', 490], ['陕西', 450], ['江西', 420],
      ['重庆', 390], ['辽宁', 360], ['云南', 330], ['广西', 300], ['山西', 270],
      ['吉林', 240], ['贵州', 220], ['新疆', 200], ['内蒙古', 180], ['天津', 160],
      ['黑龙江', 140], ['甘肃', 120], ['海南', 100], ['宁夏', 70], ['青海', 50], ['西藏', 40],
    ],
    user: [
      ['广东', 8500], ['江苏', 7200], ['浙江', 6800], ['山东', 5900], ['河南', 5200],
      ['四川', 4800], ['湖北', 4500], ['湖南', 4200], ['河北', 3900], ['福建', 3600],
      ['上海', 3400], ['北京', 3200], ['安徽', 3100], ['陕西', 2800], ['江西', 2600],
      ['重庆', 2400], ['辽宁', 2200], ['云南', 2000], ['广西', 1800], ['山西', 1600],
      ['吉林', 1400], ['贵州', 1300], ['新疆', 1200], ['内蒙古', 1100], ['天津', 1000],
      ['黑龙江', 900], ['甘肃', 800], ['海南', 700], ['宁夏', 500], ['青海', 400], ['西藏', 300],
    ],
  };

  const initRegionChart = () => {
    if (!regionChartRef.value) return;
    regionChart = echarts.init(regionChartRef.value);
    updateRegionChart();
    window.addEventListener('resize', () => regionChart.resize());
  };

  const updateRegionChart = () => {
    if (!regionChart) return;
    const data = regionHeatmapData[regionType.value as keyof typeof regionHeatmapData];
    const maxValue = Math.max(...data.map(item => item[1] as number));
    
    const option = {
      tooltip: {
        position: 'top',
        backgroundColor: 'rgba(255, 255, 255, 0.95)',
        borderColor: '#f0f0f0',
        borderWidth: 1,
        textStyle: { color: '#333' },
        extraCssText: 'box-shadow: 0 4px 12px rgba(0,0,0,0.1);',
        formatter: (params: any) => {
          const unit = regionType.value === 'income' ? '万元' : regionType.value === 'order' ? '单' : '人';
          return `${params.name}<br/>${params.value[1]} ${unit}`;
        },
      },
      grid: {
        left: '5%',
        right: '5%',
        bottom: '10%',
        top: '5%',
        containLabel: true,
      },
      xAxis: {
        type: 'category',
        data: data.map(item => item[0]),
        splitArea: { show: true },
        axisLabel: { 
          color: '#666', 
          fontSize: 11,
          rotate: 45,
          interval: 0,
        },
        axisLine: { show: false },
        axisTick: { show: false },
      },
      yAxis: {
        type: 'category',
        data: [''],
        splitArea: { show: true },
        axisLabel: { show: false },
        axisLine: { show: false },
        axisTick: { show: false },
      },
      visualMap: {
        min: 0,
        max: maxValue,
        calculable: true,
        orient: 'horizontal',
        left: 'center',
        bottom: '2%',
        inRange: {
          color: ['#e0f3f8', '#abd9e9', '#74add1', '#4575b4', '#313695'],
        },
        textStyle: { color: '#666' },
      },
      series: [{
        name: regionType.value === 'income' ? '收入' : regionType.value === 'order' ? '订单' : '用户',
        type: 'heatmap',
        data: data.map((item, index) => [index, 0, item[1]]),
        label: {
          show: true,
          fontSize: 10,
          color: '#fff',
          formatter: (params: any) => {
            return params.value[2];
          },
        },
        emphasis: {
          itemStyle: {
            shadowBlur: 10,
            shadowColor: 'rgba(0, 0, 0, 0.5)',
          },
        },
      }],
    };
    regionChart.setOption(option, true);
  };

  const handleExport = () => {
    Message.success('正在导出收入数据...');
    request('/api/business/income/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `收入数据_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  // 对账功能
  const reconciliationVisible = ref(false);
  const reconciliationResult = ref<any>({});

  const handleReconciliation = () => {
    // 模拟对账数据
    reconciliationResult.value = {
      total_order: 156,
      total_amount: 28560,
      success_count: 150,
      success_amount: 27500,
      fail_count: 6,
      fail_amount: 1060,
      reconcile_time: '2024-01-15 15:30:00',
      status: 'success',
    };
    reconciliationVisible.value = true;
  };

  // 汇总报表
  const summaryVisible = ref(false);
  const summaryData = ref<any>({});

  const handleSummary = () => {
    summaryData.value = {
      today: { order: 156, amount: 28560 },
      yesterday: { order: 142, amount: 26800 },
      this_month: { order: 4520, amount: 856000 },
      this_year: { order: 52000, amount: 9800000 },
    };
    summaryVisible.value = true;
  };

  // 提现功能
  const withdrawVisible = ref(false);
  const withdrawForm = reactive({
    amount: 0,
    account_type: 'bank',
    account_name: '',
    account_no: '',
    bank_name: '',
  });

  const handleWithdraw = () => {
    withdrawForm.amount = stats.totalIncome || 0;
    withdrawVisible.value = true;
  };

  // 获取统计数据
  const fetchStats = () => {
    // 模拟获取统计数据
    stats.todayIncome = '28,560';
    stats.monthIncome = '856,000';
    stats.totalIncome = '12,580,000';
    stats.paidUser = '8,560';
  };

  const handleWithdrawConfirm = () => {
    request('/api/business/income/withdraw', withdrawForm).then(() => {
      Message.success('提现申请已提交');
      withdrawVisible.value = false;
      fetchStats();
    });
  };

  onMounted(() => {
    initTrendChart();
    initSourceChart();
    initRegionChart();
  });
</script>

<style lang="less" scoped>
  .stat-row {
    margin-bottom: 16px;
  }

  .chart-row {
    margin-top: 16px !important;
    margin-bottom: 16px;
  }

  .stat-card {
    .stat-content {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .stat-icon {
      width: 48px;
      height: 48px;
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      color: #fff;

      &.blue {
        background: linear-gradient(135deg, #4facfe 0%, #00f2fe 100%);
      }
      &.green {
        background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
      }
      &.purple {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      }
      &.orange {
        background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
      }
    }

    .stat-info {
      .stat-label {
        font-size: 14px;
        color: var(--color-text-2);
      }
      .stat-value {
        font-size: 24px;
        font-weight: 600;
      }
    }
  }

  .chart-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    width: 100%;

    span {
      font-weight: 500;
      font-size: 15px;
    }
  }

  .chart-container {
    height: 300px;
  }

  .region-chart-container {
    height: 280px;
  }

  .table-card {
    margin-top: 16px;
  }

  .income-amount {
    font-size: 18px;
    font-weight: 600;
    color: #f53f3f;
  }
</style>
