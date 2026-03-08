<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>任务管理</span>
          <a-tag color="blue">{{ tableTotal }} 个任务</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openTaskModal({})">
            <template #icon>
              <icon-plus />
            </template>
            创建任务
          </a-button>
          <a-button size="small" @click="refreshTasks">
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
        placeholder="请输入任务名称搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="handleViewLogs">
              <template #icon>
                <icon-file />
              </template>
              执行日志
            </a-button>
            <a-button size="small" @click="handleViewSchedule">
              <template #icon>
                <icon-history />
              </template>
              调度日志
            </a-button>
          </a-space>
        </template>
      </SearchForm>

      <a-tabs v-model="activeTab" @change="fetchData">
        <a-tab-pane key="schedule" title="定时任务">
          <template #icon><icon-clock-circle /></template>
        </a-tab-pane>
        <a-tab-pane key="delay" title="延迟任务">
          <template #icon><icon-history /></template>
        </a-tab-pane>
        <a-tab-pane key="loop" title="循环任务">
          <template #icon><icon-refresh /></template>
        </a-tab-pane>
        <a-tab-pane key="manual" title="手动任务">
          <template #icon><icon-user /></template>
        </a-tab-pane>
      </a-tabs>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
      >
        <template #task_type="{ record }">
          <a-tag :color="getTypeColor(record.task_type)">
            {{ getTypeText(record.task_type) }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="runTask(record)">
              <template #icon><icon-refresh /></template>
              执行
            </a-button>
            <a-button type="text" size="small" @click="openTaskModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-popconfirm
              :content="`确定要${
                record.status === 1 ? '停用' : '启用'
              }该任务吗?`"
              position="left"
              @ok="toggleStatus(record)"
            >
              <a-button type="text" size="small">
                <template #icon>
                  <icon-lock v-if="record.status === 1" />
                  <icon-check-circle v-else />
                </template>
                {{ record.status === 1 ? '停用' : '启用' }}
              </a-button>
            </a-popconfirm>
            <a-popconfirm
              :content="`确定要删除该任务吗?`"
              position="left"
              @ok="deleteTask(record)"
            >
              <a-button type="text" size="small" status="danger">
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 任务执行日志 -->
    <a-drawer
      v-model:visible="logVisible"
      title="任务执行日志"
      :width="600"
      :unmount-on-close="true"
    >
      <a-timeline>
        <a-timeline-item
          v-for="(log, index) in taskLogs"
          :key="index"
          :color="log.status === 'success' ? 'green' : 'red'"
        >
          <div class="log-item">
            <div class="log-time">{{ log.time }}</div>
            <div class="log-content">{{ log.content }}</div>
            <div class="log-duration">耗时: {{ log.duration }}ms</div>
          </div>
        </a-timeline-item>
      </a-timeline>
      <a-empty v-if="!taskLogs.length" description="暂无执行日志" />
    </a-drawer>

    <!-- 任务编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑任务' : '创建任务'"
      :width="700"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-form-item label="任务名称" field="task_name">
          <a-input v-model="formData.task_name" placeholder="请输入任务名称" />
        </a-form-item>
        <a-form-item label="任务类型" field="task_type">
          <a-select
            v-model="formData.task_type"
            placeholder="请选择任务类型"
            :disabled="isEdit"
          >
            <a-option :value="1">定时任务</a-option>
            <a-option :value="2">延迟任务</a-option>
            <a-option :value="3">循环任务</a-option>
            <a-option :value="4">手动任务</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="任务分组" field="group_name">
          <a-input v-model="formData.group_name" placeholder="请输入任务分组" />
        </a-form-item>
        <a-form-item label="调用目标" field="target">
          <a-input
            v-model="formData.target"
            placeholder="请输入调用目标，如: app\job\TestJob"
          />
        </a-form-item>
        <a-form-item label="执行参数" field="params">
          <a-textarea
            v-model="formData.params"
            placeholder="请输入执行参数，JSON格式"
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>
        <a-row v-if="formData.task_type === 1" :gutter="16">
          <a-col :span="12">
            <a-form-item label="Cron表达式" field="cron">
              <a-input v-model="formData.cron" placeholder="如: 0 * * * *" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="超时时间(秒)" field="timeout">
              <a-input-number
                v-model="formData.timeout"
                :min="0"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row v-if="formData.task_type === 2" :gutter="16">
          <a-col :span="12">
            <a-form-item label="延迟时间(秒)" field="delay">
              <a-input-number
                v-model="formData.delay"
                :min="0"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="重试次数" field="retry">
              <a-input-number
                v-model="formData.retry"
                :min="0"
                :max="10"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="任务描述" field="description">
          <a-textarea
            v-model="formData.description"
            placeholder="请输入任务描述"
          />
        </a-form-item>
        <a-form-item label="状态" field="status">
          <a-switch v-model="formData.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 执行日志弹窗 -->
    <a-modal
      v-model:visible="logsVisible"
      title="任务执行日志"
      :width="900"
      :footer="false"
    >
      <a-table
        :columns="logColumns"
        :data="[
          {
            id: 1,
            task_name: '订单同步',
            start_time: '2024-01-20 10:00:00',
            end_time: '2024-01-20 10:00:05',
            status: 'success',
            result: '成功同步 100 条',
          },
          {
            id: 2,
            task_name: '数据统计',
            start_time: '2024-01-20 09:00:00',
            end_time: '2024-01-20 09:00:03',
            status: 'success',
            result: '成功统计 50 条',
          },
        ]"
        :pagination="false"
      >
        <template #status="{ record }">
          <a-tag :color="record.status === 'success' ? 'green' : 'red'">
            {{ record.status === 'success' ? '成功' : '失败' }}
          </a-tag>
        </template>
      </a-table>
    </a-modal>

    <!-- 调度日志弹窗 -->
    <a-modal
      v-model:visible="scheduleVisible"
      title="任务调度日志"
      :width="900"
      :footer="false"
    >
      <a-table
        :columns="scheduleColumns"
        :data="[
          {
            id: 1,
            task_name: '订单同步',
            schedule_time: '2024-01-20 10:00:00',
            execute_time: '2024-01-20 10:00:00',
            status: 'waiting',
          },
          {
            id: 2,
            task_name: '数据统计',
            schedule_time: '2024-01-20 09:00:00',
            execute_time: '2024-01-20 09:00:00',
            status: 'completed',
          },
        ]"
        :pagination="false"
      >
        <template #status="{ record }">
          <a-tag :color="record.status === 'completed' ? 'green' : 'orange'">
            {{ record.status === 'completed' ? '已完成' : '等待中' }}
          </a-tag>
        </template>
      </a-table>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed } from 'vue';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';

  const tableRef = ref();
  const loading = ref(false);
  const activeTab = ref('schedule');
  const modalVisible = ref(false);
  const logVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const taskLogs = ref<any[]>([]);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 搜索表单数据
  const formModel = reactive({
    content: '',
  });

  // 生成默认表单数据
  const generateFormModel = () => {
    return {
      content: '',
    };
  };

  // 搜索规则
  const searchRules = ref<any[]>([
    {
      label: '任务名称',
      field: 'task_name',
      type: 'input',
      placeholder: '请输入任务名称',
    },
    {
      label: '任务类型',
      field: 'task_type',
      type: 'select',
      placeholder: '请选择任务类型',
      options: [
        { label: '定时任务', value: 1 },
        { label: '延迟任务', value: 2 },
        { label: '循环任务', value: 3 },
        { label: '手动任务', value: 4 },
      ],
    },
  ]);

  // 基础搜索规则
  const baseSearchRules = ref<any[]>([
    { label: '任务名称', field: 'task_name' },
  ]);

  // 处理搜索
  const handleSubmit = () => {
    tableRef.value?.search();
  };

  const formData = reactive({
    id: 0,
    task_name: '',
    task_type: 1,
    group_name: '',
    target: '',
    params: '',
    cron: '',
    timeout: 300,
    delay: 0,
    retry: 0,
    description: '',
    status: true,
  });

  // 执行日志列定义
  const logColumns = [
    { title: '任务名称', dataIndex: 'task_name' },
    { title: '开始时间', dataIndex: 'start_time' },
    { title: '结束时间', dataIndex: 'end_time' },
    { title: '状态', dataIndex: 'status', slotName: 'status' },
    { title: '执行结果', dataIndex: 'result' },
  ];

  // 调度日志列定义
  const scheduleColumns = [
    { title: '任务名称', dataIndex: 'task_name' },
    { title: '计划时间', dataIndex: 'schedule_time' },
    { title: '执行时间', dataIndex: 'execute_time' },
    { title: '状态', dataIndex: 'status', slotName: 'status' },
  ];

  const rules = {
    task_name: [{ required: true, message: '请输入任务名称' }],
    task_type: [{ required: true, message: '请选择任务类型' }],
    target: [{ required: true, message: '请输入调用目标' }],
  };

  const columns = [
    { title: '任务ID', dataIndex: 'id', width: 80 },
    { title: '任务名称', dataIndex: 'task_name', width: 180 },
    {
      title: '任务类型',
      dataIndex: 'task_type',
      width: 100,
      slotName: 'task_type',
    },
    { title: '任务分组', dataIndex: 'group_name', width: 120 },
    { title: '调用目标', dataIndex: 'target', ellipsis: true },
    { title: '执行参数', dataIndex: 'params', ellipsis: true },
    { title: 'Cron/延迟', dataIndex: 'schedule', width: 120 },
    { title: '超时(秒)', dataIndex: 'timeout', width: 80 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '最后执行', dataIndex: 'last_run_time', width: 180 },
    { title: '操作', dataIndex: 'action', width: 220, slotName: 'action' },
  ];

  const getTaskTypeValue = (tab: string) => {
    const map: any = { schedule: 1, delay: 2, loop: 3, manual: 4 };
    return map[tab] || 1;
  };

  const getDataList = (data: any) => {
    return request('/api/operation/task/list', {
      ...data,
      task_type: getTaskTypeValue(activeTab.value),
    });
  };

  const getTypeColor = (type: number) => {
    const colors = ['', 'blue', 'orange', 'purple', 'green'];
    return colors[type] || 'default';
  };

  const getTypeText = (type: number) => {
    const texts = ['', '定时任务', '延迟任务', '循环任务', '手动任务'];
    return texts[type] || '-';
  };

  const getStatusColor = (status: number) => {
    return status === 1 ? 'green' : 'red';
  };

  const getStatusText = (status: number) => {
    return status === 1 ? '运行中' : '已停用';
  };

  const fetchData = () => {
    tableRef.value?.search();
  };

  const refreshTasks = () => {
    fetchData();
    Message.success('刷新成功');
  };

  // 执行日志
  const logsVisible = ref(false);
  const handleViewLogs = () => {
    logsVisible.value = true;
  };

  // 调度日志
  const scheduleVisible = ref(false);
  const handleViewSchedule = () => {
    scheduleVisible.value = true;
  };

  const openTaskModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, {
        ...record,
        status: record.status === 1,
      });
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        task_name: '',
        task_type: getTaskTypeValue(activeTab.value),
        group_name: 'default',
        target: '',
        params: '',
        cron: '',
        timeout: 300,
        delay: 0,
        retry: 0,
        description: '',
        status: true,
      });
    }
    modalVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    const params = {
      ...formData,
      status: formData.status ? 1 : 0,
    };

    request('/api/operation/task/save', params).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '创建成功');
      modalVisible.value = false;
      fetchData();
    });
  };

  const runTask = (record: any) => {
    request('/api/operation/task/run', { id: record.id }).then(() => {
      Message.success('任务已触发执行');
    });
  };

  const toggleStatus = (record: any) => {
    request('/api/operation/task/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    }).then(() => {
      Message.success(record.status === 1 ? '已停用' : '已启用');
      fetchData();
    });
  };

  const deleteTask = (record: any) => {
    request('/api/operation/task/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      fetchData();
    });
  };
</script>

<style lang="less" scoped>
  .table-card {
    .table-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16px;
      border-bottom: 1px solid var(--color-border-1);
    }
  }

  // 统一 Tab 字体大小
  :deep(.arco-tabs) {
    .arco-tabs-nav {
      .arco-tabs-tab {
        font-size: 13px !important;
      }
    }
  }

  // 统一表格内文字大小
  :deep(.arco-table) {
    .arco-table-cell {
      font-size: 12px !important;
    }
    .arco-table-th {
      font-size: 12px !important;
    }
  }

  // 统一按钮字体
  :deep(.arco-btn) {
    font-size: 12px !important;
  }

  // 统一标签字体
  :deep(.arco-tag) {
    font-size: 11px !important;
  }

  .log-item {
    .log-time {
      font-size: 12px;
      color: var(--color-text-3);
    }

    .log-content {
      margin: 4px 0;
    }

    .log-duration {
      font-size: 12px;
      color: var(--color-text-3);
    }
  }
</style>
