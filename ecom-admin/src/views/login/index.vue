<template>
  <div class="login-container">
    <!-- 背景装饰 -->
    <div class="bg-decoration">
      <div class="circle circle-1"></div>
      <div class="circle circle-2"></div>
      <div class="circle circle-3"></div>
      <div class="circle circle-4"></div>
      <div class="circle circle-5"></div>
      <div class="circle circle-6"></div>
      <div class="wave wave-1"></div>
      <div class="wave wave-2"></div>
    </div>

    <!-- 左侧品牌区 -->
    <div class="login-left">
      <div class="brand-section">
        <div class="logo-wrapper">
          <div class="logo-bg">
            <icon-apps style="font-size: 48px" />
          </div>
        </div>
        <h1 class="brand-title">Ecom Admin</h1>
        <p class="brand-subtitle">企业级电商管理平台</p>
        <div class="brand-desc"> 专业、高效、安全的一站式电商运营解决方案 </div>
      </div>

      <div class="features-grid">
        <div class="feature-card">
          <div class="feature-icon">
            <icon-dashboard />
          </div>
          <h3>智能数据分析</h3>
          <p>实时业务数据可视化，助力科学决策</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <icon-safe />
          </div>
          <h3>安全权限管理</h3>
          <p>企业级权限体系，保障数据安全</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <icon-thunderbolt />
          </div>
          <h3>高效运营工具</h3>
          <p>一站式管理，提升运营效率</p>
        </div>
        <div class="feature-card">
          <div class="feature-icon">
            <icon-settings />
          </div>
          <h3>灵活配置</h3>
          <p>模块化设计，满足个性化需求</p>
        </div>
      </div>

      <div class="stats-bar">
        <div class="stat-item">
          <div class="stat-value">10K+</div>
          <div class="stat-label">企业用户</div>
        </div>
        <div class="stat-divider"></div>
        <div class="stat-item">
          <div class="stat-value">99.9%</div>
          <div class="stat-label">系统稳定性</div>
        </div>
        <div class="stat-divider"></div>
        <div class="stat-item">
          <div class="stat-value">24/7</div>
          <div class="stat-label">技术支持</div>
        </div>
      </div>
    </div>

    <!-- 右侧登录区 -->
    <div class="login-right">
      <div class="login-card">
        <div class="login-header">
          <h2>欢迎回来</h2>
          <p>登录您的账户以继续</p>
        </div>
        <LoginForm />
        <div class="login-footer">
          <a-divider>或使用以下方式登录</a-divider>
          <div class="social-login">
            <a-button class="social-btn" shape="circle" size="large">
              <icon-wechat-pay />
            </a-button>
            <a-button class="social-btn" shape="circle" size="large">
              <icon-alipay-circle />
            </a-button>
            <a-button class="social-btn" shape="circle" size="large">
              <icon-qq-circle />
            </a-button>
          </div>
        </div>
      </div>
      <Footer />
    </div>
  </div>
</template>

<script lang="ts" setup>
  import { onBeforeMount } from 'vue';
  import Footer from '@/components/footer/index.vue';
  import { useUserStore } from '@/store';
  import LoginForm from './components/login-form.vue';

  const userStore = useUserStore();
  onBeforeMount(() => {
    userStore.logout();
  });
</script>

