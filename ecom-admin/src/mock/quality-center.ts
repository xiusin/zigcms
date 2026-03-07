/**
 * 质量中心 Mock 数据
 * 包含所有质量中心相关接口的完整 Mock 数据
 */

import Mock from 'mockjs';

// ==================== 工具函数 ====================

const responseSuccess = (data: any, msg = 'success') => ({
  code: 200,
  msg,
  data,
});

const responsePage = <T>(items: T[], page = 1, pageSize = 10, total?: number) => ({
  items,
  total: total || items.length,
  page,
  page_size: pageSize,
});

const recentDate = (days: number = 30): string => {
  const date = new Date();
  date.setDate(date.getDate() - Math.floor(Math.random() * days));
  return date.toISOString().slice(0, 19).replace('T', ' ');
};

const randomName = (): string =>
  ['张三', '李四', '王五', '赵六', '钱七', '孙八'][Math.floor(Math.random() * 6)];

// ==================== 数据生成器 ====================

// 生成测试用例列表
const generateTestCases = (count: number) => {
  return Mock.mock({
    [`list|${count}`]: [
      {
        'id|+1': 1,
        'title': '@ctitle(10, 30)',
        'project_id|1-5': 1,
        'module_id|1-10': 1,
        'requirement_id|1-20': function() {
          return Math.random() > 0.3 ? this.id : null;
        },
        'priority|1': ['low', 'medium', 'high', 'critical'],
        'status|1': ['pending', 'in_progress', 'passed', 'failed', 'blocked'],
        'precondition': '@cparagraph(1, 2)',
        'steps': '@cparagraph(2, 4)',
        'expected_result': '@cparagraph(1, 2)',
        'actual_result': '@cparagraph(1, 2)',
        'assignee': function() {
          return Math.random() > 0.2 ? Mock.Random.cname() : null;
        },
        'tags': function() {
          const tags = ['功能测试', '性能测试', 'UI测试', '兼容性测试', '安全测试'];
          return Mock.Random.shuffle(tags).slice(0, Mock.Random.integer(1, 3)).join(',');
        },
        'created_by': '@cname',
        'created_at': '@datetime("T")',
        'updated_at': '@datetime("T")',
      },
    ],
  }).list;
};

// 生成项目列表
const generateProjects = (count: number) => {
  return Mock.mock({
    [`list|${count}`]: [
      {
        'id|+1': 1,
        'name': '@ctitle(5, 15)',
        'description': '@cparagraph(2, 3)',
        'status|1': ['active', 'archived', 'closed'],
        'owner': '@cname',
        'members': function() {
          const members = [];
          for (let i = 0; i < Mock.Random.integer(3, 8); i++) {
            members.push(Mock.Random.cname());
          }
          return members.join(',');
        },
        'settings': '{}',
        'archived': function() {
          return this.status === 'archived';
        },
        'created_by': '@cname',
        'created_at': '@datetime("T")',
        'updated_at': '@datetime("T")',
      },
    ],
  }).list;
};

// Mock 数据存储
let testCases = generateTestCases(50);
let projects = generateProjects(10);

// ==================== Mock 接口定义 ====================

