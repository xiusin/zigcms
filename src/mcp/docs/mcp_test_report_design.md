# MCP 自动测试上报工具 - 设计方案

## 一、系统概述

### 1.1 设计目标

基于前端质量中心和自动测试系统的设计理念，为 ZigCMS MCP 实现一个**AI 监督式自动测试上报工具**，实现：

1. **AI 自动执行测试**：AI Agent 通过 MCP 接口自动执行测试任务
2. **智能问题上报**：测试失败时自动分析并上报到后端服务
3. **Bug 自动分类**：根据错误类型、位置、严重程度自动分类
4. **监督式修复**：AI 自动检测未处理的 Bug 并尝试修复
5. **完整追踪**：记录完整的测试执行日志和修复历史

### 1.2 核心价值

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AI 监督式测试闭环                                   │
└─────────────────────────────────────────────────────────────────────────────┘

AI 开发代码
     │
     ▼
AI 执行测试 (MCP test_report)
     │
     ├─ 通过 → 继续开发
     │
     └─ 失败 → 自动上报 Bug
              │
              ▼
         AI 分析 Bug (MCP test_report analyze)
              │
              ├─ 类型分类
              ├─ 位置定位
              ├─ 严重程度评估
              └─ 生成修复建议
              │
              ▼
         AI 检测未处理 Bug (MCP test_report check_pending)
              │
              ▼
         AI 尝试自动修复 (MCP test_report auto_fix)
              │
              ├─ 修复成功 → 验证测试 → 关闭 Bug
              │
              └─ 修复失败 → 标记需要人工 → 通知开发者
