<template>
  <div class="alerts-page">
    <a-page-header title="告警管理" subtitle="管理安全告警规则和历史" />
    
    <!-- 统计卡片 -->
    <a-row :gutter="16" class="stats-row">
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="今日告警"
            :value="stats.todayAlerts"
            :value-style="{ color: '#f53f3f' }"
          >
            <template #prefix>
              <icon-notification />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="活跃规则"
            :value="stats.activeRules"
            :value-style="{ color: '#165dff' }"
          >
            <template #prefix>
              <icon-settings />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="待处理"
            :value="stats.pendingAlerts"
            :value-style="{ color: '#ff7d00' }"
          >
            <template #prefix>
              <icon-exclamation-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
      
      <a-col :span="6">
        <a-card :bordered="false" class="stat-card">
          <a-statistic
            title="已处理"
            :value="stats.resolvedAlerts"
            :value-style="{ color: '#00b42a' }"
          >
            <template #prefix>
              <icon-check-circle />
            </template>
          </a-statistic>
        </a-card>
      </a-col>
    </a-row>
    
    <!-- 标签页 -->
    <a-tabs v-model:active-key="activeTab" type="card">
      <!-- 告警规则 -->
      <a-tab-pane key="rules" title="告警规则">
        <a-card :bordered="false">
          <template #extra>
            <a-button type="primary" @click="showRuleForm()">
              <template #icon><icon-plus /></template>
              新增规则
            </a-button>
          </template>
          
          <a-table
            :data="rules"
            :loading="rulesLoading"
            :pagination="rulesPagination"
            @page-change="handleRulesPageChange"
          >
            <template #columns>
              <a-table-column title="规则名称" data-index="name" :width="200" />
              <a-table-column title="事件类型" data-index="event_type" :width="150">
                <template #cell="{ record }">
                  {{ getEventTypeName(record.event_type) }}
                </template>
              </a-table-column>
              <a-table-column title="阈值" data-index="threshold" :width="100" />
              <a-table-column title="时间窗口" data-index="time_window" :width="120">
                <template #cell="{ record }">
                  {{ record.time_window }}秒
                </template>
              </a-table-column>
              <a-table-column title="通知方式" data-index="notification_channels" :width="150">
                <template #cell="{ record }">
                  <a-space>
                    <a-tag v-for="channel in record.notification_channels" :key="channel">
                      {{ getChannelName(channel) }}
                    </a-tag>
                  </a-space>
                </template>
              </a-table-column>
              <a-table-column title="状态" data-index="enabled" :width="100">
                <template #cell="{ record }">
                  <a-switch
                    v-model="record.enabled"
                    @change="handleRuleToggle(record)"
                  />
                </template>
              </a-table-column>
              <a-table-column title="操作" :width="150" fixed="right">
                <template #cell="{ record }">
                  <a-space>
                    <a-button type="text" size="small" @click="showRuleForm(record)">
                      编辑
                    </a-button>
                    <a-popconfirm
                      content="确定删除此规则吗？"
                      @ok="handleDeleteRule(record.id)"
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
        </a-card>
      </a-tab-pane>
      
      <!-- 告警历史 -->
      <a-tab-pane key="history" title="告警历史">
        <a-card :bordered="false">
          <template #extra>
            <a-space>
              <a-select
                v-model="historyFilter.status"
                placeholder="状态"
                style="width: 120px"
                allow-clear
                @change="loadHistory"
              >
                <a-option value="pending">待处理</a-option>
                <a-option value="resolved">已处理</a-option>
                <a-option value="ignored">已忽略</a-option>
              </a-select>
              <a-button @click="loadHistory">
                <template #icon><icon-refresh /></template>
                刷新
              </a-button>
            </a-space>
          </template>
          
          <a-table
            :data="history"
            :loading="historyLoading"
            :pagination="historyPagination"
            @page-change="handleHistoryPageChange"
          >
            <template #columns>
              <a-table-column title="时间" data-index="created_at" :width="180">
                <template #cell="{ record }">
                  {{ formatTime(record.created_at) }}
                </template>
              </a-table-column>
              <a-table-column title="规则名称" data-index="rule_name" :width="200" />
              <a-table-column title="事件类型" data-index="event_type" :width="150">
                <template #cell="{ record }">
                  {{ getEventTypeName(record.event_type) }}
                </template>
              </a-table-column>
              <a-table-column title="触发次数" data-index="trigger_count" :width="100" />
              <a-table-column title="描述" data-index="description" />
              <a-table-column title="状态" data-index="status" :width="100">
                <template #cell="{ record }">
                  <a-tag :color="getStatusColor(record.status)">
                    {{ getStatusName(record.status) }}
                  </a-tag>
                </template>
              </a-table-column>
              <a-table-column title="操作" :width="200" fixed="right">
                <template #cell="{ record }">
                  <a-space>
                    <a-button
                      v-if="record.status === 'pending'"
                      type="text"
                      size="small"
                      @click="handleResolveAlert(record.id)"
                    >
                      标记已处理
                    </a-button>
                    <a-button
                      v-if="record.status === 'pending'"
                      type="text"
                      size="small"
                      @click="handleIgnoreAlert(record.id)"
                    >
                      忽略
                    </a-button>
                    <a-button type="text" size="small" @click="viewAlertDetails(record)">
                      详情
                    </a-button>
                  </a-space>
                </template>
              </a-table-column>
            </template>
          </a-table>
        </a-card>
      </a-tab-pane>
    </a-tabs>
    
    <!-- 规则表单弹窗 -->
    <a-modal
      v-model:visible="ruleFormVisible"
      :title="ruleFormMode === 'create' ? '新增规则' : '编辑规则'"
      @ok="handleSaveRule"
      @cancel="handleCancelRule"
    >
      <a-form :model="ruleForm" layout="vertical">
        <a-form-item label="规则名称" required>
          <a-input v-model="ruleForm.name" placeholder="请输入规则名称" />
        </a-form-item>
        <a-form-item label="事件类型" required>
          <a-select v-model="ruleForm.event_type" placeholder="请选择事件类型">
            <a-option value="login_failed">登录失败</a-option>
            <a-option value="permission_denied">权限拒绝</a-option>
            <a-option value="rate_limit_exceeded">速率限制</a-option>
            <a-option value="sql_injection_attempt">SQL注入</a-option>
            <a-option value="xss_attack_attempt">XSS攻击</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="阈值" required>
          <a-input-number
            v-model="ruleForm.threshold"
            :min="1"
            placeholder="触发告警的次数"
          />
        </a-form-item>
        <a-form-item label="时间窗口（秒）" required>
          <a-input-number
            v-model="ruleForm.time_window"
            :min="1"
            placeholder="统计时间窗口"
          />
        </a-form-item>
        <a-form-item label="通知方式" required>
          <a-checkbox-group v-model="ruleForm.notification_channels">
            <a-checkbox value="email">邮件</a-checkbox>
            <a-checkbox value="sms">短信</a-checkbox>
            <a-checkbox value="dingtalk">钉钉</a-checkbox>
            <a-checkbox value="wechat">企业微信</a-checkbox>
          </a-checkbox-group>
        </a-form-item>
        <a-form-item label="通知接收人">
          <a-input v-model="ruleForm.recipients" placeholder="多个接收人用逗号分隔" />
        </a-form-item>
        <a-form-item label="描述">
          <a-textarea
            v-model="ruleForm.description"
            placeholder="请输入规则描述"
            :rows="3"
          />
        </a-form-item>
      </a-form>
    </a-modal>
    
    <!-- 告警详情抽屉 -->
    <a-drawer
      v-model:visible="alertDetailsVisible"
      title="告警详情"
      :width="600"
      :footer="false"
    >
      <a-descriptions v-if="selectedAlert" :column="1" bordered>
        <a-descriptions-item label="告警ID">
          {{ selectedAlert.id }}
        </a-descriptions-item>
        <a-descriptions-item label="规则名称">
          {{ selectedAlert.rule_name }}
        </a-descriptions-item>
        <a-descriptions-item label="事件类型">
          {{ getEventTypeName(selectedAlert.event_type) }}
        </a-descriptions-item>
        <a-descriptions-item label="触发次数">
          {{ selectedAlert.trigger_count }}
        </a-descriptions-item>
        <a-descriptions-item label="描述">
          {{ selectedAlert.description }}
        </a-descriptions-item>
        <a-descriptions-item label="详情">
          <pre class="json-pre">{{ formatJSON(selectedAlert.details) }}</pre>
        </a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="getStatusColor(selectedAlert.status)">
            {{ getStatusName(selectedAlert.status) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="触发时间">
          {{ formatTime(selectedAlert.created_at) }}
        </a-descriptions-item>
        <a-descriptions-item v-if="selectedAlert.resolved_at" label="处理时间">
          {{ formatTime(selectedAlert.resolved_at) }}
        </a-descriptions-item>
        <a-descriptions-item v-if="selectedAlert.resolved_by" label="处理人">
          {{ selectedAlert.resolved_by }}
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, onMounted, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  IconNotification,
  IconSettings,
  IconExclamationCircle,
  IconCheckCircle,
  IconPlus,
  IconRefresh
} from '@arco-design/web-vue/es/icon';
import { useSecurityStore } from '@/store/modules/security';
import type { Alert, HandleAlertDto } from '@/types/security';

// Store
const securityStore = useSecurityStore();

// 统计数据
const stats = computed(() => ({
  todayAlerts: securityStore.alerts.filter(a => {
    const today = new Date().toDateString();
    return new Date(a.created_at).toDateString() === today;
  }).length,
  activeRules: 8, // TODO: 从后端获取
  pendingAlerts: securityStore.pendingAlertsCount,
  resolvedAlerts: securityStore.alerts.filter(a => a.status === 'resolved').length
}));

// 标签页
const activeTab = ref('history'); // 默认显示告警历史

// 批量选择
const selectedAlertIds = ref<number[]>([]);

// 规则列表
const rules = ref<any[]>([]);
const rulesLoading = ref(false);
const rulesPagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0
});

