<template>
  <div class="attachment-upload">
    <a-upload
      :file-list="fileList"
      :custom-request="handleUpload"
      :before-upload="beforeUpload"
      :on-remove="handleRemove"
      :multiple="multiple"
      :accept="accept"
      :limit="limit"
      :show-file-list="true"
      list-type="picture-card"
    >
      <template #upload-button>
        <div class="upload-button">
          <icon-plus />
          <div class="upload-text">上传附件</div>
        </div>
      </template>
    </a-upload>

    <div v-if="tip" class="upload-tip">
      {{ tip }}
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FileItem, RequestOption } from '@arco-design/web-vue';

interface Props {
  modelValue: FileItem[];
  accept?: string;
  multiple?: boolean;
  limit?: number;
  maxSize?: number; // MB
  tip?: string;
}

interface Emits {
  (e: 'update:modelValue', files: FileItem[]): void;
  (e: 'change', files: FileItem[]): void;
}

const props = withDefaults(defineProps<Props>(), {
  accept: '*',
  multiple: true,
  limit: 10,
  maxSize: 10,
  tip: '支持上传图片、文档等文件，单个文件不超过 10MB',
});

const emit = defineEmits<Emits>();

const fileList = ref<FileItem[]>([]);

// 监听外部值变化
watch(
  () => props.modelValue,
  (newValue) => {
    fileList.value = newValue;
  },
  { immediate: true }
);

// 上传前验证
const beforeUpload = (file: File): boolean => {
  // 验证文件大小
  const sizeMB = file.size / 1024 / 1024;
  if (sizeMB > props.maxSize) {
    Message.error(`文件大小不能超过 ${props.maxSize}MB`);
    return false;
  }

  // 验证文件数量
  if (fileList.value.length >= props.limit) {
    Message.error(`最多只能上传 ${props.limit} 个文件`);
    return false;
  }

  return true;
};

// 自定义上传
const handleUpload = async (option: RequestOption) => {
  const { fileItem, onProgress, onSuccess, onError } = option;

  try {
    // 模拟上传进度
    let progress = 0;
    const timer = setInterval(() => {
      progress += 10;
      onProgress(progress);

      if (progress >= 100) {
        clearInterval(timer);
      }
    }, 100);

    // 实际项目中应该调用上传 API
    // const formData = new FormData();
    // formData.append('file', fileItem.file!);
    // const response = await uploadFile(formData);

    // 模拟上传成功
    setTimeout(() => {
      clearInterval(timer);

      // 生成文件 URL（实际项目中应该使用服务器返回的 URL）
      const url = URL.createObjectURL(fileItem.file!);

      const newFile: FileItem = {
        ...fileItem,
        status: 'done',
        url,
        response: { url },
      };

      fileList.value.push(newFile);
      emit('update:modelValue', fileList.value);
      emit('change', fileList.value);

      onSuccess({ url });
      Message.success('上传成功');
    }, 1000);
  } catch (error) {
    onError(error as Error);
    Message.error('上传失败');
    console.error(error);
  }
};

// 删除文件
const handleRemove = (fileItem: FileItem) => {
  const index = fileList.value.findIndex((item) => item.uid === fileItem.uid);
  if (index > -1) {
    fileList.value.splice(index, 1);
    emit('update:modelValue', fileList.value);
    emit('change', fileList.value);
  }
};
</script>

<style scoped lang="less">
.attachment-upload {
  .upload-button {
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    width: 100%;
    height: 100%;
    color: var(--color-text-3);

    .upload-text {
      margin-top: 8px;
      font-size: 12px;
    }
  }

  .upload-tip {
    margin-top: 8px;
    font-size: 12px;
    color: var(--color-text-3);
  }
}
</style>
