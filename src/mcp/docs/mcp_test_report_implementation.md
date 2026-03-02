# MCP 自动测试上报工具 - 实现指南

## 一、实现步骤

### Step 1: 创建数据模型

**文件**: `src/mcp/tools/test_report/models.zig`

**内容**:
- TestReport 结构体
- BugAnalysis 结构体
- 相关枚举类型
- 序列化/反序列化方法

### Step 2: 实现 API 客户端

**文件**: `src/mcp/tools/test_report/api_client.zig`

**功能**:
- 与后端服务通信
- 上报测试结果
- 查询 Bug 列表
- 更新 Bug 状态

**API 端点**:
```
POST /api/auto-test/report/create      - 创建测试报告
POST /api/auto-test/bug/create         - 创建 Bug
GET  /api/auto-test/bug/list           - 获取 Bug 列表
POST /api/auto-test/bug/analyze        - 分析 Bug
POST /api/auto-test/bug/auto-fix       - 自动修复
POST /api/auto-test/bug/update-status  - 更新状态
```

### Step 3: 实现测试执行器

**文件**: `src/mcp/tools/test_executor.zig`

**功能**:
- 执行 API 测试
- 执行单元测试
- 收集测试结果
- 生成测试报告

### Step 4: 实现 Bug 分析器

**文件**: `src/mcp/tools/bug_analyzer.zig`

**功能**:
- 分析错误信息
- 分类 Bug 类型
- 定位问题位置
- 生成修复建议

### Step 5: 实现自动修复器

**文件**: `src/mcp/tools/auto_fixer.zig`

**功能**:
- 生成修复代码
- 应用修复
- 验证修复结果

### Step 6: 实现主工具

**文件**: `src/mcp/tools/test_report.zig`

**功能**:
- 整合所有组件
- 实现 MCP 工具接口
- 处理各种操作类型

---

## 二、核心代码实现

### 2.1 数据模型 (models.zig)

