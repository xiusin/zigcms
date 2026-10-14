# 自动化测试系统架构规划文档

## 一、系统概述

### 1.1 设计目标

本自动化测试系统是一个**商业化、可复用、闭环**的智能测试平台，旨在通过AI能力实现：

- **自动化测试执行**：AI自动完成测试用例执行和结果验证
- **智能Bug管理**：自动识别、分类、复现和修复Bug
- **测试用例生成**：根据代码变更自动生成测试用例
- **全程日志追踪**：记录所有执行步骤，支持问题回溯

### 1.2 核心特性

| 特性 | 描述 |
|------|------|
| AI驱动测试 | 提供API接口，AI Agent可自动执行测试任务 |
| Bug智能分析 | 自动识别Bug类型、前端/后端问题、复现步骤 |
| 自动修复 | AI尝试自动修复问题，并标记修复状态 |
| 用例自动生成 | 根据代码变更自动生成测试用例 |
| 完整日志 | 记录所有执行步骤，支持审计和回溯 |
| 与Feedback集成 | 与现有Feedback系统深度集成 |

---

## 二、系统架构

### 2.1 整体架构图

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    前端层 (Vue 3 + Arco Design)                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 测试任务列表  │  │ 测试执行器  │  │ Bug管理    │  │ 测试报告    │  │ 系统设置   │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    API 层                                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 测试任务API │  │ 测试用例API │  │ Bug管理API │  │ 测试执行API │  │ 报告生成API │  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    业务层 (Application Services)                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 测试任务服务 │  │ 用例生成服务 │  │ Bug分析服务 │  │ 自动修复服务│  │ 报告生成服务│  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    领域层 (Domain)                                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  │
│  │ 测试任务实体 │  │ 测试用例实体 │  │ Bug实体    │  │ 测试结果实体│  │ 执行日志实体│  │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘  │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                                      │
│  │ 测试计划实体│  │ 测试套件实体│  │ 报告实体   │                                      │
│  └─────────────┘  └─────────────┘  └─────────────┘                                      │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                                    基础设施层 (Infrastructure)                           │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                   │
│  │ 数据库仓储  │  │ 消息队列    │  │ AI Agent    │  │ Webhook     │                   │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘                   │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

### 2.2 与现有系统集成

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              现有 Feedback 系统 (扩展)                                 │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 反馈类型扩展: 增加 "自动化测试" 类型                                              │  │
│  │ 状态扩展: 增加 "AI分析中" -> "自动修复中" -> "修复验证中" -> "已自动修复"          │  │
│  │ 字段扩展: 增加 test_task_id, test_case_id, bug_analysis 等字段                    │  │
│  └─────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              自动化测试系统 (新建)                                      │
│  ┌─────────────────────────────────────────────────────────────────────────────────┐  │
│  │ 独立模块: 测试任务、用例管理、Bug分析、执行引擎、报告中心                          │  │
│  │ API接口: 供 AI Agent 调用                                                         │  │
│  │ 事件驱动: 与Feedback、代码仓库、CI/CD 集成                                         │  │
│  └─────────────────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 三、核心数据模型

### 3.1 测试任务 (TestTask)

