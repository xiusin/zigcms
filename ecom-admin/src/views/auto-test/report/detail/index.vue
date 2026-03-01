<template>
  <div class="report-detail">
    <a-spin :loading="loading" style="width: 100%">
      <a-card>
        <template #title>
          <a-space>
            <span>报告详情</span>
            <a-tag color="blue">{{ detailData?.report_name }}</a-tag>
          </a-space>
        </template>

        <a-row :gutter="16" style="margin-bottom: 24px">
          <a-col :span="6">
            <a-statistic title="总用例数" :value="detailData?.total_cases" />
          </a-col>
          <a-col :span="6">
            <a-statistic title="通过" :value="detailData?.passed" :value-style="{ color: '#52c41a' }" />
          </a-col>
          <a-col :span="6">
            <a-statistic title="失败" :value="detailData?.failed" :value-style="{ color: '#ff4d4f' }" />
          </a-col>
          <a-col :span="6">
            <a-statistic title="通过率" :value="detailData?.pass_rate" suffix="%" />
          </a-col>
        </a-row>

        <a-divider>测试详情</a-divider>

        <a-table :data="detailData?.cases || []" :loading="loading" :pagination="false">
          <a-table-column title="用例名称" data-index="case_name" />
          <a-table-column title="状态" data-index="status">
            <template #cell="{ record }">
              <a-tag v-if="record.status === 'passed'" color="green">通过</a-tag>
              <a-tag v-else color="red">失败</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="耗时(ms)" data-index="duration" />
          <a-table-column title="错误信息" data-index="error_message" />
        </a-table>

        <div style="margin-top: 16px; text-align: right">
          <a-space>
            <a-button @click="handleExportPDF">导出PDF</a-button>
            <a-button type="primary" @click="handleExportHTML">导出HTML</a-button>
          </a-space>
        </div>
      </a-card>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const loading = ref(false);
const detailData = ref<any>(null);

const fetchDetail = async () => {
  const id = route.params.id;
  detailData.value = {
    id,
    report_no: `RPT${Date.now()}`,
    report_name: '每日测试报告',
    total_cases: 100,
    passed: 95,
    failed: 5,
    pass_rate: 95,
    created_at: '2024-01-15 10:00:00',
    cases: [
      { case_name: '用户登录测试', status: 'passed', duration: 1200 },
      { case_name: '用户注册测试', status: 'passed', duration: 800 },
      { case_name: '商品搜索测试', status: 'failed', duration: 500, error_message: '超时' },
      { case_name: '购物车测试', status: 'passed', duration: 1500 },
      { case_name: '订单提交测试', status: 'passed', duration: 2000 },
    ],
  };
};

const handleExportPDF = () => {
  console.log('导出PDF');
};

const handleExportHTML = () => {
  console.log('导出HTML');
};

onMounted(() => {
  fetchDetail();
});
</script>

<style scoped>
.report-detail {
  padding: 16px;
}
</style>
