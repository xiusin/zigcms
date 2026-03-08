<template>
  <div class="login-form-wrapper">
    <a-alert
      v-if="errorMessage"
      type="error"
      :closable="false"
      class="error-alert"
    >
      {{ errorMessage }}
    </a-alert>

    <a-form
      ref="loginForm"
      :model="userInfo"
      class="login-form"
      layout="vertical"
      @submit="handleSubmit"
    >
      <a-form-item
        field="username"
        :rules="[{ required: true, message: $t('login.form.userName.errMsg') }]"
        :validate-trigger="['change', 'blur']"
        hide-label
      >
        <a-input
          v-model="userInfo.username"
          :placeholder="$t('login.form.userName.placeholder')"
          size="large"
          allow-clear
          class="custom-input"
        >
          <template #prefix>
            <icon-user style="color: #3b82f6" />
          </template>
        </a-input>
      </a-form-item>

      <a-form-item
        field="password"
        :rules="[{ required: true, message: $t('login.form.password.errMsg') }]"
        :validate-trigger="['change', 'blur']"
        hide-label
      >
        <a-input-password
          v-model="userInfo.password"
          :placeholder="$t('login.form.password.placeholder')"
          size="large"
          allow-clear
          class="custom-input"
        >
          <template #prefix>
            <icon-lock style="color: #3b82f6" />
          </template>
        </a-input-password>
      </a-form-item>

      <div class="form-actions">
        <a-checkbox
          v-model="loginConfig.rememberPassword"
          @change="setRememberPassword"
        >
          <span class="checkbox-label">{{
            $t('login.form.rememberPassword')
          }}</span>
        </a-checkbox>
        <a-link @click="forgetAction" class="forget-link">
          {{ $t('login.form.forgetPassword') }}
        </a-link>
      </div>

      <a-button
        size="large"
        type="primary"
        html-type="submit"
        long
        :loading="loading"
        class="login-btn"
      >
        <template v-if="!loading">
          <icon-right style="margin-right: 8px" />
          {{ $t('login.form.login') }}
        </template>
      </a-button>

      <!-- 第三方登录分隔符 -->
      <div class="oauth-divider">
        <span class="oauth-divider-text">其他登录方式</span>
      </div>

      <!-- 第三方登录按钮 -->
      <div class="oauth-buttons">
        <a-tooltip content="飞书登录">
          <a-button class="oauth-btn feishu-btn" @click="handleOAuthLogin('feishu')">
            <template #icon>
              <svg viewBox="0 0 24 24" class="oauth-icon">
                <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-1 17.93c-3.95-.49-7-3.85-7-7.93 0-.62.08-1.21.21-1.79L9 15v1c0 1.1.9 2 2 2v1.93zm6.9-2.54c-.26-.81-1-1.39-1.9-1.39h-1v-3c0-.55-.45-1-1-1H8v-2h2c.55 0 1-.45 1-1V7h2c1.1 0 2-.9 2-2v-.41c2.93 1.19 5 4.06 5 7.41 0 2.08-.8 3.97-2.1 5.39z" fill="currentColor"/>
              </svg>
            </template>
          </a-button>
        </a-tooltip>
        <a-tooltip content="GitHub 登录">
          <a-button class="oauth-btn github-btn" @click="handleOAuthLogin('github')">
            <template #icon>
              <svg viewBox="0 0 24 24" class="oauth-icon" aria-hidden="true">
                <path d="M12 0c-6.626 0-12 5.373-12 12 0 5.302 3.438 9.8 8.207 11.387.599.111.793-.261.793-.577v-2.234c-3.338.726-4.033-1.416-4.033-1.416-.546-1.387-1.333-1.756-1.333-1.756-1.089-.745.083-.729.083-.729 1.205.084 1.839 1.237 1.839 1.237 1.07 1.834 2.807 1.304 3.492.997.107-.775.418-1.305.762-1.604-2.665-.305-5.467-1.334-5.467-5.931 0-1.311.469-2.381 1.236-3.221-.124-.303-.535-1.524.117-3.176 0 0 1.008-.322 3.301 1.23.957-.266 1.983-.399 3.003-.404 1.02.005 2.047.138 3.006.404 2.291-1.552 3.297-1.23 3.297-1.23.653 1.653.242 2.874.118 3.176.77.84 1.235 1.911 1.235 3.221 0 4.609-2.807 5.624-5.479 5.921.43.372.823 1.102.823 2.222v3.293c0 .319.192.694.801.576 4.765-1.589 8.199-6.086 8.199-11.386 0-6.627-5.373-12-12-12z" fill="currentColor"/>
              </svg>
            </template>
          </a-button>
        </a-tooltip>
      </div>
    <!--
      <div class="register-tip">
        还没有账户？
        <a-link class="register-link">立即注册</a-link>
      </div>
    -->
    </a-form>
  </div>
