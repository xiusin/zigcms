/**
 * 安全管理路由配置
 */
import type { RouteRecordRaw } from 'vue-router';

const securityRoutes: RouteRecordRaw = {
  path: '/security',
  name: 'Security',
  meta: {
    title: '安全管理',
    icon: 'icon-safe',
    requiresAuth: true,
    order: 8,
  },
  children: [
    {
      path: 'dashboard',
      name: 'SecurityDashboard',
      component: () => import('@/views/security/dashboard/index.vue'),
      meta: {
        title: '安全仪表板',
        icon: 'icon-dashboard',
        requiresAuth: true,
      },
    },
    {
      path: 'alerts',
      name: 'SecurityAlerts',
      component: () => import('@/views/security/alerts/index.vue'),
      meta: {
        title: '安全告警',
        icon: 'icon-notification',
        requiresAuth: true,
      },
    },
    {
      path: 'events',
      name: 'SecurityEvents',
      component: () => import('@/views/security/events/index.vue'),
      meta: {
        title: '安全事件',
        icon: 'icon-file',
        requiresAuth: true,
      },
    },
    {
      path: 'audit-log',
      name: 'AuditLog',
      component: () => import('@/views/security/audit-log/index.vue'),
      meta: {
        title: '审计日志',
        icon: 'icon-history',
        requiresAuth: true,
      },
    },
  ],
};

export default securityRoutes;
