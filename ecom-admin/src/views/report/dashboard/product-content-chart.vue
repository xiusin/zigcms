<template>
  <a-card class="generate-card" title="产品数据趋势">
    <template #title>
      <span>产品数据趋势</span>
      <a-link class="ml-10" @click="goRouter">查看详情</a-link>
    </template>
    <template #extra>
      <a-space> </a-space>
    </template>
    <div class="chart">
      <v-chart
        ref="chartRef"
        :loading="loading"
        :loading-options="loadingOptions"
        :option="chartOptions"
        autoresize
      />
    </div>
  </a-card>
</template>

<script setup>
  import { use } from 'echarts/core';
  import { CanvasRenderer } from 'echarts/renderers';
  import { PieChart, LineChart } from 'echarts/charts';
  import {
    TitleComponent,
    TooltipComponent,
    LegendComponent,
  } from 'echarts/components';
  import VChart, { THEME_KEY } from 'vue-echarts';
  import request from '@/api/request';
  import { ref, provide, onMounted, nextTick } from 'vue';
  import numeral from 'numeral';
  import { useRouter } from 'vue-router';

  const router = useRouter();

  use([
    CanvasRenderer,
    PieChart,
    TitleComponent,
    TooltipComponent,
    LegendComponent,
  ]);

  const searchForm = ref({
    account_agent_type: '',
    date_type: 3,
    data_type: 1, // 1汇总 2 top5
  });

  const chartData = ref({
    columns: ['time', 'cost'],
    rows: [],
  });
  const chartOptions = ref({
    color: ['#2B55E4', '#33BA7A', '#EF8C0F', '#FF0087', '#FFBF00'],
    legend: {
      show: true,
      bottom: 0,
    },
    // 指定展示的指标
    labelMap: {
      old_cost: '昨天',
      new_cost: '今天',
    },
    // 设置noData选项
    noData: {
      text: '暂无数据', // 提示文本
      textStyle: {
        fontSize: 18,
        fontWeight: 'bold',
      },
      align: 'center', // 提示文本水平对齐方式
      verticalAlign: 'middle', // 提示文本垂直对齐方式
      show: true, // 是否显示提示信息
    },
    graphic: {
      type: 'text', // 类型：文本
      left: 'center',
      top: 'middle',
      silent: true, // 不响应事件
      invisible: true, // 有数据就隐藏
      style: {
        fill: '#9d9d9d',
        fontWeight: 'normal',
        text: '(＞人＜；) 暂无数据',
        fontFamily: 'Microsoft YaHei',
        fontSize: '18px',
      },
    },
    grid: {
      top: '5%',
      left: '2%',
      right: '2%',
      bottom: '15%',
      containLabel: true,
    },
    xAxis: {
      type: 'category',
      // 在这里定义列名
      data: [],
      axisLine: {
        lineStyle: {
          width: 1,
          color: '#F2F3F5',
        },
      },
      axisLabel: {
        show: true,
        color: '#969AA1',
      },
      axisTick: {
        show: false,
      },
    },
    yAxis: {
      type: 'value',
    },
    // 有多少条数据
    series: [],
    tooltip: {
      trigger: 'axis',
      formatter: (dataArr) => {
        let tpl = [dataArr[0].axisValue];
        // let str1 =
        //   '<span style="display:inline-block;margin-right:5px;border-radius:10px;width:10px;height:10px;background-color:#434e59;"></span>';
        // let str2 =
        //   '<span style="display:inline-block;margin-right:5px;border-radius:10px;width:10px;height:10px;background-color:#434e59;"></span>';
        dataArr.forEach((item) => {
          tpl.push(
            `${item.marker} ${item.seriesName} : ${numeral(item.value).format(
              '0,0.00'
            )}`
          );
        });
        return tpl.join('<br>');
      },
    },
  });
  const loading = ref(false);
  const loadingOptions = ref({
    text: '数据加载中...',
    color: '#155DFF',
    textColor: '#155DFF',
    maskColor: 'rgba(0, 0, 0, 0.02)',
  });
  const chartRef = ref();
  // 缓存响应数据
  const cacheResData = ref(null);
  // 刷新图表方法
  const refreshChart = (resAllData) => {
    let resData = [];
    let series = [];
    // 在这里区分渲染类型
    // 1 、如果是汇总图表
    if (searchForm.value.data_type === 1) {
      resData = resAllData.data.total;
      chartOptions.value.labelMap = resData.label_map;
      // 定义有多少行称 ，纬度为日期
      chartOptions.value.xAxis.data = resData.data.map((item) => {
        return item.time;
      });
      // 放置数据 只有一条线
      if (resData.data.length > 0) {
        series = [
          {
            name: '消耗',
            type: 'line',
            data: resData.data.map((curInfo) => curInfo.cost || 0) || [],
            symbol: 'circle',
            symbolSize: 6,
            smooth: true,
          },
        ];
      }
    } else {
      // 如果是产品前5
      resData = resAllData.data.product;
      chartOptions.value.labelMap = resData.label_map;
      // 定义有多少行称 ，纬度为日期
      chartOptions.value.xAxis.data = resData.data.map((item) => {
        return item.time;
      });
      // 有多少条线 重新定义series
      if (resData.data.length > 0) {
        Object.keys(resData.label_map).forEach((key) => {
          let tmpObj = {
            name: resData.label_map[key] || key,
            type: 'line',
            data: resData.data.map((curVal) => curVal[key] || 0) || [],
            symbol: 'circle',
            symbolSize: 6,
            smooth: true,
          };
          series.push(tmpObj);
        });
      }
    }
    chartRef.value?.clear();
    nextTick(() => {
      chartRef.value?.setOption({
        series,
        graphic: {
          invisible: series.length > 0, // 有数据就隐藏
        },
      });
    });

    // 储备原始数据
    chartData.value.rows = resData.data;
    cacheResData.value = resAllData;
  };

  const refreshCacheChart = () => {
    if (cacheResData.value) {
      refreshChart(cacheResData.value);
    }
  };

  const fetchChart = async () => {
    // loading.value = true;
    // chartRef.value?.clear();
    // request('/api/v2/costLineChart', searchForm.value)
    //   .then((resAllData) => {
    //     if (resAllData && resAllData.code === 0) {
    //       refreshChart(resAllData);
    //     } else {
    //       this.$message.error(JSON.stringify(resAllData.msg || '网络异常'));
    //     }
    //   })
    //   .finally(() => {
    //     loading.value = false;
    //   });
  };
  const goRouter = () => {
    router.push({
      name: 'ad-report',
      query: {
        data_type: 'product',
      },
    });
  };
  onMounted(() => {
    fetchChart();
  });
</script>

<style lang="less" scoped>
  .chart {
    width: 100%;
    height: 400px;
  }
  .generate-card {
    padding: 0;
    :deep(.arco-card-header) {
      padding: 0;
    }
    :deep(.arco-card-body) {
      padding-left: 0;
      padding-right: 0;
      padding: 10px 0 0;
    }
  }
</style>
