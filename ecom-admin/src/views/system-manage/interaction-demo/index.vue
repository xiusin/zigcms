<template>
  <div class="interaction-demo-fullscreen">
    <a-card title="🔗 业务交互完整演示" :bordered="false">
      <a-tabs default-active-key="1" type="card-gutter">
        <!-- Tab 1: 主从表联动 -->
        <a-tab-pane key="1" title="主从表联动">
          <a-row :gutter="16">
            <a-col :span="6">
              <a-card
                title="部门树"
                size="small"
                :body-style="{
                  padding: '12px',
                  height: '70vh',
                  overflow: 'auto',
                }"
              >
                <template #extra>
                  <a-space size="small">
                    <a-button size="mini" type="primary" @click="handleAddRoot">
                      <template #icon><icon-plus /></template>
                    </a-button>
                    <a-button size="mini" @click="handleExportTree">
                      <template #icon><icon-download /></template>
                    </a-button>
                  </a-space>
                </template>
                <a-space
                  direction="vertical"
                  style="width: 100%; margin-bottom: 12px"
                  size="small"
                >
                  <a-input-search
                    v-model="treeSearchValue"
                    placeholder="搜索部门"
                    allow-clear
                    @input="debouncedSearch"
                    @clear="handleTreeSearch"
                  />
                  <a-space>
                    <a-button size="small" @click="expandAll"
                      ><template #icon><icon-down /></template
                      >全部展开</a-button
                    >
                    <a-button size="small" @click="collapseAll"
                      ><template #icon><icon-up /></template>全部收起</a-button
                    >
                  </a-space>
                </a-space>
                <a-spin :loading="treeLoading" style="width: 100%">
                  <a-empty
                    v-if="filteredTreeData.length === 0"
                    description="暂无数据"
                  />
                  <a-tree
                    v-else
                    ref="treeRef"
                    :data="filteredTreeData"
                    :default-expand-all="true"
                    :show-line="true"
                    :draggable="true"
                    @select="handleDeptSelect"
                    @drop="handleDrop"
                  >
                    <template #title="nodeData">
                      <a-dropdown
                        trigger="contextMenu"
                        @select="(val) => handleContextMenu(val, nodeData)"
                      >
                        <span
                          :style="{
                            color:
                              treeSearchValue &&
                              nodeData.title.includes(treeSearchValue)
                                ? '#165dff'
                                : '',
                          }"
                        >
                          <icon-folder
                            v-if="nodeData.children?.length"
                            style="margin-right: 4px"
                          />
                          <icon-file v-else style="margin-right: 4px" />
                          {{ nodeData.title }}
                        </span>
                        <template #content>
                          <a-doption value="add"
                            ><icon-plus /> 添加子节点</a-doption
                          >
                          <a-doption value="edit"><icon-edit /> 编辑</a-doption>
                          <a-doption value="delete"
                            ><icon-delete /> 删除</a-doption
                          >
                        </template>
                      </a-dropdown>
                      <a-tag
                        v-if="nodeData.status"
                        color="green"
                        size="small"
                        style="margin-left: 8px"
                        >启用</a-tag
                      >
                      <a-tag
                        v-else
                        color="red"
                        size="small"
                        style="margin-left: 8px"
                        >禁用</a-tag
                      >
                    </template>
                  </a-tree>
                </a-spin>
              </a-card>
            </a-col>
            <a-col :span="18">
              <a-card
                title="部门用户"
                size="small"
                :body-style="{ padding: '12px' }"
              >
                <template #extra>
                  <a-space>
                    <a-tag color="blue">{{
                      currentDept?.title || '未选择部门'
                    }}</a-tag>
                    <a-tag color="green">用户数: {{ userCount }}</a-tag>
                  </a-space>
                </template>
                <AmisCrud
                  id="user_crud"
                  ref="userCrudRef"
                  :config="userConfig"
                />
              </a-card>
            </a-col>
          </a-row>
        </a-tab-pane>

        <!-- Tab 2: 数据联动 -->
        <a-tab-pane key="2" title="数据联动">
          <a-row :gutter="16">
            <a-col :span="12">
              <a-card title="分类管理" size="small">
                <AmisCrud id="category_crud" :config="categoryConfig" />
              </a-card>
            </a-col>
            <a-col :span="12">
              <a-card title="商品管理" size="small">
                <AmisCrud id="product_crud" :config="productConfig" />
              </a-card>
            </a-col>
          </a-row>
        </a-tab-pane>

        <!-- Tab 3: 实时统计 -->
        <a-tab-pane key="3" title="实时统计">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-row :gutter="16">
              <a-col :span="6"
                ><a-statistic title="总用户数" :value="stats.totalUsers"
              /></a-col>
              <a-col :span="6"
                ><a-statistic title="活跃用户" :value="stats.activeUsers"
              /></a-col>
              <a-col :span="6"
                ><a-statistic title="今日新增" :value="stats.todayNew"
              /></a-col>
              <a-col :span="6"
                ><a-statistic title="操作次数" :value="operationCount"
              /></a-col>
            </a-row>
            <AmisCrud id="stats_crud" :config="statsConfig" />
          </a-space>
        </a-tab-pane>

        <!-- Tab 4: 批量操作 -->
        <a-tab-pane key="4" title="批量操作">
          <a-space direction="vertical" :size="16" style="width: 100%">
            <a-card title="批量操作工具" size="small">
              <a-space>
                <a-button size="small" type="primary" @click="handleBatchEnable"
                  >批量启用</a-button
                >
                <a-button size="small" @click="handleBatchDisable"
                  >批量禁用</a-button
                >
                <a-button
                  size="small"
                  status="danger"
                  @click="handleBatchDelete"
                  >批量删除</a-button
                >
                <a-tag>已选择: {{ selectedCount }} 条</a-tag>
              </a-space>
            </a-card>
            <AmisCrud
              id="batch_crud"
              ref="batchCrudRef"
              :config="batchConfig"
            />
          </a-space>
        </a-tab-pane>

        <!-- Tab 5: 操作日志 -->
        <a-tab-pane key="5" title="操作日志">
          <a-row :gutter="16">
            <a-col :span="16"
              ><AmisCrud id="log_crud" :config="logConfig"
            /></a-col>
            <a-col :span="8">
              <a-card
                title="实时日志"
                size="small"
                :body-style="{ height: '70vh', overflow: 'auto' }"
              >
                <a-timeline>
                  <a-timeline-item
                    v-for="(log, index) in recentLogs"
                    :key="index"
                    :color="log.type === 'success' ? 'green' : 'blue'"
                  >
                    <template #dot>
                      <icon-check-circle v-if="log.type === 'success'" />
                      <icon-info-circle v-else />
                    </template>
                    <div>{{ log.message }}</div>
                    <div style="color: var(--color-text-3); font-size: 12px">{{
                      log.time
                    }}</div>
                  </a-timeline-item>
                </a-timeline>
              </a-card>
            </a-col>
          </a-row>
        </a-tab-pane>

        <!-- Tab 6: 表单联动 -->
        <a-tab-pane key="6" title="表单联动">
          <a-card title="动态表单" size="small">
            <a-form :model="formData" layout="vertical">
              <a-row :gutter="16">
                <a-col :span="8">
                  <a-form-item label="选择部门">
                    <a-select
                      v-model="formData.deptId"
                      @change="handleDeptChange"
                    >
                      <a-option :value="1">技术部</a-option>
                      <a-option :value="2">销售部</a-option>
                      <a-option :value="3">市场部</a-option>
                    </a-select>
                  </a-form-item>
                </a-col>
                <a-col :span="8">
                  <a-form-item label="选择用户">
                    <a-select
                      v-model="formData.userId"
                      :disabled="!formData.deptId"
                    >
                      <a-option
                        v-for="user in filteredUsers"
                        :key="user.id"
                        :value="user.id"
                        >{{ user.name }}</a-option
                      >
                    </a-select>
                  </a-form-item>
                </a-col>
                <a-col :span="8">
                  <a-form-item label="用户角色">
                    <a-input
                      v-model="selectedUserRole"
                      readonly
                      placeholder="选择用户后显示"
                    />
                  </a-form-item>
                </a-col>
              </a-row>
            </a-form>
          </a-card>
        </a-tab-pane>
      </a-tabs>
    </a-card>

    <!-- 编辑节点弹窗 -->
    <a-modal
      v-model:visible="editModalVisible"
      :title="editModalTitle"
      @ok="handleEditOk"
      @cancel="editModalVisible = false"
    >
      <a-form :model="editForm" layout="vertical">
        <a-form-item label="节点名称" required>
          <a-input v-model="editForm.title" placeholder="请输入节点名称" />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch
            v-model="editForm.status"
            checked-text="启用"
            unchecked-text="禁用"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  /* eslint-disable no-use-before-define, no-restricted-syntax */
  import { ref, computed, onMounted, onUnmounted } from 'vue';
  import { Message, Modal } from '@arco-design/web-vue';
  import AmisCrud from '@/components/amis-crud/index.vue';
  import {
    crudEventBus,
    CrudEvents,
    crudStateManager,
    crudInstanceManager,
  } from '@/utils/crud-event-bus';
  import type { CrudConfig } from '@/utils/amis-crud-generator';

  const userCrudRef = ref();
  const batchCrudRef = ref();
  const treeRef = ref();
  const currentDept = ref<any>(null);
  const userCount = ref(0);
  const operationCount = ref(0);
  const selectedCount = ref(0);
  const treeSearchValue = ref('');
  const treeLoading = ref(false);
  const recentLogs = ref<
    Array<{ message: string; time: string; type: string }>
  >([]);
  const formData = ref({ deptId: undefined, userId: undefined });
  const stats = ref({ totalUsers: 156, activeUsers: 89, todayNew: 12 });
  const editModalVisible = ref(false);
  const editModalTitle = ref('');
  const editForm = ref({ key: '', title: '', status: true, parentKey: '' });
  const editMode = ref<'add' | 'edit'>('edit');

  // 部门树数据
  const deptTreeData = ref([
    {
      key: '1',
      title: '总公司',
      status: 1,
      children: [
        {
          key: '2',
          title: '技术部',
          status: 1,
          children: [
            { key: '3', title: '前端组', status: 1 },
            { key: '4', title: '后端组', status: 1 },
            { key: '5', title: '测试组', status: 1 },
          ],
        },
        {
          key: '6',
          title: '销售部',
          status: 1,
          children: [
            { key: '7', title: '华东区', status: 1 },
            { key: '8', title: '华南区', status: 1 },
          ],
        },
        { key: '9', title: '市场部', status: 1 },
        { key: '10', title: '财务部', status: 1 },
      ],
    },
  ]);

  const users = [
    { id: 1, name: '张三', deptId: 1, role: '开发工程师' },
    { id: 2, name: '李四', deptId: 1, role: '测试工程师' },
    { id: 3, name: '王五', deptId: 2, role: '销售经理' },
    { id: 4, name: '赵六', deptId: 2, role: '销售专员' },
    { id: 5, name: '钱七', deptId: 3, role: '市场总监' },
  ];

  const filteredUsers = computed(() => {
    if (!formData.value.deptId) return [];
    return users.filter((u) => u.deptId === formData.value.deptId);
  });

  const selectedUserRole = computed(() => {
    if (!formData.value.userId) return '';
    const user = users.find((u) => u.id === formData.value.userId);
    return user?.role || '';
  });

  // 防抖搜索
  let searchTimer: any = null;
  const debouncedSearch = () => {
    clearTimeout(searchTimer);
    searchTimer = setTimeout(() => {
      handleTreeSearch();
    }, 300);
  };

  // 树搜索过滤
  const filteredTreeData = computed(() => {
    if (!treeSearchValue.value) return deptTreeData.value;

    const filterTree = (nodes: any[]): any[] => {
      return nodes.reduce((acc: any[], node) => {
        const matches = node.title.includes(treeSearchValue.value);
        const children = node.children ? filterTree(node.children) : [];

        if (matches || children.length > 0) {
          acc.push({ ...node, children });
        }
        return acc;
      }, []);
    };

    return filterTree(deptTreeData.value);
  });

  const addLog = (message: string, type = 'info') => {
    recentLogs.value.unshift({
      message,
      time: new Date().toLocaleTimeString(),
      type,
    });
    if (recentLogs.value.length > 10) {
      recentLogs.value.pop();
    }
    operationCount.value += 1;
  };

  // 处理部门选择
  const handleDeptSelect = (selectedKeys: string[], data: any) => {
    if (data.node) {
      currentDept.value = data.node;
      addLog(`选择部门: ${data.node.title}`);
      crudStateManager.update('user_crud', {
        filters: { dept_id: data.node.key },
      });
      crudInstanceManager.refresh('user_crud');
    }
  };

  // 拖拽排序
  const handleDrop = ({ dragNode, dropNode, dropPosition }: any) => {
    addLog(
      `拖拽: ${dragNode.title} → ${dropNode.title} (${dropPosition})`,
      'success'
    );
    Message.success('节点排序成功');
  };

  // 右键菜单
  const handleContextMenu = (action: string, nodeData: any) => {
    if (action === 'add') {
      editMode.value = 'add';
      editModalTitle.value = `添加子节点 - ${nodeData.title}`;
      editForm.value = {
        key: '',
        title: '',
        status: true,
        parentKey: nodeData.key,
      };
      editModalVisible.value = true;
    } else if (action === 'edit') {
      editMode.value = 'edit';
      editModalTitle.value = `编辑节点 - ${nodeData.title}`;
      editForm.value = {
        key: nodeData.key,
        title: nodeData.title,
        status: !!nodeData.status,
        parentKey: '',
      };
      editModalVisible.value = true;
    } else if (action === 'delete') {
      Modal.confirm({
        title: '确认删除',
        content: `确定要删除 "${nodeData.title}" 吗？`,
        onOk: () => {
          deleteNode(deptTreeData.value, nodeData.key);
          addLog(`删除节点: ${nodeData.title}`, 'success');
          Message.success('删除成功');
        },
      });
    }
  };

  // 删除节点
  const deleteNode = (nodes: any[], key: string): boolean => {
    for (let i = 0; i < nodes.length; i += 1) {
      if (nodes[i].key === key) {
        nodes.splice(i, 1);
        return true;
      }
      if (nodes[i].children && deleteNode(nodes[i].children, key)) {
        return true;
      }
    }
    return false;
  };

  // 添加/编辑节点确认
  const handleEditOk = () => {
    if (!editForm.value.title) {
      Message.warning('请输入节点名称');
      return;
    }

    if (editMode.value === 'add') {
      const newNode = {
        key: String(Date.now()),
        title: editForm.value.title,
        status: editForm.value.status ? 1 : 0,
      };
      addNodeToTree(deptTreeData.value, editForm.value.parentKey, newNode);
      addLog(`添加节点: ${editForm.value.title}`, 'success');
      Message.success('添加成功');
    } else {
      updateNode(
        deptTreeData.value,
        editForm.value.key,
        editForm.value.title,
        editForm.value.status ? 1 : 0
      );
      addLog(`编辑节点: ${editForm.value.title}`, 'success');
      Message.success('编辑成功');
    }

    editModalVisible.value = false;
  };

  // 添加节点到树
  const addNodeToTree = (nodes: any[], parentKey: string, newNode: any) => {
    for (const node of nodes) {
      if (node.key === parentKey) {
        if (!node.children) node.children = [];
        node.children.push(newNode);
        return;
      }
      if (node.children) {
        addNodeToTree(node.children, parentKey, newNode);
      }
    }
  };

  // 更新节点
  const updateNode = (
    nodes: any[],
    key: string,
    title: string,
    status: number
  ) => {
    for (const node of nodes) {
      if (node.key === key) {
        node.title = title;
        node.status = status;
        return;
      }
      if (node.children) {
        updateNode(node.children, key, title, status);
      }
    }
  };

  // 添加根节点
  const handleAddRoot = () => {
    editMode.value = 'add';
    editModalTitle.value = '添加根节点';
    editForm.value = { key: '', title: '', status: true, parentKey: '' };
    editModalVisible.value = true;
  };

  // 导出树数据
  const handleExportTree = () => {
    const dataStr = JSON.stringify(deptTreeData.value, null, 2);
    const blob = new Blob([dataStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `tree-data-${Date.now()}.json`;
    a.click();
    URL.revokeObjectURL(url);
    addLog('导出树数据', 'success');
    Message.success('导出成功');
  };

  // 树操作
  const expandAll = () => {
    treeRef.value?.expandAll();
    addLog('展开所有节点');
  };

  const collapseAll = () => {
    treeRef.value?.collapseAll();
    addLog('收起所有节点');
  };

  const handleTreeSearch = () => {
    if (treeSearchValue.value) {
      addLog(`搜索部门: ${treeSearchValue.value}`);
    }
  };

  // 用户配置
  const userConfig: CrudConfig = {
    title: '部门用户',
    api: '/api/member/list',
    fields: [
      { name: 'id', label: 'ID', type: 'number', width: 60 },
      { name: 'username', label: '用户名', type: 'text', editable: true },
      { name: 'mobile', label: '手机号', type: 'phone', editable: true },
      { name: 'status', label: '状态', type: 'switch', quickEdit: true },
    ],
    enableAdd: true,
    enableEdit: true,
    enableDelete: true,
    pageSize: 10,
    editMode: 'drawer',
    events: {
      onLoad: (data) => {
        userCount.value = data.total || 0;
        addLog(`加载用户: ${data.total || 0}条`);
      },
      onAddSuccess: () => {
        addLog('新增用户成功', 'success');
        stats.value.totalUsers += 1;
      },
    },
  };

  // 分类配置
  const categoryConfig: CrudConfig = {
    title: '分类管理',
    api: '/api/category/list',
    fields: [
      { name: 'name', label: '分类名称', type: 'text', required: true },
      { name: 'sort', label: '排序', type: 'number' },
    ],
    enableAdd: true,
    enableEdit: true,
    pageSize: 10,
    editMode: 'drawer',
    events: {
      onRowClick: (row) => {
        addLog(`选择分类: ${row.name}`);
        crudInstanceManager.refresh('product_crud');
      },
    },
  };

  // 商品配置
  const productConfig: CrudConfig = {
    title: '商品管理',
    api: '/api/product/list',
    fields: [
      { name: 'name', label: '商品名称', type: 'text' },
      { name: 'price', label: '价格', type: 'number' },
      { name: 'stock', label: '库存', type: 'number' },
    ],
    enableAdd: true,
    pageSize: 10,
    editMode: 'drawer',
  };

  // 统计配置
  const statsConfig: CrudConfig = {
    title: '用户统计',
    api: '/api/member/list',
    fields: [
      { name: 'username', label: '用户名', type: 'text' },
      { name: 'login_count', label: '登录次数', type: 'number' },
      { name: 'last_login', label: '最后登录', type: 'datetime' },
    ],
    pageSize: 10,
  };

  // 批量操作配置
  const batchConfig: CrudConfig = {
    title: '用户列表',
    api: '/api/member/list',
    fields: [
      { name: 'username', label: '用户名', type: 'text' },
      { name: 'mobile', label: '手机号', type: 'phone' },
      { name: 'status', label: '状态', type: 'switch' },
    ],
    enableBulk: true,
    pageSize: 10,
    events: {
      onSelectionChange: (rows) => {
        selectedCount.value = rows.length;
        addLog(`选择了 ${rows.length} 条数据`);
      },
    },
  };

  // 日志配置
  const logConfig: CrudConfig = {
    title: '操作日志',
    api: '/api/operation/log',
    fields: [
      { name: 'username', label: '操作人', type: 'text', width: 100 },
      { name: 'action', label: '操作', type: 'text', width: 120 },
      { name: 'module', label: '模块', type: 'text', width: 100 },
      { name: 'created_at', label: '时间', type: 'datetime', width: 160 },
    ],
    enableFilter: true,
    pageSize: 10,
  };

  const handleBatchEnable = () => {
    const rows = batchCrudRef.value?.getSelectedRows() || [];
    if (rows.length === 0) {
      Message.warning('请先选择数据');
      return;
    }
    addLog(`批量启用 ${rows.length} 条数据`, 'success');
    Message.success('批量启用成功');
  };

  const handleBatchDisable = () => {
    const rows = batchCrudRef.value?.getSelectedRows() || [];
    if (rows.length === 0) {
      Message.warning('请先选择数据');
      return;
    }
    addLog(`批量禁用 ${rows.length} 条数据`, 'success');
    Message.success('批量禁用成功');
  };

  const handleBatchDelete = () => {
    const rows = batchCrudRef.value?.getSelectedRows() || [];
    if (rows.length === 0) {
      Message.warning('请先选择数据');
      return;
    }
    addLog(`批量删除 ${rows.length} 条数据`, 'success');
    Message.success('批量删除成功');
    batchCrudRef.value?.clearSelection();
  };

  const handleDeptChange = () => {
    formData.value.userId = undefined;
    addLog(`切换部门: ${formData.value.deptId}`);
  };

  const handleDataUpdated = ({ id }: any) => {
    addLog(`数据更新: ${id}`);
  };

  onMounted(() => {
    addLog('页面加载完成');
    crudEventBus.on(CrudEvents.DATA_UPDATED, handleDataUpdated);
  });

  onUnmounted(() => {
    crudEventBus.off(CrudEvents.DATA_UPDATED, handleDataUpdated);
    if (searchTimer) clearTimeout(searchTimer);
  });
</script>

<style scoped lang="less">
  .interaction-demo-fullscreen {
    padding: 0;
    height: 100%;

    :deep(.arco-card) {
      height: 100%;
    }

    :deep(.arco-card-body) {
      padding: 16px;
      height: calc(100% - 57px);
      overflow: auto;
    }

    :deep(.arco-tabs) {
      height: 100%;
    }

    :deep(.arco-tabs-content) {
      height: calc(100% - 44px);
      overflow: auto;
    }

    :deep(.arco-tree-node-title) {
      cursor: pointer;
    }
  }
</style>
