/**
 * AI 分析按钮组件
 * 用于在各个模块中快速调用 AI 聊天进行分析
 */
<template>
  <a-button
    v-bind="$attrs"
    :type="type"
    :size="size"
    :loading="loading"
    @click="handleAnalysis"
  >
    <template #icon>
      <icon-robot />
    </template>
    {{ text }}
  </a-button>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { IconRobot } from '@arco-design/web-vue/es/icon';
import { Message } from '@arco-design/web-vue';

// Props
interface Props {
  // 分析数据
  data?: any;
  // 分析类型
  analysisType?: 'quality' | 'bug' | 'feedback' | 'code' | 'custom';
  // 自定义提示词
  prompt?: string;
  // 对话标题
  title?: string;
  // 按钮文本
  text?: string;
  // 按钮类型
  type?: 'primary' | 'secondary' | 'outline' | 'text';
  // 按钮大小
  size?: 'mini' | 'small' | 'medium' | 'large';
}

const props = withDefaults(defineProps<Props>(), {
  text: 'AI 分析',
  type: 'primary',
  size: 'small',
  analysisType: 'custom',
});

// 状态
const loading = ref(false);

// 生成分析提示词
const generatePrompt = (): string => {
  if (props.prompt) {
    return props.prompt;
  }

  const dataStr = props.data ? JSON.stringify(props.data, null, 2) : '';

  switch (props.analysisType) {
    case 'quality':
      return `请分析以下质量数据：\n\n${dataStr}\n\n请给出：\n1. 当前质量状况评估\n2. 存在的主要问题\n3. 改进建议\n4. 优先级排序`;

    case 'bug':
      return `请分析这个 Bug：\n\n${dataStr}\n\n请给出：\n1. 可能的原因分析\n2. 影响范围评估\n3. 修复建议\n4. 预防措施`;

    case 'feedback':
      return `请分析这条用户反馈：\n\n${dataStr}\n\n请给出：\n1. 问题分类\n2. 严重程度评估\n3. 处理建议\n4. 相关改进方向`;

    case 'code':
      return `请审查以下代码：\n\n\`\`\`\n${dataStr}\n\`\`\`\n\n请指出：\n1. 潜在问题\n2. 性能优化建议\n3. 代码规范问题\n4. 安全隐患`;

    default:
      return dataStr ? `请分析以下数据：\n\n${dataStr}` : '请问有什么可以帮助您的？';
  }
};

// 生成对话标题
const generateTitle = (): string => {
  if (props.title) {
    return props.title;
  }

  const typeMap: Record<string, string> = {
    quality: '质量分析',
    bug: 'Bug 分析',
    feedback: '反馈分析',
    code: '代码审查',
    custom: 'AI 分析',
  };

  return typeMap[props.analysisType] || 'AI 分析';
};

// 处理分析
const handleAnalysis = () => {
  try {
    loading.value = true;

    const message = generatePrompt();
    const title = generateTitle();

    // 触发 AI 聊天创建事件
    window.dispatchEvent(new CustomEvent('ai-chat:create', {
      detail: {
        message,
        title,
      }
    }));

    Message.success('已创建 AI 分析对话');
  } catch (error) {
    console.error('AI 分析失败:', error);
    Message.error('创建 AI 分析对话失败');
  } finally {
    // 延迟重置 loading 状态，避免按钮闪烁
    setTimeout(() => {
      loading.value = false;
    }, 300);
  }
};
</script>

<style scoped lang="less">
// 无需额外样式，使用 Arco Design 默认样式
</style>
