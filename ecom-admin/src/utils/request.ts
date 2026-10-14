/**
 * HTTP 请求工具
 * 
 * 功能：
 * - 统一请求配置
 * - 请求/响应拦截
 * - 错误处理
 * - CSRF Token 自动携带
 * - 认证 Token 管理
 */

import axios, { AxiosInstance, AxiosRequestConfig, AxiosResponse, AxiosError } from 'axios';
import { Message } from '@arco-design/web-vue';

// 创建 axios 实例
const request: AxiosInstance = axios.create({
  baseURL: import.meta.env.VITE_API_BASE_URL || '/api',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json',
  },
  withCredentials: true, // 允许携带 Cookie
});

/**
 * 从 Cookie 读取 CSRF Token
 */
function getCsrfToken(): string | null {
  const match = document.cookie.match(/csrf_token=([^;]+)/);
  return match ? match[1] : null;
}

/**
 * 从 localStorage 读取认证 Token
 */
function getAuthToken(): string | null {
  return localStorage.getItem('token');
}

/**
 * 保存认证 Token
 */
export function setAuthToken(token: string): void {
  localStorage.setItem('token', token);
}

/**
 * 清除认证 Token
 */
export function clearAuthToken(): void {
  localStorage.removeItem('token');
}

/**
 * 请求拦截器
 */
request.interceptors.request.use(
  (config: AxiosRequestConfig) => {
    // 1. 添加认证 Token
    const authToken = getAuthToken();
    if (authToken && config.headers) {
      config.headers.Authorization = `Bearer ${authToken}`;
    }
    
    // 2. 添加 CSRF Token（非安全方法）
    const method = config.method?.toUpperCase();
    if (method && !['GET', 'HEAD', 'OPTIONS'].includes(method)) {
      const csrfToken = getCsrfToken();
      if (csrfToken && config.headers) {
        config.headers['X-CSRF-Token'] = csrfToken;
      }
    }
    
    // 3. 打印请求日志（开发环境）
    if (import.meta.env.DEV) {
      console.log(`[Request] ${config.method?.toUpperCase()} ${config.url}`, config.data);
    }
    
    return config;
  },
  (error: AxiosError) => {
    console.error('[Request Error]', error);
    return Promise.reject(error);
  }
);

/**
 * 响应拦截器
 */
request.interceptors.response.use(
  (response: AxiosResponse) => {
    // 打印响应日志（开发环境）
    if (import.meta.env.DEV) {
      console.log(`[Response] ${response.config.method?.toUpperCase()} ${response.config.url}`, response.data);
    }
    
    // 返回数据
    return response.data;
  },
  (error: AxiosError) => {
    // 错误处理
    if (error.response) {
      const { status, data } = error.response;
      
      switch (status) {
        case 401:
          // 未登录或 Token 过期
          Message.error('登录已过期，请重新登录');
          clearAuthToken();
          // 跳转到登录页
          window.location.href = '/login';
          break;
          
        case 403:
          // 权限不足或 CSRF Token 验证失败
          if (data && typeof data === 'object' && 'message' in data) {
            const message = (data as any).message;
            if (message && typeof message === 'string' && message.includes('CSRF')) {
              Message.error('CSRF Token 验证失败，请刷新页面');
              // 可选：自动刷新页面
              setTimeout(() => {
                window.location.reload();
              }, 1500);
            } else {
              Message.error('权限不足');
            }
          } else {
            Message.error('权限不足');
          }
          break;
          
        case 404:
          // 资源不存在
          Message.error('请求的资源不存在');
          break;
          
        case 500:
          // 服务器错误
          Message.error('服务器内部错误');
          break;
          
        default:
          // 其他错误
          if (data && typeof data === 'object' && 'message' in data) {
            Message.error((data as any).message || '请求失败');
          } else {
            Message.error('请求失败');
          }
      }
    } else if (error.request) {
      // 请求已发送但没有收到响应
      Message.error('网络错误，请检查网络连接');
    } else {
      // 请求配置错误
      Message.error('请求配置错误');
    }
    
    console.error('[Response Error]', error);
    return Promise.reject(error);
  }
);

/**
 * 获取 CSRF Token
 */
export async function fetchCsrfToken(): Promise<void> {
  try {
    await request.get('/csrf-token');
  } catch (error) {
    console.error('获取 CSRF Token 失败', error);
  }
}

export default request;
