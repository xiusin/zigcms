import { defineStore } from 'pinia';
import { isArray, isString, toNumber } from 'lodash';
import {
  setToken,
  clearToken,
  setUser,
  clearUser,
  getUser,
  getToken,
} from '@/utils/auth';
import { removeRouteListener } from '@/utils/route-listener';
import request from '@/api/request';
import { UserState } from './types';
import useAppStore from '../app';

const useUserStore = defineStore('user', {
  state: (): UserState => ({
    id: undefined,
    create_user_id: undefined,
    company_id: undefined,
    username: undefined,
    email: undefined,
    realname: undefined,
    phone: undefined,
    qy_wchat_id: undefined,
    feishu_user_id: undefined,
    feishu_open_id: undefined,
    role_id: undefined,
    // role: undefined,
    department_id: undefined,
    state: undefined,
    group_id: undefined,
    is_assistant: undefined,
    add_time: undefined,
    update_time: undefined,
    entry_time: undefined,
    leave_time: undefined,
    avatar: undefined,
    assistant_user_id: undefined,
    supplier_type: undefined,
    is_from_saas: undefined,
    host: undefined,
    name: undefined,
    token: getToken(),
    // new 新属性
    role_ids: null,
    mobile: null,
    created_at: null,
    updated_at: null,
    status: null,
    pages: null,
    buttons: null,
    ...getUser(),
  }),

  getters: {
    userInfo(state: UserState): UserState {
      return { ...state };
    },
  },

  actions: {
    // 运营 [3, 31, 100]
    hasPermission(role: number | string | number[]): boolean {
      if (this.role_id === 1) return true;
      if (isArray(role)) {
        return role.includes(this.role_id);
      }
      if (isString(role)) {
        return toNumber(role) === this.role_id;
      }
      return role === this.role_id;
    },
    switchRoles(role: number) {
      return new Promise((resolve) => {
        this.role_id = role;
        resolve(this.role_id);
      });
    },
    // Set user's information
    setInfo(partial: Partial<UserState>) {
      this.$patch(partial);
      setUser(partial);
    },
    // Set user's information
    setStateInfo(partial: Partial<UserState>) {
      this.$patch(partial);
    },

    // Reset user's information
    resetInfo() {
      this.$reset();
    },

    async info() {},
    async login(loginForm: any) {
      try {
        const res: any = await request('/api/member/login', loginForm);
        // debugger;
        setToken(res.data.token);
        this.setInfo({ ...res.data });
      } catch (err) {
        clearToken();
        throw err;
      }
    },
    async refreshUserInfo() {
      try {
        const res: any = await request('/api/member/refreshInfo');
        setToken(res.data.token);
        this.setInfo({ ...res.data });
      } catch (err) {
        clearToken();
        throw err;
      }
    },
    logoutCallBack() {
      const appStore = useAppStore();
      this.resetInfo();
      clearToken();
      clearUser();
      removeRouteListener();
      appStore.clearServerMenu();
    },
    // Logout
    async logout() {
      this.logoutCallBack();
    },
  },
});

export default useUserStore;
