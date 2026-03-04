# 质量中心完善功能 - 技术设计文档

## 概述

质量中心完善功能是一个全面的测试管理和质量保障系统，基于 ZigCMS 后端框架和 Vue 3 + Arco Design 前端技术栈构建。系统遵循整洁架构和 DDD 设计原则，提供测试用例管理、AI 自动生成、项目管理、模块管理、需求管理、数据可视化、反馈管理和脑图 UI 等核心功能。

### 设计目标

1. **安全性优先**: 使用参数化查询防止 SQL 注入，使用 Arena Allocator 和深拷贝确保内存安全
2. **高性能**: 使用关系预加载避免 N+1 查询，使用缓存优化高频查询，使用虚拟渲染优化大数据集渲染
3. **可维护性**: 遵循整洁架构分层，使用 DI 容器管理依赖，使用仓储模式抽象数据访问
4. **可扩展性**: 支持插件化 AI 生成器，支持自定义报表模板，支持多种数据导出格式
5. **用户体验**: 使用 Arco Design 保持 UI 一致性，使用响应式设计适配多端，使用骨架屏优化加载体验

### 技术栈

**后端**:
- Zig 0.13.0
- ZigCMS 框架（整洁架构 + DDD）
- MySQL 8.0（数据库）
- Redis 7.0（缓存）
- ORM/QueryBuilder（数据访问）

**前端**:
- Vue 3.4
- TypeScript 5.3
- Arco Design 2.55
- Pinia（状态管理）
- Vite 5.0（构建工具）
- ECharts 5.5（数据可视化）

**AI 集成**:
- OpenAI API（测试用例生成）
- 自定义 Prompt 模板
- 流式响应支持

## 架构设计

### 整洁架构分层


```
┌─────────────────────────────────────────────────────────────┐
│                      API 层 (api/)                          │
│  - 控制器: 参数解析、响应返回                                │
│  - DTO: 数据传输对象                                         │
│  - 路由: 端点注册                                            │
│  - 中间件: 认证、日志、错误处理                              │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                   应用层 (application/)                      │
│  - 服务: 业务逻辑编排                                        │
│  - 用例: 用户故事实现                                        │
│  - 事件处理: 领域事件订阅                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                    领域层 (domain/)                          │
│  - 实体: 业务对象                                            │
│  - 值对象: 不可变数据                                        │
│  - 仓储接口: 数据访问抽象                                    │
│  - 领域服务: 跨实体业务规则                                  │
│  - 领域事件: 业务事件定义                                    │
└─────────────────────────────────────────────────────────────┘
                            ↓
┌─────────────────────────────────────────────────────────────┐
│                  基础设施层 (infrastructure/)                │
│  - 仓储实现: ORM/QueryBuilder                                │
│  - 缓存实现: Redis                                           │
│  - 外部服务: AI API、邮件服务                                │
│  - 数据库: MySQL 连接池                                      │
└─────────────────────────────────────────────────────────────┘
```

### 模块划分

```
src/
├── domain/
│   ├── entities/
│   │   ├── test_case.model.zig          # 测试用例实体
│   │   ├── test_execution.model.zig     # 测试执行记录实体
│   │   ├── project.model.zig            # 项目实体
│   │   ├── module.model.zig             # 模块实体
│   │   ├── requirement.model.zig        # 需求实体
│   │   ├── feedback.model.zig           # 反馈实体
│   │   ├── bug.model.zig                # Bug 实体
│   │   └── link_record.model.zig        # 关联记录实体
│   ├── repositories/
│   │   ├── test_case_repository.zig     # 测试用例仓储接口
│   │   ├── project_repository.zig       # 项目仓储接口
│   │   ├── module_repository.zig        # 模块仓储接口
│   │   ├── requirement_repository.zig   # 需求仓储接口
│   │   └── feedback_repository.zig      # 反馈仓储接口
│   └── services/
│       └── ai_generator_interface.zig   # AI 生成器接口
├── application/
│   └── services/
│       ├── test_case_service.zig        # 测试用例服务
│       ├── project_service.zig          # 项目服务
│       ├── module_service.zig           # 模块服务
│       ├── requirement_service.zig      # 需求服务
│       ├── feedback_service.zig         # 反馈服务
│       └── statistics_service.zig       # 统计服务
├── infrastructure/
│   ├── database/
│   │   ├── mysql_test_case_repository.zig
│   │   ├── mysql_project_repository.zig
│   │   ├── mysql_module_repository.zig
│   │   ├── mysql_requirement_repository.zig
│   │   └── mysql_feedback_repository.zig
│   ├── ai/
│   │   └── openai_generator.zig         # OpenAI 生成器实现
│   └── cache/
│       └── redis_cache.zig              # Redis 缓存实现
└── api/
    ├── controllers/
    │   ├── test_case.controller.zig     # 测试用例控制器
    │   ├── project.controller.zig       # 项目控制器
    │   ├── module.controller.zig        # 模块控制器
    │   ├── requirement.controller.zig   # 需求控制器
    │   └── feedback.controller.zig      # 反馈控制器
    └── dto/
        ├── test_case_*.dto.zig          # 测试用例 DTO
        ├── project_*.dto.zig            # 项目 DTO
        ├── module_*.dto.zig             # 模块 DTO
        ├── requirement_*.dto.zig        # 需求 DTO
        └── feedback_*.dto.zig           # 反馈 DTO
```

## 数据模型设计

### 核心实体

#### 1. 测试用例 (TestCase)

```zig
pub const TestCase = struct {
    id: ?i32 = null,
    title: []const u8,                    // 标题（必填）
    project_id: i32,                      // 所属项目（必填）
    module_id: i32,                       // 所属模块（必填）
    requirement_id: ?i32 = null,          // 关联需求
    priority: Priority = .medium,         // 优先级
    status: TestCaseStatus = .pending,    // 状态
    precondition: []const u8 = "",        // 前置条件
    steps: []const u8 = "",               // 测试步骤
    expected_result: []const u8 = "",     // 预期结果
    actual_result: []const u8 = "",       // 实际结果
    assignee: ?[]const u8 = null,         // 负责人
    tags: []const u8 = "",                // 标签（JSON 数组）
    created_by: []const u8 = "",          // 创建人
    created_at: ?i64 = null,              // 创建时间
    updated_at: ?i64 = null,              // 更新时间
    
    // 关联数据（预加载）
    executions: ?[]TestExecution = null,  // 执行历史
    requirement: ?Requirement = null,     // 关联需求
    bugs: ?[]Bug = null,                  // 关联 Bug
    
    pub const Priority = enum {
        low,
        medium,
        high,
        critical,
    };
    
    pub const TestCaseStatus = enum {
        pending,      // 待执行
        in_progress,  // 执行中
        passed,       // 已通过
        failed,       // 未通过
        blocked,      // 已阻塞
    };
    
    // 关系定义
    pub const relations = .{
        .executions = .{
            .type = .has_many,
            .model = TestExecution,
            .foreign_key = "test_case_id",
        },
        .requirement = .{
            .type = .belongs_to,
            .model = Requirement,
            .foreign_key = "requirement_id",
        },
        .bugs = .{
            .type = .many_to_many,
            .model = Bug,
            .through = "quality_link_records",
            .foreign_key = "source_id",
            .related_key = "target_id",
        },
    };
};
```


#### 2. 测试执行记录 (TestExecution)

```zig
pub const TestExecution = struct {
    id: ?i32 = null,
    test_case_id: i32,                    // 测试用例 ID
    executor: []const u8,                 // 执行人
    status: ExecutionStatus,              // 执行状态
    actual_result: []const u8 = "",       // 实际结果
    remark: []const u8 = "",              // 备注
    duration_ms: i32 = 0,                 // 执行时长（毫秒）
    executed_at: i64,                     // 执行时间
    
    pub const ExecutionStatus = enum {
        passed,   // 通过
        failed,   // 失败
        blocked,  // 阻塞
    };
};
```

#### 3. 项目 (Project)

```zig
pub const Project = struct {
    id: ?i32 = null,
    name: []const u8,                     // 项目名称（必填）
    description: []const u8,              // 项目描述（必填）
    status: ProjectStatus = .active,      // 项目状态
    owner: []const u8 = "",               // 项目负责人
    members: []const u8 = "",             // 成员列表（JSON 数组）
    settings: []const u8 = "",            // 项目设置（JSON 对象）
    archived: bool = false,               // 是否归档
    created_by: []const u8 = "",          // 创建人
    created_at: ?i64 = null,              // 创建时间
    updated_at: ?i64 = null,              // 更新时间
    
    // 关联数据（预加载）
    modules: ?[]Module = null,            // 模块列表
    test_cases: ?[]TestCase = null,       // 测试用例列表
    requirements: ?[]Requirement = null,  // 需求列表
    
    pub const ProjectStatus = enum {
        active,    // 活跃
        archived,  // 已归档
        closed,    // 已关闭
    };
    
    // 关系定义
    pub const relations = .{
        .modules = .{
            .type = .has_many,
            .model = Module,
            .foreign_key = "project_id",
        },
        .test_cases = .{
            .type = .has_many,
            .model = TestCase,
            .foreign_key = "project_id",
        },
        .requirements = .{
            .type = .has_many,
            .model = Requirement,
            .foreign_key = "project_id",
        },
    };
};
```

#### 4. 模块 (Module)

```zig
pub const Module = struct {
    id: ?i32 = null,
    project_id: i32,                      // 所属项目
    parent_id: ?i32 = null,               // 父模块 ID
    name: []const u8,                     // 模块名称（必填）
    description: []const u8 = "",         // 模块描述
    level: i32 = 1,                       // 层级（1-5）
    sort_order: i32 = 0,                  // 排序
    created_by: []const u8 = "",          // 创建人
    created_at: ?i64 = null,              // 创建时间
    updated_at: ?i64 = null,              // 更新时间
    
    // 关联数据（预加载）
    children: ?[]Module = null,           // 子模块
    test_cases: ?[]TestCase = null,       // 测试用例
    
    // 关系定义
    pub const relations = .{
        .children = .{
            .type = .has_many,
            .model = Module,
            .foreign_key = "parent_id",
        },
        .test_cases = .{
            .type = .has_many,
            .model = TestCase,
            .foreign_key = "module_id",
        },
    };
};
```

#### 5. 需求 (Requirement)

```zig
pub const Requirement = struct {
    id: ?i32 = null,
    project_id: i32,                      // 所属项目（必填）
    title: []const u8,                    // 需求标题（必填）
    description: []const u8,              // 需求描述（必填）
    priority: Priority = .medium,         // 优先级
    status: RequirementStatus = .pending, // 状态
    assignee: ?[]const u8 = null,         // 负责人
    estimated_cases: i32 = 0,             // 建议测试用例数
    actual_cases: i32 = 0,                // 实际测试用例数
    coverage_rate: f32 = 0.0,             // 覆盖率
    created_by: []const u8 = "",          // 创建人
    created_at: ?i64 = null,              // 创建时间
    updated_at: ?i64 = null,              // 更新时间
    
    // 关联数据（预加载）
    test_cases: ?[]TestCase = null,       // 关联测试用例
    
    pub const Priority = enum {
        low,
        medium,
        high,
        critical,
    };
    
    pub const RequirementStatus = enum {
        pending,      // 待评审
        reviewed,     // 已评审
        developing,   // 开发中
        testing,      // 待测试
        in_test,      // 测试中
        completed,    // 已完成
        closed,       // 已关闭
    };
    
    // 关系定义
    pub const relations = .{
        .test_cases = .{
            .type = .has_many,
            .model = TestCase,
            .foreign_key = "requirement_id",
        },
    };
};
```

