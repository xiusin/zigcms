<template>
  <!-- 定制版 图片上传组件 -->
  <!-- {{ fileList }} -->
  <div
    class="upload-image-box"
    :class="{ 'need-right': needRight || !sendParams.pic_type }"
  >
    <div
      v-if="sendParams.pic_type && fileList.length <= 4 && !onlyShow"
      class="badge-box"
    >
      <div class="badge-text">
        {{ sendParams.pic_type }}
      </div>
    </div>
    <a-upload
      v-model:file-list="fileList"
      list-type="picture-card"
      :disabled="disabled"
      :accept="accept"
      :action="`${baseURL}${action}`"
      :tip="tip"
      :headers="headers"
      :multiple="multiple"
      :data="sendParams"
      :limit="limit"
      :show-remove-button="!disabled"
      :image-preview="true"
      :show-retry-button="true"
      @success="handleSuccess"
      @error="handleError"
    >
      <!-- :show-link="true"
    response-url-key="url" -->
      <template #image="{ fileItem }">
        <a-tooltip
          :content="`文件名：${fileItem.name || '-'}`"
          position="bottom"
        >
          <div class="image-box">
            <div v-if="sendParams.pic_type" class="badge-box">
              <div class="badge-text inset">
                {{ sendParams.pic_type }}
              </div>
            </div>
            <a-image
              v-if="fileItem.ext != 'mp4'"
              :class="{ 'not-show-mask': fileItem.status !== 'error' }"
              :src="fileItem.url"
              width="120px"
              height="120px"
            >
            </a-image>
            <div v-else class="video-mask">
              <icon-video-camera :size="20" />
              <span>视频</span>
            </div>
            <div v-if="fileItem.status !== 'error'" class="button-box">
              <icon-eye
                :size="16"
                style="color: #fff"
                class="cur-por"
                @click="onClick(fileItem)"
              />
              <icon-delete
                v-if="!onlyShow"
                style="color: #fff; margin-left: 10px"
                :size="16"
                class="cur-por"
                @click="delItem(fileItem)"
              />
            </div>
          </div>
        </a-tooltip>
      </template>
      <template #error-icon>
        <icon-image-close class="error_text" />
        <span style="font-size: 12px; vertical-align: middle">失败</span>
      </template>
      <template #retry-icon>
        <a-tooltip content="重新上传">
          <icon-refresh class="warning_text" />
        </a-tooltip>
      </template>
    </a-upload>
  </div>
  <a-image-preview-group
    v-model:visible="visible"
    v-model:current="current"
    infinite
    :src-list="srcLists"
  />
  <!-- <XgPlayer ref="playRef"></XgPlayer> -->
</template>

