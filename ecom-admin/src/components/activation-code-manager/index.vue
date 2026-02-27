<template>
  <!-- 激活码管理弹窗 -->
  <a-modal
    v-model:visible="modalVisible"
    :title="`激活码管理 - ${recordName}`"
    :width="900"
    :unmount-on-close="true"
    :footer="false"
  >
    <a-space style="margin-bottom: 16px">
      <a-button type="primary" @click="handleGenerate">
        <template #icon><icon-plus /></template>
        生成激活码
      </a-button>
      <a-button @click="fetchList">
        <template #icon><icon-refresh /></template>
        刷新
      </a-button>
    </a-space>
    <a-table
      :columns="columns"
      :data="list"
      :loading="loading"
      :pagination="false"
      :bordered="false"
      size="small"
    >
      <template #code="{ record }">
        <div class="code-cell">
          <span class="code-text">{{ record.code }}</span>
          <a-button type="text" size="mini" @click="copyCode(record.code)">
            <template #icon><icon-copy /></template>
          </a-button>
        </div>
      </template>
      <template #bind_type="{ record }">
        <a-tag :color="getBindTypeColor(record.bind_type)">
          {{ getBindTypeText(record.bind_type) }}
        </a-tag>
      </template>
      <template #status="{ record }">
        <a-tag :color="getStatusColor(record.status)">
          {{ getStatusText(record.status) }}
        </a-tag>
      </template>
      <template #action="{ record }">
        <a-space>
          <a-button
            v-if="record.status === 0"
            type="text"
            size="small"
            @click="handleDisable(record)"
          >
            禁用
          </a-button>
          <a-button
            v-if="record.status === 3"
            type="text"
            size="small"
            @click="handleEnable(record)"
          >
            启用
          </a-button>
          <a-popconfirm
            content="确定要删除该激活码吗？"
            @ok="handleDelete(record)"
          >
            <a-button type="text" size="small" status="danger">删除</a-button>
          </a-popconfirm>
        </a-space>
      </template>
    </a-table>
  </a-modal>

  <!-- 生成激活码弹窗 -->
  <a-modal
    v-model:visible="generateVisible"
    title="生成激活码"
    :width="500"
    @ok="confirmGenerate"
  >
    <a-form :model="form" layout="vertical">
      <a-form-item label="激活类型" required>
        <a-select v-model="form.bind_type" disabled>
          <a-option :value="1">会员绑定</a-option>
          <a-option :value="2">设备绑定</a-option>
          <a-option :value="3">订单绑定</a-option>
        </a-select>
      </a-form-item>
      <a-form-item label="产品/功能" required>
        <a-select v-model="form.product_id">
          <a-option :value="1">高级版功能</a-option>
          <a-option :value="2">专业版功能</a-option>
          <a-option :value="3">企业版功能</a-option>
          <a-option :value="4">API接口权限</a-option>
          <a-option :value="5">数据导出功能</a-option>
        </a-select>
      </a-form-item>
      <a-form-item label="有效期">
        <a-radio-group v-model="form.expire_type">
          <a-radio :value="0">永久有效</a-radio>
          <a-radio :value="1">指定时间</a-radio>
        </a-radio-group>
      </a-form-item>
      <a-form-item v-if="form.expire_type === 1" label="过期时间">
        <a-date-picker
          v-model="form.expire_time"
          style="width: 100%"
          show-time
          format="YYYY-MM-DD HH:mm:ss"
        />
      </a-form-item>
      <a-form-item label="最大激活次数">
        <a-input-number
          v-model="form.max_count"
          :min="1"
          :max="100"
          style="width: 100%"
        />
      </a-form-item>
      <a-form-item label="生成数量">
        <a-input-number
          v-model="form.count"
          :min="1"
          :max="100"
          style="width: 100%"
        />
      </a-form-item>
      <a-form-item label="备注">
        <a-textarea
          v-model="form.remark"
          placeholder="请输入备注信息"
          :rows="2"
        />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
  import { ref, reactive, computed, watch } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import request from '@/api/request';

  // 绑定类型: 1-会员 2-设备 3-订单
  interface Props {
    visible: boolean;
    bindType: 1 | 2 | 3;
    bindId: number | string;
    recordName?: string;
  }

  const props = withDefaults(defineProps<Props>(), {
    recordName: '',
  });

  const emit = defineEmits<{
    (e: 'update:visible', visible: boolean): void;
  }>();

  const modalVisible = computed({
    get: () => props.visible,
    set: (val) => emit('update:visible', val),
  });

  const loading = ref(false);
  const list = ref<any[]>([]);
  const generateVisible = ref(false);

  const form = reactive({
    bind_type: props.bindType,
    product_id: 1,
    expire_type: 0,
    expire_time: '',
    max_count: 1,
    count: 1,
    remark: '',
  });

  const columns = [
    { title: '激活码', dataIndex: 'code', width: 200, slotName: 'code' },
    {
      title: '绑定类型',
      dataIndex: 'bind_type',
      width: 100,
      slotName: 'bind_type',
    },
    { title: '产品', dataIndex: 'product_name', width: 120 },
    { title: '激活次数', dataIndex: 'used_count', width: 80 },
    { title: '最大次数', dataIndex: 'max_count', width: 80 },
    { title: '状态', dataIndex: 'status', width: 80, slotName: 'status' },
    { title: '过期时间', dataIndex: 'expire_time', width: 160 },
    { title: '创建时间', dataIndex: 'created_at', width: 160 },
    { title: '操作', dataIndex: 'action', width: 120, slotName: 'action' },
  ];

  // 获取激活码列表
  const fetchList = () => {
    loading.value = true;
    request('/api/activation/list', {
      bind_type: props.bindType,
      bind_id: props.bindId,
    })
      .then((res: any) => {
        list.value = res.data?.list || [];
      })
      .catch(() => {
        list.value = [];
      })
      .finally(() => {
        loading.value = false;
      });
  };

  // 监听 visible 变化，打开时加载数据
  watch(
    () => props.visible,
    (val) => {
      if (val && props.bindId) {
        fetchList();
      }
    }
  );

  // 打开生成激活码弹窗
  const handleGenerate = () => {
    Object.assign(form, {
      bind_type: props.bindType,
      product_id: 1,
      expire_type: 0,
      expire_time: '',
      max_count: 1,
      count: 1,
      remark: '',
    });
    generateVisible.value = true;
  };

  // 确认生成激活码
  const confirmGenerate = () => {
    request('/api/activation/generate', {
      ...form,
      bind_id: props.bindId,
    })
      .then(() => {
        Message.success(`成功生成 ${form.count} 个激活码`);
        generateVisible.value = false;
        fetchList();
      })
      .catch(() => {
        Message.error('生成失败');
      });
  };

  // 复制激活码
  const copyCode = (code: string) => {
    navigator.clipboard
      .writeText(code)
      .then(() => {
        Message.success('激活码已复制到剪贴板');
      })
      .catch(() => {
        Message.error('复制失败');
      });
  };

  // 禁用激活码
  const handleDisable = (record: any) => {
    request('/api/activation/disable', { id: record.id }).then(() => {
      Message.success('激活码已禁用');
      fetchList();
    });
  };

  // 启用激活码
  const handleEnable = (record: any) => {
    request('/api/activation/enable', { id: record.id }).then(() => {
      Message.success('激活码已启用');
      fetchList();
    });
  };

  // 删除激活码
  const handleDelete = (record: any) => {
    request('/api/activation/delete', { id: record.id }).then(() => {
      Message.success('激活码已删除');
      fetchList();
    });
  };

  // 绑定类型颜色
  const getBindTypeColor = (type: number) => {
    const colors = ['', 'blue', 'green', 'orange'];
    return colors[type] || 'default';
  };

  // 绑定类型文本
  const getBindTypeText = (type: number) => {
    const texts = ['', '会员绑定', '设备绑定', '订单绑定'];
    return texts[type] || '未知';
  };

  // 激活码状态颜色
  const getStatusColor = (status: number) => {
    const colors = ['green', 'blue', 'orange', 'red'];
    return colors[status] || 'default';
  };

  // 激活码状态文本
  const getStatusText = (status: number) => {
    const texts = ['未激活', '已激活', '已过期', '已禁用'];
    return texts[status] || '未知';
  };
</script>

<style lang="less" scoped>
  .code-cell {
    display: flex;
    align-items: center;
    gap: 8px;

    .code-text {
      font-family: monospace;
    }
  }
</style>
