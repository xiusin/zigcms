/**
 * 需求状态流转规则
 */

import type { RequirementStatus } from '@/types/quality-center';

/**
 * 状态流转规则映射
 * key: 当前状态
 * value: 可以流转到的状态列表
 */
export const STATUS_FLOW_RULES: Record<RequirementStatus, RequirementStatus[]> = {
  // 待评审 → 已评审、已关闭
  pending: ['reviewed', 'closed'],
  
  // 已评审 → 开发中、已关闭
  reviewed: ['developing', 'closed'],
  
  // 开发中 → 待测试、已关闭
  developing: ['testing', 'closed'],
  
  // 待测试 → 测试中、已关闭
  testing: ['in_test', 'closed'],
  
  // 测试中 → 已完成、开发中（测试不通过退回）、已关闭
  in_test: ['completed', 'developing', 'closed'],
  
  // 已完成 → 已关闭
  completed: ['closed'],
  
  // 已关闭 → 待评审（重新打开）
  closed: ['pending'],
};

/**
 * 状态显示名称
 */
export const STATUS_LABELS: Record<RequirementStatus, string> = {
  pending: '待评审',
  reviewed: '已评审',
  developing: '开发中',
  testing: '待测试',
  in_test: '测试中',
  completed: '已完成',
  closed: '已关闭',
};

/**
 * 状态颜色
 */
export const STATUS_COLORS: Record<RequirementStatus, string> = {
  pending: 'gray',
  reviewed: 'blue',
  developing: 'cyan',
  testing: 'orange',
  in_test: 'orange',
  completed: 'green',
  closed: 'gray',
};

/**
 * 状态图标
 */
export const STATUS_ICONS: Record<RequirementStatus, string> = {
  pending: 'icon-clock-circle',
  reviewed: 'icon-check-circle',
  developing: 'icon-code',
  testing: 'icon-experiment',
  in_test: 'icon-loading',
  completed: 'icon-check-circle-fill',
  closed: 'icon-close-circle',
};

/**
 * 检查状态流转是否合法
 */
export function canTransitionTo(
  fromStatus: RequirementStatus,
  toStatus: RequirementStatus
): boolean {
  const allowedStatuses = STATUS_FLOW_RULES[fromStatus];
  return allowedStatuses.includes(toStatus);
}

/**
 * 获取可流转的状态列表
 */
export function getAllowedStatuses(currentStatus: RequirementStatus): RequirementStatus[] {
  return STATUS_FLOW_RULES[currentStatus] || [];
}

/**
 * 获取状态流转错误提示
 */
export function getTransitionErrorMessage(
  fromStatus: RequirementStatus,
  toStatus: RequirementStatus
): string {
  const fromLabel = STATUS_LABELS[fromStatus];
  const toLabel = STATUS_LABELS[toStatus];
  const allowedStatuses = getAllowedStatuses(fromStatus);
  const allowedLabels = allowedStatuses.map(s => STATUS_LABELS[s]).join('、');
  
  return `无法从"${fromLabel}"流转到"${toLabel}"。当前状态只能流转到：${allowedLabels}`;
}

/**
 * 验证状态流转
 */
export function validateStatusTransition(
  fromStatus: RequirementStatus,
  toStatus: RequirementStatus
): { valid: boolean; message?: string } {
  // 状态未变化
  if (fromStatus === toStatus) {
    return { valid: true };
  }
  
  // 检查是否允许流转
  if (canTransitionTo(fromStatus, toStatus)) {
    return { valid: true };
  }
  
  return {
    valid: false,
    message: getTransitionErrorMessage(fromStatus, toStatus),
  };
}

/**
 * 获取状态流转历史记录
 */
export interface StatusHistory {
  from_status: RequirementStatus;
  to_status: RequirementStatus;
  operator: string;
  timestamp: number;
  remark?: string;
}

/**
 * 格式化状态流转历史
 */
export function formatStatusHistory(history: StatusHistory): string {
  const fromLabel = STATUS_LABELS[history.from_status];
  const toLabel = STATUS_LABELS[history.to_status];
  const date = new Date(history.timestamp * 1000);
  const dateStr = date.toLocaleString('zh-CN');
  
  let message = `${dateStr} ${history.operator} 将状态从"${fromLabel}"变更为"${toLabel}"`;
  
  if (history.remark) {
    message += `，备注：${history.remark}`;
  }
  
  return message;
}

/**
 * 获取状态进度百分比
 */
export function getStatusProgress(status: RequirementStatus): number {
  const progressMap: Record<RequirementStatus, number> = {
    pending: 0,
    reviewed: 20,
    developing: 40,
    testing: 60,
    in_test: 80,
    completed: 100,
    closed: 100,
  };
  
  return progressMap[status] || 0;
}

/**
 * 判断是否是终态
 */
export function isFinalStatus(status: RequirementStatus): boolean {
  return status === 'completed' || status === 'closed';
}

/**
 * 判断是否是进行中状态
 */
export function isInProgressStatus(status: RequirementStatus): boolean {
  return ['developing', 'testing', 'in_test'].includes(status);
}

/**
 * 获取下一个推荐状态
 */
export function getRecommendedNextStatus(currentStatus: RequirementStatus): RequirementStatus | null {
  const statusFlow: Record<RequirementStatus, RequirementStatus | null> = {
    pending: 'reviewed',
    reviewed: 'developing',
    developing: 'testing',
    testing: 'in_test',
    in_test: 'completed',
    completed: 'closed',
    closed: null,
  };
  
  return statusFlow[currentStatus];
}
