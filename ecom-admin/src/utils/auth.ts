// 环境变量可能缺失时提供安全兜底，避免 undefined 键导致 token/过期时间相互覆盖
const {
  VITE_TOKEN_KEY: ENV_TOKEN_KEY,
  VITE_TOKEN_EXPIRED_KEY: ENV_TOKEN_EXPIRED_KEY,
  VITE_USER_KEY: ENV_USER_KEY,
} = import.meta.env;

export const VITE_TOKEN_KEY = ENV_TOKEN_KEY || 'VITE_TOKEN';
export const VITE_TOKEN_EXPIRED_KEY = ENV_TOKEN_EXPIRED_KEY || 'VITE_TOKEN_EXPIRED';
export const VITE_USER_KEY = ENV_USER_KEY || 'VITE_USER_INFO';

export const getToken = (): string => {
  const stored: string = localStorage.getItem(VITE_TOKEN_KEY) || '';
  const token = stored.startsWith('Bearer ') ? stored.slice(7) : stored;
  const expireTime = localStorage.getItem(VITE_TOKEN_EXPIRED_KEY);
  if (expireTime) {
    if (parseInt(expireTime, 10) > Date.now()) {
      return token;
    }
    return '';
  }

  return token;
};

export const isLogin = () => {
  return !!getToken();
};

export const setToken = (
  token: string,
  expireTime = 7 * 24 * 60 * 60 * 1000
) => {
  localStorage.setItem(VITE_TOKEN_KEY, token);
  localStorage.setItem(VITE_TOKEN_EXPIRED_KEY, String(Date.now() + expireTime));
};

export const clearToken = () => {
  localStorage.removeItem(VITE_TOKEN_KEY);
  localStorage.removeItem(VITE_TOKEN_EXPIRED_KEY);
};

export const getUser = (): any => {
  let userInfo: any = localStorage.getItem(VITE_USER_KEY) || '';
  try {
    userInfo = JSON.parse(userInfo);
  } catch (e) {
    userInfo = {};
  }
  return userInfo;
};

export const setUser = (userInfo: any) => {
  localStorage.setItem(VITE_USER_KEY, JSON.stringify(userInfo));
};

export const clearUser = () => {
  localStorage.removeItem(VITE_USER_KEY);
};
