<template>
  <a-spin :loading="loading" style="width: 100%">
    <a-card class="generate-card" title="广告数据概况">
      <template #title>
        <span>广告数据概况</span>
        <a-link class="ml-10" @click="goRouter">查看详情</a-link>
      </template>
      <template #extra> </template>
      <div class="dashboard-card advertiser-line">
        <a-card v-for="item in keyList" :key="item.key" class="single-box">
          <a-statistic
            :title="item.title"
            :value="Number(info[item.key] || 0)"
            :precision="item.precision"
            show-group-separator
            class="mb-5"
          >
            <template #prefix>
              <icon-translate />
            </template>
            <template v-if="item.suffix" #suffix>{{ item.suffix }}</template>
          </a-statistic>
          <div class="divider mb-5"> 较上周期 </div>
          <div>
            <a-statistic
              :value="Number(info[item.diff_last] || 0)"
              :precision="item.precision"
              show-group-separator
              :class="[
                info[item.diff_last] > 0 ? 'warning_color' : 'success_color',
              ]"
            >
              <template v-if="info[item.diff_last] > 0" #prefix>
                <icon-plus style="font-weight: bold" />
              </template>
              <template v-if="item.suffix" #suffix>{{ item.suffix }}</template>
            </a-statistic>
          </div>
          <div>
            <a-statistic
              :value="Number(info[item.rate] || 0)"
              :precision="item.precision"
              show-group-separator
              :class="[
                info[item.diff_last] > 0 ? 'warning_color' : 'success_color',
              ]"
            >
              <template #prefix>
                <icon-arrow-rise v-if="info[item.diff_last] > 0" />
                <icon-arrow-fall v-else />
              </template>
              <template #suffix>%</template>
            </a-statistic>
          </div>
        </a-card>
      </div>
    </a-card>
  </a-spin>
</template>

<script lang="ts" setup>
  import { ref, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request from '@/api/request';
  import { useRouter } from 'vue-router';
  // import DictSelect from '@/components/dict-select/dict-select.vue';
  // import { dayType, agentType } from '@/components/dict-select/dict-common';

  const emit = defineEmits(['update:modelValue']);

  const props = defineProps({
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
  });
  const router = useRouter();
  const loading = ref(false);
  const keyList: any = [
    {
      title: '消耗',
      key: 'cost',
      diff_last: 'diff_last_cost',
      rate: 'cost_rate',
      precision: 2,
      format: '0,0.00',
    },
    {
      title: '展示数',
      key: 'material_click',
      diff_last: 'diff_last_material_click',
      rate: 'material_click_rate',
      format: '0,0',
      precision: 0,
    },
    {
      title: '千次展示均价',
      key: 'material_cpm',
      diff_last: 'diff_last_material_cpm',
      rate: 'material_cpm_rate',
      precision: 2,
      format: '0,0.00',
    },
    {
      title: '点击数',
      key: 'action_num',
      diff_last: 'diff_last_action_num',
      rate: 'action_num_rate',
      format: '0,0',
      precision: 0,
    },
    {
      title: '点击率',
      key: 'action_ratio',
      diff_last: 'diff_last_action_ratio',
      rate: 'action_ratio_rate',
      suffix: '%',
      precision: 2,
      format: '0,0.00%',
    },
    {
      title: '转化数',
      key: 'convert',
      diff_last: 'diff_last_convert',
      rate: 'convert_rate',
      format: '0,0',
      precision: 0,
    },
    {
      title: '转化率',
      key: 'convert_ratio',
      diff_last: 'diff_last_convert_ratio',
      rate: 'convert_ratio_rate',
      suffix: '%',
      precision: 2,
      format: '0,0.00%',
    },
    {
      title: '转化成本',
      key: 'convert_cost',
      diff_last: 'diff_last_convert_cost',
      rate: 'convert_cost_rate',
      precision: 2,
      format: '0,0.00',
    },
  ];
  const searchForm = ref({
    account_agent_type: '',
    date_type: 1,
    data_type: 1, // 1汇总 2 top5
  });

  const info: any = ref({});
  const getThisData = () => {
    loading.value = true;
    request('/api/v2/planDataOverview', searchForm.value).then((resData) => {
      loading.value = false;
      if (resData && resData.code === 0) {
        Object.keys(resData.data).forEach((item) => {
          info.value[item] = parseFloat(resData.data[item] || 0);
        });
      } else {
        Message.error(JSON.stringify(resData.msg || '网络异常'));
      }
    });
  };
  const goRouter = () => {
    router.push({
      name: 'ad-report',
    });
  };
  onMounted(() => {
    getThisData();
  });
</script>

<style lang="less" scoped>
  .dashboard-card {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    grid-gap: 10px;
    padding-bottom: 10px;
    &.advertiser-line {
      grid-template-columns: repeat(auto-fit, minmax(120px, 1fr));

      :deep(.arco-statistic-title) {
        margin-bottom: 0px;
      }
      :deep(.arco-statistic-value) {
        font-size: 16px;
      }
      :deep(.arco-statistic-value-integer) {
        font-size: 16px;
      }
      :deep(.arco-statistic-value-decimal) {
        font-size: 16px;
      }
      .single-box {
        padding: 0 10px 5px;
        :deep(.arco-statistic-prefix) {
          font-size: 12px;
          padding-right: 3px;
        }
        .success_color {
          :deep(.arco-statistic-value) {
            color: var(--color-success-light-4);
          }
        }
        .warning_color {
          :deep(.arco-statistic-value) {
            color: var(--color-danger-light-4);
          }
        }
        .divider {
          font-size: 12px;
        }
      }
    }
    .single-box {
      // background: var(--color-fill-2);
      background: radial-gradient(
          160% 160% at 0 0,
          rgba(217, 242, 255, 0.3) 0,
          rgba(242, 240, 252, 0.3) 30%,
          rgba(191, 216, 255, 0.15) 100%
        )
        var(--color-bg-1);
      .content {
        margin-top: 20px;
      }
    }
  }
  body[arco-theme='dark'] .single-box {
    background: radial-gradient(
        160% 160% at 0 0,
        rgba(217, 242, 255, 0.2) 0,
        rgba(242, 240, 252, 0.1) 48%,
        rgba(191, 216, 255, 0.05) 100%
      )
      var(--color-bg-1);
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
