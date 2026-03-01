/**
 * 报表模板编辑器页面
 * 【功能】可视化拖拽模板区块、启用/禁用区块、模板CRUD、预览
 * 【高级特性】vuedraggable拖拽排序、实时预览、模板克隆
 */
<template>
  <div class="report-templates-page">
    <!-- 顶部操作栏 -->
    <div class="page-header">
      <div class="header-left">
        <a-space>
          <icon-file :style="{ fontSize: '20px', color: '#722ED1' }" />
          <span class="page-title">报表模板编辑器</span>
          <a-tag color="purple" size="small">{{ store.reportTemplates.length }} 个模板</a-tag>
        </a-space>
      </div>
      <div class="header-right">
        <a-space>
          <a-button size="small" @click="fetchData" :loading="store.loading.reportTemplates">
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

    <!-- 模板卡片列表 -->
    <a-row :gutter="16">
      <a-col :span="8" v-for="tpl in store.reportTemplates" :key="tpl.id">
        <a-card class="template-card" hoverable>
          <template #title>
            <a-space>
              <span class="tpl-name">{{ tpl.name }}</span>
              <a-tag v-if="tpl.is_default" color="arcoblue" size="small">默认</a-tag>
            </a-space>
          </template>
          <template #extra>
            <a-dropdown @select="(v: string | number | Record<string, unknown> | undefined) => handleCardAction(v as string, tpl)">
              <a-button size="mini" type="text"><icon-more /></a-button>
              <template #content>
                <a-doption value="edit"><icon-edit /> 编辑</a-doption>
                <a-doption value="preview"><icon-eye /> 预览</a-doption>
                <a-doption value="delete"><icon-delete /> 删除</a-doption>
              </template>
            </a-dropdown>
          </template>
          <div class="tpl-desc">{{ tpl.description }}</div>
          <div class="tpl-blocks">
            <a-tag v-for="block in tpl.blocks.filter(b => b.enabled).slice(0, 4)" :key="block.id" size="small" color="gray">
              {{ block.title }}
            </a-tag>
            <a-tag v-if="tpl.blocks.filter(b => b.enabled).length > 4" size="small">
              +{{ tpl.blocks.filter(b => b.enabled).length - 4 }}
            </a-tag>
          </div>
          <div class="tpl-meta">
            <span>{{ tpl.orientation === 'landscape' ? '横向' : '纵向' }}</span>
            <a-divider direction="vertical" />
            <span>{{ tpl.watermark ? '含水印' : '无水印' }}</span>
            <a-divider direction="vertical" />
            <span>{{ tpl.created_by }}</span>
          </div>
        </a-card>
      </a-col>
      <a-col :span="8" v-if="!store.loading.reportTemplates && !store.reportTemplates.length">
        <a-card class="template-card empty-card">
          <a-empty description="暂无模板，点击右上角新建" />
        </a-card>
      </a-col>
    </a-row>

    <!-- 新建/编辑 Modal -->
    <a-modal
      v-model:visible="showFormModal"
      :title="isEdit ? '编辑报表模板' : '新建报表模板'"
      :width="800"
      @before-ok="handleFormSubmit"
      :ok-loading="store.submitting"
    >
      <a-form :model="formData" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="name" label="模板名称" :rules="[{ required: true, message: '请输入模板名称' }]">
              <a-input v-model="formData.name" placeholder="请输入模板名称" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="orientation" label="页面方向">
              <a-radio-group v-model="formData.orientation">
                <a-radio value="landscape">横向</a-radio>
                <a-radio value="portrait">纵向</a-radio>
              </a-radio-group>
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item field="description" label="模板描述">
          <a-textarea v-model="formData.description" placeholder="请输入模板描述" :max-length="200" show-word-limit />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="8">
            <a-form-item field="watermark" label="水印">
              <a-switch v-model="formData.watermark" />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item field="is_default" label="设为默认">
              <a-switch v-model="formData.is_default" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item field="header_text" label="页眉文字">
              <a-input v-model="formData.header_text" placeholder="页眉文字" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item field="footer_text" label="页脚文字">
              <a-input v-model="formData.footer_text" placeholder="页脚文字" />
            </a-form-item>
          </a-col>
        </a-row>

        <!-- 区块编辑器 -->
        <a-form-item label="报表区块（拖拽排序）">
          <div class="blocks-editor">
            <draggable
              v-model="formData.blocks"
              item-key="id"
              handle=".block-drag-handle"
              animation="200"
              ghost-class="block-ghost"
            >
              <template #item="{ element }">
                <div class="block-item" :class="{ 'block-disabled': !element.enabled }">
                  <div class="block-drag-handle">
                    <icon-drag-dot-vertical />
                  </div>
                  <div class="block-icon">
                    <icon-bar-chart v-if="element.type === 'trend_chart'" />
                    <icon-list v-else-if="element.type === 'module_table'" />
                    <icon-apps v-else-if="element.type === 'stat_cards'" />
                    <icon-pie-chart v-else-if="element.type === 'bug_pie' || element.type === 'feedback_pie'" />
                    <icon-robot v-else-if="element.type === 'ai_insights'" />
                    <icon-font-colors v-else-if="element.type === 'custom_text'" />
                    <icon-minus v-else-if="element.type === 'divider'" />
                    <icon-file v-else />
                  </div>
                  <div class="block-info">
                    <div class="block-title">{{ element.title }}</div>
                    <div class="block-type">{{ blockTypeLabel(element.type) }}</div>
                  </div>
                  <a-switch v-model="element.enabled" size="small" />
                </div>
              </template>
            </draggable>
            <a-button long type="dashed" @click="addBlock" style="margin-top: 8px">
              <template #icon><icon-plus /></template>
              添加区块
            </a-button>
          </div>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 预览 Drawer -->
    <a-drawer v-model:visible="showPreview" title="模板预览" :width="700">
      <div v-if="previewTemplate" class="template-preview">
        <div class="preview-header">{{ previewTemplate.header_text || '质量中心报表' }}</div>
        <div v-for="block in previewTemplate.blocks.filter(b => b.enabled)" :key="block.id" class="preview-block">
          <div class="preview-block-title">{{ block.title }}</div>
          <div class="preview-block-content">
            <div v-if="block.type === 'stat_cards'" class="preview-stat-cards">
              <div class="stat-item" v-for="s in ['通过率 92.5%', 'Bug 23', '反馈 15', 'AI 78%']" :key="s">{{ s }}</div>
            </div>
            <div v-else-if="block.type === 'trend_chart'" class="preview-chart">[趋势图区域]</div>
            <div v-else-if="block.type === 'module_table'" class="preview-table">[模块质量表格]</div>
            <div v-else-if="block.type === 'bug_pie'" class="preview-chart">[Bug饼图]</div>
            <div v-else-if="block.type === 'feedback_pie'" class="preview-chart">[反馈饼图]</div>
            <div v-else-if="block.type === 'ai_insights'" class="preview-ai">[AI洞察内容]</div>
            <div v-else-if="block.type === 'custom_text'" class="preview-text">{{ block.config?.text || '自定义文本' }}</div>
            <div v-else-if="block.type === 'divider'" class="preview-divider" />
          </div>
        </div>
        <div class="preview-footer">{{ previewTemplate.footer_text || '' }}</div>
        <div v-if="previewTemplate.watermark" class="preview-watermark">ZigCMS质量中心</div>
      </div>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import draggable from 'vuedraggable';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import type { ReportTemplate, ReportTemplateBlock, ReportTemplateParams } from '@/types/quality-center';

