<template>
  <div class="workflow-container">
    <a-tabs default-active-key="approval">
      <a-tab-pane key="approval" title="审批流程">
        <a-card :bordered="false">
          <div class="header-actions">
            <a-button type="primary" @click="handleAddWorkflow">
              <template #icon><icon-plus /></template>
              新增流程
            </a-button>
          </div>

          <a-table :data="workflows" :loading="loading">
            <template #columns>
              <a-table-column title="流程名称" data-index="name" />
              <a-table-column title="适用模型" data-index="model_name" />
              <a-table-column title="审批节点" :width="200">
                <template #cell="{ record }">
                  <a-tag
                    v-for="node in record.nodes"
                    :key="node.id"
                    style="margin: 2px"
                  >
                    {{ node.name }}
                  </a-tag>
                </template>
              </a-table-column>
              <a-table-column title="状态" :width="100">
                <template #cell="{ record }">
                  <a-tag v-if="record.status === 1" color="green">启用</a-tag>
                  <a-tag v-else color="red">禁用</a-tag>
                </template>
              </a-table-column>
              <a-table-column
                title="创建时间"
                data-index="created_at"
                :width="180"
              />
              <a-table-column title="操作" :width="200" fixed="right">
                <template #cell="{ record }">
                  <a-space>
                    <a-button
                      type="text"
                      size="small"
                      @click="handleEditWorkflow(record)"
                    >
                      编辑
                    </a-button>
                    <a-button
                      type="text"
                      size="small"
                      :status="record.status === 1 ? 'warning' : 'success'"
                      @click="handleToggleStatus(record)"
                    >
                      {{ record.status === 1 ? '禁用' : '启用' }}
                    </a-button>
                    <a-popconfirm
                      content="确定删除吗？"
                      @ok="handleDeleteWorkflow(record.id)"
                    >
                      <a-button type="text" size="small" status="danger"
                        >删除</a-button
                      >
                    </a-popconfirm>
                  </a-space>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-card>
      </a-tab-pane>

      <a-tab-pane key="schedule" title="定时发布">
        <a-card :bordered="false">
          <a-table :data="schedules" :loading="scheduleLoading">
            <template #columns>
              <a-table-column title="内容标题" data-index="content_title" />
              <a-table-column title="所属模型" data-index="model_name" />
              <a-table-column
                title="发布时间"
                data-index="publish_time"
                :width="180"
              />
              <a-table-column title="状态" :width="100">
                <template #cell="{ record }">
                  <a-tag v-if="record.status === 0" color="orange"
                    >待发布</a-tag
                  >
                  <a-tag v-else-if="record.status === 1" color="green"
                    >已发布</a-tag
                  >
                  <a-tag v-else color="red">已取消</a-tag>
                </template>
              </a-table-column>
              <a-table-column
                title="创建时间"
                data-index="created_at"
                :width="180"
              />
              <a-table-column title="操作" :width="150" fixed="right">
                <template #cell="{ record }">
                  <a-space>
                    <a-button
                      v-if="record.status === 0"
                      type="text"
                      size="small"
                      @click="handleEditSchedule(record)"
                    >
                      编辑
                    </a-button>
                    <a-popconfirm
                      v-if="record.status === 0"
                      content="确定取消定时发布吗？"
                      @ok="handleCancelSchedule(record.id)"
                    >
                      <a-button type="text" size="small" status="danger"
                        >取消</a-button
                      >
                    </a-popconfirm>
                  </a-space>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-card>
      </a-tab-pane>

      <a-tab-pane key="records" title="审批记录">
        <a-card :bordered="false">
          <div class="header-actions">
            <a-space>
              <a-select
                v-model="recordFilter.status"
                placeholder="审批状态"
                style="width: 150px"
                @change="fetchRecords"
              >
                <a-option value="">全部</a-option>
                <a-option :value="0">待审批</a-option>
                <a-option :value="1">已通过</a-option>
                <a-option :value="2">已拒绝</a-option>
              </a-select>
              <a-range-picker
                v-model="recordFilter.dateRange"
                @change="fetchRecords"
              />
            </a-space>
          </div>

          <a-table :data="records" :loading="recordLoading">
            <template #columns>
              <a-table-column title="内容标题" data-index="content_title" />
              <a-table-column title="流程名称" data-index="workflow_name" />
              <a-table-column title="当前节点" data-index="current_node_name" />
              <a-table-column title="申请人" data-index="applicant_name" />
              <a-table-column title="状态" :width="100">
                <template #cell="{ record }">
                  <a-tag v-if="record.status === 0" color="orange"
                    >待审批</a-tag
                  >
                  <a-tag v-else-if="record.status === 1" color="green"
                    >已通过</a-tag
                  >
                  <a-tag v-else color="red">已拒绝</a-tag>
                </template>
              </a-table-column>
              <a-table-column
                title="申请时间"
                data-index="created_at"
                :width="180"
              />
              <a-table-column title="操作" :width="150" fixed="right">
                <template #cell="{ record }">
                  <a-space>
                    <a-button
                      type="text"
                      size="small"
                      @click="handleViewRecord(record)"
                    >
                      详情
                    </a-button>
                    <a-button
                      v-if="record.status === 0"
                      type="text"
                      size="small"
                      status="success"
                      @click="handleApprove(record, 1)"
                    >
                      通过
                    </a-button>
                    <a-button
                      v-if="record.status === 0"
                      type="text"
                      size="small"
                      status="danger"
                      @click="handleApprove(record, 2)"
                    >
                      拒绝
                    </a-button>
                  </a-space>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-card>
      </a-tab-pane>
    </a-tabs>

    <!-- 工作流编辑弹窗 -->
    <a-modal
      v-model:visible="workflowModalVisible"
      :title="workflowModalTitle"
      width="700px"
      @before-ok="handleWorkflowSubmit"
    >
      <a-form :model="workflowForm" ref="workflowFormRef" layout="vertical">
        <a-form-item label="流程名称" field="name" required>
          <a-input v-model="workflowForm.name" placeholder="请输入流程名称" />
        </a-form-item>
        <a-form-item label="适用模型" field="model_id" required>
          <a-select v-model="workflowForm.model_id" placeholder="选择模型">
            <a-option v-for="model in models" :key="model.id" :value="model.id">
              {{ model.name }}
            </a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="审批节点" required>
          <div
            v-for="(node, index) in workflowForm.nodes"
            :key="index"
            class="node-item"
          >
            <a-space style="width: 100%">
              <a-input
                v-model="node.name"
                placeholder="节点名称"
                style="width: 200px"
              />
              <a-select
                v-model="node.approver_id"
                placeholder="审批人"
                style="width: 200px"
              >
                <a-option :value="1">管理员</a-option>
                <a-option :value="2">编辑</a-option>
              </a-select>
              <a-button
                type="text"
                status="danger"
                @click="workflowForm.nodes.splice(index, 1)"
              >
                <template #icon><icon-delete /></template>
              </a-button>
            </a-space>
          </div>
          <a-button type="dashed" long @click="handleAddNode">
            <template #icon><icon-plus /></template>
            添加节点
          </a-button>
        </a-form-item>
        <a-form-item label="状态" field="status">
          <a-radio-group v-model="workflowForm.status">
            <a-radio :value="1">启用</a-radio>
            <a-radio :value="0">禁用</a-radio>
          </a-radio-group>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 审批详情弹窗 -->
    <a-modal
      v-model:visible="recordDetailVisible"
      title="审批详情"
      width="800px"
      :footer="false"
    >
      <a-descriptions v-if="currentRecord" :column="2" bordered>
        <a-descriptions-item label="内容标题">{{
          currentRecord.content_title
        }}</a-descriptions-item>
        <a-descriptions-item label="流程名称">{{
          currentRecord.workflow_name
        }}</a-descriptions-item>
        <a-descriptions-item label="申请人">{{
          currentRecord.applicant_name
        }}</a-descriptions-item>
        <a-descriptions-item label="申请时间">{{
          currentRecord.created_at
        }}</a-descriptions-item>
        <a-descriptions-item label="当前状态" :span="2">
          <a-tag v-if="currentRecord.status === 0" color="orange">待审批</a-tag>
          <a-tag v-else-if="currentRecord.status === 1" color="green"
            >已通过</a-tag
          >
          <a-tag v-else color="red">已拒绝</a-tag>
        </a-descriptions-item>
      </a-descriptions>

      <a-divider>审批流程</a-divider>
      <a-timeline>
        <a-timeline-item
          v-for="log in currentRecord?.logs"
          :key="log.id"
          :label="log.created_at"
        >
          <div>
            <strong>{{ log.node_name }}</strong> - {{ log.approver_name }}
          </div>
          <div>
            <a-tag v-if="log.status === 1" color="green">通过</a-tag>
            <a-tag v-else-if="log.status === 2" color="red">拒绝</a-tag>
            <a-tag v-else color="orange">待审批</a-tag>
          </div>
          <div
            v-if="log.remark"
            style="margin-top: 8px; color: var(--color-text-3)"
          >
            备注：{{ log.remark }}
          </div>
        </a-timeline-item>
      </a-timeline>
    </a-modal>

    <!-- 审批操作弹窗 -->
    <a-modal
      v-model:visible="approveModalVisible"
      :title="approveAction === 1 ? '审批通过' : '审批拒绝'"
      width="500px"
      @before-ok="handleApproveSubmit"
    >
      <a-form layout="vertical">
        <a-form-item label="审批意见">
          <a-textarea
            v-model="approveRemark"
            placeholder="请输入审批意见（可选）"
            :max-length="200"
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
  import { IconPlus, IconDelete } from '@arco-design/web-vue/es/icon';
  import {
    getWorkflowList,
    createWorkflow,
    updateWorkflow,
    deleteWorkflow,
    getScheduleList,
    cancelSchedule,
    getApprovalRecords,
    approveContent,
    getModelList,
  } from '@/api/cms';

  const loading = ref(false);
  const workflows = ref([]);
  const models = ref([]);

  const scheduleLoading = ref(false);
  const schedules = ref([]);

  const recordLoading = ref(false);
  const records = ref([]);
  const recordFilter = reactive({
    status: '',
    dateRange: [],
  });

  // 工作流表单
  const workflowModalVisible = ref(false);
  const workflowModalTitle = ref('');
  const workflowFormRef = ref();
  const workflowForm = ref({
    name: '',
    model_id: undefined,
    nodes: [],
    status: 1,
  });

  // 审批详情
  const recordDetailVisible = ref(false);
  const currentRecord = ref<any>(null);

  // 审批操作
  const approveModalVisible = ref(false);
  const approveAction = ref(1);
  const approveRemark = ref('');
  const approveRecordId = ref<number>();

  // 加载数据
  const fetchWorkflows = async () => {
    loading.value = true;
    try {
      const res = await getWorkflowList();
      workflows.value = res.data || [];
    } catch (error) {
      Message.error('加载失败');
    } finally {
      loading.value = false;
    }
  };

  const fetchSchedules = async () => {
    scheduleLoading.value = true;
    try {
      const res = await getScheduleList();
      schedules.value = res.data || [];
    } catch (error) {
      Message.error('加载失败');
    } finally {
      scheduleLoading.value = false;
    }
  };

  const fetchRecords = async () => {
    recordLoading.value = true;
    try {
      const res = await getApprovalRecords(recordFilter);
      records.value = res.data || [];
    } catch (error) {
      Message.error('加载失败');
    } finally {
      recordLoading.value = false;
    }
  };

  const fetchModels = async () => {
    try {
      const res = await getModelList();
      models.value = res.data.items || [];
    } catch (error) {
      Message.error('加载模型失败');
    }
  };

  // 工作流操作
  const handleAddWorkflow = () => {
    workflowModalTitle.value = '新增流程';
    workflowForm.value = {
      name: '',
      model_id: undefined,
      nodes: [{ name: '', approver_id: undefined }],
      status: 1,
    };
    workflowModalVisible.value = true;
  };

  const handleEditWorkflow = (record: any) => {
    workflowModalTitle.value = '编辑流程';
    workflowForm.value = { ...record };
    workflowModalVisible.value = true;
  };

  const handleAddNode = () => {
    workflowForm.value.nodes.push({ name: '', approver_id: undefined });
  };

  const handleWorkflowSubmit = async () => {
    try {
      if (workflowForm.value.id) {
        await updateWorkflow(workflowForm.value.id, workflowForm.value);
        Message.success('更新成功');
      } else {
        await createWorkflow(workflowForm.value);
        Message.success('创建成功');
      }
      workflowModalVisible.value = false;
      await fetchWorkflows();
      return true;
    } catch (error) {
      Message.error('操作失败');
      return false;
    }
  };

  const handleToggleStatus = async (record: any) => {
    try {
      await updateWorkflow(record.id, { status: record.status === 1 ? 0 : 1 });
      Message.success('操作成功');
      await fetchWorkflows();
    } catch (error) {
      Message.error('操作失败');
    }
  };

  const handleDeleteWorkflow = async (id: number) => {
    try {
      await deleteWorkflow(id);
      Message.success('删除成功');
      await fetchWorkflows();
    } catch (error) {
      Message.error('删除失败');
    }
  };

  // 定时发布操作
  const handleEditSchedule = (record: any) => {
    Message.info('编辑定时发布功能开发中');
  };

  const handleCancelSchedule = async (id: number) => {
    try {
      await cancelSchedule(id);
      Message.success('取消成功');
      await fetchSchedules();
    } catch (error) {
      Message.error('取消失败');
    }
  };

  // 审批操作
  const handleViewRecord = (record: any) => {
    currentRecord.value = record;
    recordDetailVisible.value = true;
  };

  const handleApprove = (record: any, action: number) => {
    approveRecordId.value = record.id;
    approveAction.value = action;
    approveRemark.value = '';
    approveModalVisible.value = true;
  };

  const handleApproveSubmit = async () => {
    try {
      await approveContent(approveRecordId.value!, {
        status: approveAction.value,
        remark: approveRemark.value,
      });
      Message.success('审批成功');
      approveModalVisible.value = false;
      await fetchRecords();
      return true;
    } catch (error) {
      Message.error('审批失败');
      return false;
    }
  };

  onMounted(() => {
    fetchWorkflows();
    fetchSchedules();
    fetchRecords();
    fetchModels();
  });
</script>

<style scoped lang="less">
  .workflow-container {
    padding: 20px;
  }

  .header-actions {
    margin-bottom: 20px;
  }

  .node-item {
    margin-bottom: 12px;
  }
</style>
