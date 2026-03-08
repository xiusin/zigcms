/**
 * 安全管理路由配置
 * 包含安全监控、审计日志、告警管理等功能
 */
import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/security',
  name: 'security',
  component: DEFAULT_LAYOUT,
  redirect: '/security/dashboard',
  meta: {
    locale: '安全管理',
    icon: 'icon-safe',
    order: 30,
  },
  children: [
    // 1. 安全监控仪表板
    {
      path: 'dashboard',
      name: 'security-dashboard',
      component: () => import('@/views/security/dashboard/index.vue'),
      meta: {
        locale: '安全监控',
        icon: 'icon-dashboard',
      },
    },
    // 2. 告警管理
    {
      path: 'alerts',
      name: 'security-alerts',
      component: () => import('@/views/security/alerts/index.vue'),
      meta: {
        locale: '告警管理',
        icon: 'icon-notification',
      },
    },
    // 3. 审计日志
    {
      path: 'audit-log',
      name: 'security-audit-log',
      component: () => import('@/views/security/audit-log/index.vue'),
      meta: {
        locale: '审计日志',
        icon: 'icon-file',
      },
    },
    // 4. 日志管理（显示在菜单中）
    {
      path: 'log',
      name: 'security-log',
      component: () => import('@/views/security/audit-log/index.vue'),
      meta: {
        locale: '日志管理',
        icon: 'icon-file',
      },
    },
    // 5. 黑名单管理
    {
      path: 'blacklist',
      name: 'security-blacklist',
      component: () => import('@/views/security/blacklist/blacklist.vue'),
      meta: {
        locale: '黑名单管理',
        icon: 'icon-close-circle',
      },
    },
  ],
};

export default RouterConfig;
