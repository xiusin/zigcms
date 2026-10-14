import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/stock',
  name: 'stock',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '库存管理',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 100,
    hideInMenu: true,
  },
  children: [
    {
      path: 'consignmentManage',
      name: 'consignmentManage',
      component: () =>
        import('@/views/operation/consignment-manage/table-manage.vue'),
      meta: {
        locale: '寄卖入库',
        requiresAuth: true,
        icon: 'icon-archive',
        roles: ['*'],
      },
    },
    {
      path: 'warehousingManage',
      name: 'warehousingManage',
      component: () =>
        import('@/views/operation/warehousing-manage/table-manage.vue'),
      meta: {
        locale: '入库管理',
        requiresAuth: true,
        icon: 'icon-relation',
        roles: ['*'],
      },
    },
    {
      path: 'stockDetailsManage',
      name: 'stockDetailsManage',
      component: () =>
        import('@/views/operation/stock-details-manage/table-manage.vue'),
      meta: {
        locale: '库存明细',
        requiresAuth: true,
        icon: 'icon-storage',
        roles: ['*'],
      },
    },
    {
      path: 'outboundManage',
      name: 'outboundManage',
      component: () =>
        import('@/views/operation/outbound-manage/table-manage.vue'),
      meta: {
        locale: '出库管理',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
    {
      path: 'flowMeter',
      name: 'flowMeter',
      component: () => import('@/views/operation/flow-meter/table-manage.vue'),
      meta: {
        locale: '流水表',
        requiresAuth: true,
        icon: 'icon-subscribed',
        roles: ['*'],
      },
    },
    // {
    //   path: 'palletManage',
    //   name: 'palletManage',
    //   component: () =>
    //     import('@/views/operation/pallet-manage/table-manage.vue'),
    //   meta: {
    //     locale: '货盘需求表',
    //     requiresAuth: true,
    //     icon: 'icon-calendar',
    //     roles: ['*'],
    //   },
    // },
    // {
    //   path: 'billLadingManage',
    //   name: 'billLadingManage',
    //   component: () =>
    //     import('@/views/operation/bill-lading-manage/table-manage.vue'),
    //   meta: {
    //     locale: '提货单',
    //     requiresAuth: true,
    //     icon: 'icon-bookmark',
    //     roles: ['*'],
    //   },
    // },
  ],
};

export default RouterConfig;
