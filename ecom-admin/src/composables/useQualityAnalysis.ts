/**
 * 质量分析 Composable
 * 提供质量趋势预测、异常检测、评分算法等智能分析功能
 */

import { ref, computed } from 'vue';

export interface QualityMetrics {
  testCoverage: number; // 测试覆盖率 0-100
  passRate: number; // 通过率 0-100
  bugDensity: number; // Bug密度（每千行代码）
  avgResponseTime: number; // 平均响应时间（ms）
  codeQuality: number; // 代码质量评分 0-100
  documentationScore: number; // 文档完整度 0-100
}

export interface QualityScore {
  score: number; // 总分 0-100
  level: 'excellent' | 'good' | 'fair' | 'poor';
  factors: QualityFactor[];
  suggestions: string[];
  trend: 'improving' | 'stable' | 'declining';
}

export interface QualityFactor {
  name: string;
  weight: number; // 权重 0-1
  score: number; // 得分 0-100
  impact: 'positive' | 'negative';
  description: string;
}

export interface TrendPrediction {
  metric: string;
  current: number;
  predicted: number[];
  confidence: number; // 置信度 0-100
  dates: string[];
  trend: 'up' | 'down' | 'stable';
}

export interface Anomaly {
  id: string;
  type: 'spike' | 'drop' | 'outlier' | 'pattern_break';
  metric: string;
  value: number;
  expected: number;
  deviation: number; // 偏差百分比
  severity: 'low' | 'medium' | 'high' | 'critical';
  timestamp: string;
  description: string;
  possibleCauses: string[];
  recommendations: string[];
}

export interface ComparisonResult {
  type: 'time' | 'module' | 'project' | 'team';
  items: ComparisonItem[];
  winner: string;
  insights: string[];
}

export interface ComparisonItem {
  name: string;
  metrics: Record<string, number>;
  score: number;
  rank: number;
}

