<template>
  <a-card title="数据概览" class="bg-card">
    <!-- 顶部的概览展示 -->
    <a-spin :loading="loading" style="width: 100%">
      <div class="dashboard-card">
        <a-card class="single-box">
          <a-statistic
            title="当前在线人数"
            :value="Number(realTimeData.cost || 0)"
            :precision="2"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box">
          <a-statistic
            title="当日销售额"
            :value="Number(realTimeData.account_num || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box">
          <a-statistic
            title="今日已销售订单"
            :value="Number(realTimeData.normal_account_num || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <!-- <a-card class="single-box">
          <a-statistic
            title="今日新建广告数"
            :value="Number(realTimeData.new_campaign_num || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box">
          <a-statistic
            title="账户总余额(元)"
            :value="Number(realTimeData.balance || 0)"
            :precision="2"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card> -->
      </div>
      <div
        v-if="!isSupplierRole"
        class="dashboard-card dashboard-card-gap click"
      >
        <a-card class="single-box" @click.stop="toJRSX">
          <a-statistic
            title="今日上新"
            :value="Number(todyData.newest || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box" @click.stop="toJRCK">
          <a-statistic
            title="今日出库"
            :value="Number(todyData.outbound || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box" @click.stop="toJRFH">
          <a-statistic
            title="今日返货"
            :value="Number(todyData.return || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box" @click.stop="toJRTH">
          <a-statistic
            title="今日退货"
            :value="Number(todyData.refund || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
      </div>
      <div
        v-if="!isSupplierRole"
        class="dashboard-card dashboard-card-gap click"
      >
        <a-card class="single-box" @click.stop="toZRSX">
          <a-statistic
            title="昨日入库"
            :value="Number(yesterdayData.newest || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box" @click.stop="toZRCK">
          <a-statistic
            title="昨日出库"
            :value="Number(yesterdayData.outbound || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box" @click.stop="toZRFH">
          <a-statistic
            title="昨日返货"
            :value="Number(yesterdayData.return || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
        <a-card class="single-box" @click.stop="toZRTH">
          <a-statistic
            title="昨日退货"
            :value="Number(yesterdayData.refund || 0)"
            show-group-separator
          >
            <template #prefix>
              <icon-translate />
            </template>
          </a-statistic>
        </a-card>
      </div>
    </a-spin>
  </a-card>
</template>

<script lang="ts" setup>
  import { ref, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request from '@/api/request';
  import { useRouter } from 'vue-router';
  import dayjs from 'dayjs';
  import { useUserStore } from '@/store';

  const userStore = useUserStore();
  const { role_ids } = userStore;

  // 如果是供应商
  const isSupplierRole = ref(role_ids.includes(19) && role_ids.length === 1);

  const loading = ref(false);
  const searchForm = ref({});
  const realTimeData: any = ref({
    cost: '0.00',
    account_num: 0,
    normal_account_num: 0,
    new_campaign_num: 0,
    balance: '0.00',
    update_time: '-',
  });
  const todyData: any = ref({
    newest: 0,
    outbound: 0,
    refund: 0,
    refund_product_nos: [],
    return: 0,
    return_product_nos: [],
  });
  const yesterdayData: any = ref({
    newest: 0,
    outbound: 0,
    refund: 0,
    refund_product_nos: [],
    return: 0,
    return_product_nos: [],
  });

  const formatStr = 'YYYY-MM-DD';

  const getThisData = () => {
    loading.value = true;
    request('/api/common/overview', {
      date: dayjs().format(formatStr),
    }).then((resData) => {
      loading.value = false;
      if (resData && resData.code === 200) {
        todyData.value = resData.data;
      } else {
        Message.error(JSON.stringify(resData.msg || '网络异常'));
      }
    });

    request('/api/common/overview', {
      date: dayjs().add(-1, 'days').startOf('days').format(formatStr),
    }).then((resData) => {
      loading.value = false;
      if (resData && resData.code === 200) {
        yesterdayData.value = resData.data;
      } else {
        Message.error(JSON.stringify(resData.msg || '网络异常'));
      }
    });
  };
  onMounted(() => {
    getThisData();
  });

  const router = useRouter();
  const toJRSX = () => {
    router.push({
      name: 'stockDetailsManage',
      params: {
        date: [dayjs().format(formatStr), dayjs().format(formatStr)],
      },
    });
  };
  const toJRCK = () => {
    router.push({
      name: 'outboundManage',
      params: {
        date: [
          dayjs().format(formatStr),
          // dayjs().add(1, 'days').startOf('days').format(formatStr),
          dayjs().format(formatStr),
        ],
      },
    });
  };
  const toJRFH = () => {
    router.push({
      name: 'returnLadingManage',
      params: {
        date: [
          dayjs().format(formatStr),
          // dayjs().add(1, 'days').startOf('days').format(formatStr),
          dayjs().format(formatStr),
        ],
      },
    });
  };
  const toJRTH = () => {
    router.push({
      name: 'stockDetailsManage',
      params: {
        product_no: todyData.value?.refund_product_nos.join(';') || null,
      },
    });
  };
  const toZRSX = () => {
    router.push({
      name: 'stockDetailsManage',
      params: {
        date: [
          dayjs().add(-1, 'days').startOf('days').format(formatStr),
          dayjs().add(-1, 'days').startOf('days').format(formatStr),
        ],
      },
    });
  };
  const toZRCK = () => {
    router.push({
      name: 'outboundManage',
      params: {
        date: [
          dayjs().add(-1, 'days').startOf('days').format(formatStr),
          dayjs().add(-1, 'days').startOf('days').format(formatStr),
        ],
      },
    });
  };
  const toZRFH = () => {
    router.push({
      name: 'returnLadingManage',
      params: {
        date: [
          dayjs().add(-1, 'days').startOf('days').format(formatStr),
          dayjs().add(-1, 'days').startOf('days').format(formatStr),
        ],
      },
    });
  };
  const toZRTH = () => {
    router.push({
      name: 'stockDetailsManage',
      params: {
        product_no: yesterdayData.value?.refund_product_nos.join(';') || null,
      },
    });
  };
</script>

<style lang="less" scoped>
  .dashboard-card {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    grid-gap: 10px;
    padding-bottom: 10px;
    &.dashboard-card-gap {
      margin-top: 16px;
    }
    &.click {
      :hover {
        cursor: pointer;
      }
    }
    .single-box {
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
      :deep(.arco-statistic-prefix) {
        padding-right: 5px;
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
  .bg-card {
    height: auto !important;
  }
  :deep(.arco-card-header) {
    overflow: visible;
  }
</style>
