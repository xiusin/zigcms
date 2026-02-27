import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/purchase',
  name: 'purchase',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '采购管理',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 100,
    hideInMenu: true,
  },
  children: [
    {
      path: 'palletManage',
      name: 'palletManage',
      component: () =>
        import('@/views/operation/pallet-manage/table-manage.vue'),
      meta: {
        locale: '货盘需求表',
        requiresAuth: true,
        icon: 'icon-calendar',
        roles: ['*'],
      },
    },
    {
      path: 'billLadingManage',
      name: 'billLadingManage',
      component: () =>
        import('@/views/operation/bill-lading-manage/table-manage.vue'),
      meta: {
        locale: '提货单',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
    {
      path: 'returnLadingManage',
      name: 'returnLadingManage',
      component: () =>
        import('@/views/operation/return-lading-manage/table-manage.vue'),
      meta: {
        locale: '返货单',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
  ],
};

export default RouterConfig;
