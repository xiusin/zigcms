/**
 * 自动化测试系统 Mock 数据
 */
import Mock from 'mockjs';
import { success, pageSuccess } from './data';

// 工具函数：生成随机日期
const randomDate = () => {
  const start = new Date(2024, 0, 1);
  const end = new Date();
  return new Date(start.getTime() + Math.random() * (end.getTime() - start.getTime()))
    .toISOString()
    .slice(0, 19)
    .replace('T', ' ');
};

// 工具函数：生成随机日期（相对现在）
const recentDate = (days: number = 30) => {
  const date = new Date();
  date.setDate(date.getDate() - Math.floor(Math.random() * days));
  return date.toISOString().slice(0, 19).replace('T', ' ');
};

// 生成测试任务
const generateTestTasks = () => {
  return Array.from({ length: 15 }, (_, i) => ({
    id: i + 1,
    name: ['用户管理模块测试', '订单流程测试', '支付功能测试', '报表生成测试', '权限验证测试'][
      i % 5
    ],
    description: `针对第${i + 1}个模块的全面测试任务`,
    type: ['functional', 'integration', 'regression', 'performance', 'security'][i % 5],
    status: ['pending', 'running', 'completed', 'failed'][i % 4],
    priority: [0, 1, 2, 3][i % 4],
    trigger_type: ['manual', 'scheduled', 'webhook', 'ci_cd', 'ai_auto'][i % 5],
    schedule: i % 5 === 1 ? '0 0 * * *' : null,
    webhook_url: i % 5 === 2 ? 'https://example.com/webhook/test' : null,
    test_suite_id: (i % 5) + 1,
    related_feedback_id: i % 3 === 0 ? i + 100 : null,
    created_by: 1,
    assigned_to: i % 2 === 0 ? 1 : null,
    total_runs: Math.floor(Math.random() * 50),
    success_count: Math.floor(Math.random() * 40),
    fail_count: Math.floor(Math.random() * 10),
    last_run_at: recentDate(7),
    last_run_result: {
      passed: Math.floor(Math.random() * 100),
      failed: Math.floor(Math.random() * 10),
      skipped: Math.floor(Math.random() * 5),
      total: 100,
      pass_rate: Math.floor(Math.random() * 30 + 70),
      duration: Math.floor(Math.random() * 60000),
    },
    created_at: recentDate(90),
    updated_at: recentDate(7),
    started_at: i % 4 === 2 ? recentDate(1) : null,
    completed_at: i % 4 === 2 ? recentDate(0) : null,
  }));
};

// 生成测试用例
const generateTestCases = () => {
  return Array.from({ length: 30 }, (_, i) => ({
    id: i + 1,
    name: [
      '测试用户登录-正确凭证',
      '测试用户登录-错误密码',
      '测试用户登录-空用户名',
      '测试用户注册-成功',
      '测试用户注册-重复邮箱',
      '测试密码找回-发送验证码',
      '测试密码找回-验证码错误',
      '测试修改个人信息',
      '测试上传头像',
      '测试创建订单',
    ][i % 10],
    description: `用例描述-${i + 1}`,
    type: ['functional', 'integration', 'regression', 'performance'][i % 4],
    status: ['draft', 'active', 'disabled'][i % 3],
    test_type: ['api', 'ui', 'unit', 'e2e'][i % 4],
    method: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH'][i % 5],
    endpoint: [
      '/api/user/login',
      '/api/user/register',
      '/api/user/info',
      '/api/order/create',
      '/api/order/list',
    ][i % 5],
    headers: { 'Content-Type': 'application/json' },
    params: { page: 1, pageSize: 10 },
    body: { username: 'test', password: '123456' },
    expected_status: [200, 201, 400, 401, 403, 404, 500][i % 7],
    expected_response: { code: 0, msg: 'success' },
    validation_rules: [
      { field: 'code', type: 'equals', expected: 0 },
      { field: 'data.token', type: 'contains', expected: 'token' },
    ],
    module_id: (i % 5) + 1,
    test_suite_id: (i % 3) + 1,
    tags: [['login', 'auth'], ['user', 'register'], ['order', 'create'], ['api']][i % 4],
    related_bug_id: i % 7 === 0 ? i + 100 : null,
    source: ['manual', 'ai_generated', 'imported'][i % 3],
    generated_by_ai: i % 3 === 1,
    ai_prompt: i % 3 === 1 ? '生成登录相关的测试用例' : null,
    run_count: Math.floor(Math.random() * 100),
    pass_count: Math.floor(Math.random() * 80),
    fail_count: Math.floor(Math.random() * 20),
    avg_duration: Math.floor(Math.random() * 5000),
    created_at: recentDate(60),
    updated_at: recentDate(7),
  }));
};

