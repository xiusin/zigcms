/**
 * 业务模块类型定义
 */

// ========== 会员相关 ==========
export interface Member {
  id: number;
  nickname: string;
  mobile: string;
  email?: string;
  avatar?: string;
  level: number;
  level_name?: string;
  balance: number;
  points: number;
  status: number;
  created_at: string;
  updated_at?: string;
}

export interface MemberListParams {
  page?: number;
  pageSize?: number;
  nickname?: string;
  mobile?: string;
  status?: number | string;
  level?: number | string;
}

// ========== 订单相关 ==========
export interface Order {
  id: number;
  order_no: string;
  product_name: string;
  sku_info?: string;
  num: number;
  price: number;
  total_amount: number;
  member_id: number;
  member_name: string;
  pay_type: number;
  status: number;
  address?: string;
  remark?: string;
  created_at: string;
  updated_at?: string;
}

export interface OrderListParams {
  page?: number;
  pageSize?: number;
  order_no?: string;
  product_name?: string;
  member_name?: string;
  member_id?: number;
  status?: number | string;
  pay_type?: number | string;
  machine_id?: number;
}

// ========== 机器/设备相关 ==========
export interface Machine {
  id: number;
  machine_code: string;
  machine_name: string;
  machine_type: number;
  os_type: number;
  device_id?: string;
  bind_order_id?: number;
  order_no?: string;
  status: number;
  expire_time?: string;
  remark?: string;
  created_at: string;
  updated_at?: string;
}

export interface MachineListParams {
  page?: number;
  pageSize?: number;
  machine_code?: string;
  machine_status?: number | string;
  bind_status?: number | string;
}

export interface MachineStats {
  total: number;
  bound: number;
  trial: number;
  expired: number;
}

// ========== 收入相关 ==========
export interface Income {
  id: number;
  income_type: number;
  amount: number;
  source?: string;
  member_id?: number;
  member_name?: string;
  order_id?: number;
  order_no?: string;
  machine_id?: number;
  machine_code?: string;
  status: number;
  remark?: string;
  created_at: string;
}

export interface IncomeListParams {
  page?: number;
  pageSize?: number;
  income_type?: number | string;
  member_id?: number;
  machine_id?: number;
  order_id?: number;
  status?: number | string;
}

export interface IncomeStats {
  today: number;
  month: number;
  total: number;
  paid_users: number;
}

// ========== 激活码相关 ==========
export interface ActivationCode {
  id: number;
  code: string;
  bind_type: number; // 1-会员 2-设备 3-订单
  bind_id: number;
  product_id: number;
  product_name?: string;
  used_count: number;
  max_count: number;
  status: number; // 0-未激活 1-已激活 2-已过期 3-已禁用
  expire_time?: string;
  remark?: string;
  created_at: string;
}

export interface ActivationCodeListParams {
  bind_type: number;
  bind_id: number;
}

export interface ActivationCodeGenerateParams {
  bind_type: number;
  bind_id: number;
  product_id: number;
  expire_type: number;
  expire_time?: string;
  max_count: number;
  count: number;
  remark?: string;
}

// ========== 通用响应类型 ==========
export interface ApiResponse<T = unknown> {
  code: number;
  msg: string;
  data: T;
}

export interface PaginatedResponse<T> {
  list: T[];
  total: number;
  page: number;
  pageSize: number;
}
