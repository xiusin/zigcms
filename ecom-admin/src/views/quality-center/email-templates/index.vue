/**
 * 邮件模板管理页面
 * 【功能】邮件模板CRUD、HTML可视化编辑、实时预览、变量管理
 * 【高级特性】HTML编辑器、变量标签插入、实时预览、场景筛选
 */
<template>
  <div class="email-templates-page">
    <!-- 顶部操作栏 -->
    <div class="page-header">
      <div class="header-left">
        <a-space>
          <icon-email :style="{ fontSize: '20px', color: '#165DFF' }" />
          <span class="page-title">邮件模板管理</span>
          <a-tag color="blue" size="small">{{ store.emailTemplates.length }} 个模板</a-tag>
        </a-space>
      </div>
      <div class="header-right">
        <a-space>
          <a-button size="small" @click="fetchData" :loading="store.loading.emailTemplates">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
          <a-button type="primary" size="small" @click="openCreateModal">
            <template #icon><icon-plus /></template>
            新建模板
          </a-button>
        </a-space>
      </div>
    </div>

    <!-- 模板列表 -->
    <a-table
      :data="store.emailTemplates"
      :loading="store.loading.emailTemplates"
      :pagination="false"
      row-key="id"
      :bordered="false"
      stripe
    >
      <template #columns>
        <a-table-column title="模板名称" data-index="name" :width="180">
          <template #cell="{ record }">
            <a-space>
              <span class="tpl-name">{{ record.name }}</span>
              <a-tag v-if="record.is_default" color="arcoblue" size="small">默认</a-tag>
            </a-space>
          </template>
        </a-table-column>
        <a-table-column title="邮件主题" data-index="subject" :width="260" ellipsis />
        <a-table-column title="使用场景" data-index="scene" :width="120">
          <template #cell="{ record }">
            <a-tag :color="sceneColor(record.scene)" size="small">{{ sceneLabel(record.scene) }}</a-tag>
          </template>
        </a-table-column>
        <a-table-column title="变量数" :width="80">
          <template #cell="{ record }">
            <a-tag size="small">{{ record.variables?.length || 0 }}</a-tag>
          </template>
        </a-table-column>
        <a-table-column title="创建人" data-index="created_by" :width="100" />
        <a-table-column title="创建时间" data-index="created_at" :width="160" />
        <a-table-column title="操作" :width="200" fixed="right">
          <template #cell="{ record }">
            <a-space>
              <a-button size="mini" type="text" @click="openPreview(record)">
                <template #icon><icon-eye /></template>
                预览
              </a-button>
              <a-button size="mini" type="text" @click="openEditModal(record)">
                <template #icon><icon-edit /></template>
                编辑
              </a-button>
              <a-popconfirm content="确定删除该邮件模板？" @ok="handleDelete(record.id)">
                <a-button size="mini" type="text" status="danger">
                  <template #icon><icon-delete /></template>
                  删除
                </a-button>
              </a-popconfirm>
            </a-space>
          </template>
        </a-table-column>
      </template>
    </a-table>

    <!-- 新建/编辑 Modal -->
    <a-modal
      v-model:visible="showFormModal"
      :title="isEdit ? '编辑邮件模板' : '新建邮件模板'"
      :width="900"
      @before-ok="handleFormSubmit"
      :ok-loading="store.submitting"
      unmount-on-close
    >
      <a-form :model="formData" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="name" label="模板名称" :rules="[{ required: true, message: '请输入模板名称' }]">
              <a-input v-model="formData.name" placeholder="请输入模板名称" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="scene" label="使用场景" :rules="[{ required: true, message: '请选择使用场景' }]">
              <a-select v-model="formData.scene" placeholder="选择场景">
                <a-option value="daily_report">日报</a-option>
                <a-option value="weekly_report">周报</a-option>
                <a-option value="monthly_report">月报</a-option>
                <a-option value="alert">告警</a-option>
                <a-option value="custom">自定义</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item field="subject" label="邮件主题" :rules="[{ required: true, message: '请输入邮件主题' }]">
          <a-input v-model="formData.subject" placeholder="邮件主题，支持 {{变量名}} 格式">
            <template #suffix>
              <a-tooltip content="使用 {{变量名}} 插入动态变量">
                <icon-question-circle style="color: var(--color-text-3)" />
              </a-tooltip>
            </template>
          </a-input>
        </a-form-item>

        <!-- 变量管理 -->
        <a-form-item label="模板变量">
          <div class="variables-section">
            <a-tag
              v-for="(v, i) in formData.variables"
              :key="i"
              closable
              @close="formData.variables.splice(i, 1)"
              color="arcoblue"
              size="small"
              class="var-tag"
            >
              {{ '{{' + v + '}}' }}
            </a-tag>
            <a-input-group>
              <a-input v-model="newVariable" placeholder="输入变量名" size="small" style="width: 140px" @keyup.enter="addVariable" />
              <a-button size="small" type="primary" @click="addVariable">添加</a-button>
            </a-input-group>
          </div>
        </a-form-item>

        <!-- HTML编辑区域 -->
        <a-form-item field="body_html" label="邮件正文 (HTML)">
          <div class="html-editor-wrapper">
            <div class="editor-toolbar">
              <a-space>
                <a-tooltip v-for="v in formData.variables" :key="v" :content="`插入 {{${v}}}`">
                  <a-button size="mini" @click="insertVariable(v)">{{ '{{' + v + '}}' }}</a-button>
                </a-tooltip>
              </a-space>
            </div>
            <a-textarea
              v-model="formData.body_html"
              placeholder="请输入邮件HTML正文"
              :auto-size="{ minRows: 12, maxRows: 20 }"
              class="html-editor"
            />
          </div>
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="is_default" label="设为默认">
              <a-switch v-model="formData.is_default" />
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>
    </a-modal>

    <!-- 预览 Drawer -->
    <a-drawer v-model:visible="showPreview" title="邮件模板预览" :width="660" unmount-on-close>
      <div v-if="previewLoading" style="text-align: center; padding: 40px">
        <a-spin tip="加载预览..." />
      </div>
      <div v-else class="email-preview">
        <div class="preview-meta">
          <div><strong>主题:</strong> {{ previewRecord?.subject }}</div>
          <div><strong>场景:</strong> {{ sceneLabel(previewRecord?.scene || '') }}</div>
          <div><strong>变量:</strong>
            <a-tag v-for="v in previewRecord?.variables" :key="v" size="small" color="blue">{{ v }}</a-tag>
          </div>
        </div>
        <a-divider />
        <div class="preview-body" v-html="previewHtml" />
      </div>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import type { EmailTemplate, EmailTemplateParams } from '@/types/quality-center';

