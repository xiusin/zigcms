import type { Router, RouteRecordNormalized } from 'vue-router';
import usePermission from '@/hooks/permission';
import { useUserStore, useAppStore } from '@/store';
import { appRoutes } from '../routes';
import { WHITE_LIST, NOT_FOUND } from '../constants';

import { isLogin } from '@/utils/auth';

export default function setupPermissionGuard(router: Router) {
  router.beforeEach(async (to) => {
    // 首页重定向
    if (to.path === '/' || to.path === '') {
      return {
        path: '/business/overview',
        query: { ...to.query },
        replace: true,
      };
    }

    // 登出页面和免登录白名单直接放行
    if (
      to.name === 'logout' ||
      to.path === '/login' ||
      WHITE_LIST.some((item) => item.path === to.path)
    ) {
      return true;
    }

    // 检查是否已登录
    if (!isLogin()) {
      return {
        path: '/login',
        query: { redirect: to.fullPath },
        replace: true,
      };
    }

    const userStore = useUserStore();
    const Permission = usePermission();
    const permissionsAllow = Permission.accessRouter(to);

    // 使用本地静态路由
    if (permissionsAllow) return true;
    const destination =
      Permission.findFirstPermissionRoute(appRoutes, userStore.role_id) ||
      NOT_FOUND;
    return destination;
  });
}
