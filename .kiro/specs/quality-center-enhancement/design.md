# Design Document: Quality Center Enhancement

## Overview

质量中心完善功能是一个全面的测试管理和质量保障系统，旨在为企业提供从测试用例管理、项目管理、需求管理到数据可视化的完整质量管理解决方案。系统融合了AI能力，支持自动生成测试用例、智能分析反馈，并提供丰富的数据可视化和交互功能。

### Design Goals

1. **完整的测试管理流程**：覆盖测试用例创建、执行、跟踪的完整生命周期
2. **AI驱动的效率提升**：利用AI自动生成测试用例和分析反馈，提高工作效率
3. **数据可视化增强**：提供丰富的图表和交互功能，帮助快速了解质量状况
4. **模块化架构**：采用清晰的模块划分，便于维护和扩展
5. **优秀的用户体验**：基于Arco Design构建现代化UI，提供流畅的交互体验

### Technology Stack

- **前端框架**: Vue 3 (Composition API + script setup)
- **UI组件库**: Arco Design Vue
- **状态管理**: Pinia
- **图表库**: ECharts 5
- **HTTP客户端**: Axios
- **Mock数据**: Mock.js
- **脑图库**: vue3-mindmap (或自定义实现)
- **TypeScript**: 类型安全

## Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Presentation Layer                      │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Test Cases   │  │ Projects     │  │ Requirements │         │
│  │ Management   │  │ Management   │  │ Management   │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Modules      │  │ Feedbacks    │  │ Dashboard    │         │
│  │ Management   │  │ List         │  │ Visualization│         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         State Management (Pinia)                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Test Case    │  │ Project      │  │ Quality      │         │
│  │ Store        │  │ Store        │  │ Center Store │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         API Layer                               │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Test Case    │  │ Project      │  │ Requirement  │         │
│  │ API          │  │ API          │  │ API          │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐         │
│  │ Module API   │  │ Feedback API │  │ AI API       │         │
│  └──────────────┘  └──────────────┘  └──────────────┘         │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         Mock Data Layer                         │
│  (Development Environment)                                      │
└─────────────────────────────────────────────────────────────────┘
```

### Module Organization

```
src/
├── views/
│   └── quality-center/
│       ├── test-cases/          # 测试用例管理
│       ├── projects/            # 项目管理
│       ├── modules/             # 模块管理
│       ├── requirements/        # 需求管理
│       ├── feedbacks/           # 反馈列表
│       ├── dashboard/           # 数据可视化
│       └── components/          # 共享组件
├── api/
│   └── quality-center.ts        # API接口定义
├── types/
│   └── quality-center.d.ts      # TypeScript类型定义
├── store/
│   └── modules/
│       └── quality-center.ts    # Pinia状态管理
└── mock/
    └── quality-center.ts        # Mock数据
```

## Components and Interfaces

### Core Components

#### 1. Test Case Management Components

**TestCaseList.vue** - 测试用例列表组件
- 功能：展示测试用例列表，支持筛选、排序、分页
- Props: `projectId?: number`, `moduleId?: number`
- Events: `@create`, `@edit`, `@delete`, `@execute`

**TestCaseForm.vue** - 测试用例表单组件
- 功能：创建/编辑测试用例
- Props: `modelValue: TestCase`, `mode: 'create' | 'edit'`
- Events: `@submit`, `@cancel`

**TestCaseDetail.vue** - 测试用例详情组件
- 功能：展示测试用例完整信息和执行历史
- Props: `caseId: number`
- Events: `@edit`, `@execute`, `@delete`

**ExecuteDialog.vue** - 测试执行对话框
- 功能：记录测试执行结果
- Props: `visible: boolean`, `caseId: number`
- Events: `@submit`, `@cancel`

**AIGenerateDialog.vue** - AI生成测试用例对话框
- 功能：基于需求AI生成测试用例
- Props: `visible: boolean`, `requirementIds: number[]`
- Events: `@generated`, `@cancel`

#### 2. Project Management Components

**ProjectList.vue** - 项目列表组件
- 功能：展示项目卡片列表
- Events: `@create`, `@edit`, `@delete`, `@view`

**ProjectForm.vue** - 项目表单组件
- 功能：创建/编辑项目
- Props: `modelValue: Project`, `mode: 'create' | 'edit'`
- Events: `@submit`, `@cancel`

**ProjectDetail.vue** - 项目详情组件
- 功能：展示项目统计和快捷操作
- Props: `projectId: number`
- Events: `@edit`, `@delete`

**MemberManagement.vue** - 成员管理组件
- 功能：管理项目成员和角色
- Props: `projectId: number`
- Events: `@add`, `@remove`, `@update-role`

#### 3. Module Management Components

**ModuleTree.vue** - 模块树组件
- 功能：树形展示模块结构，支持拖拽
- Props: `projectId: number`
- Events: `@add`, `@edit`, `@delete`, `@move`, `@select`

**ModuleForm.vue** - 模块表单组件
- 功能：创建/编辑模块
- Props: `modelValue: Module`, `parentId?: number`
- Events: `@submit`, `@cancel`

**ModuleDetail.vue** - 模块详情组件
- 功能：展示模块质量统计
- Props: `moduleId: number`
- Events: `@edit`, `@delete`

#### 4. Requirement Management Components

**RequirementList.vue** - 需求列表组件
- 功能：展示需求列表，支持筛选和排序
- Props: `projectId?: number`
- Events: `@create`, `@edit`, `@delete`, `@ai-generate`

**RequirementForm.vue** - 需求表单组件
- 功能：创建/编辑需求
- Props: `modelValue: Requirement`, `mode: 'create' | 'edit'`
- Events: `@submit`, `@cancel`

**AIGenerateRequirementDialog.vue** - AI生成需求对话框
- 功能：基于用户输入AI生成需求
- Props: `visible: boolean`
- Events: `@generated`, `@cancel`

#### 5. Feedback List Components

**FeedbackList.vue** - 反馈列表组件（重构）
- 功能：使用Arco Design表格展示反馈列表
- Props: `filters?: FeedbackFilters`
- Events: `@assign`, `@update-status`, `@ai-analyze`, `@add-follow-up`

**FeedbackDetail.vue** - 反馈详情组件
- 功能：展示反馈完整信息和处理历史
- Props: `feedbackId: number`
- Events: `@update`, `@close`

**AIAnalysisDialog.vue** - AI分析对话框
- 功能：展示AI分析结果
- Props: `visible: boolean`, `feedbackId: number`
- Events: `@close`

**AssignDialog.vue** - 指派对话框
- 功能：指派负责人
- Props: `visible: boolean`, `feedbackIds: number[]`
- Events: `@submit`, `@cancel`

#### 6. Dashboard Visualization Components

**ModuleQualityChart.vue** - 模块质量分布图
- 功能：饼图展示模块质量分布
- Props: `data: ModuleQualityItem[]`
- Events: `@module-click`

**BugDistributionChart.vue** - Bug分布图
- 功能：饼图展示Bug类型分布
- Props: `data: BugTypeDistribution[]`
- Events: `@type-click`

**FeedbackStatusChart.vue** - 反馈状态分布图
- 功能：环形图展示反馈状态分布
- Props: `data: FeedbackStatusDistribution[]`
- Events: `@status-click`

**QualityTrendChart.vue** - 质量趋势图
- 功能：折线图展示质量趋势
- Props: `data: TrendDataPoint[]`, `period: 'week' | 'month' | 'quarter'`
- Events: `@date-click`

#### 7. Mindmap Components

**MindmapCanvas.vue** - 脑图画布组件
- 功能：渲染脑图，支持缩放、拖拽、搜索
- Props: `data: MindmapNode[]`, `type: 'bug' | 'feedback'`
- Events: `@node-click`, `@node-expand`, `@export`

**MindmapNode.vue** - 脑图节点组件
- 功能：渲染单个节点，自适应内容
- Props: `node: MindmapNode`, `scale: number`
- Events: `@click`, `@expand`

## Data Models

### Test Case Model

```typescript
interface TestCase {
  id: number;
  name: string;                    // 用例名称
  description?: string;            // 用例描述
  project_id: number;              // 所属项目
  module_id?: number;              // 所属模块
  
