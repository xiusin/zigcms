<template>
  <div class="category-container">
    <a-card :bordered="false">
      <div class="header-actions">
        <a-space>
          <a-button type="primary" @click="handleAdd()">
            <template #icon><icon-plus /></template>
            添加根分类
          </a-button>
          <a-button @click="expandAll">
            <template #icon><icon-expand /></template>
            全部展开
          </a-button>
          <a-button @click="collapseAll">
            <template #icon><icon-shrink /></template>
            全部收起
          </a-button>
        </a-space>
        <a-input-search
          v-model="searchKey"
          placeholder="搜索分类名称"
          style="width: 300px"
          allow-clear
        />
      </div>

      <a-spin :loading="loading" style="width: 100%">
        <a-tree
          v-if="treeData.length > 0"
          :data="filteredTreeData"
          :default-expand-all="false"
          :expanded-keys="expandedKeys"
          :draggable="true"
          block-node
          @drop="handleDrop"
          @expand="handleExpand"
        >
          <template #title="nodeData">
            <div class="tree-node-title">
              <span>{{ nodeData.title }}</span>
              <a-tag v-if="nodeData.status === 0" color="red" size="small"
                >禁用</a-tag
              >
              <a-tag v-else color="green" size="small">启用</a-tag>
              <div class="tree-node-actions">
                <a-button
                  type="text"
                  size="mini"
                  @click.stop="handleAdd(nodeData)"
                >
                  <template #icon><icon-plus /></template>
                </a-button>
                <a-button
                  type="text"
                  size="mini"
                  @click.stop="handleEdit(nodeData)"
                >
                  <template #icon><icon-edit /></template>
                </a-button>
                <a-popconfirm
                  content="确定删除该分类吗？删除后子分类也会被删除。"
                  @ok="handleDelete(nodeData.key)"
                >
                  <a-button type="text" size="mini" status="danger" @click.stop>
                    <template #icon><icon-delete /></template>
                  </a-button>
                </a-popconfirm>
              </div>
            </div>
          </template>
        </a-tree>
        <a-empty v-else description="暂无分类数据" />
      </a-spin>
    </a-card>

    <!-- 编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="modalTitle"
      width="600px"
      @before-ok="handleSubmit"
      @cancel="handleCancel"
    >
      <a-form :model="formData" :rules="rules" ref="formRef" layout="vertical">
        <a-form-item label="分类名称" field="name" required>
          <a-input v-model="formData.name" placeholder="请输入分类名称" />
        </a-form-item>
        <a-form-item label="分类标识" field="slug" required>
          <a-input
            v-model="formData.slug"
            placeholder="英文标识，如：news"
            :disabled="isEdit"
          />
        </a-form-item>
        <a-form-item label="父级分类" field="parent_id">
          <a-tree-select
            v-model="formData.parent_id"
            :data="parentOptions"
            placeholder="选择父级分类（不选则为根分类）"
            allow-clear
          />
        </a-form-item>
        <a-form-item label="排序" field="sort">
          <a-input-number
            v-model="formData.sort"
            :min="0"
            placeholder="数字越小越靠前"
          />
        </a-form-item>
        <a-form-item label="状态" field="status">
          <a-radio-group v-model="formData.status">
            <a-radio :value="1">启用</a-radio>
            <a-radio :value="0">禁用</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="描述" field="description">
          <a-textarea
            v-model="formData.description"
            placeholder="分类描述"
            :max-length="200"
            show-word-limit
          />
        </a-form-item>
        <a-divider>SEO 配置</a-divider>
        <a-form-item label="SEO 标题" field="seo_title">
          <a-input v-model="formData.seo_title" placeholder="SEO 标题" />
        </a-form-item>
        <a-form-item label="SEO 关键词" field="seo_keywords">
          <a-input
            v-model="formData.seo_keywords"
            placeholder="多个关键词用逗号分隔"
          />
        </a-form-item>
        <a-form-item label="SEO 描述" field="seo_description">
          <a-textarea
            v-model="formData.seo_description"
            placeholder="SEO 描述"
            :max-length="200"
            show-word-limit
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import {
    IconPlus,
    IconEdit,
    IconDelete,
    IconExpand,
    IconShrink,
  } from '@arco-design/web-vue/es/icon';
  import type { TreeNodeData } from '@arco-design/web-vue';
  import {
    getCategoryList,
    createCategory,
    updateCategory,
    deleteCategory,
    sortCategory,
  } from '@/api/cms';
  import type { Category } from '@/types/cms';

  const loading = ref(false);
  const categories = ref<Category[]>([]);
  const searchKey = ref('');
  const expandedKeys = ref<string[]>([]);

  // 表单
  const modalVisible = ref(false);
  const modalTitle = ref('');
  const isEdit = ref(false);
  const formRef = ref();
  const formData = ref<Partial<Category>>({
    name: '',
    slug: '',
    parent_id: undefined,
    sort: 0,
    status: 1,
    description: '',
    seo_title: '',
    seo_keywords: '',
    seo_description: '',
  });

  const rules = {
    name: [{ required: true, message: '请输入分类名称' }],
    slug: [{ required: true, message: '请输入分类标识' }],
  };

  // 转换为树形数据
  const buildTree = (items: Category[], parentId?: number): TreeNodeData[] => {
    return items
      .filter((item) => item.parent_id === parentId)
      .map((item) => ({
        key: String(item.id),
        title: item.name,
        status: item.status,
        children: buildTree(items, item.id),
        ...item,
      }));
  };

  const treeData = computed(() => buildTree(categories.value));

  // 搜索过滤
  const filteredTreeData = computed(() => {
    if (!searchKey.value) return treeData.value;

    const filterTree = (nodes: TreeNodeData[]): TreeNodeData[] => {
      return nodes
        .map((node) => {
          const children = filterTree(node.children || []);
          if (
            node.title?.toLowerCase().includes(searchKey.value.toLowerCase()) ||
            children.length > 0
          ) {
            return { ...node, children };
          }
          return null;
        })
        .filter(Boolean) as TreeNodeData[];
    };

    return filterTree(treeData.value);
  });

  // 父级选项（排除自己和子级）
  const parentOptions = computed(() => {
    const excludeIds = new Set<number>();
    if (isEdit.value && formData.value.id) {
      excludeIds.add(formData.value.id);
      const addChildren = (parentId: number) => {
        categories.value
          .filter((c) => c.parent_id === parentId)
          .forEach((c) => {
            excludeIds.add(c.id);
            addChildren(c.id);
          });
      };
      addChildren(formData.value.id);
    }

    const filtered = categories.value.filter((c) => !excludeIds.has(c.id));
    return buildTree(filtered);
  });

  // 加载数据
  const fetchData = async () => {
    loading.value = true;
    try {
      const res = await getCategoryList();
      categories.value = res.data || [];
    } catch (error) {
      Message.error('加载失败');
    } finally {
      loading.value = false;
    }
  };

  // 展开/收起
  const expandAll = () => {
    const getAllKeys = (nodes: TreeNodeData[]): string[] => {
      return nodes.reduce((keys, node) => {
        keys.push(node.key as string);
        if (node.children) {
          keys.push(...getAllKeys(node.children));
        }
        return keys;
      }, [] as string[]);
    };
    expandedKeys.value = getAllKeys(treeData.value);
  };

  const collapseAll = () => {
    expandedKeys.value = [];
  };

  const handleExpand = (keys: string[]) => {
    expandedKeys.value = keys;
  };

  // 拖拽排序
  const handleDrop = async ({ dragNode, dropNode, dropPosition }: any) => {
    try {
      await sortCategory({
        id: Number(dragNode.key),
        parent_id:
          dropPosition === 0 ? Number(dropNode.key) : dropNode.parent_id,
        sort: dropPosition,
      });
      Message.success('排序成功');
      await fetchData();
    } catch (error) {
      Message.error('排序失败');
    }
  };

  // 新增
  const handleAdd = (node?: TreeNodeData) => {
    modalTitle.value = '添加分类';
    isEdit.value = false;
    formData.value = {
      name: '',
      slug: '',
      parent_id: node ? Number(node.key) : undefined,
      sort: 0,
      status: 1,
      description: '',
      seo_title: '',
      seo_keywords: '',
      seo_description: '',
    };
    modalVisible.value = true;
  };

  // 编辑
  const handleEdit = (node: TreeNodeData) => {
    modalTitle.value = '编辑分类';
    isEdit.value = true;
    const category = categories.value.find((c) => c.id === Number(node.key));
    if (category) {
      formData.value = { ...category };
    }
    modalVisible.value = true;
  };

  // 删除
  const handleDelete = async (key: string) => {
    try {
      await deleteCategory(Number(key));
      Message.success('删除成功');
      await fetchData();
    } catch (error) {
      Message.error('删除失败');
    }
  };

  // 提交
  const handleSubmit = async () => {
    const valid = await formRef.value?.validate();
    if (!valid) {
      try {
        if (isEdit.value) {
          await updateCategory(formData.value.id!, formData.value);
          Message.success('更新成功');
        } else {
          await createCategory(formData.value);
          Message.success('创建成功');
        }
        modalVisible.value = false;
        await fetchData();
        return true;
      } catch (error) {
        Message.error('操作失败');
        return false;
      }
    }
    return false;
  };

  const handleCancel = () => {
    formRef.value?.resetFields();
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style scoped lang="less">
  .category-container {
    padding: 20px;
  }

  .header-actions {
    display: flex;
    justify-content: space-between;
    margin-bottom: 20px;
  }

  .tree-node-title {
    display: flex;
    align-items: center;
    gap: 8px;
    width: 100%;

    .tree-node-actions {
      margin-left: auto;
      display: none;
    }

    &:hover .tree-node-actions {
      display: flex;
      gap: 4px;
    }
  }

  :deep(.arco-tree-node) {
    padding: 4px 0;
  }
</style>
