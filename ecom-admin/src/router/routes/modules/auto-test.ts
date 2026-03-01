/**
 * 自动化测试系统路由配置
 */
import { DEFAULT_LAYOUT } from '../base';
import type { AppRouteRecordRaw } from '../types';

/**
 * 自动化测试系统模块路由配置
 * 包含：测试任务、测试用例、Bug分析、测试报告
 */
const RouterConfig: AppRouteRecordRaw = {
  path: '/auto-test',
  name: 'autoTest',
  component: DEFAULT_LAYOUT,
  redirect: '/auto-test/task',
  meta: {
    locale: '自动化测试',
    requiresAuth: true,
    icon: 'icon-check-circle',
    order: 30,
  },
  children: [
    // 1. 测试任务列表
    {
      path: 'task',
      name: 'auto-test-task',
      component: () => import('@/views/auto-test/task/list/index.vue'),
      meta: {
        locale: '测试任务',
        requiresAuth: true,
        icon: 'icon-bug',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:task:list',
      },
    },
    // 2. 测试任务详情
    {
      path: 'task/detail/:id',
      name: 'auto-test-task-detail',
      component: () => import('@/views/auto-test/task/detail/index.vue'),
      meta: {
        locale: '任务详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:task:detail',
      },
    },
    // 3. 测试用例管理
    {
      path: 'case',
      name: 'auto-test-case',
      component: () => import('@/views/auto-test/case/list/index.vue'),
      meta: {
        locale: '测试用例',
        requiresAuth: true,
        icon: 'icon-file',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:case:list',
      },
    },
    // 4. Bug分析
    {
      path: 'bug',
      name: 'auto-test-bug',
      component: () => import('@/views/auto-test/bug/list/index.vue'),
      meta: {
        locale: 'Bug分析',
        requiresAuth: true,
        icon: 'icon-close-circle',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:bug:list',
      },
    },
    // 5. Bug详情
    {
      path: 'bug/detail/:id',
      name: 'auto-test-bug-detail',
      component: () => import('@/views/auto-test/bug/detail/index.vue'),
      meta: {
        locale: 'Bug详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:bug:detail',
      },
    },
    // 6. 测试执行记录
    {
      path: 'execution',
      name: 'auto-test-execution',
      component: () => import('@/views/auto-test/execution/list/index.vue'),
      meta: {
        locale: '执行记录',
        requiresAuth: true,
        icon: 'icon-play-circle',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:execution:list',
      },
    },
    // 7. 执行详情/日志
    {
      path: 'execution/detail/:id',
      name: 'auto-test-execution-detail',
      component: () => import('@/views/auto-test/execution/detail/index.vue'),
      meta: {
        locale: '执行详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:execution:detail',
      },
    },
    // 8. 测试报告
    {
      path: 'report',
      name: 'auto-test-report',
      component: () => import('@/views/auto-test/report/list/index.vue'),
      meta: {
        locale: '测试报告',
        requiresAuth: true,
        icon: 'icon-file-chart',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:report:list',
      },
    },
    // 9. 报告详情
    {
      path: 'report/detail/:id',
      name: 'auto-test-report-detail',
      component: () => import('@/views/auto-test/report/detail/index.vue'),
      meta: {
        locale: '报告详情',
        requiresAuth: true,
        hideInMenu: true,
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:report:detail',
      },
    },
    // 10. AI测试生成
    {
      path: 'ai-generate',
      name: 'auto-test-ai-generate',
      component: () => import('@/views/auto-test/ai-generate/index.vue'),
      meta: {
        locale: 'AI生成测试',
        requiresAuth: true,
        icon: 'icon-robot',
        roles: ['super_admin', 'admin', 'tester'],
        permission: 'auto:test:ai:generate',
      },
    },
    // 11. 测试套件管理
    {
      path: 'suite',
      name: 'auto-test-suite',
      component: () => import('@/views/auto-test/suite/list/index.vue'),
      meta: {
        locale: '测试套件',
        requiresAuth: true,
        icon: 'icon-folder',
        roles: ['super_admin', 'admin'],
        permission: 'auto:test:suite:list',
      },
    },
  ],
};

export default RouterConfig;
