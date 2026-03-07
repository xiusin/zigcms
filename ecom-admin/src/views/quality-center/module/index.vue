<template>
  <div class="module-management">
    <!-- 页面头部 -->
    <div class="page-header">
      <a-breadcrumb>
        <a-breadcrumb-item>质量中心</a-breadcrumb-item>
        <a-breadcrumb-item>模块管理</a-breadcrumb-item>
      </a-breadcrumb>
      
      <div class="header-actions">
        <a-input-search
          v-model="searchKeyword"
          placeholder="搜索模块名称"
          style="width: 300px"
          @search="handleSearch"
          @clear="handleClearSearch"
          allow-clear
        />
        <a-button type="primary" @click="handleCreate">
          <template #icon><icon-plus /></template>
          创建模块
        </a-button>
      </div>
    </div>

    <!-- 项目选择 -->
    <a-card class="project-selector" :bordered="false">
      <a-select
        v-model="selectedProjectId"
        placeholder="选择项目"
        style="width: 300px"
        @change="handleProjectChange"
        :loading="projectsLoading"
      >
        <a-option
          v-for="project in projects"
          :key="project.id"
          :value="project.id"
          :label="project.name"
        >
          {{ project.name }}
        </a-option>
      </a-select>
    </a-card>

    <!-- 模块树 -->
    <a-card class="module-tree-card" :bordered="false">
      <template #title>
        <span>模块树</span>
        <a-tag v-if="selectedProjectId" color="blue" style="margin-left: 12px">
          共 {{ totalModules }} 个模块
        </a-tag>
      </template>

      <a-empty v-if="!selectedProjectId" description="请先选择项目" />
      
      <!-- 骨架屏 -->
      <CardSkeleton v-else-if="isInitialLoad" :show-title="false" :content-rows="8" />
      
      <!-- 模块树内容 -->
      <ModuleTree
        v-else
        :tree-data="treeData"
        :search-keyword="searchKeyword"
        :loading="dataLoading"
        @create="handleCreateChild"
        @edit="handleEdit"
        @delete="handleDelete"
        @move="handleMove"
        @refresh="loadModuleTree"
      />
    </a-card>

    <!-- 模块表单弹窗 -->
    <a-modal
      v-model:visible="formVisible"
      :title="formMode === 'create' ? '创建模块' : '编辑模块'"
      :width="600"
      @ok="handleFormSubmit"
      @cancel="handleFormCancel"
      :confirm-loading="formSubmitting"
    >
      <ModuleForm
        ref="formRef"
        :mode="formMode"
        :project-id="selectedProjectId"
        :parent-id="formParentId"
        :module-data="currentModule"
        :tree-data="treeData"
      />
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted } from 'vue';
import { Message, Modal } from '@arco-design/web-vue';
import { IconPlus } from '@arco-design/web-vue/es/icon';
import ModuleTree from './components/ModuleTree.vue';
import ModuleForm from './components/ModuleForm.vue';
import { CardSkeleton } from '@/components/skeleton';
import qualityCenterApi from '@/api/quality-center';
import {
  showSuccess,
  showError,
  showDeleteConfirm,
  withFeedback,
} from '@/utils/feedback';
import { keyboard, CommonShortcuts } from '@/utils/keyboard';
import type { Project, Module, ModuleTreeNode, CreateModuleDto, UpdateModuleDto, MoveModuleDto } from '@/types/quality-center';

// ==================== 状态管理 ====================

const dataLoading = ref(false);
const isInitialLoad = ref(true);
const projectsLoading = ref(false);
const formVisible = ref(false);
const formSubmitting = ref(false);
const formMode = ref<'create' | 'edit'>('create');
const formParentId = ref<number | null>(null);

const projects = ref<Project[]>([]);
const selectedProjectId = ref<number | null>(null);
const treeData = ref<ModuleTreeNode[]>([]);
const searchKeyword = ref('');
const currentModule = ref<Module | null>(null);

const formRef = ref();

// ==================== 计算属性 ====================

const totalModules = computed(() => {
  const countNodes = (nodes: ModuleTreeNode[]): number => {
    return nodes.reduce((count, node) => {
      return count + 1 + (node.children ? countNodes(node.children) : 0);
    }, 0);
  };
  return countNodes(treeData.value);
});

// ==================== 生命周期 ====================

// 注册键盘快捷键
const registerShortcuts = () => {
  // Ctrl+F 聚焦搜索框
  keyboard.register(
    CommonShortcuts.search(() => {
      const searchInput = document.querySelector<HTMLInputElement>(
        '.header-actions input[type="text"]'
      );
      searchInput?.focus();
    })
  );

  // Esc 关闭弹窗
  keyboard.register(
    CommonShortcuts.escape(() => {
      if (formVisible.value) {
        formVisible.value = false;
        return false;
      }
    })
  );
};

onMounted(() => {
  loadProjects();
  registerShortcuts();
});

onUnmounted(() => {
  keyboard.unregisterAll();
});

// ==================== 数据加载 ====================

/**
 * 加载项目列表
 */
