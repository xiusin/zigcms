/**
 * 质量中心 Mock 数据
 * 融合自动化测试与反馈系统的统一Mock接口
 */
import { success } from './data';

// 工具函数
const recentDate = (days: number = 30): string => {
  const date = new Date();
  date.setDate(date.getDate() - Math.floor(Math.random() * days));
  return date.toISOString().slice(0, 19).replace('T', ' ');
};

const randomName = (): string =>
  ['张三', '李四', '王五', '赵六', '钱七', '孙八'][Math.floor(Math.random() * 6)];

// ========== Dashboard 统计 ==========
const qualityCenterMock = [
  // 质量概览
  {
    url: /\/api\/quality-center\/overview/,
    method: 'get',
    response: () => {
      return success({
        pass_rate: 87.5,
        total_tasks: 42,
        active_bugs: 15,
        pending_feedbacks: 23,
        ai_fix_rate: 72.3,
        weekly_executions: 156,
        feedback_to_task_count: 18,
        avg_bug_fix_hours: 4.2,
      });
    },
  },

  // 质量趋势
  {
    url: /\/api\/quality-center\/trend/,
    method: 'get',
    response: ({ query }: { query: Record<string, string> }) => {
      const days = query?.period === 'quarter' ? 90 : query?.period === 'month' ? 30 : 7;
      const trendData = Array.from({ length: days }, (_, i) => {
        const date = new Date();
        date.setDate(date.getDate() - (days - 1 - i));
        return {
          date: date.toISOString().slice(0, 10),
          pass_rate: Math.floor(Math.random() * 15 + 80),
          bug_count: Math.floor(Math.random() * 8),
          feedback_count: Math.floor(Math.random() * 12),
          execution_count: Math.floor(Math.random() * 25 + 5),
        };
      });
      return success({
        trend_data: trendData,
        period: query?.period || 'week',
      });
    },
  },

  // 模块质量分布
  {
    url: /\/api\/quality-center\/module-quality/,
    method: 'get',
    response: () => {
      return success({
        list: [
          { module_name: '用户管理', pass_rate: 92, bug_count: 3, case_count: 45, feedback_count: 8 },
          { module_name: '订单系统', pass_rate: 85, bug_count: 7, case_count: 62, feedback_count: 15 },
          { module_name: '支付模块', pass_rate: 78, bug_count: 5, case_count: 38, feedback_count: 12 },
          { module_name: '商品管理', pass_rate: 90, bug_count: 2, case_count: 50, feedback_count: 6 },
          { module_name: '报表系统', pass_rate: 95, bug_count: 1, case_count: 28, feedback_count: 3 },
          { module_name: '权限系统', pass_rate: 88, bug_count: 4, case_count: 35, feedback_count: 5 },
        ],
      });
    },
  },

  // Bug类型分布
  {
    url: /\/api\/quality-center\/bug-distribution/,
    method: 'get',
    response: () => {
      return success({
        list: [
          { type: 'functional', type_name: '功能错误', count: 12, percentage: 30 },
          { type: 'ui', type_name: '界面问题', count: 8, percentage: 20 },
          { type: 'performance', type_name: '性能问题', count: 6, percentage: 15 },
          { type: 'security', type_name: '安全问题', count: 4, percentage: 10 },
          { type: 'data', type_name: '数据问题', count: 5, percentage: 12.5 },
          { type: 'logic', type_name: '逻辑错误', count: 5, percentage: 12.5 },
        ],
      });
    },
  },

  // 反馈状态分布
  {
    url: /\/api\/quality-center\/feedback-distribution/,
    method: 'get',
    response: () => {
      return success({
        list: [
          { status: 0, status_name: '待处理', count: 23, percentage: 28 },
          { status: 1, status_name: '处理中', count: 18, percentage: 22 },
          { status: 2, status_name: '已解决', count: 30, percentage: 37 },
          { status: 3, status_name: '已关闭', count: 8, percentage: 10 },
          { status: 4, status_name: '已拒绝', count: 3, percentage: 3 },
        ],
      });
    },
  },

  // ========== 反馈与测试联动 ==========

  // 反馈转测试任务
  {
    url: /\/api\/quality-center\/feedback-to-task/,
    method: 'post',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({
        task_id: Math.floor(Math.random() * 1000) + 100,
        task_name: body?.task_name || '反馈转测试任务',
        generated_cases: body?.auto_generate_cases ? (body?.case_count || 5) : 0,
        status: 'pending',
      });
    },
  },

  // Bug同步到反馈
  {
    url: /\/api\/quality-center\/bug-to-feedback/,
    method: 'post',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({
        feedback_id: Math.floor(Math.random() * 1000) + 100,
        feedback_title: body?.feedback_title || 'Bug转反馈',
        status: 'pending',
      });
    },
  },

  // 关联记录
  {
    url: /\/api\/quality-center\/link-records/,
    method: 'get',
    response: () => {
      const records = Array.from({ length: 12 }, (_, i) => {
        const linkTypes = [
          { source_type: 'feedback', target_type: 'task', link_type: 'feedback_to_task' },
          { source_type: 'bug', target_type: 'feedback', link_type: 'bug_to_feedback' },
          { source_type: 'task', target_type: 'bug', link_type: 'task_to_bug' },
          { source_type: 'case', target_type: 'bug', link_type: 'case_to_bug' },
        ] as const;
        const lt = linkTypes[i % 4];
        return {
          id: i + 1,
          source_type: lt.source_type,
          source_id: Math.floor(Math.random() * 100) + 1,
          source_title: [
            '用户登录异常反馈', '订单提交失败Bug', '支付回调测试任务',
            '商品搜索测试用例', '权限验证Bug', '性能优化反馈',
            '数据导出测试任务', '文件上传用例', '接口超时反馈',
            '页面渲染Bug', '缓存策略任务', '搜索排序用例',
          ][i],
          target_type: lt.target_type,
          target_id: Math.floor(Math.random() * 100) + 1,
          target_title: [
            '登录模块回归测试', '订单创建-反馈#1023', '支付Bug分析',
            '搜索接口Bug#45', '权限系统-反馈#892', '性能测试任务',
            '导出功能-反馈#567', '上传Bug分析', '超时问题-反馈#234',
            '渲染测试任务', '缓存Bug分析', '排序Bug#78',
          ][i],
          link_type: lt.link_type,
          created_at: recentDate(30),
          created_by: randomName(),
        };
      });
      return success({ list: records, total: records.length });
    },
  },

  // ========== 活动流 ==========
  {
    url: /\/api\/quality-center\/activities/,
    method: 'get',
    response: () => {
      const activities = [
        { type: 'test_pass', title: '测试通过', description: '用户登录模块回归测试全部通过 (45/45)', module: '用户管理' },
        { type: 'bug_found', title: '发现Bug', description: '订单提交接口返回500错误，已自动创建Bug分析', module: '订单系统' },
        { type: 'ai_fix', title: 'AI自动修复', description: 'AI成功修复支付回调处理异常，修复代码已提交', module: '支付模块' },
        { type: 'feedback_created', title: '新反馈', description: '用户反馈：商品搜索结果排序不正确', module: '商品管理' },
        { type: 'test_fail', title: '测试失败', description: '报表导出测试失败 (38/42)，4个用例未通过', module: '报表系统' },
        { type: 'feedback_resolved', title: '反馈已解决', description: '权限验证异常问题已修复并验证通过', module: '权限系统' },
        { type: 'ai_analysis', title: 'AI分析完成', description: 'AI分析出数据库连接池配置问题，置信度92%', module: '基础设施' },
        { type: 'bug_fixed', title: 'Bug已修复', description: '文件上传大小限制错误已修复', module: '文件管理' },
        { type: 'test_pass', title: '测试通过', description: 'API接口安全测试全部通过 (28/28)', module: '安全模块' },
        { type: 'feedback_created', title: '新反馈', description: '用户反馈：页面加载速度过慢', module: '性能优化' },
      ];
      return success({
        list: activities.map((a, i) => ({
          id: i + 1,
          ...a,
          user_name: randomName(),
          user_avatar: `https://api.dicebear.com/7.x/avataaars/svg?seed=${i}`,
          related_id: Math.floor(Math.random() * 100) + 1,
          related_type: a.type.includes('test') ? 'execution' : a.type.includes('bug') ? 'bug' : 'feedback',
          created_at: recentDate(7),
        })),
      });
    },
  },

  // ========== AI 洞察 ==========
  {
    url: /\/api\/quality-center\/ai-insights/,
    method: 'get',
    response: () => {
      return success({
        list: [
          {
            id: 1,
            type: 'risk',
            severity: 'high',
            title: '支付模块质量风险预警',
            description: '支付模块近7天测试通过率下降12%，建议增加回归测试覆盖并排查最近的代码变更。',
            module: '支付模块',
            action_url: '/auto-test/task',
            action_text: '查看测试任务',
            created_at: recentDate(1),
          },
          {
            id: 2,
            type: 'suggestion',
            severity: 'medium',
            title: '建议增加订单模块边界测试',
            description: '分析发现订单模块的边界条件测试覆盖不足，建议AI自动生成10个边界值测试用例。',
            module: '订单系统',
            action_url: '/auto-test/ai-generate',
            action_text: 'AI生成用例',
            created_at: recentDate(2),
          },
          {
            id: 3,
            type: 'anomaly',
            severity: 'medium',
            title: '接口响应时间异常波动',
            description: '检测到商品搜索接口响应时间在14:00-16:00时段异常升高，平均延迟从200ms上升到1.2s。',
            module: '商品管理',
            action_url: '/auto-test/bug',
            action_text: '查看Bug分析',
            created_at: recentDate(1),
          },
          {
            id: 4,
            type: 'trend',
            severity: 'low',
            title: '整体质量趋势向好',
            description: '本月测试通过率环比提升5.2%，AI自动修复成功率提升8.1%，反馈处理时效缩短30%。',
            module: '全局',
            created_at: recentDate(3),
          },
        ],
      });
    },
  },
];

export default qualityCenterMock;
