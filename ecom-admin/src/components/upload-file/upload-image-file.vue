<template>
  <div>
    <a-upload
      v-model:file-list="fileList"
      :accept="fileType"
      action="/api/uploadFile"
      :data="sendParams"
      :headers="headers"
      :limit="limit"
      list-type="picture-card"
      image-preview
      :multiple="multiple"
      :disabled="disabled"
      v-bind="$attrs"
      @success="handleSuccess"
      @before-remove="beforeRemove"
      @error="uploadError"
    >
    </a-upload>
  </div>
</template>

<script lang="ts" setup>
  import { getToken } from '@/utils/auth';
  import { ref, watch } from 'vue';
  import { FileItem, Message } from '@arco-design/web-vue';
  import { isArray, toString } from 'lodash';

  const props = defineProps({
    modelValue: {
      type: [Array, String],
      default: () => [],
    },
    fileType: {
      type: String,
      default: '',
    },
    sendParams: {
      type: Object,
      default: () => ({}),
    },
    multiple: {
      type: Boolean,
      default: () => true,
    },
    disabled: {
      type: Boolean,
      default: () => false,
    },
    limit: {
      type: Number,
      default: () => 3,
    },
  });

  const headers = { Authorization: getToken() };
  const emits = defineEmits(['update:modelValue']);
  const fileList = ref<FileItem[]>([]);

  watch(
    () => (props.multiple ? props.modelValue?.length : props.modelValue),
    () => {
      if (props.multiple) {
        if (isArray(props.modelValue)) {
          if (
            props.modelValue?.length !==
            fileList.value.filter((item: FileItem) => item.status === 'done')
              .length
          ) {
            let needUpdateUrls = props.modelValue.filter(
              (item: string) =>
                !fileList.value.find((val: FileItem) => val.url !== item)
            );
            fileList.value = fileList.value.filter(
              (item: FileItem) =>
                item.status !== 'done' ||
                (item.url && props.modelValue?.includes(item.url))
            );
            fileList.value.push(
              ...needUpdateUrls.map(
                (item: string, index: number) =>
                  ({
                    uid: toString(index),
                    status: 'done',
                    url: item,
                  } as FileItem)
              )
            );
          }
        } else {
          fileList.value = [];
        }
      } else if (
        !fileList.value.length ||
        fileList.value[0].response.data.url !== props.modelValue
      ) {
        if (props.modelValue) {
          fileList.value = [
            {
              uid: '1',
              status: 'done',
              url: props.modelValue as string,
            },
          ];
        } else {
          fileList.value = [];
        }
      }
    },
    {
      immediate: true,
    }
  );

  function handleSuccess(fileItem: FileItem) {
    if (fileItem.response?.code === 0) {
      fileItem.url = fileItem.response.data.url;
      emits(
        'update:modelValue',
        props.multiple
          ? [...props.modelValue, fileItem.response.data.url]
          : fileItem.response.data.url
      );
    } else {
      fileList.value = fileList.value.filter(
        (item: FileItem) => item.uid !== fileItem.uid
      );
      Message.error(fileItem.response?.msg || '上传失败，请重试');
    }
  }
  function uploadError(fileItem: FileItem) {
    if (fileItem.response?.code === 1) {
      fileList.value = fileList.value.filter(
        (item: FileItem) => item.uid !== fileItem.uid
      );
      Message.error(fileItem.response?.msg || '上传失败，请重试');
    } else {
      Message.error('上传失败，请重试');
    }
  }

  const beforeRemove = (file: FileItem) => {
    return new Promise((resolve, reject) => {
      if (file.status === 'done') {
        if (props.multiple) {
          if (isArray(props.modelValue)) {
            emits(
              'update:modelValue',
              props.modelValue.filter((item: string) => item !== file.url)
            );
          }
        } else {
          emits('update:modelValue', '');
        }
      }
      resolve(true);
    });
  };
</script>

<style lang="less" scoped></style>