```zig
const std = @import("std");

/// 测试类型
pub const TestType = enum {
    api,
    unit,
    integration,
    e2e,
    performance,
    security,
    
    pub fn toString(self: TestType) []const u8 {
        return switch (self) {
            .api => "api",
            .unit => "unit",
            .integration => "integration",
            .e2e => "e2e",
            .performance => "performance",
            .security => "security",
        };
    }
};

/// 测试状态
pub const TestStatus = enum {
    pending,
    running,
    passed,
    failed,
    error,
    skipped,
    
    pub fn toString(self: TestStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .running => "running",
            .passed => "passed",
            .failed => "failed",
            .error => "error",
            .skipped => "skipped",
        };
    }
};

/// 测试报告
pub const TestReport = struct {
    id: ?i32 = null,
    name: []const u8,
    type: TestType,
    status: TestStatus,
    total_cases: i32 = 0,
    passed_cases: i32 = 0,
    failed_cases: i32 = 0,
    skipped_cases: i32 = 0,
    pass_rate: f32 = 0.0,
    started_at: ?i64 = null,
    completed_at: ?i64 = null,
    duration: ?i32 = null,
    error_message: ?[]const u8 = null,
    stack_trace: ?[]const u8 = null,
    bug_id: ?i32 = null,
    feedback_id: ?i32 = null,
    created_by: []const u8 = "AI",
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
    
    pub fn calculatePassRate(self: *TestReport) void {
        if (self.total_cases > 0) {
            self.pass_rate = @as(f32, @floatFromInt(self.passed_cases)) / 
                            @as(f32, @floatFromInt(self.total_cases)) * 100.0;
        }
    }
};

/// Bug 类型
pub const BugType = enum {
    functional,
    ui,
    performance,
    security,
    data,
    logic,
    configuration,
    network,
    
    pub fn toString(self: BugType) []const u8 {
        return switch (self) {
            .functional => "functional",
            .ui => "ui",
            .performance => "performance",
            .security => "security",
            .data => "data",
            .logic => "logic",
            .configuration => "configuration",
            .network => "network",
        };
    }
};

/// Bug 严重程度
pub const BugSeverity = enum {
    p0,
    p1,
    p2,
    p3,
    p4,
    
    pub fn toString(self: BugSeverity) []const u8 {
        return switch (self) {
            .p0 => "p0",
            .p1 => "p1",
            .p2 => "p2",
            .p3 => "p3",
            .p4 => "p4",
        };
    }
};

/// Bug 优先级
pub const BugPriority = enum {
    urgent,
    high,
    medium,
    low,
    
    pub fn toString(self: BugPriority) []const u8 {
        return switch (self) {
            .urgent => "urgent",
            .high => "high",
            .medium => "medium",
            .low => "low",
        };
    }
};

/// 问题位置
pub const IssueLocation = enum {
    frontend,
    backend,
    database,
    infrastructure,
    third_party,
    unknown,
    
    pub fn toString(self: IssueLocation) []const u8 {
        return switch (self) {
            .frontend => "frontend",
            .backend => "backend",
            .database => "database",
            .infrastructure => "infrastructure",
            .third_party => "third_party",
            .unknown => "unknown",
        };
    }
};

/// Bug 状态
pub const BugStatus = enum {
    pending,
    analyzing,
    analyzed,
    auto_fixing,
    auto_fixed,
    manual_fixing,
    resolved,
    closed,
    reopened,
    
    pub fn toString(self: BugStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .analyzing => "analyzing",
            .analyzed => "analyzed",
            .auto_fixing => "auto_fixing",
            .auto_fixed => "auto_fixed",
            .manual_fixing => "manual_fixing",
            .resolved => "resolved",
            .closed => "closed",
            .reopened => "reopened",
        };
    }
};

/// Bug 分析
pub const BugAnalysis = struct {
    id: ?i32 = null,
    title: []const u8,
    description: []const u8,
    type: BugType,
    severity: BugSeverity,
    priority: BugPriority,
    issue_location: IssueLocation,
    file_path: ?[]const u8 = null,
    line_number: ?i32 = null,
    root_cause: ?[]const u8 = null,
    reproduction_steps: ?[]const u8 = null,
    suggested_fix: ?[]const u8 = null,
    confidence_score: f32 = 0.0,
    status: BugStatus,
    auto_fix_attempted: bool = false,
    auto_fix_success: bool = false,
    fix_code: ?[]const u8 = null,
    test_report_id: ?i32 = null,
    feedback_id: ?i32 = null,
    analyzed_by: []const u8 = "AI",
    analyzed_at: ?i64 = null,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,
};
```

### 2.2 测试执行器 (test_executor.zig)

```zig
const std = @import("std");
const models = @import("test_report/models.zig");

pub const TestExecutor = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) TestExecutor {
        return .{ .allocator = allocator };
    }
    
    /// 执行测试
    pub fn execute(
        self: *TestExecutor,
        test_type: models.TestType,
        test_target: []const u8,
    ) !models.TestReport {
        var report = models.TestReport{
            .name = try std.fmt.allocPrint(
                self.allocator,
                "{s} Test: {s}",
                .{ @tagName(test_type), test_target }
            ),
            .type = test_type,
            .status = .running,
            .started_at = std.time.milliTimestamp(),
        };
        
        // 根据测试类型执行不同的测试
        switch (test_type) {
            .api => try self.executeApiTest(&report, test_target),
            .unit => try self.executeUnitTest(&report, test_target),
            .integration => try self.executeIntegrationTest(&report, test_target),
            else => {
                report.status = .error;
                report.error_message = try self.allocator.dupe(u8, "Unsupported test type");
            },
        }
        
        report.completed_at = std.time.milliTimestamp();
        if (report.started_at) |started| {
            if (report.completed_at) |completed| {
                report.duration = @intCast(completed - started);
            }
        }
        
        report.calculatePassRate();
        
        return report;
    }
    
    /// 执行 API 测试
    fn executeApiTest(
        self: *TestExecutor,
        report: *models.TestReport,
        endpoint: []const u8,
    ) !void {
        // TODO: 实现 API 测试逻辑
        // 1. 发送 HTTP 请求
        // 2. 验证响应
        // 3. 更新报告
        
        _ = self;
        _ = endpoint;
        
        // 示例：模拟测试结果
        report.total_cases = 5;
        report.passed_cases = 3;
        report.failed_cases = 2;
        report.status = .failed;
    }
    
    /// 执行单元测试
    fn executeUnitTest(
        self: *TestExecutor,
        report: *models.TestReport,
        file_path: []const u8,
    ) !void {
        // TODO: 实现单元测试逻辑
        // 1. 编译测试文件
        // 2. 运行测试
        // 3. 收集结果
        
        _ = self;
        _ = file_path;
        
        // 示例：模拟测试结果
        report.total_cases = 10;
        report.passed_cases = 10;
        report.failed_cases = 0;
        report.status = .passed;
    }
    
    /// 执行集成测试
    fn executeIntegrationTest(
        self: *TestExecutor,
        report: *models.TestReport,
        target: []const u8,
    ) !void {
        _ = self;
        _ = target;
        
        // 示例：模拟测试结果
        report.total_cases = 8;
        report.passed_cases = 6;
        report.failed_cases = 2;
        report.status = .failed;
    }
};
```

