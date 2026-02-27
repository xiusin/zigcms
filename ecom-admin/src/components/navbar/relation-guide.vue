<template>
  <a-dropdown trigger="hover" position="br">
    <div class="bar-box">
      <div class="tab-box">
        <div id="bp-header-brand-container"
          ><div class="brand-matrix svelte-5j34ip"
            ><div
              class="brand-matrix-entrance brand-matrix-entrance-blue svelte-5j34ip"
            >
              <div class="brand-matrix-entrance-icon svelte-5j34ip"
                ><svg
                  width="16"
                  height="16"
                  fill="none"
                  xmlns="http://www.w3.org/2000/svg"
                  class="svelte-5j34ip"
                >
                  <rect
                    x="1"
                    y=".999"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="1"
                    y="6.764"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="1"
                    y="12.53"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="6.764"
                    y="1"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="6.764"
                    y="6.764"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="6.764"
                    y="12.53"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="12.53"
                    y="1"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="12.529"
                    y="6.764"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect>
                  <rect
                    x="12.529"
                    y="12.53"
                    width="2.471"
                    height="2.471"
                    rx=".825"
                    fill="#64666B"
                    class="svelte-5j34ip"
                  ></rect></svg></div></div></div
        ></div>
      </div>
    </div>
    <template #content>
      <div class="hover-content">
        <div class="hover-title"> 我的营销服务 </div>
        <div class="link-box">
          <a-link href="/#/Report/Home" target="_blank">
            <div
              class="single-box"
              @mouseover="changeIntroText('jwsaas')"
              @mouseleave="changeIntroText('default')"
            >
              <div class="img-box">
                <img
                  src="@/assets/images/jwsaas.png"
                  class="logo-icon"
                  alt=""
                  srcset=""
                />
              </div>
              <span class="logo-text"
                >JWSAAS

                <div class="go-text"> 前往平台 </div>
              </span>
              <!-- <a-tooltip content="巨量引擎、磁力引擎广告搭建平台，点击立即前往">
                <img
                  src="@/assets/images/jwsaas.png"
                  class="logo-icon"
                  alt=""
                  srcset=""
                />
                <span class="logo-text">JWSAAS</span>
            </a-tooltip> -->
            </div>
          </a-link>
        </div>

        <a-divider />
        <div class="footer">
          <icon-info-circle />
          <span> {{ introText[activeKey] }} </span>
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
  const activeKey: any = ref('default');
  const introText: any = ref({
    default: '鼠标悬停在上方任意服务了解更多信息',
    jwsaas: '巨量引擎、磁力引擎广告搭建平台，点击立即前往',
  });

  const changeIntroText = (key: any) => {
    setTimeout(() => {
      activeKey.value = key;
    }, 200);
  };

  const props = defineProps({
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
  });
</script>

<style lang="less" scoped>
  .brand-matrix-entrance.svelte-5j34ip.svelte-5j34ip {
    width: 32px;
    height: 32px;
    // border: 1px solid rgba(255, 255, 255, 0.5);
    border: 1px solid var(--color-border-2);
    cursor: pointer;
    z-index: 1;
    background: linear-gradient(
      180deg,
      rgba(255, 255, 255, 0.19) 0%,
      var(--color-border-1) 100%
    );
    // box-shadow: 0px 10px 20px rgba(0, 0, 0, 0.02);
    box-shadow: 0px 1px 2px var(--color-border-2);
    backdrop-filter: blur(10px);
    border-radius: 4px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    position: relative;
  }
  .brand-matrix.svelte-5j34ip .svelte-5j34ip {
    box-sizing: border-box !important;
  }
  .brand-matrix-entrance-icon.svelte-5j34ip.svelte-5j34ip {
    width: 30px;
    height: 30px;
    border-radius: 3px;
    display: flex;
    align-items: center;
    justify-content: center;
    position: relative;
  }
  .brand-matrix.svelte-5j34ip .svelte-5j34ip {
    box-sizing: border-box !important;
  }

  .tab-box {
    border-radius: 4px;
    &:hover {
      background: var(--color-fill-2);
    }
  }
  .hover-content {
    .hover-title {
      color: var(--color-text-1);
      font-size: 12px;
      padding: 10px 10px;
      font-weight: bold;
    }

    .logo-icon {
      width: 35px;
      height: 18px;
    }
    .logo-text {
      padding-left: 3px;
      font-weight: 500;
      transition: all 0.2s linear;
      &:hover {
        text-decoration: underline;
      }
    }
  }
  .link-box {
    min-width: 200px;
    display: flex;
    padding: 0 10px;
    .single-box {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: space-between;
      width: 95px;
      height: 95px;
      border-radius: 5px;
      cursor: pointer;

      .logo-text {
        position: relative;
        font-size: 12px;
        width: 100%;
        height: 30px;
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--color-text-1);
        .go-text {
          position: absolute;
          width: 100%;
          height: 100%;
          display: flex;
          justify-content: center;
          align-items: center;
          background: rgb(var(--primary-6));
          color: #fff;
          border-radius: 0 0 5px 5px;
          opacity: 0;
        }
      }
      &:hover {
        background: var(--color-fill-1);
        .go-text {
          opacity: 1;
        }
      }
      .img-box {
        display: flex;
        justify-content: center;
        align-items: center;
        background: var(--color-bg-popup);
        height: 48px;
        width: 48px;
        margin-top: 10px;
        border-radius: 10px;
        box-shadow: 0 1px 8px var(--color-fill-1);
        border: 1px solid var(--color-border-2);
      }
    }
  }
  .footer {
    color: var(--color-text-2);
    font-size: 12px;
    padding: 3px 10px;
    width: 300px;
  }
  :deep(.arco-link) {
    padding: 0;
  }
</style>
