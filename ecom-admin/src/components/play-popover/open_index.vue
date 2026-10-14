<template>
  <div class="video-view-box">
    <img v-if="thumb" :src="thumb" alt="" class="cover-ele" />
    <img v-if="thumb" :src="thumb" alt="" class="cover-bg" />
    <div class="video-view-group df jc-cen ai-cen" @click="viewVideo">
      <div class="video-view-btn">
        <icon-play-circle-fill />
      </div>
    </div>
  </div>
</template>

<script lang="ts" setup>
  import { ref, watchEffect } from 'vue';

  const emit = defineEmits(['update:modelValue']);

  const props = defineProps({
    modelValue: {
      type: [String, Number, Array],
      default: () => '',
    },
    thumb: {
      type: [String],
      default: '',
    },
    videoUrl: {
      type: [String],
      default: '',
    },
  });
  const errFlag = ref(false);
  const showVideo = ref(true);
  const handleError = (err: any) => {
    errFlag.value = true;
  };
  const refresh = () => {
    showVideo.value = false;
    setTimeout(() => {
      showVideo.value = true;
    }, 1000);
  };
  watchEffect(() => {
    if (props.videoUrl) {
      errFlag.value = false;
    }
  });
  const viewVideo = async (record: any) => {
    if (props.videoUrl) {
      let parm = `\u003cscript\u003elocation.replace("${props.videoUrl}")\u003c/script\u003e`;
      // eslint-disable-next-line no-script-url
      return window.open('javascript:window.name;', parm);
    }
  };
</script>

<style lang="less" scoped>
  .video-box {
    width: 210px;
    background: #fff;
    .video-wrap {
      position: relative;
      width: 100%;
      height: 100%;
      border-radius: 5px;
    }
  }

  .err-box {
    position: absolute;
    top: 0;
    left: 0;
    width: 100%;
    height: 100%;
    display: none;
    justify-content: center;
    align-items: center;
    z-index: 2;
    border-radius: 5px;
    background: #000;
    color: #fff;
    &.show {
      display: flex;
    }
  }
</style>
