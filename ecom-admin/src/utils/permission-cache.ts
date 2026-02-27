import { ref } from 'vue';

// 权限缓存配置
const CACHE_KEY = 'ecom_permissions';
const CACHE_EXPIRY_KEY = 'ecom_permissions_expiry';

// 默认缓存时间：30分钟
const DEFAULT_CACHE_DURATION = 30 * 60 * 1000;

interface PermissionCache {
  pages: string[];
  buttons: string[];
  role_ids: number[];
  timestamp: number;
}

// 内存缓存
const memoryCache = ref<PermissionCache | null>(null);

/**
 * 获取权限缓存
 * @param customDuration 自定义缓存时间（毫秒）
 */
export function getPermissionCache(
  customDuration?: number
): PermissionCache | null {
  const now = Date.now();

  // 优先从内存缓存获取
  if (memoryCache.value) {
    const expiry = customDuration || DEFAULT_CACHE_DURATION;
    if (now - memoryCache.value.timestamp < expiry) {
      return memoryCache.value;
    }
  }

  // 从 localStorage 获取
  try {
    const cached = localStorage.getItem(CACHE_KEY);
    if (cached) {
      const cacheData: PermissionCache = JSON.parse(cached);
      const expiry = customDuration || DEFAULT_CACHE_DURATION;
      if (now - cacheData.timestamp < expiry) {
        memoryCache.value = cacheData;
        return cacheData;
      }
    }
  } catch (e) {
    console.error('读取权限缓存失败:', e);
  }

  return null;
}

/**
 * 设置权限缓存
 * @param permissions 权限数据
 */
export function setPermissionCache(permissions: {
  pages?: string[];
  buttons?: string[];
  role_ids?: number[];
}): void {
  const cacheData: PermissionCache = {
    pages: permissions.pages || [],
    buttons: permissions.buttons || [],
    role_ids: permissions.role_ids || [],
    timestamp: Date.now(),
  };

  // 保存到内存
  memoryCache.value = cacheData;

  // 保存到 localStorage
  try {
    localStorage.setItem(CACHE_KEY, JSON.stringify(cacheData));
  } catch (e) {
    console.error('保存权限缓存失败:', e);
  }
}

/**
 * 清除权限缓存
 */
export function clearPermissionCache(): void {
  memoryCache.value = null;
  try {
    localStorage.removeItem(CACHE_KEY);
    localStorage.removeItem(CACHE_EXPIRY_KEY);
  } catch (e) {
    console.error('清除权限缓存失败:', e);
  }
}

/**
 * 检查是否有按钮权限
 * @param permission 权限标识
 */
export function hasButtonPermission(permission: string): boolean {
  const cache = getPermissionCache();
  if (!cache) return false;

  // 超级管理员拥有所有权限
  if (cache.role_ids.includes(1)) return true;

  return cache.buttons.includes(permission);
}

/**
 * 检查是否有页面权限
 * @param page 页面标识
 */
export function hasPagePermission(page: string): boolean {
  const cache = getPermissionCache();
  if (!cache) return false;

  // 超级管理员拥有所有权限
  if (cache.role_ids.includes(1)) return true;

  return cache.pages.includes(page);
}

/**
 * 权限缓存Hook
 */
export function usePermissionCache() {
  const isCacheValid = ref(false);

  const checkCache = () => {
    const cache = getPermissionCache();
    isCacheValid.value = !!cache;
    return cache;
  };

  const updateCache = (permissions: {
    pages?: string[];
    buttons?: string[];
    role_ids?: number[];
  }) => {
    setPermissionCache(permissions);
    isCacheValid.value = true;
  };

  const cleanCache = () => {
    clearPermissionCache();
    isCacheValid.value = false;
  };

  return {
    isCacheValid,
    checkCache,
    updateCache,
    cleanCache,
    hasButtonPermission,
    hasPagePermission,
  };
}

export default {
  getPermissionCache,
  setPermissionCache,
  clearPermissionCache,
  hasButtonPermission,
  hasPagePermission,
  usePermissionCache,
};
