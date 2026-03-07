<template>
  <a-modal
    v-model:visible="internalVisible"
    title="AI 生成测试用例"
    width="900px"
    :footer="false"
    :mask-closable="false"
    @cancel="handleCancel"
  >
    <a-steps :current="currentStep" class="steps">
      <a-step title="选择需求" />
      <a-step title="生成中" />
      <a-step title="预览编辑" />
    </a-steps>

    <!-- 步骤 1: 选择需求 -->
    <div v-if="currentStep === 0" class="step-content">
      <a-form :model="generateForm" layout="vertical">
        <a-form-item label="选择项目" required>
          <a-select
            v-model="generateForm.project_id"
            placeholder="请选择项目"
            @change="handleProjectChange"
          >
            <a-option
              v-for="project in projects"
              :key="project.id"
              :value="project.id"
            >
              {{ project.name }}
            </a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="选择需求" required>
          <a-select
            v-model="generateForm.requirement_id"
            placeholder="请选择需求"
            :disabled="!generateForm.project_id"
            @change="handleRequirementChange"
          >
            <a-option
              v-for="requirement in requirements"
              :key="requirement.id"
              :value="requirement.id"
            >
              {{ requirement.title }}
            </a-option>
          </a-select>
        </a-form-item>

        <!-- 需求详情 -->
        <a-card
          v-if="selectedRequirement"
          title="需求详情"
          class="requirement-detail"
        >
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="标题">
              {{ selectedRequirement.title }}
            </a-descriptions-item>
            <a-descriptions-item label="优先级">
              <a-tag :color="getPriorityColor(selectedRequirement.priority)">
                {{ getPriorityText(selectedRequirement.priority) }}
              </a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="描述" :span="2">
              {{ selectedRequirement.description }}
            </a-descriptions-item>
          </a-descriptions>
        </a-card>

        <a-form-item label="生成选项">
          <a-space direction="vertical" fill>
            <a-checkbox v-model="generateForm.include_edge_cases">
              包含边界条件测试
            </a-checkbox>
            <a-checkbox v-model="generateForm.include_performance">
              包含性能测试
            </a-checkbox>
          </a-space>
        </a-form-item>

        <a-form-item label="最大生成数量">
          <a-input-number
            v-model="generateForm.max_cases"
            :min="1"
            :max="20"
            :default-value="10"
          />
        </a-form-item>
      </a-form>

      <div class="step-actions">
        <a-button @click="handleCancel">取消</a-button>
        <a-button
          type="primary"
          :disabled="!generateForm.requirement_id"
          @click="handleGenerate"
        >
          开始生成
        </a-button>
      </div>
    </div>

    <!-- 步骤 2: 生成中 -->
    <div v-if="currentStep === 1" class="step-content generating">
      <div class="generating-content">
        <a-spin :size="60" />
        <div class="progress-info">
          <a-progress
            :percent="generateProgress"
            :stroke-width="8"
            status="normal"
          />
          <div class="progress-text">{{ generateMessage }}</div>
        </div>
      </div>
    </div>

    <!-- 步骤 3: 预览编辑 -->
    <div v-if="currentStep === 2" class="step-content">
      <div class="preview-header">
        <a-space>
          <a-button @click="handleSelectAll">全选</a-button>
          <a-button @click="handleDeselectAll">取消全选</a-button>
          <a-button @click="handleRegenerate">
            <template #icon><icon-refresh /></template>
            重新生成
          </a-button>
        </a-space>
        <div class="selected-count">
          已选择 {{ selectedCount }} / {{ generatedCases.length }} 个用例
        </div>
      </div>

      <div class="case-list">
        <a-card
          v-for="(testCase, index) in generatedCases"
          :key="index"
          class="case-card"
          :class="{ selected: testCase.selected }"
        >
          <template #title>
            <a-checkbox
              v-model="testCase.selected"
              @change="handleCaseSelect"
            >
              {{ testCase.title }}
            </a-checkbox>
          </template>

          <template #extra>
            <a-tag :color="getPriorityColor(testCase.priority)">
              {{ getPriorityText(testCase.priority) }}
            </a-tag>
          </template>

          <a-descriptions :column="1" bordered size="small">
            <a-descriptions-item label="前置条件">
              <a-textarea
                v-model="testCase.precondition"
                :auto-size="{ minRows: 2, maxRows: 4 }"
                :disabled="!testCase.selected"
              />
            </a-descriptions-item>
            <a-descriptions-item label="测试步骤">
              <a-textarea
                v-model="testCase.steps"
                :auto-size="{ minRows: 3, maxRows: 6 }"
                :disabled="!testCase.selected"
              />
            </a-descriptions-item>
            <a-descriptions-item label="预期结果">
              <a-textarea
                v-model="testCase.expected_result"
                :auto-size="{ minRows: 2, maxRows: 4 }"
                :disabled="!testCase.selected"
              />
            </a-descriptions-item>
            <a-descriptions-item label="标签">
              <a-space wrap>
                <a-tag v-for="tag in testCase.tags" :key="tag">
                  {{ tag }}
                </a-tag>
              </a-space>
            </a-descriptions-item>
          </a-descriptions>
        </a-card>
      </div>

      <div class="step-actions">
        <a-button @click="handleBack">上一步</a-button>
        <a-button
          type="primary"
          :loading="saving"
          :disabled="selectedCount === 0"
          @click="handleSave"
        >
          保存选中用例
        </a-button>
      </div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, reactive, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import { IconRefresh } from '@arco-design/web-vue/es/icon';