export default [
  // ==================== 测试用例管理 ====================
  
  // 搜索测试用例
  {
    url: /\/api\/quality\/test-cases(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess(responsePage(testCases.slice(0, 20), 1, 20, testCases.length));
    },
  },
  
  // 创建测试用例
  {
    url: '/api/quality/test-cases',
    method: 'post',
    response: (options: any) => {
      const body = JSON.parse(options.body);
      const newCase = {
        id: testCases.length + 1,
        ...body,
        status: 'pending',
        created_at: Date.now(),
        updated_at: Date.now(),
      };
      testCases.push(newCase);
      return responseSuccess(newCase, '创建成功');
    },
  },
  
  // 获取测试用例详情
  {
    url: /\/api\/quality\/test-cases\/(\d+)$/,
    method: 'get',
    response: (options: any) => {
      const id = parseInt(options.url.match(/\/api\/quality\/test-cases\/(\d+)$/)[1]);
      const testCase = testCases.find((tc: any) => tc.id === id);
      return responseSuccess(testCase || {});
    },
  },
  
  // 更新测试用例
  {
    url: /\/api\/quality\/test-cases\/(\d+)$/,
    method: 'put',
    response: () => {
      return responseSuccess(null, '更新成功');
    },
  },
  
  // 删除测试用例
  {
    url: /\/api\/quality\/test-cases\/(\d+)$/,
    method: 'delete',
    response: () => {
      return responseSuccess(null, '删除成功');
    },
  },
  
  // 批量删除测试用例
  {
    url: '/api/quality/test-cases/batch-delete',
    method: 'post',
    response: () => {
      return responseSuccess(null, '批量删除成功');
    },
  },
  
  // 批量更新测试用例状态
  {
    url: '/api/quality/test-cases/batch-update-status',
    method: 'post',
    response: () => {
      return responseSuccess(null, '批量更新成功');
    },
  },
  
  // 批量分配测试用例负责人
  {
    url: '/api/quality/test-cases/batch-update-assignee',
    method: 'post',
    response: () => {
      return responseSuccess(null, '批量分配成功');
    },
  },
  
  // 执行测试用例
  {
    url: /\/api\/quality\/test-cases\/(\d+)\/execute$/,
    method: 'post',
    response: () => {
      return responseSuccess({
        id: Mock.Random.integer(1, 10000),
        status: 'passed',
        executed_at: Date.now(),
      }, '执行成功');
    },
  },
  
  // 获取测试用例执行历史
  {
    url: /\/api\/quality\/test-cases\/(\d+)\/executions$/,
    method: 'get',
    response: () => {
      const executions = Mock.mock({
        'list|5-15': [
          {
            'id|+1': 1,
            'executor': '@cname',
            'status|1': ['passed', 'failed', 'blocked'],
            'actual_result': '@cparagraph(1, 2)',
            'remark': '@cparagraph(1)',
            'duration_ms|1000-60000': 5000,
            'executed_at': '@datetime("T")',
          },
        ],
      }).list;
      return responseSuccess(executions);
    },
  },

  // ==================== AI 生成 ====================
  
  // AI 生成测试用例
  {
    url: '/api/quality/ai/generate-test-cases',
    method: 'post',
    response: () => {
      const testCases = Mock.mock({
        'list|5-10': [
          {
            'title': '@ctitle(10, 30)',
            'precondition': '@cparagraph(1, 2)',
            'steps': '@cparagraph(2, 4)',
            'expected_result': '@cparagraph(1, 2)',
            'priority|1': ['low', 'medium', 'high', 'critical'],
            'tags': ['AI生成', '功能测试'],
            'selected': true,
          },
        ],
      }).list;
      return responseSuccess({
        test_cases: testCases,
        progress: 100,
        message: 'AI 生成完成',
      });
    },
  },
  
  // AI 生成需求
  {
    url: '/api/quality/ai/generate-requirement',
    method: 'post',
    response: () => {
      return responseSuccess({
        title: Mock.Random.ctitle(10, 30),
        description: Mock.Random.cparagraph(3, 5),
        priority: Mock.Random.pick(['low', 'medium', 'high', 'critical']),
        estimated_cases: Mock.Random.integer(10, 50),
      });
    },
  },
  
  // AI 分析反馈
  {
    url: '/api/quality/ai/analyze-feedback',
    method: 'post',
    response: () => {
      return responseSuccess({
        bug_type: Mock.Random.pick(['功能缺陷', '性能问题', 'UI问题', '兼容性问题', '安全漏洞']),
        severity: Mock.Random.pick(['low', 'medium', 'high', 'critical']),
        affected_modules: [Mock.Random.ctitle(3, 8), Mock.Random.ctitle(3, 8)],
        suggested_actions: ['立即修复该问题', '增加相关测试用例', '优化代码实现'],
      });
    },
  },
  
  // ==================== 项目管理 ====================
  
  // 获取项目列表
  {
    url: /\/api\/quality\/projects(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess(responsePage(projects, 1, 10, projects.length));
    },
  },
  
  // 创建项目
  {
    url: '/api/quality/projects',
    method: 'post',
    response: (options: any) => {
      const body = JSON.parse(options.body);
      const newProject = {
        id: projects.length + 1,
        ...body,
        status: 'active',
        archived: false,
        created_at: Date.now(),
        updated_at: Date.now(),
      };
      projects.push(newProject);
      return responseSuccess(newProject, '创建成功');
    },
  },
  
  // 获取项目详情
  {
    url: /\/api\/quality\/projects\/(\d+)$/,
    method: 'get',
    response: (options: any) => {
      const id = parseInt(options.url.match(/\/api\/quality\/projects\/(\d+)$/)[1]);
      const project = projects.find((p: any) => p.id === id);
      return responseSuccess(project || {});
    },
  },
  
  // 更新项目
  {
    url: /\/api\/quality\/projects\/(\d+)$/,
    method: 'put',
    response: () => {
      return responseSuccess(null, '更新成功');
    },
  },
  
  // 删除项目
  {
    url: /\/api\/quality\/projects\/(\d+)$/,
    method: 'delete',
    response: () => {
      return responseSuccess(null, '删除成功');
    },
  },
  
  // 归档项目
  {
    url: /\/api\/quality\/projects\/(\d+)\/archive$/,
    method: 'post',
    response: () => {
      return responseSuccess(null, '归档成功');
    },
  },
  
  // 恢复项目
  {
    url: /\/api\/quality\/projects\/(\d+)\/restore$/,
    method: 'post',
    response: () => {
      return responseSuccess(null, '恢复成功');
    },
  },
  
  // 获取项目统计数据
  {
    url: /\/api\/quality\/projects\/(\d+)\/statistics$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        total_cases: Mock.Random.integer(50, 500),
        execution_count: Mock.Random.integer(100, 1000),
        pass_rate: Mock.Random.integer(60, 95),
        bug_count: Mock.Random.integer(10, 100),
        requirement_coverage: Mock.Random.integer(50, 90),
      });
    },
  },
  
  // ==================== 模块管理 ====================
  
  // 获取模块树
  {
    url: /\/api\/quality\/modules\/tree(\?.*)?$/,
    method: 'get',
    response: () => {
      const modules = Mock.mock({
        'list|3-6': [
          {
            'id|+1': 1,
            'name': '@ctitle(3, 8)',
            'description': '@cparagraph(1, 2)',
            'level': 0,
            'sort_order|+1': 1,
            'children|2-4': [
              {
                'id|+100': 100,
                'name': '@ctitle(3, 8)',
                'description': '@cparagraph(1)',
                'level': 1,
                'sort_order|+1': 1,
                'children': [],
              },
            ],
          },
        ],
      }).list;
      return responseSuccess(modules);
    },
  },
  
  // 创建模块
  {
    url: '/api/quality/modules',
    method: 'post',
    response: (options: any) => {
      const body = JSON.parse(options.body);
      return responseSuccess({
        id: Mock.Random.integer(1, 1000),
        ...body,
        level: 0,
        sort_order: 1,
        created_at: Date.now(),
        updated_at: Date.now(),
      }, '创建成功');
    },
  },
  
  // 获取模块详情
  {
    url: /\/api\/quality\/modules\/(\d+)$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        id: 1,
        name: Mock.Random.ctitle(3, 8),
        description: Mock.Random.cparagraph(1, 2),
        level: 0,
        sort_order: 1,
      });
    },
  },
  
  // 更新模块
  {
    url: /\/api\/quality\/modules\/(\d+)$/,
    method: 'put',
    response: () => {
      return responseSuccess(null, '更新成功');
    },
  },
  
  // 删除模块
  {
    url: /\/api\/quality\/modules\/(\d+)$/,
    method: 'delete',
    response: () => {
      return responseSuccess(null, '删除成功');
    },
  },
  
  // 移动模块
  {
    url: /\/api\/quality\/modules\/(\d+)\/move$/,
    method: 'post',
    response: () => {
      return responseSuccess(null, '移动成功');
    },
  },
  
  // 获取模块统计数据
  {
    url: /\/api\/quality\/modules\/(\d+)\/statistics$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        total_cases: Mock.Random.integer(10, 100),
        pass_rate: Mock.Random.integer(60, 95),
        bug_count: Mock.Random.integer(5, 50),
        coverage_rate: Mock.Random.integer(50, 90),
      });
    },
  },

  // ==================== 需求管理 ====================
  
  // 搜索需求
  {
    url: /\/api\/quality\/requirements(\?.*)?$/,
    method: 'get',
    response: () => {
      const requirements = Mock.mock({
        'list|20': [
          {
            'id|+1': 1,
            'project_id|1-5': 1,
            'title': '@ctitle(10, 30)',
            'description': '@cparagraph(3, 5)',
            'priority|1': ['low', 'medium', 'high', 'critical'],
            'status|1': ['pending', 'reviewed', 'developing', 'testing', 'in_test', 'completed', 'closed'],
            'assignee': function() {
              return Math.random() > 0.2 ? Mock.Random.cname() : null;
            },
            'estimated_cases|5-50': 20,
            'actual_cases|0-50': 15,
            'coverage_rate': function() {
              return this.estimated_cases > 0 
                ? Math.round((this.actual_cases / this.estimated_cases) * 100) 
                : 0;
            },
            'created_by': '@cname',
            'created_at': '@datetime("T")',
            'updated_at': '@datetime("T")',
          },
        ],
      }).list;
      return responseSuccess(responsePage(requirements, 1, 20, requirements.length));
    },
  },
  
  // 创建需求
  {
    url: '/api/quality/requirements',
    method: 'post',
    response: (options: any) => {
      const body = JSON.parse(options.body);
      return responseSuccess({
        id: Mock.Random.integer(1, 1000),
        ...body,
        status: 'pending',
        actual_cases: 0,
        coverage_rate: 0,
        created_at: Date.now(),
        updated_at: Date.now(),
      }, '创建成功');
    },
  },
  
  // 获取需求详情
  {
    url: /\/api\/quality\/requirements\/(\d+)$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        id: 1,
        project_id: 1,
        title: Mock.Random.ctitle(10, 30),
        description: Mock.Random.cparagraph(3, 5),
        priority: 'high',
        status: 'developing',
        assignee: Mock.Random.cname(),
        estimated_cases: 25,
        actual_cases: 15,
        coverage_rate: 60,
        created_by: Mock.Random.cname(),
        created_at: Date.now(),
        updated_at: Date.now(),
      });
    },
  },
  
  // 更新需求
  {
    url: /\/api\/quality\/requirements\/(\d+)$/,
    method: 'put',
    response: () => {
      return responseSuccess(null, '更新成功');
    },
  },
  
  // 删除需求
  {
    url: /\/api\/quality\/requirements\/(\d+)$/,
    method: 'delete',
    response: () => {
      return responseSuccess(null, '删除成功');
    },
  },
  
  // 关联测试用例
  {
    url: /\/api\/quality\/requirements\/(\d+)\/link-test-case$/,
    method: 'post',
    response: () => {
      return responseSuccess(null, '关联成功');
    },
  },
  
  // 取消关联测试用例
  {
    url: /\/api\/quality\/requirements\/(\d+)\/unlink-test-case\/(\d+)$/,
    method: 'delete',
    response: () => {
      return responseSuccess(null, '取消关联成功');
    },
  },
  
  // 导入需求
  {
    url: '/api/quality/requirements/import',
    method: 'post',
    response: () => {
      return responseSuccess(null, '导入成功');
    },
  },
  
  // 导出需求
  {
    url: /\/api\/quality\/requirements\/export(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({ url: '/mock/requirements.xlsx' }, '导出成功');
    },
  },
  
  // ==================== 反馈管理 ====================
  
  // 搜索反馈
  {
    url: /\/api\/quality\/feedbacks(\?.*)?$/,
    method: 'get',
    response: () => {
      const feedbacks = Mock.mock({
        'list|20': [
          {
            'id|+1': 1,
            'title': '@ctitle(10, 30)',
            'content': '@cparagraph(3, 5)',
            'type|1': ['bug', 'feature', 'improvement', 'question'],
            'severity|1': ['low', 'medium', 'high', 'critical'],
            'status|1': ['pending', 'in_progress', 'resolved', 'closed', 'rejected'],
            'assignee': function() {
              return Math.random() > 0.3 ? Mock.Random.cname() : null;
            },
            'submitter': '@cname',
            'follow_count|0-5': 2,
            'last_follow_at': function() {
              return this.follow_count > 0 ? Mock.Random.datetime('T') : null;
            },
            'created_at': '@datetime("T")',
            'updated_at': '@datetime("T")',
          },
        ],
      }).list;
      return responseSuccess(responsePage(feedbacks, 1, 20, feedbacks.length));
    },
  },
  
  // 创建反馈
  {
    url: '/api/quality/feedbacks',
    method: 'post',
    response: (options: any) => {
      const body = JSON.parse(options.body);
      return responseSuccess({
        id: Mock.Random.integer(1, 1000),
        ...body,
        status: 'pending',
        follow_count: 0,
        created_at: Date.now(),
        updated_at: Date.now(),
      }, '创建成功');
    },
  },
  
  // 获取反馈详情
  {
    url: /\/api\/quality\/feedbacks\/(\d+)$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        id: 1,
        title: Mock.Random.ctitle(10, 30),
        content: Mock.Random.cparagraph(3, 5),
        type: 'bug',
        severity: 'high',
        status: 'in_progress',
        assignee: Mock.Random.cname(),
        submitter: Mock.Random.cname(),
        follow_ups: JSON.stringify([
          {
            id: 1,
            content: Mock.Random.cparagraph(1, 2),
            follower: Mock.Random.cname(),
            created_at: Mock.Random.datetime('T'),
          },
        ]),
        follow_count: 1,
        last_follow_at: Mock.Random.datetime('T'),
        created_at: Date.now(),
        updated_at: Date.now(),
      });
    },
  },
  
  // 更新反馈
  {
    url: /\/api\/quality\/feedbacks\/(\d+)$/,
    method: 'put',
    response: () => {
      return responseSuccess(null, '更新成功');
    },
  },
  
  // 删除反馈
  {
    url: /\/api\/quality\/feedbacks\/(\d+)$/,
    method: 'delete',
    response: () => {
      return responseSuccess(null, '删除成功');
    },
  },
  
  // 添加跟进记录
  {
    url: /\/api\/quality\/feedbacks\/(\d+)\/follow-up$/,
    method: 'post',
    response: () => {
      return responseSuccess(null, '添加成功');
    },
  },
  
  // 批量指派反馈
  {
    url: '/api/quality/feedbacks/batch-assign',
    method: 'post',
    response: () => {
      return responseSuccess(null, '批量指派成功');
    },
  },
  
  // 批量更新反馈状态
  {
    url: '/api/quality/feedbacks/batch-update-status',
    method: 'post',
    response: () => {
      return responseSuccess(null, '批量更新成功');
    },
  },
  
  // 导出反馈
  {
    url: /\/api\/quality\/feedbacks\/export(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({ url: '/mock/feedbacks.xlsx' }, '导出成功');
    },
  },

  // ==================== 数据可视化 ====================
  
  // 获取总体统计数据
  {
    url: /\/api\/quality\/statistics\/overview(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        data: {
          pass_rate: Mock.Random.integer(80, 95),
          total_tasks: Mock.Random.integer(30, 50),
          active_bugs: Mock.Random.integer(10, 30),
          pending_feedbacks: Mock.Random.integer(15, 35),
          ai_fix_rate: Mock.Random.integer(65, 85),
          weekly_executions: Mock.Random.integer(100, 200),
        },
      });
    },
  },
  
  // 获取模块质量分布
  {
    url: /\/api\/quality\/statistics\/module-distribution(\?.*)?$/,
    method: 'get',
    response: () => {
      const modules = Mock.mock({
        'list|5-10': [
          {
            'moduleId|+1': 1,
            'moduleName': '@ctitle(3, 8)',
            'testCaseCount|10-100': 50,
            'passRate|60-95': 80,
            'bugCount|5-50': 20,
          },
        ],
      }).list;
      return responseSuccess({ data: modules });
    },
  },
  
  // 获取 Bug 质量分布
  {
    url: /\/api\/quality\/statistics\/bug-distribution(\?.*)?$/,
    method: 'get',
    response: () => {
      const bugs = Mock.mock({
        'list|5-10': [
          {
            'moduleName': '@ctitle(3, 8)',
            'functionalBugs|5-30': 15,
            'performanceBugs|2-15': 8,
            'uiBugs|3-20': 10,
            'compatibilityBugs|1-10': 5,
          },
        ],
      }).list;
      return responseSuccess({ data: bugs });
    },
  },
  
  // 获取反馈状态分布
  {
    url: /\/api\/quality\/statistics\/feedback-distribution(\?.*)?$/,
    method: 'get',
    response: () => {
      const statuses = ['pending', 'in_progress', 'resolved', 'closed', 'rejected'];
      const distribution = statuses.map((status) => ({
        status,
        count: Mock.Random.integer(10, 100),
      }));
      return responseSuccess({ data: distribution });
    },
  },
  
  // 获取质量趋势
  {
    url: /\/api\/quality\/statistics\/quality-trend(\?.*)?$/,
    method: 'get',
    response: () => {
      const days = 30;
      const trend = [];
      const now = new Date();
      
      for (let i = days - 1; i >= 0; i--) {
        const date = new Date(now);
        date.setDate(date.getDate() - i);
        
        trend.push({
          date: date.toISOString().split('T')[0],
          passRate: Mock.Random.integer(70, 95),
          bugCount: Mock.Random.integer(5, 30),
          executionCount: Mock.Random.integer(20, 100),
        });
      }
      
      return responseSuccess({ data: trend });
    },
  },
  
  // 导出图表
  {
    url: /\/api\/quality\/statistics\/export(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({ url: '/mock/chart.png' }, '导出成功');
    },
  },
  
  // ==================== 报表相关 ====================
  
  // 生成测试用例报表
  {
    url: /\/api\/quality-center\/reports\/test-case(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        data: {
          total_cases: Mock.Random.integer(100, 500),
          executed_cases: Mock.Random.integer(80, 400),
          passed_cases: Mock.Random.integer(70, 350),
          failed_cases: Mock.Random.integer(5, 50),
          blocked_cases: Mock.Random.integer(0, 20),
          pass_rate: Mock.Random.integer(75, 95),
          execution_rate: Mock.Random.integer(80, 100),
          avg_execution_time: Mock.Random.integer(30, 120),
          trend: Array.from({ length: 7 }, (_, i) => ({
            date: new Date(Date.now() - (6 - i) * 86400000).toISOString().split('T')[0],
            pass_rate: Mock.Random.integer(75, 95),
            execution_count: Mock.Random.integer(20, 80),
          })),
        },
      });
    },
  },
  
  // 生成反馈报表
  {
    url: /\/api\/quality-center\/reports\/feedback(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        data: {
          total_feedbacks: Mock.Random.integer(50, 200),
          pending_feedbacks: Mock.Random.integer(10, 50),
          in_progress_feedbacks: Mock.Random.integer(15, 60),
          resolved_feedbacks: Mock.Random.integer(20, 80),
          closed_feedbacks: Mock.Random.integer(5, 30),
          avg_response_time: Mock.Random.integer(2, 24),
          avg_resolution_time: Mock.Random.integer(24, 120),
          type_distribution: [
            { type: 'bug', count: Mock.Random.integer(20, 80) },
            { type: 'feature', count: Mock.Random.integer(10, 40) },
            { type: 'improvement', count: Mock.Random.integer(10, 40) },
            { type: 'question', count: Mock.Random.integer(5, 20) },
          ],
        },
      });
    },
  },
  
  // 生成需求报表
  {
    url: /\/api\/quality-center\/reports\/requirement(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        data: {
          total_requirements: Mock.Random.integer(30, 100),
          pending_requirements: Mock.Random.integer(5, 20),
          in_progress_requirements: Mock.Random.integer(10, 30),
          completed_requirements: Mock.Random.integer(15, 50),
          avg_coverage_rate: Mock.Random.integer(60, 90),
          avg_test_cases: Mock.Random.integer(15, 40),
          priority_distribution: [
            { priority: 'critical', count: Mock.Random.integer(2, 10) },
            { priority: 'high', count: Mock.Random.integer(10, 30) },
            { priority: 'medium', count: Mock.Random.integer(15, 40) },
            { priority: 'low', count: Mock.Random.integer(5, 20) },
          ],
        },
      });
    },
  },
  
  // 生成项目质量报表
  {
    url: /\/api\/quality-center\/reports\/project-quality(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({
        data: {
          overall_quality_score: Mock.Random.integer(70, 95),
          test_coverage: Mock.Random.integer(60, 90),
          code_quality: Mock.Random.integer(70, 95),
          bug_density: Mock.Random.float(0.1, 2.0, 1, 2),
          defect_removal_efficiency: Mock.Random.integer(75, 95),
          modules: Mock.mock({
            'list|5-8': [
              {
                'module_name': '@ctitle(3, 8)',
                'quality_score|70-95': 85,
                'test_coverage|60-90': 75,
                'bug_count|2-20': 10,
              },
            ],
          }).list,
        },
      });
    },
  },
  
  // 导出报表（HTML）
  {
    url: /\/api\/quality-center\/reports\/export\/html(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({ url: '/mock/report.html' }, '导出成功');
    },
  },
  
  // 导出报表（PDF）
  {
    url: /\/api\/quality-center\/reports\/export\/pdf(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({ url: '/mock/report.pdf' }, '导出成功');
    },
  },
  
  // 导出报表（Excel）
  {
    url: /\/api\/quality-center\/reports\/export\/excel(\?.*)?$/,
    method: 'get',
    response: () => {
      return responseSuccess({ url: '/mock/report.xlsx' }, '导出成功');
    },
  },
  
  // ==================== 其他接口 ====================
  
  // 反馈转测试任务
  {
    url: '/api/quality/feedbacks/to-task',
    method: 'post',
    response: () => {
      return responseSuccess({
        task_id: Mock.Random.integer(1, 1000),
        task_name: '反馈转测试任务',
        status: 'pending',
      }, '转换成功');
    },
  },
  
  // Bug 同步到反馈
  {
    url: '/api/quality/bugs/to-feedback',
    method: 'post',
    response: () => {
      return responseSuccess({
        feedback_id: Mock.Random.integer(1, 1000),
        feedback_title: 'Bug转反馈',
        status: 'pending',
      }, '同步成功');
    },
  },
  
  // 获取关联记录
  {
    url: /\/api\/quality\/links(\?.*)?$/,
    method: 'get',
    response: () => {
      const records = Mock.mock({
        'list|10': [
          {
            'id|+1': 1,
            'source_type|1': ['feedback', 'bug', 'task', 'case'],
            'source_id|1-100': 1,
            'source_title': '@ctitle(10, 30)',
            'target_type|1': ['task', 'feedback', 'bug', 'case'],
            'target_id|1-100': 1,
            'target_title': '@ctitle(10, 30)',
            'link_type': 'feedback_to_task',
            'created_at': '@datetime("T")',
            'created_by': '@cname',
          },
        ],
      }).list;
      return responseSuccess({ list: records, total: records.length });
    },
  },
  
  // 获取最近活动
  {
    url: /\/api\/quality\/activities\/recent(\?.*)?$/,
    method: 'get',
    response: () => {
      const activities = Mock.mock({
        'list|10': [
          {
            'id|+1': 1,
            'type|1': ['test_pass', 'test_fail', 'bug_found', 'feedback_created', 'ai_fix'],
            'title': '@ctitle(5, 15)',
            'description': '@cparagraph(1, 2)',
            'module': '@ctitle(3, 8)',
            'user_name': '@cname',
            'created_at': '@datetime("T")',
          },
        ],
      }).list;
      return responseSuccess({ list: activities });
    },
  },
  
  // 获取 AI 洞察
  {
    url: /\/api\/quality\/ai\/insights(\?.*)?$/,
    method: 'get',
    response: () => {
      const insights = Mock.mock({
        'list|3-5': [
          {
            'id|+1': 1,
            'type|1': ['risk', 'suggestion', 'anomaly', 'trend'],
            'severity|1': ['low', 'medium', 'high'],
            'title': '@ctitle(10, 20)',
            'description': '@cparagraph(2, 3)',
            'module': '@ctitle(3, 8)',
            'created_at': '@datetime("T")',
          },
        ],
      }).list;
      return responseSuccess({ list: insights });
    },
  },
];
