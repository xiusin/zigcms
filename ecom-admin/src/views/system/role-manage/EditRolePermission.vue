<template>
  <d-drawer
    :title="isEditFlag ? '编辑角色' : '新建角色'"
    :visible="visible"
    :ok-loading="loading"
    width="750px"
    @ok="sendInfo"
    @cancel="onClose"
  >
    <a-form :model="info" layout="vertical">
      <a-form-item
        label="角色名称"
        field="role_name"
        :rules="[{ required: true, message: '请输入角色名称' }]"
      >
        <a-input v-model="info.role_name" placeholder="请输入角色名称" />
      </a-form-item>
      <a-form-item label="角色标识" field="role_key">
        <a-input
          v-model="info.role_key"
          placeholder="请输入角色标识（如：admin、user）"
        />
      </a-form-item>
      <a-form-item label="排序" field="sort">
        <a-input-number
          v-model="info.sort"
          :min="0"
          placeholder="数字越小越靠前"
          style="width: 100%"
        />
      </a-form-item>
      <a-form-item label="备注" field="remark">
        <a-textarea v-model="info.remark" placeholder="请输入备注" :rows="2" />
      </a-form-item>
      <a-form-item label="菜单权限" field="menu_ids">
        <div class="permission-header">
          <a-space>
            <a-checkbox
              :model-value="isSelectAll"
              :indeterminate="isIndeterminate"
              @change="handleSelectAll"
            >
              全选
            </a-checkbox>
            <a-button type="text" size="small" @click="expandAll">
              展开全部
            </a-button>
            <a-button type="text" size="small" @click="collapseAll">
              收起全部
            </a-button>
            <a-button
              type="text"
              size="small"
              :loading="menuTreeLoading"
              @click="fetchMenuTree"
            >
              <template #icon><icon-refresh /></template>
              刷新
            </a-button>
          </a-space>
        </div>
        <a-spin :spinning="menuTreeLoading">
          <a-tree
            ref="treeRef"
            v-model:checked-keys="info.menu_ids"
            :data="menuTree"
            :checkable="true"
            :default-expand-all="false"
            :field-names="{ key: 'id', title: 'title', children: 'children' }"
            :selectable="false"
            style="max-height: 300px; overflow-y: auto; margin-top: 8px"
          />
          <a-empty
            v-if="!menuTreeLoading && menuTree.length === 0"
            description="暂无菜单数据，请联系管理员配置"
          />
        </a-spin>
      </a-form-item>
      <!-- 按钮权限 -->
      <a-form-item label="按钮权限" field="button_perms">
        <div class="permission-header">
          <a-space>
            <a-checkbox
              :model-value="isBtnSelectAll"
              :indeterminate="isBtnIndeterminate"
              @change="handleBtnSelectAll"
            >
              全选
            </a-checkbox>
            <a-button
              type="text"
              size="small"
              :loading="btnPermsLoading"
              @click="fetchButtonPerms"
            >
              <template #icon><icon-refresh /></template>
              刷新
            </a-button>
          </a-space>
        </div>
        <a-spin :spinning="btnPermsLoading">
          <div class="button-perms-container">
            <a-checkbox-group
              v-model="info.button_perms"
              :options="buttonPermsOptions"
              :direction="'horizontal'"
            />
            <a-empty
              v-if="!btnPermsLoading && buttonPermsOptions.length === 0"
              description="暂无可分配的按钮权限"
            />
          </div>
        </a-spin>
      </a-form-item>
    </a-form>
  </d-drawer>
</template>