  // 测试内容
  preconditions?: string;          // 前置条件
  steps: TestStep[];               // 测试步骤
  expected_result?: string;        // 预期结果
  
  // 分类
  priority: 'P0' | 'P1' | 'P2' | 'P3';  // 优先级
  type: 'functional' | 'integration' | 'regression' | 'performance' | 'security';
  tags?: string[];                 // 标签
  
  // 状态
  status: 'draft' | 'active' | 'deprecated';
  
  // 关联
  requirement_ids?: number[];      // 关联需求
  bug_ids?: number[];              // 关联Bug
  feedback_ids?: number[];         // 关联反馈
  
  // 执行统计
  execution_count: number;         // 执行次数
  pass_count: number;              // 通过次数
  fail_count: number;              // 失败次数
  last_execution_result?: 'pass' | 'fail' | 'blocked';
  last_execution_time?: string;
  
  // 元数据
  created_by: number;
  created_at: string;
  updated_at?: string;
  source: 'manual' | 'ai_generated' | 'imported';
}

interface TestStep {
  step_number: number;
  action: string;                  // 操作描述
  expected: string;                // 预期结果
  actual?: string;                 // 实际结果（执行时填写）
}
```

### Test Execution Record Model

```typescript
interface TestExecutionRecord {
  id: number;
  test_case_id: number;
  test_case_name: string;
  
  // 执行结果
  result: 'pass' | 'fail' | 'blocked';
  actual_result?: string;          // 实际结果描述
  
  // 附件
  screenshots?: string[];          // 截图URL
  attachments?: string[];          // 附件URL
  
  // 执行信息
  executed_by: number;
  executed_by_name: string;
  execution_time: string;
  duration_minutes?: number;       // 执行时长
  
  // 备注
  remark?: string;
  
  created_at: string;
}
```

### Project Model

```typescript
interface Project {
  id: number;
  name: string;                    // 项目名称
  description?: string;            // 项目描述
  
  // 负责人
  owner_id: number;
  owner_name: string;
  
  // 成员
  members: ProjectMember[];
  
  // 配置
  test_environment?: {
    base_url?: string;
    api_prefix?: string;
    auth_token?: string;
  };
  
  notification_config?: {
    email_enabled: boolean;
    email_recipients?: string[];
    dingtalk_enabled: boolean;
    dingtalk_webhook?: string;
    wechat_enabled: boolean;
    wechat_webhook?: string;
  };
  
  workflow_config?: {
    require_review: boolean;
    auto_assign: boolean;
    default_assignee?: number;
  };
  
  // 统计
  stats: {
    total_cases: number;
    total_requirements: number;
    total_bugs: number;
    total_feedbacks: number;
    pass_rate: number;
    coverage_rate: number;
  };
  
  // 状态
  status: 'active' | 'archived';
  
  // 元数据
  created_by: number;
  created_at: string;
  updated_at?: string;
}

interface ProjectMember {
  user_id: number;
  user_name: string;
  user_avatar?: string;
  role: 'admin' | 'tester' | 'viewer';
  joined_at: string;
}
```

### Module Model

```typescript
interface Module {
  id: number;
  name: string;                    // 模块名称
  description?: string;            // 模块描述
  project_id: number;              // 所属项目
  parent_id?: number;              // 父模块ID
  
  // 负责人
  owner_id?: number;
  owner_name?: string;
  
  // 层级
  level: number;                   // 层级深度
  path: string;                    // 路径（如：1/2/3）
  sort_order: number;              // 排序
  
  // 统计
  stats: {
    case_count: number;
    pass_rate: number;
    bug_count: number;
    coverage_rate: number;
  };
  
  // 子模块
  children?: Module[];
  
  // 元数据
  created_at: string;
  updated_at?: string;
}
```

### Requirement Model

```typescript
interface Requirement {
  id: number;
  title: string;                   // 需求标题
  description: string;             // 需求描述
  acceptance_criteria?: string;    // 验收标准
  
  // 分类
  project_id: number;
  module_id?: number;
  priority: 'P0' | 'P1' | 'P2' | 'P3';
  type: 'feature' | 'enhancement' | 'bugfix';
  
  // 状态
  status: 'pending_review' | 'reviewed' | 'in_development' | 'testing' | 'completed' | 'closed';
  
  // 关联
  related_case_ids?: number[];     // 关联测试用例
  
  // 覆盖率
  coverage_stats: {
    total_test_points: number;     // 总测试点
    covered_test_points: number;   // 已覆盖测试点
    coverage_rate: number;         // 覆盖率
  };
  
  // 元数据
  created_by: number;
  created_by_name: string;
  created_at: string;
  updated_at?: string;
  source: 'manual' | 'ai_generated' | 'imported';
}
```

### Feedback Model (Extended)

```typescript
interface Feedback {
  id: number;
  title: string;                   // 反馈标题
  content: string;                 // 反馈内容
  
  // 分类
  type: number;                    // 反馈类型（1:Bug 2:建议 3:咨询）
  type_name: string;
  priority: 'high' | 'medium' | 'low';
  
  // 状态
  status: number;                  // 状态（0:待处理 1:处理中 2:已解决 3:已关闭 4:已拒绝）
  status_name: string;
  
  // 指派
  assigned_to?: number;
  assigned_to_name?: string;
  
  // 进度
  progress: number;                // 处理进度 0-100
  
  // 关联
  related_case_ids?: number[];     // 关联测试用例
  related_bug_ids?: number[];      // 关联Bug
  
  // AI分析
  ai_analysis?: {
    bug_type?: string;
    severity?: string;
    suggested_fix?: string;
    confidence_score?: number;
  };
  
  // 跟进记录
  follow_ups: FollowUpRecord[];
  
  // 附件
  attachments?: string[];
  screenshots?: string[];
  
  // 元数据
  created_by: number;
  created_by_name: string;
  created_at: string;
  updated_at?: string;
}

interface FollowUpRecord {
  id: number;
  content: string;
  attachments?: string[];
  created_by: number;
  created_by_name: string;
  created_at: string;
}
```

### Mindmap Node Model

```typescript
interface MindmapNode {
  id: string;
  label: string;                   // 节点标签
  type: 'root' | 'category' | 'item';
  
  // 数据
  data?: {
    entity_id?: number;            // 关联实体ID
    entity_type?: string;          // 实体类型
    status?: string;
    severity?: string;
    count?: number;
    [key: string]: any;
  };
  
  // 样式
  style?: {
    backgroundColor?: string;
    borderColor?: string;
    textColor?: string;
    fontSize?: number;
  };
  
  // 子节点
  children?: MindmapNode[];
  
  // 状态
  expanded: boolean;               // 是否展开
  visible: boolean;                // 是否可见
}
```

## API Interfaces

### Test Case APIs

```typescript
// 获取测试用例列表
GET /api/quality-center/test-cases
Query: {
  project_id?: number;
  module_id?: number;
  status?: string;
  priority?: string;
  keyword?: string;
  page?: number;
  page_size?: number;
}
Response: {
  code: number;
  msg: string;
  data: {
    list: TestCase[];
    total: number;
    page: number;
    page_size: number;
  };
}

// 获取测试用例详情
GET /api/quality-center/test-cases/:id
Response: {
  code: number;
  msg: string;
  data: TestCase;
}

