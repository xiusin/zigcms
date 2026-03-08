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
    icon: 'icon-safe',
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
    // 2. 测试用例管理
    {
      path: 'test-case',
      name: 'quality-center-test-case',
      component: () => import('@/views/quality-center/test-case/index.vue'),
      meta: {
        locale: '测试用例',
        requiresAuth: true,
        icon: 'icon-file',
        roles: ['*'],
        permission: 'quality:center:test-case',
      },
    },
    // ❌ 文件不存在，已注释
    // {
    //   path: 'test-case/:id',
    //   name: 'quality-center-test-case-detail',
    //   component: () => import('@/views/quality-center/test-case/detail.vue'),
    //   meta: {
    //     locale: '测试用例详情',
    //     requiresAuth: true,
    //     hideInMenu: true,
    //     roles: ['*'],
    //     permission: 'quality:center:test-case',
    //   },
    // },
    // 3. 项目管理
    {
      path: 'project',
      name: 'quality-center-project',
      component: () => import('@/views/quality-center/project/index.vue'),
      meta: {
        locale: '项目管理',
        requiresAuth: true,
        icon: 'icon-apps',
        roles: ['*'],
        permission: 'quality:center:project',
      },
    },
    {
      path: 'project/:id',
      name: 'quality-center-project-detail',
      component: () => import('@/views/quality-center/project/detail.vue'),
      meta: {
        locale: '项目详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['*'],
        permission: 'quality:center:project',
      },
    },
    // 4. 模块管理
    {
      path: 'module',
      name: 'quality-center-module',
      component: () => import('@/views/quality-center/module/index.vue'),
      meta: {
        locale: '模块管理',
        requiresAuth: true,
        icon: 'icon-folder',
        roles: ['*'],
        permission: 'quality:center:module',
      },
    },
    // 5. 需求管理
    {
      path: 'requirement',
      name: 'quality-center-requirement',
      component: () => import('@/views/quality-center/requirement/index.vue'),
      meta: {
        locale: '需求管理',
        requiresAuth: true,
        icon: 'icon-file',
        roles: ['*'],
        permission: 'quality:center:requirement',
      },
    },
    {
      path: 'requirement/:id',
      name: 'quality-center-requirement-detail',
      component: () => import('@/views/quality-center/requirement/detail.vue'),
      meta: {
        locale: '需求详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['*'],
        permission: 'quality:center:requirement',
      },
    },
    // 6. 反馈管理
    {
      path: 'feedback',
      name: 'quality-center-feedback',
      component: () => import('@/views/quality-center/feedback/index.vue'),
      meta: {
        locale: '反馈管理',
        requiresAuth: true,
        icon: 'icon-message',
        roles: ['*'],
        permission: 'quality:center:feedback',
      },
    },
    {
      path: 'feedback/:id',
      name: 'quality-center-feedback-detail',
      component: () => import('@/views/quality-center/feedback/detail.vue'),
      meta: {
        locale: '反馈详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['*'],
        permission: 'quality:center:feedback',
      },
    },
    // 7. 关联追踪
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
    // 8. 定时报表
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
    // 9. 脑图分析
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
    // 10. 报表模板编辑器
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
    // 11. 邮件模板管理
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
    // 12. 质量报表 ⭐ 新增
    {
      path: 'reports',
      name: 'quality-center-reports',
      component: () => import('@/views/quality-center/reports/index.vue'),
      meta: {
        locale: '质量报表',
        requiresAuth: true,
        icon: 'icon-bar-chart',
        roles: ['*'],
        permission: 'quality:center:report',
      },
    },
  ],
};

export default RouterConfig;
