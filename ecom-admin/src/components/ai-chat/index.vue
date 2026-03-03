<template>
  <div class="ai-chat-container">
    <!-- 右下角角标 -->
    <transition name="badge-fade">
      <div
        v-if="!isExpanded"
        class="ai-chat-badge"
        @click="toggleExpand"
      >
        <icon-robot class="badge-icon" />
        <span v-if="unreadCount > 0" class="badge-count">{{ unreadCount }}</span>
      </div>
    </transition>

    <!-- 聊天窗口 -->
    <transition name="window-expand">
      <div v-if="isExpanded" class="ai-chat-window">
        <!-- 窗口头部 -->
        <div class="chat-header">
          <div class="header-left">
            <icon-robot class="header-icon" />
            <span class="header-title">AI 助手</span>
          </div>
          <div class="header-actions">
            <a-button
              type="text"
              size="small"
              @click="showSettings = true"
            >
              <template #icon>
                <icon-settings />
              </template>
            </a-button>
            <a-button
              type="text"
              size="small"
              @click="minimizeWindow"
            >
              <template #icon>
                <icon-minus />
              </template>
            </a-button>
            <a-button
              type="text"
              size="small"
              @click="closeWindow"
            >
              <template #icon>
                <icon-close />
              </template>
            </a-button>
          </div>
        </div>

        <!-- 左右分栏布局 -->
        <div class="chat-body">
          <!-- 左侧对话列表 -->
          <div class="conversation-list">
            <div class="list-header">
              <span class="list-title">对话列表</span>
              <a-button
                type="text"
                size="mini"
                @click="handleAddTab"
              >
                <template #icon>
                  <icon-plus />
                </template>
              </a-button>
            </div>
            <div class="list-content">
              <div
                v-for="tab in tabs"
                :key="tab.key"
                class="conversation-item"
                :class="{ active: activeTabKey === tab.key }"
                @click="activeTabKey = tab.key"
              >
                <div class="conversation-info">
                  <div class="conversation-title">{{ tab.title }}</div>
                  <div class="conversation-preview">
                    {{ getConversationPreview(tab.key) }}
                  </div>
                </div>
                <a-button
                  v-if="tabs.length > 1"
                  type="text"
                  size="mini"
                  class="delete-btn"
                  @click.stop="handleDeleteTab(tab.key)"
                >
                  <template #icon>
                    <icon-close />
                  </template>
                </a-button>
              </div>
              <a-empty
                v-if="tabs.length === 0"
                description="暂无对话"
                style="margin-top: 60px"
              />
            </div>
          </div>

          <!-- 右侧聊天内容 -->
          <div class="chat-content">
            <chat-panel
              v-for="tab in tabs"
              v-show="activeTabKey === tab.key"
              :key="tab.key"
              :ref="(el) => setChatPanelRef(tab.key, el)"
              :tab-key="tab.key"
              :initial-message="tab.initialMessage"
              @update-title="(title) => updateTabTitle(tab.key, title)"
            />
          </div>
        </div>
      </div>
    </transition>

    <!-- 设置抽屉 -->
    <a-drawer
      v-model:visible="showSettings"
      title="AI 助手设置"
      :width="400"
      unmount-on-close
    >
      <a-form :model="settings" layout="vertical">
        <a-form-item label="系统提示词（咒语）" tooltip="设置 AI 的角色和行为规则">
          <a-textarea
            v-model="settings.systemPrompt"
            placeholder="例如：你是一个专业的代码审查助手，擅长发现代码中的问题..."
            :auto-size="{ minRows: 6, maxRows: 12 }"
            allow-clear
          />
        </a-form-item>
        
        <a-form-item label="温度参数" tooltip="控制回答的随机性，0-1之间，越高越随机">
          <a-slider
            v-model="settings.temperature"
            :min="0"
            :max="1"
            :step="0.1"
            :marks="{ 0: '精确', 0.5: '平衡', 1: '创造' }"
          />
        </a-form-item>

        <a-form-item label="最大回复长度">
          <a-input-number
            v-model="settings.maxTokens"
            :min="100"
            :max="4000"
            :step="100"
            style="width: 100%"
          />
        </a-form-item>

        <a-form-item label="快捷指令">
          <a-space direction="vertical" fill>
            <a-button
              v-for="(prompt, index) in quickPrompts"
              :key="index"
              long
              @click="useQuickPrompt(prompt)"
            >
              {{ prompt.title }}
            </a-button>
          </a-space>
        </a-form-item>
      </a-form>

      <template #footer>
        <a-space>
          <a-button @click="resetSettings">重置</a-button>
          <a-button type="primary" @click="saveSettings">保存</a-button>
        </a-space>
      </template>
    </a-drawer>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive, computed, onMounted, onUnmounted } from 'vue';
