<template>
  <div class="shining-gradient-svg_wrapper">
    <div
      class="shining-gradient-svg_gradient shining-gradient-svg_rainbowGradient second"
    >
      <div class="shining-gradient-svg_childWrapper">
        <button class="cta-button_root reset_reset" type="button">
          <div class="avatar_avatarContainer">
            <icon-code-sandbox />
          </div>
          智能创建
          <svg
            fill="none"
            height="16"
            viewBox="0 0 16 16"
            width="16"
            xmlns="http://www.w3.org/2000/svg"
          >
            <path
              d="M3.3335 8H12.6668"
              stroke="white"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1.5"
            ></path>
            <path
              d="M8 3.33331L12.6667 7.99998L8 12.6666"
              stroke="white"
              stroke-linecap="round"
              stroke-linejoin="round"
              stroke-width="1.5"
            ></path>
          </svg>
        </button>
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import { ref } from 'vue';

  const emit = defineEmits(['update:modelValue']);

  const props = defineProps({
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
  });
</script>

<style lang="less" scoped>
  :root,
  body {
    height: 100%;
    background-color: #000;
  }
  .shining-gradient-svg_wrapper {
    --animation-speed: 10s;
    --accents-8: #ffffff;
    --full-gradient: radial-gradient(
      #7ed1ff 0%,
      #26eef1 10%,
      #30bdff 40%,
      #52daff 70%,
      #26eef1 100%
    );
  }

  .shining-gradient-svg_wrapper {
    display: flex;
    align-items: center;
    justify-content: center;
    flex-direction: column;
    position: relative;
    height: 100%;
  }

  .shining-gradient-svg_gradient:before {
    content: '';
    position: absolute;
    z-index: -1;
    inset: calc(var(--b) * -1);
    height: 100%;
    width: 100%;
    background: var(--full-gradient);
    background-size: 300% 300%;
    padding: var(--b);
    border-radius: 32px;
    -webkit-mask: linear-gradient(#fff 0 0) content-box,
      linear-gradient(#fff 0 0);
    mask: linear-gradient(#fff 0 0) content-box, linear-gradient(#fff 0 0);
    -webkit-mask-composite: xor;
    mask-composite: exclude;
    animation: shining-gradient-svg_translateGradient var(--animation-speed)
      linear infinite;
    will-change: background-position;
  }

  .second.shining-gradient-svg_gradient:before {
    -webkit-mask: none;
    mask: none;
    -webkit-mask-composite: none;
    mask-composite: none;
  }

  .third.shining-gradient-svg_gradient:before {
    border-radius: 2px;
  }

  .cta-button_root {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: 29px;
    padding: 16px;
    width: 120px;
    border-radius: 9999px;
    font-size: 12px;
    font-weight: 500;
    font-weight: bold;
    color: var(--accents-8);
    background: rgba(0, 0, 0, 0.1);
    cursor: pointer;
  }

  .reset_reset {
    outline: none;
    margin: 0;
    padding: 0 1em;
    border: 0;
    box-sizing: border-box;
    text-decoration: none;
    -webkit-tap-highlight-color: transparent;
    cursor: pointer;
  }

  .avatar_avatarContainer {
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .avatar_avatar {
    border-radius: 50%;
    pointer-events: none;
  }

  .shining-gradient-svg_childWrapper {
    width: 100%;
  }

  .shining-gradient-svg_gradient {
    --b: 1px;
    position: relative;
    // margin: 1em;
    z-index: 0;
  }

  @keyframes shining-gradient-svg_translateGradient {
    0% {
      background-position: -20% -20%;
    }

    25% {
      background-position: 30% 80%;
    }

    50% {
      background-position: 110% 110%;
    }

    75% {
      background-position: 80% 30%;
    }

    to {
      background-position: -20% -20%;
    }
  }
</style>