#### 6. 反馈 (Feedback)

```zig
pub const Feedback = struct {
    id: ?i32 = null,
    title: []const u8,                    // 反馈标题
    content: []const u8,                  // 反馈内容
    type: FeedbackType = .bug,            // 反馈类型
    severity: Severity = .medium,         // 严重程度
    status: FeedbackStatus = .pending,    // 状态
    assignee: ?[]const u8 = null,         // 负责人
    submitter: []const u8 = "",           // 提交人
    follow_ups: []const u8 = "",          // 跟进记录（JSON 数组）
    follow_count: i32 = 0,                // 跟进次数
    last_follow_at: ?i64 = null,          // 最后跟进时间
    created_at: ?i64 = null,              // 创建时间
    updated_at: ?i64 = null,              // 更新时间
    
    pub const FeedbackType = enum {
        bug,          // Bug
        feature,      // 功能建议
        improvement,  // 改进建议
        question,     // 问题咨询
    };
    
    pub const Severity = enum {
        low,
        medium,
        high,
        critical,
    };
    
    pub const FeedbackStatus = enum {
        pending,      // 待处理
        in_progress,  // 处理中
        resolved,     // 已解决
        closed,       // 已关闭
        rejected,     // 已拒绝
    };
};
```

### 数据库表设计

#### 测试用例表 (test_cases)

