import { DEFAULT_LAYOUT } from '../base';
import { AppRouteRecordRaw } from '../types';

const RouterConfig: AppRouteRecordRaw = {
  path: '/system',
  name: 'system',
  component: DEFAULT_LAYOUT,
  meta: {
    locale: '系统管理',
    requiresAuth: true,
    icon: 'icon-settings',
    order: 100,
  },
  children: [
    {
      path: 'organization',
      name: 'organization',
      component: () => import('@/views/system/organization/index.vue'),
      meta: {
        locale: '组织架构',
        requiresAuth: true,
        icon: 'icon-user-group',
        roles: ['*'],
      },
    },
    {
      path: 'user-manage',
      name: 'user-manage',
      component: () => import('@/views/system/user-manage/user-manage.vue'),
      meta: {
        locale: '成员管理',
        requiresAuth: true,
        icon: 'icon-user-group',
        roles: ['*'],
        hideInMenu: true,
      },
    },
    {
      path: 'role-manage',
      name: 'role-manage',
      component: () => import('@/views/system/role-manage/table-manage.vue'),
      meta: {
        locale: '角色管理',
        requiresAuth: true,
        icon: 'icon-skin',
        roles: ['*'],
      },
    },
    {
      path: 'dict-manage',
      name: 'dict-manage',
      component: () => import('@/views/system/dict-manage/dict-manage.vue'),
      meta: {
        locale: '字典管理',
        requiresAuth: true,
        icon: 'icon-book',
        roles: ['*'],
      },
    },
    {
      path: 'dept-position',
      name: 'dept-position',
      component: () => import('@/views/system/dept-position/index.vue'),
      meta: {
        locale: '部门职位',
        requiresAuth: true,
        icon: 'icon-branch',
        roles: ['*'],
      },
    },
    {
      path: 'operation-log',
      name: 'operation-log',
      component: () =>
        import('@/views/system/operation-log/operation-manage.vue'),
      meta: {
        locale: '操作记录',
        requiresAuth: true,
        icon: 'icon-code-block',
        roles: ['*'],
      },
    },
    {
      path: 'menu-manage',
      name: 'menu-manage',
      component: () => import('@/views/system-manage/menu/menu.vue'),
      meta: {
        locale: '菜单管理',
        requiresAuth: true,
        icon: 'icon-menu',
        roles: ['*'],
      },
    },
    {
      path: 'config-manage',
      name: 'config-manage',
      component: () => import('@/views/system-manage/config/config.vue'),
      meta: {
        locale: '配置管理',
        requiresAuth: true,
        icon: 'icon-settings',
        roles: ['*'],
      },
    },
    {
      path: 'payment-config',
      name: 'payment-config',
      component: () => import('@/views/system-manage/payment/payment.vue'),
      meta: {
        locale: '支付配置',
        requiresAuth: true,
        icon: 'icon-alipay-circle',
        roles: ['*'],
      },
    },
    {
      path: 'version-manage',
      name: 'version-manage',
      component: () => import('@/views/system-manage/version/version.vue'),
      meta: {
        locale: '版本管理',
        requiresAuth: true,
        icon: 'icon-history',
        roles: ['*'],
      },
    },
    {
      path: 'notifications',
      name: 'system-notifications',
      component: () => import('@/views/system-manage/notifications/index.vue'),
      meta: {
        locale: '通知中心',
        requiresAuth: true,
        icon: 'icon-notification',
        roles: ['*'],
      },
    },
    {
      path: 'reports',
      name: 'system-reports',
      component: () => import('@/views/system-manage/reports/index.vue'),
      meta: {
        locale: '报表中心',
        requiresAuth: true,
        icon: 'icon-file',
        roles: ['*'],
      },
    },
    {
      path: 'audit-logs',
      name: 'system-audit-logs',
      component: () => import('@/views/system-manage/audit-logs/index.vue'),
      meta: {
        locale: '操作审计',
        requiresAuth: true,
        icon: 'icon-safe',
        roles: ['super_admin', 'admin'],
      },
    },
    {
      path: 'page-config',
      name: 'page-config',
      component: () => import('@/views/system-manage/page-config/index.vue'),
      meta: {
        locale: '页面配置',
        requiresAuth: true,
        icon: 'icon-layout',
        roles: ['*'],
      },
    },
    {
      path: 'lowcode-demo',
      name: 'lowcode-demo',
      component: () => import('@/views/system-manage/lowcode-demo/index.vue'),
      meta: {
        locale: '低代码示例',
        requiresAuth: true,
        icon: 'icon-code',
        roles: ['*'],
      },
    },
    {
      path: 'advanced-demo',
      name: 'advanced-demo',
      component: () => import('@/views/system-manage/advanced-demo/index.vue'),
      meta: {
        locale: '高级功能演示',
        requiresAuth: true,
        icon: 'icon-apps',
        roles: ['*'],
      },
    },
    {
      path: 'full-demo',
      name: 'system-full-demo',
      component: () => import('@/views/system-manage/full-demo/index.vue'),
      meta: {
        locale: '完整功能演示',
        requiresAuth: true,
        icon: 'icon-apps',
        roles: ['*'],
      },
    },
    {
      path: 'interaction-demo',
      name: 'system-interaction-demo',
      component: () =>
        import('@/views/system-manage/interaction-demo/index.vue'),
      meta: {
        locale: '业务交互演示',
        requiresAuth: true,
        icon: 'icon-relation',
        roles: ['*'],
      },
    },
    {
      path: 'lowcode/:code',
      name: 'lowcode-renderer',
      component: () => import('@/views/lowcode/renderer.vue'),
      meta: {
        locale: '低代码页面',
        requiresAuth: true,
        hideInMenu: true,
      },
    },
  ],
};

export default RouterConfig;
