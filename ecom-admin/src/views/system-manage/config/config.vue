<template>
  <div class="content-box">
    <!-- 顶部统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon blue">
              <icon-settings />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ configs.length }}</div>
              <div class="stat-label">配置项总数</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon green">
              <icon-check-circle />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ enabledCount }}</div>
              <div class="stat-label">已启用</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon orange">
              <icon-lock />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ disabledCount }}</div>
              <div class="stat-label">已禁用</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card" :bordered="false">
          <div class="stat-content">
            <div class="stat-icon purple">
              <icon-clock-circle />
            </div>
            <div class="stat-info">
              <div class="stat-value">{{ lastUpdateTime }}</div>
              <div class="stat-label">最后更新</div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <!-- 配置列表 -->
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>系统配置</span>
          <a-tag color="blue">{{ filteredConfigs.length }} 项配置</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-input-search
            v-model="searchKey"
            placeholder="搜索配置项..."
            size="small"
            style="width: 220px"
            allow-clear
            @search="handleSearch"
          />
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon><icon-plus /></template>
            添加配置
          </a-button>
          <a-button size="small" @click="handleRefreshCache">
            <template #icon><icon-refresh /></template>
            刷新缓存
          </a-button>
          <a-dropdown @select="handleExportImport">
            <a-button size="small">
              <template #icon><icon-more /></template>
              更多
            </a-button>
            <template #content>
              <a-doption value="export">
                <template #icon><icon-download /></template>
                导出配置
              </a-doption>
              <a-doption value="import">
                <template #icon><icon-upload /></template>
                导入配置
              </a-doption>
              <a-doption value="backup">
                <template #icon><icon-save /></template>
                备份配置
              </a-doption>
            </template>
          </a-dropdown>
        </a-space>
      </template>

      <!-- 配置分组标签 -->
      <div class="config-tabs-wrapper">
        <a-radio-group v-model="activeGroup" type="button" size="small">
          <a-radio value="all">
            <template #icon><icon-apps /></template>
            全部配置
          </a-radio>
          <a-radio value="basic">
            <template #icon><icon-settings /></template>
            基础配置
          </a-radio>
          <a-radio value="upload">
            <template #icon><icon-upload /></template>
            上传配置
          </a-radio>
          <a-radio value="payment">
            <template #icon><icon-wallet /></template>
            支付配置
          </a-radio>
          <a-radio value="sms">
            <template #icon><icon-message /></template>
            短信配置
          </a-radio>
          <a-radio value="email">
            <template #icon><icon-email /></template>
            邮件配置
          </a-radio>
        </a-radio-group>
      </div>

      <!-- 配置列表 -->
      <config-list
        :configs="filteredConfigs"
        @edit="openModal"
        @delete="deleteConfig"
        @status-change="changeStatus"
      />
    </a-card>

    <!-- 配置编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑配置' : '添加配置'"
      width="700px"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="配置名称" field="config_name" required>
              <a-input
                v-model="formData.config_name"
                placeholder="请输入配置名称"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="配置标识" field="config_key" required>
              <a-input
                v-model="formData.config_key"
                placeholder="如: site.name"
                :disabled="isEdit"
              />
            </a-form-item>
          </a-col>
        </a-row>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="配置分组" field="config_group">
              <a-select
                v-model="formData.config_group"
                placeholder="请选择分组"
              >
                <a-option value="basic">基础配置</a-option>
                <a-option value="upload">上传配置</a-option>
                <a-option value="payment">支付配置</a-option>
                <a-option value="sms">短信配置</a-option>
                <a-option value="email">邮件配置</a-option>
                <a-option value="other">其他配置</a-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="配置类型" field="config_type" required>
              <a-select
                v-model="formData.config_type"
                placeholder="请选择类型"
                @change="handleTypeChange"
              >
                <a-option value="text">文本</a-option>
                <a-option value="number">数字</a-option>
                <a-option value="textarea">多行文本</a-option>
                <a-option value="switch">开关</a-option>
                <a-option value="select">下拉选择</a-option>
                <a-option value="radio">单选</a-option>
                <a-option value="checkbox">多选</a-option>
                <a-option value="image">图片</a-option>
                <a-option value="file">文件</a-option>
                <a-option value="json">JSON</a-option>
                <a-option value="array">数组</a-option>
                <a-option value="color">颜色</a-option>
                <a-option value="date">日期</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>

        <a-form-item label="配置值" field="config_value">
          <a-input
            v-if="formData.config_type === 'text'"
            v-model="formData.config_value"
            placeholder="请输入配置值"
          />
          <a-input-number
            v-else-if="formData.config_type === 'number'"
            v-model="formData.config_value"
            style="width: 100%"
          />
          <a-textarea
            v-else-if="formData.config_type === 'textarea'"
            v-model="formData.config_value"
            :auto-size="{ minRows: 3, maxRows: 6 }"
            placeholder="请输入配置值"
          />
          <a-switch
            v-else-if="formData.config_type === 'switch'"
            v-model="formData.config_value"
          />
          <a-input
            v-else
            v-model="formData.config_value"
            placeholder="请输入配置值"
          />
        </a-form-item>

        <a-form-item label="配置说明" field="description">
          <a-textarea
            v-model="formData.description"
            placeholder="请输入配置说明"
            :auto-size="{ minRows: 2, maxRows: 4 }"
          />
        </a-form-item>

        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="排序" field="sort">
              <a-input-number
                v-model="formData.sort"
                :min="0"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="状态" field="status">
              <a-switch v-model="formData.status" />
            </a-form-item>
          </a-col>
        </a-row>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, onMounted } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import ConfigList from './components/config-list.vue';

  const modalVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const searchKey = ref('');
  const activeGroup = ref('all');

  const formData = reactive({
    id: 0,
    config_name: '',
    config_key: '',
    config_group: 'basic',
    config_type: 'text',
    config_value: '',
    description: '',
    sort: 0,
    status: true,
  });

  const rules = {
    config_name: [{ required: true, message: '请输入配置名称' }],
    config_key: [{ required: true, message: '请输入配置标识' }],
    config_type: [{ required: true, message: '请选择配置类型' }],
  };

  // 模拟配置数据
  const configs = ref<any[]>([
    {
      id: 1,
      config_name: '网站名称',
      config_key: 'site.name',
      config_group: 'basic',
      config_type: 'text',
      config_value: '后台管理系统',
      description: '网站标题名称',
      sort: 1,
      status: 1,
    },
    {
      id: 2,
      config_name: '网站Logo',
      config_key: 'site.logo',
      config_group: 'basic',
      config_type: 'image',
      config_value: 'https://example.com/logo.png',
      description: '网站Logo图片',
      sort: 2,
      status: 1,
    },
    {
      id: 3,
      config_name: 'ICP备案号',
      config_key: 'site.icp',
      config_group: 'basic',
      config_type: 'text',
      config_value: '京ICP备12345678号',
      description: '网站ICP备案号',
      sort: 3,
      status: 1,
    },
    {
      id: 4,
      config_name: '文件上传大小',
      config_key: 'upload.max_size',
      config_group: 'upload',
      config_type: 'number',
      config_value: 10,
      description: '最大上传文件大小(MB)',
      sort: 1,
      status: 1,
    },
    {
      id: 5,
      config_name: '允许上传类型',
      config_key: 'upload.allowed_types',
      config_group: 'upload',
      config_type: 'array',
      config_value: ['jpg', 'png', 'gif', 'pdf'],
      description: '允许上传的文件类型',
      sort: 2,
      status: 1,
    },
    {
      id: 6,
      config_name: '微信支付启用',
      config_key: 'payment.wechat.enable',
      config_group: 'payment',
      config_type: 'switch',
      config_value: true,
      description: '是否启用微信支付',
      sort: 1,
      status: 1,
    },
    {
      id: 7,
      config_name: '支付宝启用',
      config_key: 'payment.alipay.enable',
      config_group: 'payment',
      config_type: 'switch',
      config_value: true,
      description: '是否启用支付宝支付',
      sort: 2,
      status: 1,
    },
    {
      id: 8,
      config_name: '短信服务商',
      config_key: 'sms.provider',
      config_group: 'sms',
      config_type: 'select',
      config_value: 'aliyun',
      description: '短信服务提供商',
      sort: 1,
      status: 1,
    },
  ]);

  // 统计信息
  const enabledCount = computed(() => configs.value.filter(c => c.status === 1).length);
  const disabledCount = computed(() => configs.value.filter(c => c.status === 0).length);
  const lastUpdateTime = computed(() => '2小时前');

  // 过滤配置
  const filteredConfigs = computed(() => {
    let result = configs.value;
    
    // 按分组过滤
    if (activeGroup.value !== 'all') {
      result = result.filter(c => c.config_group === activeGroup.value);
    }
    
    // 按搜索关键词过滤
    if (searchKey.value) {
      const key = searchKey.value.toLowerCase();
      result = result.filter(c => 
        c.config_name.toLowerCase().includes(key) ||
        c.config_key.toLowerCase().includes(key)
      );
    }
    
    return result.sort((a, b) => a.sort - b.sort);
  });

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, {
        ...record,
        status: record.status === 1,
      });
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        config_name: '',
        config_key: '',
        config_group: activeGroup.value === 'all' ? 'basic' : activeGroup.value,
        config_type: 'text',
        config_value: '',
        description: '',
        sort: 0,
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
      status: formData.status ? 1 : 0,
    };

    if (isEdit.value) {
      const index = configs.value.findIndex(c => c.id === formData.id);
      if (index > -1) {
        configs.value[index] = { ...params, id: formData.id };
      }
      Message.success('编辑成功');
    } else {
      configs.value.push({
        ...params,
        id: configs.value.length + 1,
      });
      Message.success('添加成功');
    }
    modalVisible.value = false;
  };

  const deleteConfig = (record: any) => {
    const index = configs.value.findIndex(c => c.id === record.id);
    if (index > -1) {
      configs.value.splice(index, 1);
      Message.success('删除成功');
    }
  };

  const changeStatus = (record: any) => {
    record.status = record.status === 1 ? 0 : 1;
    Message.success(record.status === 1 ? '已启用' : '已禁用');
  };

  const handleTypeChange = () => {
    formData.config_value = '';
  };

  const handleSearch = () => {
    // 搜索逻辑已在 computed 中处理
  };

  const handleRefreshCache = () => {
    Message.loading('正在刷新缓存...');
    setTimeout(() => {
      Message.success('缓存刷新成功');
    }, 1000);
  };

  const handleExportImport = (value: string) => {
    const actions: Record<string, () => void> = {
      export: () => Message.success('配置导出成功'),
      import: () => Message.success('配置导入成功'),
      backup: () => Message.success('配置备份成功'),
    };
    actions[value]?.();
  };

  onMounted(() => {
    // 初始化数据
  });
