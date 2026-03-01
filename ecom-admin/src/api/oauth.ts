/**
 * OAuth 第三方登录 API 封装
 * 支持飞书、GitHub 第三方登录
 */
import request from './request';
import type { HttpResponse } from './request';

// ========== OAuth 相关类型定义 ==========

/** OAuth 登录提供商类型 */
export type OAuthProvider = 'feishu' | 'github';

/** OAuth 回调响应 */
export interface OAuthCallbackResponse {
  /** 访问令牌 */
  access_token: string;
  /** 刷新令牌 */
  refresh_token?: string;
  /** 令牌过期时间 */
  expires_in: number;
  /** 用户信息 */
  user: {
    /** 用户ID */
    id: string;
    /** 用户名 */
    username: string;
    /** 昵称 */
    nickname?: string;
    /** 邮箱 */
    email?: string;
    /** 头像URL */
    avatar_url?: string;
  };
  /** 第三方返回的原始数据 */
  raw_info?: Record<string, any>;
}

/** OAuth 绑定请求参数 */
export interface OAuthBindParams {
  /** OAuth 提供商 */
  provider: OAuthProvider;
  /** 第三方返回的授权码 */
  code: string;
  /** 回调状态参数 */
  state?: string;
}

/** OAuth 绑定响应 */
export interface OAuthBindResponse {
  /** 是否需要绑定现有账户 */
  need_bind: boolean;
  /** 用户信息（如果已绑定或自动注册） */
  user?: {
    id: number;
    username: string;
    nickname?: string;
    avatar?: string;
    email?: string;
  };
  /** 绑定信息 */
  bind_info?: {
    provider: OAuthProvider;
    provider_user_id: string;
    bind_time: string;
  };
}

/** OAuth 绑定账户请求 */
export interface OAuthBindAccountParams {
  /** OAuth 提供商 */
  provider: OAuthProvider;
  /** 第三方返回的授权码 */
  code: string;
  /** 现有账户ID（需要绑定的账户） */
  account_id: number;
  /** 账户密码（验证用） */
  password?: string;
}

/** 用户注册请求参数（OAuth 自动注册） */
export interface OAuthRegisterParams {
  /** OAuth 提供商 */
  provider: OAuthProvider;
  /** 第三方返回的授权码 */
  code: string;
  /** 注册用户名 */
  username: string;
  /** 昵称（可选） */
  nickname?: string;
}

// ========== OAuth API 接口 ==========

/**
 * 获取 OAuth 授权 URL
 * @param provider OAuth 提供商
 * @returns 授权跳转 URL
 */
export function getOAuthUrl(provider: OAuthProvider): Promise<HttpResponse<{ url: string }>> {
  return request.get('/api/oauth/authorize', {
    params: { provider },
  });
}

/**
 * 处理 OAuth 回调
 * @param params 回调参数
 * @returns 登录结果
 */
export function handleOAuthCallback(params: OAuthBindParams): Promise<HttpResponse<OAuthCallbackResponse>> {
  return request.post('/api/oauth/callback', params);
}

/**
 * 绑定 OAuth 账户
 * @param params 绑定参数
 * @returns 绑定结果
 */
export function bindOAuthAccount(params: OAuthBindAccountParams): Promise<HttpResponse<OAuthBindResponse>> {
  return request.post('/api/oauth/bind', params);
}

/**
 * 解绑 OAuth 账户
 * @param provider OAuth 提供商
 * @returns 解绑结果
 */
export function unbindOAuthAccount(provider: OAuthProvider): Promise<HttpResponse<null>> {
  return request.delete('/api/oauth/unbind', {
    params: { provider },
  });
}

/**
 * 获取当前用户绑定的 OAuth 账户列表
 * @returns 绑定列表
 */
export function getOAuthBindList(): Promise<HttpResponse<Array<{
  provider: OAuthProvider;
  provider_user_id: string;
  bind_time: string;
  nickname?: string;
  avatar_url?: string;
}>>> {
  return request.get('/api/oauth/bind/list');
}

/**
 * 前端直接构建 OAuth 授权 URL（跳转到第三方授权页面）
 */
export function buildOAuthAuthorizeUrl(provider: OAuthProvider): string {
  const { VITE_FEISHU_APP_ID, VITE_FEISHU_REDIRECT_URI, VITE_GITHUB_CLIENT_ID, VITE_GITHUB_REDIRECT_URI } = import.meta.env;

  const redirectUriMap: Record<OAuthProvider, string> = {
    feishu: VITE_FEISHU_REDIRECT_URI,
    github: VITE_GITHUB_REDIRECT_URI,
  };

  const clientIdMap: Record<OAuthProvider, string> = {
    feishu: VITE_FEISHU_APP_ID,
    github: VITE_GITHUB_CLIENT_ID,
  };

  const redirectUri = redirectUriMap[provider];
  const clientId = clientIdMap[provider];

  if (!clientId || !redirectUri) {
    console.error(`OAuth configuration missing for provider: ${provider}`);
    return '#';
  }

  // 生成随机 state 用于防止 CSRF
  const state = `${provider}_${Date.now()}_${Math.random().toString(36).substring(7)}`;
  // 存储 state 到 sessionStorage 用于回调验证
  sessionStorage.setItem('oauth_state', state);

  // 构建授权 URL
  if (provider === 'feishu') {
    return `https://open.feishu.cn/open-apis/authen/v1/authorize?app_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&state=${state}`;
  } else if (provider === 'github') {
    return `https://github.com/login/oauth/authorize?client_id=${clientId}&redirect_uri=${encodeURIComponent(redirectUri)}&scope=read:user+user:email&state=${state}`;
  }

  return '#';
}
