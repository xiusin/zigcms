<template>
  <a-modal
    v-model:visible="modalVisible"
    title="生成报告"
    width="600px"
    @ok="handleGenerate"
    @cancel="handleCancel"
  >
    <a-form :model="form" layout="vertical">
      <!-- 报告类型 -->
      <a-form-item label="报告类型" required>
        <a-select v-model="form.report_type" placeholder="请选择报告类型">
          <a-option value="daily">日报</a-option>
          <a-option value="weekly">周报</a-option>
          <a-option value="monthly">月报</a-option>
          <a-option value="custom">自定义</a-option>
        </a-select>
      </a-form-item>

      <!-- 时间范围 -->
      <a-form-item label="时间范围" required>
        <a-range-picker
          v-model="dateRange"
          style="width: 100%"
          :disabled-date="disabledDate"
        />
      </a-form-item>

      <!-- 报告格式 -->
      <a-form-item label="报告格式">
        <a-select v-model="form.format" placeholder="请选择报告格式">
          <a-option value="html">HTML</a-option>
          <a-option value="pdf">PDF</a-option>
          <a-option value="excel">Excel</a-option>
          <a-option value="json">JSON</a-option>
        </a-select>
      </a-form-item>

      <!-- 包含图表 -->
      <a-form-item label="包含图表">
        <a-switch v-model="form.include_charts" />
      </a-form-item>

      <!-- 包含详情 -->
      <a-form-item label="包含详情">
        <a-switch v-model="form.include_details" />
      </a-form-item>
    </a-form>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import dayjs, { Dayjs } from 'dayjs';
import type { GenerateReportRequest } from '@/types/security-report';

interface Props {
  visible: boolean;
}

interface Emits {
  (e: 'update:visible', value: boolean): void;
  (e: 'generate', params: GenerateReportRequest): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

// 对话框可见性
const modalVisible = computed({
  get: () => props.visible,
  set: (value) => emit('update:visible', value),
});

// 表单数据
const form = ref<GenerateReportRequest>({
  report_type: 'daily',
  start_date: dayjs().format('YYYY-MM-DD'),
  end_date: dayjs().format('YYYY-MM-DD'),
  format: 'html',
  include_charts: true,
  include_details: true,
});

// 日期范围
const dateRange = ref<[Dayjs, Dayjs]>([dayjs(), dayjs()]);

// 监听日期范围变化
watch(dateRange, (value) => {
  if (value && value.length === 2) {
    form.value.start_date = value[0].format('YYYY-MM-DD');
    form.value.end_date = value[1].format('YYYY-MM-DD');
  }
});

// 监听报告类型变化
watch(() => form.value.report_type, (type) => {
  const today = dayjs();
  
  switch (type) {
    case 'daily':
      dateRange.value = [today, today];
      break;
    case 'weekly':
      dateRange.value = [today.startOf('week'), today.endOf('week')];
      break;
    case 'monthly':
      dateRange.value = [today.startOf('month'), today.endOf('month')];
      break;
    default:
      // custom - 保持当前选择
      break;
  }
});

// 禁用未来日期
const disabledDate = (current: Dayjs) => {
  return current.isAfter(dayjs());
};

// 处理生成
const handleGenerate = () => {
  if (!form.value.start_date || !form.value.end_date) {
    Message.warning('请选择时间范围');
    return;
  }

  emit('generate', form.value);
};

// 处理取消
const handleCancel = () => {
  modalVisible.value = false;
};
</script>

<style scoped lang="scss">
// 样式
</style>