// 生成Bug分析
const generateBugAnalysis = () => {
  return Array.from({ length: 20 }, (_, i) => ({
    id: i + 1,
    title: [
      '登录页面样式错位',
      '提交订单接口返回500错误',
      '用户头像上传失败',
      '分页数据重复',
      '搜索结果排序错误',
      '导出Excel文件损坏',
      '验证码发送频率限制未生效',
      '支付回调处理异常',
      '文件上传大小限制错误',
      '数据库连接池耗尽',
    ][i % 10],
    description: `详细描述-${i + 1}`,
    type: ['functional', 'ui', 'performance', 'security', 'data', 'logic'][i % 6],
    severity: [0, 1, 2, 3, 4][i % 5],
    priority: [0, 1, 2, 3][i % 4],
    issue_location: ['frontend', 'backend', 'database', 'infrastructure', 'third_party'][
      i % 5
    ],
    frontend_issue:
      i % 5 === 0
        ? {
            component: 'LoginForm',
            file_path: '/src/views/login/components/LoginForm.vue',
            line_number: 45,
            error_type: 'TypeError',
            error_message: "Cannot read property 'value' of undefined",
            stack_trace: 'at LoginForm.vue:45\nat handleSubmit.vue:120',
            browser: 'Chrome 120',
            viewport: '1920x1080',
          }
        : null,
    backend_issue:
      i % 5 === 1
        ? {
            api_endpoint: '/api/order/create',
            http_method: 'POST',
            error_code: 'ORDER_CREATE_FAILED',
            error_message: 'Database connection error',
            stack_trace: 'at OrderService.create:56\nat Database.query:120',
            server_log: 'Error: connect ECONNREFUSED',
            database_query: 'INSERT INTO orders (...) VALUES (...)',
          }
        : null,
    reproduction: {
      is_reproducible: i % 3 !== 0,
      reproducibility_rate: Math.random(),
      first_occurrence: recentDate(30),
      last_occurrence: recentDate(1),
      occurrence_count: Math.floor(Math.random() * 100),
    },
    steps: [
      {
        step_number: 1,
        action: '打开登录页面',
        expected: '页面正常加载',
        actual: '页面正常加载',
        screenshot: null,
        timestamp: recentDate(1),
      },
      {
        step_number: 2,
        action: '输入用户名和密码',
        expected: '输入框显示输入内容',
        actual: '输入框显示输入内容',
        screenshot: null,
        timestamp: recentDate(1),
      },
      {
        step_number: 3,
        action: '点击登录按钮',
        expected: '登录成功，跳转首页',
        actual: '页面显示错误信息',
        screenshot: 'error_screenshot.png',
        timestamp: recentDate(1),
      },
    ],
    environment: {
      platform: 'Web',
      os: 'Windows 11',
      browser: 'Chrome 120',
      browser_version: '120.0.6099.130',
      device: 'Desktop',
      screen_resolution: '1920x1080',
      network: 'WiFi',
      location: '中国·北京',
    },
    test_data: { username: 'test@example.com', order_id: 'ORD20240101001' },
    root_cause: '服务器数据库连接池配置过小',
    analysis_report: '通过日志分析和代码审查，发现问题出在数据库连接池配置',
    suggested_fix: '增加数据库连接池最大连接数到50',
    confidence_score: Math.random() * 0.3 + 0.7,
    status: ['pending', 'analyzing', 'analyzed', 'auto_fixing', 'auto_fixed', 'resolved', 'closed'][
      i % 7
    ],
    auto_fix_attempted: i % 7 >= 4,
    auto_fix_result:
      i % 7 >= 4
        ? {
            success: i % 7 === 4 || i % 7 === 5,
            fix_applied: i % 7 === 5,
            fix_code: 'config.maxConnections = 50',
            fix_description: '增加数据库连接池配置',
            files_modified: ['config/database.ts'],
            tests_passed: i % 7 === 5,
          }
        : null,
    test_task_id: (i % 5) + 1,
    test_case_id: (i % 10) + 1,
    feedback_id: i % 4 === 0 ? i + 100 : null,
    ai_model: 'gpt-4-turbo',
    analysis_tokens: Math.floor(Math.random() * 5000),
    created_at: recentDate(30),
  }));
};

