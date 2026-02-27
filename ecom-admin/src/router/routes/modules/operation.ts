import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/operation',
  name: 'operation',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '客服看板',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 100,
  },
  children: [
    // todo 可以自行增加
    {
      path: 'orderManage',
      name: 'orderManage',
      component: () =>
        import('@/views/operation/order-manage/table-manage.vue'),
      meta: {
        locale: '订单',
        requiresAuth: true,
        icon: 'icon-bookmark',
        roles: ['*'],
      },
    },
  ],
};

export default RouterConfig;