// 创建测试用例
POST /api/quality-center/test-cases
Body: Omit<TestCase, 'id' | 'created_at' | 'updated_at'>
Response: {
  code: number;
  msg: string;
  data: TestCase;
}

// 更新测试用例
PUT /api/quality-center/test-cases/:id
Body: Partial<TestCase>
Response: {
  code: number;
  msg: string;
  data: TestCase;
}

// 删除测试用例
DELETE /api/quality-center/test-cases/:id
Response: {
  code: number;
  msg: string;
  data: null;
}

// 批量删除测试用例
POST /api/quality-center/test-cases/batch-delete
Body: { ids: number[] }
Response: {
  code: number;
  msg: string;
  data: { deleted_count: number };
}

// 执行测试用例
POST /api/quality-center/test-cases/:id/execute
Body: {
  result: 'pass' | 'fail' | 'blocked';
  actual_result?: string;
  screenshots?: string[];
  remark?: string;
  duration_minutes?: number;
}
Response: {
  code: number;
  msg: string;
  data: TestExecutionRecord;
}

// 获取执行历史
GET /api/quality-center/test-cases/:id/execution-history
Query: { page?: number; page_size?: number }
Response: {
  code: number;
  msg: string;
  data: {
    list: TestExecutionRecord[];
    total: number;
  };
}

// AI生成测试用例
POST /api/quality-center/test-cases/ai-generate
Body: {
  requirement_ids: number[];
  project_id: number;
  module_id?: number;
}
Response: {
  code: number;
  msg: string;
  data: {
    task_id: string;
    status: 'pending' | 'generating' | 'completed';
    generated_cases?: TestCase[];
    total_count?: number;
  };
}
```

### Project APIs

```typescript
// 获取项目列表
GET /api/quality-center/projects
Query: { keyword?: string; status?: string }
Response: {
  code: number;
  msg: string;
  data: { list: Project[] };
}

// 获取项目详情
GET /api/quality-center/projects/:id
Response: {
  code: number;
  msg: string;
  data: Project;
}

// 创建项目
POST /api/quality-center/projects
Body: Omit<Project, 'id' | 'created_at' | 'updated_at' | 'stats'>
Response: {
  code: number;
  msg: string;
  data: Project;
}

// 更新项目
PUT /api/quality-center/projects/:id
Body: Partial<Project>
Response: {
  code: number;
  msg: string;
  data: Project;
}

// 删除项目
DELETE /api/quality-center/projects/:id
Response: {
  code: number;
  msg: string;
  data: null;
}

// 获取项目成员
GET /api/quality-center/projects/:id/members
Response: {
  code: number;
  msg: string;
  data: { list: ProjectMember[] };
}

// 添加项目成员
POST /api/quality-center/projects/:id/members
Body: { user_id: number; role: 'admin' | 'tester' | 'viewer' }
Response: {
  code: number;
  msg: string;
  data: ProjectMember;
}

// 移除项目成员
DELETE /api/quality-center/projects/:id/members/:user_id
Response: {
  code: number;
  msg: string;
  data: null;
}

// 更新成员角色
PUT /api/quality-center/projects/:id/members/:user_id
Body: { role: 'admin' | 'tester' | 'viewer' }
Response: {
  code: number;
  msg: string;
  data: ProjectMember;
}
```

### Module APIs

```typescript
// 获取模块树
GET /api/quality-center/modules/tree
Query: { project_id: number }
Response: {
  code: number;
  msg: string;
  data: { list: Module[] };
}

// 创建模块
POST /api/quality-center/modules
Body: {
  name: string;
  description?: string;
  project_id: number;
  parent_id?: number;
  owner_id?: number;
}
Response: {
  code: number;
  msg: string;
  data: Module;
}

// 更新模块
PUT /api/quality-center/modules/:id
Body: Partial<Module>
Response: {
  code: number;
  msg: string;
  data: Module;
}

// 删除模块
DELETE /api/quality-center/modules/:id
Response: {
  code: number;
  msg: string;
  data: null;
}

// 移动模块
POST /api/quality-center/modules/:id/move
Body: {
  target_parent_id?: number;
  target_position: number;
}
Response: {
  code: number;
  msg: string;
  data: Module;
}

// 获取模块统计
GET /api/quality-center/modules/:id/stats
Response: {
  code: number;
  msg: string;
  data: {
    case_count: number;
    pass_rate: number;
    bug_count: number;
    coverage_rate: number;
  };
}
```

### Requirement APIs

```typescript
// 获取需求列表
GET /api/quality-center/requirements
Query: {
  project_id?: number;
  status?: string;
  priority?: string;
  keyword?: string;
  page?: number;
  page_size?: number;
}
Response: {
  code: number;
  msg: string;
  data: {
    list: Requirement[];
    total: number;
  };
}

// 获取需求详情
GET /api/quality-center/requirements/:id
Response: {
  code: number;
  msg: string;
  data: Requirement;
}

// 创建需求
POST /api/quality-center/requirements
Body: Omit<Requirement, 'id' | 'created_at' | 'updated_at' | 'coverage_stats'>
Response: {
  code: number;
  msg: string;
  data: Requirement;
}

// 更新需求
PUT /api/quality-center/requirements/:id
Body: Partial<Requirement>
Response: {
  code: number;
  msg: string;
  data: Requirement;
}

// 删除需求
DELETE /api/quality-center/requirements/:id
Response: {
  code: number;
  msg: string;
  data: null;
}

// AI生成需求
POST /api/quality-center/requirements/ai-generate
Body: {
  project_id: number;
  user_input: string;  // 用户故事或项目描述
  context?: string;    // 额外上下文
}
Response: {
  code: number;
  msg: string;
  data: {
    task_id: string;
    status: 'pending' | 'generating' | 'completed';
    generated_requirements?: Requirement[];
    total_count?: number;
  };
}
```

### Feedback APIs (Enhanced)

```typescript
// 获取反馈列表
GET /api/quality-center/feedbacks
Query: {
  status?: number;
  type?: number;
  priority?: string;
  assigned_to?: number;
  keyword?: string;
  start_date?: string;
  end_date?: string;
  page?: number;
  page_size?: number;
}
Response: {
  code: number;
  msg: string;
  data: {
    list: Feedback[];
    total: number;
  };
}

// 获取反馈详情
GET /api/quality-center/feedbacks/:id
Response: {
  code: number;
  msg: string;
  data: Feedback;
}

// 更新反馈
PUT /api/quality-center/feedbacks/:id
Body: Partial<Feedback>
Response: {
  code: number;
  msg: string;
  data: Feedback;
}

// 指派负责人
POST /api/quality-center/feedbacks/assign
Body: {
  feedback_ids: number[];
  assigned_to: number;
}
Response: {
  code: number;
  msg: string;
  data: { updated_count: number };
}

// AI分析反馈
POST /api/quality-center/feedbacks/:id/ai-analyze
Response: {
  code: number;
  msg: string;
  data: {
    bug_type?: string;
    severity?: string;
    suggested_fix?: string;
    confidence_score?: number;
    analysis_details?: string;
  };
}

// 添加跟进记录
POST /api/quality-center/feedbacks/:id/follow-ups
Body: {
  content: string;
  attachments?: string[];
}
Response: {
  code: number;
  msg: string;
  data: FollowUpRecord;
}

// 批量更新状态
POST /api/quality-center/feedbacks/batch-update-status
Body: {
  feedback_ids: number[];
  status: number;
}
Response: {
  code: number;
  msg: string;
  data: { updated_count: number };
}
```

### Dashboard Visualization APIs

```typescript
// 获取模块质量分布
GET /api/quality-center/dashboard/module-quality
Query: { project_id?: number }
Response: {
  code: number;
  msg: string;
  data: { list: ModuleQualityItem[] };
}