// 生成测试执行记录
const generateTestExecutions = () => {
  return Array.from({ length: 20 }, (_, i) => ({
    id: i + 1,
    test_task_id: (i % 5) + 1,
    test_case_id: null,
    name: `执行任务-${i + 1}`,
    type: ['task', 'single_case', 'batch', 'debug'][i % 4],
    status: ['pending', 'running', 'completed', 'failed', 'terminated'][i % 5],
    progress: [0, 30, 60, 100][i % 4],
    triggered_by: 1,
    trigger_type: ['manual', 'scheduled', 'webhook', 'ci_cd', 'ai_auto'][i % 5],
    trigger_params: null,
    environment: {
      platform: 'Web',
      os: 'Windows 11',
      browser: 'Chrome 120',
      browser_version: '120.0.6099.130',
      device: 'Desktop',
      screen_resolution: '1920x1080',
      network: 'WiFi',
      location: '中国·北京',
    },
    iteration: i % 3 === 0 ? 1 : null,
    total_cases: Math.floor(Math.random() * 100) + 10,
    passed_cases: Math.floor(Math.random() * 80) + 10,
    failed_cases: Math.floor(Math.random() * 10),
    skipped_cases: Math.floor(Math.random() * 5),
    duration: Math.floor(Math.random() * 60000),
    results: null,
    summary: {
      total: Math.floor(Math.random() * 100) + 10,
      passed: Math.floor(Math.random() * 80) + 10,
      failed: Math.floor(Math.random() * 10),
      skipped: Math.floor(Math.random() * 5),
      pass_rate: Math.floor(Math.random() * 30 + 70),
      avg_duration: Math.floor(Math.random() * 5000),
    },
    logs: [
      {
        id: 1,
        timestamp: recentDate(1),
        level: 'info',
        source: 'test-runner',
        message: '测试开始执行',
        data: { task_id: (i % 5) + 1 },
      },
      {
        id: 2,
        timestamp: recentDate(1),
        level: 'debug',
        source: 'test-runner',
        message: '加载测试用例',
        data: { count: 50 },
      },
    ],
    created_at: recentDate(14),
    started_at: recentDate(7),
    completed_at: recentDate(7),
  }));
};