const store = useQualityCenterStore();

const showFormModal = ref(false);
const showPreview = ref(false);
const isEdit = ref(false);
const editingId = ref<number | null>(null);
const previewTemplate = ref<ReportTemplate | null>(null);

const defaultBlocks: ReportTemplateBlock[] = [
  { id: 'b1', type: 'stat_cards', title: '质量概览统计', enabled: true, order: 0 },
  { id: 'b2', type: 'trend_chart', title: '质量趋势图', enabled: true, order: 1 },
  { id: 'b3', type: 'module_table', title: '模块质量排名', enabled: true, order: 2 },
  { id: 'b4', type: 'bug_pie', title: 'Bug类型分布', enabled: true, order: 3 },
  { id: 'b5', type: 'feedback_pie', title: '反馈状态分布', enabled: true, order: 4 },
  { id: 'b6', type: 'ai_insights', title: 'AI质量洞察', enabled: true, order: 5 },
];

const defaultForm: ReportTemplateParams & { is_default: boolean } = {
  name: '',
  description: '',
  blocks: [...defaultBlocks],
  orientation: 'landscape',
  watermark: true,
  header_text: 'ZigCMS质量中心',
  footer_text: '内部机密 - 仅供团队内部使用',
  is_default: false,
};

const formData = ref({ ...defaultForm, blocks: defaultBlocks.map(b => ({ ...b })) });

function blockTypeLabel(type: string): string {
  const map: Record<string, string> = {
    stat_cards: '统计卡片', trend_chart: '趋势图', module_table: '模块表格',
    bug_pie: 'Bug饼图', feedback_pie: '反馈饼图', ai_insights: 'AI洞察',
    custom_text: '自定义文本', divider: '分割线',
  };
  return map[type] || type;
}

function openCreateModal() {
  isEdit.value = false;
  editingId.value = null;
  formData.value = { ...defaultForm, blocks: defaultBlocks.map(b => ({ ...b })) };
  showFormModal.value = true;
}

function openEditModal(tpl: ReportTemplate) {
  isEdit.value = true;
  editingId.value = tpl.id;
  formData.value = {
    name: tpl.name,
    description: tpl.description || '',
    blocks: tpl.blocks.map(b => ({ ...b })),
    orientation: tpl.orientation,
    watermark: tpl.watermark,
    header_text: tpl.header_text || '',
    footer_text: tpl.footer_text || '',
    is_default: tpl.is_default,
  };
  showFormModal.value = true;
}

