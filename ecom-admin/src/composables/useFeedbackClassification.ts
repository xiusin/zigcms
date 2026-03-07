/**
 * 反馈智能分类 Composable
 * 提供AI自动分类、智能标签推荐、相似反馈推荐等功能
 */

import { ref, computed } from 'vue';
import type { FeedbackType, FeedbackSeverity } from '@/types/quality-center';

export interface ClassificationResult {
  type: FeedbackType;
  severity: FeedbackSeverity;
  confidence: number; // 置信度 0-100
  tags: string[];
  category: string;
  priority: number; // 优先级 1-5
  estimatedTime: number; // 预计处理时间（小时）
  suggestedAssignee?: string;
}

export interface SimilarFeedback {
  id: number;
  title: string;
  similarity: number; // 相似度 0-100
  status: string;
  resolution?: string;
}

export interface TagSuggestion {
  tag: string;
  confidence: number;
  reason: string;
}

export function useFeedbackClassification() {
  const loading = ref(false);
  const classificationResult = ref<ClassificationResult | null>(null);
  const similarFeedbacks = ref<SimilarFeedback[]>([]);
  const tagSuggestions = ref<TagSuggestion[]>([]);

  /**
   * AI自动分类
   */
  const classifyFeedback = async (
    title: string,
    content: string
  ): Promise<ClassificationResult> => {
    loading.value = true;

    try {
      // 简单的关键词匹配分类（实际应该调用AI API）
      const result = await performClassification(title, content);
      classificationResult.value = result;
      return result;
    } finally {
      loading.value = false;
    }
  };

  /**
   * 执行分类（模拟AI分类）
   */
  const performClassification = async (
    title: string,
    content: string
  ): Promise<ClassificationResult> => {
    // 模拟API延迟
    await new Promise((resolve) => setTimeout(resolve, 500));

    const text = `${title} ${content}`.toLowerCase();

    // 类型识别
    let type: FeedbackType = 'question';
    let confidence = 60;

    if (
      text.includes('bug') ||
      text.includes('错误') ||
      text.includes('崩溃') ||
      text.includes('异常')
    ) {
      type = 'bug';
      confidence = 85;
    } else if (
      text.includes('建议') ||
      text.includes('希望') ||
      text.includes('能否') ||
      text.includes('功能')
    ) {
      type = 'feature';
      confidence = 80;
    } else if (
      text.includes('优化') ||
      text.includes('改进') ||
      text.includes('提升') ||
      text.includes('更好')
    ) {
      type = 'improvement';
      confidence = 75;
    }

    // 严重程度识别
    let severity: FeedbackSeverity = 'medium';

    if (
      text.includes('紧急') ||
      text.includes('严重') ||
      text.includes('崩溃') ||
      text.includes('无法使用')
    ) {
      severity = 'critical';
    } else if (
      text.includes('重要') ||
      text.includes('影响') ||
      text.includes('频繁')
    ) {
      severity = 'high';
    } else if (
      text.includes('轻微') ||
      text.includes('小问题') ||
      text.includes('建议')
    ) {
      severity = 'low';
    }

    // 标签提取
    const tags: string[] = [];
    if (text.includes('登录')) tags.push('登录');
    if (text.includes('支付')) tags.push('支付');
    if (text.includes('订单')) tags.push('订单');
    if (text.includes('商品')) tags.push('商品');
    if (text.includes('性能')) tags.push('性能');
    if (text.includes('界面') || text.includes('UI')) tags.push('UI');
    if (text.includes('兼容')) tags.push('兼容性');

    // 分类
    let category = '其他';
    if (tags.includes('登录')) category = '用户认证';
    else if (tags.includes('支付')) category = '支付系统';
    else if (tags.includes('订单')) category = '订单管理';
    else if (tags.includes('商品')) category = '商品管理';
    else if (tags.includes('性能')) category = '性能优化';
    else if (tags.includes('UI')) category = '界面设计';

    // 优先级计算
    let priority = 3;
    if (severity === 'critical') priority = 5;
    else if (severity === 'high') priority = 4;
    else if (severity === 'low') priority = 2;

    // 预计处理时间
    let estimatedTime = 8;
    if (type === 'bug') {
      if (severity === 'critical') estimatedTime = 2;
      else if (severity === 'high') estimatedTime = 4;
      else estimatedTime = 8;
    } else if (type === 'feature') {
      estimatedTime = 16;
    } else if (type === 'improvement') {
      estimatedTime = 12;
    }

    // 建议处理人（基于分类）
    const assigneeMap: Record<string, string> = {
      '用户认证': '张三',
      '支付系统': '李四',
      '订单管理': '王五',
      '商品管理': '赵六',
      '性能优化': '钱七',
      '界面设计': '孙八',
    };
    const suggestedAssignee = assigneeMap[category];

    return {
      type,
      severity,
      confidence,
      tags,
      category,
      priority,
      estimatedTime,
      suggestedAssignee,
    };
  };

  /**
   * 查找相似反馈
   */
  const findSimilarFeedbacks = async (
    title: string,
    content: string,
    limit: number = 5
  ): Promise<SimilarFeedback[]> => {
    loading.value = true;

    try {
      // 模拟API调用
      await new Promise((resolve) => setTimeout(resolve, 300));

      // 简单的相似度计算（实际应该使用向量相似度）
      const similar: SimilarFeedback[] = [
        {
          id: 1,
          title: '登录页面无法正常显示',
          similarity: 85,
          status: 'resolved',
          resolution: '修复了CSS样式问题',
        },
        {
          id: 2,
          title: '登录按钮点击无响应',
          similarity: 78,
          status: 'resolved',
          resolution: '修复了事件绑定问题',
        },
        {
          id: 3,
          title: '登录后跳转错误',
          similarity: 65,
          status: 'in_progress',
        },
      ];

      similarFeedbacks.value = similar.slice(0, limit);
      return similarFeedbacks.value;
    } finally {
      loading.value = false;
    }
  };

  /**
   * 智能标签推荐
   */
  const suggestTags = async (
    title: string,
    content: string
  ): Promise<TagSuggestion[]> => {
    loading.value = true;

    try {
      // 模拟API调用
      await new Promise((resolve) => setTimeout(resolve, 200));

      const text = `${title} ${content}`.toLowerCase();
      const suggestions: TagSuggestion[] = [];

      // 功能模块标签
      if (text.includes('登录')) {
        suggestions.push({
          tag: '登录',
          confidence: 90,
          reason: '内容提到了登录相关功能',
        });
      }
      if (text.includes('支付')) {
        suggestions.push({
          tag: '支付',
          confidence: 90,
          reason: '内容提到了支付相关功能',
        });
      }
      if (text.includes('订单')) {
        suggestions.push({
          tag: '订单',
          confidence: 85,
          reason: '内容提到了订单相关功能',
        });
      }

      // 问题类型标签
      if (text.includes('性能') || text.includes('慢') || text.includes('卡顿')) {
        suggestions.push({
          tag: '性能',
          confidence: 85,
          reason: '内容描述了性能问题',
        });
      }
      if (text.includes('界面') || text.includes('UI') || text.includes('显示')) {
        suggestions.push({
          tag: 'UI',
          confidence: 80,
          reason: '内容涉及界面显示问题',
        });
      }
      if (text.includes('兼容') || text.includes('浏览器') || text.includes('设备')) {
        suggestions.push({
          tag: '兼容性',
          confidence: 75,
          reason: '内容涉及兼容性问题',
        });
      }

      // 优先级标签
      if (text.includes('紧急') || text.includes('严重')) {
        suggestions.push({
          tag: '高优先级',
          confidence: 95,
          reason: '内容标注为紧急或严重',
        });
      }

      tagSuggestions.value = suggestions;
      return suggestions;
    } finally {
      loading.value = false;
    }
  };

  /**
   * 自动优先级评估
   */
  const assessPriority = (
    type: FeedbackType,
    severity: FeedbackSeverity,
    affectedUsers: number = 0
  ): number => {
    let priority = 3;

    // 基于严重程度
    if (severity === 'critical') priority = 5;
    else if (severity === 'high') priority = 4;
    else if (severity === 'low') priority = 2;

    // 基于类型
    if (type === 'bug') {
      priority = Math.min(5, priority + 1);
    }

    // 基于影响用户数
    if (affectedUsers > 1000) {
      priority = 5;
    } else if (affectedUsers > 100) {
      priority = Math.min(5, priority + 1);
    }

    return priority;
  };

  /**
   * 分类准确率统计
   */
  const getClassificationAccuracy = (): {
    total: number;
    correct: number;
    accuracy: number;
  } => {
    // 模拟统计数据
    return {
      total: 150,
      correct: 135,
      accuracy: 90,
    };
  };

  return {
    // 状态
    loading: computed(() => loading.value),
    classificationResult: computed(() => classificationResult.value),
    similarFeedbacks: computed(() => similarFeedbacks.value),
    tagSuggestions: computed(() => tagSuggestions.value),

    // 方法
    classifyFeedback,
    findSimilarFeedbacks,
    suggestTags,
    assessPriority,
    getClassificationAccuracy,
  };
}
