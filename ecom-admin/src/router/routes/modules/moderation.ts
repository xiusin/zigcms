/**
 * 审核系统路由配置
 * 评论审核、敏感词管理、审核规则、审核统计
 * 【权限控制】各页面已配置相应的角色权限
 */
import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/moderation',
  name: 'moderation',
  component: DEFAULT_LAYOUT,
  redirect: '/moderation/review',
  meta: {
    locale: '审核系统',
    requiresAuth: true,
    icon: 'icon-check-circle',
    order: 21,
  },
  children: [
    // 1. 人工审核
    {
      path: 'review',
      name: 'moderation-review',
      component: () => import('@/views/moderation/review/index.vue'),
      meta: {
        locale: '人工审核',
        requiresAuth: true,
        icon: 'icon-user-group',
        roles: ['super_admin', 'admin', 'moderator'],
        permission: 'moderation:review',
      },
    },
    // 2. 敏感词管理
    {
      path: 'sensitive-words',
      name: 'moderation-sensitive-words',
      component: () => import('@/views/moderation/sensitive-words/index.vue'),
      meta: {
        locale: '敏感词管理',
        requiresAuth: true,
        icon: 'icon-filter',
        roles: ['super_admin', 'admin'],
        permission: 'moderation:sensitive-word',
      },
    },
    // 3. 审核规则
    {
      path: 'rules',
      name: 'moderation-rules',
      component: () => import('@/views/moderation/rules/index.vue'),
      meta: {
        locale: '审核规则',
        requiresAuth: true,
        icon: 'icon-settings',
        roles: ['super_admin', 'admin'],
        permission: 'moderation:rule',
      },
    },
    // 4. 审核统计
    {
      path: 'stats',
      name: 'moderation-stats',
      component: () => import('@/views/moderation/stats/index.vue'),
      meta: {
        locale: '审核统计',
        requiresAuth: true,
        icon: 'icon-bar-chart',
        roles: ['super_admin', 'admin', 'moderator'],
        permission: 'moderation:stats',
      },
    },
  ],
};

export default RouterConfig;
