<template>
  <div class="content-box">
    <a-card>
      <a-tabs default-active-key="dept" @change="handleTabChange">
        <!-- 部门管理 -->
        <a-tab-pane key="dept" title="部门管理">
          <div class="section-toolbar">
            <a-space size="small">
              <a-input-search
                v-model="deptSearchKey"
                placeholder="搜索部门名称"
                size="small"
                style="width: 300px"
                @search="fetchDeptList"
              />
            </a-space>
            <a-button type="primary" size="small" @click="handleAddDept">
              <template #icon><icon-plus /></template>
              添加部门
            </a-button>
          </div>

          <a-table
            :data="deptList"
            :columns="deptColumns"
            :pagination="deptPagination"
            :loading="deptLoading"
            size="small"
            @page-change="handleDeptPageChange"
          >
            <template #status="{ record }">
              <a-switch
                :model-value="record.status === 1"
                size="small"
                @change="handleDeptStatusChange(record)"
              />
            </template>
            <template #action="{ record }">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="handleEditDept(record)"
                >
                  编辑
                </a-button>
                <a-popconfirm
                  content="确定删除该部门吗？"
                  @ok="handleDeleteDept(record)"
                >
                  <a-button type="text" size="small" status="danger">
                    删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table>
        </a-tab-pane>

        <!-- 职位管理 -->
        <a-tab-pane key="position" title="职位管理">
          <div class="section-toolbar">
            <a-space size="small">
              <a-input-search
                v-model="positionSearchKey"
                placeholder="搜索职位名称"
                size="small"
                style="width: 300px"
                @search="fetchPositionList"
              />
            </a-space>
            <a-button type="primary" size="small" @click="handleAddPosition">
              <template #icon><icon-plus /></template>
              添加职位
            </a-button>
          </div>

          <a-table
            :data="positionList"
            :columns="positionColumns"
            :pagination="positionPagination"
            :loading="positionLoading"
            size="small"
            @page-change="handlePositionPageChange"
          >
            <template #dept="{ record }">
              <a-tag color="arcoblue">{{ getDeptName(record.dept_id) }}</a-tag>
            </template>
            <template #status="{ record }">
              <a-switch
                :model-value="record.status === 1"
                size="small"
                @change="handlePositionStatusChange(record)"
              />
            </template>
            <template #action="{ record }">
              <a-space>
                <a-button
                  type="text"
                  size="small"
                  @click="handleEditPosition(record)"
                >
                  编辑
                </a-button>
                <a-popconfirm
                  content="确定删除该职位吗？"
                  @ok="handleDeletePosition(record)"
                >
                  <a-button type="text" size="small" status="danger">
                    删除
                  </a-button>
                </a-popconfirm>
              </a-space>
            </template>
          </a-table>
        </a-tab-pane>
      </a-tabs>
    </a-card>

    <!-- 部门编辑弹窗 -->
    <a-modal
      v-model:visible="deptModalVisible"
      :title="deptModalTitle"
      width="600px"
      @before-ok="handleDeptSave"
    >
      <a-form ref="deptFormRef" :model="deptForm" :rules="deptRules">
        <a-form-item label="上级部门" field="parent_id">
          <a-tree-select
            v-model="deptForm.parent_id"
            :data="deptTreeData"
            placeholder="请选择上级部门（不选则为顶级部门）"
            allow-clear
          />
        </a-form-item>
        <a-form-item label="部门名称" field="dept_name">
          <a-input v-model="deptForm.dept_name" placeholder="请输入部门名称" />
        </a-form-item>
        <a-form-item label="部门编码" field="dept_code">
          <a-input v-model="deptForm.dept_code" placeholder="请输入部门编码" />
        </a-form-item>
        <a-form-item label="负责人">
          <a-input v-model="deptForm.leader" placeholder="请输入负责人" />
        </a-form-item>
        <a-form-item label="联系电话">
          <a-input v-model="deptForm.phone" placeholder="请输入联系电话" />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model="deptForm.sort" :min="0" />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch v-model="deptForm.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 职位编辑弹窗 -->
    <a-modal
      v-model:visible="positionModalVisible"
      :title="positionModalTitle"
      width="600px"
      @before-ok="handlePositionSave"
    >
      <a-form
        ref="positionFormRef"
        :model="positionForm"
        :rules="positionRules"
      >
        <a-form-item label="所属部门" field="dept_id">
          <a-tree-select
            v-model="positionForm.dept_id"
            :data="deptTreeData"
            placeholder="请选择所属部门"
          />
        </a-form-item>
        <a-form-item label="职位名称" field="position_name">
          <a-input
            v-model="positionForm.position_name"
            placeholder="请输入职位名称"
          />
        </a-form-item>
        <a-form-item label="职位编码" field="position_code">
          <a-input
            v-model="positionForm.position_code"
            placeholder="请输入职位编码"
          />
        </a-form-item>
        <a-form-item label="职位描述">
          <a-textarea
            v-model="positionForm.description"
            placeholder="请输入职位描述"
          />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model="positionForm.sort" :min="0" />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch v-model="positionForm.status" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request from '@/api/request';

  const activeTab = ref('dept');

  // 部门管理
  const deptLoading = ref(false);
  const deptSearchKey = ref('');
  const deptList = ref<any[]>([]);
  const deptTreeData = ref<any[]>([]);
  const deptPagination = reactive({
    current: 1,
    pageSize: 10,
    total: 0,
  });

  const deptColumns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '部门名称', dataIndex: 'dept_name', width: 200 },
    { title: '部门编码', dataIndex: 'dept_code', width: 150 },
    { title: '负责人', dataIndex: 'leader', width: 100 },
    { title: '联系电话', dataIndex: 'phone', width: 120 },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
    { title: '操作', dataIndex: 'action', slotName: 'action', width: 150 },
  ];

  const deptModalVisible = ref(false);
  const deptFormRef = ref();
  const deptForm = reactive({
    id: 0,
    parent_id: null,
    dept_name: '',
    dept_code: '',
    leader: '',
    phone: '',
    sort: 0,
    status: true,
  });
  const deptRules = {
    dept_name: [{ required: true, message: '请输入部门名称' }],
    dept_code: [{ required: true, message: '请输入部门编码' }],
  };
  const deptModalTitle = computed(() =>
    deptForm.id ? '编辑部门' : '添加部门'
  );

  const getDeptName = (deptId: number | null | undefined) => {
    if (!deptId) return '-';
    const hit = deptList.value.find((item) => Number(item.id) === Number(deptId));
    return hit?.dept_name || '-';
  };

  // 职位管理
  const positionLoading = ref(false);
  const positionSearchKey = ref('');
  const positionList = ref<any[]>([]);
  const positionPagination = reactive({
    current: 1,
    pageSize: 10,
    total: 0,
  });

  const positionColumns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '所属部门', dataIndex: 'dept', slotName: 'dept', width: 150 },
    { title: '职位名称', dataIndex: 'position_name', width: 150 },
    { title: '职位编码', dataIndex: 'position_code', width: 150 },
    { title: '职位描述', dataIndex: 'description', ellipsis: true },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
    { title: '操作', dataIndex: 'action', slotName: 'action', width: 150 },
  ];

  const positionModalVisible = ref(false);
  const positionFormRef = ref();
  const positionForm = reactive({
    id: 0,
    dept_id: null,
    position_name: '',
    position_code: '',
    description: '',
    sort: 0,
    status: true,
  });
  const positionRules = {
    dept_id: [{ required: true, message: '请选择所属部门' }],
    position_name: [{ required: true, message: '请输入职位名称' }],
    position_code: [{ required: true, message: '请输入职位编码' }],
  };
  const positionModalTitle = computed(() =>
    positionForm.id ? '编辑职位' : '添加职位'
  );

  // Tab 切换
  const handleTabChange = (key: string) => {
    activeTab.value = key;
    if (key === 'dept') {
      fetchDeptList();
    } else {
      fetchPositionList();
    }
  };

  // 部门相关方法
  const fetchDeptList = () => {
    deptLoading.value = true;
    request('/api/system/dept/list', {
      page: deptPagination.current,
      page_size: deptPagination.pageSize,
      keyword: deptSearchKey.value,
    })
      .then((res: any) => {
        deptList.value = res.data?.list || [];
        deptPagination.total = res.data?.total || 0;
      })
      .finally(() => {
        deptLoading.value = false;
      });
  };

  /** 构建树形结构 */
  const buildTree = (list: any[]): any[] => {
    if (!Array.isArray(list)) return [];
    const map = new Map<number, any>();
    list.forEach((item) => {
      const id = Number(item.id);
      map.set(id, {
        ...item,
        key: id,
        value: id,
        title: item.dept_name || item.title || '',
        children: [],
      });
    });
    const roots: any[] = [];
    list.forEach((item) => {
      const id = Number(item.id);
      const parentId = Number(item.parent_id || 0);
      const node = map.get(id);
      if (!node) return;
      if (parentId > 0 && map.has(parentId)) {
        map.get(parentId)!.children.push(node);
      } else {
        roots.push(node);
      }
    });
    return roots;
  };

  const fetchDeptTree = () => {
    request('/api/system/dept/tree', {}).then((res: any) => {
      const raw = res?.data;
      const list = Array.isArray(raw)
        ? raw
        : Array.isArray(raw?.list)
          ? raw.list
          : Array.isArray(raw?.items)
            ? raw.items
            : [];
      deptTreeData.value = buildTree(list);
    });
  };

  const handleAddDept = () => {
    Object.assign(deptForm, {
      id: 0,
      parent_id: null,
      dept_name: '',
      dept_code: '',
      leader: '',
      phone: '',
      sort: 0,
      status: true,
    });
    deptModalVisible.value = true;
  };

  const handleEditDept = (record: any) => {
    Object.assign(deptForm, {
      ...record,
      status: record.status === 1,
    });
    deptModalVisible.value = true;
  };

  const handleDeptSave = async () => {
    const valid = await deptFormRef.value?.validate();
    if (valid) return false;

    await request('/api/system/dept/save', {
      ...deptForm,
      status: deptForm.status ? 1 : 0,
    });
    Message.success(deptForm.id ? '编辑成功' : '添加成功');
    fetchDeptList();
    fetchDeptTree();
    return true;
  };

  const handleDeleteDept = async (record: any) => {
    await request('/api/system/dept/remove', { id: record.id });
    Message.success('删除成功');
    fetchDeptList();
    fetchDeptTree();
  };

  const handleDeptStatusChange = (record: any) => {
    request('/api/system/dept/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    }).then(() => {
      Message.success('状态更新成功');
      fetchDeptList();
    });
  };

  const handleDeptPageChange = (page: number) => {
    deptPagination.current = page;
    fetchDeptList();
  };

  // 职位相关方法
  const fetchPositionList = () => {
    positionLoading.value = true;
    request('/api/system/position/list', {
      page: positionPagination.current,
      page_size: positionPagination.pageSize,
      keyword: positionSearchKey.value,
    })
      .then((res: any) => {
        positionList.value = res.data?.list || [];
        positionPagination.total = res.data?.total || 0;
      })
      .finally(() => {
        positionLoading.value = false;
      });
  };

  const handleAddPosition = () => {
    Object.assign(positionForm, {
      id: 0,
      dept_id: null,
      position_name: '',
      position_code: '',
      description: '',
      sort: 0,
      status: true,
    });
    positionModalVisible.value = true;
  };

  const handleEditPosition = (record: any) => {
    Object.assign(positionForm, {
      ...record,
      status: record.status === 1,
    });
    positionModalVisible.value = true;
  };

  const handlePositionSave = async () => {
    const valid = await positionFormRef.value?.validate();
    if (valid) return false;

    await request('/api/system/position/save', {
      ...positionForm,
      status: positionForm.status ? 1 : 0,
    });
    Message.success(positionForm.id ? '编辑成功' : '添加成功');
    fetchPositionList();
    return true;
  };

  const handleDeletePosition = async (record: any) => {
    await request('/api/system/position/delete', { id: record.id });
    Message.success('删除成功');
    fetchPositionList();
  };

  const handlePositionStatusChange = (record: any) => {
    request('/api/system/position/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    }).then(() => {
      Message.success('状态更新成功');
      fetchPositionList();
    });
  };

  const handlePositionPageChange = (page: number) => {
    positionPagination.current = page;
    fetchPositionList();
  };

  onMounted(() => {
    fetchDeptList();
    fetchDeptTree();
  });
</script>

<style lang="less" scoped>
  .content-box {
    padding: 0;
  }

  .section-toolbar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 16px;
  }
</style>