```sql
CREATE TABLE IF NOT EXISTS test_cases (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    project_id INT NOT NULL,
    module_id INT NOT NULL,
    requirement_id INT DEFAULT NULL,
    priority VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    precondition TEXT NOT NULL,
    steps TEXT NOT NULL,
    expected_result TEXT NOT NULL,
    actual_result TEXT NOT NULL,
    assignee VARCHAR(64) DEFAULT NULL,
    tags TEXT NOT NULL,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_module_id (module_id),
    INDEX idx_requirement_id (requirement_id),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 测试执行记录表 (test_executions)

```sql
CREATE TABLE IF NOT EXISTS test_executions (
    id INT PRIMARY KEY AUTO_INCREMENT,
    test_case_id INT NOT NULL,
    executor VARCHAR(64) NOT NULL,
    status VARCHAR(32) NOT NULL,
    actual_result TEXT NOT NULL,
    remark TEXT NOT NULL,
    duration_ms INT NOT NULL DEFAULT 0,
    executed_at DATETIME NOT NULL,
    INDEX idx_test_case_id (test_case_id),
    INDEX idx_executor (executor),
    INDEX idx_status (status),
    INDEX idx_executed_at (executed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 项目表 (projects)

```sql
CREATE TABLE IF NOT EXISTS projects (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(200) NOT NULL,
    description VARCHAR(500) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'active',
    owner VARCHAR(64) NOT NULL DEFAULT '',
    members TEXT NOT NULL,
    settings TEXT NOT NULL,
    archived TINYINT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_status (status),
    INDEX idx_owner (owner),
    INDEX idx_archived (archived)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 模块表 (modules)

```sql
CREATE TABLE IF NOT EXISTS modules (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    parent_id INT DEFAULT NULL,
    name VARCHAR(200) NOT NULL,
    description VARCHAR(500) NOT NULL DEFAULT '',
    level INT NOT NULL DEFAULT 1,
    sort_order INT NOT NULL DEFAULT 0,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_parent_id (parent_id),
    INDEX idx_level (level),
    UNIQUE KEY uk_project_parent_name (project_id, parent_id, name)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 需求表 (requirements)

```sql
CREATE TABLE IF NOT EXISTS requirements (
    id INT PRIMARY KEY AUTO_INCREMENT,
    project_id INT NOT NULL,
    title VARCHAR(200) NOT NULL,
    description TEXT NOT NULL,
    priority VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    assignee VARCHAR(64) DEFAULT NULL,
    estimated_cases INT NOT NULL DEFAULT 0,
    actual_cases INT NOT NULL DEFAULT 0,
    coverage_rate DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_priority (priority)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```

#### 反馈表 (feedbacks)

```sql
CREATE TABLE IF NOT EXISTS feedbacks (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    content TEXT NOT NULL,
    type VARCHAR(32) NOT NULL DEFAULT 'bug',
    severity VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    assignee VARCHAR(64) DEFAULT NULL,
    submitter VARCHAR(64) NOT NULL DEFAULT '',
    follow_ups TEXT NOT NULL,
    follow_count INT NOT NULL DEFAULT 0,
    last_follow_at DATETIME DEFAULT NULL,
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_type (type),
    INDEX idx_severity (severity),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_submitter (submitter)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
```


## 组件和接口设计

### 仓储接口设计

#### 测试用例仓储接口

```zig
// src/domain/repositories/test_case_repository.zig
pub const TestCaseRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?TestCase,
        findByProject: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult(TestCase),
        findByModule: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult(TestCase),
        save: *const fn (*anyopaque, *TestCase) anyerror!void,
        delete: *const fn (*anyopaque, i32) anyerror!void,
        batchDelete: *const fn (*anyopaque, []const i32) anyerror!void,
        batchUpdateStatus: *const fn (*anyopaque, []const i32, TestCaseStatus) anyerror!void,
        batchUpdateAssignee: *const fn (*anyopaque, []const i32, []const u8) anyerror!void,
        search: *const fn (*anyopaque, SearchQuery) anyerror!PageResult(TestCase),
    };
    
    pub fn findById(self: *Self, id: i32) !?TestCase {
        return self.vtable.findById(self.ptr, id);
    }
    
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(TestCase) {
        return self.vtable.findByProject(self.ptr, project_id, query);
    }
    
    // ... 其他方法
};

pub const PageQuery = struct {
    page: i32 = 1,
    page_size: i32 = 20,
};

pub const SearchQuery = struct {
    project_id: ?i32 = null,
    module_id: ?i32 = null,
    status: ?TestCaseStatus = null,
    assignee: ?[]const u8 = null,
    keyword: ?[]const u8 = null,
    page: i32 = 1,
    page_size: i32 = 20,
};

pub fn PageResult(comptime T: type) type {
    return struct {
        items: []T,
        total: i32,
        page: i32,
        page_size: i32,
    };
}
```

### 服务层设计

#### 测试用例服务

```zig
// src/application/services/test_case_service.zig
pub const TestCaseService = struct {
    allocator: Allocator,
    test_case_repo: TestCaseRepository,
    execution_repo: TestExecutionRepository,
    cache: *CacheInterface,
    
    pub fn init(
        allocator: Allocator,
        test_case_repo: TestCaseRepository,
        execution_repo: TestExecutionRepository,
        cache: *CacheInterface,
    ) TestCaseService {
        return .{
            .allocator = allocator,
            .test_case_repo = test_case_repo,
            .execution_repo = execution_repo,
            .cache = cache,
        };
    }
    
    /// 创建测试用例
    pub fn create(self: *Self, dto: CreateTestCaseDto) !TestCase {
        // 1. 验证必填字段
        if (dto.title.len == 0) return error.TitleRequired;
        if (dto.project_id == 0) return error.ProjectIdRequired;
        if (dto.module_id == 0) return error.ModuleIdRequired;
        
        // 2. 创建测试用例
        var test_case = TestCase{
            .title = dto.title,
            .project_id = dto.project_id,
            .module_id = dto.module_id,
            .requirement_id = dto.requirement_id,
            .priority = dto.priority,
            .precondition = dto.precondition,
            .steps = dto.steps,
            .expected_result = dto.expected_result,
            .assignee = dto.assignee,
            .tags = dto.tags,
            .created_by = dto.created_by,
        };
        
        try self.test_case_repo.save(&test_case);
        
        // 3. 清除相关缓存
        try self.clearProjectCache(dto.project_id);
        try self.clearModuleCache(dto.module_id);
        
        return test_case;
    }
    
    /// 批量删除测试用例
    pub fn batchDelete(self: *Self, ids: []const i32) !void {
        // 1. 查询测试用例获取项目和模块 ID
        var project_ids = std.AutoHashMap(i32, void).init(self.allocator);
        defer project_ids.deinit();
        
        var module_ids = std.AutoHashMap(i32, void).init(self.allocator);
        defer module_ids.deinit();
        
        for (ids) |id| {
            if (try self.test_case_repo.findById(id)) |test_case| {
                defer {
                    self.allocator.free(test_case.title);
                    // ... 释放其他字符串字段
                }
                try project_ids.put(test_case.project_id, {});
                try module_ids.put(test_case.module_id, {});
            }
        }
        
        // 2. 批量删除
        try self.test_case_repo.batchDelete(ids);
        
        // 3. 清除相关缓存
        var project_it = project_ids.keyIterator();
        while (project_it.next()) |project_id| {
            try self.clearProjectCache(project_id.*);
        }
        
        var module_it = module_ids.keyIterator();
        while (module_it.next()) |module_id| {
            try self.clearModuleCache(module_id.*);
        }
    }
    
    /// 执行测试用例
    pub fn execute(self: *Self, dto: ExecuteTestCaseDto) !TestExecution {
        // 1. 查询测试用例
        const test_case = try self.test_case_repo.findById(dto.test_case_id) orelse {
            return error.TestCaseNotFound;
        };
        defer {
            self.allocator.free(test_case.title);
            // ... 释放其他字符串字段
        }
        
        // 2. 创建执行记录
        var execution = TestExecution{
            .test_case_id = dto.test_case_id,
            .executor = dto.executor,
            .status = dto.status,
            .actual_result = dto.actual_result,
            .remark = dto.remark,
            .duration_ms = dto.duration_ms,
            .executed_at = std.time.timestamp(),
        };
        
        try self.execution_repo.save(&execution);
        
        // 3. 更新测试用例状态
        var updated_case = test_case;
        updated_case.status = switch (dto.status) {
            .passed => .passed,
            .failed => .failed,
            .blocked => .blocked,
        };
        updated_case.actual_result = dto.actual_result;
        
        try self.test_case_repo.save(&updated_case);
        
        // 4. 清除缓存
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "test_case:{d}",
            .{dto.test_case_id},
        );
        defer self.allocator.free(cache_key);
        try self.cache.del(cache_key);
        
        return execution;
    }
    
    /// 搜索测试用例（带缓存）
    pub fn search(self: *Self, query: SearchQuery) !PageResult(TestCase) {
        // 1. 构建缓存键
        const cache_key = try self.buildSearchCacheKey(query);
        defer self.allocator.free(cache_key);
        
        // 2. 尝试从缓存获取
        if (self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializePageResult(cached);
        }
        
        // 3. 从数据库查询
        const result = try self.test_case_repo.search(query);
        
        // 4. 缓存结果（5 分钟）
        const json = try self.serializePageResult(result);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, 300);
        
        return result;
    }
    
    fn clearProjectCache(self: *Self, project_id: i32) !void {
        const prefix = try std.fmt.allocPrint(
            self.allocator,
            "project:{d}:",
            .{project_id},
        );
        defer self.allocator.free(prefix);
        try self.cache.delByPrefix(prefix);
    }
    
    fn clearModuleCache(self: *Self, module_id: i32) !void {
        const prefix = try std.fmt.allocPrint(
            self.allocator,
            "module:{d}:",
            .{module_id},
        );
        defer self.allocator.free(prefix);
        try self.cache.delByPrefix(prefix);
    }
};
```

### AI 生成器设计

#### AI 生成器接口

```zig
// src/domain/services/ai_generator_interface.zig
pub const AIGeneratorInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,
    
    pub const VTable = struct {
        generateTestCases: *const fn (
            *anyopaque,
            Requirement,
            GenerateOptions,
        ) anyerror![]GeneratedTestCase,
        generateRequirement: *const fn (
            *anyopaque,
            []const u8,
            GenerateOptions,
        ) anyerror!GeneratedRequirement,
        analyzeFeedback: *const fn (
            *anyopaque,
            []const u8,
        ) anyerror!FeedbackAnalysis,
    };
    
    pub fn generateTestCases(
        self: *Self,
        requirement: Requirement,
        options: GenerateOptions,
    ) ![]GeneratedTestCase {
        return self.vtable.generateTestCases(self.ptr, requirement, options);
    }
};

pub const GenerateOptions = struct {
    max_cases: i32 = 10,
    include_edge_cases: bool = true,
    include_performance: bool = false,
    language: []const u8 = "zh-CN",
};

pub const GeneratedTestCase = struct {
    title: []const u8,
    precondition: []const u8,
    steps: []const u8,
    expected_result: []const u8,
    priority: TestCase.Priority,
    tags: []const []const u8,
};

pub const GeneratedRequirement = struct {
    title: []const u8,
    description: []const u8,
    priority: Requirement.Priority,
    estimated_cases: i32,
};

pub const FeedbackAnalysis = struct {
    bug_type: []const u8,
    severity: Feedback.Severity,
    affected_modules: []const []const u8,
    suggested_actions: []const []const u8,
};
```

#### OpenAI 生成器实现

```zig
// src/infrastructure/ai/openai_generator.zig
pub const OpenAIGenerator = struct {
    allocator: Allocator,
    api_key: []const u8,
    base_url: []const u8,
    model: []const u8 = "gpt-4",
    
    pub fn init(allocator: Allocator, api_key: []const u8, base_url: []const u8) OpenAIGenerator {
        return .{
            .allocator = allocator,
            .api_key = api_key,
            .base_url = base_url,
        };
    }
    
    pub fn generateTestCases(
        self: *Self,
        requirement: Requirement,
        options: GenerateOptions,
    ) ![]GeneratedTestCase {
        // 1. 构建 Prompt
        const prompt = try self.buildTestCasePrompt(requirement, options);
        defer self.allocator.free(prompt);
        
        // 2. 调用 OpenAI API
        const response = try self.callOpenAI(prompt);
        defer self.allocator.free(response);
        
        // 3. 解析响应
        return try self.parseTestCaseResponse(response);
    }
    
    fn buildTestCasePrompt(
        self: *Self,
        requirement: Requirement,
        options: GenerateOptions,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            \\你是一个专业的测试工程师。请根据以下需求生成测试用例。
            \\
            \\需求标题: {s}
            \\需求描述: {s}
            \\优先级: {s}
            \\
            \\要求:
            \\1. 生成最多 {d} 个测试用例
            \\2. 包含正常流程、边界条件、异常场景
            \\3. 每个测试用例包含: 标题、前置条件、测试步骤、预期结果、优先级、标签
            \\4. 使用 JSON 格式返回
            \\
            \\返回格式:
            \\{{
            \\  "test_cases": [
            \\    {{
            \\      "title": "测试用例标题",
            \\      "precondition": "前置条件",
            \\      "steps": "测试步骤",
            \\      "expected_result": "预期结果",
            \\      "priority": "high|medium|low",
            \\      "tags": ["标签1", "标签2"]
            \\    }}
            \\  ]
            \\}}
        ,
            .{
                requirement.title,
                requirement.description,
                @tagName(requirement.priority),
                options.max_cases,
            },
        );
    }
    
    fn callOpenAI(self: *Self, prompt: []const u8) ![]const u8 {
        // 1. 构建请求体
        const request_body = try std.fmt.allocPrint(
            self.allocator,
            \\{{
            \\  "model": "{s}",
            \\  "messages": [
            \\    {{
            \\      "role": "user",
            \\      "content": "{s}"
            \\    }}
            \\  ],
            \\  "temperature": 0.7,
            \\  "max_tokens": 2000
            \\}}
        ,
            .{ self.model, prompt },
        );
        defer self.allocator.free(request_body);
        
        // 2. 发送 HTTP 请求
        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();
        
        const uri = try std.Uri.parse(try std.fmt.allocPrint(
            self.allocator,
            "{s}/v1/chat/completions",
            .{self.base_url},
        ));
        
        var headers = std.http.Headers{ .allocator = self.allocator };
        defer headers.deinit();
        
        try headers.append("Authorization", try std.fmt.allocPrint(
            self.allocator,
            "Bearer {s}",
            .{self.api_key},
        ));
        try headers.append("Content-Type", "application/json");
        
        var request = try client.request(.POST, uri, headers, .{});
        defer request.deinit();
        
        try request.writer().writeAll(request_body);
        try request.finish();
        try request.wait();
        
        // 3. 读取响应
        const response_body = try request.reader().readAllAlloc(
            self.allocator,
            10 * 1024 * 1024, // 10MB
        );
        
        return response_body;
    }
    
    fn parseTestCaseResponse(self: *Self, response: []const u8) ![]GeneratedTestCase {
        // 解析 JSON 响应
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();
        
        const root = parsed.value.object;
        const choices = root.get("choices").?.array;
        const message = choices.items[0].object.get("message").?.object;
        const content = message.get("content").?.string;
        
        // 解析测试用例
        var test_cases_parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content,
            .{},
        );
        defer test_cases_parsed.deinit();
        
        const test_cases_array = test_cases_parsed.value.object.get("test_cases").?.array;
        
        var result = std.ArrayList(GeneratedTestCase).init(self.allocator);
        defer result.deinit();
        
        for (test_cases_array.items) |item| {
            const obj = item.object;
            
            const title = try self.allocator.dupe(u8, obj.get("title").?.string);
            const precondition = try self.allocator.dupe(u8, obj.get("precondition").?.string);
            const steps = try self.allocator.dupe(u8, obj.get("steps").?.string);
            const expected_result = try self.allocator.dupe(u8, obj.get("expected_result").?.string);
            
            const priority_str = obj.get("priority").?.string;
            const priority = std.meta.stringToEnum(TestCase.Priority, priority_str) orelse .medium;
            
            const tags_array = obj.get("tags").?.array;
            var tags = std.ArrayList([]const u8).init(self.allocator);
            for (tags_array.items) |tag| {
                try tags.append(try self.allocator.dupe(u8, tag.string));
            }
            
            try result.append(.{
                .title = title,
                .precondition = precondition,
                .steps = steps,
                .expected_result = expected_result,
                .priority = priority,
                .tags = try tags.toOwnedSlice(),
            });
        }
        
        return try result.toOwnedSlice();
    }
};
```


### API 接口设计

#### RESTful API 端点

```
# 测试用例管理
POST   /api/quality/test-cases              # 创建测试用例
GET    /api/quality/test-cases/:id          # 获取测试用例详情
PUT    /api/quality/test-cases/:id          # 更新测试用例
DELETE /api/quality/test-cases/:id          # 删除测试用例
GET    /api/quality/test-cases              # 查询测试用例列表
POST   /api/quality/test-cases/batch-delete # 批量删除
POST   /api/quality/test-cases/batch-update-status # 批量更新状态
POST   /api/quality/test-cases/batch-update-assignee # 批量分配负责人
POST   /api/quality/test-cases/:id/execute  # 执行测试用例
GET    /api/quality/test-cases/:id/executions # 获取执行历史

# AI 生成
POST   /api/quality/ai/generate-test-cases  # 生成测试用例
POST   /api/quality/ai/generate-requirement # 生成需求
POST   /api/quality/ai/analyze-feedback     # 分析反馈

# 项目管理
POST   /api/quality/projects                # 创建项目
GET    /api/quality/projects/:id            # 获取项目详情
PUT    /api/quality/projects/:id            # 更新项目
DELETE /api/quality/projects/:id            # 删除项目
GET    /api/quality/projects                # 查询项目列表
POST   /api/quality/projects/:id/archive    # 归档项目
POST   /api/quality/projects/:id/restore    # 恢复项目
GET    /api/quality/projects/:id/statistics # 获取项目统计

# 模块管理
POST   /api/quality/modules                 # 创建模块
GET    /api/quality/modules/:id             # 获取模块详情
PUT    /api/quality/modules/:id             # 更新模块
DELETE /api/quality/modules/:id             # 删除模块
GET    /api/quality/modules/tree            # 获取模块树
POST   /api/quality/modules/:id/move        # 移动模块
GET    /api/quality/modules/:id/statistics  # 获取模块统计

# 需求管理
POST   /api/quality/requirements            # 创建需求
GET    /api/quality/requirements/:id        # 获取需求详情
PUT    /api/quality/requirements/:id        # 更新需求
DELETE /api/quality/requirements/:id        # 删除需求
GET    /api/quality/requirements            # 查询需求列表
POST   /api/quality/requirements/:id/link-test-case # 关联测试用例
DELETE /api/quality/requirements/:id/unlink-test-case/:case_id # 取消关联
POST   /api/quality/requirements/import     # 导入需求
GET    /api/quality/requirements/export     # 导出需求

# 反馈管理
POST   /api/quality/feedbacks               # 创建反馈
GET    /api/quality/feedbacks/:id           # 获取反馈详情
PUT    /api/quality/feedbacks/:id           # 更新反馈
DELETE /api/quality/feedbacks/:id           # 删除反馈
GET    /api/quality/feedbacks               # 查询反馈列表
POST   /api/quality/feedbacks/:id/follow-up # 添加跟进记录
POST   /api/quality/feedbacks/batch-assign  # 批量指派
POST   /api/quality/feedbacks/batch-update-status # 批量更新状态
GET    /api/quality/feedbacks/export        # 导出反馈

# 数据可视化
GET    /api/quality/statistics/module-distribution # 模块质量分布
GET    /api/quality/statistics/bug-distribution    # Bug 质量分布
GET    /api/quality/statistics/feedback-distribution # 反馈状态分布
GET    /api/quality/statistics/quality-trend       # 质量趋势
GET    /api/quality/statistics/export              # 导出图表
```

#### 控制器实现示例

```zig
// src/api/controllers/test_case.controller.zig
const std = @import("std");
const zap = @import("zap");
const zigcms = @import("zigcms");
const base = @import("../base.zig");

pub fn create(req: zap.Request) !void {
    // 1. 解析请求体
    const body = try req.parseBody(CreateTestCaseDto);
    
    // 2. 获取服务
    const container = zigcms.core.di.getGlobalContainer();
    const service = try container.resolve(TestCaseService);
    
    // 3. 调用服务
    const test_case = try service.create(body);
    
    // 4. 返回响应
    try base.send_success(req, test_case);
}

pub fn batchDelete(req: zap.Request) !void {
    // 1. 解析请求体
    const body = try req.parseBody(BatchDeleteDto);
    
    // 2. 验证参数
    if (body.ids.len == 0) {
        return base.send_error(req, 400, "ids 不能为空");
    }
    
    if (body.ids.len > 1000) {
        return base.send_error(req, 400, "最多支持 1000 条记录");
    }
    
    // 3. 获取服务
    const container = zigcms.core.di.getGlobalContainer();
    const service = try container.resolve(TestCaseService);
    
    // 4. 调用服务
    try service.batchDelete(body.ids);
    
    // 5. 返回响应
    try base.send_success(req, .{ .message = "批量删除成功" });
}

pub fn execute(req: zap.Request) !void {
    // 1. 解析路径参数
    const id = try req.getParamInt("id") orelse return error.InvalidId;
    
    // 2. 解析请求体
    const body = try req.parseBody(ExecuteTestCaseDto);
    body.test_case_id = id;
    
    // 3. 获取服务
    const container = zigcms.core.di.getGlobalContainer();
    const service = try container.resolve(TestCaseService);
    
    // 4. 调用服务
    const execution = try service.execute(body);
    
    // 5. 返回响应
    try base.send_success(req, execution);
}

pub fn search(req: zap.Request) !void {
    // 1. 解析查询参数
    const query = SearchQuery{
        .project_id = req.getParamInt("project_id"),
        .module_id = req.getParamInt("module_id"),
        .status = if (req.getParam("status")) |s| 
            std.meta.stringToEnum(TestCaseStatus, s) 
        else null,
        .assignee = req.getParam("assignee"),
        .keyword = req.getParam("keyword"),
        .page = req.getParamInt("page") orelse 1,
        .page_size = req.getParamInt("page_size") orelse 20,
    };
    
    // 2. 获取服务
    const container = zigcms.core.di.getGlobalContainer();
    const service = try container.resolve(TestCaseService);
    
    // 3. 调用服务
    const result = try service.search(query);
    
    // 4. 返回响应
    try base.send_success(req, result);
}
```

#### DTO 定义

```zig
// src/api/dto/test_case_create.dto.zig
pub const CreateTestCaseDto = struct {
    title: []const u8,
    project_id: i32,
    module_id: i32,
    requirement_id: ?i32 = null,
    priority: TestCase.Priority = .medium,
    precondition: []const u8 = "",
    steps: []const u8 = "",
    expected_result: []const u8 = "",
    assignee: ?[]const u8 = null,
    tags: []const u8 = "",
    created_by: []const u8 = "",
};

// src/api/dto/test_case_execute.dto.zig
pub const ExecuteTestCaseDto = struct {
    test_case_id: i32,
    executor: []const u8,
    status: TestExecution.ExecutionStatus,
    actual_result: []const u8 = "",
    remark: []const u8 = "",
    duration_ms: i32 = 0,
};

// src/api/dto/batch_delete.dto.zig
pub const BatchDeleteDto = struct {
    ids: []const i32,
};

// src/api/dto/batch_update_status.dto.zig
pub const BatchUpdateStatusDto = struct {
    ids: []const i32,
    status: TestCaseStatus,
};

// src/api/dto/batch_update_assignee.dto.zig
pub const BatchUpdateAssigneeDto = struct {
    ids: []const i32,
    assignee: []const u8,
};
```

## 前端组件设计

### 组件结构

```
ecom-admin/src/views/quality-center/
├── dashboard/
│   ├── index.vue                    # 质量中心首页
│   ├── components/
│   │   ├── ModuleDistribution.vue   # 模块质量分布图
│   │   ├── BugDistribution.vue      # Bug 质量分布图
│   │   ├── FeedbackDistribution.vue # 反馈状态分布图
│   │   └── QualityTrend.vue         # 质量趋势图
├── test-case/
│   ├── index.vue                    # 测试用例列表
│   ├── detail.vue                   # 测试用例详情
│   ├── create.vue                   # 创建测试用例
│   ├── edit.vue                     # 编辑测试用例
│   └── components/
│       ├── TestCaseTable.vue        # 测试用例表格
│       ├── TestCaseForm.vue         # 测试用例表单
│       ├── ExecutionHistory.vue     # 执行历史
│       └── AIGenerateDialog.vue     # AI 生成对话框
├── project/
│   ├── index.vue                    # 项目列表
│   ├── detail.vue                   # 项目详情
│   └── components/
│       ├── ProjectCard.vue          # 项目卡片
│       ├── ProjectForm.vue          # 项目表单
│       └── ProjectStatistics.vue    # 项目统计
├── module/
│   ├── index.vue                    # 模块管理
│   └── components/
│       ├── ModuleTree.vue           # 模块树
│       ├── ModuleForm.vue           # 模块表单
│       └── ModuleStatistics.vue     # 模块统计
├── requirement/
│   ├── index.vue                    # 需求列表
│   ├── detail.vue                   # 需求详情
│   └── components/
│       ├── RequirementTable.vue     # 需求表格
│       ├── RequirementForm.vue      # 需求表单
│       └── LinkedTestCases.vue      # 关联测试用例
├── feedback/
│   ├── index.vue                    # 反馈列表
│   ├── detail.vue                   # 反馈详情
│   └── components/
│       ├── FeedbackTable.vue        # 反馈表格
│       ├── FeedbackForm.vue         # 反馈表单
│       └── FollowUpTimeline.vue     # 跟进时间线
└── mindmap/
    ├── index.vue                    # 脑图视图
    └── components/
        ├── MindMapCanvas.vue        # 脑图画布
        └── MindMapNode.vue          # 脑图节点
```

### 核心组件实现

#### 测试用例表格组件

```vue
<!-- ecom-admin/src/views/quality-center/test-case/components/TestCaseTable.vue -->
<template>
  <div class="test-case-table">
    <a-table
      :columns="columns"
      :data="data"
      :loading="loading"
      :pagination="pagination"
      :row-selection="rowSelection"
      @page-change="handlePageChange"
      @page-size-change="handlePageSizeChange"
    >
      <template #status="{ record }">
        <a-tag :color="getStatusColor(record.status)">
          {{ getStatusText(record.status) }}
        </a-tag>
      </template>
      
      <template #priority="{ record }">
        <a-tag :color="getPriorityColor(record.priority)">
          {{ getPriorityText(record.priority) }}
        </a-tag>
      </template>
      
      <template #actions="{ record }">
        <a-space>
          <a-button type="text" size="small" @click="handleView(record)">
            查看
          </a-button>
          <a-button type="text" size="small" @click="handleEdit(record)">
            编辑
          </a-button>
          <a-button type="text" size="small" @click="handleExecute(record)">
            执行
          </a-button>
          <a-popconfirm
            content="确定删除该测试用例吗？"
            @ok="handleDelete(record)"
          >
            <a-button type="text" size="small" status="danger">
              删除
            </a-button>
          </a-popconfirm>
        </a-space>
      </template>
    </a-table>
    
    <!-- 批量操作栏 -->
    <div v-if="selectedKeys.length > 0" class="batch-actions">
      <a-space>
        <span>已选择 {{ selectedKeys.length }} 项</span>
        <a-button @click="handleBatchDelete">批量删除</a-button>
        <a-button @click="handleBatchUpdateStatus">批量更新状态</a-button>
        <a-button @click="handleBatchAssign">批量分配</a-button>
      </a-space>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { Message } from '@arco-design/web-vue';
import { qualityCenterApi } from '@/api/quality-center';

const props = defineProps<{
  projectId?: number;
  moduleId?: number;
}>();

const emit = defineEmits<{
  refresh: [];
}>();

const loading = ref(false);
const data = ref<TestCase[]>([]);
const selectedKeys = ref<number[]>([]);
const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0,
});

const columns = [
  { title: 'ID', dataIndex: 'id', width: 80 },
  { title: '标题', dataIndex: 'title', width: 200 },
  { title: '状态', slotName: 'status', width: 100 },
  { title: '优先级', slotName: 'priority', width: 100 },
  { title: '负责人', dataIndex: 'assignee', width: 120 },
  { title: '创建时间', dataIndex: 'created_at', width: 180 },
  { title: '操作', slotName: 'actions', width: 200, fixed: 'right' },
];

const rowSelection = computed(() => ({
  type: 'checkbox',
  selectedRowKeys: selectedKeys.value,
  onSelect: (rowKeys: number[]) => {
    selectedKeys.value = rowKeys;
  },
}));

const loadData = async () => {
  loading.value = true;
  try {
    const res = await qualityCenterApi.searchTestCases({
      project_id: props.projectId,
      module_id: props.moduleId,
      page: pagination.value.current,
      page_size: pagination.value.pageSize,
    });
    data.value = res.items;
    pagination.value.total = res.total;
  } catch (error) {
    Message.error('加载失败');
  } finally {
    loading.value = false;
  }
};

const handlePageChange = (page: number) => {
  pagination.value.current = page;
  loadData();
};

const handlePageSizeChange = (pageSize: number) => {
  pagination.value.pageSize = pageSize;
  pagination.value.current = 1;
  loadData();
};

const handleBatchDelete = async () => {
  if (selectedKeys.value.length === 0) return;
  
  try {
    await qualityCenterApi.batchDeleteTestCases(selectedKeys.value);
    Message.success('批量删除成功');
    selectedKeys.value = [];
    loadData();
  } catch (error) {
    Message.error('批量删除失败');
  }
};

// 初始化加载
loadData();
</script>
```

#### AI 生成对话框组件

```vue
<!-- ecom-admin/src/views/quality-center/test-case/components/AIGenerateDialog.vue -->
<template>
  <a-modal
    v-model:visible="visible"
    title="AI 生成测试用例"
    width="800px"
    :footer="false"
  >
    <div class="ai-generate-dialog">
      <!-- 步骤 1: 选择需求 -->
      <div v-if="step === 1" class="step-content">
        <h3>选择需求</h3>
        <a-select
          v-model="selectedRequirementId"
          placeholder="请选择需求"
          :loading="loadingRequirements"
          style="width: 100%"
        >
          <a-option
            v-for="req in requirements"
            :key="req.id"
            :value="req.id"
          >
            {{ req.title }}
          </a-option>
        </a-select>
        
        <div class="requirement-detail" v-if="selectedRequirement">
          <h4>需求详情</h4>
          <p>{{ selectedRequirement.description }}</p>
        </div>
        
        <div class="actions">
          <a-button @click="visible = false">取消</a-button>
          <a-button
            type="primary"
            :disabled="!selectedRequirementId"
            @click="handleGenerate"
          >
            开始生成
          </a-button>
        </div>
      </div>
      
      <!-- 步骤 2: 生成中 -->
      <div v-if="step === 2" class="step-content">
        <div class="generating">
          <a-spin :size="48" />
          <p>AI 正在分析需求并生成测试用例...</p>
          <a-progress :percent="progress" />
          <p class="progress-text">{{ progressText }}</p>
        </div>
      </div>
      
      <!-- 步骤 3: 预览和编辑 -->
      <div v-if="step === 3" class="step-content">
        <h3>生成结果预览（共 {{ generatedCases.length }} 个）</h3>
        
        <div class="generated-cases">
          <div
            v-for="(testCase, index) in generatedCases"
            :key="index"
            class="case-item"
          >
            <div class="case-header">
              <a-checkbox v-model="testCase.selected" />
              <a-input
                v-model="testCase.title"
                placeholder="测试用例标题"
              />
              <a-select v-model="testCase.priority" style="width: 120px">
                <a-option value="low">低</a-option>
                <a-option value="medium">中</a-option>
                <a-option value="high">高</a-option>
                <a-option value="critical">紧急</a-option>
              </a-select>
            </div>
            
            <a-textarea
              v-model="testCase.precondition"
              placeholder="前置条件"
              :auto-size="{ minRows: 2, maxRows: 4 }"
            />
            
            <a-textarea
              v-model="testCase.steps"
              placeholder="测试步骤"
              :auto-size="{ minRows: 3, maxRows: 6 }"
            />
            
            <a-textarea
              v-model="testCase.expected_result"
              placeholder="预期结果"
              :auto-size="{ minRows: 2, maxRows: 4 }"
            />
          </div>
        </div>
        
        <div class="actions">
          <a-button @click="handleRegenerate">重新生成</a-button>
          <a-space>
            <a-button @click="visible = false">取消</a-button>
            <a-button
              type="primary"
              :loading="saving"
              @click="handleSave"
            >
              保存选中的用例
            </a-button>
          </a-space>
        </div>
      </div>
    </div>
  </a-modal>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
import { Message } from '@arco-design/web-vue';
import { qualityCenterApi } from '@/api/quality-center';

const visible = ref(false);
const step = ref(1); // 1: 选择需求, 2: 生成中, 3: 预览编辑
const selectedRequirementId = ref<number>();
const requirements = ref<Requirement[]>([]);
const loadingRequirements = ref(false);
const generatedCases = ref<GeneratedTestCase[]>([]);
const progress = ref(0);
const progressText = ref('');
const saving = ref(false);

const selectedRequirement = computed(() => {
  return requirements.value.find(r => r.id === selectedRequirementId.value);
});

const loadRequirements = async () => {
  loadingRequirements.value = true;
  try {
    const res = await qualityCenterApi.getRequirements();
    requirements.value = res.items;
  } catch (error) {
    Message.error('加载需求失败');
  } finally {
    loadingRequirements.value = false;
  }
};

const handleGenerate = async () => {
  if (!selectedRequirementId.value) return;
  
  step.value = 2;
  progress.value = 0;
  progressText.value = '正在分析需求...';
  
  // 模拟进度更新
  const progressInterval = setInterval(() => {
    if (progress.value < 90) {
      progress.value += 10;
      if (progress.value < 30) {
        progressText.value = '正在分析需求...';
      } else if (progress.value < 60) {
        progressText.value = '正在识别测试点...';
      } else {
        progressText.value = '正在生成测试用例...';
      }
    }
  }, 500);
  
  try {
    const res = await qualityCenterApi.generateTestCases({
      requirement_id: selectedRequirementId.value,
      max_cases: 10,
      include_edge_cases: true,
    });
    
    clearInterval(progressInterval);
    progress.value = 100;
    progressText.value = '生成完成！';
    
    generatedCases.value = res.test_cases.map(tc => ({
      ...tc,
      selected: true,
    }));
    
    setTimeout(() => {
      step.value = 3;
    }, 500);
  } catch (error) {
    clearInterval(progressInterval);
    Message.error('生成失败');
    step.value = 1;
  }
};

const handleSave = async () => {
  const selectedCases = generatedCases.value.filter(c => c.selected);
  if (selectedCases.length === 0) {
    Message.warning('请至少选择一个测试用例');
    return;
  }
  
  saving.value = true;
  try {
    await qualityCenterApi.batchCreateTestCases(selectedCases);
    Message.success(`成功保存 ${selectedCases.length} 个测试用例`);
    visible.value = false;
    emit('success');
  } catch (error) {
    Message.error('保存失败');
  } finally {
    saving.value = false;
  }
};

const open = () => {
  visible.value = true;
  step.value = 1;
  selectedRequirementId.value = undefined;
  generatedCases.value = [];
  loadRequirements();
};

defineExpose({ open });

const emit = defineEmits<{
  success: [];
}>();
</script>
```


## 性能优化设计

### 1. 数据库查询优化

#### 关系预加载（避免 N+1 查询）

```zig
// ✅ 推荐：使用关系预加载
pub fn getProjectWithDetails(self: *Self, project_id: i32) !Project {
    var q = OrmProject.Query();
    defer q.deinit();
    
    // 一次性预加载所有关联数据
    _ = q.where("id", "=", project_id)
         .with(&.{ "modules", "test_cases", "requirements" });
    
    const projects = try q.get();
    defer OrmProject.freeModels(projects);
    
    if (projects.len == 0) return error.ProjectNotFound;
    
    // 深拷贝字符串字段
    return try self.deepCopyProject(projects[0]);
}

// ❌ 避免：N+1 查询
pub fn getProjectWithDetailsBad(self: *Self, project_id: i32) !Project {
    // 1 次查询项目
    const project = try self.project_repo.findById(project_id);
    
    // N 次查询模块
    for (modules) |module| {
        const test_cases = try self.test_case_repo.findByModule(module.id);
    }
    
    return project;
}
```

#### 批量查询优化

```zig
// ✅ 推荐：使用 whereIn 批量查询
pub fn getTestCasesByIds(self: *Self, ids: []const i32) ![]TestCase {
    var q = OrmTestCase.Query();
    defer q.deinit();
    
    _ = q.whereIn("id", ids);  // 1 次查询
    
    var result = try q.getWithArena(self.allocator);
    defer result.deinit();
    
    return result.items();
}

// ❌ 避免：循环查询
pub fn getTestCasesByIdsBad(self: *Self, ids: []const i32) ![]TestCase {
    var result = std.ArrayList(TestCase).init(self.allocator);
    
    for (ids) |id| {
        if (try self.test_case_repo.findById(id)) |test_case| {
            try result.append(test_case);  // N 次查询
        }
    }
    
    return result.toOwnedSlice();
}
```

#### 索引优化

```sql
-- 高频查询字段添加索引
CREATE INDEX idx_test_cases_project_id ON test_cases(project_id);
CREATE INDEX idx_test_cases_module_id ON test_cases(module_id);
CREATE INDEX idx_test_cases_status ON test_cases(status);
CREATE INDEX idx_test_cases_assignee ON test_cases(assignee);
CREATE INDEX idx_test_cases_created_at ON test_cases(created_at);

-- 复合索引优化多条件查询
CREATE INDEX idx_test_cases_project_status ON test_cases(project_id, status);
CREATE INDEX idx_test_cases_module_status ON test_cases(module_id, status);

-- 覆盖索引优化统计查询
CREATE INDEX idx_test_cases_project_status_id ON test_cases(project_id, status, id);
```

### 2. 缓存策略

#### 缓存键设计

```zig
pub const CacheKeys = struct {
    // 单个对象缓存
    pub fn testCase(id: i32) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "test_case:{d}", .{id});
    }
    
    pub fn project(id: i32) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "project:{d}", .{id});
    }
    
    // 列表缓存
    pub fn testCaseList(project_id: i32, page: i32) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "test_case_list:project:{d}:page:{d}",
            .{ project_id, page },
        );
    }
    
    // 统计缓存
    pub fn projectStatistics(project_id: i32) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "project_statistics:{d}",
            .{project_id},
        );
    }
    
    // 模块树缓存
    pub fn moduleTree(project_id: i32) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "module_tree:project:{d}",
            .{project_id},
        );
    }
};
```

#### 缓存失效策略

```zig
pub fn updateTestCase(self: *Self, id: i32, dto: UpdateTestCaseDto) !void {
    // 1. 查询原测试用例
    const old_case = try self.test_case_repo.findById(id) orelse {
        return error.TestCaseNotFound;
    };
    defer self.freeTestCase(old_case);
    
    // 2. 更新测试用例
    var updated_case = old_case;
    // ... 更新字段
    try self.test_case_repo.save(&updated_case);
    
    // 3. 清除相关缓存
    // 清除单个对象缓存
    const cache_key = try CacheKeys.testCase(id);
    defer self.allocator.free(cache_key);
    try self.cache.del(cache_key);
    
    // 清除项目相关缓存
    const project_prefix = try std.fmt.allocPrint(
        self.allocator,
        "project:{d}:",
        .{old_case.project_id},
    );
    defer self.allocator.free(project_prefix);
    try self.cache.delByPrefix(project_prefix);
    
    // 清除模块相关缓存
    const module_prefix = try std.fmt.allocPrint(
        self.allocator,
        "module:{d}:",
        .{old_case.module_id},
    );
    defer self.allocator.free(module_prefix);
    try self.cache.delByPrefix(module_prefix);
}
```

#### 缓存预热

```zig
pub fn warmupCache(self: *Self, project_id: i32) !void {
    // 1. 预加载项目统计
    const stats = try self.calculateProjectStatistics(project_id);
    const stats_key = try CacheKeys.projectStatistics(project_id);
    defer self.allocator.free(stats_key);
    
    const stats_json = try self.serializeStatistics(stats);
    defer self.allocator.free(stats_json);
    try self.cache.set(stats_key, stats_json, 300);
    
    // 2. 预加载模块树
    const tree = try self.getModuleTree(project_id);
    const tree_key = try CacheKeys.moduleTree(project_id);
    defer self.allocator.free(tree_key);
    
    const tree_json = try self.serializeModuleTree(tree);
    defer self.allocator.free(tree_json);
    try self.cache.set(tree_key, tree_json, 300);
    
    // 3. 预加载热门测试用例
    const hot_cases = try self.getHotTestCases(project_id, 20);
    for (hot_cases) |test_case| {
        const case_key = try CacheKeys.testCase(test_case.id.?);
        defer self.allocator.free(case_key);
        
        const case_json = try self.serializeTestCase(test_case);
        defer self.allocator.free(case_json);
        try self.cache.set(case_key, case_json, 300);
    }
}
```

### 3. 前端性能优化

#### 虚拟滚动（大数据集渲染）

```vue
<!-- 使用 Arco Design 虚拟列表 -->
<template>
  <a-virtual-list
    :data="testCases"
    :height="600"
    :item-height="80"
  >
    <template #item="{ item }">
      <TestCaseItem :test-case="item" />
    </template>
  </a-virtual-list>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const testCases = ref<TestCase[]>([]);

// 加载大量数据
const loadData = async () => {
  const res = await qualityCenterApi.searchTestCases({
    page: 1,
    page_size: 1000, // 一次加载 1000 条
  });
  testCases.value = res.items;
};
</script>
```

#### 分页加载

```vue
<template>
  <div class="test-case-list">
    <a-table
      :columns="columns"
      :data="data"
      :loading="loading"
      :pagination="pagination"
      @page-change="handlePageChange"
    />
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue';

const pagination = ref({
  current: 1,
  pageSize: 20,
  total: 0,
  showTotal: true,
  showJumper: true,
  showPageSize: true,
});

const handlePageChange = (page: number) => {
  pagination.value.current = page;
  loadData();
};
</script>
```

#### 防抖和节流

```typescript
import { debounce, throttle } from 'lodash-es';

// 搜索防抖（500ms）
const handleSearch = debounce((keyword: string) => {
  loadData({ keyword });
}, 500);

// 滚动节流（100ms）
const handleScroll = throttle(() => {
  // 处理滚动事件
}, 100);
```

#### 骨架屏

```vue
<template>
  <div class="test-case-list">
    <a-skeleton v-if="loading" :loading="true" :animation="true">
      <a-skeleton-line :rows="10" />
    </a-skeleton>
    
    <a-table v-else :columns="columns" :data="data" />
  </div>
</template>
```

### 4. 内存管理优化

#### Arena Allocator 使用

```zig
// ✅ 推荐：批量操作使用 Arena
pub fn batchProcess(self: *Self, ids: []const i32) !void {
    var arena = std.heap.ArenaAllocator.init(self.allocator);
    defer arena.deinit();  // 一次性释放所有内存
    const arena_allocator = arena.allocator();
    
    // 使用 Arena 分配器查询
    var q = OrmTestCase.Query();
    defer q.deinit();
    
    _ = q.whereIn("id", ids);
    var result = try q.getWithArena(arena_allocator);
    // 无需手动释放，arena.deinit() 会清理所有
    
    for (result.items()) |test_case| {
        // 处理测试用例
        try self.processTestCase(test_case);
    }
}
```

#### 深拷贝策略

```zig
// ✅ 推荐：深拷贝字符串字段
pub fn deepCopyTestCase(self: *Self, source: TestCase) !TestCase {
    return TestCase{
        .id = source.id,
        .title = try self.allocator.dupe(u8, source.title),
        .project_id = source.project_id,
        .module_id = source.module_id,
        .requirement_id = source.requirement_id,
        .priority = source.priority,
        .status = source.status,
        .precondition = try self.allocator.dupe(u8, source.precondition),
        .steps = try self.allocator.dupe(u8, source.steps),
        .expected_result = try self.allocator.dupe(u8, source.expected_result),
        .actual_result = try self.allocator.dupe(u8, source.actual_result),
        .assignee = if (source.assignee) |a| 
            try self.allocator.dupe(u8, a) 
        else null,
        .tags = try self.allocator.dupe(u8, source.tags),
        .created_by = try self.allocator.dupe(u8, source.created_by),
        .created_at = source.created_at,
        .updated_at = source.updated_at,
    };
}

// 释放深拷贝的测试用例
pub fn freeTestCase(self: *Self, test_case: TestCase) void {
    self.allocator.free(test_case.title);
    self.allocator.free(test_case.precondition);
    self.allocator.free(test_case.steps);
    self.allocator.free(test_case.expected_result);
    self.allocator.free(test_case.actual_result);
    if (test_case.assignee) |a| self.allocator.free(a);
    self.allocator.free(test_case.tags);
    self.allocator.free(test_case.created_by);
}
```

## 安全设计

### 1. SQL 注入防护

#### 参数化查询

```zig
// ✅ 推荐：使用参数化查询
pub fn searchTestCases(self: *Self, query: SearchQuery) ![]TestCase {
    var q = OrmTestCase.Query();
    defer q.deinit();
    
    // 所有条件都参数化
    if (query.project_id) |project_id| {
        _ = q.where("project_id", "=", project_id);
    }
    
    if (query.module_id) |module_id| {
        _ = q.where("module_id", "=", module_id);
    }
    
    if (query.status) |status| {
        _ = q.where("status", "=", @tagName(status));
    }
    
    if (query.assignee) |assignee| {
        _ = q.where("assignee", "=", assignee);
    }
    
    if (query.keyword) |keyword| {
        _ = q.where("title", "LIKE", try std.fmt.allocPrint(
            self.allocator,
            "%{s}%",
            .{keyword},
        ));
    }
    
    return try q.get();
}

// ❌ 禁止：字符串拼接
pub fn searchTestCasesBad(self: *Self, keyword: []const u8) ![]TestCase {
    const sql = try std.fmt.allocPrint(
        self.allocator,
        "SELECT * FROM test_cases WHERE title LIKE '%{s}%'",
        .{keyword},  // ❌ SQL 注入风险
    );
    defer self.allocator.free(sql);
    
    return try self.db.rawQuery(sql);  // ❌ 禁止使用 rawExec
}
```

#### 动态条件构建

```zig
// ✅ 推荐：使用 whereRaw + ParamBuilder
pub fn advancedSearch(self: *Self, filters: []Filter) ![]TestCase {
    var q = OrmTestCase.Query();
    defer q.deinit();
    
    var params = sql.ParamBuilder.init(self.allocator);
    defer params.deinit();
    
    var conditions = std.ArrayList(u8).init(self.allocator);
    defer conditions.deinit();
    
    try conditions.appendSlice("1=1");
    
    for (filters) |filter| {
        switch (filter.type) {
            .equals => {
                try conditions.appendSlice(" AND ");
                try conditions.appendSlice(filter.field);
                try conditions.appendSlice(" = ?");
                try params.add(filter.value);
            },
            .like => {
                try conditions.appendSlice(" AND ");
                try conditions.appendSlice(filter.field);
                try conditions.appendSlice(" LIKE ?");
                try params.add(try std.fmt.allocPrint(
                    self.allocator,
                    "%{s}%",
                    .{filter.value},
                ));
            },
            .in => {
                try conditions.appendSlice(" AND ");
                try conditions.appendSlice(filter.field);
                try conditions.appendSlice(" IN (");
                for (filter.values, 0..) |value, i| {
                    if (i > 0) try conditions.appendSlice(", ");
                    try conditions.appendSlice("?");
                    try params.add(value);
                }
                try conditions.appendSlice(")");
            },
        }
    }
    
    _ = q.whereRaw(conditions.items, params);
    return try q.get();
}
```

### 2. 权限控制

#### 基于角色的访问控制（RBAC）

```zig
pub const Permission = enum {
    test_case_view,
    test_case_create,
    test_case_edit,
    test_case_delete,
    test_case_execute,
    project_view,
    project_create,
    project_edit,
    project_delete,
    requirement_view,
    requirement_create,
    requirement_edit,
    requirement_delete,
};

pub fn checkPermission(
    self: *Self,
    user_id: i32,
    permission: Permission,
) !bool {
    // 1. 获取用户角色
    const user_roles = try self.getUserRoles(user_id);
    defer self.allocator.free(user_roles);
    
    // 2. 检查角色权限
    for (user_roles) |role| {
        const role_permissions = try self.getRolePermissions(role.id);
        defer self.allocator.free(role_permissions);
        
        for (role_permissions) |perm| {
            if (perm == permission) {
                return true;
            }
        }
    }
    
    return false;
}

// 中间件：权限检查
pub fn requirePermission(permission: Permission) Middleware {
    return struct {
        pub fn handle(req: *Request, next: NextFn) !void {
            const user_id = req.getUserId() orelse {
                return req.sendError(401, "未登录");
            };
            
            const has_permission = try checkPermission(user_id, permission);
            if (!has_permission) {
                return req.sendError(403, "无权限");
            }
            
            try next(req);
        }
    };
}
```

### 3. 输入验证

```zig
pub fn validateCreateTestCaseDto(dto: CreateTestCaseDto) !void {
    // 验证必填字段
    if (dto.title.len == 0) {
        return error.TitleRequired;
    }
    
    if (dto.title.len > 200) {
        return error.TitleTooLong;
    }
    
    if (dto.project_id <= 0) {
        return error.InvalidProjectId;
    }
    
    if (dto.module_id <= 0) {
        return error.InvalidModuleId;
    }
    
    // 验证枚举值
    _ = dto.priority; // 编译时类型检查
    
    // 验证字符串长度
    if (dto.precondition.len > 5000) {
        return error.PreconditionTooLong;
    }
    
    if (dto.steps.len > 10000) {
        return error.StepsTooLong;
    }
    
    if (dto.expected_result.len > 5000) {
        return error.ExpectedResultTooLong;
    }
}
```

### 4. 数据脱敏

```zig
pub fn maskSensitiveData(test_case: *TestCase) void {
    // 脱敏用户信息
    if (test_case.assignee) |assignee| {
        if (assignee.len > 2) {
            // 保留首尾字符，中间用 * 替换
            const masked = std.fmt.allocPrint(
                allocator,
                "{s}***{s}",
                .{ assignee[0..1], assignee[assignee.len - 1 ..] },
            ) catch return;
            allocator.free(assignee);
            test_case.assignee = masked;
        }
    }
    
    // 脱敏敏感内容
    if (std.mem.indexOf(u8, test_case.steps, "密码") != null) {
        test_case.steps = "[已脱敏]";
    }
}
```


## 正确性属性

*属性是一个特征或行为，应该在系统的所有有效执行中保持为真——本质上是关于系统应该做什么的正式陈述。属性作为人类可读规范和机器可验证正确性保证之间的桥梁。*

### 属性 1: 测试用例 CRUD 操作完整性

*对于任何*有效的测试用例，创建后应能通过 ID 查询到相同的测试用例，更新后应反映新的值，删除后应无法查询到。

**验证需求: 1.1**

### 属性 2: 必填字段验证

*对于任何*缺少必填字段（标题、项目 ID、模块 ID）的测试用例创建请求，系统应拒绝并返回验证错误。

**验证需求: 1.2**

### 属性 3: 批量删除一致性

*对于任何*测试用例 ID 集合，批量删除后，所有指定 ID 的测试用例都应无法查询到。

**验证需求: 1.3**

### 属性 4: 批量状态更新一致性

*对于任何*测试用例 ID 集合和目标状态，批量更新后，所有指定 ID 的测试用例状态都应为目标状态。

**验证需求: 1.4**

### 属性 5: 批量负责人分配一致性

*对于任何*测试用例 ID 集合和负责人，批量分配后，所有指定 ID 的测试用例负责人都应为指定负责人。

**验证需求: 1.5**

### 属性 6: 测试执行记录完整性

*对于任何*测试用例执行操作，系统应创建包含执行结果、执行时间和执行人的执行记录。

**验证需求: 1.6**

### 属性 7: 执行历史累积性

*对于任何*测试用例，多次执行后，执行历史记录数量应等于执行次数。

**验证需求: 1.7**

### 属性 8: 关联关系双向性

*对于任何*测试用例和需求/Bug/反馈的关联操作，从测试用例应能查询到关联对象，从关联对象也应能查询到测试用例。

**验证需求: 1.8**

### 属性 9: 搜索结果准确性

*对于任何*搜索条件（项目、模块、状态、负责人、关键字），返回的所有测试用例都应满足所有指定条件。

**验证需求: 1.9**

### 属性 10: 分页查询一致性

*对于任何*测试用例查询，每页返回的记录数应不超过 20 条，且所有页的记录总数应等于总记录数。

**验证需求: 1.10**


### 属性 11: AI 生成测试用例完整性

*对于任何*需求，AI 生成的测试用例应包含标题、前置条件、测试步骤和预期结果四个必需字段。

**验证需求: 2.3**

### 属性 12: AI 生成进度单调递增

*对于任何*AI 生成过程，进度值应在 0-100 之间单调递增。

**验证需求: 2.4**

### 属性 13: 批量保存测试用例一致性

*对于任何*生成的测试用例集合，批量保存后，数据库中应存在相同数量的测试用例记录。

**验证需求: 2.7**

### 属性 14: 测试用例自动关联需求

*对于任何*从需求生成并保存的测试用例，其 requirement_id 字段应等于源需求的 ID。

**验证需求: 2.8**

### 属性 15: AI 生成性能约束

*对于任何*单个需求的测试用例生成，完成时间应不超过 30 秒。

**验证需求: 2.10**

### 属性 16: 项目统计数据准确性

*对于任何*项目，统计的用例总数应等于该项目下所有测试用例的数量，通过率应等于通过用例数除以总用例数。

**验证需求: 3.5**

### 属性 17: 项目统计加载性能

*对于任何*项目详情查询，统计数据加载时间应不超过 500 毫秒。

**验证需求: 3.6**

### 属性 18: 项目归档状态一致性

*对于任何*项目，归档后状态应为 archived，恢复后状态应为 active。

**验证需求: 3.7**

### 属性 19: 项目操作日志完整性

*对于任何*项目操作（创建、修改、删除、成员变更），系统应记录包含操作类型、操作人和操作时间的日志。

**验证需求: 3.10**

### 属性 20: 模块树层级约束

*对于任何*模块，其层级深度应不超过 5 层。

**验证需求: 4.3**

### 属性 21: 模块拖拽更新性能

*对于任何*模块拖拽操作，树形结构更新时间应不超过 200 毫秒。

**验证需求: 4.5**

### 属性 22: 模块名称唯一性

*对于任何*同一父模块下的模块，名称应唯一，尝试创建重名模块应被拒绝。

**验证需求: 4.10**

### 属性 23: 需求状态流转合法性

*对于任何*需求状态变更，新状态应符合状态流转规则（待评审→已评审→开发中→待测试→测试中→已完成→已关闭）。

**验证需求: 5.4**

### 属性 24: 需求状态变更历史完整性

*对于任何*需求状态变更，系统应记录包含时间、操作人、原状态和新状态的历史记录。

**验证需求: 5.5**

### 属性 25: 需求覆盖率计算准确性

*对于任何*需求，覆盖率应等于关联测试用例数除以建议测试用例数。

**验证需求: 5.6**

### 属性 26: 需求导入导出 Round-Trip

*对于任何*有效的需求集合，导出为 Excel 后再导入，应产生等价的需求数据。

**验证需求: 5.10**

### 属性 27: 图表数据一致性

*对于任何*可视化图表（模块分布、Bug 分布、反馈分布），图表数据应与数据库实际数据一致。

**验证需求: 6.1, 6.3, 6.4**

### 属性 28: 图表时间范围筛选准确性

*对于任何*时间范围筛选，返回的数据应只包含该时间范围内的记录。

**验证需求: 6.6**

### 属性 29: 图表加载性能

*对于任何*图表查询，数据加载时间应不超过 1 秒。

**验证需求: 6.8**

### 属性 30: 反馈跟进进度准确性

*对于任何*反馈，跟进次数应等于跟进记录的数量，最后跟进时间应等于最新跟进记录的时间。

**验证需求: 7.4**

### 属性 31: 反馈批量操作一致性

*对于任何*反馈 ID 集合和操作（指派、修改状态），批量操作后，所有指定 ID 的反馈都应反映操作结果。

**验证需求: 7.6**

### 属性 32: 反馈导出 Round-Trip

*对于任何*有效的反馈集合，导出为 Excel 后再导入，应产生等价的反馈数据（包含跟进记录）。

**验证需求: 7.10**

### 属性 33: 脑图虚拟渲染性能

*对于任何*超过 100 个节点的脑图，使用虚拟渲染后，渲染性能应优于非虚拟渲染。

**验证需求: 8.5**

### 属性 34: 脑图节点搜索准确性

*对于任何*搜索关键词，返回的节点应包含该关键词。

**验证需求: 8.6**

### 属性 35: SQL 注入防护

*对于任何*包含 SQL 注入攻击载荷的输入，系统应拒绝执行并返回错误。

**验证需求: 9.3**

### 属性 36: 批量查询性能优化

*对于任何*批量查询操作，使用 whereIn 的查询次数应等于 1，而不是 N。

**验证需求: 9.4**

### 属性 37: 关系预加载性能优化

*对于任何*包含关联数据的查询，使用关系预加载的查询次数应少于不使用预加载的查询次数。

**验证需求: 9.5**

### 属性 38: 索引查询性能优化

*对于任何*高频查询字段（project_id、module_id、status），使用索引的查询时间应少于不使用索引的查询时间。

**验证需求: 9.10**

### 属性 39: 操作视觉反馈及时性

*对于任何*用户操作，视觉反馈（加载动画、按钮状态变化）应在 200 毫秒内显示。

**验证需求: 11.3**

### 属性 40: 键盘快捷键功能性

*对于任何*支持的键盘快捷键（Ctrl+S、Ctrl+F、Esc），按下后应触发对应操作。

**验证需求: 11.6**

### 属性 41: 主题切换一致性

*对于任何*主题切换操作（暗色模式↔亮色模式），所有组件的主题应同步切换。

**验证需求: 11.7**

### 属性 42: 表格状态记忆持久性

*对于任何*表格排序和筛选状态，刷新页面后应保持相同状态。

**验证需求: 11.10**

### 属性 43: 测试用例列表查询性能

*对于任何*测试用例列表查询，响应时间应不超过 500 毫秒。

**验证需求: 12.1**

### 属性 44: 项目统计查询性能

*对于任何*项目统计数据查询，加载时间应不超过 1 秒。

**验证需求: 12.2**

### 属性 45: 批量操作记录数限制

*对于任何*批量操作，支持的最大记录数应为 1000 条，超过应被拒绝。

**验证需求: 12.3**

### 属性 46: 缓存命中率优化

*对于任何*高频查询，使用缓存的响应时间应少于不使用缓存的响应时间。

**验证需求: 12.5**

### 属性 47: 缓存过期时间一致性

*对于任何*缓存数据，5 分钟后应过期并重新从数据库加载。

**验证需求: 12.6**

### 属性 48: 数据更新缓存失效

*对于任何*数据更新操作，相关缓存应被清除。

**验证需求: 12.7**

### 属性 49: 异步任务非阻塞性

*对于任何*耗时操作（AI 生成、数据导出、批量操作），应异步执行，不阻塞主线程。

**验证需求: 12.10**

### 属性 50: JSON 序列化 Round-Trip

*对于任何*有效的实体对象，序列化为 JSON 后再反序列化，应产生等价对象。

**验证需求: 13.5**

### 属性 51: JSON 字段类型验证

*对于任何*包含错误类型字段的 JSON 请求，系统应拒绝并返回类型错误信息。

**验证需求: 13.6**

### 属性 52: JSON 字段默认值生效

*对于任何*缺少可选字段的 JSON 请求，反序列化后应使用字段的默认值。

**验证需求: 13.7**

### 属性 53: JSON 特殊字符处理

*对于任何*包含特殊字符（引号、换行符、Unicode）的 JSON，系统应正确解析和序列化。

**验证需求: 13.9**

### 属性 54: JSON 请求体大小限制

*对于任何*超过 10MB 的 JSON 请求体，系统应拒绝并返回大小超限错误。

**验证需求: 13.10**


## 错误处理

### 错误类型定义

```zig
pub const QualityCenterError = error{
    // 验证错误
    TitleRequired,
    TitleTooLong,
    ProjectIdRequired,
    InvalidProjectId,
    ModuleIdRequired,
    InvalidModuleId,
    PreconditionTooLong,
    StepsTooLong,
    ExpectedResultTooLong,
    
    // 业务错误
    TestCaseNotFound,
    ProjectNotFound,
    ModuleNotFound,
    RequirementNotFound,
    FeedbackNotFound,
    DuplicateModuleName,
    MaxDepthExceeded,
    InvalidStatusTransition,
    
    // 权限错误
    PermissionDenied,
    Unauthorized,
    
    // 系统错误
    DatabaseError,
    CacheError,
    AIGenerationError,
    ExportError,
    ImportError,
};
```

### 错误处理模式

```zig
pub fn createTestCase(self: *Self, dto: CreateTestCaseDto) !TestCase {
    // 1. 输入验证
    try validateCreateTestCaseDto(dto);
    
    // 2. 业务逻辑
    var test_case = TestCase{
        .title = dto.title,
        .project_id = dto.project_id,
        .module_id = dto.module_id,
        // ...
    };
    
    // 3. 数据库操作（使用 errdefer 确保资源释放）
    try self.test_case_repo.save(&test_case);
    errdefer {
        // 如果后续操作失败，回滚数据库操作
        self.test_case_repo.delete(test_case.id.?) catch {};
    }
    
    // 4. 缓存操作（失败不影响主流程）
    self.clearProjectCache(dto.project_id) catch |err| {
        std.log.warn("清除缓存失败: {}", .{err});
    };
    
    return test_case;
}
```

### 控制器错误处理

```zig
pub fn create(req: zap.Request) !void {
    const body = req.parseBody(CreateTestCaseDto) catch |err| {
        return base.send_error(req, 400, "请求体解析失败");
    };
    
    const container = zigcms.core.di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        return base.send_error(req, 500, "服务初始化失败");
    };
    
    const test_case = service.create(body) catch |err| {
        return switch (err) {
            error.TitleRequired => base.send_error(req, 400, "标题不能为空"),
            error.TitleTooLong => base.send_error(req, 400, "标题过长"),
            error.ProjectIdRequired => base.send_error(req, 400, "项目 ID 不能为空"),
            error.InvalidProjectId => base.send_error(req, 400, "无效的项目 ID"),
            error.ModuleIdRequired => base.send_error(req, 400, "模块 ID 不能为空"),
            error.InvalidModuleId => base.send_error(req, 400, "无效的模块 ID"),
            error.PermissionDenied => base.send_error(req, 403, "无权限"),
            error.Unauthorized => base.send_error(req, 401, "未登录"),
            else => base.send_error(req, 500, "服务器内部错误"),
        };
    };
    
    try base.send_success(req, test_case);
}
```

## 测试策略

### 双重测试方法

本系统采用**单元测试 + 属性测试**的双重测试方法，确保全面的测试覆盖。

#### 单元测试

单元测试用于验证特定示例、边界条件和错误处理：

```zig
// test/test_case_service_test.zig
const std = @import("std");
const testing = std.testing;

test "创建测试用例 - 成功场景" {
    var service = try TestCaseService.init(testing.allocator, ...);
    defer service.deinit();
    
    const dto = CreateTestCaseDto{
        .title = "测试登录功能",
        .project_id = 1,
        .module_id = 1,
        .precondition = "用户已注册",
        .steps = "1. 打开登录页\n2. 输入用户名密码\n3. 点击登录",
        .expected_result = "登录成功",
        .created_by = "test_user",
    };
    
    const test_case = try service.create(dto);
    defer service.freeTestCase(test_case);
    
    try testing.expectEqualStrings("测试登录功能", test_case.title);
    try testing.expectEqual(@as(i32, 1), test_case.project_id);
    try testing.expectEqual(@as(i32, 1), test_case.module_id);
}

test "创建测试用例 - 标题为空" {
    var service = try TestCaseService.init(testing.allocator, ...);
    defer service.deinit();
    
    const dto = CreateTestCaseDto{
        .title = "",  // 空标题
        .project_id = 1,
        .module_id = 1,
        .created_by = "test_user",
    };
    
    const result = service.create(dto);
    try testing.expectError(error.TitleRequired, result);
}

test "批量删除测试用例" {
    var service = try TestCaseService.init(testing.allocator, ...);
    defer service.deinit();
    
    // 创建 3 个测试用例
    const ids = [_]i32{ 1, 2, 3 };
    for (ids) |id| {
        const dto = CreateTestCaseDto{
            .title = try std.fmt.allocPrint(testing.allocator, "测试用例 {d}", .{id}),
            .project_id = 1,
            .module_id = 1,
            .created_by = "test_user",
        };
        _ = try service.create(dto);
    }
    
    // 批量删除
    try service.batchDelete(&ids);
    
    // 验证删除成功
    for (ids) |id| {
        const result = service.findById(id);
        try testing.expectEqual(@as(?TestCase, null), result);
    }
}
```

#### 属性测试

属性测试用于验证通用属性，使用随机生成的输入：

```zig
// test/test_case_properties_test.zig
const std = @import("std");
const testing = std.testing;
const quickcheck = @import("quickcheck");

test "属性 1: 测试用例 CRUD 操作完整性" {
    // Feature: quality-center-enhancement, Property 1: 对于任何有效的测试用例，创建后应能通过 ID 查询到相同的测试用例
    
    var service = try TestCaseService.init(testing.allocator, ...);
    defer service.deinit();
    
    try quickcheck.forAll(
        testing.allocator,
        generateValidTestCaseDto,
        struct {
            fn prop(allocator: Allocator, dto: CreateTestCaseDto) !bool {
                var svc = try TestCaseService.init(allocator, ...);
                defer svc.deinit();
                
                // 创建测试用例
                const created = try svc.create(dto);
                defer svc.freeTestCase(created);
                
                // 查询测试用例
                const found = try svc.findById(created.id.?) orelse return false;
                defer svc.freeTestCase(found);
                
                // 验证相同
                return std.mem.eql(u8, created.title, found.title) and
                       created.project_id == found.project_id and
                       created.module_id == found.module_id;
            }
        }.prop,
        .{ .num_tests = 100 },
    );
}

test "属性 2: 必填字段验证" {
    // Feature: quality-center-enhancement, Property 2: 对于任何缺少必填字段的测试用例创建请求，系统应拒绝
    
    try quickcheck.forAll(
        testing.allocator,
        generateInvalidTestCaseDto,
        struct {
            fn prop(allocator: Allocator, dto: CreateTestCaseDto) !bool {
                var svc = try TestCaseService.init(allocator, ...);
                defer svc.deinit();
                
                // 尝试创建（应该失败）
                const result = svc.create(dto);
                
                // 验证失败
                return std.meta.isError(result);
            }
        }.prop,
        .{ .num_tests = 100 },
    );
}

test "属性 50: JSON 序列化 Round-Trip" {
    // Feature: quality-center-enhancement, Property 50: 对于任何有效的实体对象，序列化后反序列化应产生等价对象
    
    try quickcheck.forAll(
        testing.allocator,
        generateValidTestCase,
        struct {
            fn prop(allocator: Allocator, test_case: TestCase) !bool {
                // 序列化
                const json = try serializeTestCase(allocator, test_case);
                defer allocator.free(json);
                
                // 反序列化
                const deserialized = try deserializeTestCase(allocator, json);
                defer freeTestCase(allocator, deserialized);
                
                // 验证等价
                return std.mem.eql(u8, test_case.title, deserialized.title) and
                       test_case.project_id == deserialized.project_id and
                       test_case.module_id == deserialized.module_id and
                       test_case.priority == deserialized.priority and
                       test_case.status == deserialized.status;
            }
        }.prop,
        .{ .num_tests = 100 },
    );
}

// 生成器函数
fn generateValidTestCaseDto(allocator: Allocator, rng: *std.rand.Random) !CreateTestCaseDto {
    const title = try generateRandomString(allocator, rng, 1, 200);
    const project_id = rng.intRangeAtMost(i32, 1, 1000);
    const module_id = rng.intRangeAtMost(i32, 1, 1000);
    
    return CreateTestCaseDto{
        .title = title,
        .project_id = project_id,
        .module_id = module_id,
        .precondition = try generateRandomString(allocator, rng, 0, 1000),
        .steps = try generateRandomString(allocator, rng, 0, 2000),
        .expected_result = try generateRandomString(allocator, rng, 0, 1000),
        .created_by = "test_user",
    };
}

fn generateInvalidTestCaseDto(allocator: Allocator, rng: *std.rand.Random) !CreateTestCaseDto {
    const invalid_type = rng.intRangeAtMost(u8, 0, 2);
    
    return switch (invalid_type) {
        0 => CreateTestCaseDto{  // 空标题
            .title = "",
            .project_id = 1,
            .module_id = 1,
            .created_by = "test_user",
        },
        1 => CreateTestCaseDto{  // 无效项目 ID
            .title = "测试",
            .project_id = 0,
            .module_id = 1,
            .created_by = "test_user",
        },
        2 => CreateTestCaseDto{  // 无效模块 ID
            .title = "测试",
            .project_id = 1,
            .module_id = 0,
            .created_by = "test_user",
        },
        else => unreachable,
    };
}
```

### 测试配置

所有属性测试应配置为运行至少 100 次迭代：

```zig
.{ .num_tests = 100 }
```

每个属性测试必须使用注释标记其对应的设计文档属性：

```zig
// Feature: quality-center-enhancement, Property 1: 对于任何有效的测试用例，创建后应能通过 ID 查询到相同的测试用例
```

### 前端测试

```typescript
// test/test-case.spec.ts
import { describe, it, expect } from 'vitest';
import { mount } from '@vue/test-utils';
import TestCaseTable from '@/views/quality-center/test-case/components/TestCaseTable.vue';

describe('TestCaseTable', () => {
  it('应该渲染测试用例列表', async () => {
    const wrapper = mount(TestCaseTable, {
      props: {
        projectId: 1,
      },
    });
    
    await wrapper.vm.$nextTick();
    
    expect(wrapper.find('.test-case-table').exists()).toBe(true);
  });
  
  it('应该支持批量删除', async () => {
    const wrapper = mount(TestCaseTable);
    
    // 选择测试用例
    await wrapper.vm.selectedKeys = [1, 2, 3];
    
    // 点击批量删除
    await wrapper.find('.batch-delete-btn').trigger('click');
    
    // 验证调用 API
    expect(mockApi.batchDeleteTestCases).toHaveBeenCalledWith([1, 2, 3]);
  });
});
```

## 部署和运维

### 数据库迁移

```sql
-- migrations/20260303_quality_center_enhancement.sql

-- 测试用例表
CREATE TABLE IF NOT EXISTS test_cases (
    id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(200) NOT NULL,
    project_id INT NOT NULL,
    module_id INT NOT NULL,
    requirement_id INT DEFAULT NULL,
    priority VARCHAR(16) NOT NULL DEFAULT 'medium',
    status VARCHAR(32) NOT NULL DEFAULT 'pending',
    precondition TEXT NOT NULL,
    steps TEXT NOT NULL,
    expected_result TEXT NOT NULL,
    actual_result TEXT NOT NULL,
    assignee VARCHAR(64) DEFAULT NULL,
    tags TEXT NOT NULL,
    created_by VARCHAR(64) NOT NULL DEFAULT '',
    created_at DATETIME DEFAULT NULL,
    updated_at DATETIME DEFAULT NULL,
    INDEX idx_project_id (project_id),
    INDEX idx_module_id (module_id),
    INDEX idx_requirement_id (requirement_id),
    INDEX idx_status (status),
    INDEX idx_assignee (assignee),
    INDEX idx_created_at (created_at),
    INDEX idx_project_status (project_id, status),
    INDEX idx_module_status (module_id, status)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 其他表...
```

### DI 容器注册

```zig
// root.zig
fn registerQualityCenterServices(
    container: *DIContainer,
    allocator: Allocator,
    db: *Database,
    cache: *CacheInterface,
) !void {
    // 1. 注册仓储
    const test_case_repo = try allocator.create(MysqlTestCaseRepository);
    test_case_repo.* = MysqlTestCaseRepository.init(allocator, db);
    try container.registerInstance(MysqlTestCaseRepository, test_case_repo, null);
    
    // 2. 注册 AI 生成器
    const ai_generator = try allocator.create(OpenAIGenerator);
    ai_generator.* = OpenAIGenerator.init(
        allocator,
        config.openai_api_key,
        config.openai_base_url,
    );
    try container.registerInstance(OpenAIGenerator, ai_generator, null);
    
    // 3. 注册服务
    try container.registerSingleton(TestCaseService, TestCaseService, struct {
        fn factory(di: *DIContainer, alloc: Allocator) anyerror!*TestCaseService {
            const repo = try di.resolve(MysqlTestCaseRepository);
            const exec_repo = try di.resolve(MysqlTestExecutionRepository);
            const cache_ptr = try di.resolve(CacheInterface);
            
            const service = try alloc.create(TestCaseService);
            service.* = TestCaseService.init(alloc, repo.*, exec_repo.*, cache_ptr);
            return service;
        }
    }.factory, null);
}
```

### 路由注册

```zig
// src/api/bootstrap.zig
pub fn registerQualityCenterRoutes(self: *Self) !void {
    // 测试用例路由
    try self.app.route("POST", "/api/quality/test-cases", test_case_controller.create);
    try self.app.route("GET", "/api/quality/test-cases/:id", test_case_controller.get);
    try self.app.route("PUT", "/api/quality/test-cases/:id", test_case_controller.update);
    try self.app.route("DELETE", "/api/quality/test-cases/:id", test_case_controller.delete);
    try self.app.route("GET", "/api/quality/test-cases", test_case_controller.search);
    try self.app.route("POST", "/api/quality/test-cases/batch-delete", test_case_controller.batchDelete);
    try self.app.route("POST", "/api/quality/test-cases/:id/execute", test_case_controller.execute);
    
    // AI 生成路由
    try self.app.route("POST", "/api/quality/ai/generate-test-cases", ai_controller.generateTestCases);
    
    // 项目路由
    try self.app.route("POST", "/api/quality/projects", project_controller.create);
    try self.app.route("GET", "/api/quality/projects/:id", project_controller.get);
    try self.app.route("GET", "/api/quality/projects/:id/statistics", project_controller.statistics);
    
    // 其他路由...
}
```

## 总结

本设计文档详细描述了质量中心完善功能的技术实现方案，包括：

1. **架构设计**: 遵循整洁架构分层，清晰的职责划分
2. **数据模型**: 完整的实体定义和数据库表设计
3. **组件设计**: 仓储接口、服务层、AI 生成器的详细实现
4. **API 设计**: RESTful 接口和控制器实现
5. **前端设计**: Vue 3 + Arco Design 组件实现
6. **性能优化**: 关系预加载、批量查询、缓存策略、虚拟渲染
7. **安全设计**: SQL 注入防护、权限控制、输入验证
8. **正确性属性**: 54 个可测试属性，覆盖所有核心功能
9. **测试策略**: 单元测试 + 属性测试的双重测试方法
10. **部署方案**: 数据库迁移、DI 注册、路由配置

该设计确保系统的安全性、高性能、可维护性和可扩展性，符合 ZigCMS 开发范式和 Zig 语言最佳实践。

