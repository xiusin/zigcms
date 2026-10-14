import { resolve } from 'path';
import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
import vueJsx from '@vitejs/plugin-vue-jsx';
import svgLoader from 'vite-svg-loader';
// @ts-ignore
import htmlPlugin from 'vite-plugin-html-config';
import dayjs from 'dayjs';

// 获取git版本
import fs from 'fs';

import configArcoStyleImportPlugin from './plugin/arcoStyleImport';

let pubPath = 'dist';

// 容错处理：检查是否为 git 仓库
const gitHeadPath = resolve(__dirname, '../.git/HEAD');
if (fs.existsSync(gitHeadPath)) {
  try {
    const gitHEAD = fs.readFileSync(gitHeadPath, 'utf-8').trim();
    // @ts-ignore
    const develop = gitHEAD.split('/').pop().replace(/\./g, '');
    pubPath = develop;
    if (pubPath === 'developer' || pubPath === 'master') {
      pubPath = 'dist';
    }
  } catch (e) {
    console.warn('读取 git 版本失败，使用默认路径:', pubPath);
  }
}
const htmlPluginOpt = {
  metas: [
    {
      name: 'version',
      content: dayjs().format('YYYY-MM-DD HH:mm:ss'),
    },
  ],
};

export default defineConfig({
  plugins: [
    vue(),
    vueJsx(),
    svgLoader({ svgoConfig: {} }),
    // configArcoStyleImportPlugin(),
    htmlPlugin(htmlPluginOpt),
  ],
  resolve: {
    alias: [
      {
        find: '@',
        replacement: resolve(__dirname, '../src'),
      },
      {
        find: 'assets',
        replacement: resolve(__dirname, '../src/assets'),
      },
      {
        find: 'vue-i18n',
        replacement: 'vue-i18n/dist/vue-i18n.cjs.js', // Resolve the i18n warning issue
      },
      {
        find: 'vue',
        replacement: 'vue/dist/vue.esm-bundler.js', // compile template
      },
    ],
    extensions: ['.ts', '.js'],
  },
  build: {
    outDir: resolve(__dirname, `../../ecom-admin-publish/${pubPath}`),
    // outDir: resolve(__dirname, `../dist/${pubPath}`),
    rollupOptions: {
      // 外部化 React，避免打包到项目
      external: ['react', 'react-dom', 'react/jsx-runtime'],
    },
  },
  base: './',
  define: {
    'process.env': {},
  },
  css: {
    preprocessorOptions: {
      less: {
        modifyVars: {
          hack: `true; @import (reference) "${resolve(
            'src/assets/style/breakpoint.less'
          )}";`,
        },
        javascriptEnabled: true,
      },
    },
  },
});
