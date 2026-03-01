/**
 * 定时报表管理页面
 * 【功能】创建/编辑/删除定时报表、启用/禁用、手动触发、查看执行历史
 * 【高级特性】Arco Design表格+表单联动+状态切换+二次确认
 */
<template>
  <div class="scheduled-reports">
    <!-- 顶部操作栏 -->
    <div class="page-header">
      <div class="header-left">
        <a-space>
          <icon-calendar :style="{ fontSize: '20px', color: '#165DFF' }" />
          <span class="page-title">定时报表</span>
          <a-tag color="arcoblue" size="small">{{ store.scheduledReports.length }} 个任务</a-tag>
        </a-space>
      </div>
      <div class="header-right">
        <a-space>
          <a-button size="small" @click="fetchData" :loading="store.loading.scheduledReports">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
          <a-button type="primary" size="small" @click="openCreateModal">
            <template #icon><icon-plus /></template>
            新建定时报表
          </a-button>
        </a-space>
      </div>
    </div>

    <!-- 报表列表 -->
    <a-card class="report-list-card">
      <a-table
        :data="store.scheduledReports"
        :loading="store.loading.scheduledReports"
        :pagination="false"
        row-key="id"
        stripe
      >
        <template #columns>
          <a-table-column title="报表名称" data-index="name" :width="200">
            <template #cell="{ record }">
              <div class="report-name-cell">
                <a-space>
                  <icon-file-pdf v-if="record.format === 'pdf'" style="color: #F53F3F" />
                  <icon-file v-else-if="record.format === 'excel'" style="color: #00B42A" />
                  <icon-copy v-else style="color: #165DFF" />
                  <span class="report-name">{{ record.name }}</span>
                </a-space>
                <div class="report-desc">{{ record.description }}</div>
              </div>
            </template>
          </a-table-column>
          <a-table-column title="类型" data-index="report_type" :width="100" align="center">
            <template #cell="{ record }">
              <a-tag :color="reportTypeColor(record.report_type)" size="small">
                {{ reportTypeLabel(record.report_type) }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="格式" data-index="format" :width="80" align="center">
            <template #cell="{ record }">
              <a-tag size="small">{{ formatLabel(record.format) }}</a-tag>
            </template>
          </a-table-column>
          <a-table-column title="收件人" data-index="recipients" :width="150">
            <template #cell="{ record }">
              <a-tooltip :content="record.recipients.join('\n')">
                <a-avatar-group :size="24" :max-count="3">
                  <a-avatar
                    v-for="(r, i) in record.recipients"
                    :key="i"
                    :style="{ backgroundColor: avatarColors[i % avatarColors.length] }"
                  >
                    {{ r.charAt(0).toUpperCase() }}
                  </a-avatar>
                </a-avatar-group>
              </a-tooltip>
            </template>
          </a-table-column>
          <a-table-column title="状态" data-index="enabled" :width="80" align="center">
            <template #cell="{ record }">
              <a-switch
                :model-value="record.enabled"
                size="small"
                @change="(v: boolean | (string | number | boolean)) => handleToggle(record.id, v as boolean)"
              />
            </template>
          </a-table-column>
          <a-table-column title="上次执行" data-index="last_run_at" :width="160">
            <template #cell="{ record }">
              <div v-if="record.last_run_at">
                <a-space size="mini">
                  <icon-check-circle-fill v-if="record.last_status === 'success'" style="color: #00B42A" />
                  <icon-close-circle-fill v-else-if="record.last_status === 'failed'" style="color: #F53F3F" />
                  <icon-loading v-else style="color: #165DFF" />
                  <span class="time-text">{{ record.last_run_at }}</span>
                </a-space>
              </div>
              <span v-else class="text-muted">从未执行</span>
            </template>
          </a-table-column>
          <a-table-column title="下次执行" data-index="next_run_at" :width="160">
            <template #cell="{ record }">
              <span v-if="record.next_run_at && record.enabled" class="time-text">{{ record.next_run_at }}</span>
              <span v-else class="text-muted">{{ record.enabled ? '计算中...' : '已停用' }}</span>
            </template>
          </a-table-column>
          <a-table-column title="操作" :width="200" align="center" fixed="right">
            <template #cell="{ record }">
              <a-space size="mini">
                <a-button size="mini" type="text" @click="handleTrigger(record)">
                  <template #icon><icon-play-circle /></template>
                  执行
                </a-button>
                <a-button size="mini" type="text" @click="openEditModal(record)">
                  <template #icon><icon-edit /></template>
                  编辑
                </a-button>
                <a-button size="mini" type="text" @click="openHistory(record)">
                  <template #icon><icon-history /></template>
                  历史
                </a-button>
                <a-popconfirm content="确定删除该定时报表？" @ok="handleDelete(record.id)">
                  <a-button size="mini" type="text" status="danger">
                    <template #icon><icon-delete /></template>
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table-column>
        </template>
        <template #empty>
          <a-empty description="暂无定时报表，点击右上角新建">
            <template #image><icon-calendar style="font-size: 48px; color: var(--color-text-4)" /></template>
          </a-empty>
        </template>
      </a-table>
    </a-card>

    <!-- 新建/编辑 Modal -->
    <a-modal
      v-model:visible="showFormModal"
      :title="isEdit ? '编辑定时报表' : '新建定时报表'"
      :width="640"
      @before-ok="handleFormSubmit"
      :ok-loading="store.submitting"
    >
      <a-form :model="formData" ref="formRef" layout="vertical" :rules="formRules">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="name" label="报表名称" :rules="[{ required: true, message: '请输入报表名称' }]">
              <a-input v-model="formData.name" placeholder="请输入报表名称" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="report_type" label="报表类型" :rules="[{ required: true, message: '请选择报表类型' }]">
              <a-select v-model="formData.report_type" placeholder="请选择">
                <a-option value="daily">每日报表</a-option>
                <a-option value="weekly">每周报表</a-option>
                <a-option value="monthly">每月报表</a-option>
                <a-option value="custom">自定义</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item field="description" label="描述">
          <a-textarea v-model="formData.description" placeholder="请输入报表描述" :max-length="200" show-word-limit />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="format" label="报表格式" :rules="[{ required: true, message: '请选择格式' }]">
              <a-radio-group v-model="formData.format">
                <a-radio value="pdf">PDF</a-radio>
                <a-radio value="excel">Excel</a-radio>
                <a-radio value="both">两者都要</a-radio>
              </a-radio-group>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="schedule" label="Cron表达式" :rules="[{ required: true, message: '请输入Cron表达式' }]">
              <a-input v-model="formData.schedule" placeholder="如: 0 9 * * *" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item field="modules" label="包含模块" :rules="[{ required: true, message: '请选择至少一个模块' }]">
          <a-checkbox-group v-model="formData.modules">
            <a-checkbox value="用户管理">用户管理</a-checkbox>
            <a-checkbox value="订单系统">订单系统</a-checkbox>
            <a-checkbox value="支付模块">支付模块</a-checkbox>
            <a-checkbox value="商品管理">商品管理</a-checkbox>
            <a-checkbox value="报表系统">报表系统</a-checkbox>
            <a-checkbox value="权限系统">权限系统</a-checkbox>
          </a-checkbox-group>
        </a-form-item>
        <a-form-item field="recipients" label="收件人邮箱" :rules="[{ required: true, message: '请输入收件人' }]">
          <a-input-tag v-model="formData.recipients" placeholder="输入邮箱后按回车添加" allow-clear />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="watermark_enabled" label="启用水印">
              <a-switch v-model="formData.watermark_enabled" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="enabled" label="创建后立即启用">
              <a-switch v-model="formData.enabled" />
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>
    </a-modal>

    <!-- 执行历史 Drawer -->
    <a-drawer
      v-model:visible="showHistoryDrawer"
      :title="`执行历史 - ${currentReport?.name || ''}`"
      :width="680"
    >
      <a-table
        :data="store.reportHistory"
        :loading="store.loading.reportHistory"
        :pagination="{ pageSize: 10 }"
        row-key="id"
        size="small"
      >
        <template #columns>
          <a-table-column title="状态" data-index="status" :width="80" align="center">
            <template #cell="{ record }">
              <a-tag :color="historyStatusColor(record.status)" size="small">
                {{ historyStatusLabel(record.status) }}
              </a-tag>
            </template>
          </a-table-column>
          <a-table-column title="格式" data-index="format" :width="70" align="center">
            <template #cell="{ record }">
              <span>{{ formatLabel(record.format) }}</span>
            </template>
          </a-table-column>
          <a-table-column title="发送" data-index="sent_count" :width="60" align="center">
            <template #cell="{ record }">
              <span>{{ record.sent_count }}人</span>
            </template>
          </a-table-column>
          <a-table-column title="耗时" data-index="duration_ms" :width="80" align="center">
            <template #cell="{ record }">
              <span v-if="record.duration_ms">{{ (record.duration_ms / 1000).toFixed(1) }}s</span>
              <span v-else class="text-muted">-</span>
            </template>
          </a-table-column>
          <a-table-column title="文件大小" data-index="file_size" :width="90" align="center">
            <template #cell="{ record }">
              <span v-if="record.file_size">{{ (record.file_size / 1024).toFixed(0) }}KB</span>
              <span v-else class="text-muted">-</span>
            </template>
          </a-table-column>
          <a-table-column title="执行时间" data-index="started_at" :width="160">
            <template #cell="{ record }">
              <span class="time-text">{{ record.started_at }}</span>
            </template>
          </a-table-column>
          <a-table-column title="错误信息" data-index="error_message">
            <template #cell="{ record }">
              <span v-if="record.error_message" class="error-text">{{ record.error_message }}</span>
              <span v-else class="text-muted">-</span>
            </template>
          </a-table-column>
        </template>
      </a-table>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import type { ScheduledReport, ScheduledReportParams } from '@/types/quality-center';

const store = useQualityCenterStore();

// ========== 状态 ==========
const showFormModal = ref(false);
const showHistoryDrawer = ref(false);
const isEdit = ref(false);
const editingId = ref<number | null>(null);
const currentReport = ref<ScheduledReport | null>(null);
const formRef = ref();

const defaultFormData: ScheduledReportParams & { watermark_enabled: boolean; enabled: boolean } = {
  name: '',
  description: '',
  report_type: 'weekly',
  schedule: '0 10 * * 1',
  modules: ['用户管理', '订单系统', '支付模块', '商品管理'],
  recipients: [],
  format: 'pdf',
  watermark_enabled: true,
  enabled: true,
};
const formData = ref({ ...defaultFormData });

const formRules = {};
const avatarColors = ['#165DFF', '#00B42A', '#F53F3F', '#FF7D00', '#722ED1', '#0FC6C2'];

// ========== 工具函数 ==========
function reportTypeLabel(type: string) {
  const map: Record<string, string> = { daily: '每日', weekly: '每周', monthly: '每月', custom: '自定义' };
  return map[type] || type;
}
function reportTypeColor(type: string) {
  const map: Record<string, string> = { daily: 'green', weekly: 'arcoblue', monthly: 'purple', custom: 'orangered' };
  return map[type] || 'gray';
}
function formatLabel(format: string) {
  const map: Record<string, string> = { pdf: 'PDF', excel: 'Excel', both: 'PDF+Excel' };
  return map[format] || format;
}
function historyStatusColor(status: string) {
  const map: Record<string, string> = { success: 'green', failed: 'red', running: 'arcoblue' };
  return map[status] || 'gray';
}
function historyStatusLabel(status: string) {
  const map: Record<string, string> = { success: '成功', failed: '失败', running: '执行中' };
  return map[status] || status;
}

// ========== 操作 ==========
function openCreateModal() {
  isEdit.value = false;
  editingId.value = null;
  formData.value = { ...defaultFormData };
  showFormModal.value = true;
}

function openEditModal(record: ScheduledReport) {
  isEdit.value = true;
  editingId.value = record.id;
  formData.value = {
    name: record.name,
    description: record.description,
    report_type: record.report_type,
    schedule: record.schedule,
    modules: [...record.modules],
    recipients: [...record.recipients],
    format: record.format,
    watermark_enabled: record.watermark_enabled,
    enabled: record.enabled,
  };
  showFormModal.value = true;
}

async function handleFormSubmit(done: (closed: boolean) => void) {
  try {
    if (isEdit.value && editingId.value) {
      await store.editScheduledReport(editingId.value, formData.value);
      Message.success('定时报表已更新');
    } else {
      await store.addScheduledReport(formData.value);
      Message.success('定时报表已创建');
    }
    done(true);
  } catch {
    Message.error('操作失败，请重试');
    done(false);
  }
}

async function handleToggle(id: number, enabled: boolean) {
  try {
    await store.toggleReport(id, enabled);
    Message.success(enabled ? '报表已启用' : '报表已停用');
  } catch {
    Message.error('操作失败');
  }
}

function handleTrigger(record: ScheduledReport) {
  Modal.confirm({
    title: '手动触发报表',
    content: `确定立即执行 "${record.name}" ？将向 ${record.recipients.length} 位收件人发送报表。`,
    okText: '立即执行',
    async onOk() {
      try {
        await store.triggerReport(record.id);
        Message.success('报表已触发执行，请在执行历史中查看结果');
      } catch {
        Message.error('触发失败');
      }
    },
  });
}

async function handleDelete(id: number) {
  try {
    await store.removeScheduledReport(id);
    Message.success('定时报表已删除');
  } catch {
    Message.error('删除失败');
  }
}

async function openHistory(record: ScheduledReport) {
  currentReport.value = record;
  showHistoryDrawer.value = true;
  await store.fetchReportHistory({ report_id: record.id });
}

async function fetchData() {
  await store.fetchScheduledReports();
}

// ========== 生命周期 ==========
onMounted(async () => {
  await fetchData();
  console.log('[质量中心][定时报表][页面加载完成]');
});
</script>

<style lang="less" scoped>
.scheduled-reports {
  padding: 16px;
  background: var(--color-bg-1);
  min-height: 100%;
}

.page-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;
  padding: 12px 16px;
  background: var(--color-bg-2);
  border-radius: 8px;
  border: 1px solid var(--color-border);
  .page-title {
    font-size: 16px;
    font-weight: 600;
    color: var(--color-text-1);
  }
}

.report-list-card {
  border-radius: 8px;
}

.report-name-cell {
  .report-name {
    font-weight: 500;
    color: var(--color-text-1);
  }
  .report-desc {
    font-size: 12px;
    color: var(--color-text-3);
    margin-top: 2px;
    max-width: 250px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}

.time-text {
  font-size: 12px;
  color: var(--color-text-2);
}
.text-muted {
  font-size: 12px;
  color: var(--color-text-4);
}
.error-text {
  font-size: 12px;
  color: #F53F3F;
}
</style>