// 告警历史
const history = ref<any[]>([]);
const historyLoading = ref(false);
const historyPagination = reactive({
  current: 1,
  pageSize: 20,
  total: 0
});
const historyFilter = reactive({
  status: ''
});

// 规则表单
const ruleFormVisible = ref(false);
const ruleFormMode = ref<'create' | 'edit'>('create');
const ruleForm = reactive({
  id: null as number | null,
  name: '',
  event_type: '',
  threshold: 10,
  time_window: 60,
  notification_channels: [] as string[],
  recipients: '',
  description: ''
});

// 告警详情
const alertDetailsVisible = ref(false);
const selectedAlert = ref<any>(null);

onMounted(() => {
  loadStats();
  loadRules();
  loadHistory();
});

// 加载统计数据
async function loadStats() {
  // TODO: 调用API
  stats.value = {
    todayAlerts: 12,
    activeRules: 8,
    pendingAlerts: 5,
    resolvedAlerts: 7
  };
}

// 加载规则列表
async function loadRules() {
  rulesLoading.value = true;
  try {
    // TODO: 调用API
    rules.value = [];
    rulesPagination.total = 0;
  } finally {
    rulesLoading.value = false;
  }
}

// 加载告警历史
async function loadHistory() {
  historyLoading.value = true;
  try {
    // TODO: 调用API
    history.value = [];
    historyPagination.total = 0;
  } finally {
    historyLoading.value = false;
  }
}