```typescript
interface TestTask {
  id: number;
  name: string;                          // 任务名称
  description: string;                  // 任务描述
  type: TestTaskType;                   // 任务类型
  status: TestTaskStatus;               // 任务状态
  priority: TaskPriority;              // 优先级
  
  // 执行配置
  trigger_type: TriggerType;           // 触发类型
  schedule?: string;                   // 定时配置 (cron)
  webhook_url?: string;                 // Webhook回调地址
  
  // 关联
  test_suite_id?: number;               // 关联测试套件
  related_feedback_id?: number;         // 关联反馈ID
  created_by: number;                   // 创建者
  assigned_to?: number;                 // 指派AI Agent
  
  // 执行统计
  total_runs: number;                   // 总执行次数
  success_count: number;                // 成功次数
  fail_count: number;                   // 失败次数
  last_run_at?: string;                 // 最后执行时间
  last_run_result?: TestResult;        // 最后执行结果
  
  // 时间戳
  created_at: string;
  updated_at?: string;
  started_at?: string;                  // 开始执行时间
  completed_at?: string;                 // 完成时间
}

enum TestTaskType {
  FUNCTIONAL = 'functional',            // 功能测试
  INTEGRATION = 'integration',         // 集成测试
  REGRESSION = 'regression',           // 回归测试
  PERFORMANCE = 'performance',         // 性能测试
  SECURITY = 'security',               // 安全测试
  AI_GENERATED = 'ai_generated',        // AI生成测试
}

enum TestTaskStatus {
  PENDING = 'pending',                  // 待执行
  QUEUED = 'queued',                   // 排队中
  RUNNING = 'running',                  // 执行中
  COMPLETED = 'completed',              // 已完成
  FAILED = 'failed',                   // 失败
  CANCELLED = 'cancelled',             // 已取消
  PAUSED = 'paused',                   // 已暂停
}

enum TriggerType {
  MANUAL = 'manual',                   // 手动触发
  SCHEDULED = 'scheduled',              // 定时触发
  WEBHOOK = 'webhook',                 // Webhook触发
  CI_CD = 'ci_cd',                     // CI/CD触发
  AI_AUTO = 'ai_auto',                 // AI自动触发
}
```

### 3.2 测试用例 (TestCase)

```typescript
interface TestCase {
  id: number;
  name: string;                        // 用例名称
  description: string;                // 用例描述
  type: TestCaseType;                  // 用例类型
  status: TestCaseStatus;              // 用例状态
  
  // 测试内容
  test_type: 'api' | 'ui' | 'unit' | 'e2e';
  method: 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';
  endpoint: string;                   // API端点
  headers?: Record<string, string>;    // 请求头
  params?: Record<string, any>;        // URL参数
  body?: any;                          // 请求体
  expected_status: number;            // 期望状态码
  expected_response?: any;            // 期望响应
  validation_rules?: ValidationRule[]; // 验证规则
  
  // 关联
  module_id?: number;                  // 所属模块
  test_suite_id?: number;             // 所属测试套件
  tags?: string[];                     // 标签
  related_bug_id?: number;            // 关联Bug
  
  // 来源
  source: TestCaseSource;              // 用例来源
  generated_by_ai?: boolean;          // 是否AI生成
  ai_prompt?: string;                  // AI生成时的提示词
  
  // 统计
  run_count: number;                   // 执行次数
  pass_count: number;                  // 通过次数
  fail_count: number;                  // 失败次数
  avg_duration?: number;               // 平均执行时长(ms)
  
  // 时间戳
  created_at: string;
  updated_at?: string;
}

enum TestCaseSource {
  MANUAL = 'manual',                   // 手动创建
  AI_GENERATED = 'ai_generated',       // AI自动生成
  IMPORTED = 'imported',               // 导入
  RECORDED = 'recorded',               // 录制
  CONVERTED = 'converted',             // 转换
}

interface ValidationRule {
  field: string;                       // 验证字段
  type: 'equals' | 'contains' | 'regex' | 'schema' | 'custom';
  expected: any;                       // 期望值
  message?: string;                   // 失败消息
}
```

### 3.3 Bug分析 (BugAnalysis)

