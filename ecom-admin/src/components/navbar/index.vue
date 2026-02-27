<template>
  <div class="navbar">
    <div class="left-side">
      <a-space>
        <span class="dis-flex">
          <img
            alt="logo"
            src="@/assets/images/login-logo.png"
            style="width: 48px"
          />
          <span class="title">Ecom Admin</span>
        </span>

        <icon-menu-fold
          v-if="appStore.device === 'mobile'"
          style="font-size: 22px; cursor: pointer"
          @click="toggleDrawerMenu"
        />
      </a-space>
    </div>
    <div class="center-side">
      <Menu
        v-if="topMenu && appStore.device === 'desktop'"
        :is-need-collapsed="false"
        mode="horizontal"
      />
    </div>
    <ul class="right-side">
      <li>
        <a-tooltip
          :content="
            theme === 'light'
              ? $t('settings.navbar.theme.toDark')
              : $t('settings.navbar.theme.toLight')
          "
        >
          <a-button
            class="nav-btn"
            type="outline"
            :shape="'circle'"
            @click="handleToggleTheme"
          >
            <template #icon>
              <icon-sun-fill v-if="theme === 'dark'" />
              <icon-moon-fill v-else />
            </template>
          </a-button>
        </a-tooltip>
      </li>
      <li>
        <a-tooltip
          :content="
            isFullscreen
              ? $t('settings.navbar.screen.toExit')
              : $t('settings.navbar.screen.toFull')
          "
        >
          <a-button
            class="nav-btn"
            type="outline"
            :shape="'circle'"
            @click="toggleFullScreen"
          >
            <template #icon>
              <icon-fullscreen-exit v-if="isFullscreen" />
              <icon-fullscreen v-else />
            </template>
          </a-button>
        </a-tooltip>
      </li>
      <!--消息通知-->
      <li>
        <NotificationCenter />
      </li>

      <!--反馈通知-->
      <li>
        <FeedbackNotificationCenter />
      </li>

      <!--页面布局相关设置-->
      <!--<li>
        <a-tooltip :content="$t('settings.title')">
          <a-button
            class="nav-btn"
            type="outline"
            :shape="'circle'"
            @click="setVisible"
          >
            <template #icon>
              <icon-settings />
            </template>
          </a-button>
        </a-tooltip>
      </li>-->
      <li>
        <UserGuide></UserGuide>
      </li>
    </ul>
  </div>
</template>

<script lang="ts" setup>
  import { computed, ref, inject, onMounted } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import { useDark, useToggle, useFullscreen } from '@vueuse/core';
  import { useAppStore, useUserStore } from '@/store';
  import { LOCALE_OPTIONS } from '@/locale';
  import useLocale from '@/hooks/locale';
  import useUser from '@/hooks/user';
  import Menu from '@/components/menu/index.vue';
import { useVersionStore } from '@/hooks/check-version';
import MessageBox from '../message-box/index.vue';
import VipButton from './vip-button.vue';
import UserGuide from './user-guide.vue';
import RelationGuide from './relation-guide.vue';
import NotificationCenter from '@/components/notification-center/index.vue';
import FeedbackNotificationCenter from '@/views/feedback/components/NotificationCenter.vue';

  const router = useRouter();

  const appStore = useAppStore();
  const userStore = useUserStore();
  const versionStore = useVersionStore();
  const { logout } = useUser();
  const { changeLocale, currentLocale } = useLocale();
  const { isFullscreen, toggle: toggleFullScreen } = useFullscreen();
  const locales = [...LOCALE_OPTIONS];
  const avatar = computed(() => {
    return userStore.avatar;
  });
  const theme = computed(() => {
    return appStore.theme;
  });
  const topMenu = computed(() => appStore.topMenu && appStore.menu);
  const isDark = useDark({
    selector: 'body',
    attribute: 'arco-theme',
    valueDark: 'dark',
    valueLight: 'light',
    storageKey: 'arco-theme',
    onChanged(dark: boolean) {
      // overridden default behavior
      appStore.toggleTheme(dark);
    },
  });
  const toggleTheme = useToggle(isDark);
  const handleToggleTheme = () => {
    toggleTheme();
  };
  const setVisible = () => {
    appStore.updateSettings({ globalSettings: true });
  };
  const refBtn = ref();
  const triggerBtn = ref();

  const setPopoverVisible = () => {
    const event = new MouseEvent('click', {
      view: window,
      bubbles: true,
      cancelable: true,
    });
    refBtn.value.dispatchEvent(event);
  };
  const handleLogout = () => {
    logout();
  };
  const setDropDownVisible = () => {
    const event = new MouseEvent('click', {
      view: window,
      bubbles: true,
      cancelable: true,
    });
    triggerBtn.value.dispatchEvent(event);
  };
  const switchRoles = async () => {
    // const res = await userStore.switchRoles();
    // Message.success(res as string);
  };
  const toggleDrawerMenu = inject('toggleDrawerMenu') as () => void;

  // 任务中心点击跳转导航
  const gotoTaskRoute = (key: string) => {
    router.push({
      name: 'task-manage',
      query: {
        type: key,
      },
    });
  };
</script>

<style scoped lang="less">
  .navbar {
    display: flex;
    justify-content: space-between;
    height: 100%;
    transition: all 0.2s;
    //background-color: var(--color-bg-2);
    //border-bottom: 1px solid var(--color-border);
    &.hasbg {
      background-color: var(--color-bg-2);
      box-shadow: 0px 2px 8px 0px rgba(0, 0, 0, 0.04);
    }
  }

  .left-side {
    display: flex;
    align-items: center;
    padding: 0;
    width: 140px;
    justify-content: center;
    .dis-flex {
      display: flex;
      align-items: center;
      .title {
        font-size: 30px;
        color: var(--color-text-1);
        font-weight: bold;
        margin-left: 15px;
      }
    }
  }

  .center-side {
    flex: 1;
    padding-left: 20px;
  }

  .right-side {
    display: flex;
    padding-right: 10px;
    list-style: none;
    :deep(.locale-select) {
      border-radius: 20px;
    }
    li {
      display: flex;
      align-items: center;
      padding: 0 10px;
    }

    a {
      color: var(--color-text-1);
      text-decoration: none;
    }
    .nav-btn {
      border-color: rgb(var(--gray-2));
      color: rgb(var(--gray-8));
      font-size: 16px;
    }
    .trigger-btn,
    .ref-btn {
      position: absolute;
      bottom: 14px;
    }
    .trigger-btn {
      margin-left: 14px;
    }
  }
  .userinfo-box {
    padding: 10px 15px;
    font-size: 14px;
    opacity: 0.8;
    color: var(--color-text-1);
  }
  .logo-icon {
    height: 12px;
  }
  .logo-text {
    padding-left: 3px;
    font-weight: 500;
    transition: all 0.2s linear;
    &:hover {
      text-decoration: underline;
    }
  }
  .task-center {
    cursor: pointer;
    .task-down-icon {
      transition: all 0.2s linear;
    }
    &:hover {
      .task-down-icon {
        transform: rotate(180deg);
      }
    }
  }
</style>

<style lang="less">
  .message-popover {
    .arco-popover-content {
      margin-top: 0;
    }
  }
</style>
