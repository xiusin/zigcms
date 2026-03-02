/**
 * OAuth Token 自动刷新拦截器
 * 
 * 功能：
 * 1. 检测 401 错误自动刷新 Token
 * 2. 刷新成功后重试原请求
 * 3. 刷新失败后跳转登录页
 */

import axios, { AxiosError, InternalAxiosRequestConfig } from 'axios';
import { Message } from '@arco-design/web-vue';
import { refreshOAuthToken } from '@/api/oauth';

// Token 刷新状态
let isRefreshing = false;
let failedQueue: Array<{
  resolve: (value?: any) => void;
  reject: (reason?: any) => void;
}> = [];

/**
 * 处理等待队列
 */
const processQueue = (error: Error | null, token: string | null = null) => {
  failedQueue.forEach((prom) => {
    if (error) {
      prom.reject(error);
    } else {
      prom.resolve(token);
    }
  });

  failedQueue = [];
};

/**
 * 获取存储的 OAuth Token 信息
 */
const getOAuthTokenInfo = () => {
  const accessToken = localStorage.getItem('oauth_access_token');
  const refreshToken = localStorage.getItem('oauth_refresh_token');
  const provider = localStorage.getItem('oauth_provider');

  return { accessToken, refreshToken, provider };
};

/**
 * 保存新的 Token 信息
 */
const saveOAuthTokenInfo = (accessToken: string, refreshToken: string) => {
  localStorage.setItem('oauth_access_token', accessToken);
  localStorage.setItem('oauth_refresh_token', refreshToken);
};

/**
 * 清除 Token 信息并跳转登录
 */
const clearTokenAndRedirect = () => {
  localStorage.removeItem('oauth_access_token');
  localStorage.removeItem('oauth_refresh_token');
  localStorage.removeItem('oauth_provider');
  localStorage.removeItem('userInfo');
  
  Message.error('登录已过期，请重新登录');
  
  // 延迟跳转，避免多次触发
  setTimeout(() => {
    window.location.href = '/login';
  }, 1000);
};

/**
 * 刷新 OAuth Token
 */
const refreshToken = async (provider: string, refreshToken: string): Promise<string> => {
  try {
    const res = await refreshOAuthToken({
      provider,
      refresh_token: refreshToken,
    });

    if (res.code === 0 && res.data) {
      const { access_token, refresh_token } = res.data;
      saveOAuthTokenInfo(access_token, refresh_token);
      return access_token;
    }

    throw new Error('刷新 Token 失败');
  } catch (error) {
    console.error('刷新 Token 失败:', error);
    throw error;
  }
};

/**
 * 安装 OAuth Token 自动刷新拦截器
 */
export const setupOAuthRefreshInterceptor = () => {
  // 响应拦截器
  axios.interceptors.response.use(
    (response) => response,
    async (error: AxiosError) => {
      const originalRequest = error.config as InternalAxiosRequestConfig & {
        _retry?: boolean;
      };

      // 如果不是 401 错误，直接返回
      if (error.response?.status !== 401) {
        return Promise.reject(error);
      }

      // 如果已经重试过，不再重试
      if (originalRequest._retry) {
        clearTokenAndRedirect();
        return Promise.reject(error);
      }

      // 获取 OAuth Token 信息
      const { refreshToken: storedRefreshToken, provider } = getOAuthTokenInfo();

      // 如果没有 refresh_token 或 provider，跳转登录
      if (!storedRefreshToken || !provider) {
        clearTokenAndRedirect();
        return Promise.reject(error);
      }

      // 如果正在刷新 Token，将请求加入队列
      if (isRefreshing) {
        return new Promise((resolve, reject) => {
          failedQueue.push({ resolve, reject });
        })
          .then((token) => {
            if (originalRequest.headers) {
              originalRequest.headers.Authorization = `Bearer ${token}`;
            }
            return axios(originalRequest);
          })
          .catch((err) => Promise.reject(err));
      }

      // 标记为正在刷新
      originalRequest._retry = true;
      isRefreshing = true;

      try {
        // 刷新 Token
        const newAccessToken = await refreshToken(provider, storedRefreshToken);

        // 处理等待队列
        processQueue(null, newAccessToken);

        // 更新原请求的 Authorization 头
        if (originalRequest.headers) {
          originalRequest.headers.Authorization = `Bearer ${newAccessToken}`;
        }

        // 重试原请求
        return axios(originalRequest);
      } catch (refreshError) {
        // 刷新失败，清空队列并跳转登录
        processQueue(refreshError as Error, null);
        clearTokenAndRedirect();
        return Promise.reject(refreshError);
      } finally {
        isRefreshing = false;
      }
    }
  );

  console.log('✅ OAuth Token 自动刷新拦截器已安装');
};

/**
 * 检查 Token 是否即将过期（提前 5 分钟刷新）
 */
export const checkTokenExpiration = async () => {
  const { refreshToken: storedRefreshToken, provider } = getOAuthTokenInfo();

  if (!storedRefreshToken || !provider) {
    return;
  }

  // 这里可以添加 Token 过期时间检查逻辑
  // 如果即将过期（例如剩余 5 分钟），主动刷新
  // 需要后端返回 expires_at 时间戳
};
