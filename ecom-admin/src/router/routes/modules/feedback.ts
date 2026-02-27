import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

/**
 * 反馈系统模块路由配置
 * 包含：反馈列表、反馈详情、统计报表、标签管理
 * 【权限控制】各页面已配置相应的角色权限
 */
const RouterConfig: AppRouteRecordRaw = {
  path: '/feedback',
  name: 'feedback',
  component: DEFAULT_LAYOUT,
  redirect: '/feedback/list',
  meta: {
    locale: '建议反馈',
    requiresAuth: true,
    icon: 'icon-message',
    order: 25,
  },
  children: [
    // 1. 反馈列表页（默认子路由）- 所有登录用户可访问
    {
      path: 'list',
      name: 'feedback-list',
      component: () => import('@/views/feedback/list/index.vue'),
      meta: {
        locale: '反馈列表',
        requiresAuth: true,
        icon: 'icon-list',
        roles: ['*'], // 所有角色可访问
        activeMenu: '/feedback/list',
        // 【权限控制】页面级权限标识
        permission: 'feedback:list',
      },
    },
    // 2. 反馈详情页（不在菜单中显示）- 所有登录用户可访问
    {
      path: 'detail/:id',
      name: 'feedback-detail',
      component: () => import('@/views/feedback/detail/index.vue'),
      meta: {
        locale: '反馈详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['*'], // 所有角色可访问
        activeMenu: '/feedback/list',
        // 【权限控制】页面级权限标识
        permission: 'feedback:detail',
      },
    },
    // 3. 统计报表页 - 管理员和具有统计权限的用户可访问
    {
      path: 'statistics',
      name: 'feedback-statistics',
      component: () => import('@/views/feedback/statistics/index.vue'),
      meta: {
        locale: '统计报表',
        requiresAuth: true,
        icon: 'icon-bar-chart',
        roles: ['super_admin', 'admin'], // 仅管理员可访问
        // 【权限控制】页面级权限标识
        permission: 'feedback:statistics:view',
      },
    },
    // 4. 标签管理页（仅管理员可见）
    {
      path: 'tags',
      name: 'feedback-tags',
      component: () => import('@/views/feedback/tags/index.vue'),
      meta: {
        locale: '标签管理',
        requiresAuth: true,
        icon: 'icon-tag',
        roles: ['super_admin', 'admin'], // 仅管理员可访问
        // 【权限控制】页面级权限标识
        permission: 'feedback:tag:manage',
      },
    },
    // 5. 通知设置页 - 所有登录用户可访问
    {
      path: 'notification-settings',
      name: 'feedback-notification-settings',
      component: () => import('@/views/feedback/notification-settings/index.vue'),
      meta: {
        locale: '通知设置',
        requiresAuth: true,
        icon: 'icon-settings',
        hideInMenu: true,
        roles: ['*'], // 所有角色可访问
        activeMenu: '/feedback/list',
        // 【权限控制】页面级权限标识
        permission: 'feedback:notification:settings',
      },
    },
  ],
};

export default RouterConfig;
