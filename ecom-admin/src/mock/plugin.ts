/**
 * Vite Mock 插件
 * 用于在开发环境中拦截 API 请求并返回 Mock 数据
 */
import type { Plugin } from 'vite';
import { mockData } from './data';

interface MockConfig {
  enable?: boolean;
  timeout?: number;
}

export function viteMockPlugin(config: MockConfig = {}): Plugin {
  const { enable = true, timeout = 300 } = config;

  return {
    name: 'vite-plugin-mock',
    configureServer(server) {
      if (!enable) return;

      server.middlewares.use(async (req, res, next) => {
        const url = req.url || '';

        // 只拦截 API 请求
        if (!url.startsWith('/api') && !url.startsWith('/be/api')) {
          return next();
        }

        // 查找匹配的 Mock 数据
        const mockKey = url.split('?')[0];
        const mockItem = mockData[mockKey];

        if (mockItem) {
          // 模拟网络延迟
          setTimeout(() => {
            // 设置响应头
            res.setHeader('Content-Type', 'application/json');

            // 返回 Mock 数据
            const responseData =
              typeof mockItem === 'function' ? mockItem(req) : mockItem;
            res.end(JSON.stringify(responseData));
          }, timeout);
          return;
        }

        // 没有匹配的 Mock 数据，继续转发
        next();
      });
    },
  };
}

export default viteMockPlugin;
