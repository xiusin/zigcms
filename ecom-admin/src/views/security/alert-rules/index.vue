<template>
  <div class="alert-rules-page">
    <a-page-header title="告警规则" subtitle="配置和管理安全告警规则" />

    <!-- 操作栏 -->
    <div class="action-bar">
      <a-space>
        <a-button type="primary" @click="handleCreate">
          <template #icon><icon-plus /></template>
          新建规则
        </a-button>
        <a-button @click="handleRefresh">
          <template #icon><icon-refresh /></template>
          刷新
        </a-button>
      </a-space>

      <a-space>
        <a-select
          v-model="filters.rule_type"
          placeholder="规则类型"
          allow-clear
          style="width: 150px"
          @change="handleFilterChange"
        >
          <a-option value="brute_force">暴力破解</a-option>
          <a-option value="sql_injection">SQL注入</a-option>
          <a-option value="xss">XSS攻击</a-option>
          <a-option value="csrf">CSRF攻击</a-option>
          <a-option value="rate_limit">频率限制</a-option>
          <a-option value="abnormal_access">异常访问</a-option>
        </a-select>

        <a-select
          v-model="filters.enabled"
          placeholder="状态"
          allow-clear
          style="width: 120px"
          @change="handleFilterChange"
        >
          <a-option :value="true">已启用</a-option>
          <a-option :value="false">已禁用</a-option>
        </a-select>

        <a-input-search
          v-model="filters.keyword"
          placeholder="搜索规则名称"
          style="width: 250px"
          @search="handleSearch"
        />
      </a-space>
    </div>

    <!-- 规则列表 -->
    <a-table
      :data="rules"
      :loading="loading"
      :pagination="pagination"
      @page-change="handlePageChange"
      @page-size-change="handlePageSizeChange"
    >
      <template #columns>
        <a-table-column title="规则名称" data-index="name" :width="200" />
        
        <a-table-column title="类型" data-index="rule_type" :width="120">
          <template #cell="{ record }">
            <a-tag>{{ getRuleTypeText(record.rule_type) }}</a-tag>
          </template>
        </a-table-column>

        <a-table-column title="级别" data-index="level" :width="100">
          <template #cell="{ record }">
            <a-tag :color="getLevelColor(record.level)">
              {{ getLevelText(record.level) }}
            </a-tag>
          </template>
        </a-table-column>

        <a-table-column title="优先级" data-index="priority" :width="100" />

        <a-table-column title="状态" data-index="enabled" :width="100">
          <template #cell="{ record }">
            <a-switch
              :model-value="record.enabled"
              @change="handleToggleEnabled(record)"
            />
          </template>
        </a-table-column>

        <a-table-column title="描述" data-index="description" :width="300" />

        <a-table-column title="创建时间" data-index="created_at" :width="180">
          <template #cell="{ record }">
            {{ formatTime(record.created_at) }}
          </template>
        </a-table-column>

        <a-table-column title="操作" :width="250" fixed="right">
          <template #cell="{ record }">
            <a-space>
              <a-button type="text" size="small" @click="handleTest(record)">
                测试
              </a-button>
              <a-button type="text" size="small" @click="handleEdit(record)">
                编辑
              </a-button>
              <a-button type="text" size="small" @click="handleCopy(record)">
                复制
              </a-button>
              <a-popconfirm
                content="确定删除这条规则吗？"
                @ok="handleDelete(record)"
              >
                <a-button type="text" size="small" status="danger">
                  删除
                </a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </a-table-column>
      </template>
    </a-table>

    <!-- 规则表单对话框 -->
    <RuleFormDialog
      v-model:visible="formVisible"
      :rule="currentRule"
      @success="handleFormSuccess"
    />

    <!-- 规则测试对话框 -->
    <RuleTesterDialog
      v-model:visible="testerVisible"
      :rule="currentRule"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as alertRuleApi from '@/api/alert-rule';
