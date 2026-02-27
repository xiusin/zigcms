import { mergeConfig } from 'vite';
import baseConfig from './vite.config.base';
import { viteMockPlugin } from '../src/mock/plugin';

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
        '/amis-editor': {
          target: 'http://localhost:3201',
          changeOrigin: true,
          rewrite: (path) => {
            // 将 /amis-editor/... 转换为 /node_modules/amis-editor/dist/...
            return path.replace(/^\/amis-editor/, '/node_modules/amis-editor/dist');
          },
        },
        '/amis/sdk': {
          target: 'http://localhost:3201',
          changeOrigin: true,
          rewrite: (path) => {
            // 将 /amis/sdk/... 转换为 /node_modules/amis/sdk/...
            return path.replace(/^\/amis\/sdk/, '/node_modules/amis/sdk');
          },
        },
      },
      // 开发环境下不代理到后端，使用 Mock 数据
      // proxy: {
      //   '/api': {
      //     target: 'http://10.200.16.50:9401/be',
      //     changeOrigin: true,
      //   },
      //   '/be/api': {
      //     target: 'http://10.200.16.50:9401',
      //     changeOrigin: true,
      //   },
      // },
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
