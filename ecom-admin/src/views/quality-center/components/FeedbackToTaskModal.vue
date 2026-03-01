/**
 * 反馈转测试任务弹窗组件
 * 【高级特性】表单联动、条件渲染、防重复提交
 * 支持从反馈列表选择反馈并转换为自动化测试任务
 */
<template>
  <a-modal
    :visible="visible"
    title="反馈转测试任务"
    :width="640"
    :mask-closable="false"
    :ok-loading="store.submitting"
    ok-text="创建任务"
    @ok="handleSubmit"
    @cancel="handleCancel"
  >
    <a-form
      ref="formRef"
      :model="formData"
      :rules="rules"
      layout="vertical"
      auto-label-width
    >
      <!-- 选择反馈 -->
      <a-form-item field="feedback_id" label="选择反馈" :rules="[{ required: true, message: '请选择关联反馈' }]">
        <a-select
          v-model="formData.feedback_id"
          placeholder="搜索并选择反馈"
          allow-search
          :loading="feedbackLoading"
          @search="handleFeedbackSearch"
        >
          <a-option
            v-for="fb in feedbackOptions"
            :key="fb.id"
            :value="fb.id"
            :label="`#${fb.id} ${fb.title}`"
          >
            <div class="feedback-option">
              <span class="feedback-id">#{{ fb.id }}</span>
              <span class="feedback-title">{{ fb.title }}</span>
              <a-tag :color="priorityColor(fb.priority)" size="small">
                {{ priorityText(fb.priority) }}
              </a-tag>
            </div>
          </a-option>
        </a-select>
      </a-form-item>

      <!-- 任务名称 -->
      <a-form-item field="task_name" label="任务名称">
        <a-input
          v-model="formData.task_name"
          placeholder="请输入测试任务名称"
          :max-length="100"
          show-word-limit
        />
      </a-form-item>

      <!-- 任务类型 + 优先级 -->
      <a-row :gutter="16">
        <a-col :span="12">
          <a-form-item field="task_type" label="任务类型">
            <a-select v-model="formData.task_type" placeholder="选择任务类型">
              <a-option value="functional">功能测试</a-option>
              <a-option value="integration">集成测试</a-option>
              <a-option value="regression">回归测试</a-option>
              <a-option value="performance">性能测试</a-option>
              <a-option value="security">安全测试</a-option>
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

      <!-- 描述 -->
      <a-form-item field="description" label="描述">
        <a-textarea
          v-model="formData.description"
          placeholder="请输入任务描述（可选）"
          :max-length="500"
          :auto-size="{ minRows: 2, maxRows: 4 }"
          show-word-limit
        />
      </a-form-item>

      <!-- AI生成测试用例开关 -->
      <a-form-item label="AI自动生成用例">
        <a-space direction="vertical" fill>
          <a-switch
            v-model="formData.auto_generate_cases"
            checked-text="开启"
            unchecked-text="关闭"
          />
          <!-- 【条件渲染】仅在开启AI生成时显示用例数量选择 -->
          <a-input-number
            v-if="formData.auto_generate_cases"
            v-model="formData.case_count"
            :min="1"
            :max="50"
            :default-value="5"
            style="width: 200px"
          >
            <template #prefix>生成数量</template>
            <template #suffix>个</template>
          </a-input-number>
          <a-typography-text v-if="formData.auto_generate_cases" type="secondary">
            AI将基于反馈内容自动分析并生成对应的测试用例
          </a-typography-text>
        </a-space>
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FormInstance } from '@arco-design/web-vue';
import { useQualityCenterStore } from '@/store/modules/quality-center';

// Props & Emits
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
  feedback_id: undefined as number | undefined,
  task_name: '',
  task_type: 'functional',
  priority: 2,
  description: '',
  auto_generate_cases: true,
  case_count: 5,
});

// 表单校验规则
const rules = {
  feedback_id: [{ required: true, message: '请选择关联反馈' }],
  task_name: [{ required: true, message: '请输入任务名称' }],
  task_type: [{ required: true, message: '请选择任务类型' }],
  priority: [{ required: true, message: '请选择优先级' }],
};

// ========== 反馈搜索 ==========
const feedbackLoading = ref(false);
const feedbackOptions = ref<Array<{ id: number; title: string; priority: number }>>([
  { id: 1001, title: '用户登录时偶尔出现白屏', priority: 3 },
  { id: 1002, title: '订单提交后金额计算不正确', priority: 4 },
  { id: 1003, title: '商品搜索结果排序异常', priority: 2 },
  { id: 1004, title: '支付回调未及时更新订单状态', priority: 3 },
  { id: 1005, title: '导出报表数据不完整', priority: 2 },
  { id: 1006, title: '移动端页面布局错位', priority: 1 },
  { id: 1007, title: '权限配置保存后未生效', priority: 3 },
  { id: 1008, title: '文件上传大小超过限制无提示', priority: 2 },
]);

function handleFeedbackSearch(keyword: string) {
  if (!keyword) return;
  feedbackLoading.value = true;
  setTimeout(() => {
    feedbackLoading.value = false;
  }, 300);
}

// ========== 工具方法 ==========
function priorityColor(priority: number): string {
  const map: Record<number, string> = { 1: 'gray', 2: 'blue', 3: 'orange', 4: 'red' };
  return map[priority] || 'gray';
}

function priorityText(priority: number): string {
  const map: Record<number, string> = { 1: '低', 2: '中', 3: '高', 4: '紧急' };
  return map[priority] || '未知';
}

// ========== 提交 ==========
async function handleSubmit() {
  const errors = await formRef.value?.validate();
  if (errors) return;

  try {
    await store.convertFeedbackToTask({
      feedback_id: formData.feedback_id!,
      task_name: formData.task_name,
      task_type: formData.task_type,
      priority: formData.priority,
      description: formData.description,
      auto_generate_cases: formData.auto_generate_cases,
      case_count: formData.auto_generate_cases ? formData.case_count : 0,
    });
    emit('success');
    handleCancel();
  } catch (error) {
    Message.error('创建失败，请重试');
    console.error('[质量中心][FeedbackToTask][提交失败]', error);
  }
}

function handleCancel() {
  emit('update:visible', false);
  resetForm();
}

function resetForm() {
  formData.feedback_id = undefined;
  formData.task_name = '';
  formData.task_type = 'functional';
  formData.priority = 2;
  formData.description = '';
  formData.auto_generate_cases = true;
  formData.case_count = 5;
  formRef.value?.resetFields();
}

// 当选择反馈后自动填充任务名称
watch(() => formData.feedback_id, (val) => {
  if (val) {
    const fb = feedbackOptions.value.find(f => f.id === val);
    if (fb && !formData.task_name) {
      formData.task_name = `[反馈#${fb.id}] ${fb.title} - 回归测试`;
    }
  }
});
</script>

<style lang="less" scoped>
.feedback-option {
  display: flex;
  align-items: center;
  gap: 8px;
  .feedback-id {
    font-size: 12px;
    color: var(--color-text-3);
    min-width: 44px;
  }
  .feedback-title {
    flex: 1;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
}
</style>
