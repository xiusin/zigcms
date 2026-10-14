<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>工具箱管理</span>
          <a-tag color="blue">{{ tableTotal }} 个工具</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openToolModal({})">
            <template #icon>
              <icon-plus />
            </template>
            添加工具
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
        placeholder="请输入工具名称搜索"
        @hand-submit="handleSubmit"
      ></SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #icon="{ record }">
          <div class="tool-icon" :style="{ background: record.icon_bg }">
            <component :is="record.icon || 'IconTool'" />
          </div>
        </template>
        <template #tool_type="{ record }">
          <a-tag :color="getTypeColor(record.tool_type)">
            {{ getTypeText(record.tool_type) }}
          </a-tag>
        </template>
        <template #price_config="{ record }">
          <div class="price-info">
            <div v-if="record.is_package === 1">
              <span class="label">打包价:</span>
              <span class="value">¥{{ record.package_price }}</span>
            </div>
            <div v-if="record.is_single === 1">
              <span class="label">单独:</span>
              <span class="value">¥{{ record.single_price }}</span>
            </div>
            <span
              v-if="!record.is_package && !record.is_single"
              class="no-price"
            >
              未定价
            </span>
          </div>
        </template>
        <template #status="{ record }">
          <a-switch
            :model-value="record.status === 1"
            :loading="record.loading"
            size="small"
            @click="changeStatus(record)"
          ></a-switch>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="openToolModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-button type="text" size="small" @click="openPriceModal(record)">
              <template #icon><icon-price-tag /></template>
              价格
            </a-button>
            <a-popconfirm
              :content="`确定要删除该工具吗?`"
              position="left"
              @ok="deleteTool(record)"
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

    <!-- 工具编辑弹窗 -->
    <a-modal
      v-model:visible="toolVisible"
      :title="isEdit ? '编辑工具' : '添加工具'"
      :width="600"
      :unmount-on-close="true"
      @ok="handleSaveTool"
    >
      <a-form
        ref="toolFormRef"
        :model="toolForm"
        :rules="toolRules"
        layout="vertical"
      >
        <a-form-item label="工具名称" field="tool_name">
          <a-input v-model="toolForm.tool_name" placeholder="请输入工具名称" />
        </a-form-item>
        <a-form-item label="工具类型" field="tool_type">
          <a-select v-model="toolForm.tool_type" placeholder="请选择工具类型">
            <a-option :value="1">数据分析</a-option>
            <a-option :value="2">营销推广</a-option>
            <a-option :value="3">订单管理</a-option>
            <a-option :value="4">客户管理</a-option>
            <a-option :value="5">其他</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="工具图标" field="icon">
          <a-input v-model="toolForm.icon" placeholder="请输入图标名称" />
        </a-form-item>
        <a-form-item label="图标背景色" field="icon_bg">
          <a-input
            v-model="toolForm.icon_bg"
            placeholder="请输入背景色如: #1890ff"
          />
        </a-form-item>
        <a-form-item label="工具描述" field="description">
          <a-textarea
            v-model="toolForm.description"
            placeholder="请输入工具描述"
            :max-length="200"
            show-word-limit
          />
        </a-form-item>
        <a-form-item label="排序" field="sort">
          <a-input-number
            v-model="toolForm.sort"
            :min="0"
            :max="9999"
            style="width: 100%"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 价格配置弹窗 -->
    <a-modal
      v-model:visible="priceVisible"
      title="价格配置"
      :width="500"
      :unmount-on-close="true"
      @ok="handleSavePrice"
    >
      <a-form ref="priceFormRef" :model="priceForm" layout="vertical">
        <a-form-item label="工具名称">
          <a-input :model-value="priceForm.tool_name" disabled />
        </a-form-item>
        <a-form-item label="销售方式">
          <a-checkbox-group v-model="priceForm.sale_types">
            <a-checkbox value="package">打包销售</a-checkbox>
            <a-checkbox value="single">单独销售</a-checkbox>
          </a-checkbox-group>
        </a-form-item>
        <a-form-item
          v-if="priceForm.sale_types?.includes('package')"
          label="打包价格"
        >
          <a-input-number
            v-model="priceForm.package_price"
            :min="0"
            :precision="2"
            :step="1"
            placeholder="请输入打包价格"
            style="width: 100%"
          >
            <template #prefix>¥</template>
          </a-input-number>
        </a-form-item>
        <a-form-item
          v-if="priceForm.sale_types?.includes('single')"
          label="单独价格"
        >
          <a-input-number
            v-model="priceForm.single_price"
            :min="0"
            :precision="2"
            :step="1"
            placeholder="请输入单独价格"
            style="width: 100%"
          >
            <template #prefix>¥</template>
          </a-input-number>
        </a-form-item>
        <a-divider>高级配置</a-divider>
        <a-form-item label="是否推荐">
          <a-switch v-model="priceForm.is_recommend" />
        </a-form-item>
        <a-form-item v-if="priceForm.is_recommend" label="推荐排序">
          <a-input-number
            v-model="priceForm.recommend_sort"
            :min="0"
            style="width: 100%"
          />
        </a-form-item>
      </a-form>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed } from 'vue';
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
  const toolVisible = ref(false);
  const priceVisible = ref(false);
  const isEdit = ref(false);
  const toolFormRef = ref();
  const priceFormRef = ref();

  const toolForm = reactive({
    id: 0,
    tool_name: '',
    tool_type: 1,
    icon: '',
    icon_bg: '#1890ff',
    description: '',
    sort: 0,
  });

  const priceForm = reactive({
    id: 0,
    tool_name: '',
    sale_types: ['package'],
    package_price: 0,
    single_price: 0,
    is_recommend: false,
    recommend_sort: 0,
  });

  const toolRules = {
    tool_name: [{ required: true, message: '请输入工具名称' }],
    tool_type: [{ required: true, message: '请选择工具类型' }],
  };

  const columns = [
    { title: '图标', dataIndex: 'icon', width: 80, slotName: 'icon' },
    { title: '工具名称', dataIndex: 'tool_name', width: 150 },
    {
      title: '工具类型',
      dataIndex: 'tool_type',
      width: 100,
      slotName: 'tool_type',
    },
    {
      title: '价格配置',
      dataIndex: 'price_config',
      width: 180,
      slotName: 'price_config',
    },
    { title: '描述', dataIndex: 'description', ellipsis: true },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 200, slotName: 'action' },
  ];

  const generateFormModel = () => ({
    tool_name: null,
    tool_type: '',
    status: '',
  });

  const baseSearchRules = ref([
    { field: 'tool_name', label: '工具名称', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'tool_type',
      label: '工具类型',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'tool_type' },
    },
    {
      field: 'status',
      label: '状态',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'status' },
    },
  ]);

  const formModel = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/business/toolbox/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'purple', 'cyan'];
    return colors[type] || 'default';
  };

  const getTypeText = (type: number) => {
    const texts = ['', '数据分析', '营销推广', '订单管理', '客户管理', '其他'];
    return texts[type] || '-';
  };

  const openToolModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(toolForm, record);
    } else {
      isEdit.value = false;
      Object.assign(toolForm, {
        id: 0,
        tool_name: '',
        tool_type: 1,
        icon: '',
        icon_bg: '#1890ff',
        description: '',
        sort: 0,
      });
    }
    toolVisible.value = true;
  };

  const openPriceModal = (record: any) => {
    Object.assign(priceForm, {
      id: record.id,
      tool_name: record.tool_name,
      sale_types: record.is_package ? ['package'] : [],
      package_price: record.package_price || 0,
      single_price: record.single_price || 0,
      is_recommend: record.is_recommend === 1,
      recommend_sort: record.recommend_sort || 0,
    });
    if (record.is_single) {
      priceForm.sale_types.push('single');
    }
    priceVisible.value = true;
  };

  const handleSaveTool = async () => {
    const valid = await toolFormRef.value?.validate();
    if (valid) return;

    request('/api/business/toolbox/save', toolForm).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      toolVisible.value = false;
      handleSubmit();
    });
  };

  const handleSavePrice = () => {
    const params = {
      id: priceForm.id,
      is_package: priceForm.sale_types.includes('package') ? 1 : 0,
      is_single: priceForm.sale_types.includes('single') ? 1 : 0,
      package_price: priceForm.package_price,
      single_price: priceForm.single_price,
      is_recommend: priceForm.is_recommend ? 1 : 0,
      recommend_sort: priceForm.recommend_sort,
    };
    request('/api/business/toolbox/savePrice', params).then(() => {
      Message.success('价格配置保存成功');
      priceVisible.value = false;
      handleSubmit();
    });
  };

  const changeStatus = async (record: any) => {
    record.loading = true;
    request('/api/business/toolbox/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    })
      .then(() => {
        Message.success('状态更新成功');
        handleSubmit();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  const deleteTool = (record: any) => {
    request('/api/business/toolbox/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      handleSubmit();
    });
  };
</script>

<style lang="less" scoped>
  .tool-icon {
    width: 40px;
    height: 40px;
    border-radius: 8px;
    display: flex;
    align-items: center;
    justify-content: center;
    font-size: 20px;
    color: #fff;
  }

  .price-info {
    .label {
      color: var(--color-text-2);
      margin-right: 4px;
    }
    .value {
      color: #f53f3f;
      font-weight: 500;
      margin-right: 8px;
    }
    .no-price {
      color: var(--color-text-3);
    }
  }
</style>