<script lang="ts" setup>
  import { ref, computed, onMounted } from 'vue';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';
  import DDrawer from '@/components/d-modal/d-drawer.vue';

  const visible = ref(false);
  const loading = ref(false);
  const isEditFlag = ref(false);
  const treeRef = ref();
  const menuTreeLoading = ref(false);
  const btnPermsLoading = ref(false);

  // 菜单树数据
  const menuTree = ref<any[]>([]);

  // 按钮权限选项
  const buttonPermsOptions = ref<any[]>([]);

  // 默认按钮权限列表
  const defaultButtonPerms = [
    { label: '新增', value: 'btn:add' },
    { label: '编辑', value: 'btn:edit' },
    { label: '删除', value: 'btn:delete' },
    { label: '导出', value: 'btn:export' },
    { label: '导入', value: 'btn:import' },
    { label: '查询', value: 'btn:query' },
    { label: '详情', value: 'btn:detail' },
    { label: '审核', value: 'btn:audit' },
    { label: '启用', value: 'btn:enable' },
    { label: '禁用', value: 'btn:disable' },
    { label: '分配权限', value: 'btn:permission' },
    { label: '重置密码', value: 'btn:resetPwd' },
  ];

  const info = ref<any>({
    id: null,
    role_name: null,
    role_key: null,
    sort: 0,
    remark: null,
    menu_ids: [],
    button_perms: [],
  });

  const emits = defineEmits(['refresh']);

  // 计算所有菜单 ID
  const allMenuIds = computed(() => {
    const ids: number[] = [];
    const traverse = (nodes: any[]) => {
      nodes.forEach((node) => {
        ids.push(node.id);
        if (node.children?.length) {
          traverse(node.children);
        }
      });
    };
    traverse(menuTree.value);
    return ids;
  });

  const isSelectAll = computed(() => {
    return (
      allMenuIds.value.length > 0 &&
      allMenuIds.value.every((id) => info.value.menu_ids?.includes(id))
    );
  });

  const isIndeterminate = computed(() => {
    const checked = info.value.menu_ids?.length || 0;
    return checked > 0 && checked < allMenuIds.value.length;
  });

  // 按钮权限全选计算
  const allBtnPerms = computed(() =>
    buttonPermsOptions.value.map((item) => item.value)
  );

  const isBtnSelectAll = computed(() => {
    return (
      allBtnPerms.value.length > 0 &&
      allBtnPerms.value.every((perm) => info.value.button_perms?.includes(perm))
    );
  });

  const isBtnIndeterminate = computed(() => {
    const checked = info.value.button_perms?.length || 0;
    return checked > 0 && checked < allBtnPerms.value.length;
  });

  const handleSelectAll = (checked: boolean) => {
    info.value.menu_ids = checked ? [...allMenuIds.value] : [];
  };

  const handleBtnSelectAll = (checked: boolean) => {
    info.value.button_perms = checked ? [...allBtnPerms.value] : [];
  };

  // 获取菜单树
  const buildTree = (list: any[]) => {
    if (!Array.isArray(list)) return [];
    const map = new Map<number, any>();
    list.forEach((item) => {
      const id = Number(item.id);
      // 核心修复：增加 title 字段供 a-tree 显示，并确保 children 初始化
      map.set(id, { 
        ...item, 
        id, 
        key: id, 
        value: id, 
        title: item.menu_name || item.title || `菜单${id}`,
        children: [] 
      });
    });
    const roots: any[] = [];
    list.forEach((item) => {
      const id = Number(item.id);
      const parentId = Number(item.pid || 0);
      const node = map.get(id);
      if (!node) return;
      if (parentId > 0 && map.has(parentId)) {
        map.get(parentId).children.push(node);
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
      
      // 穿透拦截器包装：优先取 res.data (如果是数组)，否则取 list/items
      let list = [];
      if (Array.isArray(res.data)) {
        list = res.data;
      } else if (res.data && Array.isArray(res.data.list)) {
        list = res.data.list;
      } else if (res.data && Array.isArray(res.data.items)) {
        list = res.data.items;
      }

      if (list.length) {
        menuTree.value = buildTree(list);
        console.log('[EditRolePermission] Menu tree built from', list.length, 'items');
      } else {
        menuTree.value = [];
        console.warn('[EditRolePermission] No menu data found in response');
      }
    } catch (e) {
      menuTree.value = [];
      console.error('获取菜单树失败:', e);
    } finally {
      menuTreeLoading.value = false;
    }
  };

  const fetchRolePermissions = async (roleId: number) => {
    try {
      const url = `/api/system/role/permissions/info?role_id=${roleId}`;
      console.log('[EditRolePermission] Fetching permissions from:', url);
      const res = await request(url, {
        role_id: roleId,
      });
      console.log('[EditRolePermission] FULL RAW RESPONSE:', res);
      
      // 深度查找字段，兼容拦截器包装
      const findField = (obj: any, field: string): any => {
        if (!obj) return null;
        if (Array.isArray(obj[field])) return obj[field];
        if (obj.data) return findField(obj.data, field);
        return null;
      };

      const menuIds = findField(res, 'menu_ids') || [];
      const buttonPerms = findField(res, 'button_perms') || [];

      console.log('[EditRolePermission] Parsed IDs:', { menuIds, buttonPerms });

      // 转换为数字确保树组件能正确匹配 ID
      info.value.menu_ids = menuIds.map((id: any) => Number(id));
      info.value.button_perms = buttonPerms;
    } catch (e) {
      console.error('获取角色权限详情失败:', e);
    }
  };

  // 获取按钮权限列表
  const fetchButtonPerms = async () => {
    btnPermsLoading.value = true;
    try {
      // 优先从后端获取按钮权限配置
      const res = await request('/api/system/role/button-perms', {}, undefined, 'GET');
      if (res.data?.length) {
        buttonPermsOptions.value = res.data;
      } else {
        // 使用默认按钮权限
        buttonPermsOptions.value = defaultButtonPerms;
      }
    } catch (e) {
      // 使用默认按钮权限
      buttonPermsOptions.value = defaultButtonPerms;
      console.error('获取按钮权限失败:', e);
    } finally {
      btnPermsLoading.value = false;
    }
  };

  async function show(item: any) {
    visible.value = true;
    isEditFlag.value = false;
    info.value = {
      id: null,
      role_name: null,
      role_key: null,
      sort: 0,
      remark: null,
      menu_ids: [],
      button_perms: [],
    };
    
    // 1. 先加载菜单树基础数据
    await fetchMenuTree();
    // 2. 加载按钮权限基础数据
    await fetchButtonPerms();
    
    if (item?.id) {
      isEditFlag.value = true;
      Object.assign(info.value, {
        ...item,
        // 这里不要直接覆盖 menu_ids，等 fetchRolePermissions 返回
        menu_ids: [], 
        button_perms: [],
      });
      // 3. 最后根据 roleId 获取当前角色的具体权限
      await fetchRolePermissions(Number(item.id));
    }
  }

  function onClose() {
    visible.value = false;
    info.value = {
      id: null,
      role_name: null,
      role_key: null,
      sort: 0,
      remark: null,
      menu_ids: [],
      button_perms: [],
    };
  }

  async function sendInfo() {
    if (!info.value.role_name) {
      Message.warning('请输入角色名称');
      return;
    }
    loading.value = true;
    const rolePayload = {
      id: info.value.id,
      role_name: info.value.role_name,
      role_key: info.value.role_key,
      sort: info.value.sort,
      remark: info.value.remark,
      status: info.value.status ?? 1,
    };

    request('/api/system/role/save', rolePayload)
      .then(async (res: any) => {
        const roleId =
          info.value.id ||
          res?.data?.id ||
          res?.data?.data?.id ||
          0;

        if (!roleId) {
          throw new Error('角色保存成功但未返回角色ID');
        }

        await request('/api/system/role/permissions/save', {
          role_id: Number(roleId),
          menu_ids: (info.value.menu_ids || []).map((id: number) => Number(id)),
          button_perms: info.value.button_perms || [],
        });

        emits('refresh');
        Message.success('操作成功');
        onClose();
      })
      .catch((err: any) => {
        Message.error(err?.msg || err?.message || '保存失败');
      })
      .finally(() => {
        loading.value = false;
      });
  }

  // 暴露方法供外部调用
  defineExpose({ show, fetchMenuTree, fetchButtonPerms });
</script>

<style scoped>
  .permission-header {
    padding: 8px 12px;
    background: var(--color-fill-1);
    border-radius: 4px;
    margin-bottom: 8px;
  }
  .button-perms-container {
    max-height: 200px;
    overflow-y: auto;
    padding: 8px;
    border: 1px solid var(--color-border);
    border-radius: 4px;
  }
  .button-perms-container :deep(.arco-checkbox-group) {
    display: flex;
    flex-wrap: wrap;
    gap: 8px;
  }
  .button-perms-container :deep(.arco-checkbox-wrapper) {
    margin-right: 0;
  }
</style>
