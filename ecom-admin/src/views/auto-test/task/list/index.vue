/**
 * 自动化测试系统 - 测试任务列表页
 */
<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>测试任务</span>
          <a-tag color="blue">{{ taskStore.taskTotal }} 个任务</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="handleCreate">
            <template #icon>
              <icon-plus />
            </template>
            新建任务
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
        placeholder="请输入任务名称"
        @hand-submit="handleSubmit"
      ></SearchForm>

      <a-table
        :columns="columns"
        :data="taskStore.taskList"
        :loading="taskStore.loading"
        :pagination="{
          showTotal: true,
          showPageSize: true,
          pageSize: pagination.pageSize,
          current: pagination.page,
          total: taskStore.taskTotal,
        }"
        row-key="id"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #name="{ record }">
          <a-link @click="handleViewDetail(record)">{{ record.name }}</a-link>
        </template>

        <template #type="{ record }">
          <a-tag :color="getTypeColor(record.type)">
            {{ getTypeName(record.type) }}
          </a-tag>
        </template>

        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusName(record.status) }}
          </a-tag>
        </template>

        <template #priority="{ record }">
          <a-tag :color="getPriorityColor(record.priority)">
            {{ getPriorityName(record.priority) }}
          </a-tag>
        </template>

        <template #trigger_type="{ record }">
          <a-tag color="purple">{{ getTriggerTypeName(record.trigger_type) }}</a-tag>
        </template>

        <template #last_run_result="{ record }">
          <div v-if="record.last_run_result">
            <a-progress
              :percent="record.last_run_result.pass_rate"
              :stroke-width="6"
              :show-text="false"
              :color="record.last_run_result.pass_rate >= 80 ? 'green' : record.last_run_result.pass_rate >= 60 ? 'orange' : 'red'"
            />
            <span class="pass-rate-text">
              {{ record.last_run_result.passed }}/{{ record.last_run_result.total }}
              ({{ record.last_run_result.pass_rate }}%)
            </span>
          </div>
          <span v-else class="no-data">未执行</span>
        </template>

        <template #action="{ record }">
          <a-space>
            <a-link @click="handleExecute(record)">
              <icon-play-circle />
              执行
            </a-link>
            <a-link @click="handleEdit(record)">
              <icon-edit />
              编辑
            </a-link>
            <a-popconfirm
              content="确定要删除这个任务吗？"
              @ok="handleDelete(record)"
            >
              <a-link status="danger">
                <icon-delete />
                删除
              </a-link>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 新建/编辑任务弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑任务' : '新建任务'"
      @ok="handleSubmitTask"
      @cancel="modalVisible = false"
    >
      <a-form
        ref="formRef"
        :model="taskForm"
        :rules="formRules"
        layout="vertical"
      >
        <a-form-item field="name" label="任务名称">
          <a-input v-model="taskForm.name" placeholder="请输入任务名称" />
        </a-form-item>

        <a-form-item field="description" label="任务描述">
          <a-textarea v-model="taskForm.description" placeholder="请输入任务描述" />
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="type" label="任务类型">
              <a-select v-model="taskForm.type" placeholder="请选择任务类型">
                <a-option value="functional">功能测试</a-option>
                <a-option value="integration">集成测试</a-option>
                <a-option value="regression">回归测试</a-option>
                <a-option value="performance">性能测试</a-option>
                <a-option value="security">安全测试</a-option>
                <a-option value="ai_generated">AI生成测试</a-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="priority" label="优先级">
              <a-select v-model="taskForm.priority" placeholder="请选择优先级">
                <a-option :value="0">紧急</a-option>
                <a-option :value="1">高</a-option>
                <a-option :value="2">中</a-option>
                <a-option :value="3">低</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item field="trigger_type" label="触发方式">
          <a-select v-model="taskForm.trigger_type" placeholder="请选择触发方式">
            <a-option value="manual">手动触发</a-option>
            <a-option value="scheduled">定时触发</a-option>
            <a-option value="webhook">Webhook触发</a-option>
            <a-option value="ci_cd">CI/CD触发</a-option>
            <a-option value="ai_auto">AI自动触发</a-option>
          </a-select>
        </a-form-item>

        <a-form-item
          v-if="taskForm.trigger_type === 'scheduled'"
          field="schedule"
          label="定时表达式"
        >
          <a-input v-model="taskForm.schedule" placeholder="如: 0 0 * * * (每天凌晨)" />
        </a-form-item>

        <a-form-item
          v-if="taskForm.trigger_type === 'webhook'"
          field="webhook_url"
          label="Webhook地址"
        >
          <a-input v-model="taskForm.webhook_url" placeholder="请输入Webhook地址" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive, onMounted } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import { useAutoTestTaskStore } from '@/store/modules/auto-test';
  import type { TestTaskListParams, CreateTestTaskParams } from '@/types/auto-test';

  const router = useRouter();
  const taskStore = useAutoTestTaskStore();

  const columns = [
    {
      title: '任务名称',
      dataIndex: 'name',
      slotName: 'name',
      width: 200,
    },
    {
      title: '类型',
      dataIndex: 'type',
      slotName: 'type',
      width: 100,
    },
    {
      title: '状态',
      dataIndex: 'status',
      slotName: 'status',
      width: 100,
    },
    {
      title: '优先级',
      dataIndex: 'priority',
      slotName: 'priority',
      width: 80,
    },
    {
      title: '触发方式',
      dataIndex: 'trigger_type',
      slotName: 'trigger_type',
      width: 100,
    },
    {
      title: '最近结果',
      dataIndex: 'last_run_result',
      slotName: 'last_run_result',
      width: 180,
    },
    {
      title: '执行次数',
      dataIndex: 'total_runs',
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
      width: 200,
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

  const modalVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const taskForm = reactive<CreateTestTaskParams>({
    name: '',
    description: '',
    type: 'functional',
    priority: 2,
    trigger_type: 'manual',
    schedule: '',
    webhook_url: '',
  });
  const formRules = {
    name: [{ required: true, message: '请输入任务名称' }],
    type: [{ required: true, message: '请选择任务类型' }],
    trigger_type: [{ required: true, message: '请选择触发方式' }],
  };

  const loadData = async () => {
    await taskStore.fetchTestTaskList({
      ...formModel.value,
      page: pagination.page,
      pageSize: pagination.pageSize,
    } as TestTaskListParams);
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

  const handleCreate = () => {
    isEdit.value = false;
    Object.assign(taskForm, {
      name: '',
      description: '',
      type: 'functional',
      priority: 2,
      trigger_type: 'manual',
      schedule: '',
      webhook_url: '',
    });
    modalVisible.value = true;
  };

  const handleEdit = (record: any) => {
    isEdit.value = true;
    Object.assign(taskForm, record);
    modalVisible.value = true;
  };

  const handleSubmitTask = async () => {
    const err = await formRef.value?.validate();
    if (err) return;

    try {
      if (isEdit.value) {
        await taskStore.updateTask({ id: taskForm.id, ...taskForm } as any);
        Message.success('更新成功');
      } else {
        await taskStore.createTask(taskForm);
        Message.success('创建成功');
      }
      modalVisible.value = false;
      loadData();
    } catch (e) {
      Message.error('操作失败');
    }
  };

  const handleDelete = async (record: any) => {
    try {
      await taskStore.deleteTask(record.id);
      Message.success('删除成功');
      loadData();
    } catch (e) {
      Message.error('删除失败');
    }
  };

  const handleExecute = async (record: any) => {
    try {
      const res = await taskStore.executeTask(record.id);
      Message.success('任务已开始执行');
      router.push(`/auto-test/execution/detail/${res.id}`);
    } catch (e) {
      Message.error('执行失败');
    }
  };

  const handleViewDetail = (record: any) => {
    router.push(`/auto-test/task/detail/${record.id}`);
  };

  // 工具函数
  const getTypeColor = (type: string) => {
    const colors: Record<string, string> = {
      functional: 'blue',
      integration: 'green',
      regression: 'orange',
      performance: 'red',
      security: 'purple',
      ai_generated: 'cyan',
    };
    return colors[type] || 'gray';
  };

  const getTypeName = (type: string) => {
    const names: Record<string, string> = {
      functional: '功能测试',
      integration: '集成测试',
      regression: '回归测试',
      performance: '性能测试',
      security: '安全测试',
      ai_generated: 'AI测试',
    };
    return names[type] || type;
  };

  const getStatusColor = (status: string) => {
    const colors: Record<string, string> = {
      pending: 'gray',
      queued: 'blue',
      running: 'arcoblue',
      completed: 'green',
      failed: 'red',
      cancelled: 'orange',
      paused: 'gray',
    };
    return colors[status] || 'gray';
  };

  const getStatusName = (status: string) => {
    const names: Record<string, string> = {
      pending: '待执行',
      queued: '排队中',
      running: '执行中',
      completed: '已完成',
      failed: '失败',
      cancelled: '已取消',
      paused: '已暂停',
    };
    return names[status] || status;
  };

  const getPriorityColor = (priority: number) => {
    const colors = ['red', 'orange', 'blue', 'gray'];
    return colors[priority] || 'gray';
  };

  const getPriorityName = (priority: number) => {
    const names = ['紧急', '高', '中', '低'];
    return names[priority] || '未知';
  };

  const getTriggerTypeName = (type: string) => {
    const names: Record<string, string> = {
      manual: '手动',
      scheduled: '定时',
      webhook: 'Webhook',
      ci_cd: 'CI/CD',
      ai_auto: 'AI自动',
    };
    return names[type] || type;
  };

  onMounted(() => {
    loadData();
  });
</script>

<style lang="less" scoped>
  .pass-rate-text {
    font-size: 12px;
    color: #666;
    margin-top: 4px;
  }

  .no-data {
    color: #999;
  }
</style>
