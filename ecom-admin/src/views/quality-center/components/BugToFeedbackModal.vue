/**
 * Bug同步到反馈弹窗组件
 * 【高级特性】表单联动、防重复提交
 * 将自动化测试发现的Bug同步创建为反馈记录
 */
<template>
  <a-modal
    :visible="visible"
    title="Bug同步到反馈"
    :width="560"
    :mask-closable="false"
    :ok-loading="store.submitting"
    ok-text="创建反馈"
    @ok="handleSubmit"
    @cancel="handleCancel"
  >
    <a-form
      ref="formRef"
      :model="formData"
      :rules="rules"
      layout="vertical"
    >
      <!-- 选择Bug -->
      <a-form-item field="bug_analysis_id" label="选择Bug">
        <a-select
          v-model="formData.bug_analysis_id"
          placeholder="搜索并选择Bug"
          allow-search
        >
          <a-option
            v-for="bug in bugOptions"
            :key="bug.id"
            :value="bug.id"
            :label="`#${bug.id} ${bug.title}`"
          >
            <div class="bug-option">
              <span class="bug-id">#{{ bug.id }}</span>
              <span class="bug-title">{{ bug.title }}</span>
              <a-tag :color="severityColor(bug.severity)" size="small">
                {{ severityText(bug.severity) }}
              </a-tag>
            </div>
          </a-option>
        </a-select>
      </a-form-item>

      <!-- 反馈标题 -->
      <a-form-item field="feedback_title" label="反馈标题">
        <a-input
          v-model="formData.feedback_title"
          placeholder="请输入反馈标题"
          :max-length="100"
          show-word-limit
        />
      </a-form-item>

      <!-- 反馈类型 + 优先级 -->
      <a-row :gutter="16">
        <a-col :span="12">
          <a-form-item field="feedback_type" label="反馈类型">
            <a-select v-model="formData.feedback_type" placeholder="选择类型">
              <a-option :value="1">Bug反馈</a-option>
              <a-option :value="2">功能建议</a-option>
              <a-option :value="3">性能问题</a-option>
              <a-option :value="4">安全问题</a-option>
            </a-select>
          </a-form-item>
        </a-col>
        <a-col :span="12">
          <a-form-item field="priority" label="优先级">
            <a-select v-model="formData.priority" placeholder="选择优先级">
              <a-option :value="1">低</a-option>
              <a-option :value="2">中</a-option>
              <a-option :value="3">高</a-option>
              <a-option :value="4">紧急</a-option>
            </a-select>
          </a-form-item>
        </a-col>
      </a-row>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FormInstance } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';

const props = defineProps<{
  visible: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:visible', val: boolean): void;
  (e: 'success'): void;
}>();

const store = useQualityCenterStore();
const formRef = ref<FormInstance>();

// ========== 表单数据 ==========
const formData = reactive({
  bug_analysis_id: undefined as number | undefined,
  feedback_title: '',
  feedback_type: 1,
  priority: 2,
});

const rules = {
  bug_analysis_id: [{ required: true, message: '请选择Bug' }],
  feedback_title: [{ required: true, message: '请输入反馈标题' }],
};

// ========== Bug选项（模拟数据） ==========
const bugOptions = ref([
  { id: 101, title: '订单接口返回500错误', severity: 'critical' },
  { id: 102, title: '支付回调超时未处理', severity: 'major' },
  { id: 103, title: '商品搜索排序不正确', severity: 'minor' },
  { id: 104, title: '用户头像上传失败', severity: 'minor' },
  { id: 105, title: '报表数据统计遗漏', severity: 'major' },
  { id: 106, title: '权限校验绕过漏洞', severity: 'critical' },
]);

// ========== 工具方法 ==========
function severityColor(severity: string): string {
  const map: Record<string, string> = {
    critical: 'red', major: 'orange', minor: 'blue', trivial: 'gray',
  };
  return map[severity] || 'gray';
}

function severityText(severity: string): string {
  const map: Record<string, string> = {
    critical: '严重', major: '主要', minor: '次要', trivial: '轻微',
  };
  return map[severity] || severity;
}

// ========== 提交 ==========
async function handleSubmit() {
  const errors = await formRef.value?.validate();
  if (errors) return;

  try {
    await store.convertBugToFeedback({
      bug_analysis_id: formData.bug_analysis_id!,
      feedback_title: formData.feedback_title,
      feedback_type: formData.feedback_type,
      priority: formData.priority,
    });
    emit('success');
    handleCancel();
  } catch (error) {
    Message.error('创建失败，请重试');
    console.error('[质量中心][BugToFeedback][提交失败]', error);
  }
}

function handleCancel() {
  emit('update:visible', false);
  formData.bug_analysis_id = undefined;
  formData.feedback_title = '';
  formData.feedback_type = 1;
  formData.priority = 2;
  formRef.value?.resetFields();
}

// 选择Bug后自动填充标题
watch(() => formData.bug_analysis_id, (val) => {
  if (val) {
    const bug = bugOptions.value.find(b => b.id === val);
    if (bug && !formData.feedback_title) {
      formData.feedback_title = `[Bug#${bug.id}] ${bug.title}`;
    }
  }
});
</script>

<style lang="less" scoped>
.bug-option {
  display: flex;
  align-items: center;
  gap: 8px;
  .bug-id {
    font-size: 12px;
    color: var(--color-text-3);
    min-width: 40px;
  }
  .bug-title {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}
</style>