// 获取Bug分布
GET /api/quality-center/dashboard/bug-distribution
Query: { project_id?: number; start_date?: string; end_date?: string }
Response: {
  code: number;
  msg: string;
  data: { list: BugTypeDistribution[] };
}

// 获取反馈状态分布
GET /api/quality-center/dashboard/feedback-distribution
Query: { project_id?: number; start_date?: string; end_date?: string }
Response: {
  code: number;
  msg: string;
  data: { list: FeedbackStatusDistribution[] };
}

// 获取质量趋势
GET /api/quality-center/dashboard/quality-trend
Query: { period: 'week' | 'month' | 'quarter'; project_id?: number }
Response: {
  code: number;
  msg: string;
  data: QualityTrend;
}
```

### Mindmap APIs

```typescript
// 获取Bug关联脑图数据
GET /api/quality-center/mindmap/bug-links
Query: { project_id?: number }
Response: {
  code: number;
  msg: string;
  data: { nodes: MindmapNode[] };
}

// 获取反馈分类脑图数据
GET /api/quality-center/mindmap/feedback-classification
Query: { project_id?: number }
Response: {
  code: number;
  msg: string;
  data: { nodes: MindmapNode[] };
}
```

## Routing Design

### Route Configuration

```typescript
// src/router/routes/quality-center.ts
export default {
  path: '/quality-center',
  name: 'QualityCenter',
  component: () => import('@/layout/default-layout.vue'),
  meta: {
    locale: 'menu.qualityCenter',
    icon: 'icon-shield-check',
    requiresAuth: true,
    order: 5,
  },
  children: [
    {
      path: 'dashboard',
      name: 'QualityCenterDashboard',
      component: () => import('@/views/quality-center/dashboard/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.dashboard',
        requiresAuth: true,
      },
    },
    {
      path: 'test-cases',
      name: 'TestCases',
      component: () => import('@/views/quality-center/test-cases/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.testCases',
        requiresAuth: true,
      },
    },
    {
      path: 'test-cases/:id',
      name: 'TestCaseDetail',
      component: () => import('@/views/quality-center/test-cases/detail.vue'),
      meta: {
        locale: 'menu.qualityCenter.testCaseDetail',
        requiresAuth: true,
        hideInMenu: true,
      },
    },
    {
      path: 'projects',
      name: 'Projects',
      component: () => import('@/views/quality-center/projects/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.projects',
        requiresAuth: true,
      },
    },
    {
      path: 'projects/:id',
      name: 'ProjectDetail',
      component: () => import('@/views/quality-center/projects/detail.vue'),
      meta: {
        locale: 'menu.qualityCenter.projectDetail',
        requiresAuth: true,
        hideInMenu: true,
      },
    },
    {
      path: 'modules',
      name: 'Modules',
      component: () => import('@/views/quality-center/modules/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.modules',
        requiresAuth: true,
      },
    },
    {
      path: 'requirements',
      name: 'Requirements',
      component: () => import('@/views/quality-center/requirements/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.requirements',
        requiresAuth: true,
      },
    },
    {
      path: 'feedbacks',
      name: 'Feedbacks',
      component: () => import('@/views/quality-center/feedbacks/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.feedbacks',
        requiresAuth: true,
      },
    },
    {
      path: 'mindmap',
      name: 'Mindmap',
      component: () => import('@/views/quality-center/mindmap/index.vue'),
      meta: {
        locale: 'menu.qualityCenter.mindmap',
        requiresAuth: true,
      },
    },
  ],
};
```

## State Management (Pinia)

### Test Case Store

```typescript
// src/store/modules/test-case.ts
import { defineStore } from 'pinia';
import type { TestCase, TestExecutionRecord } from '@/types/quality-center';

export const useTestCaseStore = defineStore('testCase', {
  state: () => ({
    cases: [] as TestCase[],
    currentCase: null as TestCase | null,
    executionHistory: [] as TestExecutionRecord[],
    loading: {
      list: false,
      detail: false,
      execution: false,
    },
    filters: {
      project_id: undefined as number | undefined,
      module_id: undefined as number | undefined,
      status: undefined as string | undefined,
      priority: undefined as string | undefined,
      keyword: '',
    },
    pagination: {
      page: 1,
      page_size: 20,
      total: 0,
    },
  }),

  actions: {
    async fetchCases() {
      this.loading.list = true;
      try {
        const response = await testCaseAPI.list({
          ...this.filters,
          ...this.pagination,
        });
        this.cases = response.data.list;
        this.pagination.total = response.data.total;
      } finally {
        this.loading.list = false;
      }
    },

    async fetchCaseDetail(id: number) {
      this.loading.detail = true;
      try {
        const response = await testCaseAPI.detail(id);
        this.currentCase = response.data;
      } finally {
        this.loading.detail = false;
      }
    },

    async createCase(data: Partial<TestCase>) {
      const response = await testCaseAPI.create(data);
      await this.fetchCases();
      return response.data;
    },

    async updateCase(id: number, data: Partial<TestCase>) {
      const response = await testCaseAPI.update(id, data);
      await this.fetchCases();
      return response.data;
    },

    async deleteCase(id: number) {
      await testCaseAPI.delete(id);
      await this.fetchCases();
    },

    async executeCaseTest(id: number, data: any) {
      this.loading.execution = true;
      try {
        const response = await testCaseAPI.execute(id, data);
        await this.fetchExecutionHistory(id);
        return response.data;
      } finally {
        this.loading.execution = false;
      }
    },

    async fetchExecutionHistory(caseId: number) {
      const response = await testCaseAPI.executionHistory(caseId);
      this.executionHistory = response.data.list;
    },

    setFilters(filters: Partial<typeof this.filters>) {
      Object.assign(this.filters, filters);
    },

    resetFilters() {
      this.filters = {
        project_id: undefined,
        module_id: undefined,
        status: undefined,
        priority: undefined,
        keyword: '',
      };
    },
  },
});
```

### Project Store

```typescript
// src/store/modules/project.ts
import { defineStore } from 'pinia';
import type { Project, ProjectMember } from '@/types/quality-center';

export const useProjectStore = defineStore('project', {
  state: () => ({
    projects: [] as Project[],
    currentProject: null as Project | null,
    members: [] as ProjectMember[],
    loading: {
      list: false,
      detail: false,
      members: false,
    },
  }),

  getters: {
    activeProjects: (state) => state.projects.filter(p => p.status === 'active'),
    archivedProjects: (state) => state.projects.filter(p => p.status === 'archived'),
  },

  actions: {
    async fetchProjects() {
      this.loading.list = true;
      try {
        const response = await projectAPI.list();
        this.projects = response.data.list;
      } finally {
        this.loading.list = false;
      }
    },

    async fetchProjectDetail(id: number) {
      this.loading.detail = true;
      try {
        const response = await projectAPI.detail(id);
        this.currentProject = response.data;
      } finally {
        this.loading.detail = false;
      }
    },

    async createProject(data: Partial<Project>) {
      const response = await projectAPI.create(data);
      await this.fetchProjects();
      return response.data;
    },

    async updateProject(id: number, data: Partial<Project>) {
      const response = await projectAPI.update(id, data);
      await this.fetchProjects();
      return response.data;
    },

    async deleteProject(id: number) {
      await projectAPI.delete(id);
      await this.fetchProjects();
    },

    async fetchMembers(projectId: number) {
      this.loading.members = true;
      try {
        const response = await projectAPI.getMembers(projectId);
        this.members = response.data.list;
      } finally {
        this.loading.members = false;
      }
    },

    async addMember(projectId: number, userId: number, role: string) {
      const response = await projectAPI.addMember(projectId, { user_id: userId, role });
      await this.fetchMembers(projectId);
      return response.data;
    },

    async removeMember(projectId: number, userId: number) {
      await projectAPI.removeMember(projectId, userId);
      await this.fetchMembers(projectId);
    },

    async updateMemberRole(projectId: number, userId: number, role: string) {
      const response = await projectAPI.updateMemberRole(projectId, userId, { role });
      await this.fetchMembers(projectId);
      return response.data;
    },
  },
});
```

### Quality Center Dashboard Store

```typescript
// src/store/modules/quality-center.ts
import { defineStore } from 'pinia';
import type {
  QualityOverview,
  QualityTrend,
  ModuleQualityItem,
  BugTypeDistribution,
  FeedbackStatusDistribution,
} from '@/types/quality-center';

