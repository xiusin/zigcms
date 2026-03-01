/**
 * 质量中心 - 关联追踪页面
 * 展示反馈、Bug、测试任务、测试用例之间的关联关系
 * 【高级特性】AMIS CRUD + 条件筛选 + 操作事件
 */
<template>
  <div class="link-records-page">
    <a-card>
      <template #title>
        <a-space>
          <icon-link />
          <span>关联追踪</span>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button type="primary" @click="showFeedbackToTask = true">
            <icon-swap /> 反馈转任务
          </a-button>
          <a-button @click="showBugToFeedback = true">
            <icon-sync /> Bug转反馈
          </a-button>
        </a-space>
      </template>

      <!-- 筛选区 -->
      <a-row :gutter="16" style="margin-bottom: 16px">
        <a-col :span="6">
          <a-select
            v-model="filterSourceType"
            placeholder="来源类型"
            allow-clear
            @change="handleFilter"
          >
            <a-option value="feedback">反馈</a-option>
            <a-option value="bug">Bug</a-option>
            <a-option value="task">任务</a-option>
            <a-option value="case">用例</a-option>
          </a-select>
        </a-col>
        <a-col :span="6">
          <a-select
            v-model="filterLinkType"
            placeholder="关联类型"
            allow-clear
            @change="handleFilter"
          >
            <a-option value="feedback_to_task">反馈→任务</a-option>
            <a-option value="bug_to_feedback">Bug→反馈</a-option>
            <a-option value="task_to_bug">任务→Bug</a-option>
            <a-option value="case_to_bug">用例→Bug</a-option>
          </a-select>
        </a-col>
        <a-col :span="4">
          <a-button @click="handleReset">
            <icon-refresh /> 重置
          </a-button>
        </a-col>
      </a-row>

      <!-- 关联记录表格 -->
      <a-table
        :columns="columns"
        :data="store.linkRecords"
        :loading="store.loading.linkRecords"
        :pagination="pagination"
        stripe
        @page-change="handlePageChange"
      >
        <template #source_type="{ record }">
          <a-tag :color="typeColor(record.source_type)" size="small">
            {{ typeText(record.source_type) }}
          </a-tag>
        </template>
        <template #source_title="{ record }">
          <a-link @click="handleNavigate(record.source_type, record.source_id)">
            #{{ record.source_id }} {{ record.source_title }}
          </a-link>
        </template>
        <template #link_type="{ record }">
          <a-space>
            <a-tag :color="typeColor(record.source_type)" size="small">
              {{ typeText(record.source_type) }}
            </a-tag>
            <icon-arrow-right />
            <a-tag :color="typeColor(record.target_type)" size="small">
              {{ typeText(record.target_type) }}
            </a-tag>
          </a-space>
        </template>
        <template #target_title="{ record }">
          <a-link @click="handleNavigate(record.target_type, record.target_id)">
            #{{ record.target_id }} {{ record.target_title }}
          </a-link>
        </template>
        <template #created_by="{ record }">
          <a-space>
            <a-avatar :size="24">{{ record.created_by?.[0] }}</a-avatar>
            <span>{{ record.created_by }}</span>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 反馈转任务弹窗 -->
    <FeedbackToTaskModal
      v-model:visible="showFeedbackToTask"
      @success="handleSuccess('反馈已成功转为测试任务')"
    />

    <!-- Bug转反馈弹窗 -->
    <BugToFeedbackModal
      v-model:visible="showBugToFeedback"
      @success="handleSuccess('Bug已成功同步到反馈系统')"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import FeedbackToTaskModal from '../components/FeedbackToTaskModal.vue';
import BugToFeedbackModal from '../components/BugToFeedbackModal.vue';

const router = useRouter();
const store = useQualityCenterStore();

// ========== 筛选状态 ==========
const filterSourceType = ref<string | undefined>(undefined);
const filterLinkType = ref<string | undefined>(undefined);

const pagination = reactive({
  current: 1,
  pageSize: 10,
  total: 0,
  showTotal: true,
});

const showFeedbackToTask = ref(false);
const showBugToFeedback = ref(false);

// ========== 表格列 ==========
const columns = [
  { title: 'ID', dataIndex: 'id', width: 60 },
  { title: '来源类型', slotName: 'source_type', width: 90 },
  { title: '来源', slotName: 'source_title', ellipsis: true },
  { title: '关联方向', slotName: 'link_type', width: 160 },
  { title: '目标', slotName: 'target_title', ellipsis: true },
  { title: '创建人', slotName: 'created_by', width: 120 },
  { title: '创建时间', dataIndex: 'created_at', width: 160 },
];

// ========== 方法 ==========
function typeColor(type: string): string {
  const map: Record<string, string> = {
    feedback: 'blue', bug: 'red', task: 'green', case: 'purple',
  };
  return map[type] || 'gray';
}

function typeText(type: string): string {
  const map: Record<string, string> = {
    feedback: '反馈', bug: 'Bug', task: '任务', case: '用例',
  };
  return map[type] || type;
}

function handleNavigate(type: string, id: number) {
  const routeMap: Record<string, string> = {
    feedback: `/feedback/detail/${id}`,
    bug: `/auto-test/bug/detail/${id}`,
    task: `/auto-test/task/detail/${id}`,
    case: `/auto-test/case`,
  };
  const path = routeMap[type];
  if (path) router.push(path);
}

function handleFilter() {
  pagination.current = 1;
  fetchData();
}

function handleReset() {
  filterSourceType.value = undefined;
  filterLinkType.value = undefined;
  pagination.current = 1;
  fetchData();
}

function handlePageChange(page: number) {
  pagination.current = page;
  fetchData();
}

function handleSuccess(msg: string) {
  Message.success(msg);
  fetchData();
}

async function fetchData() {
  await store.fetchLinkRecords({
    source_type: filterSourceType.value,
    page: pagination.current,
    pageSize: pagination.pageSize,
  });
  pagination.total = store.linkRecordsTotal;
}

onMounted(() => {
  fetchData();
});
</script>

<style lang="less" scoped>
.link-records-page {
  padding: 16px;
}
</style>
