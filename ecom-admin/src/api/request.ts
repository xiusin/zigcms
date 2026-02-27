import axios from 'axios';
import type { AxiosResponse } from 'axios';
import { Message } from '@arco-design/web-vue';
import { getToken } from '@/utils/auth';
import { exportForm } from '@/utils/util';
import useUser from '@/hooks/user';
import { useUserStore } from '@/store';
import router from '@/router';
import { normalizeApiResponse } from './response';

// http method
export const METHOD = {
  GET: 'get',
  POST: 'post',
};

export interface HttpResponse<T = unknown> {
  msg: string;
  code: number;
  data: any | T;
}

const NODE_ENV = import.meta.env.VITE_NODE_ENV as string;

const instance = axios.create({
  baseURL: NODE_ENV === 'production' ? `${window.location.origin}/be` : '',
  // baseURL: `${window.location.origin}/be`,
});
/**
 * axios请求
 * @param url 请求地址
 * @param params 请求参数
 * @param signal {signal} 取消请求
 * @param method { "get" | "post" } http method
 * @param dconfig { object } 自定义配置
 * @returns {Promise<AxiosResponse<any>>}
 */
export default async function request(
  url: string,
  params?: any,
  signal?: any,
  method = 'post',
  dconfig = {}
): Promise<HttpResponse> {
  // 全局配置
  // let sysParams = {
  //   system_type: 'shentui',
  // };
  if (params?.export_now) {
    return exportForm(url, params);
  }

  const token = getToken();
  // 不是登录接口 则检验是否存在token
  if (!url.includes('login') && !token) {
    const { logout } = useUser();
    logout();
    return new Promise((resolve, reject) => {
      reject(new Error(`token失效-${url}-${token}`));
    });
  }
  const config: any = {
    headers: {
      Authorization: token ? `Bearer ${token}` : '',
    },
    ...dconfig,
  };
  switch (method) {
    case 'get':
      return instance.get(url, { params, ...config });
    case 'post':
    default:
      return instance.post(url, params, config);
  }
}

// 响应拦截器
instance.interceptors.response.use(
  (res: AxiosResponse): any => {
    if (res.headers['content-disposition']) {
      return Promise.resolve(res);
    }
    const normalized = normalizeApiResponse(res.data);
    if (normalized.code === 200) {
      return Promise.resolve({
        code: normalized.code,
        msg: normalized.msg || 'success',
        data: {
          ...(normalized.data && typeof normalized.data === 'object'
            ? normalized.data
            : {}),
          list: normalized.list,
          items: normalized.list,
          total: normalized.total,
          pagination: normalized.pagination,
        },
      });
    }
    if (normalized.code === 401) {
      if (router.currentRoute.value.name !== 'login') {
        useUserStore().logout();
        Message.error('登录失效，请重新登录');
        router.push({ name: 'login' });
      }
      return Promise.reject(new Error('登录失效'));
    }
    Message.error({
      content: JSON.stringify(normalized.msg || '网络错误'),
    });
    return Promise.reject({
      code: normalized.code,
      msg: normalized.msg || '网络错误',
      data: normalized.data,
    });
  },
  (error) => {
    if (!axios.isCancel(error)) {
      Message.error({
        content: JSON.stringify('网络错误'),
        resetOnHover: true,
      });
    }
    return Promise.reject(error);
  }
);