```typescript
interface BugAnalysis {
  id: number;
  
  // Bug基本信息
  title: string;                       // Bug标题
  description: string;                 // Bug描述
  type: BugType;                      // Bug类型
  severity: BugSeverity;               // 严重程度
  priority: BugPriority;              // 优先级
  
  // 问题定位
  issue_location: IssueLocation;      // 问题定位
  frontend_issue?: FrontendIssue;      // 前端问题详情
  backend_issue?: BackendIssue;        // 后端问题详情
  
  // 复现信息
  reproduction: ReproductionInfo;      // 复现信息
  steps: ReproductionStep[];           // 复现步骤
  environment: TestEnvironment;        // 测试环境
  test_data?: any;                     // 测试数据
  
  // 分析结果
  root_cause?: string;                 // 根本原因
  analysis_report?: string;            // 分析报告
  suggested_fix?: string;              // 建议修复方案
  confidence_score?: number;           // 分析置信度 (0-1)
  
  // 处理状态
  status: BugAnalysisStatus;
  auto_fix_attempted: boolean;         // 是否尝试自动修复
  auto_fix_result?: AutoFixResult;     // 自动修复结果
  
  // 关联
  test_task_id?: number;              // 关联测试任务
  test_case_id?: number;              // 关联测试用例
  feedback_id?: number;               // 关联反馈
  
  // AI分析元数据
  ai_model?: string;                   // 使用的AI模型
  analysis_tokens?: number;            // 分析消耗的token
  created_at: string;
}

enum BugType {
  FUNCTIONAL = 'functional',           // 功能错误
  UI = 'ui',                          // 界面问题
  PERFORMANCE = 'performance',        // 性能问题
  SECURITY = 'security',              // 安全问题
  DATA = 'data',                      // 数据问题
  COMPATIBILITY = 'compatibility',    // 兼容性问题
  LOGIC = 'logic',                    // 逻辑错误
  CONFIGURATION = 'configuration',    // 配置错误
  NETWORK = 'network',                // 网络问题
  UNKNOWN = 'unknown',                // 未知问题
}

enum IssueLocation {
  FRONTEND = 'frontend',              // 前端问题
  BACKEND = 'backend',                // 后端问题
  DATABASE = 'database',              // 数据库问题
  INFRASTRUCTURE = 'infrastructure',  // 基础设施问题
  THIRD_PARTY = 'third_party',       // 第三方服务问题
  UNKNOWN = 'unknown',                // 未知
}

interface FrontendIssue {
  component?: string;                  // 组件名称
  file_path?: string;                  // 文件路径
  line_number?: number;                 // 行号
  error_type?: string;                 // 错误类型
  error_message?: string;              // 错误信息
  stack_trace?: string;                // 堆栈跟踪
  browser?: string;                    // 浏览器
  viewport?: string;                   // 视口大小
}

interface BackendIssue {
  api_endpoint?: string;              // API端点
  http_method?: string;                // HTTP方法
  error_code?: string;                 // 错误代码
  error_message?: string;              // 错误信息
  stack_trace?: string;                // 堆栈跟踪
  server_log?: string;                // 服务器日志
  database_query?: string;             // 涉及的数据库查询
}

interface ReproductionStep {
  step_number: number;
  action: string;                      // 操作描述
  expected: string;                    // 预期结果
  actual: string;                      // 实际结果
  screenshot?: string;                 // 截图
  timestamp?: string;                  // 时间戳
}

interface TestEnvironment {
  platform: string;                    // 平台
  os?: string;                         // 操作系统
  browser?: string;                    // 浏览器
  browser_version?: string;            // 浏览器版本
  device?: string;                     // 设备
  screen_resolution?: string;          // 屏幕分辨率
  network?: string;                    // 网络环境
  location?: string;                   // 地理位置
}

enum BugAnalysisStatus {
  PENDING = 'pending',                // 待分析
  ANALYZING = 'analyzing',            // 分析中
  ANALYZED = 'analyzed',              // 已分析
  AUTO_FIXING = 'auto_fixing',        // 自动修复中
  AUTO_FIXED = 'auto_fixed',          // 已自动修复
  VERIFICATION = 'verification',      // 验证中
  RESOLVED = 'resolved',              // 已解决
  REOPENED = 'reopened',              // 已重新打开
  CLOSED = 'closed',                  // 已关闭
  FAILED = 'failed',                  // 分析/修复失败
}

interface AutoFixResult {
  success: boolean;                    // 是否成功
  fix_applied?: boolean;              // 是否应用了修复
  fix_code?: string;                  // 修复代码
  fix_description?: string;           // 修复描述
  files_modified?: string[];          // 修改的文件
  tests_passed?: boolean;             // 修复后测试是否通过
  error?: string;                     // 错误信息
}
```

### 3.4 测试执行记录 (TestExecution)

