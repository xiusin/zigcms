/**
 * 数据缓存工具 — staleTime 缓存策略
 * 【功能】减少重复API请求，过期自动刷新
 * 【高级特性】泛型缓存、TTL控制、手动失效、全局清除
 */

interface CacheEntry<T> {
  data: T;
  fetchedAt: number;
  staleTime: number;
}

class DataCache {
  private cache = new Map<string, CacheEntry<unknown>>();

  /** 读缓存，未过期则返回数据 */
  get<T>(key: string): T | null {
    const entry = this.cache.get(key) as CacheEntry<T> | undefined;
    if (!entry) return null;
    if (Date.now() - entry.fetchedAt > entry.staleTime) {
      this.cache.delete(key);
      return null;
    }
    return entry.data;
  }

  /** 写缓存 */
  set<T>(key: string, data: T, staleTime: number): void {
    this.cache.set(key, { data, fetchedAt: Date.now(), staleTime });
  }

  /** 手动失效某个key */
  invalidate(key: string): void {
    this.cache.delete(key);
  }

  /** 按前缀失效 */
  invalidateByPrefix(prefix: string): void {
    for (const key of this.cache.keys()) {
      if (key.startsWith(prefix)) {
        this.cache.delete(key);
      }
    }
  }

  /** 全局清除 */
  clear(): void {
    this.cache.clear();
  }

  /** 缓存条目数 */
  get size(): number {
    return this.cache.size;
  }
}

/** 全局单例 */
export const dataCache = new DataCache();

/** 默认staleTime配置（毫秒） */
export const STALE_TIMES = {
  /** 脑图数据 5分钟 */
  MINDMAP: 5 * 60 * 1000,
  /** 报表列表 2分钟 */
  REPORT_LIST: 2 * 60 * 1000,
  /** 概览数据 1分钟 */
  OVERVIEW: 60 * 1000,
  /** 邮件模板 10分钟 */
  EMAIL_TEMPLATE: 10 * 60 * 1000,
  /** 报表模板 10分钟 */
  REPORT_TEMPLATE: 10 * 60 * 1000,
  /** AI分析结果 3分钟 */
  AI_ANALYSIS: 3 * 60 * 1000,
} as const;

/**
 * 带缓存的数据获取
 * @param key 缓存key
 * @param fetcher 实际请求函数
 * @param staleTime 缓存有效期(ms)
 * @param forceRefresh 是否强制刷新
 */
export async function cachedFetch<T>(
  key: string,
  fetcher: () => Promise<T>,
  staleTime: number,
  forceRefresh = false
): Promise<T> {
  if (!forceRefresh) {
    const cached = dataCache.get<T>(key);
    if (cached !== null) {
      console.log(`[缓存][命中][${key}]`);
      return cached;
    }
  }
  const data = await fetcher();
  dataCache.set(key, data, staleTime);
  console.log(`[缓存][写入][${key}][staleTime=${staleTime}ms]`);
  return data;
}