import { IconRobot, IconMinus, IconClose, IconPlus, IconSettings } from '@arco-design/web-vue/es/icon';
import { Message } from '@arco-design/web-vue';
import ChatPanel from './ChatPanel.vue';
import { useAIChatStore } from './store';

const aiChatStore = useAIChatStore();

// 状态
const isExpanded = ref(false);
const activeTabKey = ref('tab-1');
const tabs = ref([
  { key: 'tab-1', title: '新对话', initialMessage: '' }
]);
const chatPanelRefs = reactive<Record<string, any>>({});
const unreadCount = computed(() => aiChatStore.unreadCount);
const showSettings = ref(false);

// 设置
const settings = reactive({
  systemPrompt: '',
  temperature: 0.7,
  maxTokens: 2000,
});

// 快捷指令
const quickPrompts = [
  { title: '代码审查助手', prompt: '你是一个专业的代码审查助手，擅长发现代码中的问题、性能瓶颈和安全隐患。' },
  { title: '数据分析专家', prompt: '你是一个数据分析专家，擅长从数据中发现规律和洞察。' },
  { title: 'Bug 诊断专家', prompt: '你是一个 Bug 诊断专家，擅长分析问题原因并提供解决方案。' },
  { title: '技术文档助手', prompt: '你是一个技术文档助手，擅长编写清晰易懂的技术文档。' },
];

// 本地存储键
const STORAGE_KEYS = {
  TABS: 'ai-chat-tabs',
  ACTIVE_TAB: 'ai-chat-active-tab',
  SETTINGS: 'ai-chat-settings',
};

// 设置 ChatPanel 引用
const setChatPanelRef = (key: string, el: any) => {
  if (el) {
    chatPanelRefs[key] = el;
  }
};

// 获取对话预览文本
const getConversationPreview = (key: string): string => {
  const messages = aiChatStore.getMessages(key);
  if (messages.length === 0) {
    return '开始新对话...';
  }
  const lastMessage = messages[messages.length - 1];
  const preview = lastMessage.content.replace(/\n/g, ' ').slice(0, 30);
  return preview.length < lastMessage.content.length ? `${preview}...` : preview;
};

// 保存到本地存储
const saveToLocalStorage = () => {
  try {
    localStorage.setItem(STORAGE_KEYS.TABS, JSON.stringify(tabs.value));
    localStorage.setItem(STORAGE_KEYS.ACTIVE_TAB, activeTabKey.value);
  } catch (error) {
    console.error('保存对话失败:', error);
  }
};

// 从本地存储加载
const loadFromLocalStorage = () => {
  try {
    const savedTabs = localStorage.getItem(STORAGE_KEYS.TABS);
    const savedActiveTab = localStorage.getItem(STORAGE_KEYS.ACTIVE_TAB);
    const savedSettings = localStorage.getItem(STORAGE_KEYS.SETTINGS);

    if (savedTabs) {
      const parsedTabs = JSON.parse(savedTabs);
      if (parsedTabs.length > 0) {
        tabs.value = parsedTabs;
      }
    }

    if (savedActiveTab) {
      activeTabKey.value = savedActiveTab;
    }

    if (savedSettings) {
      Object.assign(settings, JSON.parse(savedSettings));
    }
  } catch (error) {
    console.error('加载对话失败:', error);
  }
};

// 切换展开/收起
const toggleExpand = () => {
  isExpanded.value = !isExpanded.value;
  if (isExpanded.value) {
    aiChatStore.clearUnread();
  }
};