<style lang="less" scoped>
  .login-container {
    position: relative;
    display: flex;
    min-height: 100vh;
    overflow: hidden;
    background: linear-gradient(135deg, #1e3a8a 0%, #1e40af 50%, #3b82f6 100%);
  }

  // 背景装饰
  .bg-decoration {
    position: absolute;
    top: 0;
    left: 0;
    width: 60%;
    height: 100%;
    overflow: hidden;
    pointer-events: none;

    .circle {
      position: absolute;
      border-radius: 50%;
      background: rgba(255, 255, 255, 0.05);
      backdrop-filter: blur(20px);
      border: 1px solid rgba(255, 255, 255, 0.1);
      box-shadow: inset 0 0 30px rgba(255, 255, 255, 0.08),
        0 8px 32px rgba(0, 0, 0, 0.08);
      animation: float 20s infinite ease-in-out;

      &::before {
        content: '';
        position: absolute;
        top: 10%;
        left: 10%;
        width: 40%;
        height: 40%;
        background: radial-gradient(
          circle,
          rgba(255, 255, 255, 0.2) 0%,
          transparent 70%
        );
        border-radius: 50%;
      }

      &.circle-1 {
        width: 400px;
        height: 400px;
        top: -150px;
        left: -100px;
        animation-delay: 0s;
        animation-duration: 25s;
      }

      &.circle-2 {
        width: 280px;
        height: 280px;
        top: 20%;
        left: 15%;
        animation-delay: 5s;
        animation-duration: 30s;
      }

      &.circle-3 {
        width: 200px;
        height: 200px;
        bottom: 15%;
        left: 8%;
        animation-delay: 10s;
        animation-duration: 22s;
      }

      &.circle-4 {
        width: 150px;
        height: 150px;
        top: 50%;
        left: 40%;
        animation-delay: 3s;
        animation-duration: 28s;
      }

      &.circle-5 {
        width: 120px;
        height: 120px;
        bottom: 25%;
        left: 35%;
        animation-delay: 8s;
        animation-duration: 26s;
      }

      &.circle-6 {
        width: 180px;
        height: 180px;
        top: 35%;
        left: 5%;
        animation-delay: 12s;
        animation-duration: 24s;
      }
    }

    .wave {
      position: absolute;
      bottom: 0;
      left: 0;
      width: 200%;
      height: 200px;
      background: rgba(255, 255, 255, 0.03);
      border-radius: 50%;
      animation: wave 15s infinite linear;

      &.wave-1 {
        animation-delay: 0s;
      }

      &.wave-2 {
        animation-delay: 7.5s;
        opacity: 0.5;
      }
    }
  }

  @keyframes float {
    0%,
    100% {
      transform: translate(0, 0) scale(1);
    }
    25% {
      transform: translate(20px, -30px) scale(1.05);
    }
    50% {
      transform: translate(-15px, -50px) scale(0.95);
    }
    75% {
      transform: translate(25px, -35px) scale(1.02);
    }
  }

  @keyframes wave {
    0% {
      transform: translateX(0);
    }
    100% {
      transform: translateX(-50%);
    }
  }

  // 左侧品牌区
  .login-left {
    position: relative;
    flex: 1;
    display: flex;
    flex-direction: column;
    justify-content: space-between;
    padding: 60px 80px;
    color: white;
    z-index: 1;

    .brand-section {
      .logo-wrapper {
        margin-bottom: 32px;

        .logo-bg {
          width: 80px;
          height: 80px;
          background: rgba(255, 255, 255, 0.2);
          backdrop-filter: blur(20px);
          border-radius: 20px;
          display: flex;
          align-items: center;
          justify-content: center;
          color: white;
          box-shadow: 0 8px 32px rgba(0, 0, 0, 0.08);
          border: 1px solid rgba(255, 255, 255, 0.3);
        }
      }

      .brand-title {
        font-size: 56px;
        font-weight: 800;
        margin: 0 0 16px;
        background: linear-gradient(to right, #fff, rgba(255, 255, 255, 0.9));
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        letter-spacing: -1px;
      }

      .brand-subtitle {
        font-size: 24px;
        font-weight: 600;
        margin: 0 0 16px;
        opacity: 0.95;
      }

      .brand-desc {
        font-size: 16px;
        opacity: 0.8;
        line-height: 1.6;
        max-width: 500px;
      }
    }

    .features-grid {
      display: grid;
      grid-template-columns: repeat(2, 1fr);
      gap: 24px;
      margin: 60px 0;

      .feature-card {
        background: rgba(255, 255, 255, 0.15);
        backdrop-filter: blur(20px);
        border-radius: 16px;
        padding: 24px;
        border: 1px solid rgba(255, 255, 255, 0.2);
        transition: all 0.3s ease;

        &:hover {
          background: rgba(255, 255, 255, 0.2);
          transform: translateY(-4px);
          box-shadow: 0 12px 40px rgba(0, 0, 0, 0.15);
        }

        .feature-icon {
          width: 48px;
          height: 48px;
          background: rgba(255, 255, 255, 0.2);
          border-radius: 12px;
          display: flex;
          align-items: center;
          justify-content: center;
          font-size: 24px;
          margin-bottom: 16px;
        }

        h3 {
          font-size: 18px;
          font-weight: 600;
          margin: 0 0 8px;
        }

        p {
          font-size: 14px;
          margin: 0;
          opacity: 0.85;
          line-height: 1.5;
        }
      }
    }

    .stats-bar {
      display: flex;
      align-items: center;
      gap: 32px;
      padding: 24px 32px;
      background: rgba(255, 255, 255, 0.15);
      backdrop-filter: blur(20px);
      border-radius: 16px;
      border: 1px solid rgba(255, 255, 255, 0.2);

      .stat-item {
        flex: 1;
        text-align: center;

        .stat-value {
          font-size: 32px;
          font-weight: 700;
          margin-bottom: 8px;
        }

        .stat-label {
          font-size: 14px;
          opacity: 0.85;
        }
      }

      .stat-divider {
        width: 1px;
        height: 40px;
        background: rgba(255, 255, 255, 0.3);
      }
    }
  }

  // 右侧登录区
  .login-right {
    position: relative;
    width: 520px;
    display: flex;
    flex-direction: column;
    justify-content: center;
    align-items: center;
    padding: 60px;
    background: rgba(255, 255, 255, 0.98);
    backdrop-filter: blur(20px);
    box-shadow: -10px 0 50px rgba(0, 0, 0, 0.1);
    z-index: 2;

    .login-card {
      width: 100%;
      max-width: 400px;

      .login-header {
        text-align: center;
        margin-bottom: 40px;

        h2 {
          font-size: 32px;
          font-weight: 700;
          color: #1f2937;
          margin: 0 0 12px;
        }

        p {
          font-size: 16px;
          color: #6b7280;
          margin: 0;
        }
      }

      .login-footer {
        margin-top: 32px;

        :deep(.arco-divider-text) {
          color: #9ca3af;
          font-size: 14px;
        }

        .social-login {
          display: flex;
          justify-content: center;
          gap: 16px;
          margin-top: 24px;

          .social-btn {
            width: 48px;
            height: 48px;
            font-size: 24px;
            border: 1px solid #e5e7eb;
            transition: all 0.3s ease;

            &:hover {
              border-color: #667eea;
              color: #667eea;
              transform: translateY(-2px);
              box-shadow: 0 4px 12px rgba(102, 126, 234, 0.2);
            }
          }
        }
      }
    }

    :deep(.footer) {
      position: absolute;
      bottom: 24px;
      text-align: center;
      color: #9ca3af;
      font-size: 14px;
    }
  }

  // 响应式
  @media (max-width: 1200px) {
    .login-left {
      padding: 40px 60px;

      .brand-section .brand-title {
        font-size: 48px;
      }

      .features-grid {
        gap: 16px;

        .feature-card {
          padding: 20px;
        }
      }
    }

    .login-right {
      width: 480px;
      padding: 40px;
    }
  }

  @media (max-width: 992px) {
    .login-container {
      flex-direction: column;
    }

    .login-left {
      padding: 40px;

      .features-grid {
        grid-template-columns: 1fr;
      }

      .stats-bar {
        flex-direction: column;
        gap: 16px;

        .stat-divider {
          display: none;
        }
      }
    }

    .login-right {
      width: 100%;
      padding: 40px;
    }
  }
</style>
