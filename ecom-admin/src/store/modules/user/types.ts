export type RoleType = '' | '*' | 'admin' | 'user';

export interface UserState {
  id?: number;
  create_user_id?: number;
  company_id?: number;
  username?: string;
  email?: string;
  realname?: string;
  phone?: string;
  qy_wchat_id?: string | number;
  feishu_user_id?: string | number;
  feishu_open_id?: string | number;
  role_id: number;
  role_ids: Array<number>;
  // role: number;
  department_id?: number;
  state?: number;
  group_id?: number;
  is_assistant?: number;
  add_time?: string;
  update_time?: string;
  entry_time?: string;
  leave_time?: string;
  avatar?: string;
  assistant_user_id?: number;
  supplier_type?: number;
  is_from_saas?: number;
  token?: string;
  host?: string;
  name?: string;
  // 页面权限
  pages?: string[];
  // 按钮权限
  buttons?: string[];
}