```typescript
interface TestExecution {
  id: number;
  
  // 执行基本信息
  test_task_id: number;               // 关联测试任务
  test_case_id?: number;              // 关联测试用例
  name: string;                       // 执行名称
  type: ExecutionType;                // 执行类型
  
  // 执行状态
  status: ExecutionStatus;            // 执行状态
  progress: number;                   // 执行进度 (0-100)
  
  // 执行上下文
  triggered_by: number;               // 触发者 (用户ID/AI Agent ID)
  trigger_type: TriggerType;          // 触发类型
  trigger_params?: any;              // 触发参数
  
  // 环境配置
  environment: TestEnvironment;      // 测试环境
  iteration?: number;                 // 迭代次数
  
  // 结果统计
  total_cases: number;                // 总用例数
  passed_cases: number;              // 通过数
  failed_cases: number;              // 失败数
  skipped_cases: number;              // 跳过数
  duration?: number;                  // 执行时长(ms)
  
  // 详细结果
  results?: TestCaseResult[];         // 各用例执行结果
  summary?: ExecutionSummary;         // 执行摘要
  artifacts?: ExecutionArtifact[];    // 执行产物 (截图/日志等)
  
  // 日志
  logs: ExecutionLog[];              // 执行日志
  
  // 时间戳
  created_at: string;
  started_at?: string;                 // 开始时间
  completed_at?: string;               // 完成时间
}

interface TestCaseResult {
  test_case_id: number;
  test_case_name: string;
  status: 'passed' | 'failed' | 'skipped' | 'error';
  duration: number;                    // 执行时长
  error_message?: string;             // 错误信息
  stack_trace?: string;               // 堆栈跟踪
  screenshot?: string;                // 失败截图
  request?: any;                      // 请求详情
  response?: any;                     // 响应详情
}

interface ExecutionLog {
  id: number;
  timestamp: string;                   // 日志时间
  level: 'debug' | 'info' | 'warn' | 'error';
  source: string;                      // 日志来源
  message: string;                     // 日志消息
  data?: any;                         // 附加数据
  step?: string;                      // 执行步骤
}

interface ExecutionArtifact {
  type: 'screenshot' | 'video' | 'log' | 'report' | 'trace';
  name: string;                       // 文件名称
  path: string;                       // 文件路径
  size?: number;                      // 文件大小
  url?: string;                       // 访问URL
}
```

### 3.5 测试报告 (TestReport)

```typescript
interface TestReport {
  id: number;
  
  // 报告基本信息
  name: string;                       // 报告名称
  type: ReportType;                   // 报告类型
  format: ReportFormat;               // 报告格式
  
  // 关联
  test_task_id?: number;              // 关联测试任务
  test_execution_id?: number;         // 关联执行记录
  test_suite_id?: number;             // 关联测试套件
  
  // 报告内容
  summary: ReportSummary;             // 摘要统计
  charts?: ReportChart[];             // 图表数据
  details?: ReportDetail[];            // 详细数据
  recommendations?: string[];          // 建议
  
  // 质量指标
  quality_metrics?: QualityMetrics;   // 质量指标
  
  // 附加信息
  generated_by: number;               // 生成者
  generated_at: string;               // 生成时间
  
  // 文件
  file_path?: string;                  // 文件路径
  file_size?: number;                 // 文件大小
}

interface ReportSummary {
  total_cases: number;
  passed: number;
  failed: number;
  skipped: number;
  pass_rate: number;                  // 通过率
  avg_duration: number;               // 平均执行时长
  start_time: string;
  end_time: string;
}

interface QualityMetrics {
  code_coverage?: number;             // 代码覆盖率
  new_bugs_found: number;              // 发现的新Bug数
  regression_bugs: number;            // 回归Bug数
  performance_issues: number;         // 性能问题数
  security_issues: number;            // 安全问题数
}
```

---

## 四、API接口设计

### 4.1 测试任务管理 API

