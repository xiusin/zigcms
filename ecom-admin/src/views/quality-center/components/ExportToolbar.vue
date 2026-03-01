/**
 * 质量中心导出工具栏组件
 * 【高级特性】下拉菜单、多格式导出、操作反馈
 * 支持PDF/Excel/测试用例/脑图导出
 */
<template>
  <a-dropdown trigger="click" @select="handleExport">
    <a-button type="primary" status="success">
      <template #icon><icon-download /></template>
      导出
      <icon-down style="margin-left: 4px" />
    </a-button>
    <template #content>
      <a-doption value="pdf">
        <template #icon><icon-file /></template>
        导出PDF报表
      </a-doption>
      <a-doption value="excel">
        <template #icon><icon-file-image /></template>
        导出Excel报表
      </a-doption>
      <a-dsubmenu trigger="hover">
        <template #default>
          <a-space>
            <icon-code-block />
            <span>导出测试用例</span>
          </a-space>
        </template>
        <template #content>
          <a-doption value="cases_excel">Excel格式</a-doption>
          <a-doption value="cases_json">JSON格式</a-doption>
        </template>
      </a-dsubmenu>
      <a-dsubmenu trigger="hover">
        <template #default>
          <a-space>
            <icon-mind-mapping />
            <span>导出脑图</span>
          </a-space>
        </template>
        <template #content>
          <a-doption value="mindmap_quality">模块质量脑图</a-doption>
          <a-doption value="mindmap_bug">Bug关联脑图</a-doption>
          <a-doption value="mindmap_feedback">反馈分类脑图</a-doption>
        </template>
      </a-dsubmenu>
    </template>
  </a-dropdown>

  <!-- 脑图预览弹窗 -->
  <a-modal
    v-model:visible="mindmapPreviewVisible"
    title="脑图预览"
    :width="960"
    :footer="false"
    unmount-on-close
  >
    <div class="mindmap-preview">
      <div class="mindmap-toolbar">
        <a-space>
          <a-radio-group v-model="mindmapType" type="button" size="small">
            <a-radio value="quality">模块质量</a-radio>
            <a-radio value="bug-link">Bug关联</a-radio>
            <a-radio value="feedback">反馈分类</a-radio>
            <a-radio value="cases">测试用例</a-radio>
          </a-radio-group>
          <a-checkbox v-model="exportWatermark" style="margin-left: 8px">水印</a-checkbox>
          <a-button size="small" @click="handleMindmapExport('svg')">
            <icon-download /> SVG
          </a-button>
          <a-button size="small" @click="handleMindmapExport('png')">
            <icon-download /> PNG
          </a-button>
        </a-space>
      </div>
      <div
        ref="mindmapContainer"
        class="mindmap-container"
        v-html="mindmapSVG"
      />
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import {
  exportElementToPDF,
  exportToExcel,
  exportMultiSheetExcel,
  exportTestCases,
  exportTestCasesJSON,
  exportMindMapSVG,
  exportMindMapPNG,
  generateMindMapSVG,
  buildTestCaseMindMap,
  buildQualityMindMap,
  buildBugLinkMindMap,
  buildFeedbackMindMap,
} from '@/utils/export';
import { useQualityCenterStore } from '@/store/modules/quality-center';
import type { ModuleQualityItem } from '@/types/quality-center';

const props = defineProps<{
  /** Dashboard DOM容器引用 */
  dashboardRef?: HTMLElement | null;
  /** 模块质量数据 */
  moduleQuality: ModuleQualityItem[];
  /** 测试用例数据（模拟） */
  testCases?: Array<Record<string, unknown>>;
  /** 概览数据 */
  overview?: Record<string, unknown> | null;
  /** Bug分布数据 */
  bugDistribution?: Array<Record<string, unknown>>;
  /** 反馈分布数据 */
  feedbackDistribution?: Array<Record<string, unknown>>;
}>();

const qcStore = useQualityCenterStore();

// ========== 脑图预览 ==========
const mindmapPreviewVisible = ref(false);
const mindmapType = ref<'quality' | 'bug-link' | 'feedback' | 'cases'>('quality');
const mindmapSVG = ref('');
const mindmapContainer = ref<HTMLElement | null>(null);
const exportWatermark = ref(true);

// 监听脑图类型切换
watch(mindmapType, () => {
  updateMindmapPreview();
});

