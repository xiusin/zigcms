<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>角色管理</span>
          <a-tag color="blue">{{ tableTotal }} 个角色</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="editRole({})">
            <template #icon>
              <icon-plus />
            </template>
            新增
          </a-button>
          <a-button size="small" @click="handleRefresh">
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
        placeholder="请输入供应商名称"
        @hand-submit="handleSubmit"
      ></SearchForm>

      <BaseTable
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #business_user_name="{ record }">
          <div>
            {{ record.business_user_name || '-' }}
          </div>
        </template>
        <template #pages="{ record }">
          <div>
            {{ record.pages ? record.pages.join('，') : '-' }}
          </div>
        </template>

        <template #action="{ record }">
          <!-- :disabled="!user.hasPermission([3, 31, 100])" -->
          <a-link @click="editRole(record)">
            <IconEdit />
            编辑
          </a-link>
          <a-divider direction="vertical" />
          <a-popconfirm
            :content="`确定要删除这条数据吗?`"
            position="left"
            @ok="deleteItem(record)"
          >
            <a-link> <icon-delete />删除 </a-link>
          </a-popconfirm>
        </template>
      </BaseTable>
    </a-card>
    <!--编辑角色权限-->
    <edit-role-permission
      ref="editRef"
      @refresh="handleSubmit"
    ></edit-role-permission>
  </div>
</template>

<script lang="ts" setup>
  import { useUserStore } from '@/store';
  import { onBeforeMount, ref, computed } from 'vue';
  import request from '@/api/request';
  import EditRolePermission from '@/views/system/role-manage/EditRolePermission.vue';

  const user = useUserStore();

  const tableRef = ref();

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };

  const columns: any = [
    {
      title: '角色',
      dataIndex: 'role_name',
      align: 'left',
    },
    {
      title: '备注',
      dataIndex: 'remark',
      align: 'left',
      slotName: 'remark',
    },
    {
      title: '授权功能',
      dataIndex: 'pages',
      align: 'left',
      slotName: 'pages',
      maxWidth: 400,
    },
    {
      title: '操作',
      dataIndex: 'action',
      width: 200,
      align: 'center',
      slotName: 'action',
      fixed: 'right',
    },
  ];
  const loading = ref(false);
  const editRef = ref();

  const generateFormModel = () => {
    return {
      // 基础查询条件
      name: '',
      user_id: '',
      is_open_saas: '',
      is_open_saas_d: '',
      user_name: '',
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'name',
      label: '供应商名称',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    {
      field: 'user_name',
      label: '账户',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/role/list', data);
  };
  function editRole(item: any) {
    editRef.value?.show(item);
  }

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const deleteItem = async (record: any) => {
    record.loading = true;
    request('/api/role/delete', {
      id: record.id,
    })
      .then(() => {
        handleSubmit();
      })
      .finally(() => {
        record.loading = false;
      });
  };
</script>

<style lang="less" scoped></style>
