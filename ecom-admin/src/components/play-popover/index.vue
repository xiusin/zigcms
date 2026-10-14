<template>
  <a-popover position="right" @popup-visible-change="popupChange">
    <template #content>
      <div class="video-box">
        <a-spin
          dot
          tip="加载中"
          :loading="!showVideo"
          style="width: 100%; height: 100%"
        >
          <video
            v-if="showVideo"
            class="video-wrap"
            autoplay
            :src="videoUrl"
            @error="handleError"
          ></video>
          <div class="err-box" :class="{ show: errFlag && showVideo }">
            加载失败，请
            <span class="error_text cur-por" @click="refresh"> 刷新 </span>
            重试
          </div>
        </a-spin>
      </div>
    </template>
    <div class="video-view-box">
      <img v-if="thumb" :src="thumb" alt="" class="cover-ele" />
      <img v-if="thumb" :src="thumb" alt="" class="cover-bg" />
      <div class="video-view-group df jc-cen ai-cen">
        <div
          class="video-view-btn"
          @click="
            $playvideo({
              videoUrl: videoUrl,
            })
          "
        >
          <icon-play-circle-fill />
        </div>
      </div>
    </div>
  </a-popover>
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
  const showVideo = ref(false);
  const handleError = (err: any) => {
    errFlag.value = true;
  };
  const refresh = () => {
    setTimeout(() => {
      showVideo.value = true;
    }, 1000);
  };
  const popupChange = (flag: any) => {
    showVideo.value = false;
    if (flag) {
      refresh();
    }
  };
  watchEffect(() => {
    if (props.videoUrl) {
      errFlag.value = false;
    }
  });
</script>

<style lang="less" scoped>
  .video-box {
    width: 210px;
    min-height: 120px;
    display: flex;
    align-items: center;
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