```

### 1.3 与前端系统对接

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          前端质量中心 (ecom-admin)                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Dashboard    │  │ Bug 列表     │  │ 测试报告     │  │ 关联追踪     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ HTTP API
┌─────────────────────────────────────────────────────────────────────────────┐
│                          ZigCMS 后端服务                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ Bug 管理     │  │ 测试记录     │  │ 反馈系统     │  │ 质量统计     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼ MCP Protocol
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MCP 自动测试上报工具                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐   │
│  │ 测试执行     │  │ Bug 上报     │  │ Bug 分析     │  │ 自动修复     │   │
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘   │
└─────────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                          AI Agent (Claude/GPT)                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## 二、核心功能设计

### 2.1 功能模块

#### 模块 1：测试执行与上报

**功能**：
- 执行测试用例（API 测试、单元测试、集成测试）
- 收集测试结果和错误信息
- 自动上报失败的测试到后端服务

**MCP 工具**：`test_report`

**操作类型**：
1. `execute` - 执行测试并上报结果
2. `report_bug` - 手动上报 Bug
3. `get_results` - 获取测试结果

#### 模块 2：Bug 智能分析

**功能**：
- 分析 Bug 类型（功能/UI/性能/安全/数据/逻辑）
- 定位问题位置（前端/后端/数据库/第三方）
- 评估严重程度（P0-P4）
- 生成复现步骤和修复建议

**MCP 工具**：`test_report`

**操作类型**：
1. `analyze` - 分析 Bug
2. `classify` - 分类 Bug
3. `suggest_fix` - 生成修复建议

#### 模块 3：Bug 监督检测

**功能**：
- 检测未处理的 Bug
- 按优先级排序
- 生成待处理清单

**MCP 工具**：`test_report`

**操作类型**：
1. `check_pending` - 检测未处理 Bug
2. `get_priority_list` - 获取优先级列表
3. `get_statistics` - 获取统计信息

#### 模块 4：自动修复

**功能**：
- 尝试自动修复 Bug
- 验证修复结果
- 更新 Bug 状态

**MCP 工具**：`test_report`

**操作类型**：
1. `auto_fix` - 自动修复
2. `verify_fix` - 验证修复
3. `update_status` - 更新状态

---

## 三、数据模型设计

### 3.1 测试报告 (TestReport)

```zig
pub const TestReport = struct {
    id: ?i32 = null,
    
    // 基本信息
    name: []const u8,                    // 测试名称
    type: TestType,                      // 测试类型
    status: TestStatus,                  // 测试状态
    
    // 测试结果
    total_cases: i32 = 0,                // 总用例数
    passed_cases: i32 = 0,               // 通过数
    failed_cases: i32 = 0,               // 失败数
    skipped_cases: i32 = 0,              // 跳过数
    pass_rate: f32 = 0.0,                // 通过率
    
    // 执行信息
    started_at: ?i64 = null,             // 开始时间
    completed_at: ?i64 = null,           // 完成时间
    duration: ?i32 = null,               // 执行时长(ms)
    
    // 错误信息
    error_message: ?[]const u8 = null,   // 错误消息
    stack_trace: ?[]const u8 = null,     // 堆栈跟踪
    
    // 关联
    bug_id: ?i32 = null,                 // 关联 Bug ID
    feedback_id: ?i32 = null,            // 关联反馈 ID
    
    // 元数据
    created_by: []const u8 = "AI",       // 创建者
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

pub const TestType = enum {
    api,                                 // API 测试
    unit,                                // 单元测试
    integration,                         // 集成测试
    e2e,                                 // 端到端测试
    performance,                         // 性能测试
    security,                            // 安全测试
};

pub const TestStatus = enum {
    pending,                             // 待执行
    running,                             // 执行中
    passed,                              // 通过
    failed,                              // 失败
    error,                               // 错误
    skipped,                             // 跳过
};
```

### 3.2 Bug 分析 (BugAnalysis)

```zig
pub const BugAnalysis = struct {
    id: ?i32 = null,
    
    // Bug 基本信息
    title: []const u8,                   // Bug 标题
    description: []const u8,             // Bug 描述
    type: BugType,                       // Bug 类型
    severity: BugSeverity,               // 严重程度
    priority: BugPriority,               // 优先级
    
    // 问题定位
    issue_location: IssueLocation,       // 问题位置
    file_path: ?[]const u8 = null,       // 文件路径
    line_number: ?i32 = null,            // 行号
    
    // 分析结果
    root_cause: ?[]const u8 = null,      // 根本原因
    reproduction_steps: ?[]const u8 = null, // 复现步骤
    suggested_fix: ?[]const u8 = null,   // 修复建议
    confidence_score: f32 = 0.0,         // 置信度 (0-1)
    
    // 修复状态
    status: BugStatus,                   // Bug 状态
    auto_fix_attempted: bool = false,    // 是否尝试自动修复
    auto_fix_success: bool = false,      // 自动修复是否成功
    fix_code: ?[]const u8 = null,        // 修复代码
    
    // 关联
    test_report_id: ?i32 = null,         // 关联测试报告
    feedback_id: ?i32 = null,            // 关联反馈
    
    // 元数据
    analyzed_by: []const u8 = "AI",      // 分析者
    analyzed_at: ?i64 = null,            // 分析时间
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};

pub const BugType = enum {
    functional,                          // 功能错误
    ui,                                  // 界面问题
    performance,                         // 性能问题
    security,                            // 安全问题
    data,                                // 数据问题
    logic,                               // 逻辑错误
    configuration,                       // 配置错误
    network,                             // 网络问题
};

pub const BugSeverity = enum {
    p0,                                  // 致命
    p1,                                  // 严重
    p2,                                  // 一般
    p3,                                  // 轻微
    p4,                                  // 建议
};

pub const BugPriority = enum {
    urgent,                              // 紧急
    high,                                // 高
    medium,                              // 中
    low,                                 // 低
};

pub const IssueLocation = enum {
    frontend,                            // 前端
    backend,                             // 后端
    database,                            // 数据库
    infrastructure,                      // 基础设施
    third_party,                         // 第三方
    unknown,                             // 未知
};

pub const BugStatus = enum {
    pending,                             // 待处理
    analyzing,                           // 分析中
    analyzed,                            // 已分析
    auto_fixing,                         // 自动修复中
    auto_fixed,                          // 已自动修复
    manual_fixing,                       // 人工修复中
    resolved,                            // 已解决
    closed,                              // 已关闭
    reopened,                            // 已重新打开
};
```

---

## 四、MCP 工具接口设计

### 4.1 工具定义

**工具名称**：`test_report`

**描述**：自动化测试执行、Bug 上报、分析和修复工具

**操作类型**：

| 操作 | 描述 | 参数 |
|------|------|------|
| `execute` | 执行测试并上报结果 | test_type, test_target, auto_report |
| `report_bug` | 手动上报 Bug | title, description, error_info |
| `analyze` | 分析 Bug | bug_id 或 error_info |
| `check_pending` | 检测未处理 Bug | priority, limit |
| `auto_fix` | 自动修复 Bug | bug_id, verify |
| `verify_fix` | 验证修复结果 | bug_id, test_case |
| `get_statistics` | 获取统计信息 | time_range |

### 4.2 工具定义 (JSON Schema)

```json
{
  "name": "test_report",
  "description": "自动化测试执行、Bug 上报、分析和修复工具，支持 AI 监督式测试闭环",
  "inputSchema": {
    "type": "object",
    "properties": {
      "operation": {
        "type": "string",
        "enum": [
          "execute",
          "report_bug",
          "analyze",
          "check_pending",
          "auto_fix",
          "verify_fix",
          "get_statistics"
        ],
        "description": "操作类型"
      },
      "params": {
        "type": "object",
        "description": "操作参数",
        "properties": {
          "test_type": {
            "type": "string",
            "enum": ["api", "unit", "integration", "e2e", "performance", "security"],
            "description": "测试类型"
          },
          "test_target": {
            "type": "string",
            "description": "测试目标（文件路径、API 端点等）"
          },
          "auto_report": {
            "type": "boolean",
            "description": "是否自动上报失败的测试"
          },
          "bug_id": {
            "type": "integer",
            "description": "Bug ID"
          },
          "title": {
            "type": "string",
            "description": "Bug 标题"
          },
          "description": {
            "type": "string",
            "description": "Bug 描述"
          },
          "error_info": {
            "type": "object",
            "description": "错误信息"
          },
          "priority": {
            "type": "string",
            "enum": ["urgent", "high", "medium", "low"],
            "description": "优先级筛选"
          },
          "limit": {
            "type": "integer",
            "description": "返回数量限制"
          },
          "verify": {
            "type": "boolean",
            "description": "是否验证修复结果"
          },
          "time_range": {
            "type": "string",
            "enum": ["today", "week", "month", "all"],
            "description": "时间范围"
          }
        }
      }
    },
    "required": ["operation", "params"]
  }
}
```

---

## 五、实现架构

### 5.1 目录结构

```
src/mcp/tools/
├── test_report.zig              # 测试上报工具主文件
├── test_executor.zig            # 测试执行器
├── bug_analyzer.zig             # Bug 分析器
├── auto_fixer.zig               # 自动修复器
└── test_report/
    ├── models.zig               # 数据模型
    ├── api_client.zig           # API 客户端
    └── utils.zig                # 工具函数
```

### 5.2 核心组件

#### 组件 1：测试执行器 (TestExecutor)

**职责**：
- 执行各类测试（API/单元/集成/E2E）
- 收集测试结果和错误信息
- 生成测试报告

**接口**：
```zig
pub const TestExecutor = struct {
    allocator: std.mem.Allocator,
    
    pub fn execute(
        self: *TestExecutor,
        test_type: TestType,
        test_target: []const u8,
    ) !TestReport;
    
    pub fn executeApiTest(
        self: *TestExecutor,
        endpoint: []const u8,
    ) !TestReport;
    
    pub fn executeUnitTest(
        self: *TestExecutor,
        file_path: []const u8,
    ) !TestReport;
};
```

#### 组件 2：Bug 分析器 (BugAnalyzer)

**职责**：
- 分析错误信息
- 分类 Bug 类型
- 定位问题位置
- 生成修复建议

**接口**：
```zig
pub const BugAnalyzer = struct {
    allocator: std.mem.Allocator,
    
    pub fn analyze(
        self: *BugAnalyzer,
        error_info: ErrorInfo,
    ) !BugAnalysis;
    
    pub fn classifyBugType(
        self: *BugAnalyzer,
        error_message: []const u8,
    ) BugType;
    
    pub fn locateIssue(
        self: *BugAnalyzer,
        stack_trace: []const u8,
    ) IssueLocation;
    
    pub fn generateFixSuggestion(
        self: *BugAnalyzer,
        bug: *const BugAnalysis,
    ) ![]const u8;
};
```

#### 组件 3：自动修复器 (AutoFixer)

**职责**：
- 尝试自动修复 Bug
- 生成修复代码
- 验证修复结果

**接口**：
```zig
pub const AutoFixer = struct {
    allocator: std.mem.Allocator,
    
    pub fn attemptFix(
        self: *AutoFixer,
        bug: *const BugAnalysis,
    ) !FixResult;
    
    pub fn generateFixCode(
        self: *AutoFixer,
        bug: *const BugAnalysis,
    ) ![]const u8;
    
    pub fn verifyFix(
        self: *AutoFixer,
        bug_id: i32,
        test_case: []const u8,
    ) !bool;
};
```

#### 组件 4：API 客户端 (ApiClient)

**职责**：
- 与后端服务通信
- 上报测试结果
- 同步 Bug 状态

**接口**：
```zig
pub const ApiClient = struct {
    allocator: std.mem.Allocator,
    base_url: []const u8,
    
    pub fn reportTest(
        self: *ApiClient,
        report: *const TestReport,
    ) !i32;
    
    pub fn reportBug(
        self: *ApiClient,
        bug: *const BugAnalysis,
    ) !i32;
    
    pub fn getPendingBugs(
        self: *ApiClient,
        priority: ?BugPriority,
        limit: usize,
    ) ![]BugAnalysis;
    
    pub fn updateBugStatus(
        self: *ApiClient,
        bug_id: i32,
        status: BugStatus,
    ) !void;
};
```

---

## 六、使用流程

### 6.1 场景 1：AI 执行测试并自动上报

```json
// 1. AI 执行 API 测试
{
  "name": "test_report",
  "arguments": {
    "operation": "execute",
    "params": {
      "test_type": "api",
      "test_target": "/api/user/login",
      "auto_report": true
    }
  }
}
```

**响应**：
```markdown
# 测试执行结果

**测试类型**: API 测试
**测试目标**: /api/user/login
**执行状态**: ❌ 失败

## 测试统计

| 指标 | 值 |
|------|-----|
| 总用例数 | 5 |
| 通过数 | 3 |
| 失败数 | 2 |
| 通过率 | 60% |
| 执行时长 | 1250ms |

## 失败用例

### 用例 1: 登录-错误密码
- **错误**: 500 Internal Server Error
- **预期**: 401 Unauthorized
- **Bug ID**: 1001 (已自动上报)

### 用例 2: 登录-空用户名
- **错误**: 数据库连接超时
- **预期**: 400 Bad Request
- **Bug ID**: 1002 (已自动上报)

## 自动上报

✅ 已自动上报 2 个 Bug 到后端服务
- Bug #1001: 登录接口返回 500 错误
- Bug #1002: 数据库连接超时

**建议**: 运行 `test_report analyze` 分析这些 Bug
```

### 6.2 场景 2：AI 分析 Bug

```json
// 2. AI 分析 Bug
{
  "name": "test_report",
  "arguments": {
    "operation": "analyze",
    "params": {
      "bug_id": 1001
    }
  }
}
```

**响应**：
```markdown
# Bug 分析结果

**Bug ID**: 1001
**标题**: 登录接口返回 500 错误

## 分类

| 项目 | 值 |
|------|-----|
| Bug 类型 | 功能错误 (functional) |
| 问题位置 | 后端 (backend) |
| 严重程度 | P1 (严重) |
| 优先级 | 高 (high) |
| 置信度 | 92% |

## 根本原因

数据库连接池配置过小，高并发时连接耗尽导致查询失败。

## 问题定位

- **文件**: `src/infrastructure/database/connection_pool.zig`
- **行号**: 45
- **代码**: `max_connections: 10`

## 复现步骤

1. 发送 10 个并发登录请求
2. 观察第 11 个请求返回 500 错误
3. 查看日志显示 "connection pool exhausted"

## 修复建议

将数据库连接池最大连接数从 10 增加到 50：

\`\`\`zig
// src/infrastructure/database/connection_pool.zig:45
max_connections: 50,  // 从 10 增加到 50
\`\`\`

**建议**: 运行 `test_report auto_fix` 尝试自动修复
```

### 6.3 场景 3：AI 检测未处理 Bug

```json
// 3. AI 检测未处理 Bug
{
  "name": "test_report",
  "arguments": {
    "operation": "check_pending",
    "params": {
      "priority": "high",
      "limit": 10
    }
  }
}
```

**响应**：
```markdown
# 未处理 Bug 列表

**筛选条件**: 优先级 = 高
**总数**: 5 个

## Bug 列表

### 1. Bug #1001 - 登录接口返回 500 错误
- **类型**: 功能错误
- **位置**: 后端
- **严重程度**: P1
- **状态**: 已分析
- **创建时间**: 2 小时前
- **建议**: 可尝试自动修复

### 2. Bug #1003 - 用户列表查询超时
- **类型**: 性能问题
- **位置**: 数据库
- **严重程度**: P1
- **状态**: 待分析
- **创建时间**: 1 小时前
- **建议**: 需要分析

### 3. Bug #1005 - 文件上传失败
- **类型**: 功能错误
- **位置**: 后端
- **严重程度**: P1
- **状态**: 已分析
- **创建时间**: 30 分钟前
- **建议**: 可尝试自动修复

## 统计

| 状态 | 数量 |
|------|------|
| 待分析 | 1 |
| 已分析 | 3 |
| 自动修复中 | 1 |

**建议**: 
1. 先分析 Bug #1003
2. 尝试自动修复 Bug #1001 和 #1005
```

### 6.4 场景 4：AI 自动修复 Bug

```json
// 4. AI 自动修复 Bug
{
  "name": "test_report",
  "arguments": {
    "operation": "auto_fix",
    "params": {
      "bug_id": 1001,
      "verify": true
    }
  }
}
```

**响应**：
```markdown
# 自动修复结果

**Bug ID**: 1001
**标题**: 登录接口返回 500 错误

## 修复过程

### 1. 分析修复方案
✅ 已识别问题：数据库连接池配置过小

### 2. 生成修复代码
✅ 已生成修复代码

\`\`\`zig
// src/infrastructure/database/connection_pool.zig
pub const ConnectionPoolConfig = struct {
    max_connections: usize = 50,  // 从 10 增加到 50
    min_connections: usize = 5,
    connection_timeout: u32 = 30,
};
\`\`\`

### 3. 应用修复
✅ 已应用修复到代码

### 4. 验证修复
✅ 重新执行测试
- 测试用例: 登录-错误密码
- 执行结果: ✅ 通过
- 执行时长: 120ms

## 修复结果

| 项目 | 值 |
|------|-----|
| 修复状态 | ✅ 成功 |
| 修复方式 | 自动修复 |
| 验证结果 | ✅ 通过 |
| Bug 状态 | 已自动修复 |

## 修改文件

- `src/infrastructure/database/connection_pool.zig`

## 后续操作

✅ Bug 状态已更新为 "已自动修复"
✅ 已同步到反馈系统
✅ 已通知相关开发者

**建议**: 提交代码并创建 PR
```

---

## 七、后续步骤

### 7.1 实现优先级

**Phase 1: 核心功能**（本次实现）
- [x] 测试执行与上报
- [x] Bug 分析
- [x] 未处理 Bug 检测
- [x] 自动修复

**Phase 2: 增强功能**
- [ ] 支持更多测试类型（UI 测试、性能测试）
- [ ] 集成 Git 操作（自动创建 PR）
- [ ] 支持批量操作
- [ ] 添加测试覆盖率分析

**Phase 3: 智能化**
- [ ] 学习历史修复记录
- [ ] 预测性 Bug 检测
- [ ] 智能测试优先级
- [ ] 自动化回归测试

### 7.2 技术债务

- 需要实现完整的测试执行引擎
- 需要集成 AI 模型进行智能分析
- 需要实现与 Git 的集成
- 需要添加完整的错误处理和日志

---

**老铁，这是一个完整的 MCP 自动测试上报工具设计方案！** 🚀

下一步我将实现核心代码。
