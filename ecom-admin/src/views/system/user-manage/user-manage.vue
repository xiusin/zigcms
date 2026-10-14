<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>成员管理</span>
          <a-tag color="blue">{{ tableData?.length || 0 }} 个成员</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="saveAction({})">
            <template #icon><icon-plus /></template>
            新增成员
          </a-button>
          <a-button size="small" @click="handleRefresh">
            <template #icon><icon-refresh /></template>
            刷新
          </a-button>
        </a-space>
      </template>

      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入成员名称"
        @hand-submit="handleSubmit"
      />

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
        size="small"
      >
        <template #status="{ record }">
          <a-switch
            :model-value="record.status > 0"
            :loading="record.loading"
            size="small"
            @click="changeUserStatus(record)"
          />
        </template>
        <template #action="{ record }">
          <a-space>
            <a-button type="text" size="mini" @click="saveAction(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-popconfirm
              content="确定要删除这条数据吗?"
              position="left"
              @ok="deleteUser(record)"
            >
              <a-button type="text" size="mini" status="danger">
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </a-space>
        </template>
      </base-table>
    </a-card>
    <save-user ref="saveRef" @create-over="handleSubmit()" />
    <reset-password ref="pswRef" />
  </div>
</template>

<script setup lang="ts">
  import { reactive, ref, computed } from 'vue';
  import request, { HttpResponse } from '@/api/request';
  import { useUserStore } from '@/store';
  import { Modal, Message } from '@arco-design/web-vue';
  import SaveUser from '@/views/system/user-manage/SaveUser.vue';
  import ResetPassword from '@/views/system/user-manage/ResetPassword.vue';

  const user = useUserStore();
  const formRef = ref();
  const tableRef = ref();
  const saveRef = ref();
  const pswRef = ref();
  const loading = ref(false);

  const tableData = computed(() => tableRef.value?.tableData || []);

  const columns = [
    {
      title: '成员名称',
      dataIndex: 'username',
      // align: 'center',
    },
    {
      title: '授权角色',
      dataIndex: 'role_text',
      align: 'left',
    },
    {
      title: '手机号',
      dataIndex: 'mobile',
      align: 'left',
    },
    {
      title: '邮箱',
      dataIndex: 'email',
      align: 'left',
    },
    {
      title: '登录密码',
      dataIndex: 'password',
      align: 'left',
      // align: 'center',
    },
    {
      title: '注册时间',
      // align: 'center',
      dataIndex: 'created_at',
      width: 180,
    },
    {
      title: '状态',
      dataIndex: 'status',
      align: 'center',
      slotName: 'status',
    },
    {
      title: '操作',
      dataIndex: 'action',
      align: 'center',
      width: 180,
      slotName: 'action',
    },
  ];
  const generateFormModel = () => {
    return {
      // 基础查询条件
      username: null,
      // 更多查询条件
      department_id: '',
      status: '',
    };
  };
  const baseSearchRules: any = ref([
    {
      field: 'username',
      label: '成员名称',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    {
      field: 'role_ids',
      label: '角色',
      value: null,
      component_name: 'base-request-select',
      attr: {
        api: 'role',
      },
    },
    {
      field: 'status',
      label: '状态',
      value: null,
      component_name: 'base-dict-select',
      attr: {
        selectType: 'state',
      },
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/member/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const handleRefresh = () => {
    handleSubmit();
    Message.success('刷新成功');
  };

  const changeUserStatus = async (record: any) => {
    record.loading = true;
    request('/api/member/set', {
      id: record.id,
      field: 'status',
      value: record.status ? 0 : 1,
    })
      .then(() => {
        handleSubmit();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  const deleteUser = async (record: any) => {
    record.loading = true;
    request('/api/member/delete', {
      id: record.id,
    })
      .then(() => {
        handleSubmit();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  function saveAction(record: any) {
    saveRef.value?.show(record);
  }
  function resetPasswordAction(record: any) {
    pswRef.value?.show(record);
  }
</script>

<style lang="less" scoped>
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }
</style>
