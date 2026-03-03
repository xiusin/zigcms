<template>
  <div class="chat-panel">
    <!-- 消息列表 -->
    <div ref="messageListRef" class="message-list">
      <div
        v-for="message in messages"
        :key="message.id"
        class="message-item"
        :class="`message-${message.role}`"
      >
        <div class="message-avatar">
          <icon-robot v-if="message.role === 'assistant'" />
          <icon-user v-else />
        </div>
        <div class="message-content">
          <div class="message-text">
            <a-typography-paragraph
              v-if="message.role === 'assistant'"
              :copyable="true"
              style="margin-bottom: 0"
            >
              {{ message.content }}
            </a-typography-paragraph>
            <span v-else>{{ message.content }}</span>
          </div>
          <div class="message-meta">
            <span class="message-time">{{ formatTime(message.timestamp) }}</span>
            <a-tag
              v-if="message.status === 'sending'"
              color="blue"
              size="small"
            >
              发送中...
            </a-tag>
            <a-tag
              v-if="message.status === 'error'"
              color="red"
              size="small"
            >
              {{ message.error || '发送失败' }}
            </a-tag>
          </div>
        </div>
      </div>

      <!-- 加载中提示 -->
      <div v-if="isStreaming" class="message-item message-assistant">
        <div class="message-avatar">
          <icon-robot />
        </div>
        <div class="message-content">
          <div class="message-text streaming">
            <a-typography-paragraph style="margin-bottom: 0">
              {{ streamingContent }}
              <span class="cursor">|</span>
            </a-typography-paragraph>
          </div>
        </div>
      </div>
    </div>

    <!-- 输入区域 -->
    <div class="input-area">
      <a-textarea
        v-model="inputMessage"
        :placeholder="placeholder"
        :auto-size="{ minRows: 1, maxRows: 4 }"
        :disabled="isStreaming"
        @keydown.enter.prevent="handleSend"
      />
      <div class="input-actions">
        <a-button
          type="primary"
          :loading="isStreaming"
          :disabled="!inputMessage.trim()"
          @click="handleSend"
        >
          <template #icon>
            <icon-send />
          </template>
          发送
        </a-button>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch, nextTick, onMounted } from 'vue';
import { IconRobot, IconUser, IconSend } from '@arco-design/web-vue/es/icon';
import { Message as ArcoMessage } from '@arco-design/web-vue';
import { useAIChatStore } from './store';
import { sendMessage } from './api';
import { Message, MessageRole, MessageStatus } from './types';

// Props
const props = defineProps<{
  tabKey: string;
  initialMessage?: string;
}>();

// Emits
const emit = defineEmits<{
  (e: 'update-title', title: string): void;
}>();

// Store
const aiChatStore = useAIChatStore();

// 状态
const inputMessage = ref('');
const messageListRef = ref<HTMLElement>();
const isStreaming = ref(false);
const streamingContent = ref('');
const placeholder = computed(() => 
  isStreaming.value ? 'AI 正在思考中...' : '输入消息，按 Enter 发送'
);

// 消息列表
const messages = computed(() => aiChatStore.getMessages(props.tabKey));

// 格式化时间
const formatTime = (timestamp: number): string => {
  const date = new Date(timestamp);
  const now = new Date();
  const diff = now.getTime() - date.getTime();
  
  // 1分钟内
  if (diff < 60000) {
    return '刚刚';
  }
  
  // 1小时内
  if (diff < 3600000) {
    return `${Math.floor(diff / 60000)}分钟前`;
  }
  
  // 今天
  if (date.toDateString() === now.toDateString()) {
    return date.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' });
  }
  
  // 其他
  return date.toLocaleString('zh-CN', { 
    month: '2-digit', 
    day: '2-digit', 
    hour: '2-digit', 
    minute: '2-digit' 
  });
};

// 滚动到底部
const scrollToBottom = () => {
  nextTick(() => {
    if (messageListRef.value) {
      messageListRef.value.scrollTop = messageListRef.value.scrollHeight;
    }
  });
};

// 发送消息
const handleSend = async () => {
  const content = inputMessage.value.trim();
  if (!content || isStreaming.value) {
    return;
  }

  // 添加用户消息
  const userMessage: Message = {
    id: `msg-${Date.now()}`,
    role: MessageRole.USER,
    content,
    timestamp: Date.now(),
    status: MessageStatus.SUCCESS,
  };
  
  aiChatStore.addMessage(props.tabKey, userMessage);
  inputMessage.value = '';
  scrollToBottom();

  // 更新 Tab 标题（使用消息的前20个字符）
  if (messages.value.length === 1) {
    const title = content.length > 20 ? `${content.slice(0, 20)}...` : content;
    emit('update-title', title);
  }

  // 发送 AI 请求
  isStreaming.value = true;
  streamingContent.value = '';
  scrollToBottom();

  try {
    await sendMessage(
      { message: content },
      // onChunk: 接收到数据块
      (chunk: string) => {
        streamingContent.value += chunk;
        scrollToBottom();
      },
      // onEnd: 流结束
      () => {
        // 添加 AI 响应消息
        const assistantMessage: Message = {
          id: `msg-${Date.now()}`,
          role: MessageRole.ASSISTANT,
          content: streamingContent.value,
          timestamp: Date.now(),
          status: MessageStatus.SUCCESS,
        };
        
        aiChatStore.addMessage(props.tabKey, assistantMessage);
        isStreaming.value = false;
        streamingContent.value = '';
        scrollToBottom();
      },
      // onError: 错误处理
      (error: string) => {
        ArcoMessage.error(`AI 响应失败: ${error}`);
        isStreaming.value = false;
        streamingContent.value = '';
        
        // 添加错误消息
        const errorMessage: Message = {
          id: `msg-${Date.now()}`,
          role: MessageRole.ASSISTANT,
          content: '抱歉，我遇到了一些问题，请稍后再试。',
          timestamp: Date.now(),
          status: MessageStatus.ERROR,
          error,
        };
        
        aiChatStore.addMessage(props.tabKey, errorMessage);
        scrollToBottom();
      }
    );
  } catch (error: any) {
    console.error('Send message error:', error);
    ArcoMessage.error('发送消息失败');
    isStreaming.value = false;
    streamingContent.value = '';
  }
};

