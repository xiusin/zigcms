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

      <div class="register-tip">
        还没有账户？
        <a-link class="register-link">立即注册</a-link>
      </div>
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
