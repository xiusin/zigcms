<template>
  <d-drawer
    :title="isEditFlag ? '编辑角色权限' : '新建角色'"
    :visible="visible"
    :ok-loading="loading"
    width="750px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <div class="drawer-content-wrapper">
      <!-- 顶部表单区 -->
      <div class="form-header-section">
        <a-form :model="info" layout="vertical" class="compact-form">
          <a-row :gutter="24">
            <a-col :span="12">
              <a-form-item label="角色名称" field="role_name" required>
                <a-input v-model="info.role_name" placeholder="例如：超级管理员" class="glass-input" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="角色标识" field="role_key">
                <a-input v-model="info.role_key" placeholder="例如：admin" class="glass-input" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="显示排序" field="sort">
                <a-input-number v-model="info.sort" :min="0" class="glass-input" style="width: 100%" />
              </a-form-item>
            </a-col>
            <a-col :span="12">
              <a-form-item label="备注说明" field="remark">
                <a-input v-model="info.remark" placeholder="备注角色用途" class="glass-input" />
              </a-form-item>
            </a-col>
          </a-row>
        </a-form>
      </div>

      <!-- 核心权限选择区 - 自动填满剩余空间 -->
      <div class="permission-tree-section">
        <div class="tree-label">权限配置 (勾选菜单与按钮操作)</div>
        <div class="tree-container-glass">
          <!-- 极简工具栏 -->
          <div class="tree-toolbar-modern">
            <div class="toolbar-left">
              <a-checkbox
                :model-value="isSelectAll"
                :indeterminate="isIndeterminate"
                @change="handleSelectAll"
              >
                全选所有权限
              </a-checkbox>
            </div>
            <div class="toolbar-right">
              <a-button-group type="text" size="small">
                <a-button @click="expandAll(true)">
                  <template #icon><icon-expand /></template>
                  展开
                </a-button>
                <a-button @click="expandAll(false)">
                  <template #icon><icon-shrink /></template>
                  折叠
                </a-button>
                <a-button :loading="menuTreeLoading" @click="fetchMenuTree">
                  <template #icon><icon-refresh /></template>
                  刷新
                </a-button>
              </a-button-group>
            </div>
          </div>
          
          <!-- 滚动树区域 -->
          <div class="tree-viewport">
            <a-spin :loading="menuTreeLoading" tip="加载资源树..." style="width: 100%">
              <a-tree
                ref="treeRef"
                v-model:checked-keys="info.menu_ids"
                :data="menuTree"
                :checkable="true"
                :default-expand-all="false"
                :field-names="{ key: 'id', title: 'title', children: 'children' }"
                :selectable="false"
                :check-strictly="false"
                class="refined-tree"
              >
                <template #title="nodeData">
                  <div class="custom-tree-node">
                    <span class="node-icon-wrap">
                      <component :is="nodeData.icon || (nodeData.menu_type === 3 ? 'icon-command' : 'icon-file')" />
                    </span>
                    <span class="node-text">{{ nodeData.title }}</span>
                    <a-tag v-if="nodeData.menu_type === 3" size="mini" class="btn-type-tag">按钮</a-tag>
                    <span v-if="nodeData.perms" class="node-perms-hint">{{ nodeData.perms }}</span>
                  </div>
                </template>
              </a-tree>
              <a-empty v-if="!menuTreeLoading && menuTree.length === 0" />
            </a-spin>
          </div>
        </div>
      </div>
    </div>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { ref, computed } from 'vue';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';

  const visible = ref(false);
  const loading = ref(false);
  const isEditFlag = ref(false);
  const treeRef = ref();
  const menuTreeLoading = ref(false);

  const menuTree = ref<any[]>([]);
  const info = ref<any>({
    id: null,
    role_name: '',
    role_key: '',
    sort: 0,
    remark: '',
    menu_ids: [],
  });

  const emits = defineEmits(['refresh']);

  const allMenuIds = computed(() => {
    const ids: number[] = [];
    const traverse = (nodes: any[]) => {
      nodes.forEach((node) => {
        ids.push(node.id);
        if (node.children?.length) traverse(node.children);
      });
    };
    traverse(menuTree.value);
    return ids;
  });

  const isSelectAll = computed(() => 
    allMenuIds.value.length > 0 && allMenuIds.value.every(id => info.value.menu_ids?.includes(id))
  );

  const isIndeterminate = computed(() => {
    const checkedCount = info.value.menu_ids?.length || 0;
    return checkedCount > 0 && checkedCount < allMenuIds.value.length;
  });

  const handleSelectAll = (val: any) => {
    info.value.menu_ids = val ? [...allMenuIds.value] : [];
  };

  const expandAll = (isExpand: boolean) => {
    treeRef.value?.expandAll(isExpand);
  };

  const buildTree = (list: any[]) => {
    if (!Array.isArray(list)) return [];
    const map = new Map<number, any>();
    list.forEach(item => {
      const id = Number(item.id);
      map.set(id, { 
        ...item, 
        id, 
        key: id, 
        title: item.menu_name || item.title || `节点${id}`,
        children: [] 
      });
    });
    const roots: any[] = [];
    list.forEach(item => {
      const id = Number(item.id);
      const pid = Number(item.pid || 0);
      const node = map.get(id);
      if (pid > 0 && map.has(pid)) {
        map.get(pid).children.push(node);
      } else {
        roots.push(node);
      }
    });
    return roots;
  };

  const fetchMenuTree = async () => {
    menuTreeLoading.value = true;
    try {
      const res = await request('/api/system/menu/tree', {});
      const list = Array.isArray(res.data) ? res.data : (res.data?.list || res.data?.items || []);
      menuTree.value = buildTree(list);
    } catch (e) {
      console.error('Fetch tree failed', e);
    } finally {
      menuTreeLoading.value = false;
    }
  };

  const fetchRolePermissions = async (roleId: number) => {
    try {
      const res = await request(`/api/system/role/permissions/info?role_id=${roleId}`, { role_id: roleId });
      const findField = (obj: any, field: string): any => {
        if (!obj) return null;
        if (Array.isArray(obj[field])) return obj[field];
        if (obj.data) return findField(obj.data, field);
        return null;
      };
      const menuIds = findField(res, 'menu_ids') || [];
      info.value.menu_ids = menuIds.map((id: any) => Number(id));
    } catch (e) {
      console.error('Fetch permissions failed', e);
    }
  };

  async function show(item: any) {
    visible.value = true;
    isEditFlag.value = !!item?.id;
    info.value = {
      id: item?.id || null,
      role_name: item?.role_name || '',
      role_key: item?.role_key || '',
      sort: item?.sort || 0,
      remark: item?.remark || '',
      menu_ids: [],
    };
    await fetchMenuTree();
    if (item?.id) await fetchRolePermissions(Number(item.id));
  }

  function onClose() {
    visible.value = false;
  }

  async function sendInfo() {
    if (!info.value.role_name) {
      Message.warning('请输入角色名称');
      return;
    }
    loading.value = true;
    try {
      // 统一调用单个接口，带上 menu_ids
      await request('/api/system/role/save', {
        ...info.value,
        menu_ids: info.value.menu_ids.map(Number),
        status: info.value.status ?? 1,
      });

      emits('refresh');
      Message.success('保存成功');
      onClose();
    } catch (err: any) {
      Message.error(err?.msg || '操作失败');
    } finally {
      loading.value = false;
    }
  }

  defineExpose({ show });
