<template>
  <div class="content-box">
    <a-card class="generate-card no-padding">
      <SearchForm
        :form-data="formModel"
        :get-default-form-data="generateFormModel"
        :search-rules="searchRules"
        :base-search-rules="baseSearchRules"
        placeholder="请输入服务商名称"
        @hand-submit="handleSubmit"
      ></SearchForm>
    </a-card>

    <a-card class="table-card">
      <div class="table-card-header">
        <a-space>
          <a-button size="small" type="primary" @click="saveAction(null)">
            <template #icon>
              <icon-plus />
            </template>
            新增
          </a-button>
        </a-space>
        <a-space class="c-table-tool-item"> </a-space>
      </div>
      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #state="{ record }">
          <a-switch
            v-if="record.ralation_user_info.id"
            :model-value="record.ralation_user_info.state > 0"
            :disabled="!user.hasPermission([3, 31, 100])"
            :loading="record.loading"
            size="small"
            @click="changeConfirm(record)"
          ></a-switch>
          <span v-else>未开通</span>
        </template>
        <template #ralation_user_name="{ record }">
          <span v-if="record.ralation_user_name">
            {{ record.ralation_user_name }}
          </span>
          <a-link @click="saveAccountAction(record)">
            <IconEdit v-if="record.ralation_user_name" />
            <span v-else><icon-thunderbolt /> 开通</span>
          </a-link>
        </template>
        <template #business_user_name="{ record }">
          <div>
            {{ record.business_user_name || '-' }}
          </div>
        </template>
        <template #action="{ record }">
          <a-link
            :disabled="!user.hasPermission([3, 31, 100])"
            @click="saveAction(record)"
          >
            <IconEdit />
            编辑
          </a-link>
        </template>
      </base-table>
    </a-card>
    <save-service ref="saveRef" @create-over="handleSubmit()" />
    <!-- <save-customer-account
      ref="saveAccountRef"
      type="supplier"
      @create-over="handleSubmit()"
    /> -->
  </div>
</template>

<script setup lang="ts">
  import BaseTable from '@/components/table/base-table.vue';
  import { reactive, ref } from 'vue';
  import request from '@/api/request';
  import { useUserStore } from '@/store';
  import { Modal } from '@arco-design/web-vue';
  import SaveService from '@/views/manage/service-manage/SaveService.vue';
  import { isObject } from 'lodash';

  const user = useUserStore();

  const formRef = ref();
  const tableRef = ref();
  const saveRef = ref();
  const saveAccountRef = ref();
  const loading = ref(false);
  const columns = [
    {
      title: '服务商名称',
      align: 'center',
      dataIndex: 'name',
      width: 180,
      fixed: 'left',
    },
    {
      title: '销售负责人',
      align: 'center',
      dataIndex: 'business_user_name',
    },
    {
      title: '账户2',
      align: 'center',
      dataIndex: 'ralation_user_name',
    },
    {
      title: '已分配账户数',
      align: 'center',
      dataIndex: 'distribution_account_count',
    },
    {
      title: '新授权账户数',
      align: 'center',
      dataIndex: 'new_oauth_account_num',
    },
    {
      title: '创建日期',
      align: 'center',
      dataIndex: 'add_time',
      key: 'add_time',
    },
    {
      title: '更新日期',
      align: 'center',
      dataIndex: 'update_time',
    },
    {
      title: '状态',
      align: 'center',
      dataIndex: 'state',
      width: 90,
      fixed: 'right',
    },
    {
      title: '操作',
      align: 'center',
      dataIndex: 'action',
      fixed: 'right',
      width: 90,
    },
  ];

  // const formModel: any = reactive(getDefaultFormModel());

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
      label: '服务商名称',
      value: null,
      width: '100px',
    },
  ]);
  const searchRules: any = ref([
    {
      field: 'user_id',
      label: '销售负责人',
      value: null,
      component_name: 'base-request-select',
      attr: {
        api: 'user',
        sendParams: {
          role_id: 2,
          state: 1,
        },
      },
    },
    {
      field: 'is_open_saas_d',
      label: '是否开通账户',
      value: null,
      component_name: 'base-dict-select',
      attr: {
        selectType: 'openSass',
      },
    },
    {
      field: 'user_name',
      label: '账户',
      value: null,
      component_name: 'base-input',
    },
  ]);

  const formModel: any = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/supplierList', data);
  };

  // 点击搜索时 处理逻辑
  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    // 是否开通的关联关系
    if (formModel.value.is_open_saas_d === 1) {
      formModel.value.is_open_saas = true;
    } else if (formModel.value.is_open_saas_d === 0) {
      formModel.value.is_open_saas = false;
    } else {
      formModel.value.is_open_saas = '';
    }
    // 重置搜索 所有数据
    tableRef.value?.search();
  };

  const changeState = async (val: boolean, record: any) => {
    record.loading = true;
    request('/api/changeUserState', {
      id: record.ralation_user_info.id,
      state: val ? 1 : -1,
      company_type: 'supplier', // customer客户 或 supplier服务商
    })
      .then(() => {
        record.ralation_user_info.state = val ? 1 : -1;
      })
      .finally(() => {
        record.loading = false;
      });
  };

  // 修改状态二次提示
  const changeConfirm = (record: any) => {
    let val = record.ralation_user_info.state <= 0;
    if (!val) {
      Modal.confirm({
        title: '提示',
        content: `关闭账户会同时关闭此账户下的所有用户，确认关闭当前账户？`,
        onOk: () => {
          changeState(val, record);
        },
      });
    } else {
      changeState(val, record);
    }
  };

  function saveAction(record: any) {
    if (record) {
      record.contacts[0]?.cards?.forEach((item: any, index: number) => {
        if (isObject(item)) {
          // @ts-ignore
          record.contacts[0].cards[index] = item.response?.data?.url;
        }
      });
    }
    saveRef.value?.show(record);
  }
  function saveAccountAction(record: any) {
    saveAccountRef.value?.show(
      {
        ...record.ralation_user_info,
        id: record.id,
        effective_begin_date: record.effective_begin_date,
        effective_end_date: record.effective_end_date,
      },
      !!record?.ralation_user_name
    );
  }
</script>

<style scoped lang="less">
  .no-padding {
    :deep(.arco-card-body) {
      padding: 16px 16px 6px !important;
    }
  }
</style>
