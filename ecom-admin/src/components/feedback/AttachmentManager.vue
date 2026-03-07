<template>
  <div class="attachment-manager">
    <!-- 附件列表 -->
    <div v-if="attachments.length > 0" class="attachment-list">
      <div
        v-for="(attachment, index) in attachments"
        :key="index"
        class="attachment-item"
      >
        <div class="attachment-icon">
          <icon-file v-if="!isImage(attachment)" />
          <icon-image v-else />
        </div>
        
        <div class="attachment-info">
          <div class="attachment-name" :title="attachment.name">
            {{ attachment.name }}
          </div>
          <div class="attachment-meta">
            <span class="attachment-size">{{ formatSize(attachment.size) }}</span>
            <span v-if="attachment.uploaded_at" class="attachment-time">
              {{ formatTime(attachment.uploaded_at) }}
            </span>
          </div>
        </div>
        
        <div class="attachment-actions">
          <a-button
            type="text"
            size="small"
            @click="handlePreview(attachment)"
          >
            <template #icon><icon-eye /></template>
          </a-button>
          <a-button
            type="text"
            size="small"
            @click="handleDownload(attachment)"
          >
            <template #icon><icon-download /></template>
          </a-button>
          <a-button
            v-if="!readonly"
            type="text"
            size="small"
            status="danger"
            @click="handleDelete(index)"
          >
            <template #icon><icon-delete /></template>
          </a-button>
        </div>
      </div>
    </div>
    
    <!-- 上传区域 -->
    <div v-if="!readonly" class="upload-area">
      <a-upload
        :file-list="fileList"
        :custom-request="handleUpload"
        :limit="limit"
        :accept="accept"
        :multiple="multiple"
        :show-file-list="false"
        @before-upload="handleBeforeUpload"
      >
        <template #upload-button>
          <a-button type="outline">
            <template #icon><icon-upload /></template>
            {{ buttonText }}
          </a-button>
        </template>
      </a-upload>
      
      <div class="upload-tips">
        <span>支持格式：{{ acceptText }}</span>
        <span>单个文件不超过 {{ maxSize }}MB</span>
        <span v-if="limit">最多上传 {{ limit }} 个文件</span>
      </div>
    </div>
    
    <!-- 图片预览 -->
    <a-image-preview-group
      v-model:visible="previewVisible"
      :src-list="previewImages"
      :current="previewIndex"
    />
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import type { FileItem, RequestOption } from '@arco-design/web-vue';
import { formatDateTime } from '@/utils/date';

interface Attachment {
  name: string;
  url: string;
  size: number;
  type?: string;
  uploaded_at?: number;
}

interface Props {
  attachments: Attachment[];
  readonly?: boolean;
  limit?: number;
  maxSize?: number; // MB
  accept?: string;
  multiple?: boolean;
  buttonText?: string;
}

const props = withDefaults(defineProps<Props>(), {
  readonly: false,
  limit: 10,
  maxSize: 10,
  accept: '*',
  multiple: true,
  buttonText: '上传附件',
});

const emit = defineEmits<{
  add: [attachment: Attachment];
  delete: [index: number];
}>();

const fileList = ref<FileItem[]>([]);
const previewVisible = ref(false);
const previewIndex = ref(0);

// 支持的图片格式
const imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.webp', '.svg'];

// 格式化文件大小
const formatSize = (bytes: number): string => {
  if (bytes === 0) return '0 B';
  
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
};

// 格式化时间
const formatTime = (timestamp: number): string => {
  return formatDateTime(timestamp);
};

// 判断是否为图片
const isImage = (attachment: Attachment): boolean => {
  const ext = attachment.name.substring(attachment.name.lastIndexOf('.')).toLowerCase();
  return imageExtensions.includes(ext);
};

// 获取接受的文件类型文本
const acceptText = computed(() => {
  if (props.accept === '*') return '所有文件';
  return props.accept.split(',').join('、');
});

// 预览图片列表
const previewImages = computed(() => {
  return props.attachments
    .filter((attachment) => isImage(attachment))
    .map((attachment) => attachment.url);
});

// 上传前检查
const handleBeforeUpload = (file: File): boolean => {
  // 检查文件数量
  if (props.limit && props.attachments.length >= props.limit) {
    Message.warning(`最多只能上传 ${props.limit} 个文件`);
    return false;
  }
  
  // 检查文件大小
  const maxBytes = props.maxSize * 1024 * 1024;
  if (file.size > maxBytes) {
    Message.warning(`文件大小不能超过 ${props.maxSize}MB`);
    return false;
  }
  
  // 检查文件类型
  if (props.accept !== '*') {
    const ext = file.name.substring(file.name.lastIndexOf('.')).toLowerCase();
    const acceptList = props.accept.split(',').map((item) => item.trim());
    
    if (!acceptList.includes(ext) && !acceptList.includes(file.type)) {
      Message.warning(`不支持的文件格式: ${ext}`);
      return false;
    }
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
    
    // 模拟上传延迟
    await new Promise((resolve) => setTimeout(resolve, 1000));
    
    // 模拟上传成功，返回文件URL
    const mockUrl = URL.createObjectURL(fileItem.file!);
    
    const attachment: Attachment = {
      name: fileItem.name,
      url: mockUrl,
      size: fileItem.file!.size,
      type: fileItem.file!.type,
      uploaded_at: Date.now(),
    };
    
    emit('add', attachment);
    onSuccess();
    Message.success(`${fileItem.name} 上传成功`);
  } catch (error: any) {
    onError(error);
    Message.error(`${fileItem.name} 上传失败`);
  }
};

// 预览附件
const handlePreview = (attachment: Attachment) => {
  if (isImage(attachment)) {
    // 图片预览
    const index = props.attachments
      .filter((item) => isImage(item))
      .findIndex((item) => item.url === attachment.url);
    
    previewIndex.value = index;
    previewVisible.value = true;
  } else {
    // 其他文件直接下载
    handleDownload(attachment);
  }
};

// 下载附件
const handleDownload = (attachment: Attachment) => {
  const link = document.createElement('a');
  link.href = attachment.url;
  link.download = attachment.name;
  link.click();
};

// 删除附件
const handleDelete = (index: number) => {
  emit('delete', index);
  Message.success('附件已删除');
};
</script>

<style scoped lang="less">
.attachment-manager {
  .attachment-list {
    margin-bottom: 16px;
    
    .attachment-item {
      display: flex;
      align-items: center;
      padding: 12px;
      border: 1px solid var(--color-border-2);
      border-radius: 4px;
      margin-bottom: 8px;
      transition: all 0.3s;
      
      &:hover {
        border-color: var(--color-border-3);
        background: var(--color-fill-1);
      }
      
      &:last-child {
        margin-bottom: 0;
      }
      
      .attachment-icon {
        font-size: 24px;
        color: var(--color-text-3);
        margin-right: 12px;
      }
      
      .attachment-info {
        flex: 1;
        min-width: 0;
        
        .attachment-name {
          font-size: 14px;
          font-weight: 500;
          color: var(--color-text-1);
          overflow: hidden;
          text-overflow: ellipsis;
          white-space: nowrap;
        }
        
        .attachment-meta {
          display: flex;
          gap: 12px;
          margin-top: 4px;
          font-size: 12px;
          color: var(--color-text-3);
        }
      }
      
      .attachment-actions {
        display: flex;
        gap: 4px;
      }
    }
  }
  
  .upload-area {
    .upload-tips {
      display: flex;
      flex-wrap: wrap;
      gap: 16px;
      margin-top: 8px;
      font-size: 12px;
      color: var(--color-text-3);
    }
  }
}
</style>
