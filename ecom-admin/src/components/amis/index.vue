<template>
  <div class="amis-wrapper">
    <div :id="containerId" ref="boxRef" class="amis-container"></div>
  </div>
</template>

<script setup lang="ts">
  import { ref, watch, onMounted, onUnmounted, nextTick, computed } from 'vue';
  import { Message } from '@arco-design/web-vue';
  import axios from 'axios';
  import request from '@/api/request';
  import { toAmisResponse } from '@/api/response';
  import copy from 'copy-to-clipboard';
  import { useAppStore } from '@/store';

  // @ts-ignore
  import { amisRequire } from 'amis';

  declare global {
    interface Window {
      amisRequire: any;
    }
  }

  interface Props {
    /** amis JSON 配置 */
    schema?: Record<string, any>;
    /** 主题: auto(跟随 Arco) | cxd(白色) | dark(暗色) | antd */
    theme?: string;
    /** 容器ID */
    containerId?: string;
    /** 主题色，会覆盖 amis 默认颜色 */
    themeColor?: string;
  }

  const props = withDefaults(defineProps<Props>(), {
    schema: () => ({}),
    theme: 'auto',
    containerId: 'amis-container',
    themeColor: '#165DFF',
  });

  const emit = defineEmits<{
    (e: 'inited', scoped: any): void;
    (e: 'error', error: any): void;
  }>();

  const boxRef = ref<HTMLElement | null>(null);
  let amisInstance: any = null;

  const appStore = useAppStore();

  // 根据 Arco Design 主题自动切换 amis theme
  const amisTheme = computed(() => {
    // 优先使用 props.theme，否则根据 Arco 主题自动切换
    if (props.theme && props.theme !== 'auto') {
      return props.theme;
    }
    return appStore.theme === 'dark' ? 'dark' : 'cxd';
  });

  // 加载脚本
  const loadScript = (src: string): Promise<void> => {
    return new Promise((resolve, reject) => {
      if (document.querySelector(`script[src="${src}"]`)) {
        resolve();
        return;
      }
      const script = document.createElement('script');
      script.src = src;
      script.onload = () => resolve();
      script.onerror = () => reject(new Error(`加载失败: ${src}`));
      document.head.appendChild(script);
    });
  };

  // 加载样式
  const loadStyles = () => {
    const currentTheme = amisTheme.value;

    // 基础样式（所有主题都需要）
    const baseStyles = ['/amis/sdk/sdk.css'];

    // 暗色主题需要额外加载官方暗色主题
    const darkStyles =
      currentTheme === 'dark'
        ? ['https://baidu.github.io/amis/n/amis/lib/themes/dark_32627ff.css']
        : [];

    const styles = [...baseStyles, ...darkStyles];

    styles.forEach((src) => {
      if (!document.querySelector(`link[href="${src}"]`)) {
        const link = document.createElement('link');
        link.rel = 'stylesheet';
        link.href = src;
        document.head.appendChild(link);
      }
    });
  };

  // 渲染amis
  // 渲染amis
  const renderAmis = () => {
    if (!boxRef.value) return;

    const amis = window.amisRequire('amis/embed');

    // 如果已有实例，先销毁
    if (amisInstance) {
      amisInstance.unmount();
    }

    const container = `#${props.containerId}`;

    // 在容器上添加theme class

    const containerEl = document.querySelector(container);
    if (containerEl) {
      // 移除旧的主题class
      containerEl.classList.remove('amis-cxd', 'amis-dark', 'amis-antd');
      // 添加新的主题class
      containerEl.classList.add(`amis-${amisTheme.value}`);
    }

    amisInstance = amis.embed(
      container,
      props.schema,
      {
        // locale: 'zh-CN',
        // 主题
        theme: amisTheme.value,
      },
      {
        // 跳转处理
        updateLocation: (to: string, replace: boolean) => {
          console.log('跳转:', to, replace);
        },
        // 请求适配器
        fetcher: async ({ url, method, data, headers, config }: any) => {
          config = config || {};
          config.withCredentials = true;

          // 处理 signal (AbortSignal) - 转换为 axios CancelToken
          if (config.signal) {
            config.cancelToken = new axios.CancelToken((cancel) => {
              if (config.signal && config.signal.addEventListener) {
                config.signal.addEventListener('abort', () => {
                  cancel('Request aborted');
                });
              }
            });
            // 删除 signal 属性，axios 0.24.0 不支持
            delete config.signal;
          }

          // 处理 cancelExecutor
          if (config.cancelExecutor) {
            config.cancelToken = new axios.CancelToken(config.cancelExecutor);
            delete config.cancelExecutor;
          }

          config.headers = headers || {};

          // 获取Token
          const token = localStorage.getItem('ecom.authorization');
          if (token) {
            config.headers.Authorization = `Bearer ${token}`;
          }

          let response;
          if (method !== 'post' && method !== 'put' && method !== 'patch') {
            if (data) {
              config.params = data;
            }
            response = await request(url, config, undefined, method);
          } else if (data && data instanceof FormData) {
            config.headers['Content-Type'] = 'multipart/form-data';
            response = await request(url, data, undefined, method, config);
          } else if (
            data &&
            typeof data !== 'string' &&
            !(data instanceof Blob) &&
            !(data instanceof ArrayBuffer)
          ) {
            data = JSON.stringify(data);
            config.headers['Content-Type'] = 'application/json';
            response = await request(url, data, undefined, method, config);
          } else {
            response = await request(url, data, undefined, method, config);
          }

          return toAmisResponse(response);
        },
        // 取消请求判断 - axios 0.24.0 没有 isCancel，使用 CancelToken 判断
        isCancel: (value: any) => {
          return axios.CancelToken && value instanceof axios.CancelToken;
        },
        // 复制功能
        copy: (content: string) => {
          copy(content);
          Message.success('内容已复制到剪贴板');
        },
        // 提示信息
        notify: (
          type: 'success' | 'error' | 'warning' | 'info',
          msg: string
        ) => {
          Message[type](msg);
        },
      }
    );

    emit('inited', amisInstance);
  };

  // 初始化amis
  const initAmis = async () => {
    if (!props.schema || Object.keys(props.schema).length === 0) {
      return;
    }

    await nextTick();

    // 动态加载 SDK
    try {
      // 先加载样式
      loadStyles();

      const sdkSrc = '/amis/sdk/sdk.js';
      await loadScript(sdkSrc);

      renderAmis();
    } catch (error) {
      console.error('加载amis SDK失败:', error);
      emit('error', error);
    }
  };

  // 监听 schema 变化重新渲染
  watch(
    () => props.schema,
    (newSchema) => {
      if (newSchema && Object.keys(newSchema).length > 0) {
        initAmis();
      }
    },
    { deep: true }
  );

  // 监听 Arco Design 主题变化，重新渲染 amis
  watch(
    () => appStore.theme,
    () => {
      if (props.theme === 'auto') {
        initAmis();
      }
    }
  );

  onMounted(() => {
    initAmis();
  });

  onUnmounted(() => {
    if (amisInstance) {
      try {
        amisInstance.unmount();
      } catch (e) {
        console.warn('销毁amis实例失败:', e);
      }
    }
  });

  // 暴露方法
  defineExpose({
    /** 获取amis实例 */
    getInstance: () => amisInstance,
    /** 重新渲染 */
    render: () => initAmis(),
  });
