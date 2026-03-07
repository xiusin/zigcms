/**
 * 操作反馈工具函数
 * 提供统一的 Toast、Modal 确认、加载状态管理
 */

import { Message, Modal } from '@arco-design/web-vue';
import type { MessageReturn } from '@arco-design/web-vue/es/message/interface';

// Toast 提示类型
export type ToastType = 'success' | 'error' | 'warning' | 'info';

// 加载状态管理
class LoadingManager {
  private loadingInstances: Map<string, MessageReturn> = new Map();

  /**
   * 显示加载提示
   * @param key 唯一标识
   * @param content 提示内容
   * @param duration 持续时间（0 表示不自动关闭）
   */
  show(key: string, content: string = '加载中...', duration: number = 0): void {
    // 如果已存在，先关闭
    if (this.loadingInstances.has(key)) {
      this.hide(key);
    }

    const instance = Message.loading({
      content,
      duration,
      id: key,
    });

    this.loadingInstances.set(key, instance);
  }

  /**
   * 隐藏加载提示
   * @param key 唯一标识
   */
  hide(key: string): void {
    const instance = this.loadingInstances.get(key);
    if (instance) {
      instance.close();
      this.loadingInstances.delete(key);
    }
  }

  /**
   * 隐藏所有加载提示
   */
  hideAll(): void {
    this.loadingInstances.forEach((instance) => {
      instance.close();
    });
    this.loadingInstances.clear();
  }
}

export const loading = new LoadingManager();

/**
 * 显示成功提示
 * @param content 提示内容
 * @param duration 持续时间（毫秒）
 */
export function showSuccess(content: string, duration: number = 2000): void {
  Message.success({
    content,
    duration,
  });
}

/**
 * 显示错误提示
 * @param content 提示内容
 * @param duration 持续时间（毫秒）
 */
export function showError(content: string, duration: number = 3000): void {
  Message.error({
    content,
    duration,
  });
}

/**
 * 显示警告提示
 * @param content 提示内容
 * @param duration 持续时间（毫秒）
 */
export function showWarning(content: string, duration: number = 2500): void {
  Message.warning({
    content,
    duration,
  });
}

/**
 * 显示信息提示
 * @param content 提示内容
 * @param duration 持续时间（毫秒）
 */
export function showInfo(content: string, duration: number = 2000): void {
  Message.info({
    content,
    duration,
  });
}

/**
 * 显示 Toast 提示（通用）
 * @param type 提示类型
 * @param content 提示内容
 * @param duration 持续时间（毫秒）
 */
export function showToast(
  type: ToastType,
  content: string,
  duration?: number
): void {
  switch (type) {
    case 'success':
      showSuccess(content, duration);
      break;
    case 'error':
      showError(content, duration);
      break;
    case 'warning':
      showWarning(content, duration);
      break;
    case 'info':
      showInfo(content, duration);
      break;
  }
}

/**
 * 确认对话框选项
 */
export interface ConfirmOptions {
  title?: string;
  content: string;
  okText?: string;
  cancelText?: string;
  type?: 'info' | 'success' | 'warning' | 'error';
  okButtonProps?: Record<string, any>;
  cancelButtonProps?: Record<string, any>;
}

/**
 * 显示确认对话框
 * @param options 对话框选项
 * @returns Promise<boolean> 用户是否确认
 */
export function showConfirm(options: ConfirmOptions): Promise<boolean> {
  return new Promise((resolve) => {
    Modal.confirm({
      title: options.title || '确认操作',
      content: options.content,
      okText: options.okText || '确定',
      cancelText: options.cancelText || '取消',
      okButtonProps: options.okButtonProps || { status: 'normal' },
      cancelButtonProps: options.cancelButtonProps,
      onOk: () => {
        resolve(true);
      },
      onCancel: () => {
        resolve(false);
      },
    });
  });
}

/**
 * 显示删除确认对话框
 * @param content 提示内容
 * @param title 标题
 * @returns Promise<boolean> 用户是否确认
 */
export function showDeleteConfirm(
  content: string = '确定要删除吗？此操作不可恢复。',
  title: string = '删除确认'
): Promise<boolean> {
  return showConfirm({
    title,
    content,
    okText: '删除',
    cancelText: '取消',
    type: 'warning',
    okButtonProps: { status: 'danger' },
  });
}

/**
 * 显示批量操作确认对话框
 * @param count 操作数量
 * @param action 操作名称
 * @returns Promise<boolean> 用户是否确认
 */
