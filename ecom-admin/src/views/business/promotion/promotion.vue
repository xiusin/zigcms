<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>活动管理</span>
          <a-tag color="blue">{{ tableTotal }} 个活动</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            创建活动
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
        placeholder="请输入活动名称搜索"
        @hand-submit="handleSubmit"
      ></SearchForm>

      <base-table
        ref="tableRef"
        v-model:loading="loading"
        :columns-config="columns"
        :data-config="getDataList"
        :send-params="formModel"
      >
        <template #banner="{ record }">
          <a-image :src="record.banner" width="80" height="40" fit="cover" />
        </template>
        <template #promotion_type="{ record }">
          <a-tag :color="getTypeColor(record.promotion_type)">
            {{ getTypeText(record.promotion_type) }}
          </a-tag>
        </template>
        <template #discount="{ record }">
          <span v-if="record.promotion_type === 1" class="discount-text">
            {{ record.discount_value }}折
          </span>
          <span v-else-if="record.promotion_type === 2" class="discount-text">
            减¥{{ record.discount_value }}
          </span>
          <span v-else-if="record.promotion_type === 3" class="discount-text">
            ¥{{ record.discount_value }}
          </span>
          <span v-else>-</span>
        </template>
        <template #time_range="{ record }">
          <div class="time-range">
            <div>{{ record.start_time }}</div>
            <div>至</div>
            <div>{{ record.end_time }}</div>
          </div>
        </template>
        <template #status="{ record }">
          <a-tag :color="getStatusColor(record.status)">
            {{ getStatusText(record.status) }}
          </a-tag>
        </template>
        <template #action="{ record }">
          <div class="action-btns">
            <a-button type="text" size="small" @click="openModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-button type="text" size="small" @click="viewData(record)">
              <template #icon><icon-bar-chart /></template>
              数据
            </a-button>
            <a-popconfirm
              :content="`确定要${
                record.status === 1 ? '禁用' : '启用'
              }该活动吗?`"
              position="left"
              @ok="changeStatus(record)"
            >
              <a-button type="text" size="small">
                <template #icon>
                  <icon-lock v-if="record.status === 1" />
                  <icon-unlock v-else />
                </template>
                {{ record.status === 1 ? '禁用' : '启用' }}
              </a-button>
            </a-popconfirm>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 活动编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑活动' : '创建活动'"
      :width="720"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="活动名称" field="promotion_name">
              <a-input
                v-model="formData.promotion_name"
                placeholder="请输入活动名称"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="活动类型" field="promotion_type">
              <a-select
                v-model="formData.promotion_type"
                placeholder="请选择活动类型"
              >
                <a-option :value="1">折扣活动</a-option>
                <a-option :value="2">满减活动</a-option>
                <a-option :value="3">满赠活动</a-option>
                <a-option :value="4">秒杀活动</a-option>
                <a-option :value="5">拼团活动</a-option>
              </a-select>
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="活动 Banner" field="banner">
          <a-input v-model="formData.banner" placeholder="请输入图片URL" />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="折扣/减/赠值" field="discount_value">
              <a-input-number
                v-model="formData.discount_value"
                :min="0"
                :max="formData.promotion_type === 1 ? 10 : 99999"
                :precision="formData.promotion_type === 1 ? 1 : 2"
                placeholder="请输入数值"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="使用门槛" field="min_amount">
              <a-input-number
                v-model="formData.min_amount"
                :min="0"
                :precision="2"
                placeholder="请输入门槛金额"
                style="width: 100%"
              >
                <template #prefix>¥</template>
              </a-input-number>
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="活动开始时间" field="start_time">
              <a-date-picker
                v-model="formData.start_time"
                style="width: 100%"
                show-time
                format="YYYY-MM-DD HH:mm:ss"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="活动结束时间" field="end_time">
              <a-date-picker
                v-model="formData.end_time"
                style="width: 100%"
                show-time
                format="YYYY-MM-DD HH:mm:ss"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="活动范围" field="scope_type">
          <a-radio-group v-model="formData.scope_type">
            <a-radio value="all">全场通用</a-radio>
            <a-radio value="category">指定分类</a-radio>
            <a-radio value="product">指定商品</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="活动说明" field="description">
          <a-textarea
            v-model="formData.description"
            placeholder="请输入活动说明"
            :max-length="500"
            show-word-limit
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 活动数据弹窗 -->
    <a-modal
      v-model:visible="dataVisible"
      :title="`活动数据 - ${currentRecord?.promotion_name}`"
      :width="800"
      :unmount-on-close="true"
    >
      <a-descriptions :column="3" bordered>
        <a-descriptions-item label="浏览次数">
          {{ currentRecord?.view_count || 0 }}
        </a-descriptions-item>
        <a-descriptions-item label="参与人数">
          {{ currentRecord?.join_count || 0 }}
        </a-descriptions-item>
        <a-descriptions-item label="成交订单">
          <a-link @click="goToOrder">{{
            currentRecord?.order_count || 0
          }}</a-link>
        </a-descriptions-item>
        <a-descriptions-item label="优惠金额">
          ¥{{ currentRecord?.discount_amount || 0 }}
        </a-descriptions-item>
        <a-descriptions-item label="销售额">
          <a-link @click="goToIncome"
            >¥{{ currentRecord?.sales_amount || 0 }}</a-link
          >
        </a-descriptions-item>
        <a-descriptions-item label="转化率">
          {{ currentRecord?.conversion_rate || 0 }}%
        </a-descriptions-item>
      </a-descriptions>
      <template #footer>
        <a-space>
          <a-button size="small" @click="goToOrder">
            <template #icon><icon-shopping-cart /></template>
            查看订单
          </a-button>
          <a-button size="small" @click="goToIncome">
            <template #icon><icon-money-circle /></template>
            查看收入
          </a-button>
          <a-button size="small" type="primary" @click="dataVisible = false"
            >关闭</a-button
          >
        </a-space>
      </template>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed } from 'vue';
  import { useRouter } from 'vue-router';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';

  const router = useRouter();

  const tableRef = ref();
  const loading = ref(false);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };
  const modalVisible = ref(false);
  const dataVisible = ref(false);
  const isEdit = ref(false);
  const currentRecord = ref<any>({});
  const formRef = ref();

  const formData = reactive({
    id: 0,
    promotion_name: '',
    promotion_type: 1,
    banner: '',
    discount_value: 0,
    min_amount: 0,
    start_time: '',
    end_time: '',
    scope_type: 'all',
    description: '',
  });

  const rules = {
    promotion_name: [{ required: true, message: '请输入活动名称' }],
    promotion_type: [{ required: true, message: '请选择活动类型' }],
    discount_value: [{ required: true, message: '请输入折扣值' }],
  };

  const columns = [
    { title: 'Banner', dataIndex: 'banner', width: 100, slotName: 'banner' },
    { title: '活动名称', dataIndex: 'promotion_name', width: 180 },
    {
      title: '活动类型',
      dataIndex: 'promotion_type',
      width: 100,
      slotName: 'promotion_type',
    },
    { title: '优惠', dataIndex: 'discount', width: 100, slotName: 'discount' },
    { title: '门槛', dataIndex: 'min_amount', width: 100 },
    {
      title: '活动时间',
      dataIndex: 'time_range',
      width: 200,
      slotName: 'time_range',
    },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 200, slotName: 'action' },
  ];

  const generateFormModel = () => ({
    promotion_name: null,
    promotion_type: '',
    status: '',
  });

  const baseSearchRules = ref([
    { field: 'promotion_name', label: '活动名称', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'promotion_type',
      label: '活动类型',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'promotion_type' },
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
    return request('/api/business/promotion/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'red', 'purple'];
    return colors[type] || 'default';
  };

  const getTypeText = (type: number) => {
    const texts = ['', '折扣', '满减', '满赠', '秒杀', '拼团'];
    return texts[type] || '-';
  };

  const getStatusColor = (status: number) => {
    const colors = ['red', 'green', 'gray'];
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = ['未开始', '进行中', '已结束'];
    return texts[status] || '未知';
  };

  const openModal = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, record);
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        promotion_name: '',
        promotion_type: 1,
        banner: '',
        discount_value: 0,
        min_amount: 0,
        start_time: '',
        end_time: '',
        scope_type: 'all',
        description: '',
      });
    }
    modalVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    request('/api/business/promotion/save', formData).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '创建成功');
      modalVisible.value = false;
      handleSubmit();
    });
  };

  const viewData = (record: any) => {
    currentRecord.value = record;
    dataVisible.value = true;
  };

  // 跳转到订单管理
  const goToOrder = () => {
    router.push({
      path: '/business/order',
      query: { promotionId: currentRecord.value.id },
    });
  };

  // 跳转到收入管理
  const goToIncome = () => {
    router.push({
      path: '/business/income',
      query: { promotionId: currentRecord.value.id },
    });
  };

  const changeStatus = (record: any) => {
    request('/api/business/promotion/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    }).then(() => {
      Message.success('状态更新成功');
      handleSubmit();
    });
  };
</script>

<style lang="less" scoped>
  .time-range {
    font-size: 12px;
    line-height: 1.5;
    color: var(--color-text-2);
  }

  .discount-text {
    color: #f53f3f;
    font-weight: 600;
  }
</style>