// 最小化窗口
const minimizeWindow = () => {
  isExpanded.value = false;
};

// 关闭窗口
const closeWindow = () => {
  isExpanded.value = false;
};

// 添加新 Tab
const handleAddTab = () => {
  const newKey = `tab-${Date.now()}`;
  tabs.value.push({
    key: newKey,
    title: '新对话',
    initialMessage: '',
  });
  activeTabKey.value = newKey;
  saveToLocalStorage();
};

// 删除 Tab
const handleDeleteTab = (key: string) => {
  const index = tabs.value.findIndex(tab => tab.key === key);
  if (index > -1) {
    tabs.value.splice(index, 1);
    delete chatPanelRefs[key];
    aiChatStore.clearMessages(key);
    
    if (activeTabKey.value === key && tabs.value.length > 0) {
      activeTabKey.value = tabs.value[Math.max(0, index - 1)].key;
    }
    
    saveToLocalStorage();
  }
};

// 更新 Tab 标题
const updateTabTitle = (key: string, title: string) => {
  const tab = tabs.value.find(t => t.key === key);
  if (tab) {
    tab.title = title;
    saveToLocalStorage();
  }
};

// 创建新对话（供外部调用）
const createConversation = (message: string, title?: string) => {
  const newKey = `tab-${Date.now()}`;
  tabs.value.push({
    key: newKey,
    title: title || '新对话',
    initialMessage: message,
  });
  activeTabKey.value = newKey;
  isExpanded.value = true;
  saveToLocalStorage();
};

// 使用快捷指令
const useQuickPrompt = (prompt: { title: string; prompt: string }) => {
  settings.systemPrompt = prompt.prompt;
  Message.success(`已应用：${prompt.title}`);
};

// 保存设置
const saveSettings = () => {
  try {
    localStorage.setItem(STORAGE_KEYS.SETTINGS, JSON.stringify(settings));
    Message.success('设置已保存');
    showSettings.value = false;
  } catch (error) {
    Message.error('保存设置失败');
  }
};

// 重置设置
const resetSettings = () => {
  settings.systemPrompt = '';
  settings.temperature = 0.7;
  settings.maxTokens = 2000;
  Message.success('设置已重置');
};

// 监听全局事件
onMounted(() => {
  // 加载本地存储
  loadFromLocalStorage();
  
  // 监听创建对话事件
  window.addEventListener('ai-chat:create', ((e: CustomEvent) => {
    createConversation(e.detail.message, e.detail.title);
  }) as EventListener);
});

onUnmounted(() => {
  window.removeEventListener('ai-chat:create', (() => {}) as EventListener);
});

// 暴露方法供外部调用
defineExpose({
  createConversation,
  settings,
});
</script>

<style scoped lang="less">
.ai-chat-container {
  position: fixed;
  z-index: 9999;
}

// 角标样式
.ai-chat-badge {
  position: fixed;
  right: 24px;
  bottom: 24px;
  width: 56px;
  height: 56px;
  background: rgb(var(--primary-6));
  border-radius: 50%;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(var(--primary-6), 0.3);
  transition: all 0.3s cubic-bezier(0.34, 0.69, 0.1, 1);

  &:hover {
    background: rgb(var(--primary-5));
    transform: translateY(-2px);
    box-shadow: 0 6px 16px rgba(var(--primary-6), 0.4);
  }

  &:active {
    transform: translateY(0);
  }

  .badge-icon {
    font-size: 28px;
    color: #fff;
  }

  .badge-count {
    position: absolute;
    top: -4px;
    right: -4px;
    min-width: 20px;
    height: 20px;
    padding: 0 6px;
    background: rgb(var(--danger-6));
    color: #fff;
    font-size: 12px;
    line-height: 20px;
    text-align: center;
    border-radius: 10px;
    border: 2px solid #fff;
  }
}

