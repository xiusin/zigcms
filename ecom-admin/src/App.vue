<template>
  <a-config-provider :locale="locale">
    <router-view />
    <global-setting />
  </a-config-provider>
</template>

<script lang="ts" setup>
  import { computed } from 'vue';
  import enUS from '@arco-design/web-vue/es/locale/lang/en-us';
  import zhCN from '@arco-design/web-vue/es/locale/lang/zh-cn';
  import { useRouter } from 'vue-router';
  import { cloneDeep } from 'lodash';
  import GlobalSetting from '@/components/global-setting/index.vue';
  import useLocale from '@/hooks/locale';
  import { getToken, getUser, isLogin, VITE_TOKEN_KEY } from '@/utils/auth';
  import { useUserStore } from '@/store';
  import useUser from '@/hooks/user';
  import { DEFAULT_ROUTE_NAME } from '@/router/constants';

  const userStore = useUserStore();
  const router = useRouter();
  // 监听多tab登录时，无论用户相同与否，之前的tab都要重新登录
  window.addEventListener('storage', (e) => {
    if (e.key === VITE_TOKEN_KEY) {
      if (e.newValue) {
        setTimeout(() => {
          if (isLogin()) {
            userStore.setStateInfo(getUser());
            if (router.currentRoute.value.name === 'login') {
              router.push({ name: DEFAULT_ROUTE_NAME });
            }
          }
        }, 1000);
      } else {
        setTimeout(() => {
          if (!isLogin()) {
            useUser().logout();
          }
        }, 1000);
      }
    }
  });

  const { currentLocale } = useLocale();
  const locale = computed(() => {
    switch (currentLocale.value) {
      case 'zh-CN':
        return zhCN;
      case 'en-US':
        return enUS;
      default:
        return enUS;
    }
  });
</script>
