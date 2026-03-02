/// MCP 自动测试上报工具 - 数据模型
/// 定义测试报告、Bug 分析相关的结构体和枚举类型
const std = @import("std");

/// 测试类型
pub const TestType = enum {
    api,
    unit,
    integration,
    e2e,
    performance,
    security,

    /// 转为字符串
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

    /// 转为中文描述
    pub fn toDisplayName(self: TestType) []const u8 {
        return switch (self) {
            .api => "API 测试",
            .unit => "单元测试",
            .integration => "集成测试",
            .e2e => "端到端测试",
            .performance => "性能测试",
            .security => "安全测试",
        };
    }

    /// 从字符串解析
    pub fn fromString(s: []const u8) ?TestType {
        const map = std.StaticStringMap(TestType).initComptime(.{
            .{ "api", .api },
            .{ "unit", .unit },
            .{ "integration", .integration },
            .{ "e2e", .e2e },
            .{ "performance", .performance },
            .{ "security", .security },
        });
        return map.get(s);
    }
};

/// 测试状态
pub const TestStatus = enum {
    pending,
    running,
    passed,
    failed,
    @"error",
    skipped,

    /// 转为字符串
    pub fn toString(self: TestStatus) []const u8 {
        return switch (self) {
            .pending => "pending",
            .running => "running",
            .passed => "passed",
            .failed => "failed",
            .@"error" => "error",
            .skipped => "skipped",
        };
    }

    /// 转为带图标的中文描述
    pub fn toDisplayName(self: TestStatus) []const u8 {
        return switch (self) {
            .pending => "待执行",
            .running => "执行中",
            .passed => "通过",
            .failed => "失败",
            .@"error" => "错误",
            .skipped => "跳过",
        };
    }

    /// 获取状态图标
    pub fn getIcon(self: TestStatus) []const u8 {
        return switch (self) {
            .pending => "⏳",
            .running => "🔄",
            .passed => "✅",
            .failed => "❌",
            .@"error" => "💥",
            .skipped => "⏭️",
        };
    }
};

/// 测试报告
pub const TestReport = struct {
    id: ?i64 = null,

    /// 基本信息
    name: []const u8,
    test_type: TestType,
    status: TestStatus,

    /// 测试结果统计
    total_cases: i32 = 0,
    passed_cases: i32 = 0,
    failed_cases: i32 = 0,
    skipped_cases: i32 = 0,
    pass_rate: f32 = 0.0,

    /// 执行信息
    started_at: ?i64 = null,
    completed_at: ?i64 = null,
    duration_ms: ?i64 = null,

    /// 错误信息
    error_message: ?[]const u8 = null,
    stack_trace: ?[]const u8 = null,

    /// 关联信息
    bug_id: ?i64 = null,
    feedback_id: ?i64 = null,

    /// 元数据
    created_by: []const u8 = "AI",
    created_at: ?i64 = null,
    updated_at: ?i64 = null,

    /// 计算通过率
    pub fn calculatePassRate(self: *TestReport) void {
        if (self.total_cases > 0) {
            self.pass_rate = @as(f32, @floatFromInt(self.passed_cases)) /
                @as(f32, @floatFromInt(self.total_cases)) * 100.0;
        }
    }

    /// 计算执行时长
    pub fn calculateDuration(self: *TestReport) void {
        if (self.started_at) |started| {
            if (self.completed_at) |completed| {
                self.duration_ms = completed - started;
            }
        }
    }

    /// 是否失败
    pub fn isFailed(self: *const TestReport) bool {
        return self.status == .failed or self.status == .@"error";
    }
};

/// 测试用例结果（单条）
pub const TestCaseResult = struct {
    name: []const u8,
    status: TestStatus,
    duration_ms: ?i64 = null,
    error_message: ?[]const u8 = null,
    expected: ?[]const u8 = null,
    actual: ?[]const u8 = null,
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

    /// 转为字符串
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

    /// 转为中文描述
    pub fn toDisplayName(self: BugType) []const u8 {
        return switch (self) {
            .functional => "功能错误",
            .ui => "界面问题",
            .performance => "性能问题",
            .security => "安全问题",
            .data => "数据问题",
            .logic => "逻辑错误",
            .configuration => "配置错误",
            .network => "网络问题",
        };
    }

    /// 从字符串解析
    pub fn fromString(s: []const u8) ?BugType {
        const map = std.StaticStringMap(BugType).initComptime(.{
            .{ "functional", .functional },
            .{ "ui", .ui },
            .{ "performance", .performance },
            .{ "security", .security },
            .{ "data", .data },
            .{ "logic", .logic },
            .{ "configuration", .configuration },
            .{ "network", .network },
        });
        return map.get(s);
    }
};

/// Bug 严重程度
pub const BugSeverity = enum {
    p0,
    p1,
    p2,
    p3,
    p4,

    /// 转为字符串
    pub fn toString(self: BugSeverity) []const u8 {
        return switch (self) {
            .p0 => "p0",
            .p1 => "p1",
            .p2 => "p2",
            .p3 => "p3",
            .p4 => "p4",
        };
    }

    /// 转为中文描述
    pub fn toDisplayName(self: BugSeverity) []const u8 {
        return switch (self) {
            .p0 => "P0 (致命)",
            .p1 => "P1 (严重)",
            .p2 => "P2 (一般)",
            .p3 => "P3 (轻微)",
            .p4 => "P4 (建议)",
        };
    }
};