async function updateMindmapPreview() {
  switch (mindmapType.value) {
    case 'quality': {
      const root = buildQualityMindMap(props.moduleQuality);
      mindmapSVG.value = generateMindMapSVG(root);
      break;
    }
    case 'bug-link': {
      if (!qcStore.bugLinks.length) await qcStore.fetchBugLinks();
      const root = buildBugLinkMindMap(qcStore.bugLinks);
      mindmapSVG.value = generateMindMapSVG(root);
      break;
    }
    case 'feedback': {
      if (!qcStore.feedbackClassification.length) await qcStore.fetchFeedbackClassification();
      const root = buildFeedbackMindMap(qcStore.feedbackClassification);
      mindmapSVG.value = generateMindMapSVG(root);
      break;
    }
    case 'cases': {
      const mockCases = props.testCases || generateMockTestCases();
      const root = buildTestCaseMindMap(mockCases);
      mindmapSVG.value = generateMindMapSVG(root);
      break;
    }
  }
}

// ========== 导出处理 ==========
async function handleExport(value: string | number | Record<string, unknown> | undefined) {
  const key = String(value);
  console.log(`[质量中心][导出工具栏][选择][${key}]`);

  try {
    switch (key) {
      case 'pdf':
        await handleExportPDF();
        break;
      case 'excel':
        handleExportExcel();
        break;
      case 'cases_excel':
        handleExportCasesExcel();
        break;
      case 'cases_json':
        handleExportCasesJSON();
        break;
      case 'mindmap_quality':
        mindmapType.value = 'quality';
        mindmapPreviewVisible.value = true;
        updateMindmapPreview();
        break;
      case 'mindmap_bug':
        mindmapType.value = 'bug-link';
        mindmapPreviewVisible.value = true;
        updateMindmapPreview();
        break;
      case 'mindmap_feedback':
        mindmapType.value = 'feedback';
        mindmapPreviewVisible.value = true;
        updateMindmapPreview();
        break;
      default:
        break;
    }
  } catch (error) {
    console.error(`[质量中心][导出失败][${key}]`, error);
    Message.error('导出失败，请重试');
  }
}

/** 导出Dashboard为PDF */
async function handleExportPDF() {
  if (!props.dashboardRef) {
    Message.warning('Dashboard容器未就绪');
    return;
  }
  Message.loading({ content: '正在生成PDF...', id: 'export-pdf' });
  await exportElementToPDF(props.dashboardRef, `质量中心报表_${formatDate()}.pdf`, {
    title: '质量中心总览报表',
    orientation: 'landscape',
    scale: 1.5,
    watermark: exportWatermark.value ? undefined : false,
  });
  Message.success({ content: 'PDF导出成功', id: 'export-pdf' });
}

/** 导出Excel报表（多Sheet） */
function handleExportExcel() {
  Message.loading({ content: '正在生成Excel...', id: 'export-excel' });

  const sheets = [];

  // Sheet1: 质量概览
  if (props.overview) {
    sheets.push({
      name: '质量概览',
      data: [props.overview as Record<string, unknown>],
      columns: [
        { title: '测试通过率(%)', dataIndex: 'pass_rate', width: 15 },
        { title: '总测试任务', dataIndex: 'total_tasks', width: 12 },
        { title: '活跃Bug', dataIndex: 'active_bugs', width: 10 },
        { title: '待处理反馈', dataIndex: 'pending_feedbacks', width: 12 },
        { title: 'AI修复率(%)', dataIndex: 'ai_fix_rate', width: 12 },
        { title: '本周执行', dataIndex: 'weekly_executions', width: 10 },
        { title: '反馈转任务', dataIndex: 'feedback_to_task_count', width: 12 },
        { title: '平均修复时长(h)', dataIndex: 'avg_bug_fix_hours', width: 15 },
      ],
    });
  }

  // Sheet2: 模块质量
  if (props.moduleQuality.length > 0) {
    sheets.push({
      name: '模块质量',
      data: props.moduleQuality as unknown as Record<string, unknown>[],
      columns: [
        { title: '模块名称', dataIndex: 'module_name', width: 20 },
        { title: '通过率(%)', dataIndex: 'pass_rate', width: 12 },
        { title: 'Bug数', dataIndex: 'bug_count', width: 10 },
        { title: '用例数', dataIndex: 'case_count', width: 10 },
        { title: '反馈数', dataIndex: 'feedback_count', width: 10 },
      ],
    });
  }

  // Sheet3: Bug分布
  if (props.bugDistribution && props.bugDistribution.length > 0) {
    sheets.push({
      name: 'Bug分布',
      data: props.bugDistribution,
      columns: [
        { title: '类型', dataIndex: 'type_name', width: 15 },
        { title: '数量', dataIndex: 'count', width: 10 },
        { title: '占比(%)', dataIndex: 'percentage', width: 10 },
      ],
    });
  }

  // Sheet4: 反馈分布
  if (props.feedbackDistribution && props.feedbackDistribution.length > 0) {
    sheets.push({
      name: '反馈分布',
      data: props.feedbackDistribution,
      columns: [
        { title: '状态', dataIndex: 'status_name', width: 15 },
        { title: '数量', dataIndex: 'count', width: 10 },
        { title: '占比(%)', dataIndex: 'percentage', width: 10 },
      ],
    });
  }

  if (sheets.length > 0) {
    exportMultiSheetExcel(sheets, `质量中心报表_${formatDate()}.xlsx`);
    Message.success({ content: 'Excel导出成功', id: 'export-excel' });
  } else {
    Message.warning({ content: '暂无可导出的数据', id: 'export-excel' });
  }
}

