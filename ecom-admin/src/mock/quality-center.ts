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

  // ========== 定时报表 ==========

  // 定时报表列表
  {
    url: /\/api\/quality-center\/scheduled-reports$/,
    method: 'get',
    response: () => {
      const reports = [
        {
          id: 1,
          name: '每日质量日报',
          description: '每天早上9点自动生成前一天的质量总览报表，并通过邮件发送给相关负责人',
          report_type: 'daily',
          schedule: '0 9 * * *',
          modules: ['用户管理', '订单系统', '支付模块', '商品管理'],
          recipients: ['zhangsan@zigcms.com', 'lisi@zigcms.com', 'wangwu@zigcms.com'],
          format: 'both',
          watermark_enabled: true,
          enabled: true,
          last_run_at: recentDate(1),
          next_run_at: new Date(Date.now() + 8 * 3600000).toISOString().slice(0, 19).replace('T', ' '),
          last_status: 'success',
          created_by: '张三',
          created_at: recentDate(60),
          updated_at: recentDate(5),
        },
        {
          id: 2,
          name: '每周质量周报',
          description: '每周一上午10点生成上周质量汇总报表，含趋势分析和模块质量排名',
          report_type: 'weekly',
          schedule: '0 10 * * 1',
          modules: ['用户管理', '订单系统', '支付模块', '商品管理', '报表系统', '权限系统'],
          recipients: ['zhangsan@zigcms.com', 'boss@zigcms.com'],
          format: 'pdf',
          watermark_enabled: true,
          enabled: true,
          last_run_at: recentDate(3),
          next_run_at: new Date(Date.now() + 3 * 86400000).toISOString().slice(0, 19).replace('T', ' '),
          last_status: 'success',
          created_by: '李四',
          created_at: recentDate(90),
          updated_at: recentDate(10),
        },
        {
          id: 3,
          name: '月度质量月报',
          description: '每月1号生成上月完整质量分析报表，包含AI洞察和改进建议',
          report_type: 'monthly',
          schedule: '0 9 1 * *',
          modules: ['用户管理', '订单系统', '支付模块', '商品管理', '报表系统', '权限系统'],
          recipients: ['boss@zigcms.com', 'cto@zigcms.com'],
          format: 'excel',
          watermark_enabled: false,
          enabled: true,
          last_run_at: recentDate(15),
          next_run_at: '2026-04-01 09:00:00',
          last_status: 'success',
          created_by: '王五',
          created_at: recentDate(120),
        },
        {
          id: 4,
          name: '支付模块专项报表',
          description: '针对支付模块的专项质量监控报表，关注通过率和Bug趋势',
          report_type: 'custom',
          schedule: '0 18 * * 5',
          modules: ['支付模块'],
          recipients: ['payment-team@zigcms.com'],
          format: 'pdf',
          watermark_enabled: true,
          enabled: false,
          last_run_at: recentDate(10),
          last_status: 'failed',
          created_by: '赵六',
          created_at: recentDate(30),
        },
      ];
      return success({ list: reports, total: reports.length });
    },
  },

  // 创建定时报表
  {
    url: /\/api\/quality-center\/scheduled-reports$/,
    method: 'post',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({
        id: Math.floor(Math.random() * 1000) + 100,
        ...body,
        enabled: body.enabled ?? true,
        watermark_enabled: body.watermark_enabled ?? true,
        created_by: randomName(),
        created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      });
    },
  },

  // 更新定时报表
  {
    url: /\/api\/quality-center\/scheduled-reports\/\d+$/,
    method: 'put',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({
        id: 1,
        ...body,
        updated_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      });
    },
  },

  // 删除定时报表
  {
    url: /\/api\/quality-center\/scheduled-reports\/\d+$/,
    method: 'delete',
    response: () => success(null),
  },

  // 切换报表启用状态
  {
    url: /\/api\/quality-center\/scheduled-reports\/\d+\/toggle/,
    method: 'put',
    response: () => success(null),
  },

  // 手动触发报表
  {
    url: /\/api\/quality-center\/scheduled-reports\/\d+\/trigger/,
    method: 'post',
    response: () => {
      return success({
        id: Math.floor(Math.random() * 1000),
        report_id: 1,
        report_name: '手动触发报表',
        status: 'running',
        format: 'pdf',
        recipients: ['zhangsan@zigcms.com'],
        sent_count: 0,
        started_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      });
    },
  },

  // 报表执行历史
  {
    url: /\/api\/quality-center\/report-history/,
    method: 'get',
    response: () => {
      const reportNames = ['每日质量日报', '每周质量周报', '月度质量月报', '支付模块专项报表'];
      const statuses: Array<'success' | 'failed'> = ['success', 'success', 'success', 'failed'];
      const histories = Array.from({ length: 20 }, (_, i) => ({
        id: i + 1,
        report_id: (i % 4) + 1,
        report_name: reportNames[i % 4],
        status: i === 5 ? 'failed' : statuses[i % 4],
        format: i % 3 === 0 ? 'both' : i % 3 === 1 ? 'pdf' : 'excel',
        file_url: i === 5 ? undefined : `/files/report_${i + 1}.pdf`,
        file_size: i === 5 ? undefined : Math.floor(Math.random() * 2000000) + 500000,
        recipients: ['zhangsan@zigcms.com', 'lisi@zigcms.com'],
        sent_count: i === 5 ? 0 : 2,
        error_message: i === 5 ? '邮件服务器连接超时' : undefined,
        started_at: recentDate(i + 1),
        finished_at: i === 5 ? undefined : recentDate(i + 1),
        duration_ms: i === 5 ? undefined : Math.floor(Math.random() * 30000) + 5000,
      }));
      return success({ list: histories, total: histories.length });
    },
  },

  // ========== Bug关联分析 ==========
  {
    url: /\/api\/quality-center\/bug-links/,
    method: 'get',
    response: () => {
      const bugs = [
        {
          id: 1,
          title: '订单提交接口500错误',
          severity: 'critical',
          module: '订单系统',
          status: 'open',
          related_cases: [
            { id: 101, name: '订单创建-正常流程', status: 'failed' },
            { id: 102, name: '订单创建-并发测试', status: 'failed' },
            { id: 103, name: '订单创建-边界值', status: 'passed' },
          ],
          related_feedbacks: [
            { id: 201, title: '用户反馈：下单失败', status: '处理中' },
            { id: 202, title: '用户反馈：支付后未生成订单', status: '待处理' },
          ],
        },
        {
          id: 2,
          title: '支付回调处理异常',
          severity: 'high',
          module: '支付模块',
          status: 'fixing',
          related_cases: [
            { id: 104, name: '支付回调-成功场景', status: 'failed' },
            { id: 105, name: '支付回调-重复通知', status: 'failed' },
          ],
          related_feedbacks: [
            { id: 203, title: '反馈：支付成功但显示未支付', status: '处理中' },
          ],
        },
        {
          id: 3,
          title: '用户权限校验漏洞',
          severity: 'high',
          module: '权限系统',
          status: 'open',
          related_cases: [
            { id: 106, name: '越权访问-普通用户', status: 'failed' },
            { id: 107, name: '越权访问-游客', status: 'failed' },
            { id: 108, name: '越权访问-已禁用账号', status: 'failed' },
            { id: 109, name: '正常权限-管理员', status: 'passed' },
          ],
          related_feedbacks: [],
        },
        {
          id: 4,
          title: '商品搜索响应时间过长',
          severity: 'medium',
          module: '商品管理',
          status: 'analyzing',
          related_cases: [
            { id: 110, name: '搜索性能-1000条数据', status: 'failed' },
          ],
          related_feedbacks: [
            { id: 204, title: '搜索太慢了', status: '已解决' },
            { id: 205, title: '搜索结果加载慢', status: '待处理' },
          ],
        },
        {
          id: 5,
          title: '报表导出PDF格式错乱',
          severity: 'low',
          module: '报表系统',
          status: 'fixed',
          related_cases: [
            { id: 111, name: 'PDF导出-基础验证', status: 'passed' },
          ],
          related_feedbacks: [
            { id: 206, title: '导出PDF排版有问题', status: '已解决' },
          ],
        },
        {
          id: 6,
          title: '文件上传大小限制未生效',
          severity: 'medium',
          module: '文件管理',
          status: 'open',
          related_cases: [
            { id: 112, name: '上传-超过限制文件', status: 'failed' },
            { id: 113, name: '上传-正常文件', status: 'passed' },
          ],
          related_feedbacks: [
            { id: 207, title: '能上传100MB文件', status: '处理中' },
          ],
        },
      ];
      return success({ list: bugs });
    },
  },

  // ========== 反馈分类分析 ==========
  {
    url: /\/api\/quality-center\/feedback-classification/,
    method: 'get',
    response: () => {
      const types = [
        { type: 'bug', type_name: 'Bug报告' },
        { type: 'feature', type_name: '功能需求' },
        { type: 'improvement', type_name: '改进建议' },
        { type: 'question', type_name: '使用咨询' },
      ];
      const statuses = [
        { status: 0, status_name: '待处理' },
        { status: 1, status_name: '处理中' },
        { status: 2, status_name: '已解决' },
        { status: 3, status_name: '已关闭' },
      ];
      const priorities = ['critical', 'high', 'medium', 'low'];
      const modules = ['用户管理', '订单系统', '支付模块', '商品管理', '报表系统', '权限系统'];
      const titles = [
        '登录页面白屏', '下单失败', '支付超时', '搜索不准确',
        '希望增加批量操作', '建议优化列表加载速度', '如何导出数据',
        '权限配置不生效', '报表数据不准', '文件上传失败',
        '希望支持深色模式', '密码强度提示', '订单状态不同步',
        '退款流程太复杂', '手机端适配问题', '通知消息延迟',
        '搜索结果排序问题', '图片压缩质量差', '导入数据出错',
        '国际化翻译缺失', '缓存没有更新', '接口超时',
        '希望有操作日志', '角色管理优化建议',
      ];

      const feedbacks = Array.from({ length: 24 }, (_, i) => {
        const t = types[i % types.length];
        const s = statuses[Math.floor(Math.random() * statuses.length)];
        return {
          id: i + 1,
          title: titles[i],
          type: t.type,
          type_name: t.type_name,
          status: s.status,
          status_name: s.status_name,
          priority: priorities[i % priorities.length],
          module: modules[i % modules.length],
          created_at: recentDate(30),
        };
      });
      return success({ list: feedbacks });
    },
  },
  // ========== 报表模板 ==========
  {
    url: /\/api\/quality-center\/report-templates$/,
    method: 'get',
    response: () => {
      const templates = [
        {
          id: 1, name: '标准质量日报模板', description: '包含统计卡片、趋势图、模块质量表和AI洞察的标准日报模板',
          blocks: [
            { id: 'b1', type: 'stat_cards', title: '质量概览统计', enabled: true, order: 0 },
            { id: 'b2', type: 'trend_chart', title: '质量趋势图', enabled: true, order: 1 },
            { id: 'b3', type: 'module_table', title: '模块质量排名', enabled: true, order: 2 },
            { id: 'b4', type: 'bug_pie', title: 'Bug类型分布', enabled: true, order: 3 },
            { id: 'b5', type: 'feedback_pie', title: '反馈状态分布', enabled: true, order: 4 },
            { id: 'b6', type: 'ai_insights', title: 'AI质量洞察', enabled: true, order: 5 },
          ],
          orientation: 'landscape', watermark: true, header_text: 'ZigCMS质量中心 - 日报', footer_text: '内部机密 - 仅供团队内部使用',
          is_default: true, created_by: '张三', created_at: recentDate(60),
        },
        {
          id: 2, name: '精简周报模板', description: '仅包含趋势和模块排名的精简周报',
          blocks: [
            { id: 'b1', type: 'stat_cards', title: '质量概览', enabled: true, order: 0 },
            { id: 'b2', type: 'trend_chart', title: '周趋势', enabled: true, order: 1 },
            { id: 'b3', type: 'module_table', title: '模块排名', enabled: true, order: 2 },
            { id: 'b4', type: 'custom_text', title: '本周总结', enabled: true, order: 3, config: { text: '请在此填写本周总结' } },
          ],
          orientation: 'portrait', watermark: false, header_text: 'ZigCMS - 质量周报',
          is_default: false, created_by: '李四', created_at: recentDate(30),
        },
        {
          id: 3, name: 'Bug专项分析模板', description: '专注Bug分析的报表模板，包含Bug分布和关联数据',
          blocks: [
            { id: 'b1', type: 'stat_cards', title: 'Bug统计', enabled: true, order: 0 },
            { id: 'b2', type: 'bug_pie', title: 'Bug类型分布', enabled: true, order: 1 },
            { id: 'b3', type: 'module_table', title: '模块Bug排名', enabled: true, order: 2 },
            { id: 'b4', type: 'divider', title: '分割线', enabled: true, order: 3 },
            { id: 'b5', type: 'ai_insights', title: 'AI Bug洞察', enabled: true, order: 4 },
          ],
          orientation: 'landscape', watermark: true, header_text: 'Bug专项分析报告',
          is_default: false, created_by: '王五', created_at: recentDate(15),
        },
      ];
      return success({ list: templates });
    },
  },
  {
    url: /\/api\/quality-center\/report-templates$/,
    method: 'post',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({ id: Math.floor(Math.random() * 1000) + 100, ...body, created_by: randomName(), created_at: new Date().toISOString().slice(0, 19).replace('T', ' ') });
    },
  },
  {
    url: /\/api\/quality-center\/report-templates\/\d+$/,
    method: 'put',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({ id: 1, ...body, updated_at: new Date().toISOString().slice(0, 19).replace('T', ' ') });
    },
  },
  {
    url: /\/api\/quality-center\/report-templates\/\d+$/,
    method: 'delete',
    response: () => success(null),
  },

  // ========== 邮件模板 ==========
  {
    url: /\/api\/quality-center\/email-templates$/,
    method: 'get',
    response: () => {
      const templates = [
        {
          id: 1, name: '日报邮件模板', subject: '【质量日报】{{date}} 质量中心报表',
          body_html: `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px;background:#f5f5f5"><div style="background:#165DFF;color:#fff;padding:20px;border-radius:8px 8px 0 0;text-align:center"><h1 style="margin:0;font-size:22px">📊 质量中心日报</h1><p style="margin:8px 0 0;opacity:0.85">{{date}}</p></div><div style="background:#fff;padding:20px;border-radius:0 0 8px 8px"><h2 style="color:#1D2129;font-size:16px;border-bottom:2px solid #165DFF;padding-bottom:8px">📈 质量概览</h2><table style="width:100%;border-collapse:collapse;margin:12px 0"><tr><td style="padding:8px;background:#f2f3f5;border-radius:4px;text-align:center;width:25%"><div style="font-size:24px;font-weight:bold;color:#165DFF">{{pass_rate}}%</div><div style="font-size:12px;color:#86909C;margin-top:4px">测试通过率</div></td><td style="padding:8px;background:#f2f3f5;border-radius:4px;text-align:center;width:25%"><div style="font-size:24px;font-weight:bold;color:#F53F3F">{{active_bugs}}</div><div style="font-size:12px;color:#86909C;margin-top:4px">活跃Bug</div></td><td style="padding:8px;background:#f2f3f5;border-radius:4px;text-align:center;width:25%"><div style="font-size:24px;font-weight:bold;color:#FF7D00">{{pending_feedbacks}}</div><div style="font-size:12px;color:#86909C;margin-top:4px">待处理反馈</div></td><td style="padding:8px;background:#f2f3f5;border-radius:4px;text-align:center;width:25%"><div style="font-size:24px;font-weight:bold;color:#00B42A">{{ai_fix_rate}}%</div><div style="font-size:12px;color:#86909C;margin-top:4px">AI修复率</div></td></tr></table><h2 style="color:#1D2129;font-size:16px;border-bottom:2px solid #00B42A;padding-bottom:8px">🤖 AI洞察</h2><p style="color:#4E5969;line-height:1.8">{{ai_summary}}</p><div style="text-align:center;margin-top:20px"><a href="{{dashboard_url}}" style="display:inline-block;background:#165DFF;color:#fff;padding:10px 24px;border-radius:4px;text-decoration:none;font-weight:bold">查看完整报表 →</a></div></div><div style="text-align:center;padding:12px;color:#C9CDD4;font-size:12px">此邮件由 ZigCMS 质量中心自动发送 | {{footer}}</div></div>`,
          variables: ['date', 'pass_rate', 'active_bugs', 'pending_feedbacks', 'ai_fix_rate', 'ai_summary', 'dashboard_url', 'footer'],
          is_default: true, scene: 'daily_report', created_by: '张三', created_at: recentDate(60),
        },
        {
          id: 2, name: '周报邮件模板', subject: '【质量周报】{{start_date}} ~ {{end_date}}',
          body_html: `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px"><div style="background:linear-gradient(135deg,#722ED1,#165DFF);color:#fff;padding:24px;border-radius:8px 8px 0 0;text-align:center"><h1 style="margin:0;font-size:22px">📋 质量周报</h1><p style="margin:8px 0 0;opacity:0.85">{{start_date}} ~ {{end_date}}</p></div><div style="background:#fff;padding:20px;border:1px solid #e5e6eb;border-top:none;border-radius:0 0 8px 8px"><p style="color:#4E5969;line-height:1.8">{{summary}}</p><div style="text-align:center;margin-top:20px"><a href="{{dashboard_url}}" style="display:inline-block;background:#722ED1;color:#fff;padding:10px 24px;border-radius:4px;text-decoration:none">查看详情</a></div></div></div>`,
          variables: ['start_date', 'end_date', 'summary', 'dashboard_url'],
          is_default: false, scene: 'weekly_report', created_by: '李四', created_at: recentDate(30),
        },
        {
          id: 3, name: '告警邮件模板', subject: '⚠️ 【质量告警】{{alert_title}}',
          body_html: `<div style="font-family:Arial,sans-serif;max-width:600px;margin:0 auto;padding:20px"><div style="background:#F53F3F;color:#fff;padding:20px;border-radius:8px 8px 0 0"><h1 style="margin:0;font-size:20px">⚠️ 质量告警</h1></div><div style="background:#fff;padding:20px;border:1px solid #e5e6eb;border-top:none;border-radius:0 0 8px 8px"><h2 style="color:#F53F3F">{{alert_title}}</h2><p style="color:#4E5969;line-height:1.8">{{alert_content}}</p><p style="color:#86909C;font-size:12px">模块: {{module}} | 时间: {{time}}</p><div style="text-align:center;margin-top:16px"><a href="{{action_url}}" style="display:inline-block;background:#F53F3F;color:#fff;padding:10px 24px;border-radius:4px;text-decoration:none">立即查看</a></div></div></div>`,
          variables: ['alert_title', 'alert_content', 'module', 'time', 'action_url'],
          is_default: false, scene: 'alert', created_by: '王五', created_at: recentDate(10),
        },
      ];
      return success({ list: templates });
    },
  },
  {
    url: /\/api\/quality-center\/email-templates$/,
    method: 'post',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({ id: Math.floor(Math.random() * 1000) + 100, ...body, created_by: randomName(), created_at: new Date().toISOString().slice(0, 19).replace('T', ' ') });
    },
  },
  {
    url: /\/api\/quality-center\/email-templates\/\d+$/,
    method: 'put',
    response: ({ body }: { body: Record<string, unknown> }) => {
      return success({ id: 1, ...body, updated_at: new Date().toISOString().slice(0, 19).replace('T', ' ') });
    },
  },
  {
    url: /\/api\/quality-center\/email-templates\/\d+$/,
    method: 'delete',
    response: () => success(null),
  },
  {
    url: /\/api\/quality-center\/email-templates\/\d+\/preview/,
    method: 'get',
    response: () => {
      return success({ html: '<div style="font-family:Arial;padding:20px;background:#f5f5f5"><div style="background:#165DFF;color:#fff;padding:20px;border-radius:8px 8px 0 0;text-align:center"><h1>📊 质量中心日报</h1><p>2026-03-01</p></div><div style="background:#fff;padding:20px;border-radius:0 0 8px 8px"><p>测试通过率: <b>92.5%</b> | 活跃Bug: <b>23</b> | 待处理反馈: <b>15</b> | AI修复率: <b>78.3%</b></p><p>AI洞察: 本日测试通过率环比提升2.1%，支付模块发现2个新Bug需关注。</p></div></div>' });
    },
  },

  // ========== AI分析 ==========
  {
    url: /\/api\/quality-center\/ai-analysis$/,
    method: 'post',
    response: ({ body }: { body: Record<string, unknown> }) => {
      const typeMap: Record<string, string> = {
        quality_overview: '整体质量分析',
        bug_analysis: 'Bug深度分析',
        feedback_analysis: '反馈趋势分析',
        trend_prediction: '质量趋势预测',
        risk_assessment: '风险评估',
        custom: '自定义分析',
      };
      const analysisType = String(body.type || 'quality_overview');
      return success({
        task_id: `ai_${Date.now()}`,
        status: 'completed',
        summary: `【${typeMap[analysisType] || '分析'}】经过对当前项目数据的深度分析，系统整体质量处于良好水平。测试通过率稳定在90%以上，Bug修复周期平均为4.2小时。支付模块近期Bug密度较高，建议加强回归测试。反馈处理效率环比提升15%，AI辅助修复贡献率达78%。`,
        details: [
          { title: '质量评分', content: '当前项目整体质量评分为 85/100，处于"良好"等级。其中代码质量 88分，测试覆盖率 82分，Bug修复效率 85分，用户满意度 84分。', type: 'text' },
          { title: '关键指标趋势', content: '近30天测试通过率从87.2%提升至92.5%，环比增长5.3个百分点。活跃Bug数从35个降至23个，降幅34.3%。', type: 'text' },
          { title: '模块风险热力图', content: '支付模块风险等级: 高 | 订单系统: 中 | 用户管理: 低 | 商品管理: 低 | 权限系统: 中', type: 'text' },
          { title: '异常检测', content: '检测到支付模块在近3天内Bug提交频率异常升高(+180%)，可能与最近的支付网关升级有关。建议立即进行专项回归测试。', type: 'text' },
        ],
        suggestions: [
          { id: 1, priority: 'high', title: '支付模块专项回归测试', description: '支付模块Bug密度异常升高，建议立即执行完整回归测试套件，重点覆盖支付回调和订单创建流程。', action_type: 'navigate', action_url: '/auto-test/execution' },
          { id: 2, priority: 'high', title: '关注权限校验漏洞', description: '发现3个权限相关Bug未修复，涉及越权访问风险，建议在下一个迭代优先处理。', action_type: 'navigate', action_url: '/auto-test/bug?module=权限系统' },
          { id: 3, priority: 'medium', title: '增加E2E测试覆盖', description: '当前E2E测试覆盖率仅65%，建议新增订单完整流程和支付流程的端到端测试用例。', action_type: 'info' },
          { id: 4, priority: 'medium', title: '优化反馈处理流程', description: '平均反馈处理时间为6.5小时，建议引入自动分类和优先级评估，预计可缩短30%处理时间。', action_type: 'info' },
          { id: 5, priority: 'low', title: '定期清理过期测试数据', description: '发现120条超过90天的过期测试记录，建议定期归档以提升查询性能。', action_type: 'info' },
        ],
        risk_score: 32,
        duration_ms: 3200,
        created_at: new Date().toISOString().slice(0, 19).replace('T', ' '),
      });
    },
  },
  {
    url: /\/api\/quality-center\/ai-analysis\/history/,
    method: 'get',
    response: () => {
      const types = ['quality_overview', 'bug_analysis', 'feedback_analysis', 'trend_prediction', 'risk_assessment'];
      const list = Array.from({ length: 10 }, (_, i) => ({
        task_id: `ai_hist_${i + 1}`,
        status: 'completed',
        summary: `历史分析 #${i + 1} - ${['整体质量良好', 'Bug趋势下降', '反馈处理效率提升', '预测下周质量稳定', '风险评分降低'][i % 5]}`,
        details: [],
        suggestions: [],
        risk_score: Math.floor(Math.random() * 60) + 10,
        duration_ms: Math.floor(Math.random() * 5000) + 1000,
        created_at: recentDate(i + 1),
      }));
      return success({ list, total: list.length });
    },
  },
];

export default qualityCenterMock;
