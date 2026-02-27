import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

// 业务功能模块路由配置
const RouterConfig: AppRouteRecordRaw = {
  path: '/business',
  name: 'business',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '业务管理',
    requiresAuth: true,
    icon: 'icon-apps',
    order: 10,
  },
  children: [
    // 1. 数据概览
    {
      path: 'overview',
      name: 'business-overview',
      component: () => import('@/views/business/overview/overview.vue'),
      meta: {
        locale: '数据概览',
        requiresAuth: true,
        icon: 'icon-dashboard',
        roles: ['*'],
      },
    },
    // 2. 会员管理
    {
      path: 'member',
      name: 'business-member',
      component: () => import('@/views/business/member/member.vue'),
      meta: {
        locale: '会员管理',
        requiresAuth: true,
        icon: 'icon-user',
        roles: ['*'],
      },
    },
    // 3. 订单管理
    {
      path: 'order',
      name: 'business-order',
      component: () => import('@/views/business/order/order.vue'),
      meta: {
        locale: '订单管理',
        requiresAuth: true,
        icon: 'icon-ordered-list',
        roles: ['*'],
      },
    },
    // 4. 工具箱
    {
      path: 'toolbox',
      name: 'business-toolbox',
      component: () => import('@/views/business/toolbox/toolbox.vue'),
      meta: {
        locale: '工具箱',
        requiresAuth: true,
        icon: 'icon-tool',
        roles: ['*'],
      },
    },
    // 5. 优惠活动
    {
      path: 'promotion',
      name: 'business-promotion',
      component: () => import('@/views/business/promotion/promotion.vue'),
      meta: {
        locale: '优惠活动',
        requiresAuth: true,
        icon: 'icon-gift',
        roles: ['*'],
      },
    },
    // 6. 机器管理
    {
      path: 'machine',
      name: 'business-machine',
      component: () => import('@/views/business/machine/machine.vue'),
      meta: {
        locale: '机器管理',
        requiresAuth: true,
        icon: 'icon-computer',
        roles: ['*'],
      },
    },
    // 7. 收入管理
    {
      path: 'income',
      name: 'business-income',
      component: () => import('@/views/business/income/income.vue'),
      meta: {
        locale: '收入管理',
        requiresAuth: true,
        icon: 'icon-subscribe',
        roles: ['*'],
      },
    },
  ],
};

// 运营管理模块路由
const OperationConfig: AppRouteRecordRaw = {
  path: '/operation-manage',
  name: 'operation-manage',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '运营管理',
    requiresAuth: true,
    icon: 'icon-operation',
    order: 15,
  },
  children: [
    // 任务管理
    {
      path: 'task',
      name: 'operation-task',
      component: () => import('@/views/operation/task/task.vue'),
      meta: {
        locale: '任务管理',
        requiresAuth: true,
        icon: 'icon-clock-circle',
        roles: ['*'],
      },
    },
    // 插件管理
    {
      path: 'plugin',
      name: 'operation-plugin',
      component: () => import('@/views/operation/plugin/plugin.vue'),
      meta: {
        locale: '插件管理',
        requiresAuth: true,
        icon: 'icon-apps',
        roles: ['*'],
      },
    },
  ],
};

// 安全运维模块路由
const SecurityConfig: AppRouteRecordRaw = {
  path: '/security',
  name: 'security',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '安全运维',
    requiresAuth: true,
    icon: 'icon-safe',
    order: 95,
  },
  children: [
    // 日志管理
    {
      path: 'log',
      name: 'security-log',
      component: () => import('@/views/security/log/log.vue'),
      meta: {
        locale: '日志管理',
        requiresAuth: true,
        icon: 'icon-file',
        roles: ['*'],
      },
    },
    // 黑名单
    {
      path: 'blacklist',
      name: 'security-blacklist',
      component: () => import('@/views/security/blacklist/blacklist.vue'),
      meta: {
        locale: '黑名单',
        requiresAuth: true,
        icon: 'icon-close-circle',
        roles: ['*'],
      },
    },
  ],
};

export default [RouterConfig, OperationConfig, SecurityConfig];
