/**
 * CRUD 性能优化工具
 * 请求合并、防抖节流、懒加载
 */

/* eslint-disable max-classes-per-file, @typescript-eslint/no-non-null-assertion */

/**
 * 请求队列管理器
 * 合并相同的请求，避免重复调用
 */
class RequestQueue {
  private pending: Map<string, Promise<any>> = new Map();

  async request<T>(key: string, fn: () => Promise<T>): Promise<T> {
    if (this.pending.has(key)) {
      return this.pending.get(key)!;
    }

    const promise = fn().finally(() => {
      this.pending.delete(key);
    });

    this.pending.set(key, promise);
    return promise;
  }

  clear() {
    this.pending.clear();
  }
}

export const requestQueue = new RequestQueue();

/**
 * 防抖函数
 */
export function debounce<T extends (...args: any[]) => any>(
  fn: T,
  delay: number
): (...args: Parameters<T>) => void {
  let timer: any;
  return (...args: Parameters<T>) => {
    clearTimeout(timer);
    timer = setTimeout(() => fn(...args), delay);
  };
}

/**
 * 节流函数
 */
export function throttle<T extends (...args: any[]) => any>(
  fn: T,
  delay: number
): (...args: Parameters<T>) => void {
  let last = 0;
  return (...args: Parameters<T>) => {
    const now = Date.now();
    if (now - last >= delay) {
      last = now;
      fn(...args);
    }
  };
}

/**
 * 批量请求管理器
 * 将多个请求合并为一个批量请求
 */
class BatchRequestManager {
  private queue: Array<{
    id: string;
    resolve: (value: any) => void;
    reject: (error: any) => void;
  }> = [];

  private timer: any;

  private batchSize = 10;

  private delay = 100;

  request<T>(id: string, api: string): Promise<T> {
    return new Promise((resolve, reject) => {
      this.queue.push({ id, resolve, reject });

      clearTimeout(this.timer);
      this.timer = setTimeout(() => {
        this.flush(api);
      }, this.delay);

      if (this.queue.length >= this.batchSize) {
        this.flush(api);
      }
    });
  }

  private async flush(api: string) {
    if (this.queue.length === 0) return;

    const batch = this.queue.splice(0, this.batchSize);
    const ids = batch.map((item) => item.id);

    try {
      const response = await fetch(api, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ids }),
      });
      const result = await response.json();

      batch.forEach((item) => {
        const data = result.data?.find((d: any) => d.id === item.id);
        if (data) {
          item.resolve(data);
        } else {
          item.reject(new Error('数据不存在'));
        }
      });
    } catch (error) {
      batch.forEach((item) => item.reject(error));
    }
  }
}

export const batchRequestManager = new BatchRequestManager();

/**
 * 虚拟滚动优化
 * 计算可见区域，只渲染可见项
 */
export interface VirtualScrollConfig {
  itemHeight: number;
  containerHeight: number;
  buffer?: number; // 缓冲区项数
}

export class VirtualScroller {
  private itemHeight: number;

  private containerHeight: number;

  private buffer: number;

  constructor(config: VirtualScrollConfig) {
    this.itemHeight = config.itemHeight;
    this.containerHeight = config.containerHeight;
    this.buffer = config.buffer || 5;
  }

  getVisibleRange(scrollTop: number, totalItems: number) {
    const start = Math.max(
      0,
      Math.floor(scrollTop / this.itemHeight) - this.buffer
    );
    const visibleCount = Math.ceil(this.containerHeight / this.itemHeight);
    const end = Math.min(totalItems, start + visibleCount + this.buffer * 2);

    return { start, end };
  }

  getOffsetY(index: number) {
    return index * this.itemHeight;
  }

  getTotalHeight(totalItems: number) {
    return totalItems * this.itemHeight;
  }
}

/**
 * 懒加载图片
 */
export class LazyImageLoader {
  private observer: IntersectionObserver;

  private images: Set<HTMLImageElement> = new Set();

  constructor() {
    this.observer = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            const img = entry.target as HTMLImageElement;
            const { src } = img.dataset;
            if (src) {
              img.src = src;
              this.observer.unobserve(img);
              this.images.delete(img);
            }
          }
        });
      },
      { rootMargin: '50px' }
    );
  }

  observe(img: HTMLImageElement) {
    this.images.add(img);
    this.observer.observe(img);
  }

  unobserve(img: HTMLImageElement) {
    this.images.delete(img);
    this.observer.unobserve(img);
  }

  disconnect() {
    this.observer.disconnect();
    this.images.clear();
  }
}

/**
 * 数据预加载
 */
export class DataPreloader {
  private cache: Map<string, any> = new Map();

  private loading: Set<string> = new Set();

  async preload(key: string, loader: () => Promise<any>): Promise<void> {
    if (this.cache.has(key) || this.loading.has(key)) {
      return;
    }

    this.loading.add(key);
    try {
      const data = await loader();
      this.cache.set(key, data);
    } finally {
      this.loading.delete(key);
    }
  }

  get(key: string): any | undefined {
    return this.cache.get(key);
  }

  has(key: string): boolean {
    return this.cache.has(key);
  }

  clear() {
    this.cache.clear();
    this.loading.clear();
  }
}

export const dataPreloader = new DataPreloader();

/**
 * 内存优化：大数据分页处理
 */
export function* chunkArray<T>(array: T[], size: number): Generator<T[]> {
  for (let i = 0; i < array.length; i += size) {
    yield array.slice(i, i + size);
  }
}

/**
 * 性能监控
 */
export class PerformanceMonitor {
  private marks: Map<string, number> = new Map();

  start(name: string) {
    this.marks.set(name, performance.now());
  }

  end(name: string): number {
    const start = this.marks.get(name);
    if (!start) {
      console.warn(`未找到性能标记: ${name}`);
      return 0;
    }

    const duration = performance.now() - start;
    this.marks.delete(name);

    if (duration > 1000) {
      console.warn(`${name} 耗时过长: ${duration.toFixed(2)}ms`);
    }

    return duration;
  }

  measure(name: string, fn: () => any): any {
    this.start(name);
    const result = fn();
    this.end(name);
    return result;
  }

  async measureAsync(name: string, fn: () => Promise<any>): Promise<any> {
    this.start(name);
    const result = await fn();
    this.end(name);
    return result;
  }
}

export const performanceMonitor = new PerformanceMonitor();