export const useQualityCenterStore = defineStore('qualityCenter', {
  state: () => ({
    overview: null as QualityOverview | null,
    trend: null as QualityTrend | null,
    moduleQuality: [] as ModuleQualityItem[],
    bugDistribution: [] as BugTypeDistribution[],
    feedbackDistribution: [] as FeedbackStatusDistribution[],
    loading: {
      overview: false,
      trend: false,
      moduleQuality: false,
      bugDistribution: false,
      feedbackDistribution: false,
    },
  }),

  actions: {
    async fetchOverview() {
      this.loading.overview = true;
      try {
        const response = await qualityCenterAPI.getQualityOverview();
        this.overview = response.data;
      } finally {
        this.loading.overview = false;
      }
    },

    async fetchTrend(period: 'week' | 'month' | 'quarter' = 'week') {
      this.loading.trend = true;
      try {
        const response = await qualityCenterAPI.getQualityTrend({ period });
        this.trend = response.data;
      } finally {
        this.loading.trend = false;
      }
    },

    async fetchModuleQuality() {
      this.loading.moduleQuality = true;
      try {
        const response = await qualityCenterAPI.getModuleQuality();
        this.moduleQuality = response.data.list;
      } finally {
        this.loading.moduleQuality = false;
      }
    },

    async fetchBugDistribution() {
      this.loading.bugDistribution = true;
      try {
        const response = await qualityCenterAPI.getBugTypeDistribution();
        this.bugDistribution = response.data.list;
      } finally {
        this.loading.bugDistribution = false;
      }
    },

    async fetchFeedbackDistribution() {
      this.loading.feedbackDistribution = true;
      try {
        const response = await qualityCenterAPI.getFeedbackStatusDistribution();
        this.feedbackDistribution = response.data.list;
      } finally {
        this.loading.feedbackDistribution = false;
      }
    },

    async fetchDashboardAll() {
      await Promise.all([
        this.fetchOverview(),
        this.fetchTrend(),
        this.fetchModuleQuality(),
        this.fetchBugDistribution(),
        this.fetchFeedbackDistribution(),
      ]);
    },
  },
});
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Test Case Creation Persistence

*For any* valid test case data (with required fields: name, project_id), when submitted through the creation form, the system should successfully save the test case and it should appear in the test case list.

**Validates: Requirements 1.3**

### Property 2: Test Case Edit Form Pre-population

*For any* existing test case, when the edit button is clicked, the edit form should pre-fill with the current test case data matching all fields of the original test case.

**Validates: Requirements 1.4**

### Property 3: Test Case Deletion Removes from List

*For any* test case, when deleted and confirmed, the test case should no longer appear in the test case list.

**Validates: Requirements 1.5**

### Property 4: Batch Operations Apply to All Selected Items

*For any* selection of test cases, when a batch operation (delete/update status/assign) is performed, the operation should be applied to all selected items.

**Validates: Requirements 1.6**

### Property 5: Test Execution Creates History Record

*For any* test case execution with a result (pass/fail/blocked), the system should create an execution record that appears in the test case's execution history.

**Validates: Requirements 1.8**

### Property 6: AI Generated Cases Have Correct Source Marker

*For any* test case generated by AI, the test case should have its source field set to "ai_generated".

**Validates: Requirements 2.8**

### Property 7: AI Generated Cases Are Complete

*For any* test case generated by AI, the test case should contain all required fields (name, description, steps, expected_result).

**Validates: Requirements 2.4**

### Property 8: Batch Save of Generated Cases

*For any* set of AI-generated test cases that are confirmed, all cases in the set should be successfully saved to the database.

**Validates: Requirements 2.5**

### Property 9: Project Name Uniqueness Validation

*For any* project creation attempt with a name that already exists, the system should reject the creation and return a validation error.

**Validates: Requirements 3.3**

### Property 10: Child Module Parent ID Assignment

*For any* child module creation, the system should automatically set the parent_id field to match the parent module from which the creation was initiated.

**Validates: Requirements 4.3**

### Property 11: Sibling Module Name Uniqueness

*For any* module creation attempt with a name that matches an existing sibling module (same parent_id), the system should reject the creation and return a validation error.

**Validates: Requirements 4.4**

### Property 12: Module Deletion Validation

*For any* module that has child modules or associated test cases, deletion attempts should be rejected with an appropriate error message.

**Validates: Requirements 4.8**

### Property 13: Module Statistics Aggregation

*For any* module, the quality statistics should correctly aggregate data from the module itself and all its descendant modules.

**Validates: Requirements 4.9**

### Property 14: New Requirement Initial Status

*For any* newly created requirement, the status field should be initialized to "pending_review".

**Validates: Requirements 5.3**

### Property 15: AI Generated Requirements Batch Save

*For any* set of AI-generated requirements that are confirmed, all requirements in the set should be successfully saved to the database.

**Validates: Requirements 5.6**

### Property 16: Requirement Status Transitions

*For any* requirement, status updates should only allow valid state transitions according to the defined workflow (pending_review → reviewed → in_development → testing → completed → closed).

**Validates: Requirements 5.8**

### Property 17: Requirement Coverage Calculation

*For any* requirement, the coverage rate should be calculated as (covered_test_points / total_test_points) * 100.

**Validates: Requirements 5.9**

### Property 18: Requirement Deletion Validation

*For any* requirement that has associated test cases, deletion attempts should be rejected with an appropriate error message.

**Validates: Requirements 5.10**

### Property 19: Dashboard Filter Application

*For any* combination of filters (project, module, time range) applied to dashboard charts, the returned data should only include items matching all filter criteria.

**Validates: Requirements 6.9**

### Property 20: Feedback AI Analysis Completion

*For any* feedback submitted for AI analysis, the system should return analysis results including bug_type, severity, and suggested_fix fields.

**Validates: Requirements 7.5**

### Property 21: Feedback Batch Operations

*For any* selection of feedbacks, when a batch operation (assign/update status/close) is performed, the operation should be applied to all selected feedbacks.

**Validates: Requirements 7.7**

### Property 22: Feedback Advanced Filter Combination

*For any* combination of filter criteria (status, type, priority, assigned_to, date range), the feedback list should only display items matching all specified criteria.

**Validates: Requirements 7.8**

### Property 23: Mindmap Node Focus on Double-Click

*For any* mindmap node, when double-clicked, the view should center on that node.

**Validates: Requirements 8.8**

### Property 24: Mindmap Search Highlighting

*For any* search term entered in the mindmap search, all nodes containing the search term should be highlighted, and the view should scroll to the first matching node.

**Validates: Requirements 8.9**

## Error Handling

### Error Types

