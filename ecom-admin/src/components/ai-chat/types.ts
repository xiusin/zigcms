/**
 * AI 聊天模块类型定义
 */

// 消息角色
export enum MessageRole {
    USER = 'user',
    ASSISTANT = 'assistant',
    SYSTEM = 'system',
}

// 消息状态
export enum MessageStatus {
    SENDING = 'sending',
    SUCCESS = 'success',
    ERROR = 'error',
}

// 消息接口
export interface Message {
    id: string;
    role: MessageRole;
    content: string;
    timestamp: number;
    status?: MessageStatus;
    error?: string;
}

// 聊天 Tab 接口
export interface ChatTab {
    key: string;
    title: string;
    initialMessage?: string;
    messages?: Message[];
}

// AI 请求参数
export interface AIRequestParams {
    message: string;
    conversationId?: string;
    context?: any;
}

// AI 响应接口
export interface AIResponse {
    content: string;
    conversationId: string;
    finished: boolean;
}

// 流式响应事件
export interface StreamEvent {
    type: 'start' | 'chunk' | 'end' | 'error';
    data?: string;
    error?: string;
}
