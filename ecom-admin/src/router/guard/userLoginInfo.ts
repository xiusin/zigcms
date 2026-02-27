import type { Router, LocationQueryRaw } from 'vue-router';

import { useUserStore } from '@/store';
import { isLogin } from '@/utils/auth';
import useUser from '@/hooks/user';

export default function setupUserLoginInfoGuard(router: Router) {
  router.beforeEach(async (to, from) => {
    const userStore = useUserStore();
    const user = useUser();
    // todo
    if (isLogin()) {
      // debugger;
      if (userStore.role_id || userStore.role_ids) {
        return true;
      }
      user.logout();
      return false;
    }
    if (to.name === 'login') {
      return true;
    }
    return {
      name: 'login',
      query: {
        redirect: to.name,
        ...to.query,
      } as LocationQueryRaw,
    };
  });
}
