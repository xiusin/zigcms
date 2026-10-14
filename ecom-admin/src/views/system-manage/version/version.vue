<template>
  <div class="content-box">
    <!-- 版本列表 -->
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>版本列表</span>
          <a-tag color="blue">{{ tableTotal }} 个版本</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            发布新版本
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
        placeholder="请输入版本号搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-radio-group v-model="versionType" type="button" size="small">
              <a-radio value="all">全部</a-radio>
              <a-radio value="stable">正式版</a-radio>
              <a-radio value="beta">测试版</a-radio>
            </a-radio-group>
          </a-space>
        </template>
      </SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
      >
        <template #version_type="{ record }">
          <a-tag :color="getTypeColor(record.version_type)">
            {{ getTypeText(record.version_type) }}
          </a-tag>
        </template>
        <template #force_update="{ record }">
          <a-tag :color="record.force_update === 1 ? 'red' : 'green'">
            {{ record.force_update === 1 ? '强制更新' : '可选更新' }}
          </a-tag>
        </template>
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="viewDetail(record)">
              <template #icon><icon-eye /></template>
              查看
            </a-button>
            <a-button type="text" size="small" @click="openModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-popconfirm
              :content="`确定要${
                record.status === 1 ? '下架' : '发布'
              }该版本吗?`"
              position="left"
              @ok="changeStatus(record)"
            >
              <a-button type="text" size="small">
                <template #icon>
                  <icon-send v-if="record.status === 0" />
                  <icon-close v-else />
                </template>
                {{ record.status === 1 ? '下架' : '发布' }}
              </a-button>
            </a-popconfirm>
            <a-button type="text" size="small" @click="handleRollback(record)">
              <template #icon><icon-refresh /></template>
              回滚
            </a-button>
            <a-popconfirm
              :content="`确定要删除该版本吗?`"
              position="left"
              @ok="deleteVersion(record)"
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

    <!-- 版本编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑版本' : '发布新版本'"
      :width="700"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="版本号" field="version">
              <a-input v-model="formData.version" placeholder="如: 1.0.0" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="版本类型" field="version_type">
              <a-select
                v-model="formData.version_type"
                placeholder="请选择版本类型"
              >
                <a-option :value="1">正式版</a-option>
                <a-option :value="2">测试版</a-option>
                <a-option :value="3">历史版本</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="强制更新" field="force_update">
              <a-switch v-model="formData.force_update" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="最低版本" field="min_version">
              <a-input v-model="formData.min_version" placeholder="如: 1.0.0" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="版本标题" field="title">
          <a-input v-model="formData.title" placeholder="请输入版本标题" />
        </a-form-item>
        <a-form-item label="更新内容" field="content">
          <a-textarea
            v-model="formData.content"
            placeholder="请输入更新内容，每行一项"
            :auto-size="{ minRows: 5, maxRows: 10 }"
          />
        </a-form-item>
        <a-form-item label="下载链接" field="download_url">
          <a-input
            v-model="formData.download_url"
            placeholder="请输入安装包下载链接"
          />
        </a-form-item>
        <a-form-item label="版本大小" field="file_size">
          <a-input v-model="formData.file_size" placeholder="如: 50MB" />
        </a-form-item>
        <a-form-item label="MD5校验码" field="md5">
          <a-input v-model="formData.md5" placeholder="请输入MD5校验码" />
        </a-form-item>
        <a-form-item label="发布说明" field="remark">
          <a-textarea v-model="formData.remark" placeholder="请输入发布说明" />
        </a-form-item>
        <a-form-item label="立即发布" field="status">
          <a-switch v-model="formData.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 版本回滚弹窗 -->
    <a-modal
      v-model:visible="rollbackVisible"
      title="版本回滚"
      :width="500"
      @ok="confirmRollback"
    >
      <a-alert type="warning" style="margin-bottom: 16px">
        回滚操作将会影响当前系统运行，请确认后再操作！
      </a-alert>
      <a-form layout="vertical">
        <a-form-item label="回滚目标版本">
          <a-input :model-value="rollbackRecord.value?.version" disabled />
        </a-form-item>
        <a-form-item label="回滚说明">
          <a-textarea placeholder="请输入回滚原因" :rows="3" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 版本详情弹窗 -->
    <a-drawer
      v-model:visible="detailVisible"
      :title="`版本详情 - v${currentRecord?.version}`"
      :width="500"
      :unmount-on-close="true"
    >
      <a-descriptions :column="1" bordered>
        <a-descriptions-item label="版本号">
          v{{ currentRecord?.version }}
        </a-descriptions-item>
        <a-descriptions-item label="版本类型">
          <a-tag :color="getTypeColor(currentRecord?.version_type)">
            {{ getTypeText(currentRecord?.version_type) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="更新方式">
          <a-tag :color="currentRecord?.force_update === 1 ? 'red' : 'green'">
            {{ currentRecord?.force_update === 1 ? '强制更新' : '可选更新' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="版本大小">
          {{ currentRecord?.file_size }}
        </a-descriptions-item>
        <a-descriptions-item label="下载链接">
          <a-link :href="currentRecord?.download_url" target="_blank">
            {{ currentRecord?.download_url }}
          </a-link>
        </a-descriptions-item>
        <a-descriptions-item label="MD5">
          {{ currentRecord?.md5 }}
        </a-descriptions-item>
        <a-descriptions-item label="更新内容">
          <div class="content-list">
            <div
              v-for="(item, index) in (currentRecord?.content || '').split(
                '\n'
              )"
              :key="index"
            >
              {{ item }}
            </div>
          </div>
        </a-descriptions-item>
        <a-descriptions-item label="发布时间">
          {{ currentRecord?.release_time }}
        </a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="getStatusColor(currentRecord?.status)">
            {{ getStatusText(currentRecord?.status) }}
          </a-tag>
        </a-descriptions-item>
      </a-descriptions>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed } from 'vue';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';

  const tableRef = ref();
  const loading = ref(false);
  const modalVisible = ref(false);
  const detailVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const versionType = ref('all');
  const currentRecord = ref<any>({});

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

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
      label: '版本号',
      field: 'version',
      type: 'input',
      placeholder: '请输入版本号',
    },
    {
      label: '版本类型',
      field: 'version_type',
      type: 'select',
      placeholder: '请选择版本类型',
      options: [
        { label: '正式版', value: 1 },
        { label: '测试版', value: 2 },
      ],
    },
  ]);

  // 基础搜索规则
  const baseSearchRules = ref<any[]>([
    { label: '版本号', field: 'version' },
  ]);

  // 处理搜索
  const handleSubmit = () => {
    tableRef.value?.search();
  };

  // 刷新数据
  const refreshData = () => {
    tableRef.value?.search();
    Message.success('刷新成功');
  };

  const currentVersion = reactive({
    version: '1.0.8',
    release_time: '2024-01-15 10:00:00',
  });

  const formData = reactive({
    id: 0,
    version: '',
    version_type: 1,
    force_update: false,
    min_version: '',
    title: '',
    content: '',
    download_url: '',
    file_size: '',
    md5: '',
    remark: '',
    status: true,
  });

  const rules = {
    version: [{ required: true, message: '请输入版本号' }],
    version_type: [{ required: true, message: '请选择版本类型' }],
    title: [{ required: true, message: '请输入版本标题' }],
    download_url: [{ required: true, message: '请输入下载链接' }],
  };

  const columns = [
    { title: '版本号', dataIndex: 'version', width: 100 },
    { title: '版本标题', dataIndex: 'title', width: 180 },
    {
      title: '版本类型',
      dataIndex: 'version_type',
      width: 100,
      slotName: 'version_type',
    },
    {
      title: '更新方式',
      dataIndex: 'force_update',
      width: 100,
      slotName: 'force_update',
    },
    { title: '最低版本', dataIndex: 'min_version', width: 100 },
    { title: '版本大小', dataIndex: 'file_size', width: 100 },
    { title: '发布状态', dataIndex: 'status', width: 100, slotName: 'status' },
    { title: '发布时间', dataIndex: 'release_time', width: 180 },
    { title: '操作', dataIndex: 'action', width: 280, slotName: 'action' },
  ];

  const getDataList = (data: any) => {
    return request('/api/system/version/list', {
      ...data,
      version_type: versionType.value,
    });
  };

  const getTypeColor = (type: number) => {
    const colors = ['', 'green', 'blue', 'gray'];
    return colors[type] || 'default';
  };

  const getTypeText = (type: number) => {
    const texts = ['', '正式版', '测试版', '历史版本'];
    return texts[type] || '-';
  };

  const getStatusColor = (status: number) => {
    const colors = ['red', 'green', 'gray'];
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = ['未发布', '已发布', '已下架'];
    return texts[status] || '未知';
  };

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, {
        ...record,
        force_update: record.force_update === 1,
        status: record.status === 1,
      });
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        version: '',
        version_type: 1,
        force_update: false,
        min_version: '',
        title: '',
        content: '',
        download_url: '',
        file_size: '',
        md5: '',
        remark: '',
        status: true,
      });
    }
    modalVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    const params = {
      ...formData,
      force_update: formData.force_update ? 1 : 0,
      status: formData.status ? 1 : 0,
    };

    request('/api/system/version/save', params).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '发布成功');
      modalVisible.value = false;
      tableRef.value?.search();
    });
  };

  const viewDetail = (record: any) => {
    currentRecord.value = record;
    detailVisible.value = true;
  };

  const changeStatus = (record: any) => {
    request('/api/system/version/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    }).then(() => {
      Message.success(record.status === 1 ? '下架成功' : '发布成功');
      tableRef.value?.search();
    });
  };

  const deleteVersion = (record: any) => {
    request('/api/system/version/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      tableRef.value?.search();
    });
  };

  const checkUpdate = () => {
    Message.success('当前已是最新版本');
  };

  // 版本回滚
  const rollbackVisible = ref(false);
  const rollbackRecord = ref<any>({});

  const handleRollback = (record: any) => {
    rollbackRecord.value = record;
    rollbackVisible.value = true;
  };

  const confirmRollback = () => {
    Message.success(`已回滚到版本 ${rollbackRecord.value.version}`);
    rollbackVisible.value = false;
  };
</script>

<style lang="less" scoped>
  .version-card {
    margin-bottom: 16px;

    .current-version {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 20px;

      .version-info {
        .version-title {
          font-size: 14px;
          color: var(--color-text-2);
          margin-bottom: 8px;
        }

        .version-number {
          font-size: 32px;
          font-weight: 600;
          color: var(--color-text-1);
        }

        .version-time {
          font-size: 12px;
          color: var(--color-text-3);
          margin-top: 8px;
        }
      }
    }
  }

  .table-card {
    .table-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16px;
      border-bottom: 1px solid var(--color-border-1);
    }
  }

  .content-list {
    white-space: pre-wrap;
  }
</style>