import type { AlertRule } from '@/types/alert-rule';
import RuleFormDialog from './components/RuleFormDialog.vue';
import RuleTesterDialog from './components/RuleTesterDialog.vue';

const loading = ref(false);
const rules = ref<AlertRule[]>([]);
const currentRule = ref<AlertRule | null>(null);
const formVisible = ref(false);
const testerVisible = ref(false);

const filters = reactive({
  rule_type: undefined as string | undefined,
  enabled: undefined as boolean | undefined,
  keyword: '',
});

const pagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0,
});

// 加载规则列表
const loadRules = async () => {
  loading.value = true;
  try {
    const data = await alertRuleApi.getAlertRules({
      rule_type: filters.rule_type,
      enabled: filters.enabled,
      page: pagination.current,
      page_size: pagination.pageSize,
    });
    rules.value = data;
    pagination.total = data.length;
  } catch (error) {
    Message.error('加载规则列表失败');
  } finally {
    loading.value = false;
  }
};

// 刷新
const handleRefresh = () => {
  loadRules();
};

// 筛选变化
const handleFilterChange = () => {
  pagination.current = 1;
  loadRules();
};

// 搜索
const handleSearch = () => {
  pagination.current = 1;
  loadRules();
};

// 分页变化
const handlePageChange = (page: number) => {
  pagination.current = page;
  loadRules();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.pageSize = pageSize;
  pagination.current = 1;
  loadRules();
};

// 新建规则
const handleCreate = () => {
  currentRule.value = null;
  formVisible.value = true;
};

// 编辑规则
const handleEdit = (rule: AlertRule) => {
  currentRule.value = rule;
  formVisible.value = true;
};

// 复制规则
const handleCopy = (rule: AlertRule) => {
  currentRule.value = {
    ...rule,
    id: undefined,
    name: `${rule.name} (副本)`,
  };
  formVisible.value = true;
};

// 测试规则
const handleTest = (rule: AlertRule) => {
  currentRule.value = rule;
  testerVisible.value = true;
};

// 删除规则
const handleDelete = async (rule: AlertRule) => {
  try {
    await alertRuleApi.deleteAlertRule(rule.id!);
    Message.success('删除成功');
    loadRules();
  } catch (error) {
    Message.error('删除失败');
  }
};

// 切换启用状态
const handleToggleEnabled = async (rule: AlertRule) => {
  try {
    if (rule.enabled) {
      await alertRuleApi.disableAlertRule(rule.id!);
      Message.success('已禁用');
    } else {
      await alertRuleApi.enableAlertRule(rule.id!);
      Message.success('已启用');
    }
    loadRules();
  } catch (error) {
    Message.error('操作失败');
  }
};

// 表单成功
const handleFormSuccess = () => {
  formVisible.value = false;
  loadRules();
};

// 工具函数
const getRuleTypeText = (type: string) => {
  const map: Record<string, string> = {
    brute_force: '暴力破解',
    sql_injection: 'SQL注入',
    xss: 'XSS攻击',
    csrf: 'CSRF攻击',
    rate_limit: '频率限制',
    abnormal_access: '异常访问',
    data_leak: '数据泄露',
    permission_denied: '权限拒绝',
    custom: '自定义',
  };
  return map[type] || type;
};

const getLevelColor = (level: string) => {
  const map: Record<string, string> = {
    critical: 'red',
    high: 'orangered',
    medium: 'orange',
    low: 'blue',
  };
  return map[level] || 'gray';
};

const getLevelText = (level: string) => {
  const map: Record<string, string> = {
    critical: '严重',
    high: '高危',
    medium: '中危',
    low: '低危',
  };
  return map[level] || level;
};

const formatTime = (time: string) => {
  return new Date(time).toLocaleString('zh-CN');
};

onMounted(() => {
  loadRules();
});
</script>

<style scoped lang="scss">
.alert-rules-page {
  padding: 20px;

  .action-bar {
    display: flex;
    justify-content: space-between;
    margin-bottom: 20px;
  }
}
</style>