// 处理初始消息
onMounted(() => {
  if (props.initialMessage) {
    inputMessage.value = props.initialMessage;
    nextTick(() => {
      handleSend();
    });
  }
});

// 监听消息变化，自动滚动
watch(
  () => messages.value.length,
  () => {
    scrollToBottom();
  }
);
</script>

<style scoped lang="less">
.chat-panel {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: var(--color-bg-1);
}

.message-list {
  flex: 1;
  overflow-y: auto;
  padding: 20px;
  background: var(--color-bg-1);
  
  &::-webkit-scrollbar {
    width: 6px;
  }
  
  &::-webkit-scrollbar-track {
    background: transparent;
  }
  
  &::-webkit-scrollbar-thumb {
    background: var(--color-fill-3);
    border-radius: 3px;
    
    &:hover {
      background: var(--color-fill-4);
    }
  }
}

.message-item {
  display: flex;
  gap: 10px;
  margin-bottom: 20px;
  animation: messageSlideIn 0.3s cubic-bezier(0.34, 1.56, 0.64, 1);
  
  &.message-user {
    flex-direction: row-reverse;
    
    .message-content {
      align-items: flex-end;
    }
    
    .message-text {
      background: rgb(var(--primary-6));
      color: #fff;
      border-radius: 18px 18px 4px 18px;
      box-shadow: 0 2px 8px rgba(var(--primary-6), 0.2);
      position: relative;

      &::after {
        content: '';
        position: absolute;
        right: -6px;
        bottom: 0;
        width: 0;
        height: 0;
        border-style: solid;
        border-width: 0 0 12px 12px;
        border-color: transparent transparent rgb(var(--primary-6)) transparent;
      }
    }

    .message-avatar {
      background: linear-gradient(135deg, rgb(var(--primary-1)) 0%, rgb(var(--primary-2)) 100%);
      border-color: rgb(var(--primary-3));

      svg {
        color: rgb(var(--primary-6));
      }
    }
  }
  
  &.message-assistant {
    .message-text {
      background: var(--color-fill-2);
      color: var(--color-text-1);
      border-radius: 18px 18px 18px 4px;
      box-shadow: 0 2px 4px rgba(0, 0, 0, 0.04);
      position: relative;

      &::after {
        content: '';
        position: absolute;
        left: -6px;
        bottom: 0;
        width: 0;
        height: 0;
        border-style: solid;
        border-width: 0 12px 12px 0;
        border-color: transparent var(--color-fill-2) transparent transparent;
      }
    }

    .message-avatar {
      background: linear-gradient(135deg, var(--color-fill-2) 0%, var(--color-fill-3) 100%);
      border-color: var(--color-border-2);

      svg {
        color: rgb(var(--primary-6));
      }
    }
  }
}

@keyframes messageSlideIn {
  from {
    opacity: 0;
    transform: translateY(15px) scale(0.95);
  }
  to {
    opacity: 1;
    transform: translateY(0) scale(1);
  }
}

.message-avatar {
  width: 36px;
  height: 36px;
  border-radius: 50%;
  border: 2px solid var(--color-border-2);
  display: flex;
  align-items: center;
  justify-content: center;
  flex-shrink: 0;
  transition: all 0.3s;
  box-shadow: 0 2px 4px rgba(0, 0, 0, 0.06);
  
  svg {
    font-size: 20px;
    transition: transform 0.3s;
  }

  &:hover svg {
    transform: scale(1.1);
  }
}

.message-content {
  flex: 1;
  display: flex;
  flex-direction: column;
  gap: 4px;
  max-width: 70%;
}

.message-text {
  padding: 12px 16px;
  border-radius: 16px;
  word-break: break-word;
  line-height: 1.6;
  font-size: 14px;
  max-width: 100%;
  transition: all 0.2s;
  
  &.streaming {
    .cursor {
      display: inline-block;
      width: 2px;
      height: 1em;
      background: currentColor;
      margin-left: 2px;
      animation: blink 1s infinite;
    }
  }

  :deep(.arco-typography) {
    margin-bottom: 0;
    color: inherit;
  }
}

.message-meta {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 0 4px;
  margin-top: 6px;
}

.message-time {
  font-size: 12px;
  color: var(--color-text-4);
}

.input-area {
  border-top: 1px solid var(--color-border);
  padding: 16px;
  background: var(--color-bg-2);
  
  :deep(.arco-textarea-wrapper) {
    margin-bottom: 12px;
    border-radius: 8px;
    
    .arco-textarea {
      font-size: 14px;
      line-height: 1.6;
    }
  }
}

.input-actions {
  display: flex;
  justify-content: flex-end;
  gap: 8px;

  :deep(.arco-btn-primary) {
    border-radius: 6px;
    font-weight: 500;
  }
}

@keyframes blink {
  0%, 50% {
    opacity: 1;
  }
  51%, 100% {
    opacity: 0;
  }
}

</style>