/// Bug 优先级
pub const BugPriority = enum {
    urgent,
    high,
    medium,
    low,

    /// 转为字符串
    pub fn toString(self: BugPriority) []const u8 {
        return switch (self) {
            .urgent => "urgent",
            .high => "high",
            .medium => "medium",
            .low => "low",
        };
    }

    /// 转为中文描述
    pub fn toDisplayName(self: BugPriority) []const u8 {
        return switch (self) {
            .urgent => "紧急",
            .high => "高",
            .medium => "中",
            .low => "低",
        };
    }

    /// 从字符串解析
    pub fn fromString(s: []const u8) ?BugPriority {
        const map = std.StaticStringMap(BugPriority).initComptime(.{
            .{ "urgent", .urgent },
            .{ "high", .high },
            .{ "medium", .medium },
            .{ "low", .low },
        });
        return map.get(s);
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

    /// 转为字符串
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

    /// 转为中文描述
    pub fn toDisplayName(self: IssueLocation) []const u8 {
        return switch (self) {
            .frontend => "前端",
            .backend => "后端",
            .database => "数据库",
            .infrastructure => "基础设施",
            .third_party => "第三方",
            .unknown => "未知",
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

    /// 转为字符串
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

    /// 转为中文描述
    pub fn toDisplayName(self: BugStatus) []const u8 {
        return switch (self) {
            .pending => "待处理",
            .analyzing => "分析中",
            .analyzed => "已分析",
            .auto_fixing => "自动修复中",
            .auto_fixed => "已自动修复",
            .manual_fixing => "人工修复中",
            .resolved => "已解决",
            .closed => "已关闭",
            .reopened => "已重新打开",
        };
    }

    /// 从字符串解析
    pub fn fromString(s: []const u8) ?BugStatus {
        const map = std.StaticStringMap(BugStatus).initComptime(.{
            .{ "pending", .pending },
            .{ "analyzing", .analyzing },
            .{ "analyzed", .analyzed },
            .{ "auto_fixing", .auto_fixing },
            .{ "auto_fixed", .auto_fixed },
            .{ "manual_fixing", .manual_fixing },
            .{ "resolved", .resolved },
            .{ "closed", .closed },
            .{ "reopened", .reopened },
        });
        return map.get(s);
    }

    /// 是否为未处理状态
    pub fn isPending(self: BugStatus) bool {
        return self == .pending or self == .analyzing or self == .analyzed or self == .reopened;
    }
};

/// Bug 分析结果
pub const BugAnalysis = struct {
    id: ?i64 = null,

    /// Bug 基本信息
    title: []const u8,
    description: []const u8,
    bug_type: BugType,
    severity: BugSeverity,
    priority: BugPriority,

    /// 问题定位
    issue_location: IssueLocation,
    file_path: ?[]const u8 = null,
    line_number: ?i32 = null,

    /// 分析结果
    root_cause: ?[]const u8 = null,
    reproduction_steps: ?[]const u8 = null,
    suggested_fix: ?[]const u8 = null,
    confidence_score: f32 = 0.0,

    /// 修复状态
    status: BugStatus,
    auto_fix_attempted: bool = false,
    auto_fix_success: bool = false,
    fix_code: ?[]const u8 = null,

    /// 关联信息
    test_report_id: ?i64 = null,
    feedback_id: ?i64 = null,

    /// 元数据
    analyzed_by: []const u8 = "AI",
    analyzed_at: ?i64 = null,
    created_at: ?i64 = null,
    updated_at: ?i64 = null,

    /// 是否可尝试自动修复
    pub fn canAutoFix(self: *const BugAnalysis) bool {
        return (self.status == .analyzed or self.status == .reopened) and
            self.confidence_score >= 0.7 and
            !self.auto_fix_attempted;
    }
};

/// 修复结果
pub const FixResult = struct {
    success: bool,
    bug_id: ?i64 = null,
    fix_code: ?[]const u8 = null,
    fix_description: ?[]const u8 = null,
    files_modified: ?[]const u8 = null,
    verified: bool = false,
    error_message: ?[]const u8 = null,
};

/// 错误信息（用于 Bug 上报）
pub const ErrorInfo = struct {
    message: ?[]const u8 = null,
    stack_trace: ?[]const u8 = null,
    file_path: ?[]const u8 = null,
    line_number: ?i32 = null,
    http_status: ?i32 = null,
    endpoint: ?[]const u8 = null,
};

/// 统计信息
pub const TestStatistics = struct {
    total_tests: i32 = 0,
    passed_tests: i32 = 0,
    failed_tests: i32 = 0,
    total_bugs: i32 = 0,
    pending_bugs: i32 = 0,
    auto_fixed_bugs: i32 = 0,
    manual_fixed_bugs: i32 = 0,
    auto_fix_rate: f32 = 0.0,
    overall_pass_rate: f32 = 0.0,

    /// 计算自动修复率
    pub fn calculateAutoFixRate(self: *TestStatistics) void {
        const fixed = self.auto_fixed_bugs + self.manual_fixed_bugs;
        if (fixed > 0) {
            self.auto_fix_rate = @as(f32, @floatFromInt(self.auto_fixed_bugs)) /
                @as(f32, @floatFromInt(fixed)) * 100.0;
        }
    }

    /// 计算整体通过率
    pub fn calculateOverallPassRate(self: *TestStatistics) void {
        if (self.total_tests > 0) {
            self.overall_pass_rate = @as(f32, @floatFromInt(self.passed_tests)) /
                @as(f32, @floatFromInt(self.total_tests)) * 100.0;
        }
    }
};