const loadProjects = async () => {
  try {
    projectsLoading.value = true;
    const result = await qualityCenterApi.getProjects();
    projects.value = result.items.filter(p => p.status === 'active');
    
    // 自动选择第一个项目
    if (projects.value.length > 0 && !selectedProjectId.value) {
      selectedProjectId.value = projects.value[0].id!;
      await loadModuleTree();
    }
  } catch (error: any) {
    showError(error?.message || '加载项目列表失败');
  } finally {
    projectsLoading.value = false;
  }
};

/**
 * 加载模块树
 */
const loadModuleTree = async () => {
  if (!selectedProjectId.value) return;
  
  dataLoading.value = true;
  try {
    treeData.value = await qualityCenterApi.getModuleTree(selectedProjectId.value);
    
    // 首次加载完成
    if (isInitialLoad.value) {
      isInitialLoad.value = false;
    }
  } catch (error: any) {
    showError(error?.message || '加载模块树失败');
  } finally {
    dataLoading.value = false;
  }
};

// ==================== 事件处理 ====================

/**
 * 项目切换
 */
const handleProjectChange = async () => {
  searchKeyword.value = '';
  await loadModuleTree();
};

/**
 * 搜索
 */
const handleSearch = () => {
  // 搜索逻辑在 ModuleTree 组件中实现
};

/**
 * 清除搜索
 */
const handleClearSearch = () => {
  searchKeyword.value = '';
};

/**
 * 创建根模块
 */
const handleCreate = () => {
  if (!selectedProjectId.value) {
    showError('请先选择项目');
    return;
  }
  
  formMode.value = 'create';
  formParentId.value = null;
  currentModule.value = null;
  formVisible.value = true;
};

/**
 * 创建子模块
 */
const handleCreateChild = (parentId: number) => {
  formMode.value = 'create';
  formParentId.value = parentId;
  currentModule.value = null;
  formVisible.value = true;
};

/**
 * 编辑模块
 */
const handleEdit = async (id: number) => {
  try {
    dataLoading.value = true;
    currentModule.value = await qualityCenterApi.getModule(id);
    formMode.value = 'edit';
    formParentId.value = currentModule.value.parent_id || null;
    formVisible.value = true;
  } catch (error: any) {
    showError(error?.message || '加载模块信息失败');
  } finally {
    dataLoading.value = false;
  }
};

/**
 * 删除模块
 */
const handleDelete = async (id: number, hasChildren: boolean) => {
  const confirmed = await showDeleteConfirm(
    hasChildren 
      ? '该模块包含子模块，删除后子模块也会被删除，是否继续？'
      : '确定要删除该模块吗？',
    '确认删除'
  );
  
  if (!confirmed) return;

  await withFeedback(
    () => qualityCenterApi.deleteModule(id),
    {
      loadingText: '删除中...',
      successText: '删除成功',
      errorText: '删除失败',
    }
  );
  
  await loadModuleTree();
};

/**
 * 移动模块
 */
const handleMove = async (id: number, dto: MoveModuleDto) => {
  await withFeedback(
    () => qualityCenterApi.moveModule(id, dto),
    {
      loadingText: '移动中...',
      successText: '移动成功',
      errorText: '移动失败',
    }
  );
  
  await loadModuleTree();
};

/**
 * 表单提交
 */
const handleFormSubmit = async () => {
  try {
    const valid = await formRef.value?.validate();
    if (!valid) return;
    
    formSubmitting.value = true;
    const formData = formRef.value?.getFormData();
    
    await withFeedback(
      async () => {
        if (formMode.value === 'create') {
          const dto: CreateModuleDto = {
            project_id: selectedProjectId.value!,
            parent_id: formParentId.value,
            name: formData.name,
            description: formData.description || '',
            created_by: 'current_user', // TODO: 从用户上下文获取
          };
          await qualityCenterApi.createModule(dto);
        } else {
          const dto: UpdateModuleDto = {
            name: formData.name,
            description: formData.description,
          };
          await qualityCenterApi.updateModule(currentModule.value!.id!, dto);
        }
      },
      {
        loadingText: formMode.value === 'create' ? '创建中...' : '更新中...',
        successText: formMode.value === 'create' ? '创建成功' : '更新成功',
        errorText: formMode.value === 'create' ? '创建失败' : '更新失败',
      }
    );
    
    formVisible.value = false;
    await loadModuleTree();
  } catch (error) {
    // 验证失败，不显示错误提示
  } finally {
    formSubmitting.value = false;
  }
};

/**
 * 表单取消
 */
const handleFormCancel = () => {
  formVisible.value = false;
  currentModule.value = null;
};
</script>

<style scoped lang="less">
.module-management {
  padding: 20px;
  
  .page-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 20px;
    
    .header-actions {
      display: flex;
      gap: 12px;
    }
  }
  
  .project-selector {
    margin-bottom: 20px;
  }
  
  .module-tree-card {
    min-height: 600px;
    
    :deep(.arco-card-body) {
      padding: 20px;
    }
  }
}
</style>