</script>

<style scoped lang="less">
  /* 填满父容器的关键布局 */
  .drawer-content-wrapper {
    display: flex;
    flex-direction: column;
    height: 100%;
    gap: 16px;
  }

  .form-header-section {
    flex-shrink: 0;
    padding: 4px;
  }

  .permission-tree-section {
    flex: 1; /* 自动撑满 */
    display: flex;
    flex-direction: column;
    min-height: 0; /* 允许内部滚动 */
  }

  .tree-label {
    font-size: 13px;
    font-weight: 600;
    color: var(--color-text-2);
    margin-bottom: 8px;
    display: flex;
    align-items: center;
    &::before {
      content: '';
      width: 3px;
      height: 14px;
      background: rgb(var(--primary-6));
      margin-right: 8px;
      border-radius: 2px;
    }
  }

  /* 玻璃态容器容器 */
  .tree-container-glass {
    flex: 1;
    display: flex;
    flex-direction: column;
    border: 1px solid rgba(0, 0, 0, 0.08);
    border-radius: 12px;
    background: rgba(255, 255, 255, 0.4);
    backdrop-filter: blur(10px);
    overflow: hidden;
    box-shadow: inset 0 1px 1px rgba(255, 255, 255, 0.6);
  }

  .tree-toolbar-modern {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 16px;
    background: rgba(var(--primary-6), 0.04);
    border-bottom: 1px solid rgba(0, 0, 0, 0.05);
    
    :deep(.arco-checkbox-label) {
      font-size: 13px;
      font-weight: 500;
    }
  }

  .tree-viewport {
    flex: 1;
    overflow-y: auto;
    padding: 12px;
    
    &::-webkit-scrollbar { width: 5px; }
    &::-webkit-scrollbar-thumb {
      background: rgba(0, 0, 0, 0.1);
      border-radius: 10px;
    }
  }

  .refined-tree {
    background: transparent;
    :deep(.arco-tree-node) {
      padding: 4px 8px;
      border-radius: 6px;
      transition: all 0.2s;
      &:hover { background: rgba(var(--primary-6), 0.05); }
    }
  }

  .custom-tree-node {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 13px;

    .node-icon-wrap {
      color: var(--color-text-3);
      font-size: 14px;
      display: flex;
    }

    .btn-type-tag {
      background: linear-gradient(135deg, #ff9a44 0%, #fc6076 100%);
      color: white;
      border: none;
      font-weight: 600;
      border-radius: 4px;
      box-shadow: 0 2px 4px rgba(252, 96, 118, 0.2);
    }

    .node-perms-hint {
      font-size: 11px;
      color: var(--color-text-4);
      font-family: monospace;
      margin-left: auto;
      padding-left: 20px;
    }
  }

  .glass-input {
    background: rgba(255, 255, 255, 0.6) !important;
    border: 1px solid rgba(0, 0, 0, 0.1);
    border-radius: 8px;
    transition: all 0.2s;
    &:hover, &-focus {
      background: #fff !important;
      border-color: rgb(var(--primary-6)) !important;
      box-shadow: 0 0 0 3px rgba(var(--primary-6), 0.1);
    }
  }
</style>