export function useQualityAnalysis() {
  const loading = ref(false);
  const qualityScore = ref<QualityScore | null>(null);
  const predictions = ref<TrendPrediction[]>([]);
  const anomalies = ref<Anomaly[]>([]);
  const comparisons = ref<ComparisonResult[]>([]);
  
  /**
   * 计算质量评分
   */
  const calculateQualityScore = (metrics: QualityMetrics): QualityScore => {
    loading.value = true;
    
    try {
      // 定义评分因子
      const factors: QualityFactor[] = [
        {
          name: '测试覆盖率',
          weight: 0.25,
          score: metrics.testCoverage,
          impact: 'positive',
          description: `当前覆盖率 ${metrics.testCoverage.toFixed(1)}%`,
        },
        {
          name: '测试通过率',
          weight: 0.25,
          score: metrics.passRate,
          impact: 'positive',
          description: `当前通过率 ${metrics.passRate.toFixed(1)}%`,
        },
        {
          name: 'Bug密度',
          weight: 0.2,
          score: calculateBugDensityScore(metrics.bugDensity),
          impact: 'negative',
          description: `每千行代码 ${metrics.bugDensity.toFixed(2)} 个Bug`,
        },
        {
          name: '响应性能',
          weight: 0.15,
          score: calculateResponseScore(metrics.avgResponseTime),
          impact: 'positive',
          description: `平均响应时间 ${metrics.avgResponseTime}ms`,
        },
        {
          name: '代码质量',
          weight: 0.1,
          score: metrics.codeQuality,
          impact: 'positive',
          description: `代码质量评分 ${metrics.codeQuality.toFixed(1)}`,
        },
        {
          name: '文档完整度',
          weight: 0.05,
          score: metrics.documentationScore,
          impact: 'positive',
          description: `文档完整度 ${metrics.documentationScore.toFixed(1)}%`,
        },
      ];
      
      // 计算加权总分
      const totalScore = factors.reduce((sum, factor) => {
        return sum + factor.score * factor.weight;
      }, 0);
      
      // 确定等级
      const level = getScoreLevel(totalScore);
      
      // 生成改进建议
      const suggestions = generateSuggestions(factors, metrics);
      
      // 计算趋势（需要历史数据，这里简化处理）
      const trend = 'stable' as const;
      
      const result: QualityScore = {
        score: totalScore,
        level,
        factors,
        suggestions,
        trend,
      };
      
      qualityScore.value = result;
      return result;
      
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 计算Bug密度评分
   */
  const calculateBugDensityScore = (density: number): number => {
    // Bug密度越低越好
    // 0-1: 优秀 (100分)
    // 1-3: 良好 (80分)
    // 3-5: 一般 (60分)
    // 5-10: 较差 (40分)
    // >10: 很差 (20分)
    
    if (density <= 1) return 100;
    if (density <= 3) return 100 - (density - 1) * 10;
    if (density <= 5) return 80 - (density - 3) * 10;
    if (density <= 10) return 60 - (density - 5) * 4;
    return Math.max(20, 40 - (density - 10) * 2);
  };
  
  /**
   * 计算响应时间评分
   */
  const calculateResponseScore = (responseTime: number): number => {
    // 响应时间越短越好
    // <100ms: 优秀 (100分)
    // 100-300ms: 良好 (80分)
    // 300-500ms: 一般 (60分)
    // 500-1000ms: 较差 (40分)
    // >1000ms: 很差 (20分)
    
    if (responseTime < 100) return 100;
    if (responseTime < 300) return 100 - (responseTime - 100) / 2 * 0.1;
    if (responseTime < 500) return 80 - (responseTime - 300) / 2 * 0.1;
    if (responseTime < 1000) return 60 - (responseTime - 500) / 5 * 0.04;
    return Math.max(20, 40 - (responseTime - 1000) / 100);
  };
  
  /**
   * 获取评分等级
   */
  const getScoreLevel = (score: number): 'excellent' | 'good' | 'fair' | 'poor' => {
    if (score >= 90) return 'excellent';
    if (score >= 75) return 'good';
    if (score >= 60) return 'fair';
    return 'poor';
  };
  
  /**
   * 生成改进建议
   */
  const generateSuggestions = (factors: QualityFactor[], metrics: QualityMetrics): string[] => {
    const suggestions: string[] = [];
    
    // 测试覆盖率建议
    if (metrics.testCoverage < 80) {
      suggestions.push(`提高测试覆盖率至80%以上（当前${metrics.testCoverage.toFixed(1)}%）`);
    }
    
    // 通过率建议
    if (metrics.passRate < 95) {
      suggestions.push(`提高测试通过率至95%以上（当前${metrics.passRate.toFixed(1)}%）`);
    }
    
    // Bug密度建议
    if (metrics.bugDensity > 3) {
      suggestions.push(`降低Bug密度至3以下（当前${metrics.bugDensity.toFixed(2)}）`);
    }
    
    // 响应时间建议
    if (metrics.avgResponseTime > 300) {
      suggestions.push(`优化响应时间至300ms以内（当前${metrics.avgResponseTime}ms）`);
    }
    
    // 代码质量建议
    if (metrics.codeQuality < 80) {
      suggestions.push(`提升代码质量评分至80以上（当前${metrics.codeQuality.toFixed(1)}）`);
    }
    
    // 文档建议
    if (metrics.documentationScore < 70) {
      suggestions.push(`完善项目文档至70%以上（当前${metrics.documentationScore.toFixed(1)}%）`);
    }
    
    // 如果没有建议，说明质量很好
    if (suggestions.length === 0) {
      suggestions.push('质量指标优秀，继续保持！');
    }
    
    return suggestions;
  };
  
  /**
   * 预测质量趋势
   */
  const predictTrend = (
    metric: string,
    historicalData: number[],
    futureDays: number = 7
  ): TrendPrediction => {
    loading.value = true;
    
    try {
      // 简单的线性回归预测
      const n = historicalData.length;
      if (n < 2) {
        throw new Error('历史数据不足');
      }
      
      // 计算平均值和趋势
      const avg = historicalData.reduce((sum, val) => sum + val, 0) / n;
      
      // 计算线性趋势
      let sumX = 0;
      let sumY = 0;
      let sumXY = 0;
      let sumX2 = 0;
      
      for (let i = 0; i < n; i++) {
        sumX += i;
        sumY += historicalData[i];
        sumXY += i * historicalData[i];
        sumX2 += i * i;
      }
      
      const slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
      const intercept = (sumY - slope * sumX) / n;
      
      // 预测未来值
      const predicted: number[] = [];
      for (let i = 0; i < futureDays; i++) {
        const value = slope * (n + i) + intercept;
        predicted.push(Math.max(0, Math.min(100, value))); // 限制在0-100之间
      }
      
      // 生成日期
      const dates: string[] = [];
      const today = new Date();
      for (let i = 1; i <= futureDays; i++) {
        const date = new Date(today);
        date.setDate(date.getDate() + i);
        dates.push(date.toISOString().split('T')[0]);
      }
      
      // 计算置信度（基于数据稳定性）
      const variance = historicalData.reduce((sum, val) => {
        return sum + Math.pow(val - avg, 2);
      }, 0) / n;
      const stdDev = Math.sqrt(variance);
      const confidence = Math.max(50, Math.min(95, 100 - stdDev));
      
      // 确定趋势
      const trend = slope > 0.5 ? 'up' : slope < -0.5 ? 'down' : 'stable';
      
      const prediction: TrendPrediction = {
        metric,
        current: historicalData[n - 1],
        predicted,
        confidence,
        dates,
        trend,
      };
      
      predictions.value.push(prediction);
      return prediction;
      
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 检测异常数据
   */
  const detectAnomalies = (
    metric: string,
    data: Array<{ value: number; timestamp: string }>
  ): Anomaly[] => {
    loading.value = true;
    
    try {
      const detected: Anomaly[] = [];
      
      if (data.length < 3) return detected;
      
      // 计算统计指标
      const values = data.map(d => d.value);
      const mean = values.reduce((sum, val) => sum + val, 0) / values.length;
      const variance = values.reduce((sum, val) => sum + Math.pow(val - mean, 2), 0) / values.length;
      const stdDev = Math.sqrt(variance);
      
      // 检测异常点（使用3-sigma规则）
      data.forEach((point, index) => {
        const zScore = Math.abs((point.value - mean) / stdDev);
        
        if (zScore > 3) {
          // 严重异常
          const deviation = ((point.value - mean) / mean) * 100;
          const type = point.value > mean ? 'spike' : 'drop';
          
          detected.push({
            id: `anomaly_${index}`,
            type,
            metric,
            value: point.value,
            expected: mean,
            deviation: Math.abs(deviation),
            severity: zScore > 4 ? 'critical' : 'high',
            timestamp: point.timestamp,
            description: `${metric}出现${type === 'spike' ? '异常升高' : '异常降低'}`,
            possibleCauses: generatePossibleCauses(type, metric),
            recommendations: generateRecommendations(type, metric),
          });
        } else if (zScore > 2) {
          // 中度异常
          const deviation = ((point.value - mean) / mean) * 100;
          const type = point.value > mean ? 'spike' : 'drop';
          
          detected.push({
            id: `anomaly_${index}`,
            type: 'outlier',
            metric,
            value: point.value,
            expected: mean,
            deviation: Math.abs(deviation),
            severity: 'medium',
            timestamp: point.timestamp,
            description: `${metric}出现轻微异常`,
            possibleCauses: generatePossibleCauses(type, metric),
            recommendations: generateRecommendations(type, metric),
          });
        }
      });
      
      anomalies.value = detected;
      return detected;
      
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 生成可能原因
   */
  const generatePossibleCauses = (type: string, metric: string): string[] => {
    const causes: string[] = [];
    
    if (type === 'spike') {
      causes.push('系统负载突然增加');
      causes.push('新功能上线导致');
      causes.push('数据异常或错误');
    } else {
      causes.push('系统故障或宕机');
      causes.push('配置错误');
      causes.push('资源不足');
    }
    
    return causes;
  };
  
  /**
   * 生成建议
   */
  const generateRecommendations = (type: string, metric: string): string[] => {
    const recommendations: string[] = [];
    
    recommendations.push('检查系统日志');
    recommendations.push('分析相关指标');
    recommendations.push('联系相关负责人');
    
    if (type === 'spike') {
      recommendations.push('考虑扩容或优化');
    } else {
      recommendations.push('检查系统健康状态');
    }
    
    return recommendations;
  };
  
  /**
   * 对比分析
   */
  const compare = (
    type: 'time' | 'module' | 'project' | 'team',
    items: Array<{ name: string; metrics: Record<string, number> }>
  ): ComparisonResult => {
    loading.value = true;
    
    try {
      // 计算每个项目的综合得分
      const scoredItems: ComparisonItem[] = items.map(item => {
        const score = Object.values(item.metrics).reduce((sum, val) => sum + val, 0) / Object.keys(item.metrics).length;
        return {
          name: item.name,
          metrics: item.metrics,
          score,
          rank: 0,
        };
      });
      
      // 排序并分配排名
      scoredItems.sort((a, b) => b.score - a.score);
      scoredItems.forEach((item, index) => {
        item.rank = index + 1;
      });
      
      // 生成洞察
      const insights = generateInsights(type, scoredItems);
      
      const result: ComparisonResult = {
        type,
        items: scoredItems,
        winner: scoredItems[0].name,
        insights,
      };
      
      comparisons.value.push(result);
      return result;
      
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 生成洞察
   */
  const generateInsights = (type: string, items: ComparisonItem[]): string[] => {
    const insights: string[] = [];
    
    const winner = items[0];
    const loser = items[items.length - 1];
    
    insights.push(`${winner.name}表现最佳，综合得分${winner.score.toFixed(1)}`);
    insights.push(`${loser.name}需要改进，综合得分${loser.score.toFixed(1)}`);
    
    const gap = winner.score - loser.score;
    if (gap > 20) {
      insights.push(`差距较大（${gap.toFixed(1)}分），建议重点关注落后项`);
    } else {
      insights.push(`差距较小（${gap.toFixed(1)}分），整体水平较为均衡`);
    }
    
    return insights;
  };
  
  return {
    // 状态
    loading: computed(() => loading.value),
    qualityScore: computed(() => qualityScore.value),
    predictions: computed(() => predictions.value),
    anomalies: computed(() => anomalies.value),
    comparisons: computed(() => comparisons.value),
    
    // 方法
    calculateQualityScore,
    predictTrend,
    detectAnomalies,
    compare,
  };
}

