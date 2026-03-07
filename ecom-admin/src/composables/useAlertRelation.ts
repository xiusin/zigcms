/**
 * 告警关联分析 Composable
 * 分析告警之间的关联关系，识别攻击模式
 */

import { ref, computed } from 'vue';
import type { Alert } from '@/types/security';

export interface AlertRelation {
  type: 'same_ip' | 'same_type' | 'same_user' | 'time_series' | 'attack_pattern';
  alerts: Alert[];
  count: number;
  trend: 'up' | 'down' | 'stable';
  severity: 'low' | 'medium' | 'high' | 'critical';
  description: string;
  recommendation?: string;
}

export interface AttackPattern {
  id: string;
  name: string;
  description: string;
  alerts: Alert[];
  confidence: number; // 0-100
  severity: 'low' | 'medium' | 'high' | 'critical';
  indicators: string[];
  mitigation: string[];
}

export interface TimeSeriesData {
  timestamp: number;
  count: number;
  level: string;
}

export function useAlertRelation() {
  const loading = ref(false);
  const relations = ref<AlertRelation[]>([]);
  const patterns = ref<AttackPattern[]>([]);
  
  /**
   * 分析告警关联
   */
  const analyzeRelations = async (alert: Alert, allAlerts: Alert[]): Promise<AlertRelation[]> => {
    loading.value = true;
    const result: AlertRelation[] = [];
    
    try {
      // 1. 相同IP的告警
      const sameIPAlerts = allAlerts.filter(a => 
        a.id !== alert.id && 
        a.client_ip === alert.client_ip
      );
      
      if (sameIPAlerts.length > 0) {
        result.push({
          type: 'same_ip',
          alerts: sameIPAlerts,
          count: sameIPAlerts.length,
          trend: calculateTrend(sameIPAlerts),
          severity: calculateSeverity(sameIPAlerts),
          description: `来自 ${alert.client_ip} 的其他 ${sameIPAlerts.length} 条告警`,
          recommendation: sameIPAlerts.length > 5 
            ? '建议封禁该IP地址' 
            : '建议持续监控该IP',
        });
      }
      
      // 2. 相同类型的告警
      const sameTypeAlerts = allAlerts.filter(a => 
        a.id !== alert.id && 
        a.type === alert.type
      );
      
      if (sameTypeAlerts.length > 0) {
        result.push({
          type: 'same_type',
          alerts: sameTypeAlerts,
          count: sameTypeAlerts.length,
          trend: calculateTrend(sameTypeAlerts),
          severity: calculateSeverity(sameTypeAlerts),
          description: `相同类型（${alert.type}）的其他 ${sameTypeAlerts.length} 条告警`,
          recommendation: '建议检查系统是否存在该类型的安全漏洞',
        });
      }
      
      // 3. 相同用户的告警
      if (alert.user_id) {
        const sameUserAlerts = allAlerts.filter(a => 
          a.id !== alert.id && 
          a.user_id === alert.user_id
        );
        
        if (sameUserAlerts.length > 0) {
          result.push({
            type: 'same_user',
            alerts: sameUserAlerts,
            count: sameUserAlerts.length,
            trend: calculateTrend(sameUserAlerts),
            severity: calculateSeverity(sameUserAlerts),
            description: `用户 ${alert.username || alert.user_id} 的其他 ${sameUserAlerts.length} 条告警`,
            recommendation: sameUserAlerts.length > 3 
              ? '建议检查该用户账号是否被盗用' 
              : '建议提醒用户注意账号安全',
          });
        }
      }
      
      // 4. 时间序列分析
      const timeSeriesAlerts = analyzeTimeSeries(alert, allAlerts);
      if (timeSeriesAlerts.length > 0) {
        result.push({
          type: 'time_series',
          alerts: timeSeriesAlerts,
          count: timeSeriesAlerts.length,
          trend: calculateTrend(timeSeriesAlerts),
          severity: calculateSeverity(timeSeriesAlerts),
          description: `在相近时间段内的 ${timeSeriesAlerts.length} 条告警`,
          recommendation: '建议分析是否存在集中攻击行为',
        });
      }
      
      relations.value = result;
      return result;
      
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 识别攻击模式
   */
  const detectAttackPatterns = async (alerts: Alert[]): Promise<AttackPattern[]> => {
    loading.value = true;
    const result: AttackPattern[] = [];
    
    try {
      // 1. 暴力破解模式
      const bruteForcePattern = detectBruteForce(alerts);
      if (bruteForcePattern) {
        result.push(bruteForcePattern);
      }
      
      // 2. SQL注入模式
      const sqlInjectionPattern = detectSQLInjection(alerts);
      if (sqlInjectionPattern) {
        result.push(sqlInjectionPattern);
      }
      
      // 3. XSS攻击模式
      const xssPattern = detectXSS(alerts);
      if (xssPattern) {
        result.push(xssPattern);
      }
      
      // 4. 扫描探测模式
      const scanPattern = detectScanning(alerts);
      if (scanPattern) {
        result.push(scanPattern);
      }
      
      // 5. DDoS模式
      const ddosPattern = detectDDoS(alerts);
      if (ddosPattern) {
        result.push(ddosPattern);
      }
      
      patterns.value = result;
      return result;
      
    } finally {
      loading.value = false;
    }
  };
  
  /**
   * 检测暴力破解
   */
  const detectBruteForce = (alerts: Alert[]): AttackPattern | null => {
    const loginFailedAlerts = alerts.filter(a => 
      a.type === 'login_failed' || 
      a.type === 'brute_force'
    );
    
    if (loginFailedAlerts.length < 5) return null;
    
    // 按IP分组
    const ipGroups = groupByIP(loginFailedAlerts);
    const suspiciousIPs = Object.entries(ipGroups).filter(([_, alerts]) => alerts.length >= 5);
    
    if (suspiciousIPs.length === 0) return null;
    
    const allSuspiciousAlerts = suspiciousIPs.flatMap(([_, alerts]) => alerts);
    
    return {
      id: 'brute_force',
      name: '暴力破解攻击',
      description: `检测到 ${suspiciousIPs.length} 个IP地址进行暴力破解尝试`,
      alerts: allSuspiciousAlerts,
      confidence: Math.min(95, 60 + suspiciousIPs.length * 5),
      severity: suspiciousIPs.length > 3 ? 'critical' : 'high',
      indicators: [
        `${suspiciousIPs.length} 个可疑IP`,
        `${allSuspiciousAlerts.length} 次登录失败`,
        '短时间内高频尝试',
      ],
      mitigation: [
        '立即封禁可疑IP地址',
        '启用账号锁定机制',
        '增加验证码验证',
        '启用多因素认证',
      ],
    };
  };
  
  /**
   * 检测SQL注入
   */
  const detectSQLInjection = (alerts: Alert[]): AttackPattern | null => {
    const sqlAlerts = alerts.filter(a => 
      a.type === 'sql_injection' || 
      a.type === 'sql_injection_attempt'
    );
    
    if (sqlAlerts.length < 3) return null;
    
    return {
      id: 'sql_injection',
      name: 'SQL注入攻击',
      description: `检测到 ${sqlAlerts.length} 次SQL注入尝试`,
      alerts: sqlAlerts,
      confidence: Math.min(90, 50 + sqlAlerts.length * 10),
      severity: 'critical',
      indicators: [
        `${sqlAlerts.length} 次注入尝试`,
        '包含SQL关键字',
        '异常查询参数',
      ],
      mitigation: [
        '立即修复SQL注入漏洞',
        '使用参数化查询',
        '启用WAF防护',
        '限制数据库权限',
      ],
    };
  };
  
  /**
   * 检测XSS攻击
   */
  const detectXSS = (alerts: Alert[]): AttackPattern | null => {
    const xssAlerts = alerts.filter(a => 
      a.type === 'xss' || 
      a.type === 'xss_attack_attempt'
    );
    
    if (xssAlerts.length < 3) return null;
    
    return {
      id: 'xss',
      name: 'XSS跨站脚本攻击',
      description: `检测到 ${xssAlerts.length} 次XSS攻击尝试`,
      alerts: xssAlerts,
      confidence: Math.min(85, 50 + xssAlerts.length * 8),
      severity: 'high',
      indicators: [
        `${xssAlerts.length} 次攻击尝试`,
        '包含脚本标签',
        '异常输入内容',
      ],
      mitigation: [
        '对用户输入进行转义',
        '启用CSP策略',
        '使用HttpOnly Cookie',
        '定期安全审计',
      ],
    };
  };
  
  /**
   * 检测扫描探测
   */
  const detectScanning = (alerts: Alert[]): AttackPattern | null => {
    // 检测短时间内大量不同路径的访问
    const recentAlerts = alerts.filter(a => {
      const time = new Date(a.created_at).getTime();
      const now = Date.now();
      return now - time < 3600000; // 1小时内
    });
    
    if (recentAlerts.length < 20) return null;
    
    // 按IP分组
    const ipGroups = groupByIP(recentAlerts);
    const scanningIPs = Object.entries(ipGroups).filter(([_, alerts]) => {
      // 检查是否访问了多个不同路径
      const uniquePaths = new Set(alerts.map(a => a.path || ''));
      return uniquePaths.size >= 10;
    });
    
    if (scanningIPs.length === 0) return null;
    
    const allScanningAlerts = scanningIPs.flatMap(([_, alerts]) => alerts);
    
    return {
      id: 'scanning',
      name: '扫描探测行为',
      description: `检测到 ${scanningIPs.length} 个IP进行扫描探测`,
      alerts: allScanningAlerts,
      confidence: Math.min(80, 40 + scanningIPs.length * 10),
      severity: 'medium',
      indicators: [
        `${scanningIPs.length} 个扫描IP`,
        '访问大量不同路径',
        '短时间高频访问',
      ],
      mitigation: [
        '封禁扫描IP',
        '隐藏敏感路径',
        '启用访问频率限制',
        '记录详细日志',
      ],
    };
  };
  
  /**
   * 检测DDoS攻击
   */
  const detectDDoS = (alerts: Alert[]): AttackPattern | null => {
    const rateLimitAlerts = alerts.filter(a => 
      a.type === 'rate_limit_exceeded' || 
      a.type === 'rate_limit'
    );
    
    if (rateLimitAlerts.length < 10) return null;
    
    // 检查是否来自多个不同IP
    const uniqueIPs = new Set(rateLimitAlerts.map(a => a.client_ip));
    
    if (uniqueIPs.size < 5) return null;
    
    return {
      id: 'ddos',
      name: 'DDoS攻击',
      description: `检测到来自 ${uniqueIPs.size} 个IP的DDoS攻击`,
      alerts: rateLimitAlerts,
      confidence: Math.min(90, 50 + uniqueIPs.size * 3),
      severity: 'critical',
      indicators: [
        `${uniqueIPs.size} 个攻击IP`,
        `${rateLimitAlerts.length} 次超限访问`,
        '分布式攻击特征',
      ],
      mitigation: [
        '启用DDoS防护',
        '使用CDN分流',
        '限制请求频率',
        '联系运营商协助',
      ],
    };
  };
  
  /**
   * 计算趋势
   */
  const calculateTrend = (alerts: Alert[]): 'up' | 'down' | 'stable' => {
    if (alerts.length < 2) return 'stable';
    
    // 按时间排序
    const sorted = [...alerts].sort((a, b) => 
      new Date(a.created_at).getTime() - new Date(b.created_at).getTime()
    );
    
    // 分成两半比较
    const mid = Math.floor(sorted.length / 2);
    const firstHalf = sorted.slice(0, mid);
    const secondHalf = sorted.slice(mid);
    
    const firstCount = firstHalf.length;
    const secondCount = secondHalf.length;
    
    if (secondCount > firstCount * 1.2) return 'up';
    if (secondCount < firstCount * 0.8) return 'down';
    return 'stable';
  };
  
  /**
   * 计算严重程度
   */
  const calculateSeverity = (alerts: Alert[]): 'low' | 'medium' | 'high' | 'critical' => {
    const criticalCount = alerts.filter(a => a.level === 'critical').length;
    const highCount = alerts.filter(a => a.level === 'high').length;
    
    if (criticalCount > 0) return 'critical';
    if (highCount > alerts.length * 0.5) return 'high';
    if (alerts.length > 10) return 'medium';
    return 'low';
  };
  
  /**
   * 时间序列分析
   */
  const analyzeTimeSeries = (alert: Alert, allAlerts: Alert[]): Alert[] => {
    const alertTime = new Date(alert.created_at).getTime();
    const timeWindow = 300000; // 5分钟
    
    return allAlerts.filter(a => {
      if (a.id === alert.id) return false;
      const time = new Date(a.created_at).getTime();
      return Math.abs(time - alertTime) <= timeWindow;
    });
  };
  
  /**
   * 按IP分组
   */
  const groupByIP = (alerts: Alert[]): Record<string, Alert[]> => {
    return alerts.reduce((groups, alert) => {
      const ip = alert.client_ip || 'unknown';
      if (!groups[ip]) {
        groups[ip] = [];
      }
      groups[ip].push(alert);
      return groups;
    }, {} as Record<string, Alert[]>);
  };
  
  /**
   * 获取时间序列数据
   */
  const getTimeSeriesData = (alerts: Alert[], interval: number = 3600000): TimeSeriesData[] => {
    if (alerts.length === 0) return [];
    
    // 找出时间范围
    const times = alerts.map(a => new Date(a.created_at).getTime());
    const minTime = Math.min(...times);
    const maxTime = Math.max(...times);
    
    // 生成时间桶
    const buckets: Record<number, { count: number; levels: string[] }> = {};
    
    for (let time = minTime; time <= maxTime; time += interval) {
      buckets[time] = { count: 0, levels: [] };
    }
    
    // 填充数据
    alerts.forEach(alert => {
      const time = new Date(alert.created_at).getTime();
      const bucketTime = Math.floor(time / interval) * interval;
      
      if (buckets[bucketTime]) {
        buckets[bucketTime].count++;
        buckets[bucketTime].levels.push(alert.level);
      }
    });
    
    // 转换为数组
    return Object.entries(buckets).map(([timestamp, data]) => ({
      timestamp: parseInt(timestamp),
      count: data.count,
      level: getMostSevereLevel(data.levels),
    }));
  };
  
  /**
   * 获取最严重的级别
   */
  const getMostSevereLevel = (levels: string[]): string => {
    if (levels.includes('critical')) return 'critical';
    if (levels.includes('high')) return 'high';
    if (levels.includes('medium')) return 'medium';
    if (levels.includes('low')) return 'low';
    return 'info';
  };
  
  return {
    // 状态
    loading: computed(() => loading.value),
    relations: computed(() => relations.value),
    patterns: computed(() => patterns.value),
    
    // 方法
    analyzeRelations,
    detectAttackPatterns,
    getTimeSeriesData,
    groupByIP,
  };
}

