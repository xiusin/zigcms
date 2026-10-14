<template>
  <div class="content-box">
    <!-- 统计卡片 -->
    <a-row :gutter="[16, 16]" class="stat-row">
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon blue">
              <icon-computer />
            </div>
            <div class="stat-info">
              <div class="stat-label">设备总数</div>
              <div class="stat-value">{{ stats.total }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon green">
              <icon-check-circle />
            </div>
            <div class="stat-info">
              <div class="stat-label">已绑定</div>
              <div class="stat-value">{{ stats.bound }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon orange">
              <icon-history />
            </div>
            <div class="stat-info">
              <div class="stat-label">试用中</div>
              <div class="stat-value">{{ stats.trial }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
      <a-col :xs="24" :sm="12" :md="6">
        <a-card class="stat-card">
          <div class="stat-content">
            <div class="stat-icon red">
              <icon-exclamation-circle />
            </div>
            <div class="stat-info">
              <div class="stat-label">待续费</div>
              <div class="stat-value">{{ stats.expired }}</div>
            </div>
          </div>
        </a-card>
      </a-col>
    </a-row>

    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>机器管理</span>
          <a-tag color="blue">{{ tableTotal }} 台机器</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            添加机器
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
        placeholder="请输入机器编号搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="handleTrialReminder">
              <template #icon>
                <icon-bell />
              </template>
              试用期提醒
            </a-button>
            <a-button size="small" @click="handleExport">
              <template #icon>
                <icon-download />
              </template>
              导出
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
        <template #machine_status="{ record }">
          <a-tag :color="getStatusColor(record.machine_status)">
            {{ getStatusText(record.machine_status) }}
          </a-tag>
        </template>
        <template #bind_status="{ record }">
          <a-tag :color="record.bind_order_id ? 'green' : 'orange'">
            {{ record.bind_order_id ? '已绑定' : '未绑定' }}
          </a-tag>
        </template>
        <template #expire_status="{ record }">
          <a-tag v-if="record.machine_status === 2" color="red"> 已过期 </a-tag>
          <a-tag
            v-else-if="record.machine_status === 1 && record.expire_days <= 7"
            color="orange"
          >
            即将过期({{ record.expire_days }}天)
          </a-tag>
          <a-tag v-else-if="record.machine_status === 1" color="green">
            正常使用
          </a-tag>
          <a-tag v-else color="gray">未绑定</a-tag>
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
            <a-button
              type="text"
              size="small"
              @click="openActivationCode(record)"
            >
              <template #icon><icon-key /></template>
              激活码
            </a-button>
            <a-button type="text" size="small" @click="openBindModal(record)">
              <template #icon><icon-link /></template>
              绑定
            </a-button>
            <a-popconfirm
              :content="`确定要删除该机器吗?`"
              position="left"
              @ok="deleteMachine(record)"
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

    <!-- 机器编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑机器' : '添加机器'"
      :width="600"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-form-item label="机器编号" field="machine_code">
          <a-input
            v-model="formData.machine_code"
            placeholder="请输入机器编号"
            :disabled="isEdit"
          />
        </a-form-item>
        <a-form-item label="机器名称" field="machine_name">
          <a-input
            v-model="formData.machine_name"
            placeholder="请输入机器名称"
          />
        </a-form-item>
        <a-form-item label="机器类型" field="machine_type">
          <a-select
            v-model="formData.machine_type"
            placeholder="请选择机器类型"
          >
            <a-option :value="1">PC端</a-option>
            <a-option :value="2">移动端</a-option>
            <a-option :value="3">平板</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="操作系统" field="os_type">
          <a-select v-model="formData.os_type" placeholder="请选择操作系统">
            <a-option :value="1">Windows</a-option>
            <a-option :value="2">macOS</a-option>
            <a-option :value="3">Linux</a-option>
            <a-option :value="4">Android</a-option>
            <a-option :value="5">iOS</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="设备标识" field="device_id">
          <a-input v-model="formData.device_id" placeholder="请输入设备标识" />
        </a-form-item>
        <a-form-item label="备注" field="remark">
          <a-textarea v-model="formData.remark" placeholder="请输入备注" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 机器详情弹窗 -->
    <a-modal
      v-model:visible="detailVisible"
      :title="`机器详情 - ${currentRecord?.machine_name}`"
      :width="900"
      :unmount-on-close="true"
    >
      <a-descriptions :column="2" bordered>
        <a-descriptions-item label="机器编号">
          {{ currentRecord?.machine_code }}
        </a-descriptions-item>
        <a-descriptions-item label="机器名称">
          {{ currentRecord?.machine_name }}
        </a-descriptions-item>
        <a-descriptions-item label="机器类型">
          {{
            currentRecord?.machine_type === 1
              ? 'PC端'
              : currentRecord?.machine_type === 2
              ? '移动端'
              : '平板'
          }}
        </a-descriptions-item>
        <a-descriptions-item label="操作系统">
          {{
            currentRecord?.os_type === 1
              ? 'Windows'
              : currentRecord?.os_type === 2
              ? 'macOS'
              : currentRecord?.os_type === 3
              ? 'Linux'
              : currentRecord?.os_type === 4
              ? 'Android'
              : 'iOS'
          }}
        </a-descriptions-item>
        <a-descriptions-item label="绑定状态">
          <a-tag :color="currentRecord?.bind_order_id ? 'green' : 'orange'">
            {{ currentRecord?.bind_order_id ? '已绑定' : '未绑定' }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="机器状态">
          <a-tag :color="getStatusColor(currentRecord?.machine_status)">
            {{ getStatusText(currentRecord?.machine_status) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="绑定订单" :span="2">
          <a-link
            v-if="currentRecord?.order_no"
            @click="goToOrder(currentRecord?.bind_order_id)"
          >
            {{ currentRecord?.order_no }}
          </a-link>
          <span v-else>-</span>
        </a-descriptions-item>
      </a-descriptions>

      <a-divider>订单记录</a-divider>
      <a-table
        :data="detailOrderList"
        :loading="detailLoading"
        :pagination="false"
        :bordered="false"
        size="small"
      >
        <a-table-column title="订单编号" data-index="order_no" width="180">
          <template #cell="{ record }">
            <a-link @click="goToOrder(record.id)">{{ record.order_no }}</a-link>
          </template>
        </a-table-column>
        <a-table-column title="商品名称" data-index="product_name" ellipsis />
        <a-table-column
          title="订单金额"
          data-index="total_amount"
          width="100"
        />
        <a-table-column title="订单状态" data-index="status" width="100">
          <template #cell="{ record }">
            <a-tag
              :color="
                record.status === 1
                  ? 'green'
                  : record.status === 2
                  ? 'blue'
                  : 'gray'
              "
            >
              {{
                record.status === 1
                  ? '已支付'
                  : record.status === 2
                  ? '已完成'
                  : '未支付'
              }}
            </a-tag>
          </template>
        </a-table-column>
        <a-table-column title="下单时间" data-index="created_at" width="160" />
        <a-table-empty v-if="detailOrderList.length === 0" />
      </a-table>
      <div v-if="detailOrderList.length > 0" class="view-more">
        <a-link @click="goToOrder()">查看全部订单 →</a-link>
      </div>

      <a-divider>收入记录</a-divider>
      <a-table
        :data="detailIncomeList"
        :loading="detailLoading"
        :pagination="false"
        :bordered="false"
        size="small"
      >
        <a-table-column title="收入类型" data-index="income_type" width="100">
          <template #cell="{ record }">
            <a-tag>{{ record.income_type === 1 ? '订单收入' : '其他' }}</a-tag>
          </template>
        </a-table-column>
        <a-table-column title="金额" data-index="amount" width="100" />
        <a-table-column title="来源" data-index="source" ellipsis />
        <a-table-column title="状态" data-index="status" width="80">
          <template #cell="{ record }">
            <a-tag :color="record.status === 1 ? 'green' : 'orange'">
              {{ record.status === 1 ? '已到账' : '待确认' }}
            </a-tag>
          </template>
        </a-table-column>
        <a-table-column title="时间" data-index="created_at" width="160" />
        <a-table-empty v-if="detailIncomeList.length === 0" />
      </a-table>
      <div v-if="detailIncomeList.length > 0" class="view-more">
        <a-link @click="goToIncome()">查看全部收入 →</a-link>
      </div>

      <template #footer>
        <a-button size="small" @click="detailVisible = false">关闭</a-button>
      </template>
    </a-modal>

    <!-- 绑定订单弹窗 -->
    <a-modal
      v-model:visible="bindVisible"
      title="绑定订单"
      :width="600"
      :unmount-on-close="true"
      @ok="handleBind"
    >
      <a-descriptions :column="2" bordered size="small">
        <a-descriptions-item label="机器编号">
          {{ bindForm.machine_code }}
        </a-descriptions-item>
        <a-descriptions-item label="机器名称">
          {{ bindForm.machine_name }}
        </a-descriptions-item>
        <a-descriptions-item label="当前状态">
          <a-tag :color="bindForm.bind_order_id ? 'green' : 'orange'">
            {{ bindForm.bind_order_id ? '已绑定' : '未绑定' }}
          </a-tag>
        </a-descriptions-item>
      </a-descriptions>
      <a-divider>选择订单</a-divider>
      <a-form layout="vertical">
        <a-form-item label="绑定订单">
          <a-select
            v-model="bindForm.order_id"
            :searchable="true"
            placeholder="请搜索选择订单"
            :filter-option="false"
            @search="handleOrderSearch"
          >
            <a-option
              v-for="item in orderList"
              :key="item.id"
              :value="item.id"
              :label="`${item.order_no} - ¥${item.total_amount}`"
            />
          </a-select>
        </a-form-item>
        <a-form-item label="绑定说明">
          <a-textarea v-model="bindForm.remark" placeholder="请输入绑定说明" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 续费弹窗 -->
    <a-modal
      v-model:visible="renewVisible"
      title="机器续费"
      :width="500"
      :unmount-on-close="true"
      @ok="handleRenewConfirm"
    >
      <a-descriptions :column="2" bordered size="small">
        <a-descriptions-item label="机器编号">
          {{ renewForm.machine_code }}
        </a-descriptions-item>
        <a-descriptions-item label="机器名称">
          {{ renewForm.machine_name }}
        </a-descriptions-item>
        <a-descriptions-item label="当前到期时间" :span="2">
          {{ renewForm.current_expire }}
        </a-descriptions-item>
      </a-descriptions>
      <a-divider />
      <a-form :model="renewForm" layout="vertical">
        <a-form-item label="续费天数">
          <a-radio-group v-model="renewForm.renew_days">
            <a-radio :value="30">30天 ¥99</a-radio>
            <a-radio :value="90">90天 ¥269</a-radio>
            <a-radio :value="180">180天 ¥499</a-radio>
            <a-radio :value="365">365天 ¥899</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="支付方式">
          <a-select v-model="renewForm.payment_method">
            <a-option value="wechat">微信支付</a-option>
            <a-option value="alipay">支付宝</a-option>
            <a-option value="bank">银行卡</a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 试用期提醒弹窗 -->
    <a-modal
      v-model:visible="trialVisible"
      title="试用期提醒"
      :width="600"
      :unmount-on-close="true"
    >
      <a-alert type="warning" style="margin-bottom: 16px">
        以下机器试用期即将到期，请及时处理
      </a-alert>
      <a-table :data="trialList" :pagination="false">
        <a-table-column title="机器编号" data-index="machine_code" />
        <a-table-column title="机器名称" data-index="machine_name" />
        <a-table-column title="剩余天数" data-index="trial_days">
          <template #cell="{ record }">
            <a-tag :color="record.trial_days <= 3 ? 'red' : 'orange'">
              {{ record.trial_days }}天
            </a-tag>
          </template>
        </a-table-column>
        <a-table-column title="操作">
          <template #cell="{ record }">
            <a-button type="primary" size="small" @click="handleRenew(record)">
              立即续费
            </a-button>
            <a-button
              size="small"
              style="margin-left: 8px"
              @click="handleSendReminder(record)"
            >
              发送提醒
            </a-button>
          </template>
        </a-table-column>
      </a-table>
    </a-modal>

    <!-- 激活码管理弹窗 -->
    <ActivationCodeManager
      v-model:visible="activationVisible"
      :bind-type="2"
      :bind-id="activationRecord?.id"
      :record-name="activationRecord?.machine_code"
    />
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted, computed } from 'vue';
  import { useRouter, useRoute } from 'vue-router';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';
  import ActivationCodeManager from '@/components/activation-code-manager/index.vue';

  const router = useRouter();
  const route = useRoute();

  const tableRef = ref();
  const loading = ref(false);

  // 表格数据总数
  const tableTotal = computed(() => tableRef.value?.tableData?.length || 0);

  // 刷新
  const handleRefresh = () => {
    tableRef.value?.search();
  };
  const modalVisible = ref(false);
  const bindVisible = ref(false);
  const detailVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();
  const orderList = ref<any[]>([]);
  const currentRecord = ref<any>({});

  // 详情相关数据
  const detailOrderList = ref<any[]>([]);
  const detailIncomeList = ref<any[]>([]);
  const detailLoading = ref(false);

  // 激活码相关
  const activationVisible = ref(false);
  const activationRecord = ref<any>({});

  const stats = reactive({
    total: 0,
    bound: 0,
    trial: 0,
    expired: 0,
  });

  const formData = reactive({
    id: 0,
    machine_code: '',
    machine_name: '',
    machine_type: 1,
    os_type: 1,
    device_id: '',
    remark: '',
  });

  const bindForm = reactive({
    id: 0,
    machine_code: '',
    machine_name: '',
    bind_order_id: 0,
    order_id: 0,
    remark: '',
  });

  const rules = {
    machine_code: [{ required: true, message: '请输入机器编号' }],
    machine_name: [{ required: true, message: '请输入机器名称' }],
    machine_type: [{ required: true, message: '请选择机器类型' }],
  };

  const columns = [
    { title: '机器编号', dataIndex: 'machine_code', width: 140 },
    { title: '机器名称', dataIndex: 'machine_name', width: 140 },
    { title: '机器类型', dataIndex: 'machine_type', width: 100 },
    { title: '操作系统', dataIndex: 'os_type', width: 100 },
    {
      title: '绑定状态',
      dataIndex: 'bind_status',
      width: 100,
      slotName: 'bind_status',
    },
    { title: '绑定订单', dataIndex: 'order_no', width: 180 },
    {
      title: '到期状态',
      dataIndex: 'expire_status',
      width: 140,
      slotName: 'expire_status',
    },
    {
      title: '机器状态',
      dataIndex: 'machine_status',
      width: 100,
      slotName: 'machine_status',
    },
    { title: '操作时间', dataIndex: 'updated_at', width: 180 },
    { title: '操作', dataIndex: 'action', width: 180, slotName: 'action' },
  ];

  const generateFormModel = () => ({
    machine_code: null,
    machine_status: '',
    bind_status: '',
  });

  const baseSearchRules = ref([
    { field: 'machine_code', label: '机器编号', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'machine_status',
      label: '机器状态',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'machine_status' },
    },
    {
      field: 'bind_status',
      label: '绑定状态',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'bind_status' },
    },
  ]);

  const formModel = ref(generateFormModel());

  const getDataList = (data: any) => {
    return request('/api/business/machine/list', data);
  };

  const fetchStats = () => {
    request('/api/business/machine/stats').then((res: any) => {
      Object.assign(stats, res.data);
    });
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getStatusColor = (status: number) => {
    const colors = ['gray', 'green', 'orange', 'red'];
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = ['未使用', '使用中', '试用中', '已过期'];
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
        machine_code: '',
        machine_name: '',
        machine_type: 1,
        os_type: 1,
        device_id: '',
        remark: '',
      });
    }
    modalVisible.value = true;
  };

  // 加载订单列表
  const loadOrderList = (keyword = '') => {
    request('/api/business/order/simpleList', { keyword }).then((res: any) => {
      orderList.value = res.data || [];
    });
  };

  const openBindModal = (record: any) => {
    Object.assign(bindForm, {
      id: record.id,
      machine_code: record.machine_code,
      machine_name: record.machine_name,
      bind_order_id: record.bind_order_id,
      order_id: record.bind_order_id || 0,
      remark: '',
    });
    if (record.bind_order_id) {
      loadOrderList(record.bind_order_id);
    }
    bindVisible.value = true;
  };

  const handleOrderSearch = (value: string) => {
    loadOrderList(value);
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    request('/api/business/machine/save', formData).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      modalVisible.value = false;
      handleSubmit();
      fetchStats();
    });
  };

  const handleBind = () => {
    if (!bindForm.order_id) {
      Message.warning('请选择要绑定的订单');
      return;
    }
    request('/api/business/machine/bind', {
      id: bindForm.id,
      order_id: bindForm.order_id,
      remark: bindForm.remark,
    }).then(() => {
      Message.success('绑定成功');
      bindVisible.value = false;
      handleSubmit();
      fetchStats();
    });
  };

  const deleteMachine = (record: any) => {
    request('/api/business/machine/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      handleSubmit();
      fetchStats();
    });
  };

  // 续费相关
  const renewVisible = ref(false);
  const renewForm = reactive({
    id: 0,
    machine_code: '',
    machine_name: '',
    current_expire: '',
    renew_days: 30,
    renew_amount: 0,
    payment_method: 'wechat',
  });

  const handleRenew = (record: any) => {
    renewForm.id = record.id;
    renewForm.machine_code = record.machine_code;
    renewForm.machine_name = record.machine_name;
    renewForm.current_expire = record.expire_time || '未设置';
    renewForm.renew_days = 30;
    renewForm.renew_amount = 99;
    renewVisible.value = true;
  };

  const handleRenewConfirm = () => {
    request('/api/business/machine/renew', {
      id: renewForm.id,
      renew_days: renewForm.renew_days,
      renew_amount: renewForm.renew_amount,
      payment_method: renewForm.payment_method,
    }).then(() => {
      Message.success('续费成功');
      renewVisible.value = false;
      handleSubmit();
      fetchStats();
    });
  };

  // 试用期提醒相关
  const trialVisible = ref(false);
  const trialList = ref<any[]>([]);

  const handleTrialReminder = () => {
    // 获取试用期即将到期的机器
    trialList.value = [
      {
        id: 1,
        machine_code: 'MC001',
        machine_name: '测试机器1',
        trial_days: 3,
      },
      {
        id: 2,
        machine_code: 'MC002',
        machine_name: '测试机器2',
        trial_days: 5,
      },
      {
        id: 3,
        machine_code: 'MC003',
        machine_name: '测试机器3',
        trial_days: 7,
      },
    ];
    trialVisible.value = true;
  };

  const handleSendReminder = (record: any) => {
    Message.success(`已向机器 ${record.machine_code} 发送续费提醒`);
  };

  // 查看机器详情
  const viewDetail = async (record: any) => {
    currentRecord.value = record;
    detailVisible.value = true;
    detailLoading.value = true;

    // 加载绑定的订单
    try {
      const orderRes = await request('/api/business/order/list', {
        machine_id: record.id,
        page: 1,
        pageSize: 5,
      });
      detailOrderList.value = orderRes.data?.list || [];
    } catch (e) {
      detailOrderList.value = [];
    }

    // 加载收入记录
    try {
      const incomeRes = await request('/api/business/income/list', {
        machine_id: record.id,
        page: 1,
        pageSize: 5,
      });
      detailIncomeList.value = incomeRes.data?.list || [];
    } catch (e) {
      detailIncomeList.value = [];
    }

    detailLoading.value = false;
  };

  // 跳转到订单管理
  const goToOrder = (orderId?: number) => {
    router.push({
      path: '/business/order',
      query: orderId ? { orderId } : { machineId: currentRecord.value.id },
    });
  };

  // 跳转到收入管理
  const goToIncome = () => {
    router.push({
      path: '/business/income',
      query: { machineId: currentRecord.value.id },
    });
  };

  const handleExport = () => {
    Message.success('正在导出机器数据...');
    request('/api/business/machine/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `机器数据_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  // ========== 激活码管理功能 ==========

  // 打开激活码管理弹窗
  const openActivationCode = (record: any) => {
    activationRecord.value = record;
    activationVisible.value = true;
  };

  onMounted(async () => {
    // 处理路由参数
    const { machineId } = route.query;
    if (machineId) {
      // 通过路由参数查询机器详情
      try {
        const res = await request('/api/business/machine/list', {
          id: machineId,
        });
        const { data } = res;
        if (data?.list?.length) {
          const [firstItem] = data.list;
          currentRecord.value = firstItem;
          detailVisible.value = true;
        }
      } catch (e) {
        console.error('获取机器详情失败', e);
      }
      // 清除路由参数
      router.replace({ path: '/business/machine' });
    }

    fetchStats();
  });
</script>

<style lang="less" scoped>
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
      border-radius: 8px;
      display: flex;
      align-items: center;
      justify-content: center;
      font-size: 24px;
      color: #fff;

      &.blue {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      }
      &.green {
        background: linear-gradient(135deg, #43e97b 0%, #38f9d7 100%);
      }
      &.orange {
        background: linear-gradient(135deg, #fa709a 0%, #fee140 100%);
      }
      &.red {
        background: linear-gradient(135deg, #f093fb 0%, #f5576c 100%);
      }
    }

    .stat-info {
      .stat-label {
        font-size: 14px;
        color: var(--color-text-2);
      }
      .stat-value {
        font-size: 24px;
        font-weight: 600;
      }
    }
  }

  .table-card {
    margin-top: 16px;
  }

  .view-more {
    text-align: center;
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid var(--color-border-1);
  }
</style>
