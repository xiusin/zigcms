<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>页面配置</span>
          <a-tag color="blue">{{ tableData.length }} 个页面</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="handleAdd">
            <template #icon><icon-plus /></template>
            新建页面
          </a-button>
          <a-button size="small" @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </template>

      <SearchForm
        v-model:form-state="searchState"
        :form-items="searchItems"
        @search="handleSearch"
        @reset="handleReset"
      />

      <a-table
        :columns="columns"
        :data="tableData"
        :loading="loading"
        :pagination="pagination"
        row-key="id"
        size="small"
        @page-change="handlePageChange"
        @page-size-change="handlePageSizeChange"
      >
        <template #status="{ record }">
          <a-tag :color="record.status === 1 ? 'green' : 'red'">
            {{ record.status === 1 ? '启用' : '禁用' }}
          </a-tag>
        </template>

        <template #operations="{ record }">
          <a-space>
            <a-button type="text" size="mini" @click="handleEdit(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-button type="text" size="mini" @click="handlePreview(record)">
              <template #icon><icon-eye /></template>
              预览
            </a-button>
            <a-button type="text" size="mini" @click="handleCopy(record)">
              <template #icon><icon-copy /></template>
              复制
            </a-button>
            <a-button
              type="text"
              size="mini"
              :status="record.status === 1 ? 'warning' : 'success'"
              @click="handleToggleStatus(record)"
            >
              {{ record.status === 1 ? '禁用' : '启用' }}
            </a-button>
            <a-popconfirm title="确定删除此页面吗?" @ok="handleDelete(record)">
              <a-button type="text" status="danger" size="mini">
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </a-table>
    </a-card>

    <!-- 编辑弹窗 -->
    <a-modal
      v-model:visible="editVisible"
      :title="editType === 'add' ? '新建页面' : '编辑页面'"
      :width="900"
      @ok="handleSave"
      @cancel="handleCancel"
    >
      <a-form ref="formRef" :model="formState" :rules="rules" layout="vertical">
        <a-form-item label="页面名称" field="page_name">
          <a-input v-model="formState.page_name" placeholder="请输入页面名称" />
        </a-form-item>

        <a-form-item label="页面编码" field="page_code">
          <a-input
            v-model="formState.page_code"
            placeholder="请输入页面编码"
            :disabled="editType === 'edit'"
          />
        </a-form-item>

        <a-form-item label="页面描述" field="description">
          <a-textarea
            v-model="formState.description"
            placeholder="请输入页面描述"
            :rows="2"
          />
        </a-form-item>

        <a-form-item label="页面分类" field="category_id">
          <a-select
            v-model="formState.category_id"
            placeholder="请选择页面分类"
          >
            <a-option :value="1">系统页面</a-option>
            <a-option :value="2">业务页面</a-option>
            <a-option :value="3">自定义页面</a-option>
          </a-select>
        </a-form-item>

        <a-form-item label="JSON 配置" field="schema_json">
          <div class="schema-editor-wrapper">
            <AmisEditor v-model="formState.schema_json" />
          </div>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 预览弹窗 -->
    <a-modal
      v-model:visible="previewVisible"
      title="页面预览"
      :width="1000"
      :footer="false"
    >
      <div class="preview-container">
        <AmisRenderer :schema="previewSchema" />
      </div>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import { AmisRenderer, AmisEditor, SchemaTemplates } from '@/components/amis';
  import type { AmisSchema } from '@/types/amis.d';

  // 表格列定义
  const columns = [
    { title: 'ID', dataIndex: 'id', width: 80 },
    { title: '页面名称', dataIndex: 'page_name', width: 150 },
    { title: '页面编码', dataIndex: 'page_code', width: 150 },
    { title: '页面描述', dataIndex: 'description', ellipsis: true },
    { title: '分类', dataIndex: 'category_name', width: 100 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '更新时间', dataIndex: 'updated_at', width: 180 },
    {
      title: '操作',
      dataIndex: 'operations',
      width: 250,
      slotName: 'operations',
      fixed: 'right',
    },
  ];

  // 搜索表单配置
  const searchItems = [
    { field: 'page_name', label: '页面名称', component: 'input' },
    { field: 'page_code', label: '页面编码', component: 'input' },
    {
      field: 'status',
      label: '状态',
      component: 'select',
      options: [
        { label: '启用', value: 1 },
        { label: '禁用', value: 0 },
      ],
    },
  ];

  // 状态
  const loading = ref(false);
  const tableData = ref<any[]>([]);
  const searchState = reactive({
    page_name: '',
    page_code: '',
    status: '',
  });

  const pagination = reactive({
    current: 1,
    pageSize: 10,
    total: 0,
  });

  // 编辑弹窗
  const editVisible = ref(false);
  const editType = ref<'add' | 'edit'>('add');
  const formRef = ref();
  const formState = reactive({
    id: 0,
    page_name: '',
    page_code: '',
    description: '',
    category_id: 1,
    schema_json: { ...SchemaTemplates.blankPage } as AmisSchema,
  });

  const rules = {
    page_name: [{ required: true, message: '请输入页面名称' }],
    page_code: [{ required: true, message: '请输入页面编码' }],
  };

  // 预览
  const previewVisible = ref(false);
  const previewSchema = ref<AmisSchema>({});

  // 加载数据
  const loadData = async () => {
    loading.value = true;
    try {
      // 复杂的测试 JSON schema
      const complexSchema = {
        type: 'page',
        title: '用户管理页面',
        subTitle: '用户列表与操作',
        toolbar: [
          {
            type: 'button',
            label: '新增用户',
            icon: 'plus',
            actionType: 'dialog',
            dialog: {
              title: '新增用户',
              body: {
                type: 'form',
                mode: 'horizontal',
                body: [
                  {
                    type: 'input-text',
                    name: 'username',
                    label: '用户名',
                    required: true,
                  },
                  {
                    type: 'input-email',
                    name: 'email',
                    label: '邮箱',
                    required: true,
                  },
                  {
                    type: 'input-number',
                    name: 'age',
                    label: '年龄',
                    min: 18,
                    max: 100,
                  },
                  {
                    type: 'select',
                    name: 'role',
                    label: '角色',
                    options: [
                      { label: '管理员', value: 'admin' },
                      { label: '普通用户', value: 'user' },
                      { label: '访客', value: 'guest' },
                    ],
                  },
                  {
                    type: 'switch',
                    name: 'status',
                    label: '启用状态',
                  },
                ],
              },
            },
          },
        ],
        body: {
          type: 'crud',
          api: '/api/users',
          columns: [
            {
              name: 'id',
              label: 'ID',
              width: 60,
              sortable: true,
            },
            {
              name: 'avatar',
              label: '头像',
              width: 80,
              type: 'avatar',
            },
            {
              name: 'username',
              label: '用户名',
              searchable: true,
              sortable: true,
            },
            {
              name: 'email',
              label: '邮箱',
              width: 200,
            },
            {
              name: 'age',
              label: '年龄',
              width: 80,
              sortable: true,
            },
            {
              name: 'role',
              label: '角色',
              width: 100,
              type: 'mapping',
              map: {
                admin: '<span class="label label-success">管理员</span>',
                user: '<span class="label label-info">普通用户</span>',
                guest: '<span class="label label-default">访客</span>',
              },
            },
            {
              name: 'status',
              label: '状态',
              width: 80,
              type: 'switch',
              trueText: '启用',
              falseText: '禁用',
            },
            {
              name: 'created_at',
              label: '创建时间',
              width: 180,
              sortable: true,
            },
            {
              name: 'operate',
              label: '操作',
              width: 150,
              type: 'operate',
              buttons: [
                {
                  type: 'button',
                  label: '编辑',
                  icon: 'edit',
                  actionType: 'dialog',
                  dialog: {
                    title: '编辑用户',
                    body: {
                      type: 'form',
                      mode: 'horizontal',
                      body: [
                        {
                          type: 'input-text',
                          name: 'username',
                          label: '用户名',
                        },
                        {
                          type: 'input-email',
                          name: 'email',
                          label: '邮箱',
                        },
                      ],
                    },
                  },
                },
                {
                  type: 'button',
                  label: '删除',
                  icon: 'delete',
                  actionType: 'ajax',
                  confirmText: '确认删除此用户?',
                  api: 'delete:/api/users/$id',
                },
              ],
            },
          ],
          filters: [
            {
              type: 'input-text',
              name: 'username',
              label: '用户名',
              placeholder: '请输入用户名',
            },
            {
              type: 'select',
              name: 'role',
              label: '角色',
              options: [
                { label: '全部', value: '' },
                { label: '管理员', value: 'admin' },
                { label: '普通用户', value: 'user' },
                { label: '访客', value: 'guest' },
              ],
            },
            {
              type: 'switch',
              name: 'status',
              label: '仅显示启用',
            },
          ],
          bulkActions: [
            {
              type: 'button',
              label: '批量删除',
              icon: 'delete',
              actionType: 'ajax',
              confirmText: '确认删除选中的用户?',
              api: 'post:/api/users/bulk-delete',
            },
            {
              type: 'button',
              label: '批量启用',
              actionType: 'ajax',
              api: 'post:/api/users/bulk-enable',
            },
          ],
          loadDataOnce: true,
          syncLocation: false,
        },
        footer: [
          {
            type: 'tpl',
            tpl: `共 \${total} 条记录`,
          },
        ],
      };

      // 模拟数据
      tableData.value = [
        {
          id: 1,
          page_name: '用户列表',
          page_code: 'user_list',
          description: '用户管理列表页面',
          category_id: 1,
          category_name: '系统页面',
          status: 1,
          updated_at: '2024-01-15 10:30:00',
          schema_json: complexSchema,
        },
        {
          id: 2,
          page_name: '订单管理',
          page_code: 'order_manage',
          description: '订单列表页面',
          category_id: 2,
          category_name: '业务页面',
          status: 1,
          updated_at: '2024-01-14 15:20:00',
          schema_json: {
            type: 'page',
            title: '订单管理',
            body: {
              type: 'table',
              columns: [
                { label: '订单号', name: 'order_no' },
                { label: '商品名称', name: 'product_name' },
                { label: '价格', name: 'price' },
                { label: '状态', name: 'status' },
              ],
            },
          },
        },
        {
          id: 3,
          page_name: '数据统计',
          page_code: 'data_statistics',
          description: '数据统计看板',
          category_id: 3,
          category_name: '自定义页面',
          status: 0,
          updated_at: '2024-01-13 09:00:00',
          schema_json: {
            type: 'page',
            title: '数据统计',
            body: {
              type: 'grid',
              columns: [
                {
                  type: 'card',
                  header: '总用户数',
                  body: '10,000',
                },
                {
                  type: 'card',
                  header: '活跃用户',
                  body: '5,000',
                },
                {
                  type: 'card',
                  header: '新增用户',
                  body: '200',
                },
              ],
            },
          },
        },
      ];
      pagination.total = 3;
    } finally {
      loading.value = false;
    }
  };

  // 搜索
  const handleSearch = () => {
    pagination.current = 1;
    loadData();
  };

  const handleReset = () => {
    searchState.page_name = '';
    searchState.page_code = '';
    searchState.status = '';
    handleSearch();
  };

  const handleRefresh = () => {
    loadData();
  };

  // 分页
  const handlePageChange = (page: number) => {
    pagination.current = page;
    loadData();
  };

  const handlePageSizeChange = (pageSize: number) => {
    pagination.pageSize = pageSize;
    loadData();
  };

  // 操作
  const handleAdd = () => {
    editType.value = 'add';
    formState.id = 0;
    formState.page_name = '';
    formState.page_code = '';
    formState.description = '';
    formState.category_id = 1;
    formState.schema_json = { ...SchemaTemplates.blankPage };
    editVisible.value = true;
  };

  const handleEdit = (record: any) => {
    editType.value = 'edit';
    Object.assign(formState, record);
    editVisible.value = true;
  };

  const handlePreview = (record: any) => {
    previewSchema.value = record.schema_json || record.schema;
    previewVisible.value = true;
  };

  const handleCopy = (record: any) => {
    editType.value = 'add';
    formState.page_name = `${record.page_name}(副本)`;
    formState.page_code = `${record.page_code}_copy`;
    formState.description = record.description;
    formState.category_id = record.category_id;
    formState.schema_json = JSON.parse(
      JSON.stringify(record.schema_json || record.schema)
    );
    editVisible.value = true;
    Message.success('已复制，请修改页面编码');
  };

  const handleToggleStatus = async (record: any) => {
    const newStatus = record.status === 1 ? 0 : 1;
    Message.success(newStatus === 1 ? '已启用' : '已禁用');
    loadData();
  };

  const handleDelete = async (record: any) => {
    Message.success('删除成功');
    loadData();
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (!valid) return;

    Message.success(editType.value === 'add' ? '创建成功' : '保存成功');
    editVisible.value = false;
    loadData();
  };

  const handleCancel = () => {
    editVisible.value = false;
  };

  onMounted(() => {
    loadData();
  });
</script>

<style scoped lang="less">
  .content-box {
    padding: 20px;
  }

  .schema-editor-wrapper {
    border: 1px solid var(--color-border);
    border-radius: 4px;
    min-height: 400px;
  }

  .preview-container {
    min-height: 500px;
  }
</style>
