<template>
  <div class="moderation-rules">
    <a-card title="审核规则管理" :bordered="false">
      <!-- 操作栏 -->
      <div class="action-bar">
        <a-button type="primary" @click="handleCreate">
          <template #icon><icon-plus /></template>
          添加规则
        </a-button>
      </div>

      <!-- 筛选条件 -->
      <a-form :model="queryParams" layout="inline" class="filter-form">
        <a-form-item label="规则类型">
          <a-select
            v-model="queryParams.rule_type"
            placeholder="请选择规则类型"
            style="width: 150px"
            allow-clear
          >
            <a-option value="sensitive_word">敏感词</a-option>
            <a-option value="length">长度</a-option>
            <a-option value="frequency">频率</a-option>
            <a-option value="user_level">用户等级</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="状态">
          <a-select
            v-model="queryParams.status"
            placeholder="请选择状态"
            style="width="150px"
            allow-clear
          >
            <a-option :value="1">启用</a-option>
            <a-option :value="0">禁用</a-option>
          </a-select>
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

      <!-- 规则列表 -->
      <a-table
        :columns="columns"
        :data="tableData"
        :loading="loading"
        :pagination="pagination"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
        row-key="id"
      >
        <template #rule_type="{ record }">
          <a-tag>{{ getRuleTypeText(record.rule_type) }}</a-tag>
        </template>

        <template #action="{ record }">
          <a-tag :color="getActionColor(record.action)">
            {{ getActionText(record.action) }}
          </a-tag>
        </template>

        <template #priority="{ record }">
          <a-tag :color="getPriorityColor(record.priority)">
            {{ record.priority }}
          </a-tag>
        </template>

        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            @change="(value) => handleToggleStatus(record, value)"
          />
        </template>

        <template #created_at="{ record }">
          {{ formatDateTime(record.created_at) }}
        </template>

        <template #actions="{ record }">
          <a-space>
            <a-button
              type="text"
              size="small"
              @click="handleEdit(record)"
            >
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-popconfirm
              content="确定要删除这个规则吗？"
              @ok="handleDelete(record)"
            >
              <a-button
                type="text"
                size="small"
                status="danger"
              >
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 添加/编辑对话框 -->
    <a-modal
      v-model:visible="formVisible"
      :title="formMode === 'create' ? '添加规则' : '编辑规则'"
      @ok="handleFormSubmit"
      @cancel="handleFormCancel"
      width="700px"
    >
      <a-form :model="formData" layout="vertical">
        <a-form-item label="规则名称" required>
          <a-input
            v-model="formData.name"
            placeholder="请输入规则名称"
            :max-length="100"
          />
        </a-form-item>

        <a-form-item label="规则描述">
          <a-textarea
            v-model="formData.description"
            placeholder="请输入规则描述"
            :rows="3"
            :max-length="500"
          />
        </a-form-item>

        <a-form-item label="规则类型" required>
          <a-select
            v-model="formData.rule_type"
            placeholder="请选择规则类型"
          >
            <a-option value="sensitive_word">敏感词</a-option>
            <a-option value="length">长度</a-option>
            <a-option value="frequency">频率</a-option>
            <a-option value="user_level">用户等级</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="规则条件" required>
          <a-textarea
            v-model="conditionsText"
            placeholder='请输入规则条件（JSON格式），例如：{"level": 3}'
            :rows="5"
            :max-length="1000"
          />
        </a-form-item>

        <a-form-item label="处理方式" required>
          <a-select
            v-model="formData.action"
            placeholder="请选择处理方式"
          >
            <a-option value="auto_approve">自动通过</a-option>
            <a-option value="auto_reject">自动拒绝</a-option>
            <a-option value="review">人工审核</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="优先级" required>
          <a-input-number
            v-model="formData.priority"
            placeholder="请输入优先级"
            :min="0"
            :max="100"
            style="width: 100%"
          />
          <div class="form-tip">数字越大优先级越高</div>
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import { moderationRuleApi } from '@/api/moderation';
import type {
  ModerationRule,
  CreateModerationRuleRequest,
  UpdateModerationRuleRequest,
  ModerationRuleQueryParams,
} from '@/types/moderation';
import dayjs from 'dayjs';

// 查询参数
const queryParams = reactive<ModerationRuleQueryParams>({
  page: 1,
  page_size: 20,
});

// 表格数据
const tableData = ref<ModerationRule[]>([]);
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
  { title: '规则名称', dataIndex: 'name', width: 200 },
  { title: '规则类型', dataIndex: 'rule_type', slotName: 'rule_type', width: 120 },
  { title: '处理方式', dataIndex: 'action', slotName: 'action', width: 120 },
  { title: '优先级', dataIndex: 'priority', slotName: 'priority', width: 100 },
  { title: '状态', dataIndex: 'status', slotName: 'status', width: 100 },
  { title: '创建时间', dataIndex: 'created_at', slotName: 'created_at', width: 180 },
  { title: '操作', slotName: 'actions', width: 150, fixed: 'right' },
];