const store = useQualityCenterStore();

const showFormModal = ref(false);
const showPreview = ref(false);
const isEdit = ref(false);
const editingId = ref<number | null>(null);
const previewRecord = ref<EmailTemplate | null>(null);
const previewHtml = ref('');
const previewLoading = ref(false);
const newVariable = ref('');

const defaultForm: EmailTemplateParams & { is_default: boolean } = {
  name: '',
  subject: '',
  body_html: '',
  variables: [],
  is_default: false,
  scene: 'daily_report',
};

const formData = ref<EmailTemplateParams & { is_default: boolean }>({ ...defaultForm, variables: [] });

function sceneLabel(scene: string): string {
  const map: Record<string, string> = {
    daily_report: '日报', weekly_report: '周报', monthly_report: '月报', alert: '告警', custom: '自定义',
  };
  return map[scene] || scene;
}

function sceneColor(scene: string): string {
  const map: Record<string, string> = {
    daily_report: 'blue', weekly_report: 'purple', monthly_report: 'green', alert: 'red', custom: 'gray',
  };
  return map[scene] || 'gray';
}

function openCreateModal() {
  isEdit.value = false;
  editingId.value = null;
  formData.value = { ...defaultForm, variables: [] };
  showFormModal.value = true;
}

function openEditModal(record: EmailTemplate) {
  isEdit.value = true;
  editingId.value = record.id;
  formData.value = {
    name: record.name,
    subject: record.subject,
    body_html: record.body_html,
    variables: [...(record.variables || [])],
    is_default: record.is_default,
    scene: record.scene,
  };
  showFormModal.value = true;
}

async function openPreview(record: EmailTemplate) {
  previewRecord.value = record;
  showPreview.value = true;
  previewLoading.value = true;
  try {
    await store.previewEmail(record.id);
    previewHtml.value = store.emailPreviewHtml;
  } catch {
    previewHtml.value = record.body_html;
  } finally {
    previewLoading.value = false;
  }
  console.log(`[邮件模板][预览][${record.name}]`);
}

async function handleFormSubmit(done: (closed: boolean) => void) {
  if (!formData.value.name.trim()) { Message.warning('请输入模板名称'); done(false); return; }
  if (!formData.value.subject.trim()) { Message.warning('请输入邮件主题'); done(false); return; }
  if (!formData.value.body_html.trim()) { Message.warning('请输入邮件正文'); done(false); return; }

  try {
    if (isEdit.value && editingId.value) {
      await store.editEmailTemplate(editingId.value, formData.value);
      Message.success('模板已更新');
    } else {
      await store.addEmailTemplate(formData.value);
      Message.success('模板已创建');
    }
    done(true);
  } catch {
    Message.error('操作失败');
    done(false);
  }
}

async function handleDelete(id: number) {
  try {
    await store.removeEmailTemplate(id);
    Message.success('模板已删除');
  } catch {
    Message.error('删除失败');
  }
}

function addVariable() {
  const name = newVariable.value.trim();
  if (!name) return;
  if (formData.value.variables?.includes(name)) {
    Message.warning('变量已存在');
    return;
  }
  formData.value.variables = [...(formData.value.variables || []), name];
  newVariable.value = '';
}

function insertVariable(name: string) {
  formData.value.body_html += `{{${name}}}`;
}

async function fetchData() {
  await store.fetchEmailTemplates(true);
}

onMounted(async () => {
  await store.fetchEmailTemplates();
  console.log('[质量中心][邮件模板管理][页面加载完成]');
});
</script>

<style lang="less" scoped>
.email-templates-page {
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
  .page-title { font-size: 16px; font-weight: 600; color: var(--color-text-1); }
}
.tpl-name { font-weight: 500; }
.variables-section {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  align-items: center;
  .var-tag { cursor: default; }
}
.html-editor-wrapper {
  border: 1px solid var(--color-border);
  border-radius: 6px;
  overflow: hidden;
  .editor-toolbar {
    padding: 6px 10px;
    background: var(--color-fill-2);
    border-bottom: 1px solid var(--color-border);
  }
  .html-editor {
    :deep(textarea) {
      font-family: 'Fira Code', 'Consolas', monospace;
      font-size: 12px;
      line-height: 1.6;
      border: none;
      border-radius: 0;
    }
  }
}
.email-preview {
  .preview-meta {
    display: flex;
    flex-direction: column;
    gap: 8px;
    font-size: 13px;
    color: var(--color-text-2);
  }
  .preview-body {
    border: 1px solid var(--color-border);
    border-radius: 8px;
    overflow: hidden;
    min-height: 300px;
    background: #fff;
    :deep(*) { max-width: 100%; }
  }
}
</style>
