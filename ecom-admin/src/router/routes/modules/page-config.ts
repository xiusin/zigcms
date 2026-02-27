/**
 * 系统管理 - 页面配置管理路由
 */
import { RouteRecordRaw } from 'vue-router';

const pageConfigRoutes: RouteRecordRaw[] = [
  {
    path: 'page-config',
    name: 'PageConfig',
    component: () => import('@/views/system-manage/page-config/index.vue'),
    meta: {
      title: '页面配置',
      icon: 'icon-layout',
      requiresAuth: true,
      roles: ['admin', 'system'],
    },
  },
  {
    path: 'lowcode/:code',
    name: 'LowcodeRenderer',
    component: () => import('@/views/lowcode/renderer.vue'),
    meta: {
      title: '低代码页面',
      requiresAuth: true,
      hidden: true,
    },
  },
];

export default pageConfigRoutes;
