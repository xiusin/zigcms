<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>插件管理</span>
          <a-tag color="blue">{{ tableTotal }} 个插件</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            安装插件
          </a-button>
          <a-button size="small" @click="refreshList">
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
        placeholder="请输入插件名称搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="handleMarket">
              <template #icon>
                <icon-store />
              </template>
              插件市场
            </a-button>
            <a-button size="small" @click="handleUpdate">
              <template #icon>
                <icon-up />
              </template>
              检查更新
            </a-button>
          </a-space>
        </template>
      </SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
      >
        <template #logo="{ record }">
          <div class="plugin-logo">
            <img v-if="record.logo" :src="record.logo" alt="logo" />
            <icon-apps v-else />
          </div>
        </template>
        <template #plugin_type="{ record }">
          <a-tag :color="getTypeColor(record.plugin_type)">
            {{ getTypeText(record.plugin_type) }}
          </a-tag>
        </template>
        <template #price="{ record }">
          <span class="price">¥{{ record.price }}</span>
        </template>
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button
              v-if="record.status === 0"
              type="text"
              size="small"
              @click="installPlugin(record)"
            >
              <template #icon><icon-download /></template>
              安装
            </a-button>
            <template v-if="record.status === 1">
              <a-button
                type="text"
                size="small"
                @click="openConfigModal(record)"
              >
                <template #icon><icon-settings /></template>
                配置
              </a-button>
              <a-button
                type="text"
                size="small"
                status="danger"
                @click="uninstallPlugin(record)"
              >
                <template #icon><icon-delete /></template>
                卸载
              </a-button>
            </template>
            <a-button type="text" size="small" @click="viewDetail(record)">
              <template #icon><icon-eye /></template>
              详情
            </a-button>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 插件配置弹窗 -->
    <a-modal
      v-model:visible="configVisible"
      :title="`配置 - ${currentPlugin?.name}`"
      :width="700"
      :unmount-on-close="true"
      @ok="saveConfig"
    >
      <a-form :model="configData" layout="vertical">
        <a-form-item
          v-for="(item, key) in configFields"
          :key="key"
          :label="item.label"
        >
          <a-input
            v-if="item.type === 'text'"
            v-model="configData[key]"
            :placeholder="item.placeholder"
          />
          <a-input-number
            v-else-if="item.type === 'number'"
            v-model="configData[key]"
            :placeholder="item.placeholder"
            style="width: 100%"
          />
          <a-switch
            v-else-if="item.type === 'switch'"
            v-model="configData[key]"
          />
          <a-select
            v-else-if="item.type === 'select'"
            v-model="configData[key]"
            :placeholder="item.placeholder"
          >
            <a-option
              v-for="opt in item.options"
              :key="opt.value"
              :value="opt.value"
            >
              {{ opt.label }}
            </a-option>
          </a-select>
          <a-textarea
            v-else-if="item.type === 'textarea'"
            v-model="configData[key]"
            :placeholder="item.placeholder"
            :auto-size="{ minRows: 3, maxRows: 6 }"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 插件详情弹窗 -->
    <a-drawer
      v-model:visible="detailVisible"
      title="插件详情"
      :width="500"
      :unmount-on-close="true"
    >
      <div v-if="currentPlugin" class="plugin-detail">
        <div class="detail-header">
          <div class="detail-logo">
            <img
              v-if="currentPlugin.logo"
              :src="currentPlugin.logo"
              alt="logo"
            />
            <icon-apps v-else :size="48" />
          </div>
          <div class="detail-info">
            <div class="detail-name">{{ currentPlugin.name }}</div>
            <div class="detail-version">v{{ currentPlugin.version }}</div>
          </div>
        </div>
        <a-descriptions :column="1" bordered>
          <a-descriptions-item label="插件标识">
            {{ currentPlugin.identifier }}
          </a-descriptions-item>
          <a-descriptions-item label="插件类型">
            <a-tag :color="getTypeColor(currentPlugin.plugin_type)">
              {{ getTypeText(currentPlugin.plugin_type) }}
            </a-tag>
          </a-descriptions-item>
          <a-descriptions-item label="作者">
            {{ currentPlugin.author }}
          </a-descriptions-item>
          <a-descriptions-item label="价格">
            <span class="price">¥{{ currentPlugin.price }}</span>
          </a-descriptions-item>
          <a-descriptions-item label="下载次数">
            {{ currentPlugin.downloads || 0 }}
          </a-descriptions-item>
          <a-descriptions-item label="评分">
            <a-rate :model-value="currentPlugin.rating || 5" disabled />
          </a-descriptions-item>
          <a-descriptions-item label="简介">
            {{ currentPlugin.description }}
          </a-descriptions-item>
          <a-descriptions-item label="功能介绍">
            <div class="features">
              <div
                v-for="(feature, idx) in (currentPlugin.features || '').split(
                  '\n'
                )"
                :key="idx"
              >
                {{ feature }}
              </div>
            </div>
          </a-descriptions-item>
          <a-descriptions-item
            v-if="currentPlugin.install_time"
            label="安装时间"
          >
            {{ currentPlugin.install_time }}
          </a-descriptions-item>
          <a-descriptions-item label="状态">
            <a-tag :color="getStatusColor(currentPlugin.status)">
              {{ getStatusText(currentPlugin.status) }}
            </a-tag>
          </a-descriptions-item>
        </a-descriptions>
      </div>
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
  const configVisible = ref(false);
  const detailVisible = ref(false);
  const marketVisible = ref(false);
  const currentPlugin = ref<any>({});
  const configData = reactive<any>({});
  const configFields = ref<any>({});

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
      label: '插件名称',
      field: 'name',
      type: 'input',
      placeholder: '请输入插件名称',
    },
    {
      label: '插件类型',
      field: 'plugin_type',
      type: 'select',
      placeholder: '请选择插件类型',
      options: [
        { label: '功能增强', value: 1 },
        { label: '数据处理', value: 2 },
        { label: '第三方集成', value: 3 },
        { label: 'UI组件', value: 4 },
        { label: '安全防护', value: 5 },
      ],
    },
  ]);

  // 基础搜索规则
  const baseSearchRules = ref<any[]>([
    { label: '插件名称', field: 'name' },
  ]);

  // 处理搜索
  const handleSubmit = () => {
    tableRef.value?.search();
  };

  const columns = [
    { title: 'Logo', dataIndex: 'logo', width: 80, slotName: 'logo' },
    { title: '插件名称', dataIndex: 'name', width: 160 },
    { title: '标识符', dataIndex: 'identifier', width: 160 },
    { title: '版本', dataIndex: 'version', width: 80 },
    {
      title: '类型',
      dataIndex: 'plugin_type',
      width: 100,
      slotName: 'plugin_type',
    },
    { title: '作者', dataIndex: 'author', width: 120 },
    { title: '价格', dataIndex: 'price', width: 100, slotName: 'price' },
    { title: '下载', dataIndex: 'downloads', width: 80 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 220, slotName: 'action' },
  ];

  const getDataList = (data: any) => {
    return request('/api/operation/plugin/list', data);
  };

  const getTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'purple', 'red'];
    return colors[type] || 'default';
  };

  const getTypeText = (type: number) => {
    const texts = [
      '',
      '功能增强',
      '数据处理',
      '第三方集成',
      'UI组件',
      '安全防护',
    ];
    return texts[type] || '-';
  };

  const getStatusColor = (status: number) => {
    const colors = ['red', 'green', 'orange', 'gray'];
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = ['未安装', '已安装', '配置异常', '已卸载'];
    return texts[status] || '未知';
  };

  const refreshList = () => {
    tableRef.value?.search();
    Message.success('刷新成功');
  };

  // 插件市场
  const handleMarket = () => {
    Message.info('即将跳转到插件市场');
  };

  // 检查更新
  const handleUpdate = () => {
    Message.loading('正在检查插件更新...');
    setTimeout(() => {
      Message.success('所有插件已是最新版本');
    }, 1500);
  };

  const openModal = (record: any) => {
    marketVisible.value = true;
    Message.success('已打开插件市场');
  };

  const installPlugin = (record: any) => {
    request('/api/operation/plugin/install', { id: record.id }).then(() => {
      Message.success('安装成功');
      tableRef.value?.search();
    });
  };

  const uninstallPlugin = (record: any) => {
    request('/api/operation/plugin/uninstall', { id: record.id }).then(() => {
      Message.success('卸载成功');
      tableRef.value?.search();
    });
  };

  const openConfigModal = (record: any) => {
    currentPlugin.value = record;
    // 模拟配置字段
    configFields.value = {
      api_key: { label: 'API密钥', type: 'text', placeholder: '请输入API密钥' },
      api_secret: {
        label: 'API密钥',
        type: 'text',
        placeholder: '请输入API密钥',
      },
      enable: { label: '是否启用', type: 'switch' },
      timeout: {
        label: '超时时间(秒)',
        type: 'number',
        placeholder: '请输入超时时间',
      },
    };
    configData.api_key = 'test_key';
    configData.api_secret = 'test_secret';
    configData.enable = true;
    configData.timeout = 30;
    configVisible.value = true;
  };

  const saveConfig = () => {
    request('/api/operation/plugin/saveConfig', {
      plugin_id: currentPlugin.value.id,
      config: configData,
    }).then(() => {
      Message.success('配置保存成功');
      configVisible.value = false;
    });
  };

  const viewDetail = (record: any) => {
    currentPlugin.value = record;
    detailVisible.value = true;
  };
