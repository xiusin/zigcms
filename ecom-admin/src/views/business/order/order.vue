<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>订单管理</span>
          <a-tag color="blue">{{ tableTotal }} 个订单</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="handleExport">
            <template #icon>
              <icon-download />
            </template>
            导出订单
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
        placeholder="请输入订单号、商品名称搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-button size="small" @click="handleBatchAction">
              <template #icon>
                <icon-settings />
              </template>
              批量操作
            </a-button>
            <a-radio-group v-model="orderType" type="button" size="small">
              <a-radio value="all">全部</a-radio>
              <a-radio value="today">今日</a-radio>
              <a-radio value="week">本周</a-radio>
              <a-radio value="month">本月</a-radio>
            </a-radio-group>
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
        <template #order_no="{ record }">
          <a-link class="link-text" @click="viewDetail(record)">{{
            record.order_no
          }}</a-link>
        </template>
        <template #pay_type="{ record }">
          <a-tag :color="getPayTypeColor(record.pay_type)">
            {{ getPayTypeText(record.pay_type) }}
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
            <a-button
              type="text"
              size="small"
              @click="openActivationCode(record)"
            >
              <template #icon><icon-key /></template>
              激活码
            </a-button>
            <a-dropdown>
              <a-button type="text" size="small">
                更多
                <template #icon><icon-down /></template>
              </a-button>
              <template #content>
                <a-doption @click="handleProcess(record)">处理订单</a-doption>
                <a-doption @click="handleRemark(record)">备注</a-doption>
                <a-doption @click="handlePrint(record)">打印</a-doption>
                <a-doption
                  v-if="record.status === 3"
                  @click="handleLogistics(record)"
                >
                  物流
                </a-doption>
                <a-doption
                  v-if="record.status === 2"
                  @click="handleRefund(record)"
                >
                  退款
                </a-doption>
                <a-doption @click="handleExportOne(record)">导出</a-doption>
              </template>
            </a-dropdown>
          </div>
        </template>
      </base-table>
    </a-card>

    <!-- 订单详情弹窗 -->
    <a-drawer
      v-model:visible="detailVisible"
      :title="`订单详情 - ${currentRecord?.order_no}`"
      :width="720"
      :unmount-on-close="true"
    >
      <a-descriptions :column="2" bordered>
        <a-descriptions-item label="订单编号" :span="2">
          {{ currentRecord?.order_no }}
        </a-descriptions-item>
        <a-descriptions-item label="商品名称">
          {{ currentRecord?.product_name }}
        </a-descriptions-item>
        <a-descriptions-item label="商品规格">
          {{ currentRecord?.sku_info || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="购买数量">
          {{ currentRecord?.num }}
        </a-descriptions-item>
        <a-descriptions-item label="商品单价">
          ¥{{ currentRecord?.price }}
        </a-descriptions-item>
        <a-descriptions-item label="订单金额" :span="2">
          <span class="total-price">¥{{ currentRecord?.total_amount }}</span>
        </a-descriptions-item>
        <a-descriptions-item label="会员名称">
          <a-link @click="goToMember(currentRecord)">
            {{ currentRecord?.member_name }}
          </a-link>
        </a-descriptions-item>
        <a-descriptions-item label="会员手机">
          <a-link @click="goToMember(currentRecord)">
            {{ currentRecord?.member_phone }}
          </a-link>
        </a-descriptions-item>
        <a-descriptions-item label="收货地址" :span="2">
          {{ currentRecord?.address }}
        </a-descriptions-item>
        <a-descriptions-item label="支付方式">
          <a-tag :color="getPayTypeColor(currentRecord?.pay_type)">
            {{ getPayTypeText(currentRecord?.pay_type) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="订单状态">
          <a-tag :color="getStatusColor(currentRecord?.status)">
            {{ getStatusText(currentRecord?.status) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="支付时间">
          {{ currentRecord?.pay_time || '-' }}
        </a-descriptions-item>
        <a-descriptions-item label="下单时间">
          {{ currentRecord?.created_at }}
        </a-descriptions-item>
        <a-descriptions-item label="备注" :span="2">
          {{ currentRecord?.remark || '无' }}
        </a-descriptions-item>
      </a-descriptions>

      <template #footer>
        <a-space>
          <a-button size="small" @click="detailVisible = false">关闭</a-button>
          <a-button size="small" @click="handleRemark(currentRecord)">
            <icon-edit />备注
          </a-button>
          <a-button size="small" @click="handlePrint(currentRecord)">
            <icon-printer />打印
          </a-button>
          <a-button
            v-if="currentRecord?.status === 3"
            size="small"
            @click="handleLogistics(currentRecord)"
          >
            <icon-truck />物流
          </a-button>
          <a-button
            size="small"
            type="primary"
            @click="handleProcess(currentRecord)"
          >
            处理订单
          </a-button>
        </a-space>
      </template>
    </a-drawer>

    <!-- 退款弹窗 -->
    <a-modal
      v-model:visible="refundVisible"
      title="退款处理"
      :width="500"
      :unmount-on-close="true"
      @ok="handleRefundConfirm"
    >
      <a-descriptions :column="2" bordered size="small">
        <a-descriptions-item label="订单编号">
          {{ refundRecord.order_no }}
        </a-descriptions-item>
        <a-descriptions-item label="订单金额">
          ¥{{ refundRecord.total_amount }}
        </a-descriptions-item>
      </a-descriptions>
      <a-divider />
      <a-form :model="refundForm" layout="vertical">
        <a-form-item label="退款金额">
          <a-input-number
            v-model="refundForm.refund_amount"
            :min="0"
            :max="refundRecord.total_amount"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="退款原因">
          <a-select
            v-model="refundForm.refund_reason"
            placeholder="请选择退款原因"
          >
            <a-option value="质量问题">质量问题</a-option>
            <a-option value="商品不符">商品不符</a-option>
            <a-option value="用户申请">用户申请</a-option>
            <a-option value="其他原因">其他原因</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea
            v-model="refundForm.refund_remark"
            placeholder="请输入退款备注"
            :rows="3"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 备注弹窗 -->
    <a-modal
      v-model:visible="remarkVisible"
      title="订单备注"
      :width="500"
      :unmount-on-close="true"
      @ok="handleRemarkSave"
    >
      <a-form layout="vertical">
        <a-form-item label="备注内容">
          <a-textarea
            v-model="remarkForm.remark"
            placeholder="请输入订单备注"
            :rows="4"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 物流跟踪弹窗 -->
    <a-modal
      v-model:visible="logisticsVisible"
      title="物流跟踪"
      :width="600"
      :unmount-on-close="true"
    >
      <a-descriptions :column="2" bordered size="small">
        <a-descriptions-item label="订单编号">
          {{ logisticsRecord.order_no }}
        </a-descriptions-item>
        <a-descriptions-item label="物流公司">顺丰速运</a-descriptions-item>
        <a-descriptions-item label="物流单号">
          SF1234567890
        </a-descriptions-item>
      </a-descriptions>
      <a-divider>物流轨迹</a-divider>
      <a-timeline>
        <a-timeline-item
          v-for="(item, index) in logisticsTimeline"
          :key="index"
          :color="index === 0 ? 'green' : 'gray'"
        >
          <div class="logistics-item">
            <div class="logistics-status">{{ item.status }}</div>
            <div class="logistics-desc">{{ item.desc }}</div>
            <div class="logistics-time">{{ item.time }}</div>
          </div>
        </a-timeline-item>
      </a-timeline>
    </a-modal>

    <!-- 激活码管理弹窗 -->
    <ActivationCodeManager
      v-model:visible="activationVisible"
      :bind-type="3"
      :bind-id="activationRecord?.id"
      :record-name="activationRecord?.order_no"
    />
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, onMounted, computed } from 'vue';
  import { useRouter, useRoute } from 'vue-router';
  import request from '@/api/request';
  import { Message, Modal } from '@arco-design/web-vue';
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
  const detailVisible = ref(false);
  const batchVisible = ref(false);
  const selectedKeys = ref<string[]>([]);
  const currentRecord = ref<any>({});
  const orderType = ref('all');

  // 激活码相关
  const activationVisible = ref(false);
  const activationRecord = ref<any>({});

  const columns = [
    {
      title: '订单编号',
      dataIndex: 'order_no',
      width: 200,
      slotName: 'order_no',
    },
    { title: '商品名称', dataIndex: 'product_name', ellipsis: true },
    { title: '商品规格', dataIndex: 'sku_info', width: 120 },
    { title: '数量', dataIndex: 'num', width: 80 },
    { title: '单价', dataIndex: 'price', width: 100 },
    { title: '订单金额', dataIndex: 'total_amount', width: 120 },
    { title: '会员名称', dataIndex: 'member_name', width: 100 },
    {
      title: '支付方式',
      dataIndex: 'pay_type',
      width: 100,
      slotName: 'pay_type',
    },
    { title: '订单状态', dataIndex: 'status', width: 100, slotName: 'status' },
    { title: '下单时间', dataIndex: 'created_at', width: 180 },
    { title: '操作', dataIndex: 'action', width: 120, slotName: 'action' },
  ];

  const generateFormModel = () => ({
    order_no: null,
    product_name: null,
    member_name: null,
    status: '',
    pay_type: '',
  });

  const baseSearchRules = ref([
    { field: 'order_no', label: '订单号', value: null },
    { field: 'product_name', label: '商品', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'status',
      label: '订单状态',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'order_status' },
    },
    {
      field: 'pay_type',
      label: '支付方式',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'pay_type' },
    },
  ]);

  const formModel = ref(generateFormModel());

  // 页面加载时检查路由参数
  onMounted(() => {
    const { orderId } = route.query;
    const { memberId } = route.query;
    const { machineId } = route.query;

    if (orderId) {
      // 通过路由参数打开订单详情
      request('/api/business/order/list', { id: orderId }).then((res: any) => {
        const { data } = res;
        if (data?.list?.length) {
          const [firstItem] = data.list;
          currentRecord.value = firstItem;
          detailVisible.value = true;
          // 清除路由参数，避免刷新后重复打开
          router.replace({ path: '/business/order' });
        }
      });
    } else if (memberId) {
      // 通过路由参数筛选会员订单
      formModel.value.member_id = Number(memberId);
      tableRef.value?.search();
      // 清除路由参数
      router.replace({ path: '/business/order' });
    } else if (machineId) {
      // 通过路由参数筛选机器订单
      formModel.value.machine_id = Number(machineId);
      tableRef.value?.search();
      // 清除路由参数
      router.replace({ path: '/business/order' });
    }
  });

  const getDataList = (data: any) => {
    return request('/api/business/order/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getPayTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'purple'];
    return colors[type] || 'default';
  };

  const getPayTypeText = (type: number) => {
    const texts = ['', '微信支付', '支付宝', '银行卡', '余额支付'];
    return texts[type] || '-';
  };

  const getStatusColor = (status: number) => {
    const colors = ['red', 'orange', 'green', 'gray', 'blue'];
    return colors[status] || 'gray';
  };

  const getStatusText = (status: number) => {
    const texts = ['待支付', '已支付', '已完成', '已取消', '已退款'];
    return texts[status] || '未知';
  };

  const viewDetail = (record: any) => {
    currentRecord.value = record;
    detailVisible.value = true;
  };

  const goToMember = (record: any) => {
    if (record?.member_id) {
      router.push({
        path: '/business/member',
        query: { memberId: record.member_id },
      });
    }
  };

  const handleProcess = (record: any) => {
    Modal.confirm({
      title: '处理订单',
      content: `确定要处理订单 ${record.order_no} 吗？`,
      onOk: () => {
        request('/api/business/order/process', { order_id: record.id })
          .then(() => {
            Message.success('订单处理成功');
            handleSubmit();
          })
          .catch(() => {
            Message.error('订单处理失败');
          });
      },
    });
  };

  // 退款相关 - 需要在使用前定义
  const refundVisible = ref(false);
  const refundRecord = ref<any>({});

  const handleRefund = (record: any) => {
    refundRecord.value = record;
    refundVisible.value = true;
  };

  const refundForm = reactive({
    refund_amount: 0,
    refund_reason: '',
    refund_remark: '',
  });

  const handleRefundConfirm = () => {
    request('/api/business/order/refund', {
      order_id: refundRecord.value.id,
      refund_amount: refundForm.refund_amount,
      refund_reason: refundForm.refund_reason,
      refund_remark: refundForm.refund_remark,
    }).then(() => {
      Message.success('退款成功');
      refundVisible.value = false;
      handleSubmit();
    });
  };

  // 备注相关
  const remarkVisible = ref(false);
  const remarkRecord = ref<any>({});
  const remarkForm = reactive({
    remark: '',
  });

  const handleRemark = (record: any) => {
    remarkRecord.value = record;
    remarkForm.remark = record.remark || '';
    remarkVisible.value = true;
  };

  const handleRemarkSave = () => {
    request('/api/business/order/remark', {
      order_id: remarkRecord.value.id,
      remark: remarkForm.remark,
    }).then(() => {
      Message.success('备注保存成功');
      remarkVisible.value = false;
      handleSubmit();
    });
  };

  // 打印订单
  const handlePrint = (record: any) => {
    Message.info('正在打开打印窗口...');
    // 实际项目中可调用 window.print() 或调用打印服务
    const printContent = `
      订单编号: ${record.order_no}
      商品名称: ${record.product_name}
      商品规格: ${record.sku_info}
      购买数量: ${record.num}
      商品单价: ¥${record.price}
      订单金额: ¥${record.total_amount}
      会员名称: ${record.member_name}
      收货地址: ${record.address}
      下单时间: ${record.created_at}
    `;
    console.log('打印内容:', printContent);
  };

  // 物流跟踪
  const logisticsVisible = ref(false);
  const logisticsRecord = ref<any>({});
  const logisticsTimeline = ref<any[]>([]);

  const handleLogistics = (record: any) => {
    logisticsRecord.value = record;
    // 模拟物流数据
    logisticsTimeline.value = [
      {
        time: '2024-01-15 14:30',
        status: '已签收',
        desc: '已签收，感谢使用',
      },
      {
        time: '2024-01-15 09:20',
        status: '配送中',
        desc: '快递员正在为您配送',
      },
      { time: '2024-01-14 18:00', status: '运输中', desc: '已到达XX市快递点' },
      { time: '2024-01-13 20:00', status: '已发货', desc: '商品已发出' },
      { time: '2024-01-13 15:00', status: '待发货', desc: '商品准备中' },
    ];
    logisticsVisible.value = true;
  };

  const handleExport = () => {
    Message.success('正在导出订单数据...');
    request('/api/business/order/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `订单数据_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  const handleExportOne = (record: any) => {
    Message.success('正在导出订单...');
    request('/api/business/order/exportOne', { order_id: record.id })
      .then((res: any) => {
        Message.success('导出成功');
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `订单_${record.order_no}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败');
      });
  };

  const handleBatchAction = () => {
    if (selectedKeys.value.length === 0) {
      Message.warning('请先选择要操作的订单');
      return;
    }
    batchVisible.value = true;
  };

  // ========== 激活码管理功能 ==========

  // 打开激活码管理弹窗
  const openActivationCode = (record: any) => {
    activationRecord.value = record;
    activationVisible.value = true;
  };
</script>

<style lang="less" scoped>
  .total-price {
    font-size: 18px;
    font-weight: 600;
    color: #f53f3f;
  }
</style>
