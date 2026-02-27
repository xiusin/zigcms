/**
 * 业务模块 API 封装
 */
import request from './request';
import type {
  MemberListParams,
  OrderListParams,
  MachineListParams,
  IncomeListParams,
  ActivationCodeListParams,
  ActivationCodeGenerateParams,
} from '@/types/business';

// ========== 会员相关 API ==========

/** 获取会员列表 */
export function getMemberList(params: MemberListParams) {
  return request('/api/business/member/list', params);
}

/** 获取会员详情 */
export function getMemberDetail(id: number) {
  return request('/api/business/member/detail', { id });
}

/** 保存会员 */
export function saveMember(data: Record<string, unknown>) {
  return request('/api/business/member/save', data);
}

/** 删除会员 */
export function deleteMember(id: number) {
  return request('/api/business/member/delete', { id });
}

/** 设置会员状态 */
export function setMemberStatus(id: number, status: number) {
  return request('/api/business/member/set', { id, status });
}

/** 导出会员 */
export function exportMembers(params: MemberListParams) {
  return request('/api/business/member/export', params);
}

/** 会员积分充值 */
export function memberPointRecharge(data: {
  member_id: number;
  type: 'add' | 'reduce';
  point: number;
  remark?: string;
}) {
  return request('/api/business/member/pointRecharge', data);
}

/** 会员余额充值 */
export function memberBalanceRecharge(data: {
  member_id: number;
  type: 'add' | 'reduce';
  amount: number;
  payment_method: string;
  remark?: string;
}) {
  return request('/api/business/member/balanceRecharge', data);
}

// ========== 订单相关 API ==========

/** 获取订单列表 */
export function getOrderList(params: OrderListParams) {
  return request('/api/business/order/list', params);
}

/** 获取订单详情 */
export function getOrderDetail(id: number) {
  return request('/api/business/order/detail', { id });
}

/** 处理订单 */
export function processOrder(orderId: number) {
  return request('/api/business/order/process', {
    order_id: orderId,
  });
}

/** 订单退款 */
export function refundOrder(data: {
  order_id: number;
  refund_amount: number;
  refund_reason: string;
  refund_remark?: string;
}) {
  return request('/api/business/order/refund', data);
}

/** 订单备注 */
export function updateOrderRemark(orderId: number, remark: string) {
  return request('/api/business/order/remark', {
    order_id: orderId,
    remark,
  });
}

/** 导出订单 */
export function exportOrders(params: OrderListParams) {
  return request('/api/business/order/export', params);
}

/** 导出单个订单 */
export function exportOrder(orderId: number) {
  return request('/api/business/order/exportOne', { order_id: orderId });
}

// ========== 机器/设备相关 API ==========

/** 获取机器列表 */
export function getMachineList(params: MachineListParams) {
  return request('/api/business/machine/list', params);
}

/** 获取机器详情 */
export function getMachineDetail(id: number) {
  return request('/api/business/machine/detail', { id });
}

/** 保存机器 */
export function saveMachine(data: Record<string, unknown>) {
  return request('/api/business/machine/save', data);
}

/** 删除机器 */
export function deleteMachine(id: number) {
  return request('/api/business/machine/delete', { id });
}

/** 获取机器统计 */
export function getMachineStats() {
  return request('/api/business/machine/stats');
}

/** 绑定订单 */
export function bindOrder(data: {
  id: number;
  order_id: number;
  remark?: string;
}) {
  return request('/api/business/machine/bind', data);
}

/** 解绑订单 */
export function unbindMachine(id: number) {
  return request('/api/business/machine/unbind', { id });
}

/** 机器续费 */
export function renewMachine(data: {
  id: number;
  renew_days: number;
  renew_amount: number;
  payment_method: string;
}) {
  return request('/api/business/machine/renew', data);
}

/** 导出机器 */
export function exportMachines(params: MachineListParams) {
  return request('/api/business/machine/export', params);
}

// ========== 收入相关 API ==========

/** 获取收入列表 */
export function getIncomeList(params: IncomeListParams) {
  return request('/api/business/income/list', params);
}

/** 获取收入统计 */
export function getIncomeStats() {
  return request('/api/business/income/stats');
}

/** 提现申请 */
export function withdrawApply(data: {
  amount: number;
  account_type: string;
  account_info: string;
  remark?: string;
}) {
  return request('/api/business/income/withdraw', data);
}

/** 导出收入 */
export function exportIncome(params: IncomeListParams) {
  return request('/api/business/income/export', params);
}

// ========== 激活码相关 API ==========

/** 获取激活码列表 */
export function getActivationCodeList(params: ActivationCodeListParams) {
  return request('/api/activation/list', params);
}

/** 生成激活码 */
export function generateActivationCode(data: ActivationCodeGenerateParams) {
  return request('/api/activation/generate', data);
}

/** 禁用激活码 */
export function disableActivationCode(id: number) {
  return request('/api/activation/disable', { id });
}

/** 启用激活码 */
export function enableActivationCode(id: number) {
  return request('/api/activation/enable', { id });
}

/** 删除激活码 */
export function deleteActivationCode(id: number) {
  return request('/api/activation/delete', { id });
}

// ========== 导出所有 API ==========
export default {
  // 会员
  getMemberList,
  getMemberDetail,
  saveMember,
  deleteMember,
  setMemberStatus,
  exportMembers,
  memberPointRecharge,
  memberBalanceRecharge,
  // 订单
  getOrderList,
  getOrderDetail,
  processOrder,
  refundOrder,
  updateOrderRemark,
  exportOrders,
  exportOrder,
  // 机器
  getMachineList,
  getMachineDetail,
  saveMachine,
  deleteMachine,
  getMachineStats,
  bindOrder,
  unbindMachine,
  renewMachine,
  exportMachines,
  // 收入
  getIncomeList,
  getIncomeStats,
  withdrawApply,
  exportIncome,
  // 激活码
  getActivationCodeList,
  generateActivationCode,
  disableActivationCode,
  enableActivationCode,
  deleteActivationCode,
};
