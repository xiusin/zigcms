import { useRouter } from 'vue-router';
import { Message } from '@arco-design/web-vue';
import router from '@/router';
import { useUserStore } from '@/store';

export default function useUser() {
  const userStore = useUserStore();
  const logout = async (logoutTo?: string) => {
    await userStore.logout();
    const currentRoute = router.currentRoute.value;
    if (currentRoute.name !== 'login') {
      Message.success('登出成功');
      router.replace({
        name: logoutTo && typeof logoutTo === 'string' ? logoutTo : 'login',
        query: {
          ...currentRoute.query,
          redirect: (currentRoute.name !== 'login'
            ? currentRoute.name
            : undefined) as string,
        },
      });
    }
  };
  return {
    logout,
  };
}
