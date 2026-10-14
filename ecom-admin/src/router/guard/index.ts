import type { Router } from 'vue-router';
import NProgress from 'nprogress';
import { setRouteEmitter } from '@/utils/route-listener';
import { doReportedMenu } from '@/api/base';
import checkVersion from '@/hooks/check-version';
import setupUserLoginInfoGuard from './userLoginInfo';
import setupPermissionGuard from './permission';

function setupPageGuard(router: Router) {
  router.beforeEach(async (to, from) => {
    NProgress.start();
    // emit route change
    setRouteEmitter(to);
  });
  router.beforeResolve(async (to) => {
    try {
      checkVersion.checkVersion(false).then((res) => {
        if (res) {
          window.location.reload();
        }
      });
    } catch (e) {
      console.log('检查更新', e);
    }

    // 访问上报 todo 暂时屏蔽
    let data: any = {};
    if (!['/login', '/Redirect'].includes(to.path)) {
      try {
        data.menu_one_mark =
          to.matched[0]?.meta?.locale || to.matched[0]?.name || '';
        data.menu_two_mark = to.meta.locale || to.name;
        // doReportedMenu(data);
      } catch (e) {
        console.log('上报菜单', e);
      }
    }
  });
  router.afterEach(async (to: any) => {
    NProgress.done();
  });
}

export default function createRouteGuard(router: Router) {
  setupPageGuard(router);
  setupUserLoginInfoGuard(router);
  setupPermissionGuard(router);
}
