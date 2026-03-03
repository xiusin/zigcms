/**
 * AI 聊天 API
 * 实现流式响应处理
 */
import type { AIRequestParams, StreamEvent } from './types';

/**
 * 发送 AI 消息（流式响应）
 * @param params 请求参数
 * @param onChunk 接收到数据块时的回调
 * @param onEnd 流结束时的回调
 * @param onError 错误时的回调
 */
export async function sendAIMessage(
    params: AIRequestParams,
    onChunk: (chunk: string) => void,
    onEnd: () => void,
    onError: (error: string) => void
): Promise<void> {
    try {
        // TODO: 替换为实际的 AI API 端点
        const apiUrl = '/api/ai/chat/stream';

        const response = await fetch(apiUrl, {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Authorization': `Bearer ${localStorage.getItem('token') || ''}`,
            },
            body: JSON.stringify(params),
        });

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        // 检查是否支持流式响应
        if (!response.body) {
            throw new Error('Stream not supported');
        }

        const reader = response.body.getReader();
        const decoder = new TextDecoder();

        // 读取流
        while (true) {
            const { done, value } = await reader.read();

            if (done) {
                onEnd();
                break;
            }

            // 解码数据块
            const chunk = decoder.decode(value, { stream: true });

            // 处理 SSE 格式（Server-Sent Events）
            const lines = chunk.split('\n');
            for (const line of lines) {
                if (line.startsWith('data: ')) {
                    const data = line.slice(6).trim();

                    // 跳过空行和结束标记
                    if (!data || data === '[DONE]') {
                        continue;
                    }

                    try {
                        const parsed = JSON.parse(data);
                        if (parsed.content) {
                            onChunk(parsed.content);
                        }
                    } catch (e) {
                        // 如果不是 JSON，直接作为文本处理
                        onChunk(data);
                    }
                }
            }
        }
    } catch (error: any) {
        console.error('AI API Error:', error);
        onError(error.message || '请求失败');
    }
}

/**
 * 模拟 AI 响应（用于开发测试）
 * @param params 请求参数
 * @param onChunk 接收到数据块时的回调
 * @param onEnd 流结束时的回调
 * @param onError 错误时的回调
 */
export async function mockAIMessage(
    params: AIRequestParams,
    onChunk: (chunk: string) => void,
    onEnd: () => void,
    onError: (error: string) => void
): Promise<void> {
    try {
        // 模拟响应文本
        const mockResponse = `这是对您问题的回答：\n\n${params.message}\n\n我理解您的需求，让我为您详细分析一下：\n\n1. 首先，这个问题涉及到多个方面\n2. 其次，我们需要考虑实际应用场景\n3. 最后，建议采用渐进式的实现方案\n\n希望这个回答对您有帮助！`;

        // 模拟流式输出
        const words = mockResponse.split('');
        for (let i = 0; i < words.length; i++) {
            await new Promise(resolve => setTimeout(resolve, 30)); // 模拟延迟
            onChunk(words[i]);
        }

        onEnd();
    } catch (error: any) {
        onError(error.message || '模拟请求失败');
    }
}

/**
 * 发送 AI 消息（根据环境选择真实或模拟）
 */
export async function sendMessage(
    params: AIRequestParams,
    onChunk: (chunk: string) => void,
    onEnd: () => void,
    onError: (error: string) => void
): Promise<void> {
    // 开发环境使用模拟数据
    const isDev = import.meta.env.DEV;

    if (isDev) {
        return mockAIMessage(params, onChunk, onEnd, onError);
    }

    return sendAIMessage(params, onChunk, onEnd, onError);
}