| 接口 | 方法 | 描述 |
|------|------|------|
| `/api/auto-test/task/list` | GET | 获取测试任务列表 |
| `/api/auto-test/task/detail` | GET | 获取任务详情 |
| `/api/auto-test/task/create` | POST | 创建测试任务 |
| `/api/auto-test/task/update` | POST | 更新测试任务 |
| `/api/auto-test/task/delete` | DELETE | 删除测试任务 |
| `/api/auto-test/task/execute` | POST | 执行测试任务 |
| `/api/auto-test/task/stop` | POST | 停止执行 |
| `/api/auto-test/task/clone` | POST | 克隆任务 |

### 4.2 测试用例管理 API

| 接口 | 方法 | 描述 |
|------|------|------|
| `/api/auto-test/case/list` | GET | 获取测试用例列表 |
| `/api/auto-test/case/detail` | GET | 获取用例详情 |
| `/api/auto-test/case/create` | POST | 创建测试用例 |
| `/api/auto-test/case/batch-create` | POST | 批量创建用例 |
| `/api/auto-test/case/update` | POST | 更新测试用例 |
| `/api/auto-test/case/delete` | DELETE | 删除测试用例 |
| `/api/auto-test/case/run` | POST | 运行单个用例 |
| `/api/auto-test/case/generate` | POST | AI生成测试用例 |

### 4.3 Bug分析 API (核心AI接口)

| 接口 | Method | 描述 |
|------|--------|------|
| `/api/auto-test/bug/analyze` | POST | AI分析Bug |
| `/api/auto-test/bug/list` | GET | 获取Bug分析列表 |
| `/api/auto-test/bug/detail` | GET | 获取Bug详情 |
| `/api/auto-test/bug/auto-fix` | POST | AI自动修复Bug |
| `/api/auto-test/bug/verify-fix` | POST | 验证修复结果 |
| `/api/auto-test/bug/update-status` | POST | 更新Bug状态 |
| `/api/auto-test/bug/create-feedback` | POST | 同步到Feedback系统 |

### 4.4 测试执行 API

| 接口 | Method | 描述 |
|------|--------|------|
| `/api/auto-test/execution/list` | GET | 获取执行记录列表 |
| `/api/auto-test/execution/detail` | GET | 获取执行详情 |
| `/api/auto-test/execution/start` | POST | 开始执行 |
| `/api/auto-test/execution/stop` | POST | 停止执行 |
| `/api/auto-test/execution/logs` | GET | 获取执行日志 (流式) |
| `/api/auto-test/execution/results` | GET | 获取执行结果 |

### 4.5 测试报告 API

| 接口 | Method | 描述 |
|------|--------|------|
| `/api/auto-test/report/list` | GET | 获取报告列表 |
| `/api/auto-test/report/detail` | GET | 获取报告详情 |
| `/api/auto-test/report/generate` | POST | 生成报告 |
| `/api/auto-test/report/download` | GET | 下载报告 |
| `/api/auto-test/report/trend` | GET | 获取趋势数据 |

### 4.6 AI Agent 接口 (核心)

| 接口 | Method | 描述 |
|------|--------|------|
| `/api/auto-test/ai/execute-task` | POST | AI执行测试任务 |
| `/api/auto-test/ai/generate-cases` | POST | AI生成测试用例 |
| `/api/auto-test/ai/analyze-bug` | POST | AI分析Bug |
| `/api/auto-test/ai/auto-fix` | POST | AI自动修复 |
| `/api/auto-test/ai/verify-fix` | POST | AI验证修复 |
| `/api/auto-test/ai/health-check` | GET | AI服务健康检查 |

---

## 五、核心业务流

### 5.1 AI自动测试执行流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              AI自动测试执行流程                                          │
└─────────────────────────────────────────────────────────────────────────────────────────┘

1. 触发条件
   ├─ 定时任务触发 (Cron)
   ├─ Webhook触发 (代码提交/PR创建)
   ├─ 手动触发 (管理员点击执行)
   └─ AI Agent触发 (外部AI调用API)

2. 任务初始化
   ├─ 创建执行记录 (TestExecution)
   ├─ 初始化执行上下文
   ├─ 准备测试环境
   └─ 通知AI Agent开始执行

