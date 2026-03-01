<template>
  <div class="execution-detail">
    <a-spin :loading="loading" style="width: 100%">
      <a-card>
        <template #title>
          <a-space>
            <span>执行详情</span>
            <a-tag v-if="detailData?.status === 'success'" color="green">成功</a-tag>
            <a-tag v-else-if="detailData?.status === 'failed'" color="red">失败</a-tag>
            <a-tag v-else color="blue">执行中</a-tag>
          </a-space>
        </template>
        
        <a-descriptions :column="2" bordered>
          <a-descriptions-item label="执行编号">{{ detailData?.execution_no }}</a-descriptions-item>
          <a-descriptions-item label="用例名称">{{ detailData?.case_name }}</a-descriptions-item>
          <a-descriptions-item label="执行类型">{{ detailData?.execute_type }}</a-descriptions-item>
          <a-descriptions-item label="执行人">{{ detailData?.executor }}</a-descriptions-item>
          <a-descriptions-item label="开始时间">{{ detailData?.started_at }}</a-descriptions-item>
          <a-descriptions-item label="结束时间">{{ detailData?.finished_at }}</a-descriptions-item>
          <a-descriptions-item label="耗时(秒)">{{ detailData?.duration }}</a-descriptions-item>
          <a-descriptions-item label="通过率">{{ detailData?.pass_rate }}%</a-descriptions-item>
        </a-descriptions>

        <a-divider>执行日志</a-divider>
        
        <a-alert v-if="detailData?.error_message" type="error" :title="detailData.error_message" style="margin-bottom: 16px" />
        
        <a-tabs v-model:activeKey="activeTab">
          <a-tab-pane key="log" tab="执行日志">
            <pre class="log-content">{{ detailData?.log || '暂无日志' }}</pre>
          </a-tab-pane>
          <a-tab-pane key="error" tab="错误信息">
            <pre class="log-content error">{{ detailData?.error_detail || '无错误' }}</pre>
          </a-tab-pane>
          <a-tab-pane key="screenshot" tab="截图">
            <a-image v-if="detailData?.screenshot" :src="detailData.screenshot" />
            <a-empty v-else description="无截图" />
          </a-tab-pane>
        </a-tabs>
      </a-card>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { useRoute } from 'vue-router';

const route = useRoute();
const loading = ref(false);
const activeTab = ref('log');
const detailData = ref<any>(null);

const fetchDetail = async () => {
  const id = route.params.id;
  // 使用 mock 数据
  detailData.value = {
    id,
    execution_no: `EXEC${Date.now()}`,
    case_name: '用户登录测试',
    execute_type: 'manual',
    status: 'success',
    executor: 'admin',
    started_at: '2024-01-15 10:00:00',
    finished_at: '2024-01-15 10:05:00',
    duration: 300,
    pass_rate: 95,
    log: `[2024-01-15 10:00:00] 开始执行测试用例
[2024-01-15 10:00:01] 初始化测试环境
[2024-01-15 10:00:05] 打开浏览器
[2024-01-15 10:00:10] 访问登录页面
[2024-01-15 10:00:15] 输入用户名: admin
[2024-01-15 10:00:16] 输入密码: ******
[2024-01-15 10:00:17] 点击登录按钮
[2024-01-15 10:00:20] 验证登录成功
[2024-01-15 10:00:25] 测试通过
[2024-01-15 10:05:00] 执行完成`,
    error_detail: '',
    screenshot: '',
  };
};

onMounted(() => {
  fetchDetail();
});
</script>

<style scoped>
.execution-detail {
  padding: 16px;
}

.log-content {
  background: #1e1e1e;
  color: #d4d4d4;
  padding: 16px;
  border-radius: 4px;
  max-height: 400px;
  overflow: auto;
  font-family: monospace;
  white-space: pre-wrap;
  word-break: break-all;
}

.log-content.error {
  color: #f48771;
}
</style>
