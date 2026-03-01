<template>
  <div class="oauth-callback">
    <a-spin v-if="loading" tip="正在处理登录，请稍候..." size="large" />
    <a-result v-else-if="error" status="error" :title="error.title" :sub-title="error.message">
      <template #extra>
        <a-button type="primary" @click="goLogin">返回登录</a-button>
      </template>
    </a-result>
    <a-result v-else-if="success" status="success" title="登录成功">
      <template #sub-title>
        正在跳转...
      </template>
    </a-result>
  </div>
</template>

<script lang="ts" setup>
  import { ref, onMounted } from 'vue';
  import { useRouter, useRoute } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import { handleOAuthCallback } from '@/api/oauth';
  import { useUserStore } from '@/store';
  import { DEFAULT_ROUTE_NAME } from '@/router/constants';

  const router = useRouter();
  const route = useRoute();
  const userStore = useUserStore();

  const loading = ref(true);
  const error = ref<{ title: string; message: string } | null>(null);
  const success = ref(false);

  const goLogin = () => {
    router.push('/login');
  };

  onMounted(async () => {
    const { code, state, provider } = route.query;

    // 验证 state 防止 CSRF
    const savedState = sessionStorage.getItem('oauth_state');
    if (!state || state !== savedState) {
      loading.value = false;
      error.value = {
        title: '授权验证失败',
        message: '请重新发起登录请求',
      };
      return;
    }

    // 清理 state
    sessionStorage.removeItem('oauth_state');

    if (!code || !provider) {
      loading.value = false;
      error.value = {
        title: '参数错误',
        message: '缺少必要的授权参数',
      };
      return;
    }

    try {
      // 调用后端接口处理 OAuth 回调
      const res = await handleOAuthCallback({
        provider: provider as 'feishu' | 'github',
        code: code as string,
        state: state as string,
      });

      if (res.code === 0 || res.code === 200) {
        const { access_token, user } = res.data;

        // 存储令牌
        userStore.setToken(access_token);
        userStore.setUserInfo(user);

        success.value = true;
        Message.success(`欢迎回来，${user.nickname || user.username}！`);

        // 跳转到首页
        setTimeout(() => {
          router.push(DEFAULT_ROUTE_NAME);
        }, 1000);
      } else {
        error.value = {
          title: '登录失败',
          message: res.msg || '第三方登录失败，请重试',
        };
      }
    } catch (err: any) {
      error.value = {
        title: '登录异常',
        message: err.message || '登录过程发生错误，请重试',
      };
    } finally {
      loading.value = false;
    }
  });
</script>

<style lang="less" scoped>
  .oauth-callback {
    display: flex;
    justify-content: center;
    align-items: center;
    min-height: 100vh;
    background: linear-gradient(135deg, #f5f7fa 0%, #e4e8ec 100%);
  }

  :deep(.arco-result) {
    background: #fff;
    padding: 40px;
    border-radius: 16px;
    box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
  }
</style>