```typescript
enum QualityCenterErrorCode {
  // Validation Errors
  VALIDATION_FAILED = 'QC_VALIDATION_FAILED',
  DUPLICATE_NAME = 'QC_DUPLICATE_NAME',
  INVALID_STATUS_TRANSITION = 'QC_INVALID_STATUS_TRANSITION',
  REQUIRED_FIELD_MISSING = 'QC_REQUIRED_FIELD_MISSING',
  
  // Resource Errors
  RESOURCE_NOT_FOUND = 'QC_RESOURCE_NOT_FOUND',
  RESOURCE_HAS_DEPENDENCIES = 'QC_RESOURCE_HAS_DEPENDENCIES',
  PERMISSION_DENIED = 'QC_PERMISSION_DENIED',
  
  // AI Errors
  AI_SERVICE_UNAVAILABLE = 'QC_AI_SERVICE_UNAVAILABLE',
  AI_GENERATION_FAILED = 'QC_AI_GENERATION_FAILED',
  AI_ANALYSIS_TIMEOUT = 'QC_AI_ANALYSIS_TIMEOUT',
  
  // Operation Errors
  BATCH_OPERATION_PARTIAL_FAILURE = 'QC_BATCH_OPERATION_PARTIAL_FAILURE',
  CONCURRENT_MODIFICATION = 'QC_CONCURRENT_MODIFICATION',
  EXPORT_FAILED = 'QC_EXPORT_FAILED',
}

interface QualityCenterError {
  code: QualityCenterErrorCode;
  message: string;
  details?: any;
  field?: string;
  suggestion?: string;
}
```

### Error Handling Strategy

1. **Validation Errors**: Display inline validation messages on form fields
2. **Resource Errors**: Show toast notifications with actionable messages
3. **AI Errors**: Display error dialog with retry option and fallback to manual operation
4. **Batch Operation Errors**: Show detailed results with success/failure breakdown
5. **Network Errors**: Implement automatic retry with exponential backoff
6. **Permission Errors**: Redirect to appropriate page with explanation

### Error Recovery

```typescript
// Example: AI Generation Error Recovery
async function generateTestCasesWithRetry(requirementIds: number[], maxRetries = 3) {
  let attempt = 0;
  
  while (attempt < maxRetries) {
    try {
      const result = await testCaseAPI.aiGenerate({ requirement_ids: requirementIds });
      return result;
    } catch (error) {
      attempt++;
      
      if (error.code === 'QC_AI_SERVICE_UNAVAILABLE' && attempt < maxRetries) {
        // Wait before retry (exponential backoff)
        await new Promise(resolve => setTimeout(resolve, Math.pow(2, attempt) * 1000));
        continue;
      }
      
      if (error.code === 'QC_AI_GENERATION_FAILED') {
        // Offer manual creation as fallback
        Message.error({
          content: 'AI生成失败，请手动创建测试用例',
          duration: 5000,
        });
        return { fallback: true };
      }
      
      throw error;
    }
  }
  
  throw new Error('AI服务暂时不可用，请稍后重试');
}
```

## Testing Strategy

### Unit Testing

Unit tests focus on specific examples, edge cases, and error conditions. They complement property-based tests by validating concrete scenarios.

**Test Coverage Areas:**
- Component rendering with specific props
- Form validation logic
- API request/response handling
- Store actions and state mutations
- Utility functions
- Error handling flows

**Example Unit Tests:**

```typescript
// Test Case Form Validation
describe('TestCaseForm', () => {
  it('should show error when name is empty', () => {
    const wrapper = mount(TestCaseForm, {
      props: { modelValue: { name: '' } }
    });
    wrapper.find('button[type="submit"]').trigger('click');
    expect(wrapper.find('.error-message').text()).toContain('请输入用例名称');
  });
  
  it('should emit submit event with valid data', async () => {
    const wrapper = mount(TestCaseForm, {
      props: { 
        modelValue: { 
          name: 'Test Case 1',
          project_id: 1,
          steps: [{ step_number: 1, action: 'Click button', expected: 'Page loads' }]
        } 
      }
    });
    await wrapper.find('button[type="submit"]').trigger('click');
    expect(wrapper.emitted('submit')).toBeTruthy();
  });
});

// Module Tree Operations
describe('ModuleTree', () => {
  it('should prevent deletion of module with children', async () => {
    const module = { id: 1, name: 'Parent', children: [{ id: 2, name: 'Child' }] };
    const wrapper = mount(ModuleTree, {
      props: { modules: [module] }
    });
    
    await wrapper.find('[data-action="delete"][data-id="1"]').trigger('click');
    expect(wrapper.find('.error-message').text()).toContain('存在子模块');
  });
});
```

### Property-Based Testing

Property-based tests verify universal properties across all inputs using randomization. Each test should run a minimum of 100 iterations.

**Configuration:**
- Library: fast-check (for JavaScript/TypeScript)
- Minimum iterations: 100 per property
- Tag format: `Feature: quality-center-enhancement, Property {number}: {property_text}`

**Example Property Tests:**

```typescript
import fc from 'fast-check';

// Property 1: Test Case Creation Persistence
describe('Property 1: Test Case Creation Persistence', () => {
  it('should persist any valid test case', () => {
    // Feature: quality-center-enhancement, Property 1: Test Case Creation Persistence
    fc.assert(
      fc.asyncProperty(
        fc.record({
          name: fc.string({ minLength: 1, maxLength: 100 }),
          project_id: fc.integer({ min: 1, max: 1000 }),
          description: fc.option(fc.string({ maxLength: 500 })),
          priority: fc.constantFrom('P0', 'P1', 'P2', 'P3'),
          type: fc.constantFrom('functional', 'integration', 'regression'),
        }),
        async (testCase) => {
          const created = await testCaseAPI.create(testCase);
          const list = await testCaseAPI.list({ project_id: testCase.project_id });
          
          expect(list.data.list.some(c => c.id === created.data.id)).toBe(true);
        }
      ),
      { numRuns: 100 }
    );
  });
});

// Property 3: Test Case Deletion Removes from List
describe('Property 3: Test Case Deletion', () => {
  it('should remove any test case from list after deletion', () => {
    // Feature: quality-center-enhancement, Property 3: Test Case Deletion Removes from List
    fc.assert(
      fc.asyncProperty(
        fc.integer({ min: 1, max: 1000 }),
        async (caseId) => {
          await testCaseAPI.delete(caseId);
          const list = await testCaseAPI.list({});
          
          expect(list.data.list.some(c => c.id === caseId)).toBe(false);
        }
      ),
      { numRuns: 100 }
    );
  });
});

// Property 9: Project Name Uniqueness Validation
describe('Property 9: Project Name Uniqueness', () => {
  it('should reject duplicate project names', () => {
    // Feature: quality-center-enhancement, Property 9: Project Name Uniqueness Validation
    fc.assert(
      fc.asyncProperty(
        fc.string({ minLength: 1, maxLength: 50 }),
        async (projectName) => {
          // Create first project
          await projectAPI.create({ name: projectName, description: 'Test' });
          
          // Attempt to create duplicate
          await expect(
            projectAPI.create({ name: projectName, description: 'Duplicate' })
          ).rejects.toThrow('QC_DUPLICATE_NAME');
        }
      ),
      { numRuns: 100 }
    );
  });
});

// Property 17: Requirement Coverage Calculation
describe('Property 17: Requirement Coverage Calculation', () => {
  it('should correctly calculate coverage for any requirement', () => {
    // Feature: quality-center-enhancement, Property 17: Requirement Coverage Calculation
    fc.assert(
      fc.property(
        fc.integer({ min: 1, max: 100 }),
        fc.integer({ min: 0, max: 100 }),
        (totalPoints, coveredPoints) => {
          fc.pre(coveredPoints <= totalPoints);
          
          const requirement = {
            coverage_stats: {
              total_test_points: totalPoints,
              covered_test_points: coveredPoints,
              coverage_rate: (coveredPoints / totalPoints) * 100,
            },
          };
          
          const expectedRate = (coveredPoints / totalPoints) * 100;
          expect(requirement.coverage_stats.coverage_rate).toBeCloseTo(expectedRate, 2);
        }
      ),
      { numRuns: 100 }
    );
  });
});
```

