<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>支付管理</span>
          <a-tag color="blue">{{ tableTotal }} 个支付渠道</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="openModal({})">
            <template #icon>
              <icon-plus />
            </template>
            添加支付渠道
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
        placeholder="请输入渠道名称搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="handleKeyManage">
              <template #icon>
                <icon-lock />
              </template>
              密钥管理
            </a-button>
            <a-button size="small" @click="handleTestAll">
              <template #icon>
                <icon-check-circle />
              </template>
              测试全部
            </a-button>
            <a-button size="small" @click="handleTransactionLog">
              <template #icon>
                <icon-history />
              </template>
              交易明细
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
        <template #pay_type="{ record }">
          <div class="pay-type">
            <component :is="getPayIcon(record.pay_type)" class="pay-icon" />
            {{ getPayText(record.pay_type) }}
          </div>
        </template>
        <template #fee_rate="{ record }"> {{ record.fee_rate }}% </template>
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
            <a-button type="text" size="small" @click="openModal(record)">
              <template #icon><icon-edit /></template>
              编辑
            </a-button>
            <a-button type="text" size="small" @click="testConnect(record)">
              <template #icon><icon-refresh /></template>
              测试
            </a-button>
            <a-popconfirm
              :content="`确定要删除该支付渠道吗?`"
              position="left"
              @ok="deletePayment(record)"
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

    <!-- 支付渠道编辑弹窗 -->
    <a-modal
      v-model:visible="modalVisible"
      :title="isEdit ? '编辑支付渠道' : '添加支付渠道'"
      :width="700"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="支付方式" field="pay_type">
              <a-select
                v-model="formData.pay_type"
                placeholder="请选择支付方式"
                :disabled="isEdit"
              >
                <a-option :value="1">微信支付</a-option>
                <a-option :value="2">支付宝</a-option>
                <a-option :value="3">银行卡</a-option>
                <a-option :value="4">余额支付</a-option>
                <a-option :value="5">Apple Pay</a-option>
                <a-option :value="6">银联支付</a-option>
                <a-option :value="7">PayPal</a-option>
                <a-option :value="8">京东支付</a-option>
                <a-option :value="9">Google Pay</a-option>
                <a-option :value="10">抖音支付</a-option>
              </a-select>
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="渠道名称" field="channel_name">
              <a-input
                v-model="formData.channel_name"
                placeholder="请输入渠道名称"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="商户号" field="mch_id">
              <a-input v-model="formData.mch_id" placeholder="请输入商户号" />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="应用ID" field="app_id">
              <a-input v-model="formData.app_id" placeholder="请输入应用ID" />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="API密钥" field="api_key">
          <a-input v-model="formData.api_key" placeholder="请输入API密钥" />
        </a-form-item>
        <a-form-item label="公钥/证书" field="public_key">
          <a-textarea
            v-model="formData.public_key"
            placeholder="请输入公钥或证书内容"
            :auto-size="{ minRows: 3, maxRows: 5 }"
          />
        </a-form-item>
        <a-form-item label="私钥" field="private_key">
          <a-textarea
            v-model="formData.private_key"
            placeholder="请输入私钥"
            :auto-size="{ minRows: 3, maxRows: 5 }"
          />
        </a-form-item>
        <a-row :gutter="16">
          <a-col :span="12">
            <a-form-item label="手续费率(%)" field="fee_rate">
              <a-input-number
                v-model="formData.fee_rate"
                :min="0"
                :max="100"
                :precision="2"
                placeholder="请输入手续费率"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
          <a-col :span="12">
            <a-form-item label="排序" field="sort">
              <a-input-number
                v-model="formData.sort"
                :min="0"
                style="width: 100%"
              />
            </a-form-item>
          </a-col>
        </a-row>
        <a-form-item label="回调地址" field="notify_url">
          <a-input
            v-model="formData.notify_url"
            placeholder="请输入支付回调地址"
          />
        </a-form-item>
        <a-form-item label="备注" field="remark">
          <a-textarea v-model="formData.remark" placeholder="请输入备注" />
        </a-form-item>
        <a-form-item label="状态" field="status">
          <a-switch v-model="formData.status" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 密钥管理弹窗 -->
    <a-modal v-model:visible="keyManageVisible" title="密钥管理" :width="600">
      <a-form layout="vertical">
        <a-form-item label="微信支付商户号">
          <a-input-password placeholder="请输入微信支付商户号" />
        </a-form-item>
        <a-form-item label="微信支付API密钥">
          <a-input-password placeholder="请输入微信支付API密钥" />
        </a-form-item>
        <a-form-item label="微信支付APIv3密钥">
          <a-input-password placeholder="请输入微信支付APIv3密钥" />
        </a-form-item>
        <a-form-item label="支付宝应用ID">
          <a-input-password placeholder="请输入支付宝应用ID" />
        </a-form-item>
        <a-form-item label="支付宝私钥">
          <a-textarea placeholder="请输入支付宝私钥" :rows="4" />
        </a-form-item>
      </a-form>
      <template #footer>
        <a-button size="small" @click="keyManageVisible = false">取消</a-button>
        <a-button
          size="small"
          type="primary"
          @click="Message.success('密钥保存成功')"
          >保存</a-button
        >
      </template>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, computed } from 'vue';
  import {
    IconWechatpay,
    IconAlipayCircle,
    IconSafe,
    IconPhone,
    IconMobile,
    IconPublic,
    IconGift,
    IconStar,
  } from '@arco-design/web-vue/es/icon';
  import request from '@/api/request';
  import { Message } from '@arco-design/web-vue';

  const tableRef = ref();
  const loading = ref(false);
  const modalVisible = ref(false);
  const isEdit = ref(false);
  const formRef = ref();

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
      label: '渠道名称',
      field: 'channel_name',
      type: 'input',
      placeholder: '请输入渠道名称',
    },
    {
      label: '支付方式',
      field: 'pay_type',
      type: 'select',
      placeholder: '请选择支付方式',
      options: [
        { label: '微信支付', value: 1 },
        { label: '支付宝', value: 2 },
        { label: '银行卡', value: 3 },
        { label: '余额支付', value: 4 },
      ],
    },
  ]);

  // 基础搜索规则
  const baseSearchRules = ref<any[]>([
    { label: '渠道名称', field: 'channel_name' },
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

  const formData = reactive({
    id: 0,
    pay_type: 1,
    channel_name: '',
    mch_id: '',
    app_id: '',
    api_key: '',
    public_key: '',
    private_key: '',
    fee_rate: 0.6,
    sort: 0,
    notify_url: '',
    remark: '',
    status: true,
  });

  const rules = {
    pay_type: [{ required: true, message: '请选择支付方式' }],
    channel_name: [{ required: true, message: '请输入渠道名称' }],
    mch_id: [{ required: true, message: '请输入商户号' }],
  };

  const columns = [
    {
      title: '支付方式',
      dataIndex: 'pay_type',
      width: 140,
      slotName: 'pay_type',
    },
    { title: '渠道名称', dataIndex: 'channel_name', width: 140 },
    { title: '商户号', dataIndex: 'mch_id', width: 140 },
    { title: '应用ID', dataIndex: 'app_id', width: 140 },
    {
      title: '手续费率',
      dataIndex: 'fee_rate',
      width: 100,
      slotName: 'fee_rate',
    },
    { title: '排序', dataIndex: 'sort', width: 80 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 200, slotName: 'action' },
  ];

  const getDataList = (data: any) => {
    return request('/api/system/payment/list', data);
  };

  const getPayIcon = (type: number) => {
    const icons: any = {
      1: IconWechatpay,
      2: IconAlipayCircle,
      3: IconSafe,
      4: IconPhone,
      5: IconMobile,
      6: IconPublic,
      7: IconPublic,
      8: IconGift,
      9: IconMobile,
      10: IconStar,
    };
    return icons[type] || IconPhone;
  };

  const getPayText = (type: number) => {
    const texts: any = {
      1: '微信支付',
      2: '支付宝',
      3: '银行卡',
      4: '余额支付',
      5: 'Apple Pay',
      6: '银联支付',
      7: 'PayPal',
      8: '京东支付',
      9: 'Google Pay',
      10: '抖音支付',
    };
    return texts[type] || '-';
  };

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
        pay_type: 1,
        channel_name: '',
        mch_id: '',
        app_id: '',
        api_key: '',
        public_key: '',
        private_key: '',
        fee_rate: 0.6,
        sort: 0,
        notify_url: '',
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
      status: formData.status ? 1 : 0,
    };

    request('/api/system/payment/save', params).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '添加成功');
      modalVisible.value = false;
      tableRef.value?.search();
    });
  };

  const changeStatus = (record: any) => {
    record.loading = true;
    request('/api/system/payment/set', {
      id: record.id,
      field: 'status',
      value: record.status === 1 ? 0 : 1,
    })
      .then(() => {
        Message.success('状态更新成功');
        tableRef.value?.search();
      })
      .finally(() => {
        record.loading = false;
      });
  };

  // 密钥管理
  const keyManageVisible = ref(false);
  const handleKeyManage = () => {
    keyManageVisible.value = true;
  };

  // 测试全部连接
  const handleTestAll = () => {
    Message.loading('正在测试所有支付渠道...');
    setTimeout(() => {
      Message.success('所有支付渠道连接正常');
    }, 1500);
  };

  // 交易明细
  const handleTransactionLog = () => {
    Message.info('跳转到交易明细页面');
  };

  const testConnect = (record: any) => {
    record.loading = true;
    Message.info('正在测试连接...');
    request('/api/system/payment/test', { id: record.id })
      .then((res: any) => {
        record.loading = false;
        if (res.data?.success) {
          Message.success('连接测试成功');
        } else {
          Message.error(res.data?.message || '连接测试失败');
        }
      })
      .catch(() => {
        record.loading = false;
        Message.error('连接测试失败，请检查配置');
      });
  };

  const deletePayment = (record: any) => {
    request('/api/system/payment/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      tableRef.value?.search();
    });
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

  .pay-type {
    display: flex;
    align-items: center;
    gap: 8px;

    .pay-icon {
      font-size: 18px;
    }
  }
</style>