3. 测试执行循环
   ├─ For each 测试用例:
   │   ├─ 准备测试数据
   │   ├─ 执行API请求 / UI操作
   │   ├─ 收集响应/结果
   │   ├─ 验证结果 (断言)
   │   ├─ 记录详细日志
   │   ├─ 捕获截图/错误信息 (如失败)
   │   └─ 更新用例执行结果
   │
   └─ 收集所有结果

4. 结果处理
   ├─ 生成执行摘要
   ├─ 统计通过/失败/跳过数
   ├─ 计算质量指标
   ├─ 生成详细报告
   └─ 触发后续动作:
       ├─ 发送通知 (邮件/Slack/钉钉)
       ├─ 创建Bug (如发现新Bug)
       └─ 更新相关任务状态

5. 执行完成
   ├─ 清理测试环境
   ├─ 归档执行记录
   ├─ 更新任务统计
   └─ 回调Webhook (如配置)
```

### 5.2 Bug智能分析流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              Bug智能分析流程                                             │
└─────────────────────────────────────────────────────────────────────────────────────────┘

1. 输入
   ├─ 测试失败记录
   ├─ 错误信息/堆栈跟踪
   ├─ 截图/录屏
   ├─ 环境信息
   └─ 相关日志

2. AI分析阶段
   ├─ 初步分类:
   │   ├─ 问题类型 (功能/UI/性能/安全/数据/逻辑)
   │   ├─ 问题位置 (前端/后端/数据库/第三方)
   │   ├─ 严重程度 (P0-P4)
   │   └─ 优先级 (紧急/高/中/低)
   │
   ├─ 根因分析:
   │   ├─ 代码层面分析
   │   ├─ 数据流分析
   │   ├─ 依赖分析
   │   └─ 历史类似问题匹配
   │
   ├─ 复现步骤生成:
   │   ├─ 解析错误信息
   │   ├─ 生成可复现步骤
   │   ├─ 生成测试数据
   │   └─ 验证复现路径

3. 输出
   ├─ BugAnalysis对象
   ├─ 详细分析报告
   ├─ 建议修复方案
   └─ 置信度评分

4. 自动修复 (可选)
   ├─ 基于分析结果生成修复代码
   ├─ 创建修复PR (如集成Git)
   ├─ 执行验证测试
   └─ 报告修复结果

5. 状态更新
   ├─ 更新Bug状态
   ├─ 同步到Feedback系统
   ├─ 通知相关人员
   └─ 记录完整分析日志
```

### 5.3 测试用例自动生成流程

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              测试用例自动生成流程                                        │
└─────────────────────────────────────────────────────────────────────────────────────────┘

1. 触发条件
   ├─ 代码变更检测 (PR/Commit)
   ├─ API文档变更
   ├─ 手动触发 (指定模块/接口)
   └─ 定时全量生成

2. 输入分析
   ├─ 获取变更代码 diff
   ├─ 分析API接口定义
   ├─ 提取数据模型
   ├─ 查找相关文档
   └─ 获取历史测试用例

3. AI生成
   ├─ 功能分析:
   │   ├─ 新增功能识别
   │   ├─ 修改功能识别
   │   ├─ 边界条件分析
   │   └─ 异常场景分析
   │
   ├─ 用例设计:
   │   ├─ 正向用例生成
   │   ├─ 边界值用例生成
   │   ├─ 异常用例生成
   │   ├─ 组合用例生成
   │   └─ 性能/安全用例生成
   │
   └─ 用例实现:
       ├─ 生成请求参数
       ├─ 生成期望响应
       ├─ 生成验证规则
       └─ 生成断言逻辑

4. 用例优化
   ├─ 去重检查
   ├─ 覆盖率分析
   ├─ 可执行性检查
   └─ 优先级排序

5. 输出
   ├─ 测试用例列表
   ├─ 用例说明文档
   ├─ 覆盖率报告
   └─ 建议执行计划

