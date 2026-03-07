/**
 * CSRF Token 处理工具
 */

/**
 * 从 Cookie 获取 CSRF Token
 */
export function getCsrfToken(): string | null {
  const cookies = document.cookie.split('; ');
  const csrfCookie = cookies.find(row => row.startsWith('csrf_token='));
  
  if (csrfCookie) {
    return csrfCookie.split('=')[1];
  }
  
  return null;
}

/**
 * 设置 CSRF Token 到请求头
 */
export function setCsrfTokenHeader(headers: Record<string, string> = {}): Record<string, string> {
  const token = getCsrfToken();
  
  if (token) {
    headers['X-CSRF-Token'] = token;
  }
  
  return headers;
}

/**
 * 刷新 CSRF Token
 */
export async function refreshCsrfToken(): Promise<string | null> {
  try {
    const response = await fetch('/api/auth/csrf-token', {
      method: 'GET',
      credentials: 'include'
    });
    
    if (response.ok) {
      const data = await response.json();
      return data.token;
    }
  } catch (error) {
    console.error('Failed to refresh CSRF token:', error);
  }
  
  return null;
}

/**
 * 验证 CSRF Token 是否有效
 */
export function isCsrfTokenValid(): boolean {
  const token = getCsrfToken();
  return token !== null && token.length > 0;
}

/**
 * CSRF Token 拦截器（用于 axios）
 */
export function csrfInterceptor(config: any) {
  // 只对非安全方法添加 CSRF Token
  const safeMethods = ['GET', 'HEAD', 'OPTIONS'];
  
  if (!safeMethods.includes(config.method?.toUpperCase())) {
    const token = getCsrfToken();
    
    if (token) {
      config.headers['X-CSRF-Token'] = token;
    } else {
      console.warn('CSRF token not found, request may be rejected');
    }
  }
  
  return config;
}

/**
 * CSRF 错误处理
 */
export function handleCsrfError(error: any) {
  if (error.response?.status === 403 && error.response?.data?.message?.includes('CSRF')) {
    console.error('CSRF token invalid or missing');
    
    // 尝试刷新 Token
    refreshCsrfToken().then(token => {
      if (token) {
        console.log('CSRF token refreshed, please retry the request');
        // 可以触发重试逻辑
      }
    });
  }
}
