<template>
  <a-dropdown trigger="hover" position="bottom">
    <div class="user-box bar">
      <div class="left-box">
        <a-avatar :size="32" :style="{ backgroundColor: '#2878FF' }">
          <IconUser />
        </a-avatar>
      </div>
      <div class="center-box">
        <div class="username">
          {{ userStore.realname }}
        </div>
        <div class="intro">{{ userStore.username }} </div>
      </div>
      <div class="right-box">
        <icon-caret-down class="caret-down" />
      </div>
      <div class="userinfo-box"> </div>
    </div>
    <template #content>
      <div class="hover-content">
        <div class="hover-title"> 当前登录账户 </div>
        <div class="user-box">
          <div class="left-box">
            <a-avatar :size="32" :style="{ backgroundColor: '#2878FF' }">
              <IconUser />
            </a-avatar>
          </div>
          <div class="center-box">
            <div class="username">
              {{ userStore.realname }}
            </div>
            <div class="intro">{{ userStore.username }} </div>
          </div>
          <div class="right-box"> </div>
          <div class="userinfo-box"> </div>
        </div>
        <a-divider />
        <div class="login-out" @click="handleLogout">
          <icon-poweroff />
          <span class="ml-5">退出登录</span>
        </div>
      </div>
    </template>
  </a-dropdown>
</template>

<script lang="ts" setup>
  import { ref } from 'vue';
  import { useAppStore, useUserStore } from '@/store';

  import useUser from '@/hooks/user';

  const emit = defineEmits(['update:modelValue']);

  const userStore = useUserStore();
  const { logout } = useUser();
  const guide = ref();

  const props = defineProps({
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
  });
  const handleLogout = () => {
    logout();
  };
</script>

<style lang="less" scoped>
  .user-box {
    display: flex;
    align-items: center;
    padding: 5px 10px;
    cursor: pointer;
    transition: all 0.1s linear;
    .caret-down {
      transition: all 0.2s linear;
      color: var(--color-text-2);
      margin-left: 3px;
    }
    &.bar {
      &:hover {
        border-radius: 25px;
        background: var(--color-fill-3);
        .caret-down {
          transform: rotate(180deg);
        }
      }
    }

    .left-box {
      margin-right: 5px;
    }
    .center-box {
      display: flex;
      flex-direction: column;
      .username {
        font-size: 12px;
        color: var(--color-text-1);
      }
      .intro {
        font-size: 12px;
        color: var(--color-text-3);
        margin-top: 2px;
      }
    }
  }

  .hover-content {
    .hover-title {
      color: var(--color-text-3);
      font-size: 12px;
      padding: 10px 10px;
    }
    .login-out {
      color: var(--color-text-1);
      padding: 10px 10px 10px 10px;
      cursor: pointer;
      &:hover {
        background: var(--color-fill-2);
      }
    }
  }
</style>
