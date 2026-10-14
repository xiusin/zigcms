<template>
  <div class="feedback-flow-chart">
    <div class="flow-container" ref="flowContainer"></div>
    
    <!-- 流转规则配置 -->
    <a-drawer
      v-model:visible="configVisible"
      title="流转规则配置"
      :width="600"
      :footer="false"
    >
      <a-form :model="flowConfig" layout="vertical">
        <a-form-item label="自动流转规则">
          <a-checkbox-group v-model="flowConfig.autoRules">
            <a-checkbox value="auto_assign">自动分配处理人</a-checkbox>
            <a-checkbox value="auto_escalate">超时自动升级</a-checkbox>
            <a-checkbox value="auto_close">自动关闭已解决反馈</a-checkbox>
          </a-checkbox-group>
        </a-form-item>

        <a-form-item label="超时升级时间（小时）">
          <a-input-number
            v-model="flowConfig.escalateHours"
            :min="1"
            :max="168"
            style="width: 100%"
          />
        </a-form-item>

        <a-form-item label="自动关闭时间（天）">
          <a-input-number
            v-model="flowConfig.autoCloseDays"
            :min="1"
            :max="30"
            style="width: 100%"
          />
        </a-form-item>

        <a-form-item label="通知设置">
          <a-checkbox-group v-model="flowConfig.notifications">
            <a-checkbox value="email">邮件通知</a-checkbox>
            <a-checkbox value="sms">短信通知</a-checkbox>
            <a-checkbox value="dingtalk">钉钉通知</a-checkbox>
          </a-checkbox-group>
        </a-form-item>

        <a-form-item>
          <a-space>
            <a-button type="primary" @click="handleSaveConfig">
              保存配置
            </a-button>
            <a-button @click="configVisible = false">
              取消
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, onUnmounted, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import * as echarts from 'echarts';

interface Props {
  currentStatus?: string;
  showConfig?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  currentStatus: 'pending',
  showConfig: true,
});

const emit = defineEmits<{
  statusChange: [status: string];
  configChange: [config: any];
}>();

const flowContainer = ref<HTMLElement>();
let chartInstance: echarts.ECharts | null = null;

const configVisible = ref(false);
const flowConfig = ref({
  autoRules: ['auto_assign'],
  escalateHours: 24,
  autoCloseDays: 7,
  notifications: ['email', 'dingtalk'],
});

// 流转节点定义
const flowNodes = [
  { name: '待处理', value: 'pending', x: 100, y: 200, color: '#86909c' },
  { name: '处理中', value: 'in_progress', x: 300, y: 200, color: '#165dff' },
  { name: '已解决', value: 'resolved', x: 500, y: 100, color: '#00b42a' },
  { name: '已关闭', value: 'closed', x: 700, y: 100, color: '#0fc6c2' },
  { name: '已拒绝', value: 'rejected', x: 500, y: 300, color: '#f53f3f' },
];

// 流转关系定义
const flowLinks = [
  { source: 'pending', target: 'in_progress', label: '开始处理' },
  { source: 'in_progress', target: 'resolved', label: '解决问题' },
  { source: 'in_progress', target: 'rejected', label: '拒绝反馈' },
  { source: 'resolved', target: 'closed', label: '确认关闭' },
  { source: 'resolved', target: 'in_progress', label: '重新打开' },
  { source: 'rejected', target: 'in_progress', label: '重新处理' },
];

// 初始化流程图
const initFlowChart = () => {
  if (!flowContainer.value) return;

  chartInstance = echarts.init(flowContainer.value);

  const option = {
    title: {
      text: '反馈流转流程',
      left: 'center',
      top: 20,
    },
    tooltip: {
      trigger: 'item',
      formatter: (params: any) => {
        if (params.dataType === 'node') {
          return `${params.data.name}<br/>点击查看该状态的反馈`;
        } else {
          return params.data.label;
        }
      },
    },
    series: [
      {
        type: 'graph',
        layout: 'none',
        symbolSize: 80,
        roam: false,
        label: {
          show: true,
          fontSize: 14,
          fontWeight: 'bold',
        },
        edgeSymbol: ['none', 'arrow'],
        edgeSymbolSize: [0, 10],
        edgeLabel: {
          show: true,
          fontSize: 12,
          formatter: '{c}',
        },
        data: flowNodes.map((node) => ({
          name: node.name,
          value: node.value,
          x: node.x,
          y: node.y,
          itemStyle: {
            color: node.value === props.currentStatus ? node.color : '#e5e6eb',
            borderColor: node.value === props.currentStatus ? node.color : '#c9cdd4',
            borderWidth: node.value === props.currentStatus ? 3 : 1,
          },
          label: {
            color: node.value === props.currentStatus ? '#fff' : '#4e5969',
          },
        })),
        links: flowLinks.map((link) => ({
          source: flowNodes.findIndex((n) => n.value === link.source),
          target: flowNodes.findIndex((n) => n.value === link.target),
          label: link.label,
          lineStyle: {
            color: '#c9cdd4',
            curveness: 0.2,
          },
        })),
      },
    ],
  };

  chartInstance.setOption(option);

  // 绑定点击事件
  chartInstance.on('click', (params: any) => {
    if (params.dataType === 'node') {
      const status = params.data.value;
      emit('statusChange', status);
      Message.info(`切换到${params.data.name}状态`);
    }
  });

  // 监听窗口大小变化
  window.addEventListener('resize', handleResize);
};

// 更新流程图
const updateFlowChart = () => {
  if (!chartInstance) return;

  const option = chartInstance.getOption() as any;
  if (option.series && option.series[0]) {
    option.series[0].data = flowNodes.map((node) => ({
      name: node.name,
      value: node.value,
      x: node.x,
      y: node.y,
      itemStyle: {
        color: node.value === props.currentStatus ? node.color : '#e5e6eb',
        borderColor: node.value === props.currentStatus ? node.color : '#c9cdd4',
        borderWidth: node.value === props.currentStatus ? 3 : 1,
      },
      label: {
        color: node.value === props.currentStatus ? '#fff' : '#4e5969',
      },
    }));
    chartInstance.setOption(option);
  }
};

// 处理窗口大小变化
const handleResize = () => {
  chartInstance?.resize();
};

// 打开配置
const handleOpenConfig = () => {
  configVisible.value = true;
};

// 保存配置
const handleSaveConfig = () => {
  emit('configChange', flowConfig.value);
  Message.success('流转规则配置已保存');
  configVisible.value = false;
};

// 监听当前状态变化
watch(
  () => props.currentStatus,
  () => {
    updateFlowChart();
  }
);

onMounted(() => {
  initFlowChart();
});

onUnmounted(() => {
  window.removeEventListener('resize', handleResize);
  chartInstance?.dispose();
});

// 暴露方法
defineExpose({
  openConfig: handleOpenConfig,
});
</script>

<style scoped lang="less">
.feedback-flow-chart {
  .flow-container {
    width: 100%;
    height: 400px;
  }
}
</style>