// 窗口样式
.ai-chat-window {
  position: fixed;
  right: 24px;
  bottom: 24px;
  width: 800px;
  height: 600px;
  background: var(--color-bg-1);
  border-radius: 12px;
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.12);
  display: flex;
  flex-direction: column;
  overflow: hidden;
  border: 1px solid var(--color-border);

  .chat-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 10px 16px;
    background: var(--color-bg-2);
    border-bottom: 1px solid var(--color-border);
    color: var(--color-text-1);
    min-height: 48px;

    .header-left {
      display: flex;
      align-items: center;
      gap: 8px;

      .header-icon {
        font-size: 20px;
        color: rgb(var(--primary-6));
      }

      .header-title {
        font-size: 15px;
        font-weight: 600;
      }
    }

    .header-actions {
      display: flex;
      gap: 2px;

      :deep(.arco-btn-text) {
        color: var(--color-text-2);
        padding: 4px 8px;

        &:hover {
          background: var(--color-fill-2);
          color: var(--color-text-1);
        }
      }
    }
  }

  .chat-body {
    flex: 1;
    display: flex;
    overflow: hidden;
  }
}

// 左侧对话列表
.conversation-list {
  width: 240px;
  background: var(--color-bg-2);
  border-right: 1px solid var(--color-border);
  display: flex;
  flex-direction: column;

  .list-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 16px;
    border-bottom: 1px solid var(--color-border);

    .list-title {
      font-size: 14px;
      font-weight: 500;
      color: var(--color-text-1);
    }

    :deep(.arco-btn-text) {
      color: var(--color-text-2);

      &:hover {
        color: rgb(var(--primary-6));
        background: var(--color-fill-2);
      }
    }
  }

  .list-content {
    flex: 1;
    overflow-y: auto;
    padding: 8px;

    &::-webkit-scrollbar {
      width: 6px;
    }

    &::-webkit-scrollbar-thumb {
      background: var(--color-fill-3);
      border-radius: 3px;

      &:hover {
        background: var(--color-fill-4);
      }
    }
  }
}

.conversation-item {
  display: flex;
  align-items: center;
  gap: 8px;
  padding: 12px;
  margin-bottom: 4px;
  border-radius: 8px;
  cursor: pointer;
  transition: all 0.2s;
  position: relative;

  &:hover {
    background: var(--color-fill-2);

    .delete-btn {
      opacity: 1;
    }
  }

  &.active {
    background: rgb(var(--primary-1));
    border: 1px solid rgb(var(--primary-3));

    .conversation-title {
      color: rgb(var(--primary-6));
      font-weight: 500;
    }
  }

  .conversation-info {
    flex: 1;
    min-width: 0;
  }

  .conversation-title {
    font-size: 14px;
    color: var(--color-text-1);
    margin-bottom: 4px;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .conversation-preview {
    font-size: 12px;
    color: var(--color-text-3);
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }

  .delete-btn {
    opacity: 0;
    transition: opacity 0.2s;
    flex-shrink: 0;

    :deep(.arco-icon) {
      font-size: 14px;
    }

    &:hover {
      color: rgb(var(--danger-6));
      background: rgb(var(--danger-1));
    }
  }
}

// 右侧聊天内容
.chat-content {
  flex: 1;
  overflow: hidden;
  background: var(--color-bg-1);
}

// 移除旧的 tabs 样式
:deep(.arco-tabs) {
  display: none;
}

// 动画
.badge-fade-enter-active,
.badge-fade-leave-active {
  transition: all 0.3s ease;
}

.badge-fade-enter-from,
.badge-fade-leave-to {
  opacity: 0;
  transform: scale(0.8);
}

.window-expand-enter-active {
  animation: window-expand-in 0.4s cubic-bezier(0.34, 1.56, 0.64, 1);
}

.window-expand-leave-active {
  animation: window-expand-out 0.3s ease;
}

@keyframes window-expand-in {
  from {
    opacity: 0;
    transform: scale(0.3) translateY(100px);
    transform-origin: bottom right;
  }
  to {
    opacity: 1;
    transform: scale(1) translateY(0);
    transform-origin: bottom right;
  }
}

@keyframes window-expand-out {
  from {
    opacity: 1;
    transform: scale(1) translateY(0);
  }
  to {
    opacity: 0;
    transform: scale(0.3) translateY(100px);
  }
}
</style>
