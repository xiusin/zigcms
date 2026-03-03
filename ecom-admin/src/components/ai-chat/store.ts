/**
 * AI 聊天模块 Pinia Store
 */
import { defineStore } from 'pinia';
import { ref, computed, watch } from 'vue';
import type { Message } from './types';

const STORAGE_KEY = 'ai-chat-conversations';

export const useAIChatStore = defineStore('ai-chat', () => {
    // 状态
    const unreadCount = ref(0);
    const conversations = ref<Record<string, Message[]>>({});
    const isLoading = ref(false);

    // 计算属性
    const hasUnread = computed(() => unreadCount.value > 0);

    // 从本地存储加载
    const loadFromStorage = () => {
        try {
            const saved = localStorage.getItem(STORAGE_KEY);
            if (saved) {
                conversations.value = JSON.parse(saved);
            }
        } catch (error) {
            console.error('加载对话历史失败:', error);
        }
    };

    // 保存到本地存储
    const saveToStorage = () => {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(conversations.value));
        } catch (error) {
            console.error('保存对话历史失败:', error);
        }
    };

    // 监听 conversations 变化，自动保存
    watch(conversations, () => {
        saveToStorage();
    }, { deep: true });

    // 方法
    const addMessage = (tabKey: string, message: Message) => {
        if (!conversations.value[tabKey]) {
            conversations.value[tabKey] = [];
        }
        conversations.value[tabKey].push(message);
    };

    const updateMessage = (tabKey: string, messageId: string, updates: Partial<Message>) => {
        const messages = conversations.value[tabKey];
        if (messages) {
            const index = messages.findIndex(m => m.id === messageId);
            if (index > -1) {
                messages[index] = { ...messages[index], ...updates };
            }
        }
    };

    const getMessages = (tabKey: string): Message[] => {
        return conversations.value[tabKey] || [];
    };

    const clearMessages = (tabKey: string) => {
        delete conversations.value[tabKey];
    };

    const clearAllMessages = () => {
        conversations.value = {};
        localStorage.removeItem(STORAGE_KEY);
    };

    const incrementUnread = () => {
        unreadCount.value += 1;
    };

    const clearUnread = () => {
        unreadCount.value = 0;
    };

    const setLoading = (loading: boolean) => {
        isLoading.value = loading;
    };

    // 初始化时加载
    loadFromStorage();

    return {
        // 状态
        unreadCount,
        conversations,
        isLoading,
        hasUnread,

        // 方法
        addMessage,
        updateMessage,
        getMessages,
        clearMessages,
        clearAllMessages,
        incrementUnread,
        clearUnread,
        setLoading,
        loadFromStorage,
    };
});