</template>

<script lang="ts" setup>
  import { ref, reactive } from 'vue';
  import { useRouter } from 'vue-router';
  import { Message } from '@arco-design/web-vue';
  import { ValidatedError } from '@arco-design/web-vue/es/form/interface';
  import { useI18n } from 'vue-i18n';
  import { useStorage } from '@vueuse/core';
  import { useUserStore } from '@/store';
  import useLoading from '@/hooks/loading';
  import { DEFAULT_ROUTE_NAME } from '@/router/constants';
  import request from '@/api/request';
  import { buildOAuthAuthorizeUrl } from '@/api/oauth';

  const { VITE_ACCOUNT_KEY } = import.meta.env;
  const router = useRouter();
  const { t } = useI18n();
  const errorMessage = ref('');
  const { loading, setLoading } = useLoading();
  const userStore = useUserStore();

  const loginConfig = useStorage(VITE_ACCOUNT_KEY, {
    rememberPassword: true,
    username: '',
    password: '',
  });
  const userInfo = reactive({
    username: loginConfig.value.username,
    password: loginConfig.value.password,
  });

  const handleSubmit = async ({
    errors,
    values,
  }: {
    errors: Record<string, ValidatedError> | undefined;
    values: Record<string, any>;
  }) => {
    if (loading.value) return;
    if (!errors) {
      setLoading(true);
      try {
        await userStore.login(values);
        const { redirect, ...othersQuery } = router.currentRoute.value.query;
        router.push({
          // name: (redirect as string) || DEFAULT_ROUTE_NAME,
          path: DEFAULT_ROUTE_NAME,
          query: {
            ...othersQuery,
          },
        });
        Message.success(t('login.form.login.success'));
        const { rememberPassword } = loginConfig.value;
        const { username, password } = values;
        // 实际生产环境需要进行加密存储。
        loginConfig.value.username = rememberPassword ? username : '';
        loginConfig.value.password = rememberPassword ? password : '';
      } catch (err) {
        errorMessage.value = (err as Error).message;
      } finally {
        setLoading(false);
      }
    }
  };
  const setRememberPassword = (value: any) => {
    loginConfig.value.rememberPassword = value;
  };

  const forgetAction = () => {
    Message.warning('请联系管理员');
  };

  /**
   * 处理第三方 OAuth 登录
   * @param provider OAuth 提供商 (feishu | github)
   */
  const handleOAuthLogin = (provider: 'feishu' | 'github') => {
    const { VITE_OAUTH_ENABLED } = import.meta.env;
    
    if (VITE_OAUTH_ENABLED !== 'true') {
      Message.warning('第三方登录功能未启用');
      return;
    }

    const authUrl = buildOAuthAuthorizeUrl(provider);
    if (authUrl === '#') {
      Message.error('OAuth 配置错误，请联系管理员');
      return;
    }

    // 跳转到第三方授权页面
    window.location.href = authUrl;
  };
</script>

