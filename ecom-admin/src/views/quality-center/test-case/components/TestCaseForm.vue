<template>
  <a-form
    ref="formRef"
    :model="formData"
    :rules="rules"
    layout="vertical"
  >
    <a-form-item label="标题" field="title" required>
      <a-input
        v-model="formData.title"
        placeholder="请输入测试用例标题"
        :max-length="200"
        show-word-limit
      />
    </a-form-item>

    <a-row :gutter="16">
      <a-col :span="12">
        <a-form-item label="所属项目" field="project_id" required>
          <a-select
            v-model="formData.project_id"
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
      </a-col>

      <a-col :span="12">
        <a-form-item label="所属模块" field="module_id" required>
          <a-select
            v-model="formData.module_id"
            placeholder="请选择模块"
            :disabled="!formData.project_id"
          >
            <a-option
              v-for="module in modules"
              :key="module.id"
              :value="module.id"
            >
              {{ module.name }}
            </a-option>
          </a-select>
        </a-form-item>
      </a-col>
    </a-row>

    <a-row :gutter="16">
      <a-col :span="12">
        <a-form-item label="关联需求" field="requirement_id">
          <a-select
            v-model="formData.requirement_id"
            placeholder="请选择需求"
            allow-clear
            :disabled="!formData.project_id"
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
      </a-col>

      <a-col :span="12">
        <a-form-item label="优先级" field="priority">
          <a-select v-model="formData.priority" placeholder="请选择优先级">
            <a-option value="low">低</a-option>
            <a-option value="medium">中</a-option>
            <a-option value="high">高</a-option>
            <a-option value="critical">紧急</a-option>
          </a-select>
        </a-form-item>
      </a-col>
    </a-row>

    <a-form-item label="前置条件" field="precondition">
      <a-textarea
        v-model="formData.precondition"
        placeholder="请输入前置条件"
        :max-length="1000"
        :auto-size="{ minRows: 3, maxRows: 6 }"
        show-word-limit
      />
    </a-form-item>

    <a-form-item label="测试步骤" field="steps">
      <a-textarea
        v-model="formData.steps"
        placeholder="请输入测试步骤"
        :max-length="2000"
        :auto-size="{ minRows: 4, maxRows: 8 }"
        show-word-limit
      />
    </a-form-item>

    <a-form-item label="预期结果" field="expected_result">
      <a-textarea
        v-model="formData.expected_result"
        placeholder="请输入预期结果"
        :max-length="1000"
        :auto-size="{ minRows: 3, maxRows: 6 }"
        show-word-limit
      />
    </a-form-item>

    <a-row :gutter="16">
      <a-col :span="12">
        <a-form-item label="负责人" field="assignee">
          <a-input
            v-model="formData.assignee"
            placeholder="请输入负责人"
          />
        </a-form-item>
      </a-col>

      <a-col :span="12">
        <a-form-item label="标签" field="tags">
          <a-input
            v-model="formData.tags"
            placeholder="多个标签用逗号分隔"
          />
        </a-form-item>
      </a-col>
    </a-row>
  </a-form>
</template>

<script setup lang="ts">
import { ref, reactive, watch, onMounted } from 'vue';
import { Message } from '@arco-design/web-vue';
import qualityCenterApi from '@/api/quality-center';
import type {
  TestCase,
  Project,
  Module,
  Requirement,
  CreateTestCaseDto,
  UpdateTestCaseDto,
} from '@/types/quality-center';

interface Props {
  mode: 'create' | 'edit';
  data?: TestCase | null;
  projects: Project[];
}

const props = withDefaults(defineProps<Props>(), {
  data: null,
});

// 表单引用
const formRef = ref();

// 表单数据
const formData = reactive<CreateTestCaseDto | UpdateTestCaseDto>({
  title: '',
  project_id: 0,
  module_id: 0,
  requirement_id: null,
  priority: 'medium',
  precondition: '',
  steps: '',
  expected_result: '',
  assignee: '',
  tags: '',
  created_by: 'current_user', // TODO: 从用户信息获取
});

// 模块列表
const modules = ref<Module[]>([]);

// 需求列表
const requirements = ref<Requirement[]>([]);

// 表单验证规则
const rules = {
  title: [
    { required: true, message: '请输入测试用例标题' },
    { minLength: 2, message: '标题至少2个字符' },
    { maxLength: 200, message: '标题最多200个字符' },
  ],
  project_id: [
    { required: true, message: '请选择项目' },
  ],
  module_id: [
    { required: true, message: '请选择模块' },
  ],
};

// 加载模块列表
const loadModules = async (projectId: number) => {
  try {
    const result = await qualityCenterApi.getModuleTree(projectId);
    // 扁平化树形结构
    const flattenModules = (nodes: Module[]): Module[] => {
      return nodes.reduce((acc, node) => {
        acc.push(node);
        if (node.children && node.children.length > 0) {
          acc.push(...flattenModules(node.children));
        }
        return acc;
      }, [] as Module[]);
    };
    modules.value = flattenModules(result);
  } catch (error) {
    Message.error('加载模块列表失败');
  }
};

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
  formData.module_id = 0;
  formData.requirement_id = null;
  modules.value = [];
  requirements.value = [];
  
  if (projectId) {
    loadModules(projectId);
    loadRequirements(projectId);
  }
};

// 监听数据变化
watch(
  () => props.data,
  (newData) => {
    if (newData) {
      Object.assign(formData, {
        title: newData.title,
        project_id: newData.project_id,
        module_id: newData.module_id,
        requirement_id: newData.requirement_id,
        priority: newData.priority,
        precondition: newData.precondition,
        steps: newData.steps,
        expected_result: newData.expected_result,
        assignee: newData.assignee,
        tags: newData.tags,
      });
      
      // 加载模块和需求
      if (newData.project_id) {
        loadModules(newData.project_id);
        loadRequirements(newData.project_id);
      }
    } else {
      // 重置表单
      Object.assign(formData, {
        title: '',
        project_id: 0,
        module_id: 0,
        requirement_id: null,
        priority: 'medium',
        precondition: '',
        steps: '',
        expected_result: '',
        assignee: '',
        tags: '',
        created_by: 'current_user',
      });
      modules.value = [];
      requirements.value = [];
    }
  },
  { immediate: true }
);

// 验证表单
const validate = async () => {
  try {
    await formRef.value?.validate();
    return true;
  } catch (error) {
    return false;
  }
};

// 获取表单数据
const getFormData = () => {
  return { ...formData };
};

// 暴露方法
defineExpose({
  validate,
  getFormData,
});
</script>

<style scoped lang="less">
// 样式
</style>