// 显示规则表单
function showRuleForm(record?: any) {
  if (record) {
    ruleFormMode.value = 'edit';
    Object.assign(ruleForm, record);
  } else {
    ruleFormMode.value = 'create';
    Object.assign(ruleForm, {
      id: null,
      name: '',
      event_type: '',
      threshold: 10,
      time_window: 60,
      notification_channels: [],
      recipients: '',
      description: ''
    });
  }
  ruleFormVisible.value = true;
}

// 保存规则
async function handleSaveRule() {
  try {
    // TODO: 调用API
    Message.success(ruleFormMode.value === 'create' ? '创建成功' : '更新成功');
    ruleFormVisible.value = false;
    loadRules();
  } catch (error) {
    Message.error('保存失败');
  }
}

// 取消规则表单
function handleCancelRule() {
  ruleFormVisible.value = false;
}

// 切换规则状态
async function handleRuleToggle(record: any) {
  try {
    // TODO: 调用API
    Message.success(record.enabled ? '已启用' : '已禁用');
  } catch (error) {
    Message.error('操作失败');
    record.enabled = !record.enabled;
  }
}

// 删除规则
async function handleDeleteRule(id: number) {
  try {
    // TODO: 调用API
    Message.success('删除成功');
    loadRules();
  } catch (error) {
    Message.error('删除失败');
  }
}