6. 后续动作
   ├─ 自动执行新增用例
   ├─ 与现有用例合并
   ├─ 更新测试套件
   └─ 通知管理员审核
```

---

## 六、与Feedback系统集成

### 6.1 数据同步策略

```
┌─────────────────────────────────────────────────────────────────────────────────────────┐
│                              Feedback与测试系统数据同步                                  │
└─────────────────────────────────────────────────────────────────────────────────────────┘

1. 反馈转Bug分析
   ├─ 用户提交Feedback (类型=Bug)
   ├─ AI自动分析Feedback内容
   ├─ 生成BugAnalysis记录
   ├─ 尝试自动修复
   ├─ 修复结果同步回Feedback
   └─ 状态流转: 待处理 → AI分析中 → 自动修复中 → 已自动修复/需要人工

2. Bug分析转Feedback
   ├─ 测试发现Bug
   ├─ AI生成BugAnalysis
   ├─ 自动创建Feedback (可选)
   ├─ 关联测试任务/用例
   └─ 通知相关开发人员

3. 状态双向同步
   ├─ Feedback状态变更 → 测试系统记录
   ├─ 测试执行结果 → Feedback更新
   └─ 人工确认 → 同步到测试系统
```

### 6.2 扩展现有Feedback模型

```typescript
// 在现有Feedback模型基础上扩展
interface FeedbackTestExt {
  // 测试系统关联
  test_task_id?: number;             // 关联测试任务
  test_case_id?: number;             // 关联测试用例
  test_execution_id?: number;        // 关联执行记录
  
  // AI分析结果
  bug_analysis_id?: number;          // Bug分析ID
  bug_type?: BugType;                // Bug类型
  issue_location?: IssueLocation;    // 问题位置
  severity?: BugSeverity;            // 严重程度
  
  // 修复状态
  auto_fix_attempted?: boolean;      // 是否尝试自动修复
  auto_fix_result?: string;          // 修复结果
  fix_verified?: boolean;            // 修复是否已验证
  
  // 分析元数据
  ai_model?: string;                 // 使用的AI模型
  analysis_prompt?: string;          // 分析使用的prompt
  analysis_result?: string;         // AI分析结果
}

// 新增反馈状态
enum FeedbackStatusExtended {
  // 现有状态...
  AI_ANALYZING = 'ai_analyzing',     // AI分析中
  AUTO_FIXING = 'auto_fixing',       // 自动修复中
  AUTO_FIXED = 'auto_fixed',         // 已自动修复
  FIX_VERIFYING = 'fix_verifying',   // 修复验证中
}

// 新增反馈类型
enum FeedbackTypeExtended {
  // 现有类型...
  AUTO_TEST = 'auto_test',           // 自动化测试发现
  REGRESSION = 'regression',         // 回归测试发现
}
```

---

## 七、安全与权限

### 7.1 权限模型

```typescript
// 测试系统权限
enum TestPermission {
  // 任务权限
  TASK_VIEW = 'test:task:view',
  TASK_CREATE = 'test:task:create',
  TASK_EDIT = 'test:task:edit',
  TASK_DELETE = 'test:task:delete',
  TASK_EXECUTE = 'test:task:execute',
  
  // 用例权限
  CASE_VIEW = 'test:case:view',
  CASE_CREATE = 'test:case:create',
  CASE_EDIT = 'test:case:edit',
  CASE_DELETE = 'test:case:delete',
  
  // Bug分析权限
  BUG_VIEW = 'test:bug:view',
  BUG_ANALYZE = 'test:bug:analyze',
  BUG_AUTO_FIX = 'test:bug:auto_fix',
  
  // 报告权限
  REPORT_VIEW = 'test:report:view',
  REPORT_GENERATE = 'test:report:generate',
  REPORT_EXPORT = 'test:report:export',
  