// 生成测试报告
const generateTestReports = () => {
  return Array.from({ length: 10 }, (_, i) => ({
    id: i + 1,
    name: `测试报告-${i + 1}`,
    type: ['execution', 'trend', 'quality', 'coverage'][i % 4],
    format: ['html', 'pdf', 'json', 'excel'][i % 4],
    test_task_id: (i % 5) + 1,
    test_execution_id: (i % 5) + 1,
    test_suite_id: (i % 3) + 1,
    summary: {
      total_cases: Math.floor(Math.random() * 100) + 20,
      passed: Math.floor(Math.random() * 80) + 10,
      failed: Math.floor(Math.random() * 10),
      skipped: Math.floor(Math.random() * 5),
      pass_rate: Math.floor(Math.random() * 30 + 70),
      avg_duration: Math.floor(Math.random() * 5000),
      start_time: recentDate(7),
      end_time: recentDate(7),
    },
    charts: [
      {
        type: 'pie',
        title: '通过率分布',
        data: { passed: 80, failed: 15, skipped: 5 },
      },
    ],
    details: [],
    recommendations: ['建议增加边界值测试', '建议优化接口响应时间'],
    quality_metrics: {
      code_coverage: Math.floor(Math.random() * 30 + 70),
      new_bugs_found: Math.floor(Math.random() * 5),
      regression_bugs: Math.floor(Math.random() * 3),
      performance_issues: Math.floor(Math.random() * 2),
      security_issues: 0,
    },
    generated_by: 1,
    generated_at: recentDate(7),
    file_path: `/reports/test-report-${i + 1}.pdf`,
    file_size: Math.floor(Math.random() * 1024 * 1024),
  }));
};

// 测试任务列表
const testTaskList = generateTestTasks();

// 测试用例列表
const testCaseList = generateTestCases();

// Bug分析列表
const bugAnalysisList = generateBugAnalysis();

// 测试执行列表
const testExecutionList = generateTestExecutions();

// 测试报告列表
const testReportList = generateTestReports();

// 测试套件列表
const testSuiteList = [
  { id: 1, name: '用户管理套件', description: '用户相关测试', case_count: 15, created_at: recentDate(60) },
  { id: 2, name: '订单管理套件', description: '订单相关测试', case_count: 20, created_at: recentDate(60) },
  { id: 3, name: '支付功能套件', description: '支付相关测试', case_count: 10, created_at: recentDate(60) },
];

