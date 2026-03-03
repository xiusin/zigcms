# AI 聊天模块使用指南

## 概述

AI 聊天模块是一个可复用的全局组件，提供右下角常驻角标和聊天窗口，支持多 Tab 对话和流式输出。

## 功能特性

- ✅ 右下角常驻角标（带未读消息计数）
- ✅ 点击角标动画展开为聊天窗口
- ✅ 支持多 Tab 对话管理
- ✅ 流式输出 AI 响应（支持 SSE）
- ✅ 从任何模块调用创建新对话
- ✅ 消息历史记录（Pinia 状态管理）
- ✅ 响应式设计，适配移动端

## 快速开始

### 1. 组件已全局引入

AI 聊天组件已在 `src/layout/default-layout.vue` 中引入，无需额外配置。

### 2. 从任何页面调用

#### 方式一：使用全局事件（推荐）

```vue
<template>
  <a-button @click="handleAIAnalysis">
    <icon-robot /> AI 分析
  </a-button>
</template>

<script setup lang="ts">
const handleAIAnalysis = () => {
  // 触发 AI 聊天创建事件
  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message: '请分析这个数据：\n\n' + JSON.stringify(data, null, 2),
      title: '数据分析'
    }
  }));
};
</script>
```

#### 方式二：使用 Composable（高级）

```vue
<script setup lang="ts">
import { useAIChat } from '@/components/ai-chat/composables';

const { createConversation } = useAIChat();

const handleAIAnalysis = () => {
  createConversation({
    message: '请分析这个数据：\n\n' + JSON.stringify(data, null, 2),
    title: '数据分析'
  });
};
</script>
```

## 使用示例

### 示例 1：质量中心 AI 分析

```vue
<template>
  <a-button type="primary" @click="analyzeQuality">
    <icon-robot /> AI 质量分析
  </a-button>
</template>

<script setup lang="ts">
import { useQualityCenterStore } from '@/store/modules/quality-center';

const store = useQualityCenterStore();

const analyzeQuality = () => {
  const data = {
    passRate: store.overview?.pass_rate,
    activeBugs: store.overview?.active_bugs,
    pendingFeedbacks: store.overview?.pending_feedbacks,
  };

  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message: `请分析以下质量数据：\n\n通过率: ${data.passRate}%\n活跃Bug: ${data.activeBugs}\n待处理反馈: ${data.pendingFeedbacks}\n\n请给出改进建议。`,
      title: '质量分析'
    }
  }));
};
</script>
```

### 示例 2：Bug 分析

```vue
<template>
  <a-button size="small" @click="analyzeBug(bug)">
    <icon-robot /> AI 分析
  </a-button>
</template>

<script setup lang="ts">
const analyzeBug = (bug: any) => {
  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message: `请分析这个 Bug：\n\n标题: ${bug.title}\n描述: ${bug.description}\n模块: ${bug.module}\n严重程度: ${bug.severity}\n\n请给出可能的原因和修复建议。`,
      title: `Bug分析 - ${bug.title}`
    }
  }));
};
</script>
```

### 示例 3：代码审查

```vue
<template>
  <a-button @click="reviewCode">
    <icon-robot /> AI 代码审查
  </a-button>
</template>

<script setup lang="ts">
const reviewCode = () => {
  const code = `
function calculateTotal(items) {
  let total = 0;
  for (let i = 0; i < items.length; i++) {
    total += items[i].price * items[i].quantity;
  }
  return total;
}
  `;

  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message: `请审查以下代码：\n\n\`\`\`javascript\n${code}\n\`\`\`\n\n请指出潜在问题和改进建议。`,
      title: '代码审查'
    }
  }));
};
</script>
```

## API 配置

### 开发环境

开发环境默认使用模拟数据，无需配置后端 API。

### 生产环境

修改 `src/components/ai-chat/api.ts` 中的 API 端点：

```typescript
// 修改为实际的 AI API 端点
const apiUrl = '/api/ai/chat/stream';
```

### 后端接口要求

后端需要实现流式响应接口，支持 SSE（Server-Sent Events）格式：

```
POST /api/ai/chat/stream
Content-Type: application/json
Authorization: Bearer <token>

{
  "message": "用户消息",
  "conversationId": "可选的对话ID",
  "context": "可选的上下文数据"
}

响应格式（SSE）：
data: {"content": "AI响应的第一部分"}
data: {"content": "AI响应的第二部分"}
data: [DONE]
```

## 组件结构

```
src/components/ai-chat/
├── index.vue           # 主组件（角标 + 窗口）
├── ChatPanel.vue       # 聊天面板组件
├── store.ts            # Pinia 状态管理
├── api.ts              # AI API 请求
├── types.ts            # TypeScript 类型定义
└── README.md           # 使用文档
```

## 状态管理

使用 Pinia store 管理全局状态：

```typescript
import { useAIChatStore } from '@/components/ai-chat/store';

const aiChatStore = useAIChatStore();

// 获取未读消息数
console.log(aiChatStore.unreadCount);

// 获取对话历史
const messages = aiChatStore.getMessages('tab-1');

// 添加消息
aiChatStore.addMessage('tab-1', {
  id: 'msg-1',
  role: 'user',
  content: 'Hello',
  timestamp: Date.now(),
});
```

## 样式定制

组件使用 Arco Design 的主题变量，自动适配系统主题：

```less
// 主色调（使用 Arco 主题色）
background: rgb(var(--primary-6));

// 背景色（使用 Arco 背景色）
background: var(--color-bg-1);
background: var(--color-bg-2);

// 边框色（使用 Arco 边框色）
border: 1px solid var(--color-border);

// 文字色（使用 Arco 文字色）
color: var(--color-text-1);
color: var(--color-text-2);
color: var(--color-text-3);

// 窗口大小
width: 480px;
height: 640px;

// 位置
right: 24px;
bottom: 24px;
```

支持 Arco Design 的亮色/暗色主题自动切换。

## 注意事项

1. **流式输出**：确保后端支持 SSE 或 WebSocket 流式响应
2. **内存管理**：长对话会占用内存，建议定期清理历史消息
3. **权限控制**：根据需要添加用户权限验证
4. **错误处理**：网络错误会自动显示错误消息
5. **移动端适配**：窗口会自动适配小屏幕设备

## 常见问题

### Q: 如何修改 AI API 端点？

A: 修改 `src/components/ai-chat/api.ts` 中的 `apiUrl` 变量。

### Q: 如何禁用模拟数据？

A: 在 `api.ts` 中修改 `sendMessage` 函数，移除 `isDev` 判断。

### Q: 如何自定义消息格式？

A: 修改 `types.ts` 中的 `Message` 接口和 `ChatPanel.vue` 中的渲染逻辑。

### Q: 如何添加文件上传功能？

A: 在 `ChatPanel.vue` 的输入区域添加文件上传组件，并修改 API 请求支持 FormData。

### Q: 如何实现多轮对话上下文？

A: 在 `api.ts` 中添加 `conversationId` 参数，后端根据 ID 维护对话上下文。

## 后续优化

- [ ] 支持 Markdown 渲染
- [ ] 支持代码高亮
- [ ] 支持图片上传
- [ ] 支持语音输入
- [ ] 支持对话导出
- [ ] 支持快捷指令
- [ ] 支持多语言
- [ ] 支持主题切换

## 贡献

欢迎提交 Issue 和 Pull Request！