  // AI权限
  AI_EXECUTE = 'test:ai:execute',
  AI_CONFIG = 'test:ai:config',
}
```

### 7.2 API访问控制

- 所有测试API需要认证
- AI执行接口需要特定权限
- 敏感操作需要二次验证
- 执行日志完整记录用户/Agent操作

---

## 八、边界条件与容错

### 8.1 边界条件处理

| 场景 | 处理策略 |
|------|----------|
| AI服务不可用 | 降级到人工处理队列，发送告警 |
| 执行超时 | 自动终止，保存当前状态，记录日志 |
| 测试环境异常 | 隔离环境，重试或跳过，记录异常 |
| 大量失败用例 | 批量处理，优先分析高优先级 |
| 网络中断 | 自动重试，保存断点，恢复执行 |
| 资源不足 | 排队等待，动态扩容，优先级调度 |
| 并发冲突 | 乐观锁，冲突重试，状态校验 |

### 8.2 错误处理

```typescript
// 统一错误响应
interface TestError {
  code: string;                       // 错误代码
  message: string;                    // 错误消息
  details?: any;                      // 详细错误信息
  suggestion?: string;                // 建议操作
  trace_id?: string;                  // 追踪ID
}

// 错误代码枚举
enum TestErrorCode {
  // 执行错误
  EXECUTION_TIMEOUT = 'test:execution:timeout',
  EXECUTION_CANCELLED = 'test:execution:cancelled',
  EXECUTION_ENV_FAILED = 'test:execution:env_failed',
  
  // AI错误
  AI_SERVICE_UNAVAILABLE = 'test:ai:service_unavailable',
  AI_ANALYSIS_FAILED = 'test:ai:analysis_failed',
  AI_FIX_FAILED = 'test:ai:fix_failed',
  
  // 用例错误
  CASE_VALIDATION_FAILED = 'test:case:validation_failed',
  CASE_DEPENDENCY_NOT_MET = 'test:case:dependency_not_met',
  
  // 资源错误
  RESOURCE_NOT_FOUND = 'test:resource_not_found',
  RESOURCE_CONFLICT = 'test:resource_conflict',
}
```

---

## 九、监控与告警

### 9.1 监控指标

- **执行指标**: 执行次数、通过率、平均时长、失败率
- **AI指标**: 分析成功率、修复成功率、Token消耗
- **资源指标**: CPU/内存使用、API调用延迟、队列积压
- **业务指标**: Bug发现数、用例覆盖率、回归率

### 9.2 告警规则

| 告警级别 | 触发条件 |
|----------|----------|
| P0 | AI服务完全不可用 |
| P0 | 测试执行100%失败 |
| P1 | 连续3次执行失败 |
| P1 | 执行超时 > 30分钟 |
| P2 | 通过率下降 > 20% |
| P2 | AI分析失败率 > 10% |
| P3 | 资源使用率 > 80% |

---

## 十、技术选型

### 10.1 前端技术栈

- **框架**: Vue 3 (Composition API + script setup)
- **UI组件库**: Arco Design Vue
- **状态管理**: Pinia
- **HTTP**: Axios + 拦截器
- **WebSocket**: 用于实时日志
- **图表**: ECharts

### 10.2 后端接口设计 (ZigCMS)

- 使用现有的ORM/QueryBuilder
- 复用现有DI系统
- 异步任务使用消息队列
- AI调用通过Plugin机制

### 10.3 存储

- **结构化数据**: MySQL (使用ZigCMS现有数据库)
- **日志**: Elasticsearch + Kibana
- **文件**: 对象存储 (截图/报告)
- **缓存**: Redis (会话/计数器)

---

## 十一、后续迭代计划

### Phase 1: 基础功能 (MVP)

- [x] 测试任务管理
- [x] 测试用例管理
- [x] 基本执行引擎
- [x] 基础报告

### Phase 2: AI增强

- [ ] Bug自动分析
- [ ] 用例自动生成
- [ ] 自动修复尝试

### Phase 3: 商业化增强

- [ ] 多租户支持
- [ ] 高级报告模板
- [ ] 自定义工作流
- [ ] 第三方集成 (Jira/GitHub/Jenkins)

### Phase 4: 智能化

- [ ] 智能测试优先级
- [ ] 预测性测试
- [ ] 自动化Code Review
- [ ] 持续优化建议
