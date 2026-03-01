<template>
  <div class="task-detail">
    <a-spin :loading="loading" style="width: 100%">
      <a-card>
        <template #title>
          <a-space>
            <span>任务详情</span>
            <a-tag v-if="detailData?.status === 'completed'" color="green">已完成</a-tag>
            <a-tag v-else-if="detailData?.status === 'running'" color="blue">执行中</a-tag>
            <a-tag v-else color="default">等待中</a-tag>
          </a-space>
        </template>

        <a-descriptions :column="2" bordered>
          <a-descriptions-item label="任务名称">{{ detailData?.task_name }}</a-descriptions-item>
          <a-descriptions-item label="任务类型">{{ detailData?.task_type }}</a-descriptions-item>
          <a-descriptions-item label="执行计划">{{ detailData?.cron_expression || '立即执行' }}</a-descriptions-item>
          <a-descriptions-item label="创建人">{{ detailData?.creator }}</a-descriptions-item>
          <a-descriptions-item label="创建时间">{{ detailData?.created_at }}</a-descriptions-item>
          <a-descriptions-item label="最后执行">{{ detailData?.last_executed_at || '-' }}</a-descriptions-item>
        </a-descriptions>

        <a-divider>执行统计</a-divider>

        <a-row :gutter="16">
          <a-col :span="8">
            <a-card hoverable>
              <a-statistic title="总执行次数" :value="detailData?.stats?.total_runs || 0" />
            </a-card>
          </a-col>
          <a-col :span="8">
            <a-card hoverable>
              <a-statistic title="成功次数" :value="detailData?.stats?.success_runs || 0" :value-style="{ color: '#52c41a' }" />
            </a-card>
          </a-col>
          <a-col :span="8">
            <a-card hoverable>
              <a-statistic title="失败次数" :value="detailData?.stats?.failed_runs || 0" :value-style="{ color: '#ff4d4f' }" />
            </a-card>
          </a-col>
        </a-row>

        <a-divider>关联用例</a-divider>

        <a-table :data="detailData?.cases || []" :loading="loading" :pagination="false">
          <a-table-column title="用例ID" data-index="id" width="80" />
          <a-table-column title="用例名称" data-index="case_name" />
          <a-table-column title="类型" data-index="case_type" />
          <a-table-column title="优先级" data-index="priority" />
        </a-table>

        <div style="margin-top: 16px; text-align: right">
          <a-space>
            <a-button @click="handleExecuteNow">立即执行</a-button>
            <a-button type="primary" @click="handleEdit">编辑任务</a-button>
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
    task_name: '每日回归测试',
    task_type: 'scheduled',
    cron_expression: '0 0 * * *',
    creator: 'admin',
    created_at: '2024-01-01 00:00:00',
    last_executed_at: '2024-01-15 00:00:00',
    status: 'running',
    stats: {
      total_runs: 15,
      success_runs: 14,
      failed_runs: 1,
    },
    cases: [
      { id: 1, case_name: '用户登录测试', case_type: '集成测试', priority: '高' },
      { id: 2, case_name: '用户注册测试', case_type: '集成测试', priority: '高' },
      { id: 3, case_name: '商品搜索测试', case_type: 'E2E测试', priority: '中' },
    ],
  };
};

const handleExecuteNow = () => {
  console.log('立即执行任务');
};

const handleEdit = () => {
  console.log('编辑任务');
};

onMounted(() => {
  fetchDetail();
});
</script>

<style scoped>
.task-detail {
  padding: 16px;
}
</style>