### 2.3 Bug 分析器 (bug_analyzer.zig)

```zig
const std = @import("std");
const models = @import("test_report/models.zig");

pub const BugAnalyzer = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) BugAnalyzer {
        return .{ .allocator = allocator };
    }
    
    /// 分析 Bug
    pub fn analyze(
        self: *BugAnalyzer,
        title: []const u8,
        description: []const u8,
        error_message: ?[]const u8,
        stack_trace: ?[]const u8,
    ) !models.BugAnalysis {
        var bug = models.BugAnalysis{
            .title = title,
            .description = description,
            .type = .functional,
            .severity = .p2,
            .priority = .medium,
            .issue_location = .unknown,
            .status = .analyzing,
            .analyzed_at = std.time.milliTimestamp(),
        };
        
        // 分析 Bug 类型
        bug.type = try self.classifyBugType(error_message, stack_trace);
        
        // 定位问题位置
        bug.issue_location = try self.locateIssue(stack_trace);
        
        // 评估严重程度
        bug.severity = try self.assessSeverity(&bug);
        
        // 确定优先级
        bug.priority = try self.determinePriority(&bug);
        
        // 生成修复建议
        bug.suggested_fix = try self.generateFixSuggestion(&bug);
        
        // 计算置信度
        bug.confidence_score = 0.85;
        
        bug.status = .analyzed;
        
        return bug;
    }
    
    /// 分类 Bug 类型
    fn classifyBugType(
        self: *BugAnalyzer,
        error_message: ?[]const u8,
        stack_trace: ?[]const u8,
    ) !models.BugType {
        _ = self;
        
        if (error_message) |msg| {
            if (std.mem.indexOf(u8, msg, "500") != null or
                std.mem.indexOf(u8, msg, "Internal Server Error") != null)
            {
                return .functional;
            }
            
            if (std.mem.indexOf(u8, msg, "timeout") != null or
                std.mem.indexOf(u8, msg, "slow") != null)
            {
                return .performance;
            }
            
            if (std.mem.indexOf(u8, msg, "database") != null or
                std.mem.indexOf(u8, msg, "connection") != null)
            {
                return .data;
            }
        }
        
        _ = stack_trace;
        
        return .functional;
    }
    
    /// 定位问题位置
    fn locateIssue(
        self: *BugAnalyzer,
        stack_trace: ?[]const u8,
    ) !models.IssueLocation {
        _ = self;
        
        if (stack_trace) |trace| {
            if (std.mem.indexOf(u8, trace, "src/api") != null or
                std.mem.indexOf(u8, trace, "src/application") != null)
            {
                return .backend;
            }
            
            if (std.mem.indexOf(u8, trace, "src/infrastructure/database") != null) {
                return .database;
            }
        }
        
        return .backend;
    }
    
    /// 评估严重程度
    fn assessSeverity(
        self: *BugAnalyzer,
        bug: *const models.BugAnalysis,
    ) !models.BugSeverity {
        _ = self;
        
        // 根据 Bug 类型和位置评估严重程度
        if (bug.type == .security) {
            return .p0;
        }
        
        if (bug.type == .functional and bug.issue_location == .backend) {
            return .p1;
        }
        
        if (bug.type == .performance) {
            return .p2;
        }
        
        return .p3;
    }
    
    /// 确定优先级
    fn determinePriority(
        self: *BugAnalyzer,
        bug: *const models.BugAnalysis,
    ) !models.BugPriority {
        _ = self;
        
        // 根据严重程度确定优先级
        return switch (bug.severity) {
            .p0 => .urgent,
            .p1 => .high,
            .p2 => .medium,
            .p3, .p4 => .low,
        };
    }
    
    /// 生成修复建议
    fn generateFixSuggestion(
        self: *BugAnalyzer,
        bug: *const models.BugAnalysis,
    ) ![]const u8 {
        // 根据 Bug 类型生成修复建议
        const suggestion = switch (bug.type) {
            .functional => "检查业务逻辑，确保所有边界条件都被正确处理",
            .performance => "优化查询性能，考虑添加索引或缓存",
            .data => "检查数据库连接配置，确保连接池大小合适",
            .security => "立即修复安全漏洞，进行安全审计",
            else => "需要进一步分析问题根源",
        };
        
        return try self.allocator.dupe(u8, suggestion);
    }
};
```