// Mock 数据配置
const autoTestMock = [
  // ========== 测试任务 ==========
  {
    url: /\/api\/auto-test\/task\/list/,
    method: 'get',
    response: ({ query }: any) => {
      const { page = 1, pageSize = 10, keyword, type, status } = query || {};
      let list = [...testTaskList];
      
      if (keyword) {
        list = list.filter(t => t.name.includes(keyword));
      }
      if (type) {
        list = list.filter(t => t.type === type);
      }
      if (status) {
        list = list.filter(t => t.status === status);
      }
      
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      
      return pageSuccess(list.slice(start, end), list.length);
    },
  },
  {
    url: /\/api\/auto-test\/task\/detail/,
    method: 'get',
    response: ({ query }: any) => {
      const task = testTaskList.find(t => t.id === Number(query?.id));
      return success(task || testTaskList[0]);
    },
  },
  {
    url: /\/api\/auto-test\/task\/create/,
    method: 'post',
    response: ({ body }: any) => {
      const newTask = {
        id: testTaskList.length + 1,
        ...body,
        status: 'pending',
        total_runs: 0,
        success_count: 0,
        fail_count: 0,
        created_at: new Date().toISOString(),
      };
      testTaskList.push(newTask);
      return success(newTask);
    },
  },
  {
    url: /\/api\/auto-test\/task\/update/,
    method: 'post',
    response: ({ body }: any) => {
      const index = testTaskList.findIndex(t => t.id === body.id);
      if (index >= 0) {
        testTaskList[index] = { ...testTaskList[index], ...body };
        return success(testTaskList[index]);
      }
      return success(null, '任务不存在');
    },
  },
  {
    url: /\/api\/auto-test\/task\/delete/,
    method: 'delete',
    response: ({ query }: any) => {
      return success(null, '删除成功');
    },
  },
  {
    url: /\/api\/auto-test\/task\/execute/,
    method: 'post',
    response: () => {
      const execution = {
        id: testExecutionList.length + 1,
        test_task_id: 1,
        name: '手动执行',
        type: 'task',
        status: 'running',
        progress: 0,
        triggered_by: 1,
        trigger_type: 'manual',
        environment: { platform: 'Web', os: 'Windows 11' },
        total_cases: 0,
        passed_cases: 0,
        failed_cases: 0,
        skipped_cases: 0,
        logs: [],
        created_at: new Date().toISOString(),
      };
      testExecutionList.push(execution);
      return success(execution);
    },
  },

  // ========== 测试用例 ==========
  {
    url: /\/api\/auto-test\/case\/list/,
    method: 'get',
    response: ({ query }: any) => {
      const { page = 1, pageSize = 10, keyword, status, test_type } = query || {};
      let list = [...testCaseList];
      
      if (keyword) {
        list = list.filter(c => c.name.includes(keyword));
      }
      if (status) {
        list = list.filter(c => c.status === status);
      }
      if (test_type) {
        list = list.filter(c => c.test_type === test_type);
      }
      
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      
      return pageSuccess(list.slice(start, end), list.length);
    },
  },
  {
    url: /\/api\/auto-test\/case\/detail/,
    method: 'get',
    response: ({ query }: any) => {
      const testCase = testCaseList.find(c => c.id === Number(query?.id));
      return success(testCase || testCaseList[0]);
    },
  },
  {
    url: /\/api\/auto-test\/case\/create/,
    method: 'post',
    response: ({ body }: any) => {
      const newCase = {
        id: testCaseList.length + 1,
        ...body,
        status: 'draft',
        run_count: 0,
        pass_count: 0,
        fail_count: 0,
        created_at: new Date().toISOString(),
      };
      testCaseList.push(newCase);
      return success(newCase);
    },
  },
  {
    url: /\/api\/auto-test\/case\/batch-create/,
    method: 'post',
    response: ({ body }: any) => {
      const newCases = body.cases.map((c: any, i: number) => ({
        id: testCaseList.length + i + 1,
        ...c,
        status: 'draft',
        run_count: 0,
        pass_count: 0,
        fail_count: 0,
        created_at: new Date().toISOString(),
      }));
      testCaseList.push(...newCases);
      return success(newCases);
    },
  },
  {
    url: /\/api\/auto-test\/case\/run/,
    method: 'post',
    response: () => {
      const result = {
        test_case_id: 1,
        test_case_name: '测试用例',
        status: ['passed', 'failed', 'skipped'][Math.floor(Math.random() * 3)],
        duration: Math.floor(Math.random() * 5000),
        error_message: null,
      };
      return success(result);
    },
  },
  {
    url: /\/api\/auto-test\/case\/delete/,
    method: 'delete',
    response: () => success(null, '删除成功'),
  },

  // ========== 测试套件 ==========
  {
    url: /\/api\/auto-test\/suite\/list/,
    method: 'get',
    response: () => success({ list: testSuiteList, total: testSuiteList.length }),
  },
  {
    url: /\/api\/auto-test\/suite\/detail/,
    method: 'get',
    response: ({ query }: any) => {
      const suite = testSuiteList.find(s => s.id === Number(query?.id));
      return success({
        ...suite,
        cases: testCaseList.slice(0, 5),
      });
    },
  },

  // ========== Bug分析 ==========
  {
    url: /\/api\/auto-test\/bug\/list/,
    method: 'get',
    response: ({ query }: any) => {
      const { page = 1, pageSize = 10, keyword, type, status } = query || {};
      let list = [...bugAnalysisList];
      
      if (keyword) {
        list = list.filter(b => b.title.includes(keyword));
      }
      if (type) {
        list = list.filter(b => b.type === type);
      }
      if (status) {
        list = list.filter(b => b.status === status);
      }
      
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      
      return pageSuccess(list.slice(start, end), list.length);
    },
  },
  {
    url: /\/api\/auto-test\/bug\/detail/,
    method: 'get',
    response: ({ query }: any) => {
      const bug = bugAnalysisList.find(b => b.id === Number(query?.id));
      return success(bug || bugAnalysisList[0]);
    },
  },
  {
    url: /\/api\/auto-test\/bug\/analyze/,
    method: 'post',
    response: ({ body }: any) => {
      const newBug = {
        id: bugAnalysisList.length + 1,
        ...body,
        type: 'functional',
        severity: 2,
        priority: 2,
        issue_location: 'backend',
        status: 'analyzed',
        confidence_score: 0.85,
        created_at: new Date().toISOString(),
      };
      bugAnalysisList.push(newBug);
      return success({
        bug_analysis: newBug,
        processing_time: Math.floor(Math.random() * 5000),
        tokens_used: Math.floor(Math.random() * 3000),
      });
    },
  },
  {
    url: /\/api\/auto-test\/bug\/auto-fix/,
    method: 'post',
    response: ({ body }: any) => {
      const bug = bugAnalysisList.find(b => b.id === body.bug_analysis_id);
      return success({
        success: true,
        bug_analysis: { ...bug, status: 'auto_fixed' },
        fix_result: {
          success: true,
          fix_applied: true,
          fix_code: '// 修复代码',
          fix_description: '已应用修复',
          files_modified: ['src/service/UserService.ts'],
          tests_passed: true,
        },
        verification_passed: true,
        processing_time: Math.floor(Math.random() * 10000),
      });
    },
  },
  {
    url: /\/api\/auto-test\/bug\/update-status/,
    method: 'post',
    response: ({ body }: any) => {
      return success(null, '状态更新成功');
    },
  },
  {
    url: /\/api\/auto-test\/bug\/create-feedback/,
    method: 'post',
    response: () => {
      return success({ feedback_id: Math.floor(Math.random() * 10000) + 1000 });
    },
  },

  // ========== 测试执行 ==========
  {
    url: /\/api\/auto-test\/execution\/list/,
    method: 'get',
    response: ({ query }: any) => {
      const { page = 1, pageSize = 10 } = query || {};
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      return pageSuccess(testExecutionList.slice(start, end), testExecutionList.length);
    },
  },
  {
    url: /\/api\/auto-test\/execution\/detail/,
    method: 'get',
    response: ({ query }: any) => {
      const execution = testExecutionList.find(e => e.id === Number(query?.id));
      return success(execution || testExecutionList[0]);
    },
  },
  {
    url: /\/api\/auto-test\/execution\/\\d+\/logs/,
    method: 'get',
    response: ({ query }: any) => {
      return success({
        logs: testExecutionList[0]?.logs || [],
        next_cursor: null,
      });
    },
  },

  // ========== 测试报告 ==========
  {
    url: /\/api\/auto-test\/report\/list/,
    method: 'get',
    response: ({ query }: any) => {
      const { page = 1, pageSize = 10 } = query || {};
      const start = (page - 1) * pageSize;
      const end = start + pageSize;
      return pageSuccess(testReportList.slice(start, end), testReportList.length);
    },
  },
  {
    url: /\/api\/auto-test\/report\/detail/,
    method: 'get',
    response: ({ query }: any) => {
      const report = testReportList.find(r => r.id === Number(query?.id));
      return success(report || testReportList[0]);
    },
  },
  {
    url: /\/api\/auto-test\/report\/generate/,
    method: 'post',
    response: ({ body }: any) => {
      const newReport = {
        id: testReportList.length + 1,
        ...body,
        summary: {
          total_cases: Math.floor(Math.random() * 100) + 20,
          passed: Math.floor(Math.random() * 80) + 10,
          failed: Math.floor(Math.random() * 10),
          skipped: Math.floor(Math.random() * 5),
          pass_rate: Math.floor(Math.random() * 30 + 70),
          avg_duration: Math.floor(Math.random() * 5000),
          start_time: recentDate(7),
          end_time: recentDate(7),
        },
        generated_by: 1,
        generated_at: new Date().toISOString(),
      };
      testReportList.push(newReport);
      return success(newReport);
    },
  },
  {
    url: /\/api\/auto-test\/report\/trend/,
    method: 'get',
    response: () => {
      return success({
        trend_data: Array.from({ length: 30 }, (_, i) => ({
          date: new Date(Date.now() - (29 - i) * 24 * 60 * 60 * 1000).toISOString().slice(0, 10),
          value: Math.floor(Math.random() * 30) + 70,
        })),
        summary: {
          total: 100,
          avg: 85,
          max: 98,
          min: 72,
        },
      });
    },
  },

  // ========== AI Agent 接口 ==========
  {
    url: /\/api\/auto-test\/ai\/execute-task/,
    method: 'post',
    response: ({ body }: any) => {
      return success({
        execution_id: Math.floor(Math.random() * 1000) + 100,
        status: 'running',
      });
    },
  },
  {
    url: /\/api\/auto-test\/ai\/generate-cases/,
    method: 'post',
    response: ({ body }: any) => {
      const count = body.count || 5;
      const cases = Array.from({ length: count }, (_, i) => ({
        id: testCaseList.length + i + 1,
        name: `AI生成用例-${i + 1}`,
        description: body.target,
        type: 'functional',
        status: 'active',
        test_type: body.type || 'api',
        method: 'POST',
        endpoint: body.target,
        expected_status: 200,
        source: 'ai_generated',
        generated_by_ai: true,
        ai_prompt: body.target,
        run_count: 0,
        pass_count: 0,
        fail_count: 0,
        created_at: new Date().toISOString(),
      }));
      return success({
        test_cases: cases,
        generation_time: Math.floor(Math.random() * 5000),
        tokens_used: Math.floor(Math.random() * 3000),
        coverage_improvement: Math.random() * 5,
      });
    },
  },
  {
    url: /\/api\/auto-test\/ai\/analyze-bug/,
    method: 'post',
    response: ({ body }: any) => {
      return success({
        bug_analysis: {
          id: bugAnalysisList.length + 1,
          title: body.title,
          description: body.description,
          type: 'functional',
          severity: 2,
          priority: 2,
          issue_location: 'backend',
          status: 'analyzed',
          confidence_score: 0.85,
          root_cause: 'AI分析得出的根本原因',
          analysis_report: 'AI分析报告详情',
          suggested_fix: '建议的修复方案',
          created_at: new Date().toISOString(),
        },
        processing_time: Math.floor(Math.random() * 5000),
        tokens_used: Math.floor(Math.random() * 3000),
      });
    },
  },
  {
    url: /\/api\/auto-test\/ai\/auto-fix/,
    method: 'post',
    response: ({ body }: any) => {
      return success({
        success: true,
        bug_analysis: {
          ...bugAnalysisList[0],
          status: 'auto_fixed',
        },
        fix_result: {
          success: true,
          fix_applied: true,
          fix_code: '// AI生成的修复代码',
          fix_description: '自动修复完成',
          files_modified: ['src/handler/UserHandler.ts'],
          tests_passed: true,
        },
        verification_passed: true,
        processing_time: Math.floor(Math.random() * 10000),
      });
    },
  },
  {
    url: /\/api\/auto-test\/ai\/verify-fix/,
    method: 'post',
    response: () => {
      return success({
        passed: Math.random() > 0.3,
        details: '修复验证详情',
      });
    },
  },
  {
    url: /\/api\/auto-test\/ai\/health-check/,
    method: 'get',
    response: () => {
      return success({
        status: 'healthy',
        latency_ms: Math.floor(Math.random() * 500),
        queue_size: Math.floor(Math.random() * 10),
      });
    },
  },

  // ========== 模块管理 ==========
  {
    url: /\/api\/auto-test\/module\/list/,
    method: 'get',
    response: () => {
      return success({
        list: [
          { id: 1, name: '用户模块', parent_id: null },
          { id: 2, name: '订单模块', parent_id: null },
          { id: 3, name: '支付模块', parent_id: null },
          { id: 4, name: '报表模块', parent_id: null },
        ],
      });
    },
  },
  {
    url: /\/api\/auto-test\/module\/create/,
    method: 'post',
    response: ({ body }: any) => {
      return success({ id: Math.floor(Math.random() * 1000) + 100 });
    },
  },
];

export default autoTestMock;