</script>

<style scoped lang="less">
  .stat-row {
    margin-bottom: 16px;
  }

  .stat-card {
    .stat-content {
      display: flex;
      align-items: center;
      gap: 16px;
    }

    .stat-icon {
      width: 48px;
      height: 48px;
      border-radius: 12px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;

      &.blue {
        background: linear-gradient(135deg, #e6f7ff 0%, #bae7ff 100%);
        color: #1890ff;
      }

      &.green {
        background: linear-gradient(135deg, #f6ffed 0%, #d9f7be 100%);
        color: #52c41a;
      }

      &.orange {
        background: linear-gradient(135deg, #fff7e6 0%, #ffe7ba 100%);
        color: #fa8c16;
      }

      &.purple {
        background: linear-gradient(135deg, #f9f0ff 0%, #efdbff 100%);
        color: #722ed1;
      }
    }

    .stat-info {
      .stat-value {
        font-size: 24px;
        font-weight: 600;
        color: var(--color-text-1);
        line-height: 1.2;
      }

      .stat-label {
        font-size: 13px;
        color: var(--color-text-3);
        margin-top: 4px;
      }
    }
  }

  .config-tabs-wrapper {
    padding: 16px 16px 0;
    border-bottom: 1px solid var(--color-border-1);
    margin: 0 -16px 16px;
  }

  .table-card {
    :deep(.arco-card-body) {
      padding: 0;
    }
  }
</style>
