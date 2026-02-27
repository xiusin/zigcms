<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>黑名单管理</span>
          <a-tag color="blue">{{ tableTotal }} 个黑名单</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            添加黑名单
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
        placeholder="请输入用户名搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="batchImport">
              <template #icon>
                <icon-upload />
              </template>
              批量导入
            </a-button>
            <a-button size="small" @click="exportList">
              <template #icon>
                <icon-download />
              </template>
              导出列表
            </a-button>
            <a-button size="small" @click="handleAppeal">
              <template #icon>
                <icon-message />
              </template>
              申诉管理
            </a-button>
            <a-button size="small" @click="handleUnblockRecord">
              <template #icon>
                <icon-history />
              </template>
              解封记录
            </a-button>
          </a-space>
        </template>
      </SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #user_info="{ record }">
          <div class="user-info">
            <a-avatar :size="36" :image-url="record.avatar">
              {{ record.username?.charAt(0) }}
            </a-avatar>
            <div class="user-detail">
              <div class="username">{{ record.username }}</div>
              <div class="userid">ID: {{ record.user_id }}</div>
            </div>
          </div>
        </template>
        <template #block_type="{ record }">
          <a-tag :color="getBlockTypeColor(record.block_type)">
            {{ getBlockTypeText(record.block_type) }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            :loading="record.loading"
            size="small"
            @click="toggleStatus(record)"
          ></a-switch>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="openModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-popconfirm
              :content="`确定要${
                record.status === 1 ? '解封' : '封禁'
              }该用户吗?`"
              position="left"
              @ok="toggleStatus(record)"
            >
              <a-button type="text" size="small">
                <template #icon>
                  <icon-unlock v-if="record.status === 1" />
                  <icon-lock v-else />
                </template>
                {{ record.status === 1 ? '解封' : '封禁' }}
              </a-button>
            </a-popconfirm>
            <a-popconfirm
              :content="`确定要删除该记录吗?`"
              position="left"
              @ok="deleteRecord(record)"
            >
              <a-button type="text" size="small" status="danger">
                <template #icon><icon-delete /></template>
                删除
              </a-button>
            </a-popconfirm>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 添加/编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑黑名单' : '添加黑名单'"
      :width="600"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-form-item label="用户信息" field="user_id">
          <a-select
            v-model="formData.user_id"
            placeholder="请搜索选择用户"
            :filter-option="false"
            allow-clear
            show-search
          >
            <a-option v-for="user in userList" :key="user.id" :value="user.id">
              {{ user.username }} - {{ user.mobile }}
            </a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="封禁类型" field="block_type">
          <a-select v-model="formData.block_type" placeholder="请选择封禁类型">
            <a-option :value="1">账号封禁</a-option>
            <a-option :value="2">IP封禁</a-option>
            <a-option :value="3">设备封禁</a-option>
            <a-option :value="4">手机号封禁</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="封禁原因" field="reason">
          <a-textarea
            v-model="formData.reason"
            placeholder="请输入封禁原因"
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="封禁开始时间" field="start_time">
              <a-date-picker
                v-model="formData.start_time"
                style="width: 100%"
                show-time
                format="YYYY-MM-DD HH:mm:ss"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="封禁结束时间" field="end_time">
              <a-date-picker
                v-model="formData.end_time"
                style="width: 100%"
                show-time
                format="YYYY-MM-DD HH:mm:ss"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="封禁证据" field="evidence">
          <a-textarea
            v-model="formData.evidence"
            placeholder="请输入封禁证据"
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>
        <a-form-item label="备注" field="remark">
          <a-textarea v-model="formData.remark" placeholder="请输入备注" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 批量导入弹窗 -->
    <a-modal
      v-model:visible="importVisible"
      title="批量导入黑名单"
      :width="500"
      :unmount-on-close="true"
      @ok="handleImport"
    >
      <div class="import-tips">
        <div class="tips-title">导入说明：</div>
        <div>1. 请先下载模板文件，按模板格式填写数据</div>
        <div>2. 支持导入的字段：用户名、手机号、封禁类型、封禁原因</div>
        <div>3. 单次最多导入1000条数据</div>
        <div class="download-template">
          <a-button size="small" type="primary" @click="downloadTemplate">
            <template #icon>
              <icon-download />
            </template>
            下载模板
          </a-button>
        </div>
      </div>
      <a-upload
        :custom-request="handleUpload"
        :show-upload-list="false"
        accept=".xlsx,.xls,.csv"
      >
        <a-button>
          <template #icon>
            <icon-upload />
          </template>
          选择文件
        </a-button>
      </a-upload>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted, computed } from 'vue';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';

  const tableRef = ref();
  const loading = ref(false);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };

  const modalVisible = ref(false);
  const importVisible = ref(false);
  const appealVisible = ref(false);
  const unblockVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const userList = ref<any[]>([]);
  const importFile = ref<any>(null);

  const formData = reactive({
    id: 0,
    user_id: 0,
    block_type: 1,
    reason: '',
    start_time: '',
    end_time: '',
    evidence: '',
    remark: '',
  });

  const generateFormModel = () => ({
    username: null,
    block_type: '',
    status: '',
  });

  const rules = {
    user_id: [{ required: true, message: '请选择用户' }],
    block_type: [{ required: true, message: '请选择封禁类型' }],
    reason: [{ required: true, message: '请输入封禁原因' }],
  };

  const formModel = ref(generateFormModel());

  const baseSearchRules = ref([
    { field: 'username', label: '用户名', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'block_type',
      label: '封禁类型',
      value: null,
      component_name: 'base-select',
      attr: {
        placeholder: '请选择封禁类型',
        options: [
          { label: '账号封禁', value: 1 },
          { label: 'IP封禁', value: 2 },
          { label: '设备封禁', value: 3 },
          { label: '手机号封禁', value: 4 },
        ],
      },
    },
    {
      field: 'status',
      label: '状态',
      value: null,
      component_name: 'base-select',
      attr: {
        placeholder: '请选择状态',
        options: [
          { label: '生效中', value: 1 },
          { label: '已解封', value: 0 },
        ],
      },
    },
  ]);

  const columns = [
    {
      title: '用户信息',
      dataIndex: 'user_info',
      width: 200,
      slotName: 'user_info',
    },
    {
      title: '封禁类型',
      dataIndex: 'block_type',
      width: 120,
      slotName: 'block_type',
    },
    { title: '封禁原因', dataIndex: 'reason', ellipsis: true },
    { title: '封禁IP', dataIndex: 'ip', width: 140 },
    { title: '封禁设备', dataIndex: 'device_id', width: 160 },
    { title: '开始时间', dataIndex: 'start_time', width: 180 },
    { title: '结束时间', dataIndex: 'end_time', width: 180 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作人', dataIndex: 'operator', width: 100 },
    { title: '操作时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', dataIndex: 'action', width: 200, slotName: 'action' },
  ];

  const getDataList = (data: any) => {
    return request('/api/security/blacklist/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getBlockTypeColor = (type: number) => {
    const colors = ['', 'red', 'orange', 'purple', 'blue'];
    return colors[type] || 'default';
  };

  const getBlockTypeText = (type: number) => {
    const texts = ['', '账号封禁', 'IP封禁', '设备封禁', '手机号封禁'];
    return texts[type] || '-';
  };

  const fetchUserList = () => {
    request('/api/member/list', { pageSize: 100 }).then((res: any) => {
      userList.value = res.data?.list || [];
    });
  };

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, record);
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        user_id: 0,
        block_type: 1,
        reason: '',
        start_time: '',
        end_time: '',
        evidence: '',
        remark: '',
      });
    }
    modalVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    request('/api/security/blacklist/save', formData).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      modalVisible.value = false;
      tableRef.value?.search();
    });
  };

  const toggleStatus = (record: any) => {
    record.loading = true;
    request('/api/security/blacklist/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    })
      .then(() => {
        Message.success(record.status === 1 ? '已解封' : '已封禁');
        tableRef.value?.search();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  const deleteRecord = (record: any) => {
    request('/api/security/blacklist/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      tableRef.value?.search();
    });
  };

  const batchImport = () => {
    importVisible.value = true;
  };

  const handleImport = () => {
    Message.success('正在导入数据...');
    request('/api/security/blacklist/import', { file: importFile.value })
      .then((res: any) => {
        Message.success(`成功导入 ${res.data?.count || 0} 条数据`);
        importVisible.value = false;
        tableRef.value?.search();
      })
      .catch(() => {
        Message.error('导入失败，请检查文件格式');
      });
  };

  const downloadTemplate = () => {
    Message.success('正在下载模板...');
    const link = document.createElement('a');
    link.href = '/templates/blacklist_import_template.xlsx';
    link.download = '黑名单导入模板.xlsx';
    link.click();
  };

  const handleUpload = (options: any) => {
    console.log('上传文件:', options);
  };

  const exportList = () => {
    Message.success('正在导出数据...');
    request('/api/security/blacklist/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `黑名单数据_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  // 申诉管理
  const handleAppeal = () => {
    appealVisible.value = true;
  };

  // 解封记录
  const handleUnblockRecord = () => {
    unblockVisible.value = true;
  };

  onMounted(() => {
    fetchUserList();
  });
</script>

<style lang="less" scoped>
  .user-info {
    display: flex;
    align-items: center;
    gap: 12px;

    .user-detail {
      .username {
        font-weight: 500;
      }

      .userid {
        font-size: 12px;
        color: var(--color-text-3);
      }
    }
  }

  .import-tips {
    margin-bottom: 16px;
    padding: 16px;
    background: var(--color-secondary);
    border-radius: 4px;

    .tips-title {
      font-weight: 600;
      margin-bottom: 8px;
    }

    .download-template {
      margin-top: 16px;
    }
  }
</style>
