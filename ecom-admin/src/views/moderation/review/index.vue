<template>
  <div class="moderation-review">
    <a-card title="人工审核" :bordered="false">
      <!-- 统计卡片 -->
      <a-row :gutter="16" class="stats-row">
        <a-col :span="6">
          <a-statistic title="待审核" :value="stats.pending" :value-style="{ color: '#faad14' }">
            <template #prefix>
              <icon-clock-circle />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="已通过" :value="stats.approved" :value-style="{ color: '#52c41a' }">
            <template #prefix>
              <icon-check-circle />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="已拒绝" :value="stats.rejected" :value-style="{ color: '#f5222d' }">
            <template #prefix>
              <icon-close-circle />
            </template>
          </a-statistic>
        </a-col>
        <a-col :span="6">
          <a-statistic title="总计" :value="stats.total">
            <template #prefix>
              <icon-file-text />
            </template>
          </a-statistic>
        </a-col>
      </a-row>

      <a-divider />

      <!-- 筛选条件 -->
      <a-form :model="queryParams" layout="inline" class="filter-form">
        <a-form-item label="内容类型">
          <a-select
            v-model="queryParams.content_type"
            placeholder="请选择内容类型"
            style="width: 150px"
            allow-clear
          >
            <a-option value="comment">评论</a-option>
            <a-option value="feedback">反馈</a-option>
            <a-option value="requirement">需求</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="审核状态">
          <a-select
            v-model="queryParams.status"
            placeholder="请选择审核状态"
            style="width: 150px"
            allow-clear
          >
            <a-option value="pending">待审核</a-option>
            <a-option value="approved">已通过</a-option>
            <a-option value="rejected">已拒绝</a-option>
            <a-option value="auto_approved">自动通过</a-option>
            <a-option value="auto_rejected">自动拒绝</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="日期范围">
          <a-range-picker
            v-model="dateRange"
            style="width: 300px"
            @change="handleDateChange"
          />
        </a-form-item>

        <a-form-item label="关键词">
          <a-input
            v-model="queryParams.keyword"
            placeholder="请输入关键词"
            style="width: 200px"
            allow-clear
          />
        </a-form-item>

        <a-form-item>
          <a-space>
            <a-button type="primary" @click="handleSearch">
              <template #icon><icon-search /></template>
              查询
            </a-button>
            <a-button @click="handleReset">
              <template #icon><icon-refresh /></template>
              重置
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>

      <!-- 审核列表 -->
      <a-table
        :columns="columns"
        :data="tableData"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
        row-key="id"
        class="review-table"
      >
        <template #content_type="{ record }">
          <a-tag :color="getContentTypeColor(record.content_type)">
            {{ getContentTypeText(record.content_type) }}
          </a-tag>
        </template>

        <template #content_text="{ record }">
          <div class="content-text">
            {{ record.content_text }}
          </div>
        </template>

        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>

        <template #matched_words="{ record }">
          <a-space v-if="record.matched_words && record.matched_words.length > 0" wrap>
            <a-tag
              v-for="(word, index) in record.matched_words"
              :key="index"
              :color="getWordLevelColor(word.level)"
            >
              {{ word.word }} ({{ word.category }})
            </a-tag>
          </a-space>
          <span v-else class="text-secondary">无</span>
        </template>

        <template #created_at="{ record }">
          {{ formatDateTime(record.created_at) }}
        </template>

        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleViewDetail(record)"
            >
              <template #icon><icon-eye /></template>
              查看
            </a-button>
            <a-button
              v-if="record.status === 'pending'"
              type="text"
              size="small"
              status="success"
              @click="handleApprove(record)"
            >
              <template #icon><icon-check /></template>
              通过
            </a-button>
            <a-button
              v-if="record.status === 'pending'"
              type="text"
              size="small"
              status="danger"
              @click="handleReject(record)"
            >
              <template #icon><icon-close /></template>
              拒绝
            </a-button>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 审核详情抽屉 -->
    <a-drawer
      v-model:visible="detailVisible"
      title="审核详情"
      width="600px"
      :footer="false"
    >
      <div v-if="currentRecord" class="detail-content">
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="内容类型">
            <a-tag :color="getContentTypeColor(currentRecord.content_type)">
              {{ getContentTypeText(currentRecord.content_type) }}
            </a-tag>
          </a-descriptions-item>

          <a-descriptions-item label="内容ID">
            {{ currentRecord.content_id }}
          </a-descriptions-item>

          <a-descriptions-item label="内容文本">
            <div class="content-text-detail">
              {{ currentRecord.content_text }}
            </div>
          </a-descriptions-item>

          <a-descriptions-item label="用户ID">
            {{ currentRecord.user_id }}
          </a-descriptions-item>

          <a-descriptions-item label="审核状态">
            <a-tag :color="getStatusColor(currentRecord.status)">
              {{ getStatusText(currentRecord.status) }}
            </a-tag>
          </a-descriptions-item>

          <a-descriptions-item label="匹配的敏感词">
            <a-space v-if="currentRecord.matched_words && currentRecord.matched_words.length > 0" wrap>
              <a-tag
                v-for="(word, index) in currentRecord.matched_words"
                :key="index"
                :color="getWordLevelColor(word.level)"
              >
                {{ word.word }} ({{ word.category }}, 等级{{ word.level }})
              </a-tag>
            </a-space>
            <span v-else class="text-secondary">无</span>
          </a-descriptions-item>

          <a-descriptions-item label="匹配的规则">
            <a-space v-if="currentRecord.matched_rules && currentRecord.matched_rules.length > 0" direction="vertical">
              <a-tag v-for="(rule, index) in currentRecord.matched_rules" :key="index">
                {{ rule }}
              </a-tag>
            </a-space>
            <span v-else class="text-secondary">无</span>
          </a-descriptions-item>

          <a-descriptions-item label="自动处理方式">
            {{ currentRecord.auto_action || '-' }}
          </a-descriptions-item>

          <a-descriptions-item label="审核人ID">
            {{ currentRecord.reviewer_id || '-' }}
          </a-descriptions-item>

          <a-descriptions-item label="审核理由">
            {{ currentRecord.review_reason || '-' }}
          </a-descriptions-item>

          <a-descriptions-item label="审核时间">
            {{ currentRecord.reviewed_at ? formatDateTime(currentRecord.reviewed_at) : '-' }}
          </a-descriptions-item>

          <a-descriptions-item label="创建时间">
            {{ formatDateTime(currentRecord.created_at) }}
          </a-descriptions-item>
        </a-descriptions>

        <div v-if="currentRecord.status === 'pending'" class="action-buttons">
          <a-space>
            <a-button type="primary" @click="handleApprove(currentRecord)">
              <template #icon><icon-check /></template>
              通过审核
            </a-button>
            <a-button status="danger" @click="handleReject(currentRecord)">
              <template #icon><icon-close /></template>
              拒绝审核
            </a-button>
          </a-space>
        </div>
      </div>
    </a-drawer>

    <!-- 审核操作对话框 -->
    <a-modal
      v-model:visible="reviewVisible"
      :title="reviewAction === 'approve' ? '通过审核' : '拒绝审核'"
      @ok="handleReviewConfirm"
      @cancel="handleReviewCancel"
    >
      <a-form :model="reviewForm" layout="vertical">
        <a-form-item label="审核理由" required>
          <a-textarea
            v-model="reviewForm.review_reason"
            placeholder="请输入审核理由"
            :rows="4"
            :max-length="500"
            show-word-limit
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import { moderationApi } from '@/api/moderation';
import type { ModerationLog, ModerationStats, ModerationQueryParams } from '@/types/moderation';
import dayjs from 'dayjs';