function handleCardAction(action: string, tpl: ReportTemplate) {
  switch (action) {
    case 'edit':
      openEditModal(tpl);
      break;
    case 'preview':
      previewTemplate.value = tpl;
      showPreview.value = true;
      break;
    case 'delete':
      Modal.confirm({
        title: '确认删除',
        content: `确定删除模板「${tpl.name}」？`,
        okButtonProps: { status: 'danger' },
        async onOk() {
          try {
            await store.removeReportTemplate(tpl.id);
            Message.success('模板已删除');
          } catch { Message.error('删除失败'); }
        },
      });
      break;
  }
}

async function handleFormSubmit(done: (closed: boolean) => void) {
  if (!formData.value.name.trim()) {
    Message.warning('请输入模板名称');
    done(false);
    return;
  }
  try {
    const params: ReportTemplateParams = {
      ...formData.value,
      blocks: formData.value.blocks.map((b, i) => ({ ...b, order: i })),
    };
    if (isEdit.value && editingId.value) {
      await store.editReportTemplate(editingId.value, params);
      Message.success('模板已更新');
    } else {
      await store.addReportTemplate(params);
      Message.success('模板已创建');
    }
    done(true);
  } catch {
    Message.error('操作失败');
    done(false);
  }
}

function addBlock() {
  const id = `b_${Date.now()}`;
  formData.value.blocks.push({
    id,
    type: 'custom_text',
    title: '新区块',
    enabled: true,
    order: formData.value.blocks.length,
    config: { text: '请输入内容' },
  });
}

async function fetchData() {
  await store.fetchReportTemplates(true);
}

onMounted(async () => {
  await store.fetchReportTemplates();
  console.log('[质量中心][报表模板编辑器][页面加载完成]');
});
</script>

<style lang="less" scoped>
.report-templates-page {
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
.template-card {
  margin-bottom: 16px;
  border-radius: 8px;
  .tpl-name { font-weight: 600; }
  .tpl-desc { font-size: 13px; color: var(--color-text-3); margin-bottom: 10px; min-height: 36px; }
  .tpl-blocks { display: flex; flex-wrap: wrap; gap: 4px; margin-bottom: 10px; }
  .tpl-meta { font-size: 12px; color: var(--color-text-4); }
  &.empty-card { display: flex; align-items: center; justify-content: center; min-height: 200px; }
}
.blocks-editor {
  .block-item {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 12px;
    border: 1px solid var(--color-border);
    border-radius: 6px;
    margin-bottom: 6px;
    background: var(--color-bg-2);
    transition: all 0.2s;
    &.block-disabled { opacity: 0.5; }
    &:hover { border-color: var(--color-primary-light-3); }
  }
  .block-drag-handle { cursor: grab; color: var(--color-text-4); &:active { cursor: grabbing; } }
  .block-icon { font-size: 18px; color: var(--color-primary-6); }
  .block-info { flex: 1; }
  .block-title { font-size: 13px; font-weight: 500; }
  .block-type { font-size: 11px; color: var(--color-text-4); }
  .block-ghost { opacity: 0.4; background: var(--color-primary-light-1); }
}
.template-preview {
  position: relative;
  min-height: 500px;
  border: 1px solid var(--color-border);
  border-radius: 8px;
  overflow: hidden;
  .preview-header {
    background: #165DFF;
    color: #fff;
    padding: 16px;
    text-align: center;
    font-size: 18px;
    font-weight: bold;
  }
  .preview-block {
    padding: 12px 16px;
    border-bottom: 1px solid var(--color-border-2);
    .preview-block-title { font-weight: 600; margin-bottom: 8px; color: var(--color-text-1); }
  }
  .preview-stat-cards {
    display: flex; gap: 8px;
    .stat-item { flex: 1; background: var(--color-fill-2); padding: 12px; border-radius: 6px; text-align: center; font-size: 13px; }
  }
  .preview-chart { height: 80px; background: var(--color-fill-2); border-radius: 6px; display: flex; align-items: center; justify-content: center; color: var(--color-text-4); }
  .preview-table { height: 60px; background: var(--color-fill-2); border-radius: 6px; display: flex; align-items: center; justify-content: center; color: var(--color-text-4); }
  .preview-ai { height: 50px; background: #FFF7E8; border-radius: 6px; display: flex; align-items: center; justify-content: center; color: #FF7D00; }
  .preview-text { color: var(--color-text-2); font-size: 13px; padding: 8px; }
  .preview-divider { border-top: 1px dashed var(--color-border); margin: 8px 0; }
  .preview-footer { padding: 12px 16px; text-align: center; font-size: 12px; color: var(--color-text-4); }
  .preview-watermark {
    position: absolute;
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%) rotate(-30deg);
    font-size: 48px;
    color: rgba(0,0,0,0.04);
    pointer-events: none;
    white-space: nowrap;
  }
}
</style>
