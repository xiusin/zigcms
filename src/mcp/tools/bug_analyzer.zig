/// MCP 自动测试上报工具 - Bug 分析器
/// 负责分析错误信息、分类 Bug 类型、定位问题位置、生成修复建议
const std = @import("std");
const models = @import("test_report/models.zig");
const utils = @import("test_report/utils.zig");

/// Bug 分析器
pub const BugAnalyzer = struct {
    allocator: std.mem.Allocator,

    /// 初始化
    pub fn init(allocator: std.mem.Allocator) BugAnalyzer {
        return .{ .allocator = allocator };
    }

    /// 完整分析流程：分类 → 定位 → 评估 → 建议
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
            .bug_type = .functional,
            .severity = .p2,
            .priority = .medium,
            .issue_location = .unknown,
            .status = .analyzing,
            .analyzed_at = utils.currentTimestampMs(),
        };

        // 步骤 1: 分类 Bug 类型
        bug.bug_type = self.classifyBugType(error_message, stack_trace);

        // 步骤 2: 定位问题位置
        bug.issue_location = self.locateIssue(stack_trace, error_message);

        // 步骤 3: 提取文件路径和行号
        if (stack_trace) |trace| {
            const loc = self.extractFileLocation(trace);
            bug.file_path = loc.file_path;
            bug.line_number = loc.line_number;
        }

        // 步骤 4: 评估严重程度
        bug.severity = self.assessSeverity(&bug);

        // 步骤 5: 确定优先级
        bug.priority = self.determinePriority(&bug);

        // 步骤 6: 分析根本原因
        bug.root_cause = try self.analyzeRootCause(error_message, stack_trace, bug.bug_type);

        // 步骤 7: 生成复现步骤
        bug.reproduction_steps = try self.generateReproductionSteps(&bug);

        // 步骤 8: 生成修复建议
        bug.suggested_fix = try self.generateFixSuggestion(&bug);

        // 步骤 9: 计算置信度
        bug.confidence_score = self.calculateConfidence(&bug);

        bug.status = .analyzed;
        bug.created_at = utils.currentTimestampMs();

        return bug;
    }

    /// 从测试报告创建 Bug 分析
    pub fn analyzeFromTestReport(
        self: *BugAnalyzer,
        report: *const models.TestReport,
    ) !models.BugAnalysis {
        const title = try std.fmt.allocPrint(
            self.allocator,
            "测试失败: {s}",
            .{report.name},
        );

        const desc = try std.fmt.allocPrint(
            self.allocator,
            "{s} 执行失败，通过率 {d:.1}%，失败 {d} 个用例",
            .{ report.test_type.toDisplayName(), report.pass_rate, report.failed_cases },
        );

        var bug = try self.analyze(
            title,
            desc,
            report.error_message,
            report.stack_trace,
        );

        bug.test_report_id = report.id;
        return bug;
    }

    // ========== Bug 分类 ==========

    /// 根据错误信息和堆栈判断 Bug 类型
    fn classifyBugType(
        self: *BugAnalyzer,
        error_message: ?[]const u8,
        stack_trace: ?[]const u8,
    ) models.BugType {
        _ = self;

        if (error_message) |msg| {
            // 安全类关键词
            if (containsAny(msg, &.{ "unauthorized", "forbidden", "401", "403", "csrf", "xss", "injection" })) {
                return .security;
            }

            // 性能类关键词
            if (containsAny(msg, &.{ "timeout", "slow", "too many connections", "pool exhausted", "deadline exceeded" })) {
                return .performance;
            }

            // 数据类关键词
            if (containsAny(msg, &.{ "database", "connection", "query failed", "constraint violation", "duplicate key" })) {
                return .data;
            }

            // 网络类关键词
            if (containsAny(msg, &.{ "network", "dns", "connection refused", "ECONNREFUSED", "unreachable" })) {
                return .network;
            }

            // 配置类关键词
            if (containsAny(msg, &.{ "config", "environment", "missing key", "invalid setting", "not configured" })) {
                return .configuration;
            }

            // 500 错误通常是功能性问题
            if (containsAny(msg, &.{ "500", "Internal Server Error", "panic", "segfault" })) {
                return .functional;
            }

            // UI 类关键词
            if (containsAny(msg, &.{ "render", "display", "layout", "css", "style", "component" })) {
                return .ui;
            }
        }

        // 从堆栈中推断
        if (stack_trace) |trace| {
            if (containsAny(trace, &.{ "src/infrastructure/database", "sqlite", "postgres" })) {
                return .data;
            }
            if (containsAny(trace, &.{ "src/api", "controller", "router" })) {
                return .functional;
            }
        }

        return .functional;
    }

    // ========== 问题定位 ==========

    /// 根据堆栈和错误信息定位问题所在层
    fn locateIssue(
        self: *BugAnalyzer,
        stack_trace: ?[]const u8,
        error_message: ?[]const u8,
    ) models.IssueLocation {
        _ = self;

        if (stack_trace) |trace| {
            if (containsAny(trace, &.{ "src/api/", "controller" })) return .backend;
            if (containsAny(trace, &.{ "src/application/", "service" })) return .backend;
            if (containsAny(trace, &.{ "src/infrastructure/database", "repository" })) return .database;
            if (containsAny(trace, &.{ "src/infrastructure/", "redis", "cache" })) return .infrastructure;
            if (containsAny(trace, &.{ "ecom-admin/", "frontend/", "components/" })) return .frontend;
        }

        if (error_message) |msg| {
            if (containsAny(msg, &.{ "database", "sql", "query" })) return .database;
            if (containsAny(msg, &.{ "redis", "cache", "connection pool" })) return .infrastructure;
            if (containsAny(msg, &.{ "render", "component", "dom" })) return .frontend;
            if (containsAny(msg, &.{ "third_party", "external", "api call" })) return .third_party;
        }

        return .backend;
    }

    /// 从堆栈中提取文件路径和行号
    fn extractFileLocation(self: *BugAnalyzer, stack_trace: []const u8) FileLocation {
        _ = self;
        // 尝试匹配 "src/xxx/yyy.zig:123" 格式
        var iter = std.mem.splitSequence(u8, stack_trace, "\n");
        while (iter.next()) |line| {
            // 查找 .zig: 模式
            if (std.mem.indexOf(u8, line, ".zig:")) |zig_pos| {
                // 向前找路径起点
                var start: usize = 0;
                var i: usize = zig_pos;
                while (i > 0) : (i -= 1) {
                    if (line[i - 1] == ' ' or line[i - 1] == '\t' or line[i - 1] == '(') {
                        start = i;
                        break;
                    }
                }
                const colon_pos = zig_pos + 4; // ".zig:" 之后
                const file_path = line[start..colon_pos];

                // 提取行号
                var line_num: ?i32 = null;
                if (colon_pos < line.len) {
                    var end: usize = colon_pos;
                    while (end < line.len and line[end] >= '0' and line[end] <= '9') : (end += 1) {}
                    if (end > colon_pos) {
                        line_num = std.fmt.parseInt(i32, line[colon_pos..end], 10) catch null;
                    }
                }

                return .{
                    .file_path = file_path,
                    .line_number = line_num,
                };
            }
        }

        return .{ .file_path = null, .line_number = null };
    }

    // ========== 严重程度评估 ==========

    /// 根据 Bug 类型和位置评估严重程度
    fn assessSeverity(self: *BugAnalyzer, bug: *const models.BugAnalysis) models.BugSeverity {
        _ = self;

        // 安全问题一律 P0
        if (bug.bug_type == .security) return .p0;

        // 后端功能错误 P1
        if (bug.bug_type == .functional and bug.issue_location == .backend) return .p1;

        // 数据库问题 P1
        if (bug.bug_type == .data and bug.issue_location == .database) return .p1;

        // 性能问题 P2
        if (bug.bug_type == .performance) return .p2;

        // 网络问题 P2
        if (bug.bug_type == .network) return .p2;

        // 配置错误 P3
        if (bug.bug_type == .configuration) return .p3;

        // UI 问题 P3
        if (bug.bug_type == .ui) return .p3;

        return .p2;
    }

    // ========== 优先级确定 ==========

    /// 根据严重程度确定优先级
    fn determinePriority(self: *BugAnalyzer, bug: *const models.BugAnalysis) models.BugPriority {
        _ = self;
        return switch (bug.severity) {
            .p0 => .urgent,
            .p1 => .high,
            .p2 => .medium,
            .p3, .p4 => .low,
        };
    }

    // ========== 根因分析 ==========

    /// 分析根本原因
    fn analyzeRootCause(
        self: *BugAnalyzer,
        error_message: ?[]const u8,
        stack_trace: ?[]const u8,
        bug_type: models.BugType,
    ) ![]const u8 {
        var cause = std.ArrayList(u8).init(self.allocator);
        errdefer cause.deinit();

        // 基于 Bug 类型给出通用原因
        switch (bug_type) {
            .functional => try cause.appendSlice("业务逻辑处理异常"),
            .performance => try cause.appendSlice("系统响应超时或资源瓶颈"),
            .data => try cause.appendSlice("数据库操作异常"),
            .security => try cause.appendSlice("安全策略缺失或配置不当"),
            .network => try cause.appendSlice("网络连接异常"),
            .configuration => try cause.appendSlice("系统配置错误"),
            .ui => try cause.appendSlice("界面渲染异常"),
            .logic => try cause.appendSlice("代码逻辑错误"),
        }

        // 从错误信息中补充具体信息
        if (error_message) |msg| {
            try cause.appendSlice("。具体错误: ");
            const max_len: usize = @min(msg.len, 200);
            try cause.appendSlice(msg[0..max_len]);
        }

        if (stack_trace) |trace| {
            const loc = self.extractFileLocation(trace);
            if (loc.file_path) |fp| {
                try cause.appendSlice("。问题定位于文件: ");
                try cause.appendSlice(fp);
                if (loc.line_number) |ln| {
                    const ln_str = try std.fmt.allocPrint(self.allocator, ":{d}", .{ln});
                    defer self.allocator.free(ln_str);
                    try cause.appendSlice(ln_str);
                }
            }
        }

        return cause.toOwnedSlice();
    }

    // ========== 复现步骤生成 ==========

    /// 生成复现步骤
    fn generateReproductionSteps(
        self: *BugAnalyzer,
        bug: *const models.BugAnalysis,
    ) ![]const u8 {
        var steps = std.ArrayList(u8).init(self.allocator);
        errdefer steps.deinit();

        switch (bug.bug_type) {
            .functional => {
                try steps.appendSlice("1. 调用相关 API 接口\n");
                try steps.appendSlice("2. 传入触发错误的参数\n");
                try steps.appendSlice("3. 观察返回的错误状态码和消息\n");
            },
            .performance => {
                try steps.appendSlice("1. 准备并发测试环境\n");
                try steps.appendSlice("2. 发送大量并发请求\n");
                try steps.appendSlice("3. 监控响应时间和系统资源\n");
            },
            .data => {
                try steps.appendSlice("1. 检查数据库连接配置\n");
                try steps.appendSlice("2. 执行相关数据库操作\n");
                try steps.appendSlice("3. 检查错误日志中的 SQL 异常\n");
            },
            .security => {
                try steps.appendSlice("1. 构造恶意请求数据\n");
                try steps.appendSlice("2. 发送请求到目标端点\n");
                try steps.appendSlice("3. 验证安全防护是否生效\n");
            },
            else => {
                try steps.appendSlice("1. 复现操作场景\n");
                try steps.appendSlice("2. 按描述的步骤操作\n");
                try steps.appendSlice("3. 观察异常行为\n");
            },
        }

        if (bug.file_path) |fp| {
            try steps.appendSlice("4. 查看文件: ");
            try steps.appendSlice(fp);
            if (bug.line_number) |ln| {
                const ln_str = try std.fmt.allocPrint(self.allocator, ":{d}", .{ln});
                defer self.allocator.free(ln_str);
                try steps.appendSlice(ln_str);
            }
            try steps.appendSlice("\n");
        }

        return steps.toOwnedSlice();
    }

    // ========== 修复建议 ==========

    /// 生成修复建议
    fn generateFixSuggestion(
        self: *BugAnalyzer,
        bug: *const models.BugAnalysis,
    ) ![]const u8 {
        const suggestion = switch (bug.bug_type) {
            .functional => "检查业务逻辑，确保所有边界条件都被正确处理。验证入参校验是否完备，异常路径是否有兜底处理。",
            .performance => "优化查询性能，考虑添加数据库索引或引入缓存。检查连接池配置是否合理，是否存在 N+1 查询问题。",
            .data => "检查数据库连接配置和连接池大小。验证 SQL 语句是否正确，参数绑定是否完整。排查数据约束冲突。",
            .security => "立即修复安全漏洞。检查输入验证、参数绑定、权限校验。进行全面的安全审计。",
            .network => "检查网络连接配置和超时设置。验证目标服务是否可达，DNS 解析是否正常。",
            .configuration => "核对配置文件中的各项参数。检查环境变量是否正确设置，配置文件路径是否正确。",
            .ui => "检查前端组件渲染逻辑。验证数据绑定是否正确，样式是否兼容。",
            .logic => "审查代码逻辑流程，特别关注条件分支和循环边界。增加单元测试覆盖。",
        };

        return try self.allocator.dupe(u8, suggestion);
    }

    // ========== 置信度计算 ==========

    /// 计算分析置信度
    fn calculateConfidence(self: *BugAnalyzer, bug: *const models.BugAnalysis) f32 {
        _ = self;
        var score: f32 = 0.5;

        // 有明确的文件路径和行号，置信度提高
        if (bug.file_path != null) score += 0.15;
        if (bug.line_number != null) score += 0.10;

        // 有根本原因分析，置信度提高
        if (bug.root_cause != null) score += 0.10;

        // 有修复建议，置信度提高
        if (bug.suggested_fix != null) score += 0.10;

        // 类型明确（非 functional 兜底），置信度更高
        if (bug.bug_type != .functional) score += 0.05;

        return @min(score, 0.99);
    }

    // ========== 辅助函数 ==========

    /// 检查字符串是否包含给定关键词列表中的任一项（大小写不敏感）
    fn containsAny(haystack: []const u8, needles: []const []const u8) bool {
        for (needles) |needle| {
            if (containsIgnoreCase(haystack, needle)) return true;
        }
        return false;
    }

    /// 大小写不敏感的子串查找
    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len > haystack.len) return false;
        if (needle.len == 0) return true;

        const end = haystack.len - needle.len + 1;
        for (0..end) |i| {
            var matched = true;
            for (0..needle.len) |j| {
                if (toLowerAscii(haystack[i + j]) != toLowerAscii(needle[j])) {
                    matched = false;
                    break;
                }
            }
            if (matched) return true;
        }
        return false;
    }

    /// ASCII 小写转换
    fn toLowerAscii(c: u8) u8 {
        return if (c >= 'A' and c <= 'Z') c + 32 else c;
    }
};

/// 文件位置信息（内部使用）
const FileLocation = struct {
    file_path: ?[]const u8,
    line_number: ?i32,
};