// 统计数据
const stats = ref<ModerationStats>({
  total: 0,
  pending: 0,
  approved: 0,
  rejected: 0,
  auto_approved: 0,
  auto_rejected: 0,
});

// 查询参数
const queryParams = reactive<ModerationQueryParams>({
  page: 1,
  page_size: 20,
});

// 日期范围
const dateRange = ref<[string, string]>();

// 表格数据
const tableData = ref<ModerationLog[]>([]);
const loading = ref(false);

// 分页
const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
  showTotal: true,
  showPageSize: true,
});

// 表格列
const columns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '内容类型', dataIndex: 'content_type', slotName: 'content_type', width: 100 },
  { title: '内容文本', dataIndex: 'content_text', slotName: 'content_text', width: 300, ellipsis: true, tooltip: true },
  { title: '用户ID', dataIndex: 'user_id', width: 100 },
  { title: '审核状态', dataIndex: 'status', slotName: 'status', width: 120 },
  { title: '匹配的敏感词', dataIndex: 'matched_words', slotName: 'matched_words', width: 200 },
  { title: '创建时间', dataIndex: 'created_at', slotName: 'created_at', width: 180 },
  { title: '操作', slotName: 'actions', width: 200, fixed: 'right' },
];

// 详情抽屉
const detailVisible = ref(false);
const currentRecord = ref<ModerationLog | null>(null);

// 审核对话框
const reviewVisible = ref(false);
const reviewAction = ref<'approve' | 'reject'>('approve');
const reviewForm = reactive({
  review_reason: '',
});

// 加载统计数据
const loadStats = async () => {
  try {
    const data = await moderationApi.getStats();
    stats.value = data;
  } catch (error) {
    console.error('加载统计数据失败:', error);
  }
};

