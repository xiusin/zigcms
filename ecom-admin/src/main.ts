import { createApp } from 'vue';
import ArcoVue from '@arco-design/web-vue';
import ArcoVueIcon from '@arco-design/web-vue/es/icon';
import globalComponents from '@/components';
import checkVersion from '@/hooks/check-version';
import router from './router';
import store from './store';
import i18n from './locale';
import directive from './directive';
import App from './App.vue';
// Styles are imported via arco-plugin. See config/plugin/arcoStyleImport.ts in the directory for details
// 样式通过 arco-plugin 插件导入。详见目录文件 config/plugin/arcoStyleImport.ts
// https://arco.design/docs/designlab/use-theme-package
import '@arco-themes/vue-shentui/index.less';
import '@/api/request';
import '@/assets/style/global.less';
import '@/mock';

const app = createApp(App);

app.use(ArcoVue, {
  // 全局配置组件默认尺寸为 mini（最小尺寸）
  componentSize: 'mini',
  // 全局配置 Card 组件不显示悬停阴影效果
  components: {
    Card: {
      hoverable: false,
    },
    Table: {
      size: 'mini',
      ellipsis: true,
      tooltip: true,
      border: true,
      hover: true,
      stripe: true,
    },
  },
});
app.use(ArcoVueIcon);

app.use(router);
app.use(store);
app.use(i18n);
app.use(globalComponents);
app.use(directive);
app.use(checkVersion);

app.mount('#app');