<style lang="less" scoped>
  .login-form-wrapper {
    width: 100%;
  }

  .error-alert {
    margin-bottom: 24px;
    border-radius: 12px;
    border: none;
    background: #fef2f2;

    :deep(.arco-alert-body) {
      padding: 12px 16px;
    }
  }

  .login-form {
    :deep(.arco-form-item) {
      margin-bottom: 20px;
    }

    .custom-input {
      :deep(.arco-input-wrapper) {
        height: 48px;
        border-radius: 8px;
        border: 2px solid #e5e7eb;
        padding: 0 16px;
        transition: all 0.3s ease;
        background: #f9fafb;

        &:hover {
          border-color: #3b82f6;
          background: #fff;
        }

        &.arco-input-focus {
          border-color: #3b82f6;
          background: #fff;
          box-shadow: 0 0 0 4px rgba(59, 130, 246, 0.1);
        }

        .arco-input {
          background: transparent;
          font-size: 15px;
          padding-left: 8px;
        }

        .arco-input-prefix {
          margin-right: 8px;
          padding-left: 4px;
        }
      }
    }

    .form-actions {
      display: flex;
      justify-content: space-between;
      align-items: center;
      margin-bottom: 24px;

      .checkbox-label {
        color: #6b7280;
        font-size: 14px;
      }

      .forget-link {
        color: #3b82f6;
        font-size: 14px;
        font-weight: 500;

        &:hover {
          color: #2563eb;
        }
      }
    }

    .login-btn {
      height: 48px;
      border-radius: 8px;
      font-size: 16px;
      font-weight: 600;
      background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
      border: none;
      box-shadow: 0 4px 12px rgba(59, 130, 246, 0.3);
      transition: all 0.3s ease;

      &:hover {
        transform: translateY(-2px);
        box-shadow: 0 6px 20px rgba(59, 130, 246, 0.4);
        background: linear-gradient(135deg, #2563eb 0%, #1e40af 100%);
      }

      &:active {
        transform: translateY(0);
      }

      :deep(.arco-icon) {
        font-size: 18px;
      }
    }

    .register-tip {
      text-align: center;
      margin-top: 24px;
      color: #6b7280;
      font-size: 14px;

      .register-link {
        color: #3b82f6;
        font-weight: 600;
        margin-left: 4px;

        &:hover {
          color: #2563eb;
        }
      }
    }

    // 第三方登录分隔符
    .oauth-divider {
      display: flex;
      align-items: center;
      margin: 24px 0;
      color: #9ca3af;
      font-size: 12px;

      &::before,
      &::after {
        content: '';
        flex: 1;
        height: 1px;
        background: #e5e7eb;
      }

      .oauth-divider-text {
        padding: 0 12px;
      }
    }

    // 第三方登录按钮
    .oauth-buttons {
      display: flex;
      justify-content: center;
      gap: 16px;

      .oauth-btn {
        height: 48px;
        border-radius: 50%;
        border: 2px solid #e5e7eb;
        background: #fff;
        transition: all 0.3s ease;
        display: flex;
        align-items: center;
        justify-content: center;

        &:hover {
          border-color: #3b82f6;
          transform: translateY(-2px);
          box-shadow: 0 4px 12px rgba(59, 130, 246, 0.2);
        }

        &.feishu-btn {
          &:hover {
            border-color: #29b6f6;
            box-shadow: 0 4px 12px rgba(41, 182, 246, 0.3);
          }
        }

        &.github-btn {
          &:hover {
            border-color: #24292e;
            box-shadow: 0 4px 12px rgba(36, 41, 46, 0.3);
          }
        }

        .oauth-icon {
          width: 20px;
          height: 20px;
        }
      }
    }
  }

  :deep(.arco-checkbox) {
    .arco-checkbox-icon {
      border-radius: 4px;
      border-width: 2px;
    }

    &.arco-checkbox-checked .arco-checkbox-icon {
      background: linear-gradient(135deg, #3b82f6 0%, #2563eb 100%);
      border-color: #3b82f6;
    }
  }
</style>