// 加载列表数据
const loadData = async () => {
  loading.value = true;
  try {
    const { items, total } = await moderationApi.getPendingList(queryParams);
    tableData.value = items;
    pagination.total = total;
  } catch (error) {
    Message.error('加载数据失败');
    console.error('加载数据失败:', error);
  } finally {
    loading.value = false;
  }
};

// 搜索
const handleSearch = () => {
  queryParams.page = 1;
  pagination.current = 1;
  loadData();
};

// 重置
const handleReset = () => {
  Object.assign(queryParams, {
    page: 1,
    page_size: 20,
    content_type: undefined,
    status: undefined,
    start_date: undefined,
    end_date: undefined,
    keyword: undefined,
  });
  dateRange.value = undefined;
  pagination.current = 1;
  loadData();
};

// 日期范围变化
const handleDateChange = (value: [string, string] | undefined) => {
  if (value) {
    queryParams.start_date = value[0];
    queryParams.end_date = value[1];
  } else {
    queryParams.start_date = undefined;
    queryParams.end_date = undefined;
  }
};

// 分页变化
const handlePageChange = (page: number) => {
  queryParams.page = page;
  pagination.current = page;
  loadData();
};

const handlePageSizeChange = (pageSize: number) => {
  queryParams.page_size = pageSize;
  queryParams.page = 1;
  pagination.pageSize = pageSize;
  pagination.current = 1;
  loadData();
};

// 查看详情
const handleViewDetail = (record: ModerationLog) => {
  currentRecord.value = record;
  detailVisible.value = true;
};

// 通过审核
const handleApprove = (record: ModerationLog) => {
  currentRecord.value = record;
  reviewAction.value = 'approve';
  reviewForm.review_reason = '';
  reviewVisible.value = true;
};

// 拒绝审核
const handleReject = (record: ModerationLog) => {
  currentRecord.value = record;
  reviewAction.value = 'reject';
  reviewForm.review_reason = '';
  reviewVisible.value = true;
};

// 确认审核
const handleReviewConfirm = async () => {
  if (!reviewForm.review_reason.trim()) {
    Message.warning('请输入审核理由');
    return;
  }

  if (!currentRecord.value) return;

  try {
    const data = {
      reviewer_id: 1, // TODO: 从用户信息中获取
      review_reason: reviewForm.review_reason,
    };

    if (reviewAction.value === 'approve') {
      await moderationApi.approve(currentRecord.value.id, data);
      Message.success('审核已通过');
    } else {
      await moderationApi.reject(currentRecord.value.id, data);
      Message.success('审核已拒绝');
    }

    reviewVisible.value = false;
    detailVisible.value = false;
    loadData();
    loadStats();
  } catch (error) {
    Message.error('审核操作失败');
    console.error('审核操作失败:', error);
  }
};

// 取消审核
const handleReviewCancel = () => {
  reviewVisible.value = false;
  reviewForm.review_reason = '';
};

// 获取内容类型颜色
const getContentTypeColor = (type: string) => {
  const colors: Record<string, string> = {
    comment: 'blue',
    feedback: 'green',
    requirement: 'orange',
  };
  return colors[type] || 'gray';
};

// 获取内容类型文本
const getContentTypeText = (type: string) => {
  const texts: Record<string, string> = {
    comment: '评论',
    feedback: '反馈',
    requirement: '需求',
  };
  return texts[type] || type;
};

// 获取状态颜色
const getStatusColor = (status: string) => {
  const colors: Record<string, string> = {
    pending: 'orange',
    approved: 'green',
    rejected: 'red',
    auto_approved: 'cyan',
    auto_rejected: 'magenta',
  };
  return colors[status] || 'gray';
};

// 获取状态文本
const getStatusText = (status: string) => {
  const texts: Record<string, string> = {
    pending: '待审核',
    approved: '已通过',
    rejected: '已拒绝',
    auto_approved: '自动通过',
    auto_rejected: '自动拒绝',
  };
  return texts[status] || status;
};

// 获取敏感词等级颜色
const getWordLevelColor = (level: number) => {
  if (level >= 3) return 'red';
  if (level >= 2) return 'orange';
  return 'blue';
};

// 格式化日期时间
const formatDateTime = (dateTime: string) => {
  return dayjs(dateTime).format('YYYY-MM-DD HH:mm:ss');
};

// 初始化
onMounted(() => {
  loadStats();
  loadData();
});
</script>

<style scoped lang="scss">
.moderation-review {
  .stats-row {
    margin-bottom: 24px;
  }

  .filter-form {
    margin-bottom: 16px;
  }

  .review-table {
    .content-text {
      max-width: 300px;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
  }

  .detail-content {
    .content-text-detail {
      white-space: pre-wrap;
      word-break: break-all;
    }

    .action-buttons {
      margin-top: 24px;
      text-align: center;
    }
  }

  .text-secondary {
    color: var(--color-text-3);
  }
}
</style>