import qualityCenterApi from '@/api/quality-center';
import type {
  Project,
  Requirement,
  GeneratedTestCase,
  Priority,
  AIGenerateTestCasesDto,
} from '@/types/quality-center';

interface Props {
  visible: boolean;
  projects: Project[];
}

interface Emits {
  (e: 'update:visible', value: boolean): void;
  (e: 'success'): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// 内部可见状态
const internalVisible = ref(false);

// 当前步骤
const currentStep = ref(0);

// 生成表单
const generateForm = reactive<AIGenerateTestCasesDto>({
  requirement_id: 0,
  max_cases: 10,
  include_edge_cases: true,
  include_performance: false,
  language: 'zh-CN',
  project_id: 0,
});

// 需求列表
const requirements = ref<Requirement[]>([]);

// 选中的需求
const selectedRequirement = ref<Requirement | null>(null);

// 生成进度
const generateProgress = ref(0);
const generateMessage = ref('正在分析需求...');

// 生成的测试用例
const generatedCases = ref<GeneratedTestCase[]>([]);

// 保存中
const saving = ref(false);

// 选中数量
const selectedCount = computed(() => {
  return generatedCases.value.filter((c) => c.selected).length;
});

// 监听外部可见状态
watch(
  () => props.visible,
  (newVisible) => {
    internalVisible.value = newVisible;
    if (newVisible) {
      // 重置状态
      currentStep.value = 0;
      generateProgress.value = 0;
      generateMessage.value = '正在分析需求...';
      generatedCases.value = [];
    }
  }
);

// 监听内部可见状态
watch(internalVisible, (newVisible) => {
  emit('update:visible', newVisible);
});

// 加载需求列表
const loadRequirements = async (projectId: number) => {
  try {
    const result = await qualityCenterApi.searchRequirements({
      project_id: projectId,
      page: 1,
      page_size: 100,
    });
    requirements.value = result.items;
  } catch (error) {
    Message.error('加载需求列表失败');
  }
};

// 项目变更
const handleProjectChange = (projectId: number) => {
  generateForm.requirement_id = 0;
  selectedRequirement.value = null;
  requirements.value = [];
  
  if (projectId) {
    loadRequirements(projectId);
  }
};

// 需求变更
const handleRequirementChange = (requirementId: number) => {
  selectedRequirement.value =
    requirements.value.find((r) => r.id === requirementId) || null;
};

// 开始生成
const handleGenerate = async () => {
  if (!generateForm.requirement_id) {
    Message.warning('请选择需求');
    return;
  }

  currentStep.value = 1;
  generateProgress.value = 0;
  generateMessage.value = '正在分析需求...';

  // 模拟进度更新
  const progressInterval = setInterval(() => {
    if (generateProgress.value < 90) {
      generateProgress.value += 10;
      
      if (generateProgress.value < 30) {
        generateMessage.value = '正在分析需求...';
      } else if (generateProgress.value < 60) {
        generateMessage.value = '正在识别测试点...';
      } else {
        generateMessage.value = '正在生成测试用例...';
      }
    }
  }, 500);

  try {
    const result = await qualityCenterApi.generateTestCases(generateForm);
    
    clearInterval(progressInterval);
    generateProgress.value = 100;
    generateMessage.value = '生成完成！';

    // 添加选中状态
    generatedCases.value = result.test_cases.map((tc) => ({
      ...tc,
      selected: true,
    }));

    setTimeout(() => {
      currentStep.value = 2;
    }, 500);
  } catch (error) {
    clearInterval(progressInterval);
    Message.error('生成失败，请重试');
    currentStep.value = 0;
  }
};

// 重新生成
const handleRegenerate = () => {
  currentStep.value = 0;
  generatedCases.value = [];
};

// 全选
const handleSelectAll = () => {
  generatedCases.value.forEach((tc) => {
    tc.selected = true;
  });
};

// 取消全选
const handleDeselectAll = () => {
  generatedCases.value.forEach((tc) => {
    tc.selected = false;
  });
};

// 用例选择变更
const handleCaseSelect = () => {
  // 触发响应式更新
};

// 保存
const handleSave = async () => {
  const selectedCases = generatedCases.value.filter((tc) => tc.selected);
  
  if (selectedCases.length === 0) {
    Message.warning('请至少选择一个测试用例');
    return;
  }

  saving.value = true;

  try {
    // 批量创建测试用例
    for (const testCase of selectedCases) {
      await qualityCenterApi.createTestCase({
        title: testCase.title,
        project_id: generateForm.project_id!,
        module_id: selectedRequirement.value?.project_id || 0, // TODO: 选择模块
        requirement_id: generateForm.requirement_id,
        priority: testCase.priority,
        precondition: testCase.precondition,
        steps: testCase.steps,
        expected_result: testCase.expected_result,
        tags: testCase.tags.join(','),
        created_by: 'current_user', // TODO: 从用户信息获取
      });
    }

    Message.success(`成功保存 ${selectedCases.length} 个测试用例`);
    emit('success');
    internalVisible.value = false;
  } catch (error) {
    Message.error('保存失败');
  } finally {
    saving.value = false;
  }
};

// 上一步
const handleBack = () => {
  currentStep.value = 0;
};

// 取消
const handleCancel = () => {
  internalVisible.value = false;
};

// 优先级颜色
const getPriorityColor = (priority: Priority): string => {
  const colorMap: Record<Priority, string> = {
    low: 'gray',
    medium: 'blue',
    high: 'orange',
    critical: 'red',
  };
  return colorMap[priority] || 'gray';
};

// 优先级文本
const getPriorityText = (priority: Priority): string => {
  const textMap: Record<Priority, string> = {
    low: '低',
    medium: '中',
    high: '高',
    critical: '紧急',
  };
  return textMap[priority] || priority;
};
</script>

<style scoped lang="less">
.steps {
  margin-bottom: 32px;
}

.step-content {
  min-height: 400px;
  padding: 24px 0;
}

.step-actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;
  margin-top: 24px;
  padding-top: 24px;
  border-top: 1px solid #e5e6eb;
}

.requirement-detail {
  margin-top: 16px;
}

.generating {
  display: flex;
  align-items: center;
  justify-content: center;
}

.generating-content {
  text-align: center;
  width: 100%;
  max-width: 400px;

  .progress-info {
    margin-top: 32px;

    .progress-text {
      margin-top: 16px;
      font-size: 14px;
      color: #666;
    }
  }
}

.preview-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 16px;

  .selected-count {
    font-size: 14px;
    color: #666;
  }
}

.case-list {
  max-height: 500px;
  overflow-y: auto;
}

.case-card {
  margin-bottom: 16px;

  &.selected {
    border-color: #165dff;
  }
}
</style>
