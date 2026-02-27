import { Notification } from '@arco-design/web-vue';

export interface ToastOptions {
  title?: string;
  content: string;
  duration?: number;
  position?: 'topLeft' | 'topRight' | 'bottomLeft' | 'bottomRight';
}

export const toast = {
  success(options: string | ToastOptions) {
    const config = typeof options === 'string' ? { content: options } : options;
    Notification.success({
      title: config.title || '成功',
      content: config.content,
      duration: config.duration || 3000,
      position: config.position || 'topRight',
    });
  },

  error(options: string | ToastOptions) {
    const config = typeof options === 'string' ? { content: options } : options;
    Notification.error({
      title: config.title || '错误',
      content: config.content,
      duration: config.duration || 3000,
      position: config.position || 'topRight',
    });
  },

  warning(options: string | ToastOptions) {
    const config = typeof options === 'string' ? { content: options } : options;
    Notification.warning({
      title: config.title || '警告',
      content: config.content,
      duration: config.duration || 3000,
      position: config.position || 'topRight',
    });
  },

  info(options: string | ToastOptions) {
    const config = typeof options === 'string' ? { content: options } : options;
    Notification.info({
      title: config.title || '提示',
      content: config.content,
      duration: config.duration || 3000,
      position: config.position || 'topRight',
    });
  },
};
