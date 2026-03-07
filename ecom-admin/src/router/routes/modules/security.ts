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
    requiresAuth: true,
    icon: 'icon-safe',
    order: 30,
    roles: ['super_admin', 'admin'],
  },
  children: [
    // 1. 安全监控仪表板
    {
      path: 'dashboard',
      name: 'security-dashboard',
      component: () => import('@/views/security/dashboard/index.vue'),
      meta: {
        locale: '安全监控',
        requiresAuth: true,
        icon: 'icon-dashboard',
        roles: ['super_admin', 'admin'],
        permission: 'security:dashboard:view',
      },
    },
    // 2. 审计日志
    {
      path: 'audit-log',
      name: 'security-audit-log',
      component: () => import('@/views/security/audit-log/index.vue'),
      meta: {
        locale: '审计日志',
        requiresAuth: true,
        icon: 'icon-file-text',
        roles: ['super_admin', 'admin'],
        permission: 'security:audit-log:view',
      },
    },
    // 3. 告警管理
    {
      path: 'alerts',
      name: 'security-alerts',
      component: () => import('@/views/security/alerts/index.vue'),
      meta: {
        locale: '告警管理',
        requiresAuth: true,
        icon: 'icon-notification',
        roles: ['super_admin', 'admin'],
        permission: 'security:alerts:view',
      },
    },
  ],
};

export default RouterConfig;
