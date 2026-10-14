import { createRouter, createWebHistory } from 'vue-router';
import type { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/oauth/callback',
  name: 'oauth-callback',
  component: () => import('@/views/oauth/callback/index.vue'),
  meta: {
    requiresAuth: false,
    hideInMenu: true,
  },
};

export default RouterConfig;