---

## 三、后端 API 实现建议

### 3.1 数据库表设计

```sql
-- 测试报告表
CREATE TABLE test_reports (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT NOT NULL,
    type TEXT NOT NULL,
    status TEXT NOT NULL,
    total_cases INTEGER DEFAULT 0,
    passed_cases INTEGER DEFAULT 0,
    failed_cases INTEGER DEFAULT 0,
    skipped_cases INTEGER DEFAULT 0,
    pass_rate REAL DEFAULT 0.0,
    started_at INTEGER,
    completed_at INTEGER,
    duration INTEGER,
    error_message TEXT,
    stack_trace TEXT,
    bug_id INTEGER,
    feedback_id INTEGER,
    created_by TEXT DEFAULT 'AI',
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER
);

-- Bug 分析表
CREATE TABLE bug_analyses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    title TEXT NOT NULL,
    description TEXT NOT NULL,
    type TEXT NOT NULL,
    severity TEXT NOT NULL,
    priority TEXT NOT NULL,
    issue_location TEXT NOT NULL,
    file_path TEXT,
    line_number INTEGER,
    root_cause TEXT,
    reproduction_steps TEXT,
    suggested_fix TEXT,
    confidence_score REAL DEFAULT 0.0,
    status TEXT NOT NULL,
    auto_fix_attempted INTEGER DEFAULT 0,
    auto_fix_success INTEGER DEFAULT 0,
    fix_code TEXT,
    test_report_id INTEGER,
    feedback_id INTEGER,
    analyzed_by TEXT DEFAULT 'AI',
    analyzed_at INTEGER,
    created_at INTEGER DEFAULT (strftime('%s', 'now')),
    updated_at INTEGER,
    FOREIGN KEY (test_report_id) REFERENCES test_reports(id),
    FOREIGN KEY (feedback_id) REFERENCES feedbacks(id)
);

-- 索引
CREATE INDEX idx_test_reports_status ON test_reports(status);
CREATE INDEX idx_test_reports_created_at ON test_reports(created_at);
CREATE INDEX idx_bug_analyses_status ON bug_analyses(status);
CREATE INDEX idx_bug_analyses_priority ON bug_analyses(priority);
CREATE INDEX idx_bug_analyses_created_at ON bug_analyses(created_at);
```

### 3.2 API 控制器