### Integration Testing

Integration tests verify the interaction between multiple components and the API layer.

**Test Scenarios:**
- Complete user flows (create project → add module → create test case → execute test)
- API integration with mock backend
- Store integration with components
- Chart interaction and navigation
- AI generation workflow

### E2E Testing

End-to-end tests validate complete user journeys using tools like Playwright or Cypress.

**Critical User Journeys:**
1. Create project and add team members
2. Create module hierarchy
3. Create and execute test cases
4. Generate test cases from requirements using AI
5. View and interact with dashboard visualizations
6. Process feedback with AI analysis

## Mock Data Design

### Test Case Mock Data

```typescript
// src/mock/quality-center/test-cases.ts
export const mockTestCases = Mock.mock({
  'list|50': [
    {
      'id|+1': 1,
      name: '@ctitle(5, 15)',
      description: '@cparagraph(1, 3)',
      'project_id|1-10': 1,
      'module_id|1-20': 1,
      'priority': '@pick(["P0", "P1", "P2", "P3"])',
      'type': '@pick(["functional", "integration", "regression", "performance", "security"])',
      'status': '@pick(["draft", "active", "deprecated"])',
      'steps|1-5': [
        {
          'step_number|+1': 1,
          action: '@csentence(5, 15)',
          expected: '@csentence(5, 15)',
        },
      ],
      'tags|0-3': ['@cword(2, 4)'],
      'execution_count|0-100': 10,
      'pass_count|0-100': 8,
      'fail_count|0-20': 2,
      'last_execution_result': '@pick(["pass", "fail", "blocked", null])',
      'last_execution_time': '@datetime',
      'created_by': 1,
      'created_at': '@datetime',
      'source': '@pick(["manual", "ai_generated", "imported"])',
    },
  ],
});

export const mockExecutionHistory = Mock.mock({
  'list|20': [
    {
      'id|+1': 1,
      test_case_id: 1,
      test_case_name: '@ctitle(5, 10)',
      'result': '@pick(["pass", "fail", "blocked"])',
      actual_result: '@cparagraph(1, 2)',
      'screenshots|0-3': ['@image("200x100")'],
      executed_by: 1,
      executed_by_name: '@cname',
      execution_time: '@datetime',
      'duration_minutes|5-120': 30,
      remark: '@csentence',
      created_at: '@datetime',
    },
  ],
});
```

### Project Mock Data

```typescript
// src/mock/quality-center/projects.ts
export const mockProjects = Mock.mock({
  'list|15': [
    {
      'id|+1': 1,
      name: '@ctitle(3, 10)项目',
      description: '@cparagraph(1, 2)',
      owner_id: 1,
      owner_name: '@cname',
      'members|3-8': [
        {
          'user_id|+1': 1,
          user_name: '@cname',
          user_avatar: '@image("50x50")',
          'role': '@pick(["admin", "tester", "viewer"])',
          joined_at: '@datetime',
        },
      ],
      test_environment: {
        base_url: '@url',
        api_prefix: '/api',
        auth_token: '@guid',
      },
      notification_config: {
        email_enabled: '@boolean',
        'email_recipients|0-3': ['@email'],
        dingtalk_enabled: '@boolean',
        dingtalk_webhook: '@url',
        wechat_enabled: '@boolean',
        wechat_webhook: '@url',
      },
      workflow_config: {
        require_review: '@boolean',
        auto_assign: '@boolean',
        'default_assignee|1-10': 1,
      },
      stats: {
        'total_cases|10-200': 50,
        'total_requirements|5-50': 20,
        'total_bugs|0-30': 10,
        'total_feedbacks|0-50': 15,
        'pass_rate|60-100': 85,
        'coverage_rate|50-100': 75,
      },
      'status': '@pick(["active", "archived"])',
      'created_by': 1,
      created_at: '@datetime',
      updated_at: '@datetime',
    },
  ],
});
```

### Module Mock Data

```typescript
// src/mock/quality-center/modules.ts
export const mockModules = Mock.mock({
  'list|10': [
    {
      'id|+1': 1,
      name: '@cword(2, 6)模块',
      description: '@csentence',
      'project_id|1-10': 1,
      parent_id: null,
      'owner_id|1-10': 1,
      owner_name: '@cname',
      'level': 1,
      path: '1',
      'sort_order|1-100': 1,
      stats: {
        'case_count|5-50': 20,
        'pass_rate|60-100': 85,
        'bug_count|0-10': 3,
        'coverage_rate|50-100': 75,
      },
      'children|2-5': [
        {
          'id|+100': 100,
          name: '@cword(2, 6)子模块',
          description: '@csentence',
          'project_id|1-10': 1,
          'parent_id': '@id',
          'owner_id|1-10': 1,
          owner_name: '@cname',
          'level': 2,
          path: '1/100',
          'sort_order|1-100': 1,
          stats: {
            'case_count|5-30': 10,
            'pass_rate|60-100': 80,
            'bug_count|0-5': 2,
            'coverage_rate|50-100': 70,
          },
          children: [],
          created_at: '@datetime',
          updated_at: '@datetime',
        },
      ],
      created_at: '@datetime',
      updated_at: '@datetime',
    },
  ],
});
```

### Requirement Mock Data

```typescript
// src/mock/quality-center/requirements.ts
export const mockRequirements = Mock.mock({
  'list|30': [
    {
      'id|+1': 1,
      title: '@ctitle(5, 20)',
      description: '@cparagraph(2, 4)',
      acceptance_criteria: '@cparagraph(1, 3)',
      'project_id|1-10': 1,
      'module_id|1-20': 1,
      'priority': '@pick(["P0", "P1", "P2", "P3"])',
      'type': '@pick(["feature", "enhancement", "bugfix"])',
      'status': '@pick(["pending_review", "reviewed", "in_development", "testing", "completed", "closed"])',
      'related_case_ids|0-5': ['@integer(1, 100)'],
      coverage_stats: {
        'total_test_points|5-20': 10,
        'covered_test_points|0-20': 7,
        'coverage_rate|0-100': 70,
      },
      'created_by': 1,
      created_by_name: '@cname',
      created_at: '@datetime',
      updated_at: '@datetime',
      'source': '@pick(["manual", "ai_generated", "imported"])',
    },
  ],
});
```

### Feedback Mock Data (Enhanced)

```typescript
// src/mock/quality-center/feedbacks.ts
export const mockFeedbacks = Mock.mock({
  'list|50': [
    {
      'id|+1': 1,
      title: '@ctitle(5, 20)',
      content: '@cparagraph(2, 4)',
      'type|1-3': 1,
      'type_name': '@pick(["Bug", "建议", "咨询"])',
      'priority': '@pick(["high", "medium", "low"])',
      'status|0-4': 1,
      'status_name': '@pick(["待处理", "处理中", "已解决", "已关闭", "已拒绝"])',
      'assigned_to|1-10': 1,
      assigned_to_name: '@cname',
      'progress|0-100': 50,
      'related_case_ids|0-3': ['@integer(1, 100)'],
      'related_bug_ids|0-2': ['@integer(1, 50)'],
      ai_analysis: {
        bug_type: '@pick(["功能错误", "UI问题", "性能问题", "安全问题"])',
        severity: '@pick(["critical", "high", "medium", "low"])',
        suggested_fix: '@cparagraph(1, 2)',
        'confidence_score|0.5-1': 0.85,
      },
      'follow_ups|0-5': [
        {
          'id|+1': 1,
          content: '@cparagraph(1, 2)',
          'attachments|0-2': ['@url'],
          'created_by|1-10': 1,
          created_by_name: '@cname',
          created_at: '@datetime',
        },
      ],
      'attachments|0-3': ['@url'],
      'screenshots|0-3': ['@image("400x300")'],
      'created_by': 1,
      created_by_name: '@cname',
      created_at: '@datetime',
      updated_at: '@datetime',
    },
  ],
});
```