</script>

<style lang="less" scoped>
  .table-card {
    .table-card-header {
      display: flex;
      justify-content: space-between;
      align-items: center;
      padding: 16px;
      border-bottom: 1px solid var(--color-border-1);
    }
  }

  .plugin-logo {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    overflow: hidden;
    display: flex;
    align-items: center;
    justify-content: center;
    background: var(--color-secondary);
    color: var(--color-text-2);

    img {
      width: 100%;
      height: 100%;
      object-fit: cover;
    }
  }

  .price {
    font-size: 16px;
    font-weight: 600;
    color: #f53f3f;
  }

  .plugin-detail {
    .detail-header {
      display: flex;
      align-items: center;
      gap: 16px;
      padding-bottom: 16px;
      margin-bottom: 16px;
      border-bottom: 1px solid var(--color-border-1);

      .detail-logo {
        width: 64px;
        height: 64px;
        border-radius: 12px;
        overflow: hidden;
        display: flex;
        align-items: center;
        justify-content: center;
        background: var(--color-secondary);
        color: var(--color-text-2);

        img {
          width: 100%;
          height: 100%;
          object-fit: cover;
        }
      }

      .detail-info {
        .detail-name {
          font-size: 18px;
          font-weight: 600;
          margin-bottom: 4px;
        }

        .detail-version {
          font-size: 12px;
          color: var(--color-text-3);
        }
      }
    }

    .features {
      white-space: pre-wrap;
    }
  }

  // 统一表格内文字大小
  :deep(.arco-table) {
    .arco-table-cell {
      font-size: 12px !important;
    }
    .arco-table-th {
      font-size: 12px !important;
    }
  }

  // 统一按钮字体
  :deep(.arco-btn) {
    font-size: 12px !important;
  }

  // 统一标签字体
  :deep(.arco-tag) {
    font-size: 11px !important;
  }

  // 统一表单字体
  :deep(.arco-form-item) {
    .arco-form-item-label {
      font-size: 12px !important;
    }
  }

  // 统一描述列表字体
  :deep(.arco-descriptions) {
    .arco-descriptions-item-label {
      font-size: 12px !important;
    }
    .arco-descriptions-item-value {
      font-size: 12px !important;
    }
  }
</style>
