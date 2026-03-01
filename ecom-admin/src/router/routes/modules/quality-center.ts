/**
 * 质量中心路由配置
 * 融合自动化测试与反馈系统的统一入口
 * 【权限控制】各页面已配置相应的角色权限
 */
import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/quality-center',
  name: 'qualityCenter',
  component: DEFAULT_LAYOUT,
  redirect: '/quality-center/dashboard',
  meta: {
    locale: '质量中心',
    requiresAuth: true,
    icon: 'icon-shield-check',
    order: 20,
  },
  children: [
    // 1. 质量总览Dashboard
    {
      path: 'dashboard',
      name: 'quality-center-dashboard',
      component: () => import('@/views/quality-center/dashboard/index.vue'),
      meta: {
        locale: '质量总览',
        requiresAuth: true,
        icon: 'icon-dashboard',
        roles: ['*'],
        permission: 'quality:center:dashboard',
      },
    },
    // 2. 关联追踪
    {
      path: 'link-records',
      name: 'quality-center-link-records',
      component: () => import('@/views/quality-center/link-records/index.vue'),
      meta: {
        locale: '关联追踪',
        requiresAuth: true,
        icon: 'icon-link',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'quality:center:link',
      },
    },
    // 3. 定时报表
    {
      path: 'scheduled-reports',
      name: 'quality-center-scheduled-reports',
      component: () => import('@/views/quality-center/scheduled-reports/index.vue'),
      meta: {
        locale: '定时报表',
        requiresAuth: true,
        icon: 'icon-calendar',
        roles: ['super_admin', 'admin'],
        permission: 'quality:center:report',
      },
    },
    // 4. 脑图分析
    {
      path: 'mindmap',
      name: 'quality-center-mindmap',
      component: () => import('@/views/quality-center/mindmap/index.vue'),
      meta: {
        locale: '脑图分析',
        requiresAuth: true,
        icon: 'icon-mind-mapping',
        roles: ['*'],
        permission: 'quality:center:mindmap',
      },
    },
    // 5. 报表模板编辑器
    {
      path: 'report-templates',
      name: 'quality-center-report-templates',
      component: () => import('@/views/quality-center/report-templates/index.vue'),
      meta: {
        locale: '报表模板',
        requiresAuth: true,
        icon: 'icon-file',
        roles: ['super_admin', 'admin'],
        permission: 'quality:center:report-template',
      },
    },
    // 6. 邮件模板管理
    {
      path: 'email-templates',
      name: 'quality-center-email-templates',
      component: () => import('@/views/quality-center/email-templates/index.vue'),
      meta: {
        locale: '邮件模板',
        requiresAuth: true,
        icon: 'icon-email',
        roles: ['super_admin', 'admin'],
        permission: 'quality:center:email-template',
      },
    },
  ],
};

export default RouterConfig;
