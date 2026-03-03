/**
 * AI 聊天模块使用示例
 * 展示如何在不同场景下调用 AI 聊天
 */
<template>
  <div class="ai-chat-examples">
    <a-card title="AI 聊天模块使用示例">
      <a-space direction="vertical" size="large" fill>
        <!-- 示例 1：质量数据分析 -->
        <div class="example-section">
          <h3>示例 1：质量数据分析</h3>
          <p>分析当前质量中心的整体数据</p>
          <a-space>
            <AIAnalysisButton
              :data="qualityData"
              analysis-type="quality"
              text="分析质量数据"
            />
            <a-button @click="handleQualityAnalysis">
              <icon-robot /> 自定义分析
            </a-button>
          </a-space>
        </div>

        <!-- 示例 2：Bug 分析 -->
        <div class="example-section">
          <h3>示例 2：Bug 分析</h3>
          <p>分析特定 Bug 的原因和修复建议</p>
          <a-space>
            <AIAnalysisButton
              :data="bugData"
              analysis-type="bug"
              text="分析 Bug"
            />
          </a-space>
        </div>

        <!-- 示例 3：用户反馈分析 -->
        <div class="example-section">
          <h3>示例 3：用户反馈分析</h3>
          <p>分析用户反馈内容和处理建议</p>
          <a-space>
            <AIAnalysisButton
              :data="feedbackData"
              analysis-type="feedback"
              text="分析反馈"
            />
          </a-space>
        </div>

        <!-- 示例 4：代码审查 -->
        <div class="example-section">
          <h3>示例 4：代码审查</h3>
          <p>审查代码质量和潜在问题</p>
          <a-space>
            <AIAnalysisButton
              :data="codeData"
              analysis-type="code"
              text="审查代码"
            />
          </a-space>
        </div>

        <!-- 示例 5：自定义提示词 -->
        <div class="example-section">
          <h3>示例 5：自定义提示词</h3>
          <p>使用自定义提示词进行分析</p>
          <a-space>
            <AIAnalysisButton
              :prompt="customPrompt"
              title="自定义分析"
              text="自定义分析"
            />
          </a-space>
        </div>

        <!-- 示例 6：直接调用全局事件 -->
        <div class="example-section">
          <h3>示例 6：直接调用全局事件</h3>
          <p>不使用组件，直接触发全局事件</p>
          <a-space>
            <a-button type="primary" @click="handleDirectCall">
              <icon-robot /> 直接调用
            </a-button>
          </a-space>
        </div>

        <!-- 示例 7：批量数据分析 -->
        <div class="example-section">
          <h3>示例 7：批量数据分析</h3>
          <p>分析多个数据项</p>
          <a-space>
            <a-button type="primary" @click="handleBatchAnalysis">
              <icon-robot /> 批量分析
            </a-button>
          </a-space>
        </div>
      </a-space>
    </a-card>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';
import { IconRobot } from '@arco-design/web-vue/es/icon';
import { Message } from '@arco-design/web-vue';
import AIAnalysisButton from '../components/AIAnalysisButton.vue';

// 示例数据
const qualityData = ref({
  passRate: 85.5,
  totalTasks: 120,
  activeBugs: 15,
  pendingFeedbacks: 8,
  aiFixRate: 45.2,
  weeklyExecutions: 56,
});

const bugData = ref({
  id: 1001,
  title: '登录页面无法提交表单',
  description: '用户点击登录按钮后，表单无响应，控制台报错：Cannot read property of undefined',
  module: '用户认证',
  severity: 'high',
  status: 'open',
  createdAt: '2024-01-15 10:30:00',
});

const feedbackData = ref({
  id: 2001,
  title: '搜索功能响应慢',
  content: '在搜索商品时，输入关键词后需要等待 5-10 秒才能看到结果，体验很差',
  category: '性能问题',
  priority: 'medium',
  status: 'pending',
  createdAt: '2024-01-16 14:20:00',
});

const codeData = ref(`
function calculateDiscount(price, userLevel) {
  if (userLevel == 'vip') {
    return price * 0.8;
  } else if (userLevel == 'svip') {
    return price * 0.6;
  } else {
    return price;
  }
}
`);

const customPrompt = ref(`
请帮我分析一下电商系统的用户留存率问题：

当前数据：
- 新用户注册量：1000/月
- 7日留存率：35%
- 30日留存率：15%
- 平均订单价值：¥150

请给出：
1. 留存率偏低的可能原因
2. 提升留存率的具体建议
3. 需要关注的关键指标
4. 实施优先级
`);

// 自定义质量分析
const handleQualityAnalysis = () => {
  const message = `
请深度分析以下质量数据：

📊 核心指标：
- 测试通过率：${qualityData.value.passRate}%
- 总测试任务：${qualityData.value.totalTasks}
- 活跃 Bug：${qualityData.value.activeBugs}
- 待处理反馈：${qualityData.value.pendingFeedbacks}
- AI 修复率：${qualityData.value.aiFixRate}%
- 本周执行：${qualityData.value.weeklyExecutions}

🎯 分析要求：
1. 评估当前质量状况（优秀/良好/一般/较差）
2. 识别最紧急的问题
3. 给出具体的改进措施
4. 预测未来趋势
5. 提供可量化的目标建议
  `.trim();

  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message,
      title: '深度质量分析',
    }
  }));

  Message.success('已创建深度分析对话');
};

// 直接调用示例
const handleDirectCall = () => {
  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message: '你好！我想了解一下如何提升系统的整体质量。',
      title: '质量咨询',
    }
  }));

  Message.success('已创建对话');
};

// 批量分析示例
const handleBatchAnalysis = () => {
  const bugs = [
    { id: 1, title: '登录失败', severity: 'high' },
    { id: 2, title: '页面加载慢', severity: 'medium' },
    { id: 3, title: '图片显示异常', severity: 'low' },
  ];

  const message = `
请批量分析以下 Bug：

${bugs.map((bug, index) => `
${index + 1}. ${bug.title}
   - ID: ${bug.id}
   - 严重程度: ${bug.severity}
`).join('\n')}

请给出：
1. 每个 Bug 的优先级排序
2. 可能的共同原因
3. 修复顺序建议
4. 预计修复时间
  `.trim();

  window.dispatchEvent(new CustomEvent('ai-chat:create', {
    detail: {
      message,
      title: '批量 Bug 分析',
    }
  }));

  Message.success('已创建批量分析对话');
};
</script>

<style scoped lang="less">
.ai-chat-examples {
  padding: 20px;

  .example-section {
    padding: 16px;
    background: var(--color-fill-1);
    border-radius: 8px;

    h3 {
      margin: 0 0 8px 0;
      font-size: 16px;
      font-weight: 600;
      color: var(--color-text-1);
    }

    p {
      margin: 0 0 12px 0;
      font-size: 14px;
      color: var(--color-text-2);
    }
  }
}
</style>
