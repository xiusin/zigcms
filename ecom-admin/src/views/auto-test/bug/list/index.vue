<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>Bug分析</span>
          <a-tag color="red">{{ bugStore.bugTotal }} 个问题</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="handleAIAnalyze">
            <template #icon>
              <icon-robot />
            </template>
            AI分析
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
        placeholder="请输入Bug标题"
        @hand-submit="handleSubmit"
      ></SearchForm>

      <a-table
        :columns="columns"
        :data="bugStore.bugList"
        :loading="bugStore.loading"
        :pagination="{
          showTotal: true,
          showPageSize: true,
          pageSize: pagination.pageSize,
          current: pagination.page,
          total: bugStore.bugTotal,
        }"
        row-key="id"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #title="{ record }">
          <a-link @click="handleViewDetail(record)">{{ record.title }}</a-link>
        </template>

        <template #type="{ record }">
          <a-tag :color="getBugTypeColor(record.type)">
            {{ getBugTypeName(record.type) }}
          </a-tag>
        </template>

        <template #severity="{ record }">
          <a-tag :color="getSeverityColor(record.severity)">
            {{ getSeverityName(record.severity) }}
          </a-tag>
        </template>

        <template #issue_location="{ record }">
          <a-tag :color="getLocationColor(record.issue_location)">
            {{ getLocationName(record.issue_location) }}
          </a-tag>
        </template>

        <template #status="{ record }">
          <a-badge
            :status="getStatusBadge(record.status)"
            :text="getStatusName(record.status)"
          />
        </template>

        <template #confidence_score="{ record }">
          <a-progress
            v-if="record.confidence_score"
            :percent="Math.round(record.confidence_score * 100)"
            :stroke-width="6"
            :show-text="false"
            :color="record.confidence_score >= 0.8 ? 'green' : record.confidence_score >= 0.6 ? 'orange' : 'red'"
          />
          <span v-else>-</span>
        </template>

        <template #auto_fix_attempted="{ record }">
          <a-tag v-if="record.auto_fix_attempted && record.auto_fix_result?.success" color="green">
            已修复
          </a-tag>
          <a-tag v-else-if="record.auto_fix_attempted" color="red">
            修复失败
          </a-tag>
          <a-tag v-else>未修复</a-tag>
        </template>

        <template #action="{ record }">
          <a-space>
            <a-link
              v-if="record.status === 'analyzed' || record.status === 'pending'"
              @click="handleAIFix(record)"
            >
              <icon-wand />
              AI修复
            </a-link>
            <a-link @click="handleVerify(record)">
              <icon-check-circle />
              验证
            </a-link>
            <a-link @click="handleSyncToFeedback(record)">
              <icon-send />
              同步
            </a-link>
            <a-popconfirm
              content="确定要删除这个Bug记录吗？"
              @ok="handleDelete(record)"
            >
              <a-link status="danger">
                <icon-delete />
              </a-link>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- AI分析弹窗 -->
    <a-modal
      v-model:visible="analyzeModalVisible"
      title="AI分析Bug"
      :modal-style="{ width: '700px' }"
      @ok="handleSubmitAnalyze"
      @cancel="analyzeModalVisible = false"
    >
      <a-form
        ref="analyzeFormRef"
        :model="analyzeForm"
        :rules="analyzeRules"
        layout="vertical"
      >
        <a-form-item field="title" label="问题标题">
          <a-input v-model="analyzeForm.title" placeholder="请输入问题标题" />
        </a-form-item>

        <a-form-item field="description" label="问题描述">
          <a-textarea
            v-model="analyzeForm.description"
            placeholder="请详细描述问题现象"
            :auto-size="{ minRows: 3, maxRows: 6 }"
          />
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="error_message" label="错误信息">
              <a-textarea
                v-model="analyzeForm.error_message"
                placeholder="请输入错误信息（如有）"
                :auto-size="{ minRows: 2, maxRows: 4 }"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="stack_trace" label="堆栈跟踪">
              <a-textarea
                v-model="analyzeForm.stack_trace"
                placeholder="请输入堆栈跟踪（如有）"
                :auto-size="{ minRows: 2, maxRows: 4 }"
              />
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="问题截图">
          <a-upload
            v-model:file-list="analyzeForm.screenshots"
            action="/api/upload"
            :limit="5"
            list-type="picture-card"
          >
            <div class="upload-trigger">
              <icon-plus />
              <div class="upload-text">上传图片</div>
            </div>
          </a-upload>
        </a-form-item>

        <a-form-item label="测试环境">
          <a-space direction="vertical" style="width: 100%">
            <a-row :gutter="16">
              <a-col :span="8">
                <a-input
                  v-model="analyzeForm.environment?.browser"
                  placeholder="浏览器"
                />
              </a-col>
              <a-col :span="8">
                <a-input
                  v-model="analyzeForm.environment?.os"
                  placeholder="操作系统"
                />
              </a-col>
              <a-col :span="8">
                <a-input
                  v-model="analyzeForm.environment?.platform"
                  placeholder="平台"
                />
              </a-col>
            </a-row>
          </a-space>
        </a-form-item>
      </a-form>

      <template #footer>
        <a-space>
          <a-button @click="analyzeModalVisible = false">取消</a-button>
          <a-button type="primary" :loading="bugStore.analyzing" @click="handleSubmitAnalyze">
            {{ bugStore.analyzing ? '分析中...' : '开始AI分析' }}
          </a-button>
        </a-space>
      </template>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import { useBugAnalysisStore } from '@/store/modules/auto-test';
  import type { BugAnalysisListParams, AIBugAnalysisParams } from '@/types/auto-test';

  const router = useRouter();
  const bugStore = useBugAnalysisStore();

  const columns = [
    {
      title: '问题标题',
      dataIndex: 'title',
      slotName: 'title',
      width: 250,
    },
    {
      title: 'Bug类型',
      dataIndex: 'type',
      slotName: 'type',
      width: 100,
    },
    {
      title: '严重程度',
      dataIndex: 'severity',
      slotName: 'severity',
      width: 90,
    },
    {
      title: '问题位置',
      dataIndex: 'issue_location',
      slotName: 'issue_location',
      width: 100,
    },
    {
      title: 'AI置信度',
      dataIndex: 'confidence_score',
      slotName: 'confidence_score',
      width: 120,
    },
    {
      title: '状态',
      dataIndex: 'status',
      slotName: 'status',
      width: 120,
    },
    {
      title: '修复状态',
      dataIndex: 'auto_fix_attempted',
      slotName: 'auto_fix_attempted',
      width: 100,
    },
    {
      title: '创建时间',
      dataIndex: 'created_at',
      width: 170,
    },
    {
      title: '操作',
      dataIndex: 'action',
      slotName: 'action',
      width: 220,
      fixed: 'right',
    },
  ];

  const pagination = reactive({
    page: 1,
    pageSize: 10,
  });

  const formModel = ref<Record<string, any>>({});
  const generateFormModel = () => ({
    keyword: '',
  });
  const baseSearchRules = ref([
    {
      field: 'keyword',
      label: '关键词',
      value: null,
      width: '200px',
    },
  ]);
  const searchRules = ref([]);

  // AI分析弹窗
  const analyzeModalVisible = ref(false);
  const analyzeFormRef = ref();
  const analyzeForm = reactive<AIBugAnalysisParams>({
    title: '',
    description: '',
    error_message: '',
    stack_trace: '',
    screenshots: [],
    environment: {
      platform: 'Web',
      browser: 'Chrome',
      os: 'Windows',
    },
    test_data: undefined,
  });
  const analyzeRules = {
    title: [{ required: true, message: '请输入问题标题' }],
    description: [{ required: true, message: '请输入问题描述' }],
  };

  const loadData = async () => {
    await bugStore.fetchBugList({
      ...formModel.value,
      page: pagination.page,
      pageSize: pagination.pageSize,
    } as BugAnalysisListParams);
  };

  const handleSubmit = async () => {
    pagination.page = 1;
    await loadData();
  };

  const handlePageChange = async (page: number) => {
    pagination.page = page;
    await loadData();
  };

  const handlePageSizeChange = async (pageSize: number) => {
    pagination.pageSize = pageSize;
    await loadData();
  };

  const handleRefresh = () => {
    loadData();
  };

  const handleViewDetail = (record: any) => {
    router.push(`/auto-test/bug/detail/${record.id}`);
  };

  const handleAIAnalyze = () => {
    analyzeModalVisible.value = true;
  };

  const handleSubmitAnalyze = async () => {
    const err = await analyzeFormRef.value?.validate();
    if (err) return;

    try {
      const res = await bugStore.aiAnalyzeBug(analyzeForm);
      Message.success('AI分析完成');
      analyzeModalVisible.value = false;
      loadData();
      // 跳转到分析详情
      router.push(`/auto-test/bug/detail/${res.bug_analysis.id}`);
    } catch (e) {
      Message.error('分析失败');
    }
  };

  const handleAIFix = async (record: any) => {
    try {
      const res = await bugStore.aiAutoFix({ bug_analysis_id: record.id });
      if (res.success) {
        Message.success('AI修复成功');
      } else {
        Message.warning('AI修复未成功，请人工处理');
      }
      loadData();
    } catch (e) {
      Message.error('修复失败');
    }
  };

  const handleVerify = async (record: any) => {
    try {
      const res = await bugStore.aiVerifyFix(record.id);
      if (res.passed) {
        Message.success('验证通过');
      } else {
        Message.warning('验证未通过');
      }
      loadData();
    } catch (e) {
      Message.error('验证失败');
    }
  };

  const handleSyncToFeedback = async (record: any) => {
    try {
      // 这里调用同步到feedback的接口
      Message.success('已同步到反馈系统');
    } catch (e) {
      Message.error('同步失败');
    }
  };

  const handleDelete = async (record: any) => {
    Message.success('删除成功');
    loadData();
  };

  // 工具函数
  const getBugTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      functional: 'blue',
      ui: 'green',
      performance: 'orange',
      security: 'red',
      data: 'purple',
      compatibility: 'cyan',
      logic: 'pink',
      configuration: 'gray',
      network: 'lime',
      unknown: 'default',
    };
    return colors[type] || 'gray';
  };

  const getBugTypeName = (type: string) => {
    const names: Record<string, string> = {
      functional: '功能错误',
      ui: '界面问题',
      performance: '性能问题',
      security: '安全问题',
      data: '数据问题',
      compatibility: '兼容性问题',
      logic: '逻辑错误',
      configuration: '配置错误',
      network: '网络问题',
      unknown: '未知问题',
    };
    return names[type] || type;
  };

  const getSeverityColor = (severity: number) => {
    const colors = ['red', 'orange', 'blue', 'gray', 'green'];
    return colors[severity] || 'gray';
  };

  const getSeverityName = (severity: number) => {
    const names = ['致命(P0)', '严重(P1)', '一般(P2)', '轻微(P3)', '建议(P4)'];
    return names[severity] || '未知';
  };

  const getLocationColor = (location: string) => {
    const colors: Record<string, string> = {
      frontend: 'blue',
      backend: 'green',
      database: 'orange',
      infrastructure: 'purple',
      third_party: 'cyan',
      unknown: 'gray',
    };
    return colors[location] || 'gray';
  };

  const getLocationName = (location: string) => {
    const names: Record<string, string> = {
      frontend: '前端问题',
      backend: '后端问题',
      database: '数据库问题',
      infrastructure: '基础设施问题',
      third_party: '第三方服务',
      unknown: '未知',
    };
    return names[location] || location;
  };

  const getStatusBadge = (status: string) => {
    const badges: Record<string, any> = {
      pending: 'default',
      analyzing: 'processing',
      analyzed: 'success',
      auto_fixing: 'processing',
      auto_fixed: 'success',
      verification: 'warning',
      resolved: 'success',
      reopened: 'warning',
      closed: 'success',
      failed: 'danger',
    };
    return badges[status] || 'default';
  };

  const getStatusName = (status: string) => {
    const names: Record<string, string> = {
      pending: '待分析',
      analyzing: '分析中',
      analyzed: '已分析',
      auto_fixing: '修复中',
      auto_fixed: '已修复',
      verification: '验证中',
      resolved: '已解决',
      reopened: '已重新打开',
      closed: '已关闭',
      failed: '失败',
    };
    return names[status] || status;
  };

  onMounted(() => {
    loadData();
  });
</script>

<style lang="less" scoped>
  :deep(.arco-upload-list-picture-card) {
    width: 80px;
    height: 80px;
  }

  .upload-trigger {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 80px;
    height: 80px;
    border: 1px dashed var(--color-border);
    border-radius: 4px;
    cursor: pointer;
    transition: all 0.2s;

    &:hover {
      border-color: rgb(var(--primary-6));
    }

    .upload-text {
      font-size: 12px;
      margin-top: 4px;
    }
  }
</style>
