<template>
  <div class="content-box">
    <a-card>
      <div class="section-toolbar">
        <a-space size="small">
          <a-select
            v-model="filterDeptId"
            placeholder="筛选部门"
            size="small"
            style="width: 200px"
            allow-clear
            @change="fetchList"
          >
            <a-option
              v-for="dept in deptList"
              :key="dept.id"
              :value="dept.id"
              :label="dept.dept_name"
            />
          </a-select>
          <a-input-search
            v-model="searchKey"
            placeholder="搜索职位名称"
            size="small"
            style="width: 300px"
            @search="fetchList"
          />
        </a-space>
        <a-button type="primary" size="small" @click="handleAdd">
          <template #icon><icon-plus /></template>
          添加职位
        </a-button>
      </div>

      <a-table
        :data="tableData"
        :columns="columns"
        :pagination="pagination"
        :loading="loading"
        size="small"
        @page-change="handlePageChange"
      >
        <template #dept="{ record }">
          <a-tag color="arcoblue">{{ record.dept_name }}</a-tag>
        </template>
        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            size="small"
            @change="handleStatusChange(record)"
          />
        </template>
        <template #action="{ record }">
          <a-space>
            <a-button type="text" size="small" @click="handleEdit(record)">
              编辑
            </a-button>
            <a-popconfirm
              content="确定删除该职位吗？"
              @ok="handleDelete(record)"
            >
              <a-button type="text" size="small" status="danger">
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="modalTitle"
      width="600px"
      @before-ok="handleSave"
    >
      <a-form ref="formRef" :model="form" :rules="rules">
        <a-form-item label="所属部门" field="dept_id">
          <a-tree-select
            v-model="form.dept_id"
            :data="deptTreeData"
            placeholder="请选择所属部门"
          />
        </a-form-item>
        <a-form-item label="职位名称" field="position_name">
          <a-input v-model="form.position_name" placeholder="请输入职位名称" />
        </a-form-item>
        <a-form-item label="职位编码" field="position_code">
          <a-input v-model="form.position_code" placeholder="请输入职位编码" />
        </a-form-item>
        <a-form-item label="职位描述">
          <a-textarea
            v-model="form.description"
            placeholder="请输入职位描述"
            :max-length="200"
            show-word-limit
          />
        </a-form-item>
        <a-form-item label="排序">
          <a-input-number v-model="form.sort" :min="0" style="width: 100%" />
        </a-form-item>
        <a-form-item label="状态">
          <a-switch v-model="form.status" />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request from '@/api/request';

  const loading = ref(false);
  const searchKey = ref('');
  const filterDeptId = ref();
  const tableData = ref<any[]>([]);
  const deptList = ref<any[]>([]);
  const deptTreeData = ref<any[]>([]);
  const pagination = reactive({
    current: 1,
    pageSize: 10,
    total: 0,
  });

  const columns = [
    { title: 'ID', dataIndex: 'id', width: 60 },
    { title: '所属部门', dataIndex: 'dept', slotName: 'dept', width: 150 },
    { title: '职位名称', dataIndex: 'position_name', width: 150 },
    { title: '职位编码', dataIndex: 'position_code', width: 150 },
    { title: '职位描述', dataIndex: 'description', ellipsis: true },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', slotName: 'status', width: 80 },
    { title: '操作', dataIndex: 'action', slotName: 'action', width: 150 },
  ];

  const modalVisible = ref(false);
  const formRef = ref();
  const form = reactive({
    id: 0,
    dept_id: null,
    position_name: '',
    position_code: '',
    description: '',
    sort: 0,
    status: true,
  });
  const rules = {
    dept_id: [{ required: true, message: '请选择所属部门' }],
    position_name: [{ required: true, message: '请输入职位名称' }],
    position_code: [{ required: true, message: '请输入职位编码' }],
  };
  const modalTitle = computed(() => (form.id ? '编辑职位' : '添加职位'));

  const fetchList = () => {
    loading.value = true;
    request('/api/system/position/list', {
      page: pagination.current,
      page_size: pagination.pageSize,
      keyword: searchKey.value,
      dept_id: filterDeptId.value,
    })
      .then((res: any) => {
        tableData.value = res.data?.list || [];
        pagination.total = res.data?.total || 0;
      })
      .finally(() => {
        loading.value = false;
      });
  };

  const fetchDeptList = () => {
    request('/api/system/dept/all', {}).then((res: any) => {
      deptList.value = res.data || [];
    });
  };

  const fetchDeptTree = () => {
    request('/api/system/dept/tree', {}).then((res: any) => {
      deptTreeData.value = res.data || [];
    });
  };

  const handleAdd = () => {
    Object.assign(form, {
      id: 0,
      dept_id: filterDeptId.value || null,
      position_name: '',
      position_code: '',
      description: '',
      sort: 0,
      status: true,
    });
    modalVisible.value = true;
  };

  const handleEdit = (record: any) => {
    Object.assign(form, {
      ...record,
      status: record.status === 1,
    });
    modalVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return false;

    await request('/api/system/position/save', {
      ...form,
      status: form.status ? 1 : 0,
    });
    Message.success(form.id ? '编辑成功' : '添加成功');
    fetchList();
    return true;
  };

  const handleDelete = async (record: any) => {
    await request('/api/system/position/delete', { id: record.id });
    Message.success('删除成功');
    fetchList();
  };

  const handleStatusChange = (record: any) => {
    request('/api/system/position/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    }).then(() => {
      Message.success('状态更新成功');
      fetchList();
    });
  };

  const handlePageChange = (page: number) => {
    pagination.current = page;
    fetchList();
  };

  onMounted(() => {
    fetchList();
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