export function showBatchConfirm(
  count: number,
  action: string = '操作'
): Promise<boolean> {
  return showConfirm({
    title: '批量操作确认',
    content: `确定要对选中的 ${count} 项执行${action}吗？`,
    okText: '确定',
    cancelText: '取消',
    type: 'warning',
  });
}

/**
 * 异步操作包装器
 * 自动显示加载状态和结果提示
 * @param fn 异步函数
 * @param options 选项
 * @returns Promise<T>
 */
export async function withFeedback<T>(
  fn: () => Promise<T>,
  options: {
    loadingText?: string;
    successText?: string;
    errorText?: string;
    showSuccess?: boolean;
    showError?: boolean;
    loadingKey?: string;
  } = {}
): Promise<T> {
  const {
    loadingText = '处理中...',
    successText = '操作成功',
    errorText = '操作失败',
    showSuccess = true,
    showError = true,
    loadingKey = 'default',
  } = options;

  // 显示加载状态
  loading.show(loadingKey, loadingText);

  try {
    const result = await fn();

    // 隐藏加载状态
    loading.hide(loadingKey);

    // 显示成功提示
    if (showSuccess) {
      showSuccess(successText);
    }

    return result;
  } catch (error: any) {
    // 隐藏加载状态
    loading.hide(loadingKey);

    // 显示错误提示
    if (showError) {
      const message = error?.message || error?.msg || errorText;
      showError(message);
    }

    throw error;
  }
}

/**
 * 按钮加载状态管理
 */
export class ButtonLoadingManager {
  private loadingStates: Map<string, boolean> = new Map();

  /**
   * 设置按钮加载状态
   * @param key 按钮唯一标识
   * @param loading 是否加载中
   */
  setLoading(key: string, loading: boolean): void {
    this.loadingStates.set(key, loading);
  }

  /**
   * 获取按钮加载状态
   * @param key 按钮唯一标识
   * @returns 是否加载中
   */
  isLoading(key: string): boolean {
    return this.loadingStates.get(key) || false;
  }

  /**
   * 清除按钮加载状态
   * @param key 按钮唯一标识
   */
  clear(key: string): void {
    this.loadingStates.delete(key);
  }

  /**
   * 清除所有按钮加载状态
   */
  clearAll(): void {
    this.loadingStates.clear();
  }
}

export const buttonLoading = new ButtonLoadingManager();

/**
 * 防抖函数
 * @param fn 函数
 * @param delay 延迟时间（毫秒）
 * @returns 防抖后的函数
 */
export function debounce<T extends (...args: any[]) => any>(
  fn: T,
  delay: number = 300
): (...args: Parameters<T>) => void {
  let timer: ReturnType<typeof setTimeout> | null = null;

  return function (this: any, ...args: Parameters<T>) {
    if (timer) {
      clearTimeout(timer);
    }

    timer = setTimeout(() => {
      fn.apply(this, args);
      timer = null;
    }, delay);
  };
}

/**
 * 节流函数
 * @param fn 函数
 * @param delay 延迟时间（毫秒）
 * @returns 节流后的函数
 */
export function throttle<T extends (...args: any[]) => any>(
  fn: T,
  delay: number = 300
): (...args: Parameters<T>) => void {
  let lastTime = 0;

  return function (this: any, ...args: Parameters<T>) {
    const now = Date.now();

    if (now - lastTime >= delay) {
      fn.apply(this, args);
      lastTime = now;
    }
  };
}

/**
 * 操作反馈装饰器
 * 用于 Vue 组件方法
 */
export function withOperationFeedback(
  loadingText: string = '处理中...',
  successText: string = '操作成功',
  errorText: string = '操作失败'
) {
  return function (
    target: any,
    propertyKey: string,
    descriptor: PropertyDescriptor
  ) {
    const originalMethod = descriptor.value;

    descriptor.value = async function (this: any, ...args: any[]) {
      const loadingKey = `${propertyKey}_${Date.now()}`;
      loading.show(loadingKey, loadingText);

      try {
        const result = await originalMethod.apply(this, args);
        loading.hide(loadingKey);
        showSuccess(successText);
        return result;
      } catch (error: any) {
        loading.hide(loadingKey);
        const message = error?.message || error?.msg || errorText;
        showError(message);
        throw error;
      }
    };

    return descriptor;
  };
}

// 导出默认对象
export default {
  loading,
  showSuccess,
  showError,
  showWarning,
  showInfo,
  showToast,
  showConfirm,
  showDeleteConfirm,
  showBatchConfirm,
  withFeedback,
  buttonLoading,
  debounce,
  throttle,
  withOperationFeedback,
};