// 标记已处理
async function handleResolveAlert(id: number) {
  try {
    // TODO: 调用API
    Message.success('已标记为已处理');
    loadHistory();
    loadStats();
  } catch (error) {
    Message.error('操作失败');
  }
}

// 忽略告警
async function handleIgnoreAlert(id: number) {
  try {
    // TODO: 调用API
    Message.success('已忽略');
    loadHistory();
    loadStats();
  } catch (error) {
    Message.error('操作失败');
  }
}

// 查看告警详情
function viewAlertDetails(record: any) {
  selectedAlert.value = record;
  alertDetailsVisible.value = true;
}

// 分页变化
function handleRulesPageChange(page: number) {
  rulesPagination.current = page;
  loadRules();
}

function handleHistoryPageChange(page: number) {
  historyPagination.current = page;
  loadHistory();
}

// 格式化时间
function formatTime(time: string) {
  return new Date(time).toLocaleString('zh-CN');
}

// 格式化 JSON
function formatJSON(json: string) {
  try {
    return JSON.stringify(JSON.parse(json), null, 2);
  } catch {
    return json;
  }
}

// 获取事件类型名称
function getEventTypeName(type: string) {
  const names: Record<string, string> = {
    login_failed: '登录失败',
    permission_denied: '权限拒绝',
    rate_limit_exceeded: '速率限制',
    sql_injection_attempt: 'SQL注入',
    xss_attack_attempt: 'XSS攻击'
  };
  return names[type] || type;
}

// 获取通知方式名称
function getChannelName(channel: string) {
  const names: Record<string, string> = {
    email: '邮件',
    sms: '短信',
    dingtalk: '钉钉',
    wechat: '企业微信'
  };
  return names[channel] || channel;
}

// 获取状态颜色
function getStatusColor(status: string) {
  const colors: Record<string, string> = {
    pending: 'orange',
    resolved: 'green',
    ignored: 'gray'
  };
  return colors[status] || 'blue';
}

// 获取状态名称
function getStatusName(status: string) {
  const names: Record<string, string> = {
    pending: '待处理',
    resolved: '已处理',
    ignored: '已忽略'
  };
  return names[status] || status;
}
</script>

<style scoped lang="less">
.alerts-page {
  padding: 20px;
  
  .stats-row {
    margin-bottom: 16px;
    
    .stat-card {
      :deep(.arco-statistic-title) {
        font-size: 14px;
        color: var(--color-text-2);
      }
      
      :deep(.arco-statistic-value) {
        font-size: 28px;
        font-weight: 600;
      }
    }
  }
  
  .json-pre {
    background: var(--color-fill-2);
    padding: 12px;
    border-radius: 4px;
    font-size: 12px;
    max-height: 300px;
    overflow: auto;
  }
}
</style>