```zig
// src/api/controllers/auto_test.zig
pub const AutoTest = struct {
    allocator: std.mem.Allocator,
    
    pub fn init(allocator: std.mem.Allocator) AutoTest {
        return .{ .allocator = allocator };
    }
    
    /// 创建测试报告
    pub fn createReport(self: *AutoTest, req: zap.Request) !void {
        // 解析请求体
        const body = try req.parseBody(TestReportDto);
        
        // 保存到数据库
        const report_id = try self.saveReport(body);
        
        // 返回响应
        try base.send_success(req, .{ .id = report_id });
    }
    
    /// 创建 Bug
    pub fn createBug(self: *AutoTest, req: zap.Request) !void {
        const body = try req.parseBody(BugAnalysisDto);
        const bug_id = try self.saveBug(body);
        try base.send_success(req, .{ .id = bug_id });
    }
    
    /// 获取 Bug 列表
    pub fn getBugList(self: *AutoTest, req: zap.Request) !void {
        const priority = req.getParam("priority");
        const limit = req.getParamInt("limit") orelse 10;
        
        const bugs = try self.queryBugs(priority, limit);
        try base.send_success(req, bugs);
    }
    
    /// 分析 Bug
    pub fn analyzeBug(self: *AutoTest, req: zap.Request) !void {
        const body = try req.parseBody(AnalyzeBugDto);
        const analysis = try self.performAnalysis(body);
        try base.send_success(req, analysis);
    }
    
    /// 自动修复
    pub fn autoFix(self: *AutoTest, req: zap.Request) !void {
        const body = try req.parseBody(AutoFixDto);
        const result = try self.attemptAutoFix(body);
        try base.send_success(req, result);
    }
    
    /// 更新 Bug 状态
    pub fn updateBugStatus(self: *AutoTest, req: zap.Request) !void {
        const body = try req.parseBody(UpdateStatusDto);
        try self.updateStatus(body);
        try base.send_success(req, .{ .message = "状态更新成功" });
    }
};
```

---

## 四、测试用例

### 4.1 单元测试

```zig
// src/mcp/tools/test_report_test.zig
const std = @import("std");
const testing = std.testing;
const TestReportTool = @import("test_report.zig").TestReportTool;

test "execute API test" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var tool = TestReportTool.init(allocator, .{});
    defer tool.deinit();
    
    const result = try tool.execute("execute", .{
        .test_type = "api",
        .test_target = "/api/user/login",
        .auto_report = true,
    });
    defer allocator.free(result);
    
    try testing.expect(result.len > 0);
}

test "analyze bug" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    var tool = TestReportTool.init(allocator, .{});
    defer tool.deinit();
    
    const result = try tool.execute("analyze", .{
        .bug_id = 1001,
    });
    defer allocator.free(result);
    
    try testing.expect(result.len > 0);
}
```

---

## 五、部署清单

### 5.1 前置条件

- [ ] 后端 API 已实现
- [ ] 数据库表已创建
- [ ] 测试环境已配置

### 5.2 部署步骤

1. **编译代码**
   ```bash
   zig build
   ```

2. **运行测试**
   ```bash
   zig build test
   ```

3. **启动服务**
   ```bash
   zig build run
   ```

4. **验证功能**
   ```bash
   # 测试 MCP 工具
   curl -X POST http://127.0.0.1:3000/mcp/message \
     -H "Content-Type: application/json" \
     -d '{
       "jsonrpc": "2.0",
       "method": "tools/call",
       "params": {
         "name": "test_report",
         "arguments": {
           "operation": "execute",
           "params": {
             "test_type": "api",
             "test_target": "/api/user/login",
             "auto_report": true
           }
         }
       },
       "id": 1
     }'
   ```

---

## 六、监控与维护

### 6.1 关键指标

- 测试执行成功率
- Bug 上报数量
- 自动修复成功率
- 平均响应时间

### 6.2 日志记录

所有操作都会记录详细日志：
- 测试执行日志
- Bug 分析日志
- 自动修复日志
- API 调用日志

### 6.3 告警规则

- 测试执行失败率 > 50%
- Bug 上报失败
- 自动修复失败率 > 80%
- API 响应超时

---

**老铁，这是完整的实现指南！** 🚀

下一步可以开始编写核心代码。