### Dashboard Mock Data

```typescript
// src/mock/quality-center/dashboard.ts
export const mockDashboardData = {
  overview: {
    pass_rate: 85.5,
    total_tasks: 156,
    active_bugs: 23,
    pending_feedbacks: 45,
    ai_fix_rate: 72.3,
    weekly_executions: 234,
    feedback_to_task_count: 18,
    avg_bug_fix_hours: 12.5,
  },
  
  trend: Mock.mock({
    period: 'week',
    'trend_data|7': [
      {
        date: '@date("yyyy-MM-dd")',
        'pass_rate|70-95': 85,
        'bug_count|5-25': 15,
        'feedback_count|10-40': 25,
        'execution_count|20-60': 40,
      },
    ],
  }),
  
  moduleQuality: Mock.mock({
    'list|8': [
      {
        module_name: '@cword(2, 6)模块',
        'pass_rate|60-100': 85,
        'bug_count|0-15': 5,
        'case_count|10-80': 40,
        'feedback_count|0-20': 8,
      },
    ],
  }),
  
  bugDistribution: Mock.mock({
    'list|5': [
      {
        type: '@pick(["functional", "ui", "performance", "security", "data"])',
        type_name: '@pick(["功能错误", "UI问题", "性能问题", "安全问题", "数据问题"])',
        'count|5-50': 20,
        'percentage|5-40': 25,
      },
    ],
  }),
  
  feedbackDistribution: Mock.mock({
    'list|5': [
      {
        'status|0-4': 0,
        status_name: '@pick(["待处理", "处理中", "已解决", "已关闭", "已拒绝"])',
        'count|5-50': 20,
        'percentage|5-40': 25,
      },
    ],
  }),
};
```

### Mindmap Mock Data

```typescript
// src/mock/quality-center/mindmap.ts
export const mockMindmapData = {
  bugLinks: {
    nodes: [
      {
        id: 'root',
        label: 'Bug关联分析',
        type: 'root',
        expanded: true,
        visible: true,
        children: [
          {
            id: 'critical',
            label: '严重Bug (5)',
            type: 'category',
            data: { severity: 'critical', count: 5 },
            style: { backgroundColor: '#f53f3f', textColor: '#fff' },
            expanded: true,
            visible: true,
            children: Mock.mock({
              'list|5': [
                {
                  'id': '@guid',
                  label: '@ctitle(5, 15)',
                  type: 'item',
                  data: {
                    'entity_id|+1': 1,
                    entity_type: 'bug',
                    status: '@pick(["open", "in_progress", "resolved"])',
                    severity: 'critical',
                  },
                  expanded: false,
                  visible: true,
                },
              ],
            }).list,
          },
          {
            id: 'high',
            label: '高优先级Bug (12)',
            type: 'category',
            data: { severity: 'high', count: 12 },
            style: { backgroundColor: '#ff7d00', textColor: '#fff' },
            expanded: false,
            visible: true,
            children: [],
          },
        ],
      },
    ],
  },
  
  feedbackClassification: {
    nodes: [
      {
        id: 'root',
        label: '反馈分类',
        type: 'root',
        expanded: true,
        visible: true,
        children: [
          {
            id: 'bug',
            label: 'Bug反馈 (28)',
            type: 'category',
            data: { type: 'bug', count: 28 },
            style: { backgroundColor: '#165dff', textColor: '#fff' },
            expanded: true,
            visible: true,
            children: Mock.mock({
              'list|10': [
                {
                  'id': '@guid',
                  label: '@ctitle(5, 15)',
                  type: 'item',
                  data: {
                    'entity_id|+1': 1,
                    entity_type: 'feedback',
                    type: 'bug',
                    'status|0-4': 1,
                    'priority': '@pick(["high", "medium", "low"])',
                  },
                  expanded: false,
                  visible: true,
                },
              ],
            }).list,
          },
          {
            id: 'suggestion',
            label: '建议反馈 (15)',
            type: 'category',
            data: { type: 'suggestion', count: 15 },
            style: { backgroundColor: '#00b42a', textColor: '#fff' },
            expanded: false,
            visible: true,
            children: [],
          },
        ],
      },
    ],
  },
};
```

## Implementation Notes

### Performance Optimization

1. **Virtual Scrolling**: Implement virtual scrolling for large lists (test cases, feedbacks)
2. **Lazy Loading**: Load module tree nodes on-demand
3. **Debouncing**: Debounce search and filter inputs (300ms)
4. **Caching**: Cache dashboard data for 5 minutes
5. **Code Splitting**: Lazy load routes and heavy components
6. **Image Optimization**: Use lazy loading for screenshots and attachments

### Accessibility

1. **Keyboard Navigation**: Support full keyboard navigation for all interactive elements
2. **ARIA Labels**: Add appropriate ARIA labels to all components
3. **Focus Management**: Manage focus properly in dialogs and modals
4. **Color Contrast**: Ensure WCAG AA compliance for all text and UI elements
5. **Screen Reader Support**: Test with screen readers (NVDA, JAWS)

### Browser Compatibility

- Chrome 90+
- Firefox 88+
- Safari 14+
- Edge 90+

### Mobile Responsiveness

- Responsive breakpoints: xs (< 576px), sm (576px), md (768px), lg (992px), xl (1200px)
- Touch-friendly UI elements (minimum 44x44px tap targets)
- Optimized layouts for mobile devices
- Swipe gestures for mobile navigation

## Deployment Considerations

### Environment Variables

```env
# API Configuration
VITE_API_BASE_URL=http://localhost:8080
VITE_API_TIMEOUT=30000

# AI Service Configuration
VITE_AI_SERVICE_URL=http://localhost:8081
VITE_AI_SERVICE_KEY=your-api-key

# Feature Flags
VITE_ENABLE_AI_GENERATION=true
VITE_ENABLE_MINDMAP=true
VITE_ENABLE_EXPORT=true

# Mock Data
VITE_USE_MOCK=true
```

### Build Configuration

```typescript
// vite.config.ts
export default defineConfig({
  build: {
    rollupOptions: {
      output: {
        manualChunks: {
          'vendor': ['vue', 'vue-router', 'pinia'],
          'arco': ['@arco-design/web-vue'],
          'echarts': ['echarts'],
          'quality-center': [
            './src/views/quality-center',
            './src/store/modules/quality-center',
          ],
        },
      },
    },
    chunkSizeWarningLimit: 1000,
  },
});
```

## Future Enhancements

1. **Real-time Collaboration**: WebSocket support for real-time updates
2. **Advanced AI Features**: AI-powered test case optimization and bug prediction
3. **Integration with CI/CD**: Automatic test execution on code commits
4. **Custom Workflows**: User-defined workflow states and transitions
5. **Advanced Reporting**: Customizable report templates and scheduling
6. **Mobile App**: Native mobile app for on-the-go test management
7. **API Documentation**: Interactive API documentation with Swagger/OpenAPI
8. **Webhooks**: Custom webhook support for external integrations

## Conclusion

This design document provides a comprehensive blueprint for implementing the Quality Center Enhancement feature. The system is built on modern technologies (Vue 3, Arco Design, ECharts) and follows best practices for maintainability, testability, and user experience. The modular architecture allows for easy extension and customization, while the AI integration provides intelligent automation capabilities. The combination of unit tests and property-based tests ensures high code quality and correctness across all scenarios.