<script lang="ts" setup>
  import { ref, watch } from 'vue';
  import { getToken } from '@/utils/auth';
  import { Message } from '@arco-design/web-vue';
  // import { setWorkFlowField } from '@/api/live';
  // import XgPlayer from '../xgPlayer/xgPlayer.vue';

  const props = defineProps({
    // 用于回显的双向绑定的数据
    modelValue: {
      type: [String, Array],
      default: () => [],
    },
    multiple: {
      type: Boolean,
      default: true,
    },
    sendParams: {
      type: Object,
      default: () => ({}),
    },
    limit: {
      type: Number,
      default: 0,
    },
    accept: {
      type: String,
      default: '.png,.jpg,.jpeg',
    },
    tip: {
      type: String,
      default: '',
    },
    listType: {
      type: String,
      default: 'picture-card',
    },
    disabled: {
      type: Boolean,
      default: false,
    },
    action: {
      type: String,
      default: '/be/api/common/upload',
    },
    setFields: {
      type: Object,
      default: () => ({}),
    },
    onlyShow: {
      type: Boolean,
      default: false,
    },
    // 是否开启内边距，向右
    needRight: {
      type: Boolean,
      default: false,
    },
  });
  const emit = defineEmits(['update:modelValue', 'success', 'change']);
  const baseURL = (import.meta.env.VITE_BASE_URL as string) && '';
  const headers = ref({
    Authorization: `${getToken()}`,
  });
  const uploadRef = ref();
  const visible = ref(false);
  const current = ref(0);
  const srcLists = ref([]);

  let fileList: any = ref<any>([]);
  // const playRef = ref();
  // const playVideo = (videoUrl: any) => {
  //   playRef.value.play(videoUrl);
  // };
  // set工作流字段值
  // 拉取排班数据
  // const setWorkFlowFieldFn = async (data: any = {}) => {
  //   // 过滤fileList
  //   const sendFileList = await fileList.value.filter((item: any) => {
  //     return (
  //       (item.status === 'done' &&
  //         item.response &&
  //         item.response.status !== 500) ||
  //       item.path
  //     );
  //   });
  //   setWorkFlowField({
  //     ...props.setFields,
  //     value: sendFileList,
  //   }).then(
  //     (res: any) => {
  //       console.log(res);
  //       if (res && res.code === 200) {
  //         // monthSchedulesInfo.value = res.data;
  //       }
  //     },
  //     (err: any) => {
  //       console.log(err);
  //     }
  //   );
  // };

  const onClick = (fileItem: any) => {
    if (fileItem.ext === 'mp4') {
      // playVideo(fileItem.url);
      return;
    }

    srcLists.value = fileList.value.map((item: any) => {
      return item.url;
    });
    current.value = srcLists.value.findIndex((val: any) => {
      return val === fileItem.url;
    });
    visible.value = true;
  };

  const delItem = async (fileItem: any) => {
    fileList.value = await fileList.value.filter((val: any) => {
      return val.url !== fileItem.url;
    });
    // 延迟500ms
    // setTimeout(() => {
    //   setWorkFlowFieldFn();
    // }, 500);
  };

  const handleSuccess = (fileItem: any) => {
    // todo 处理成功
    console.log('上传成功', fileItem);
    // emit('update:modelValue', fileItem);
    emit('success', fileItem);
    emit('change', fileItem);
    // 延迟500ms
    // setTimeout(() => {
    //   setWorkFlowFieldFn();
    // }, 500);
  };
  const handleError = (fileItem: any) => {
    console.log('上传失败');
    Message.error('上传失败');
    // 展示此时的fileList
  };

  watch(fileList, async (val) => {
    // 向父组件传递 fileList
    // 深度比较val和modelValue是否相同
    // 如果不同则更新modelValue
    if (val !== props.modelValue) {
      let tmp: any = [];
      let filterOverFlag = true;
      // 提取fileList中的response的data
      for (let key = 0; key < val.length; key += 1) {
        let item = val[key];
        if (item.status === 'uploading') {
          filterOverFlag = false;
        }
        // 校验响应
        if (
          item.status === 'done' &&
          item.response &&
          item.response.code === 200
        ) {
          tmp.push(item.response.data);
        } else if (
          item.status === 'done' &&
          item.response &&
          item.response.code === 500
        ) {
          tmp.push({
            ...item,
            status: 'error',
            url: item.url,
            percent: 0,
          });
          Message.error(item.response.msg);
        } else if (item.path) {
          tmp.push(item);
        }
      }
      console.log(fileList, tmp, '此时的图片数据');
      if (filterOverFlag) {
        emit('update:modelValue', tmp);
      }
    }
  });

  // 监听回显的数据 如果回显数据存在且fileList不存在 fileList不一致 则更新fileList
  watch(
    () => props.modelValue,
    (val) => {
      // console.log(fileList.value);
      if (val && val.length > 0) {
        fileList.value = val;
      } else if (val && val.length === 0 && fileList.value.length > 0) {
        fileList.value = [];
      }
    },
    {
      immediate: true,
    }
  );
</script>

<style lang="less" scoped>
  :deep(.arco-upload-tip) {
    margin-left: 0;
  }
  :deep(.arco-upload-picture-card) {
    width: 120px;
    height: 120px;
    margin-bottom: 20px;
  }
  :deep(.arco-upload-list-picture) {
    width: 120px;
    height: 120px;
    margin-right: 0;
    margin-bottom: 20px;
  }
  .need-right {
    :deep(.arco-upload-list-picture) {
      margin-right: 20px;
    }
  }
  .upload-image-box {
    position: relative;
  }
  .image-box {
    position: relative;
    width: 120px;
    height: 120px;
    .button-box {
      display: flex;
      justify-content: center;
      align-items: center;
      position: absolute;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(0, 0, 0, 0.5);
      z-index: 1000;
      opacity: 0;
      transition: all 0.2s linear;
    }
    &:hover {
      .button-box {
        opacity: 1;
      }
    }
  }
  .not-show-mask {
    position: relative;
    z-index: 999;
  }
  .video-mask {
    width: 100%;
    height: 100%;
    background: var(--color-bg-1);
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .badge-box {
    position: absolute;
    top: -3px;
    right: -17px;
    font-size: 12px;
    z-index: 1000;
    width: 0;
    height: 0;
    border-left: 30px solid transparent;
    border-right: 30px solid transparent;
    border-bottom: 30px solid var(--color-bg-1);
    transform: rotate(45deg);
    .badge-text {
      position: absolute;
      top: 12px;
      left: -17px;
      width: 40px;
      font-size: 12px;
      transform: scale(0.7);
      font-weight: bold;
      color: rgb(var(--primary-6));
      &.inset {
        top: -20px;
        left: -20px;
      }
    }
  }
</style>
