<template>
  <div class="content-box">
    <a-card class="table-card">
      <template #title>
        <a-space>
          <span>会员管理</span>
          <a-tag color="blue">{{ tableTotal }} 个会员</a-tag>
        </a-space>
      </template>
      <template #extra>
        <a-space>
          <a-button size="small" type="primary" @click="saveAction({})">
            <template #icon>
              <icon-plus />
            </template>
            新增会员
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
        placeholder="请输入会员名称、手机号搜索"
        @hand-submit="handleSubmit"
      >
        <template #actions>
          <a-space>
            <a-dropdown>
              <a-button size="small">
                <template #icon>
                  <icon-settings />
                </template>
                批量操作
              </a-button>
              <template #content>
                <a-doption @click="handleBatchEnable">批量启用</a-doption>
                <a-doption @click="handleBatchDisable">批量禁用</a-doption>
                <a-doption @click="handleBatchDelete">批量删除</a-doption>
                <a-doption @click="handleBatchExport">批量导出</a-doption>
              </template>
            </a-dropdown>
            <a-button size="small" @click="handleTagManage">
              <template #icon>
                <icon-tag />
              </template>
              标签管理
            </a-button>
            <a-button size="small" @click="handlePointRecharge">
              <template #icon>
                <icon-star />
              </template>
              积分充值
            </a-button>
            <a-button size="small" @click="handleBalanceRecharge">
              <template #icon>
                <icon-money-circle />
              </template>
              余额充值
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
        <template #avatar="{ record }">
          <a-avatar :size="36" :image-url="record.avatar">
            {{ record.nickname?.charAt(0) }}
          </a-avatar>
        </template>
        <template #level="{ record }">
          <a-tag :color="getLevelColor(record.level)">
            {{ getLevelText(record.level) }}
          </a-tag>
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
            <a-button type="text" size="small" @click="viewDetail(record)">
              <template #icon><icon-eye /></template>
              查看
            </a-button>
            <a-button type="text" size="small" @click="saveAction(record)">
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
            <a-popconfirm
              :content="`确定要删除该会员吗?`"
              position="left"
              @ok="deleteMember(record)"
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

    <!-- 会员详情弹窗 -->
    <a-modal
      v-model:visible="detailVisible"
      :title="`会员详情 - ${currentRecord?.nickname}`"
      :width="900"
      :unmount-on-close="true"
    >
      <a-tabs v-model:active-key="detailTab">
        <a-tab-pane key="base" title="基本信息">
          <a-descriptions :column="2" bordered>
            <a-descriptions-item label="会员头像">
              <a-avatar :size="64" :image-url="currentRecord?.avatar">
                {{ currentRecord?.nickname?.charAt(0) }}
              </a-avatar>
            </a-descriptions-item>
            <a-descriptions-item label="会员等级">
              <a-tag :color="getLevelColor(currentRecord?.level)">
                {{ getLevelText(currentRecord?.level) }}
              </a-tag>
            </a-descriptions-item>
            <a-descriptions-item label="会员昵称">
              {{ currentRecord?.nickname || '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="会员手机">
              {{ currentRecord?.mobile || '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="账户余额">
              ¥{{ currentRecord?.balance || 0 }}
            </a-descriptions-item>
            <a-descriptions-item label="累计消费">
              <a-link @click="goToOrder">{{
                currentRecord?.total_consume || 0
              }}</a-link>
            </a-descriptions-item>
            <a-descriptions-item label="注册时间">
              {{ currentRecord?.created_at || '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="最后登录">
              {{ currentRecord?.last_login || '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="邮箱">
              {{ currentRecord?.email || '-' }}
            </a-descriptions-item>
            <a-descriptions-item label="状态">
              <a-tag :color="currentRecord?.status === 1 ? 'green' : 'red'">
                {{ currentRecord?.status === 1 ? '正常' : '禁用' }}
              </a-tag>
            </a-descriptions-item>
          </a-descriptions>
        </a-tab-pane>
        <a-tab-pane key="orders" title="订单记录">
          <a-table
            :columns="orderColumns"
            :data="orderList"
            :loading="orderLoading"
            :pagination="false"
            :bordered="false"
            size="small"
          >
            <template #order_no="{ record }">
              <a-link @click="goToOrderDetail(record)">{{
                record.order_no
              }}</a-link>
            </template>
            <template #status="{ record }">
              <a-tag :color="getOrderStatusColor(record.status)">
                {{ getOrderStatusText(record.status) }}
              </a-tag>
            </template>
            <template #empty>
              <a-empty description="暂无订单记录" />
            </template>
          </a-table>
          <div v-if="orderList.length > 0" class="view-more-orders">
            <a-link @click="goToOrder">查看全部订单 →</a-link>
          </div>
        </a-tab-pane>
        <a-tab-pane key="income" title="收入记录">
          <a-table
            :columns="incomeColumns"
            :data="incomeList"
            :loading="incomeLoading"
            :pagination="false"
            :bordered="false"
            size="small"
          >
            <template #income_type="{ record }">
              <a-tag :color="getIncomeTypeColor(record.income_type)">
                {{ getIncomeTypeText(record.income_type) }}
              </a-tag>
            </template>
            <template #status="{ record }">
              <a-tag :color="record.status === 1 ? 'green' : 'orange'">
                {{ record.status === 1 ? '已到账' : '待确认' }}
              </a-tag>
            </template>
            <template #empty>
              <a-empty description="暂无收入记录" />
            </template>
          </a-table>
          <div v-if="incomeList.length > 0" class="view-more-orders">
            <a-link @click="goToIncome">查看全部收入 →</a-link>
          </div>
        </a-tab-pane>
      </a-tabs>
      <template #footer>
        <a-space>
          <a-button
            v-if="currentRecord?.status === 1"
            size="small"
            @click="handleAddToBlacklist(currentRecord)"
          >
            <template #icon><icon-close-circle /></template>
            加入黑名单
          </a-button>
          <a-button size="small" @click="detailVisible = false">关闭</a-button>
        </a-space>
      </template>
    </a-modal>

    <!-- 新增/编辑弹窗 -->
    <a-modal
      v-model:visible="saveVisible"
      :title="isEdit ? '编辑会员' : '新增会员'"
      :width="600"
      :unmount-on-close="true"
      @ok="handleSave"
    >
      <a-form ref="formRef" :model="formData" :rules="rules" layout="vertical">
        <a-form-item label="会员昵称" field="nickname">
          <a-input v-model="formData.nickname" placeholder="请输入会员昵称" />
        </a-form-item>
        <a-form-item label="手机号码" field="mobile">
          <a-input v-model="formData.mobile" placeholder="请输入手机号码" />
        </a-form-item>
        <a-form-item label="邮箱" field="email">
          <a-input v-model="formData.email" placeholder="请输入邮箱" />
        </a-form-item>
        <a-form-item label="会员等级" field="level">
          <a-select v-model="formData.level" placeholder="请选择会员等级">
            <a-option :value="1">普通会员</a-option>
            <a-option :value="2">铜牌会员</a-option>
            <a-option :value="3">银牌会员</a-option>
            <a-option :value="4">金牌会员</a-option>
            <a-option :value="5">钻石会员</a-option>
          </a-select>
        </a-form-item>
        <a-form-item v-if="isEdit" label="账户余额" field="balance">
          <a-input-number
            v-model="formData.balance"
            :min="0"
            :precision="2"
            placeholder="请输入账户余额"
            style="width: 100%"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 标签管理弹窗 -->
    <a-modal
      v-model:visible="tagVisible"
      title="标签管理"
      :width="600"
      :unmount-on-close="true"
    >
      <a-space style="margin-bottom: 16px">
        <a-button type="primary" size="small" @click="handleAddTag">
          <template #icon>
            <icon-plus />
          </template>
          新增标签
        </a-button>
      </a-space>
      <a-space wrap>
        <a-tag
          v-for="tag in tagList"
          :key="tag.id"
          :color="tag.color"
          closable
          @close="() => {}"
        >
          {{ tag.name }}
        </a-tag>
      </a-space>
      <a-divider>会员标签分配</a-divider>
      <a-form layout="vertical">
        <a-form-item label="选择会员">
          <a-select
            placeholder="请选择会员"
            :searchable="true"
            style="width: 100%"
          >
            <a-option value="1">张三</a-option>
            <a-option value="2">李四</a-option>
            <a-option value="3">王五</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="分配标签">
          <a-select
            placeholder="请选择标签"
            :multiple="true"
            style="width: 100%"
          >
            <a-option v-for="tag in tagList" :key="tag.id" :value="tag.id">
              {{ tag.name }}
            </a-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 积分充值弹窗 -->
    <a-modal
      v-model:visible="pointVisible"
      title="积分充值"
      :width="500"
      :unmount-on-close="true"
      @ok="handlePointConfirm"
    >
      <a-form :model="pointForm" layout="vertical">
        <a-form-item label="会员">
          <a-input :model-value="pointForm.member_name" disabled />
        </a-form-item>
        <a-form-item label="充值类型">
          <a-radio-group v-model="pointForm.type">
            <a-radio value="add">增加积分</a-radio>
            <a-radio value="reduce">扣除积分</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="积分数量">
          <a-input-number
            v-model="pointForm.point"
            :min="0"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea
            v-model="pointForm.remark"
            placeholder="请输入备注"
            :rows="3"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 余额充值弹窗 -->
    <a-modal
      v-model:visible="balanceVisible"
      title="余额充值"
      :width="500"
      :unmount-on-close="true"
      @ok="handleBalanceConfirm"
    >
      <a-form :model="balanceForm" layout="vertical">
        <a-form-item label="会员">
          <a-input :model-value="balanceForm.member_name" disabled />
        </a-form-item>
        <a-form-item label="充值类型">
          <a-radio-group v-model="balanceForm.type">
            <a-radio value="add">充值</a-radio>
            <a-radio value="reduce">扣款</a-radio>
          </a-radio-group>
        </a-form-item>
        <a-form-item label="金额">
          <a-input-number
            v-model="balanceForm.amount"
            :min="0"
            :precision="2"
            style="width: 100%"
          />
        </a-form-item>
        <a-form-item label="支付方式">
          <a-select v-model="balanceForm.payment_method">
            <a-option value="wechat">微信支付</a-option>
            <a-option value="alipay">支付宝</a-option>
            <a-option value="bank">银行卡</a-option>
            <a-option value="cash">现金</a-option>
          </a-select>
        </a-form-item>
        <a-form-item label="备注">
          <a-textarea
            v-model="balanceForm.remark"
            placeholder="请输入备注"
            :rows="3"
          />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 激活码管理弹窗 -->
    <ActivationCodeManager
      v-model:visible="activationVisible"
      :bind-type="1"
      :bind-id="activationRecord?.id"
      :record-name="activationRecord?.nickname"
    />
  </div>
</template>

<script setup lang="ts">
  import { ref, reactive, watch, onMounted, computed } from 'vue';
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
  const detailTab = ref('base');
  const detailVisible = ref(false);
  const saveVisible = ref(false);
  const isEdit = ref(false);
  const currentRecord = ref<any>({});
  const formRef = ref();

  // 激活码相关
  const activationVisible = ref(false);
  const activationRecord = ref<any>({});

  // 订单记录相关
  const orderLoading = ref(false);
  const orderList = ref<any[]>([]);
  const orderColumns = [
    {
      title: '订单编号',
      dataIndex: 'order_no',
      width: 180,
      slotName: 'order_no',
    },
    { title: '商品名称', dataIndex: 'product_name', ellipsis: true },
    { title: '订单金额', dataIndex: 'total_amount', width: 100 },
    { title: '订单状态', dataIndex: 'status', width: 100, slotName: 'status' },
    { title: '下单时间', dataIndex: 'created_at', width: 160 },
  ];

  // 收入记录相关
  const incomeLoading = ref(false);
  const incomeList = ref<any[]>([]);
  const incomeColumns = [
    {
      title: '收入类型',
      dataIndex: 'income_type',
      width: 100,
      slotName: 'income_type',
    },
    { title: '金额', dataIndex: 'amount', width: 100 },
    { title: '来源', dataIndex: 'source', ellipsis: true },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '时间', dataIndex: 'created_at', width: 160 },
  ];

  const formData = reactive({
    id: 0,
    nickname: '',
    mobile: '',
    email: '',
    level: 1,
    balance: 0,
  });

  const rules = {
    nickname: [{ required: true, message: '请输入会员昵称' }],
    mobile: [{ required: true, message: '请输入手机号码' }],
  };

  const columns = [
    { title: '头像', dataIndex: 'avatar', width: 80, slotName: 'avatar' },
    { title: '昵称', dataIndex: 'nickname', width: 120 },
    { title: '手机号', dataIndex: 'mobile', width: 130 },
    { title: '邮箱', dataIndex: 'email' },
    { title: '会员等级', dataIndex: 'level', width: 100, slotName: 'level' },
    { title: '账户余额', dataIndex: 'balance', width: 120 },
    { title: '累计消费', dataIndex: 'total_consume', width: 120 },
    { title: '注册时间', dataIndex: 'created_at', width: 180 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '操作', dataIndex: 'action', width: 180, slotName: 'action' },
  ];

  const generateFormModel = () => ({
    nickname: null,
    mobile: null,
    level: '',
    status: '',
  });

  const baseSearchRules = ref([
    { field: 'nickname', label: '昵称', value: null },
    { field: 'mobile', label: '手机号', value: null },
  ]);

  const searchRules = ref([
    {
      field: 'level',
      label: '会员等级',
      value: null,
      component_name: 'base-dict-select',
      attr: { selectType: 'member_level' },
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

  // 页面加载时检查路由参数
  onMounted(() => {
    const { memberId } = route.query;
    if (memberId) {
      // 通过路由参数打开会员详情
      request('/api/business/member/list', { id: memberId }).then(
        (res: any) => {
          const { data } = res;
          if (data?.list?.length) {
            const [firstItem] = data.list;
            currentRecord.value = firstItem;
            detailVisible.value = true;
            // 清除路由参数
            router.replace({ path: '/business/member' });
          }
        }
      );
    }
  });

  const getDataList = (data: any) => {
    return request('/api/business/member/list', data);
  };

  const handleSubmit = (resData: any = {}) => {
    Object.assign(formModel.value, resData);
    tableRef.value?.search();
  };

  const getLevelColor = (level: number) => {
    const colors = ['default', 'orange', 'lime', 'gold', 'purple', 'cyan'];
    return colors[level] || 'default';
  };

  const getLevelText = (level: number) => {
    const texts = [
      '',
      '普通会员',
      '铜牌会员',
      '银牌会员',
      '金牌会员',
      '钻石会员',
    ];
    return texts[level] || '普通会员';
  };

  const changeStatus = async (record: any) => {
    record.loading = true;
    request('/api/business/member/set', {
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

  const viewDetail = async (record: any) => {
    currentRecord.value = record;
    detailTab.value = 'base';
    detailVisible.value = true;

    // 加载订单记录
    orderLoading.value = true;
    try {
      const orderRes = await request('/api/business/order/list', {
        member_id: record.id,
        page: 1,
        pageSize: 5,
      });
      orderList.value = orderRes.data?.list || [];
    } catch (e) {
      orderList.value = [];
    } finally {
      orderLoading.value = false;
    }

    // 加载收入记录
    incomeLoading.value = true;
    try {
      const incomeRes = await request('/api/business/income/list', {
        member_id: record.id,
        page: 1,
        pageSize: 5,
      });
      incomeList.value = incomeRes.data?.list || [];
    } catch (e) {
      incomeList.value = [];
    } finally {
      incomeLoading.value = false;
    }
  };

  const saveAction = (record: any) => {
    if (record.id) {
      isEdit.value = true;
      Object.assign(formData, record);
    } else {
      isEdit.value = false;
      Object.assign(formData, {
        id: 0,
        nickname: '',
        mobile: '',
        email: '',
        level: 1,
        balance: 0,
      });
    }
    saveVisible.value = true;
  };

  const handleSave = async () => {
    const valid = await formRef.value?.validate();
    if (valid) return;

    request('/api/business/member/save', formData).then(() => {
      Message.success(isEdit.value ? '编辑成功' : '新增成功');
      saveVisible.value = false;
      handleSubmit();
    });
  };

  const deleteMember = async (record: any) => {
    request('/api/business/member/delete', { id: record.id }).then(() => {
      Message.success('删除成功');
      handleSubmit();
    });
  };

  const handleExport = () => {
    Message.success('正在导出数据...');
    request('/api/business/member/export', formModel.value)
      .then((res: any) => {
        Message.success('导出成功，文件已下载');
        // 模拟下载
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `会员数据_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败，请稍后重试');
      });
  };

  // 批量操作相关
  const selectedKeys = ref<string[]>([]);

  const handleBatchEnable = () => {
    if (selectedKeys.value.length === 0) {
      Message.warning('请先选择要操作的会员');
      return;
    }
    request('/api/business/member/batchEnable', {
      ids: selectedKeys.value,
    }).then(() => {
      Message.success('批量启用成功');
      handleSubmit();
    });
  };

  const handleBatchDisable = () => {
    if (selectedKeys.value.length === 0) {
      Message.warning('请先选择要操作的会员');
      return;
    }
    request('/api/business/member/batchDisable', {
      ids: selectedKeys.value,
    }).then(() => {
      Message.success('批量禁用成功');
      handleSubmit();
    });
  };

  const handleBatchDelete = () => {
    if (selectedKeys.value.length === 0) {
      Message.warning('请先选择要删除的会员');
      return;
    }
    request('/api/business/member/batchDelete', {
      ids: selectedKeys.value,
    }).then(() => {
      Message.success('批量删除成功');
      handleSubmit();
    });
  };

  const handleBatchExport = () => {
    if (selectedKeys.value.length === 0) {
      Message.warning('请先选择要导出的会员');
      return;
    }
    Message.success('正在导出选中数据...');
    request('/api/business/member/export', { ids: selectedKeys.value })
      .then((res: any) => {
        Message.success(`成功导出 ${selectedKeys.value.length} 条数据`);
        const link = document.createElement('a');
        link.href = res.data?.url || '#';
        link.download = `会员数据_${new Date().getTime()}.xlsx`;
        link.click();
      })
      .catch(() => {
        Message.error('导出失败，请稍后重试');
      });
  };

  // 标签管理弹窗
  const tagVisible = ref(false);
  const newTagName = ref('');
  const newTagColor = ref('blue');
  const tagList = ref([
    { id: 1, name: 'VIP客户', color: 'red' },
    { id: 2, name: '活跃用户', color: 'green' },
    { id: 3, name: '沉睡用户', color: 'gray' },
    { id: 4, name: '高消费', color: 'purple' },
  ]);

  const handleTagManage = () => {
    tagVisible.value = true;
  };

  const handleAddTag = () => {
    if (!newTagName.value) {
      Message.warning('请输入标签名称');
      return;
    }
    request('/api/business/member/tag/add', {
      name: newTagName.value,
      color: newTagColor.value,
    })
      .then(() => {
        Message.success('标签添加成功');
        newTagName.value = '';
        newTagColor.value = 'blue';
        // 刷新标签列表
        tagList.value.push({
          id: Date.now(),
          name: newTagName.value,
          color: newTagColor.value,
        });
      })
      .catch(() => {
        Message.error('添加标签失败');
      });
  };

  // 积分充值弹窗
  const pointVisible = ref(false);
  const pointForm = reactive({
    member_id: 0,
    member_name: '',
    point: 0,
    type: 'add',
    remark: '',
  });

  const handlePointRecharge = (record?: any) => {
    if (record) {
      pointForm.member_id = record.id;
      pointForm.member_name = record.nickname;
    } else {
      pointForm.member_id = 0;
      pointForm.member_name = '';
    }
    pointVisible.value = true;
  };

  const handlePointConfirm = () => {
    request('/api/business/member/pointRecharge', pointForm).then(() => {
      Message.success('积分充值成功');
      pointVisible.value = false;
      handleSubmit();
    });
  };

  // 余额充值弹窗
  const balanceVisible = ref(false);
  const balanceForm = reactive({
    member_id: 0,
    member_name: '',
    amount: 0,
    type: 'add',
    payment_method: 'wechat',
    remark: '',
  });

  const handleBalanceRecharge = (record?: any) => {
    if (record) {
      balanceForm.member_id = record.id;
      balanceForm.member_name = record.nickname;
    } else {
      balanceForm.member_id = 0;
      balanceForm.member_name = '';
    }
    balanceVisible.value = true;
  };

  const handleBalanceConfirm = () => {
    request('/api/business/member/balanceRecharge', balanceForm).then(() => {
      Message.success('余额充值成功');
      balanceVisible.value = false;
      handleSubmit();
    });
  };

  // 跳转到订单管理
  const goToOrder = () => {
    router.push({
      path: '/business/order',
      query: { memberId: currentRecord.value.id },
    });
  };

  // 跳转到订单详情
  const goToOrderDetail = (record: any) => {
    router.push({
      path: '/business/order',
      query: { orderId: record.id },
    });
  };

  // 跳转到收入管理
  const goToIncome = () => {
    router.push({
      path: '/business/income',
      query: { memberId: currentRecord.value.id },
    });
  };

  // 加入黑名单
  const handleAddToBlacklist = (record: any) => {
    request('/api/security/blacklist/add', {
      member_id: record.id,
      reason: '会员管理手动拉黑',
    }).then(() => {
      Message.success('已加入黑名单');
      detailVisible.value = false;
      handleSubmit();
    });
  };

  // 订单状态颜色
  const getOrderStatusColor = (status: number) => {
    const colors = ['red', 'orange', 'green', 'gray', 'blue'];
    return colors[status] || 'gray';
  };

  // 订单状态文本
  const getOrderStatusText = (status: number) => {
    const texts = ['待支付', '已支付', '已完成', '已取消', '已退款'];
    return texts[status] || '未知';
  };

  // 收入类型颜色
  const getIncomeTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange', 'purple'];
    return colors[type] || 'default';
  };

  // 收入类型文本
  const getIncomeTypeText = (type: number) => {
    const texts = ['', '订单收入', '充值', '退款', '其他'];
    return texts[type] || '未知';
  };

  // ========== 激活码管理功能 ==========

  // 打开激活码管理弹窗
  const openActivationCode = (record: any) => {
    activationRecord.value = record;
    activationVisible.value = true;
  };
</script>

<style lang="less" scoped>
  .view-more-orders {
    text-align: center;
    margin-top: 12px;
    padding-top: 12px;
    border-top: 1px solid var(--color-border-1);
  }
</style>