</script>

<style>
  /* 容器样式 - 隔离外部影响 */
  .amis-wrapper {
    width: 100%;
    min-height: 400px;
    position: relative;
    overflow: auto;
  }

  .amis-wrapper .amis-container {
    width: 100%;
    min-height: 400px;
  }

  /* 隔离外部样式 */
  .amis-wrapper .amis {
    all: initial;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
      'Helvetica Neue', Arial, sans-serif;
  }

  .amis-wrapper .amis * {
    box-sizing: border-box;
  }

  /* 主题色覆盖 - 使用更通用的选择器 */
  .amis-wrapper .amis .cxd-Button--primary,
  .amis-wrapper .amis .cxd-Action--primary,
  .amis-wrapper .amis .cxd-Button--primary:hover,
  .amis-wrapper .amis .cxd-Action--primary:hover {
    background-color: var(--amis-primary, #165dff);
    border-color: var(--amis-primary, #165dff);
  }

  /* 暗色主题下使用 Arco 主题色 */
  [arco-theme='dark'] .amis-wrapper .amis .cxd-Button--primary,
  [arco-theme='dark'] .amis-wrapper .amis .cxd-Action--primary {
    background-color: var(--color-primary, #4080ff);
    border-color: var(--color-primary, #4080ff);
  }
</style>