// 表单
const formVisible = ref(false);
const formMode = ref<'create' | 'edit'>('create');
const formData = reactive<CreateModerationRuleRequest | UpdateModerationRuleRequest>({
  name: '',
  description: '',
  rule_type: 'sensitive_word',
  conditions: {},
  action: 'review',
  priority: 0,
});
const currentId = ref<number>();

// 条件文本
const conditionsText = ref('{}');

// 加载列表数据
const loadData = async () => {
  loading.value = true;
  try {
    const { items, total } = await moderationRuleApi.getList(queryParams);
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
    rule_type: undefined,
    status: undefined,
  });
  pagination.current = 1;
  loadData();
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

// 添加
const handleCreate = () => {
  formMode.value = 'create';
  Object.assign(formData, {
    name: '',
    description: '',
    rule_type: 'sensitive_word',
    conditions: {},
    action: 'review',
    priority: 0,
  });
  conditionsText.value = '{}';
  formVisible.value = true;
};

// 编辑
const handleEdit = (record: ModerationRule) => {
  formMode.value = 'edit';
  currentId.value = record.id;
  Object.assign(formData, {
    name: record.name,
    description: record.description,
    rule_type: record.rule_type,
    conditions: record.conditions,
    action: record.action,
    priority: record.priority,
  });
  conditionsText.value = JSON.stringify(record.conditions, null, 2);
  formVisible.value = true;
};

// 提交表单
const handleFormSubmit = async () => {
  if (!formData.name?.trim()) {
    Message.warning('请输入规则名称');
    return;
  }

  try {
    // 解析条件 JSON
    formData.conditions = JSON.parse(conditionsText.value);
  } catch (error) {
    Message.error('规则条件格式错误，请输入有效的 JSON');
    return;
  }

  try {
    if (formMode.value === 'create') {
      await moderationRuleApi.create(formData as CreateModerationRuleRequest);
      Message.success('添加成功');
    } else {
      await moderationRuleApi.update(currentId.value!, formData as UpdateModerationRuleRequest);
      Message.success('更新成功');
    }
    formVisible.value = false;
    loadData();
  } catch (error) {
    Message.error('操作失败');
    console.error('操作失败:', error);
  }
};

// 取消表单
const handleFormCancel = () => {
  formVisible.value = false;
};

// 删除
const handleDelete = async (record: ModerationRule) => {
  try {
    await moderationRuleApi.delete(record.id);
    Message.success('删除成功');
    loadData();
  } catch (error) {
    Message.error('删除失败');
    console.error('删除失败:', error);
  }
};

// 切换状态
const handleToggleStatus = async (record: ModerationRule, value: boolean) => {
  try {
    await moderationRuleApi.toggleStatus(record.id, value ? 1 : 0);
    Message.success('状态已更新');
    loadData();
  } catch (error) {
    Message.error('状态更新失败');
    console.error('状态更新失败:', error);
  }
};

// 获取规则类型文本
const getRuleTypeText = (type: string) => {
  const texts: Record<string, string> = {
    sensitive_word: '敏感词',
    length: '长度',
    frequency: '频率',
    user_level: '用户等级',
  };
  return texts[type] || type;
};

// 获取处理方式颜色
const getActionColor = (action: string) => {
  const colors: Record<string, string> = {
    auto_approve: 'green',
    auto_reject: 'red',
    review: 'orange',
  };
  return colors[action] || 'gray';
};

// 获取处理方式文本
const getActionText = (action: string) => {
  const texts: Record<string, string> = {
    auto_approve: '自动通过',
    auto_reject: '自动拒绝',
    review: '人工审核',
  };
  return texts[action] || action;
};

// 获取优先级颜色
const getPriorityColor = (priority: number) => {
  if (priority >= 80) return 'red';
  if (priority >= 50) return 'orange';
  return 'blue';
};

// 格式化日期时间
const formatDateTime = (dateTime: string) => {
  return dayjs(dateTime).format('YYYY-MM-DD HH:mm:ss');
};

// 初始化
onMounted(() => {
  loadData();
});
</script>

<style scoped lang="scss">
.moderation-rules {
  .action-bar {
    margin-bottom: 16px;
  }

  .filter-form {
    margin-bottom: 16px;
  }

  .form-tip {
    margin-top: 4px;
    font-size: 12px;
    color: var(--color-text-3);
  }
}
</style>
