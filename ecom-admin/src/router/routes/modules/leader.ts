import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/leader',
  name: 'leader',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '运营看板',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 100,
    hideInMenu: true,
  },
  children: [
    {
      path: 'shelveDetailsManage',
      name: 'shelveDetailsManage',
      component: () =>
        import('@/views/leader/shelve-details-manage/table-manage.vue'),
      meta: {
        locale: '上架商品管理',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
    {
      path: 'todoManage',
      name: 'todoManage',
      component: () => import('@/views/leader/todo/index.vue'),
      meta: {
        locale: '审核任务',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
    {
      path: 'codeManage',
      name: 'codeManage',
      component: () => import('@/views/leader/codeManage/index.vue'),
      meta: {
        locale: '商品码表',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
    {
      path: 'detailConfig',
      name: 'detailConfig',
      component: () => import('@/views/leader/detailConfig/index.vue'),
      meta: {
        locale: '商品详情配置',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
  ],
};

export default RouterConfig;
