<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>菜单管理</span>
          <a-tag color="blue">{{ tableTotal }} 个菜单</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            添加菜单
          </a-button>
          <a-button size="small" @click="refreshData">
            <template #icon>
              <icon-refresh />
            </template>
            刷新
          </a-button>
        </a-space>
      </template>

      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入菜单名称搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="expandAll">
              <template #icon>
                <icon-expand />
              </template>
              展开全部
            </a-button>
            <a-button size="small" @click="collapseAll">
              <template #icon>
                <icon-shrink />
              </template>
              收起全部
            </a-button>
            <a-button size="small" @click="handleExport">
              <template #icon>
                <icon-download />
              </template>
              导出
            </a-button>
          </a-space>
        </template>
      </SearchForm>

      <a-table
        ref="tableRef"
        :data="tableData"
        :columns="columns"
        :expanded-keys="expandedKeys"
        row-key="id"
        :pagination="false"
        @expand="handleExpandChange"
      >
        <template #icon="{ record }">
          <span class="menu-icon">
            <component :is="record.icon || 'IconMenu'" />
          </span>
        </template>
        <template #is_hide="{ record }">
          <a-tag :color="record.is_hide === 1 ? 'orange' : 'green'">
            {{ record.is_hide === 1 ? '隐藏' : '显示' }}
          </a-tag>
        </template>
        <template #is_cache="{ record }">
          <a-tag :color="record.is_cache === 1 ? 'blue' : 'gray'">
            {{ record.is_cache === 1 ? '缓存' : '不缓存' }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            :loading="record.loading"
            size="small"
            @click="changeStatus(record)"
          ></a-switch>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="openModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-button
              v-if="record.pid === 0"
              type="text"
              size="small"
              @click="addChild(record)"
            >
              <template #icon><icon-plus /></template>
              添加子级
            </a-button>
            <a-button
              v-if="record.menu_type === 2"
              type="text"
              size="small"
              @click="handlePermission(record)"
            >
              <template #icon><icon-safe /></template>
              权限
            </a-button>
            <a-popconfirm
              :content="`确定要删除该菜单吗?`"
              position="left"
              @ok="deleteMenu(record)"
            >
              <a-button type="text" size="small" status="danger">
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </div>
        </template>
      </a-table>
    </a-card>

    <!-- 菜单编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑菜单' : '添加菜单'"
      :width="600"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-form-item label="上级菜单" field="pid">
          <a-tree-select
            v-model="formData.pid"
            :data="menuTreeData"
            :field-names="{
              key: 'id',
              title: 'menu_name',
              children: 'children',
            }"
            placeholder="请选择上级菜单"
            allow-clear
          />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="菜单名称" field="menu_name">
              <a-input
                v-model="formData.menu_name"
                placeholder="请输入菜单名称"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="菜单图标" field="icon">
              <a-select
                v-model="formData.icon"
                placeholder="选择图标"
                allow-search
              >
                <a-option value="icon-home"><icon-home /> 首页</a-option>
                <a-option value="icon-dashboard"
                  ><icon-dashboard /> 仪表盘</a-option
                >
                <a-option value="icon-user"><icon-user /> 用户</a-option>
                <a-option value="icon-user-group"
                  ><icon-user-group /> 用户组</a-option
                >
                <a-option value="icon-settings"
                  ><icon-settings /> 设置</a-option
                >
                <a-option value="icon-tool"><icon-tool /> 工具</a-option>
                <a-option value="icon-lock"><icon-lock /> 锁定</a-option>
                <a-option value="icon-unlock"><icon-unlock /> 解锁</a-option>
                <a-option value="icon-cart"><icon-cart /> 购物车</a-option>
                <a-option value="icon-money"><icon-money /> 金钱</a-option>
                <a-option value="icon-shopping-cart"
                  ><icon-shopping-cart /> 订单</a-option
                >
                <a-option value="icon-file"><icon-file /> 文件</a-option>
                <a-option value="icon-folder"><icon-folder /> 文件夹</a-option>
                <a-option value="icon-tag"><icon-tag /> 标签</a-option>
                <a-option value="icon-star"><icon-star /> 星星</a-option>
                <a-option value="icon-heart"><icon-heart /> 爱心</a-option>
                <a-option value="icon-star-fill"
                  ><icon-star-fill /> 星星填充</a-option
                >
                <a-option value="icon-link"><icon-link /> 链接</a-option>
                <a-option value="icon-apps"><icon-apps /> 应用</a-option>
                <a-option value="icon-menu"><icon-menu /> 菜单</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="菜单类型" field="menu_type">
              <a-select
                v-model="formData.menu_type"
                placeholder="请选择菜单类型"
              >
                <a-option :value="1">目录</a-option>
                <a-option :value="2">菜单</a-option>
                <a-option :value="3">按钮</a-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="排序" field="sort">
              <a-input-number
                v-model="formData.sort"
                :min="0"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item
          v-if="formData.menu_type === 2"
          label="路由地址"
          field="path"
        >
          <a-input v-model="formData.path" placeholder="请输入路由地址" />
        </a-form-item>
        <a-form-item
          v-if="formData.menu_type === 2"
          label="组件路径"
          field="component"
        >
          <a-input v-model="formData.component" placeholder="请输入组件路径" />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="8">
            <a-form-item label="是否隐藏" field="is_hide">
              <a-switch v-model="formData.is_hide" />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item label="是否缓存" field="is_cache">
              <a-switch v-model="formData.is_cache" />
            </a-form-item>
          </a-col>
          <a-col :span="8">
            <a-form-item label="状态" field="status">
              <a-switch v-model="formData.status" />
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>
    </a-modal>

    <!-- 权限配置弹窗 -->
    <a-modal
      v-model:visible="permissionVisible"
      title="按钮权限配置"
      :width="500"
      :unmount-on-close="true"
      @ok="handlePermissionSave"
    >
      <a-alert type="info" style="margin-bottom: 16px">
        配置该菜单的按钮权限，用于细粒度控制用户的操作权限
      </a-alert>
      <a-checkbox-group v-model="permissionList">
        <a-space direction="vertical" style="width: 100%">
          <a-checkbox
            v-for="item in allPermissions"
            :key="item.code"
            :value="item.code"
          >
            {{ item.name }}
          </a-checkbox>
        </a-space>
      </a-checkbox-group>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted, computed } from 'vue';
  import {
    IconEdit,
    IconPlus,
    IconDelete,
    IconMenu,
  } from '@arco-design/web-vue/es/icon';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';

  const tableRef = ref();
  const tableData = ref<any[]>([]);
  const menuTreeData = ref<any[]>([]);
  const expandedKeys = ref<(string | number)[]>([]);
  const modalVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();

  // 表格数据总数
  const tableTotal = computed(() => tableData.value?.length || 0);

  // 搜索表单数据
  const formModel = reactive({
    content: '',
  });

  // 生成默认表单数据
  const generateFormModel = () => {
    return {
      content: '',
    };
  };

  // 搜索规则
  const searchRules = ref<any[]>([
    {
      label: '菜单名称',
      field: 'menu_name',
      type: 'input',
      placeholder: '请输入菜单名称',
    },
  ]);

  // 基础搜索规则
  const baseSearchRules = ref<any[]>([
    { label: '菜单名称', field: 'menu_name' },
  ]);

  // 处理搜索
  const handleSubmit = () => {
    fetchData();
  };

  // 刷新数据
  const refreshData = () => {
    fetchData();
    Message.success('刷新成功');
  };

  const formData = reactive({
    id: 0,
    pid: 0,
    menu_name: '',
    icon: '',
    menu_type: 2,
    path: '',
    component: '',
    sort: 0,
    is_hide: false,
    is_cache: false,
    status: true,
  });

  const rules = {
    menu_name: [{ required: true, message: '请输入菜单名称' }],
    menu_type: [{ required: true, message: '请选择菜单类型' }],
  };

  const columns = [
    { title: '菜单名称', dataIndex: 'menu_name', width: 200 },
    { title: '图标', dataIndex: 'icon', width: 60, slotName: 'icon' },
    { title: '菜单类型', dataIndex: 'menu_type', width: 100 },
    { title: '路由地址', dataIndex: 'path', ellipsis: true },
    { title: '组件路径', dataIndex: 'component', ellipsis: true },
    { title: '隐藏', dataIndex: 'is_hide', width: 80, slotName: 'is_hide' },
    { title: '缓存', dataIndex: 'is_cache', width: 80, slotName: 'is_cache' },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 220, slotName: 'action' },
  ];

  const fetchData = () => {
    request('/api/system/menu/list')
      .then((res: any) => {
        const data = res.data?.list || res.data || [];
        const safeData = Array.isArray(data) ? data : [];
        tableData.value = safeData;
        menuTreeData.value = [
          { id: 0, menu_name: '顶级菜单', children: safeData },
        ];
        expandedKeys.value = [];
      })
      .catch(() => {
        tableData.value = [];
        menuTreeData.value = [];
        expandedKeys.value = [];
      });
  };

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, {
        ...record,
        is_hide: record.is_hide === 1,
        is_cache: record.is_cache === 1,
        status: record.status === 1,
      });
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        pid: 0,
        menu_name: '',
        icon: '',
        menu_type: 2,
        path: '',
        component: '',
        sort: 0,
        is_hide: false,
        is_cache: false,
        status: true,
      });
    }
    modalVisible.value = true;
  };

  const addChild = (record: any) => {
    openModal({});
    formData.pid = record.id;
    formData.menu_type = 2;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    const params = {
      ...formData,
      is_hide: formData.is_hide ? 1 : 0,
      is_cache: formData.is_cache ? 1 : 0,
      status: formData.status ? 1 : 0,
    };

    request('/api/system/menu/save', params).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      modalVisible.value = false;
      fetchData();
    });
  };

  // 权限配置弹窗
  const permissionVisible = ref(false);
  const currentMenuId = ref(0);
  const permissionList = ref<string[]>([]);
  const allPermissions = [
    { id: 1, name: '查看', code: 'view' },
    { id: 2, name: '新增', code: 'add' },
    { id: 3, name: '编辑', code: 'edit' },
    { id: 4, name: '删除', code: 'delete' },
    { id: 5, name: '导出', code: 'export' },
    { id: 6, name: '导入', code: 'import' },
  ];

  const handlePermission = (record: any) => {
    currentMenuId.value = record.id;
    // 从后端获取该菜单已配置的权限
    request('/api/system/menu/permissions', { menu_id: record.id })
      .then((res: any) => {
        permissionList.value = res.data?.permissions || [];
      })
      .catch(() => {
        permissionList.value = [];
      });
    permissionVisible.value = true;
  };

  const handlePermissionSave = () => {
    request('/api/system/menu/save-permissions', {
      menu_id: currentMenuId.value,
      permissions: permissionList.value,
    })
      .then(() => {
        Message.success('权限配置保存成功');
        permissionVisible.value = false;
      })
      .catch(() => {
        Message.error('权限配置保存失败');
      });
  };

  // 导出菜单
  const handleExport = () => {
    Message.success('正在导出菜单数据...');
    request('/api/system/menu/export', {})
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `菜单数据_${new Date().getTime()}.json`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  const changeStatus = (record: any) => {
    record.loading = true;
    request('/api/system/menu/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    })
      .then(() => {
        Message.success('状态更新成功');
        fetchData();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  const deleteMenu = (record: any) => {
    request('/api/system/menu/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      fetchData();
    });
  };

  const handleExpandChange = (rowKey: string | number, record: any) => {
    const index = expandedKeys.value.indexOf(rowKey);
    if (index > -1) {
      expandedKeys.value.splice(index, 1);
    } else {
      expandedKeys.value.push(rowKey);
    }
  };

  const expandAll = () => {
    // 展开全部 - 递归获取所有有子菜单的行的 key
    const getAllParentKeys = (rows: any[]): (string | number)[] => {
      const keys: (string | number)[] = [];
      rows.forEach((row) => {
        if (row.children && row.children.length > 0) {
          keys.push(row.id);
          keys.push(...getAllParentKeys(row.children));
        }
      });
      return keys;
    };
    expandedKeys.value = getAllParentKeys(tableData.value);
    Message.success('已展开全部');
  };

  const collapseAll = () => {
    // 收起全部
    expandedKeys.value = [];
    Message.success('已收起全部');
  };

  onMounted(() => {
    fetchData();
  });
</script>

<style lang="less" scoped>
  .table-card {
    .table-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16px;
      border-bottom: 1px solid var(--color-border-1);
    }
  }

  .menu-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 24px;
    height: 24px;
    font-size: 16px;
    color: var(--color-primary);
  }

  .action-btns {
    display: flex;
    align-items: center;
    gap: 4px;

    :deep(.arco-btn) {
      padding: 2px 8px;
      font-size: 12px;
      border-radius: 4px;

      .arco-btn-icon {
        font-size: 12px;
      }
    }

    :deep(.arco-btn-text) {
      color: var(--color-primary);

      &:hover {
        background: var(--color-primary-light-1);
      }
    }

    :deep(.arco-btn-text.status-danger) {
      color: rgb(var(--red-6));

      &:hover {
        background: rgb(var(--red-1));
      }
    }
  }

  :deep(.child-table) {
    padding: 8px 16px;
    background: var(--color-fill-1);
    border-radius: 4px;
    margin: 8px 0;

    .arco-table {
      background: transparent;
    }
  }
</style>
