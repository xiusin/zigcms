import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/report',
  name: 'report',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '数据概览',
    requiresAuth: true,
    icon: 'icon-dashboard',
    order: 10,
    hideInMenu: true,
  },
  children: [
    {
      path: 'dashboard',
      name: 'dashboard',
      component: () => import('@/views/business/overview/overview.vue'),
      meta: {
        locale: '大盘数据',
        requiresAuth: true,
        icon: 'icon-dashboard',
        roles: ['*'],
      },
    },
    {
      path: 'day-report',
      name: 'day-report',
      component: () => import('@/views/report/dashboard/dashboard.vue'),
      meta: {
        locale: '日数据',
        requiresAuth: true,
        icon: 'icon-relation',
        roles: ['*'],
      },
    },
  ],
};

// 运营分析模块路由
const ReportAnalysisConfig: AppRouteRecordRaw = {
  path: '/report-analysis',
  name: 'report-analysis',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '运营分析',
    requiresAuth: true,
    icon: 'icon-chart',
    order: 20,
  },
  children: [
    {
      path: 'statistics',
      name: 'report-statistics',
      component: () => import('@/views/report/statistics/statistics.vue'),
      meta: {
        locale: '报表统计',
        requiresAuth: true,
        icon: 'icon-bar-chart',
        roles: ['*'],
      },
    },
  ],
};

export default [RouterConfig, ReportAnalysisConfig];
