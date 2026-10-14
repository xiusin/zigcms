<template>
  <div class="sla-indicator">
    <a-tooltip :content="tooltipContent">
      <a-tag :color="statusColor" class="sla-tag">
        <template #icon>
          <icon-clock-circle v-if="!isOverdue" />
          <icon-exclamation-circle v-else />
        </template>
        {{ displayText }}
      </a-tag>
    </a-tooltip>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import dayjs from 'dayjs';
import duration from 'dayjs/plugin/duration';

dayjs.extend(duration);

interface Props {
  createdAt: number | string;
  severity: 'low' | 'medium' | 'high' | 'critical';
  status: string;
}

const props = defineProps<Props>();

// SLA 时限配置（小时）
const SLA_LIMITS: Record<string, number> = {
  low: 72, // 3 天
  medium: 48, // 2 天
  high: 24, // 1 天
  critical: 4, // 4 小时
};

// 计算剩余时间
const remainingTime = computed(() => {
  const limit = SLA_LIMITS[props.severity];
  const created = dayjs(props.createdAt);
  const deadline = created.add(limit, 'hour');
  const now = dayjs();

  return deadline.diff(now, 'millisecond');
});

// 是否超时
const isOverdue = computed(() => {
  return remainingTime.value < 0;
});

// 状态颜色
const statusColor = computed(() => {
  if (props.status === 'resolved' || props.status === 'closed') {
    return 'green';
  }

  if (isOverdue.value) {
    return 'red';
  }

  const hours = remainingTime.value / (1000 * 60 * 60);
  if (hours < 2) {
    return 'orange';
  }

  return 'blue';
});

// 显示文本
const displayText = computed(() => {
  if (props.status === 'resolved' || props.status === 'closed') {
    return '已完成';
  }

  if (isOverdue.value) {
    const overdue = Math.abs(remainingTime.value);
    return `超时 ${formatDuration(overdue)}`;
  }

  return `剩余 ${formatDuration(remainingTime.value)}`;
});

// 提示内容
const tooltipContent = computed(() => {
  const limit = SLA_LIMITS[props.severity];
  const created = dayjs(props.createdAt);
  const deadline = created.add(limit, 'hour');

  return `SLA 时限: ${limit} 小时\n截止时间: ${deadline.format('YYYY-MM-DD HH:mm:ss')}`;
});

// 格式化时长
const formatDuration = (ms: number): string => {
  const d = dayjs.duration(ms);
  const days = Math.floor(d.asDays());
  const hours = d.hours();
  const minutes = d.minutes();

  if (days > 0) {
    return `${days}天${hours}小时`;
  }

  if (hours > 0) {
    return `${hours}小时${minutes}分钟`;
  }

  return `${minutes}分钟`;
};
</script>

<style scoped lang="less">
.sla-indicator {
  display: inline-block;

  .sla-tag {
    cursor: help;
  }
}
</style>
