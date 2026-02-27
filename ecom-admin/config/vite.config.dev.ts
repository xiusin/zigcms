import { mergeConfig } from 'vite';
import baseConfig from './vite.config.base';
import { viteMockPlugin } from '../src/mock/plugin';

const API_PROXY_TARGET = process.env.VITE_PROXY_TARGET || 'http://127.0.0.1:3000';

export default mergeConfig(
  {
    mode: 'development',
    server: {
      port: 3201,
      host: '0.0.0.0',
      open: false,
      fs: {
        strict: false,
        allow: ['..'],
      },
      proxy: {
        '/api': {
          target: API_PROXY_TARGET,
          changeOrigin: true,
        },
        '/be/api': {
          target: API_PROXY_TARGET,
          changeOrigin: true,
          rewrite: (path: string) => path.replace(/^\/be\/api/, '/api'),
        },
        '/amis-editor': {
          target: 'http://localhost:3201',
          changeOrigin: true,
          rewrite: (path: string) => {
            // 将 /amis-editor/... 转换为 /node_modules/amis-editor/dist/...
            return path.replace(/^\/amis-editor/, '/node_modules/amis-editor/dist');
          },
        },
        '/amis/sdk': {
          target: 'http://localhost:3201',
          changeOrigin: true,
          rewrite: (path: string) => {
            // 将 /amis/sdk/... 转换为 /node_modules/amis/sdk/...
            return path.replace(/^\/amis\/sdk/, '/node_modules/amis/sdk');
          },
        },
      },
    },
    plugins: [
      // Mock 插件 - 开发环境使用 Mock 数据
      viteMockPlugin({
        enable: true,
        timeout: 300,
      }),
    ],
  },
  baseConfig
);