/** 导出测试用例Excel */
function handleExportCasesExcel() {
  const cases = props.testCases || generateMockTestCases();
  Message.loading({ content: '正在导出测试用例...', id: 'export-cases' });
  exportTestCases(cases, `测试用例_${formatDate()}.xlsx`);
  Message.success({ content: '测试用例导出成功', id: 'export-cases' });
}

/** 导出测试用例JSON */
function handleExportCasesJSON() {
  const cases = props.testCases || generateMockTestCases();
  Message.loading({ content: '正在导出JSON...', id: 'export-json' });
  exportTestCasesJSON(cases, `测试用例_${formatDate()}.json`);
  Message.success({ content: 'JSON导出成功', id: 'export-json' });
}

/** 脑图导出 */
function handleMindmapExport(format: 'svg' | 'png') {
  const suffixMap: Record<string, string> = {
    'quality': '模块质量', 'bug-link': 'Bug关联', 'feedback': '反馈分类', 'cases': '测试用例',
  };
  const suffix = suffixMap[mindmapType.value] || '';

  let root;
  switch (mindmapType.value) {
    case 'quality':
      root = buildQualityMindMap(props.moduleQuality);
      break;
    case 'bug-link':
      root = buildBugLinkMindMap(qcStore.bugLinks);
      break;
    case 'feedback':
      root = buildFeedbackMindMap(qcStore.feedbackClassification);
      break;
    case 'cases':
    default:
      root = buildTestCaseMindMap(props.testCases || generateMockTestCases());
      break;
  }

  if (format === 'svg') {
    exportMindMapSVG(root, `${suffix}脑图_${formatDate()}.svg`);
  } else {
    exportMindMapPNG(root, `${suffix}脑图_${formatDate()}.png`, exportWatermark.value ? undefined : false);
  }
  Message.success(`脑图${format.toUpperCase()}导出成功`);
  console.log(`[质量中心][脑图导出][${format}][${suffix}][水印:${exportWatermark.value}]`);
}

// ========== 工具方法 ==========
function formatDate(): string {
  return new Date().toISOString().slice(0, 10).replace(/-/g, '');
}

/** 生成模拟测试用例数据（用于导出演示） */
function generateMockTestCases(): Array<Record<string, unknown>> {
  const modules = ['用户管理', '订单系统', '支付模块', '商品管理', '报表系统', '权限系统'];
  const types = ['api', 'ui', 'unit', 'e2e'];
  const methods = ['GET', 'POST', 'PUT', 'DELETE'];
  const statuses = ['active', 'draft', 'deprecated'];

  return Array.from({ length: 30 }, (_, i) => ({
    id: i + 1,
    name: `测试用例-${i + 1}`,
    description: `${modules[i % modules.length]}模块${types[i % types.length]}测试`,
    type: 'functional',
    test_type: types[i % types.length],
    method: methods[i % methods.length],
    endpoint: `/api/${modules[i % modules.length].toLowerCase()}/${i + 1}`,
    expected_status: 200,
    status: statuses[i % statuses.length],
    source: i % 3 === 0 ? 'ai_generated' : 'manual',
    generated_by_ai: i % 3 === 0 ? '是' : '否',
    module_name: modules[i % modules.length],
    run_count: Math.floor(Math.random() * 20),
    pass_count: Math.floor(Math.random() * 15),
    fail_count: Math.floor(Math.random() * 5),
    created_at: new Date(Date.now() - Math.random() * 30 * 86400000).toISOString().slice(0, 19).replace('T', ' '),
  }));
}
</script>

<style lang="less" scoped>
.mindmap-preview {
  .mindmap-toolbar {
    margin-bottom: 12px;
    padding-bottom: 12px;
    border-bottom: 1px solid var(--color-border);
  }
  .mindmap-container {
    overflow: auto;
    max-height: 600px;
    border: 1px solid var(--color-border);
    border-radius: 6px;
    background: #fff;
    :deep(svg) {
      display: block;
      max-width: 100%;
      height: auto;
    }
  }
}
</style>
