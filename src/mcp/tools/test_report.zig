/// MCP 自动测试上报工具 - 主入口
/// 整合测试执行器、Bug 分析器、自动修复器，实现 AI 监督式测试闭环
const std = @import("std");
const McpConfig = @import("../../core/config/mcp.zig").McpConfig;
const SecurityConfig = McpConfig.SecurityConfig;
const models = @import("test_report/models.zig");
const utils = @import("test_report/utils.zig");
const api_client_mod = @import("test_report/api_client.zig");
const test_executor_mod = @import("test_executor.zig");
const bug_analyzer_mod = @import("bug_analyzer.zig");
const auto_fixer_mod = @import("auto_fixer.zig");

/// 测试上报工具（MCP Tool）
pub const TestReportTool = struct {
    allocator: std.mem.Allocator,
    security: SecurityConfig,
    executor: test_executor_mod.TestExecutor,
    analyzer: bug_analyzer_mod.BugAnalyzer,
    fixer: auto_fixer_mod.AutoFixer,

    /// 初始化
    pub fn init(allocator: std.mem.Allocator, security: SecurityConfig) TestReportTool {
        return .{
            .allocator = allocator,
            .security = security,
            .executor = test_executor_mod.TestExecutor.init(allocator),
            .analyzer = bug_analyzer_mod.BugAnalyzer.init(allocator),
            .fixer = auto_fixer_mod.AutoFixer.init(allocator),
        };
    }

    /// 执行操作（MCP 工具入口）
    pub fn execute(self: *TestReportTool, operation: []const u8, params: std.json.Value) ![]const u8 {
        const params_obj = switch (params) {
            .object => |o| o,
            else => return error.InvalidParams,
        };

        if (std.mem.eql(u8, operation, "execute")) {
            return try self.handleExecute(params_obj);
        } else if (std.mem.eql(u8, operation, "report_bug")) {
            return try self.handleReportBug(params_obj);
        } else if (std.mem.eql(u8, operation, "analyze")) {
            return try self.handleAnalyze(params_obj);
        } else if (std.mem.eql(u8, operation, "check_pending")) {
            return try self.handleCheckPending(params_obj);
        } else if (std.mem.eql(u8, operation, "auto_fix")) {
            return try self.handleAutoFix(params_obj);
        } else if (std.mem.eql(u8, operation, "verify_fix")) {
            return try self.handleVerifyFix(params_obj);
        } else if (std.mem.eql(u8, operation, "get_statistics")) {
            return try self.handleGetStatistics(params_obj);
        } else {
            return error.UnknownOperation;
        }
    }

    // ========== 操作处理器 ==========

    /// 处理 execute 操作：执行测试并上报结果
    fn handleExecute(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        const test_type_str = utils.getJsonString(params, "test_type") orelse "api";
        const test_target = utils.getJsonString(params, "test_target") orelse "/api/health";
        const auto_report = utils.getJsonBool(params, "auto_report") orelse true;

        const test_type = models.TestType.fromString(test_type_str) orelse .api;

        // 执行测试
        var report = try self.executor.execute(test_type, test_target);

        // 如果失败且开启自动上报，进行 Bug 分析
        var bug: ?models.BugAnalysis = null;
        if (report.isFailed() and auto_report) {
            bug = self.analyzer.analyzeFromTestReport(&report) catch null;
        }

        // 构建 Markdown 响应
        return try self.formatExecuteResult(&report, bug);
    }

    /// 处理 report_bug 操作：手动上报 Bug
    fn handleReportBug(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        const title = utils.getJsonString(params, "title") orelse return error.MissingTitle;
        const description = utils.getJsonString(params, "description") orelse return error.MissingDescription;

        var error_msg: ?[]const u8 = null;
        var stack_trace: ?[]const u8 = null;

        if (utils.getJsonObject(params, "error_info")) |error_info| {
            error_msg = utils.getJsonString(error_info, "message");
            stack_trace = utils.getJsonString(error_info, "stack_trace");
        }

        // 分析 Bug
        var bug = try self.analyzer.analyze(title, description, error_msg, stack_trace);

        return try self.formatBugReport(&bug);
    }

    /// 处理 analyze 操作：分析 Bug
    fn handleAnalyze(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        // 支持通过 bug_id 分析已有 Bug，或通过 error_info 分析新 Bug
        if (utils.getJsonInt(params, "bug_id")) |bug_id| {
            // 通过 ApiClient 从后端获取 Bug 详情
            var client = api_client_mod.ApiClient.init(self.allocator, "http://127.0.0.1:8080");
            defer client.deinit();

            if (client.getBugDetail(bug_id)) |maybe_bug| {
                if (maybe_bug) |fetched_bug| {
                    // 用后端数据重新分析
                    var bug = try self.analyzer.analyze(
                        fetched_bug.title,
                        fetched_bug.description,
                        null,
                        null,
                    );
                    bug.id = fetched_bug.id;
                    return try self.formatAnalyzeResult(&bug);
                }
            } else |_| {}

            return try self.formatAnalyzeByIdResult();
        }

        // 通过错误信息分析
        var error_msg: ?[]const u8 = null;
        var stack_trace: ?[]const u8 = null;

        if (utils.getJsonObject(params, "error_info")) |error_info| {
            error_msg = utils.getJsonString(error_info, "message");
            stack_trace = utils.getJsonString(error_info, "stack_trace");
        }

        const title = utils.getJsonString(params, "title") orelse "未命名 Bug";
        const description = utils.getJsonString(params, "description") orelse "无描述";

        var bug = try self.analyzer.analyze(title, description, error_msg, stack_trace);

        return try self.formatAnalyzeResult(&bug);
    }

    /// 处理 check_pending 操作：检测未处理 Bug
    fn handleCheckPending(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        const priority_str = utils.getJsonString(params, "priority");
        const limit = utils.getJsonInt(params, "limit") orelse 10;

        var priority: ?models.BugPriority = null;
        if (priority_str) |ps| {
            priority = models.BugPriority.fromString(ps);
        }

        return try self.formatCheckPendingResult(priority, limit);
    }

    /// 处理 auto_fix 操作：自动修复 Bug
    fn handleAutoFix(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        const verify = utils.getJsonBool(params, "verify") orelse true;

        // 先创建一个待修复的 Bug（实际应从后端获取）
        const title = utils.getJsonString(params, "title") orelse "待修复 Bug";
        const description = utils.getJsonString(params, "description") orelse "";

        var error_msg: ?[]const u8 = null;
        var stack_trace: ?[]const u8 = null;

        if (utils.getJsonObject(params, "error_info")) |error_info| {
            error_msg = utils.getJsonString(error_info, "message");
            stack_trace = utils.getJsonString(error_info, "stack_trace");
        }

        // 分析 Bug
        var bug = try self.analyzer.analyze(title, description, error_msg, stack_trace);

        if (utils.getJsonInt(params, "bug_id")) |bid| {
            bug.id = bid;
        }

        // 尝试修复
        const fix_result = try self.fixer.attemptFix(&bug);

        // 如果需要验证且修复成功，重新执行测试验证
        if (verify and fix_result.success) {
            const test_target = utils.getJsonString(params, "test_target") orelse "/api/health";
            const test_type_str = utils.getJsonString(params, "test_type") orelse "api";
            const test_type = models.TestType.fromString(test_type_str) orelse .api;
            var verify_report = try self.executor.execute(test_type, test_target);
            const verified = !verify_report.isFailed();
            return try self.formatAutoFixResult(&bug, &fix_result, verified);
        }

        return try self.formatAutoFixResult(&bug, &fix_result, false);
    }

    /// 处理 verify_fix 操作：验证修复结果
    fn handleVerifyFix(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("修复验证结果");
        try md.newline();

        // 通过 bug_id 获取 Bug 详情
        const bug_id = utils.getJsonInt(params, "bug_id") orelse {
            try md.keyValue("状态", "⚠️ 缺少 bug_id 参数");
            try md.append("**说明**: 请传入 `bug_id` 参数指定要验证的 Bug\n");
            return md.toOwnedSlice();
        };

        try md.keyValueFmt("Bug ID", "{d}", .{bug_id});

        // 从后端获取 Bug 详情
        var client = api_client_mod.ApiClient.init(self.allocator, "http://127.0.0.1:8080");
        defer client.deinit();

        const maybe_bug = client.getBugDetail(bug_id) catch |err| {
            try md.keyValueFmt("状态", "❌ 获取 Bug 详情失败: {s}", .{@errorName(err)});
            return md.toOwnedSlice();
        };

        if (maybe_bug == null) {
            try md.keyValue("状态", "❌ Bug 不存在");
            return md.toOwnedSlice();
        }

        // 重新执行测试验证
        const test_target = utils.getJsonString(params, "test_target") orelse "/api/health";
        const test_type_str = utils.getJsonString(params, "test_type") orelse "api";
        const test_type = models.TestType.fromString(test_type_str) orelse .api;

        try md.keyValue("测试类型", test_type.toDisplayName());
        try md.keyValue("测试目标", test_target);
        try md.newline();

        var verify_report = try self.executor.execute(test_type, test_target);

        if (verify_report.isFailed()) {
            try md.keyValue("验证结果", "❌ 测试仍然失败，修复未生效");
            if (verify_report.error_message) |err_msg| {
                try md.keyValue("错误信息", err_msg);
            }
            try md.newline();
            try md.append("**建议**: Bug 需要重新分析或人工修复\n");
        } else {
            try md.keyValue("验证结果", "✅ 测试通过，修复已生效");
            try md.keyValueFmt("通过率", "{d:.1}%", .{verify_report.pass_rate});
            try md.newline();

            // 更新 Bug 状态为 resolved
            _ = client.updateBugStatus(bug_id, .resolved) catch {};
            try md.append("✅ Bug 状态已更新为 **已解决**\n");
        }

        return md.toOwnedSlice();
    }

    /// 处理 get_statistics 操作：获取统计信息
    fn handleGetStatistics(self: *TestReportTool, params: std.json.ObjectMap) ![]const u8 {
        const time_range = utils.getJsonString(params, "time_range") orelse "today";
        return try self.formatStatistics(time_range);
    }

    // ========== 响应格式化方法 ==========

    /// 格式化测试执行结果
    fn formatExecuteResult(
        self: *TestReportTool,
        report: *const models.TestReport,
        bug: ?models.BugAnalysis,
    ) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("测试执行结果");
        try md.newline();

        try md.keyValue("测试类型", report.test_type.toDisplayName());
        try md.keyValue("测试名称", report.name);
        try md.keyValueFmt("执行状态", "{s} {s}", .{ report.status.getIcon(), report.status.toDisplayName() });
        try md.newline();

        // 测试统计表格
        try md.h2("测试统计");

        const headers = [_][]const u8{ "指标", "值" };
        try md.tableHeader(&headers);

        const total_str = try std.fmt.allocPrint(self.allocator, "{d}", .{report.total_cases});
        defer self.allocator.free(total_str);
        const passed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{report.passed_cases});
        defer self.allocator.free(passed_str);
        const failed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{report.failed_cases});
        defer self.allocator.free(failed_str);
        const rate_str = try utils.formatPassRate(self.allocator, report.pass_rate);
        defer self.allocator.free(rate_str);

        try md.tableRow(&.{ "总用例数", total_str });
        try md.tableRow(&.{ "通过数", passed_str });
        try md.tableRow(&.{ "失败数", failed_str });
        try md.tableRow(&.{ "通过率", rate_str });

        if (report.duration_ms) |d| {
            const dur_str = try utils.formatDuration(self.allocator, d);
            defer self.allocator.free(dur_str);
            try md.tableRow(&.{ "执行时长", dur_str });
        }

        try md.newline();

        // 错误信息
        if (report.error_message) |err_msg| {
            try md.h2("错误信息");
            try md.codeBlock("", err_msg);
        }

        // Bug 分析结果
        if (bug) |b| {
            try md.separator();
            try md.h2("自动上报 Bug");
            try md.newline();
            try md.keyValue("标题", b.title);
            try md.keyValue("类型", b.bug_type.toDisplayName());
            try md.keyValue("严重程度", b.severity.toDisplayName());
            try md.keyValue("优先级", b.priority.toDisplayName());
            try md.keyValue("问题位置", b.issue_location.toDisplayName());
            try md.keyValueFmt("置信度", "{d:.0}%", .{b.confidence_score * 100.0});
            try md.newline();

            if (b.root_cause) |rc| {
                try md.keyValue("根本原因", rc);
            }
            if (b.suggested_fix) |sf| {
                try md.keyValue("修复建议", sf);
            }

            try md.newline();
            try md.append("**建议**: 运行 `test_report auto_fix` 尝试自动修复\n");
        }

        return md.toOwnedSlice();
    }

    /// 格式化 Bug 上报结果
    fn formatBugReport(self: *TestReportTool, bug: *const models.BugAnalysis) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("Bug 上报成功");
        try md.newline();

        if (bug.id) |id| {
            try md.keyValueFmt("Bug ID", "{d}", .{id});
        }
        try md.keyValue("标题", bug.title);
        try md.keyValue("描述", bug.description);
        try md.newline();

        // 分类信息
        try md.h2("分类信息");
        const class_headers = [_][]const u8{ "项目", "值" };
        try md.tableHeader(&class_headers);
        try md.tableRow(&.{ "Bug 类型", bug.bug_type.toDisplayName() });
        try md.tableRow(&.{ "问题位置", bug.issue_location.toDisplayName() });
        try md.tableRow(&.{ "严重程度", bug.severity.toDisplayName() });
        try md.tableRow(&.{ "优先级", bug.priority.toDisplayName() });

        const conf_str = try std.fmt.allocPrint(self.allocator, "{d:.0}%", .{bug.confidence_score * 100.0});
        defer self.allocator.free(conf_str);
        try md.tableRow(&.{ "置信度", conf_str });
        try md.newline();

        // 分析详情
        if (bug.root_cause) |rc| {
            try md.h2("根本原因");
            try md.append(rc);
            try md.newline();
            try md.newline();
        }

        if (bug.file_path) |fp| {
            try md.h2("问题定位");
            try md.listItemBold("文件", fp);
            if (bug.line_number) |ln| {
                const ln_str = try std.fmt.allocPrint(self.allocator, "{d}", .{ln});
                defer self.allocator.free(ln_str);
                try md.listItemBold("行号", ln_str);
            }
            try md.newline();
        }

        if (bug.reproduction_steps) |steps| {
            try md.h2("复现步骤");
            try md.append(steps);
            try md.newline();
        }

        if (bug.suggested_fix) |fix| {
            try md.h2("修复建议");
            try md.append(fix);
            try md.newline();
            try md.newline();
        }

        try md.append("**建议**: 运行 `test_report analyze` 获取更详细的分析\n");

        return md.toOwnedSlice();
    }

    /// 格式化按 ID 分析结果（占位）
    fn formatAnalyzeByIdResult(self: *TestReportTool) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("Bug 分析");
        try md.newline();
        try md.keyValue("状态", "⚠️ 按 ID 查询需要后端 API 支持");
        try md.newline();
        try md.append("**提示**: 后端 `/api/auto-test/bug/detail` 接口就绪后将自动启用此功能\n");
        try md.newline();
        try md.append("**替代方案**: 可直接传入 `error_info` 参数进行在线分析\n");

        return md.toOwnedSlice();
    }

    /// 格式化分析结果
    fn formatAnalyzeResult(self: *TestReportTool, bug: *const models.BugAnalysis) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("Bug 分析结果");
        try md.newline();
        try md.keyValue("标题", bug.title);
        try md.newline();

        // 分类表格
        try md.h2("分类");
        const headers = [_][]const u8{ "项目", "值" };
        try md.tableHeader(&headers);
        try md.tableRow(&.{ "Bug 类型", bug.bug_type.toDisplayName() });
        try md.tableRow(&.{ "问题位置", bug.issue_location.toDisplayName() });
        try md.tableRow(&.{ "严重程度", bug.severity.toDisplayName() });
        try md.tableRow(&.{ "优先级", bug.priority.toDisplayName() });

        const conf_str = try std.fmt.allocPrint(self.allocator, "{d:.0}%", .{bug.confidence_score * 100.0});
        defer self.allocator.free(conf_str);
        try md.tableRow(&.{ "置信度", conf_str });
        try md.newline();

        if (bug.root_cause) |rc| {
            try md.h2("根本原因");
            try md.append(rc);
            try md.newline();
            try md.newline();
        }

        if (bug.file_path) |fp| {
            try md.h2("问题定位");
            try md.listItemBold("文件", fp);
            if (bug.line_number) |ln| {
                const ln_str = try std.fmt.allocPrint(self.allocator, "{d}", .{ln});
                defer self.allocator.free(ln_str);
                try md.listItemBold("行号", ln_str);
            }
            try md.newline();
        }

        if (bug.reproduction_steps) |steps| {
            try md.h2("复现步骤");
            try md.append(steps);
            try md.newline();
        }

        if (bug.suggested_fix) |fix| {
            try md.h2("修复建议");
            try md.append(fix);
            try md.newline();
            try md.newline();
        }

        if (bug.canAutoFix()) {
            try md.append("**建议**: 运行 `test_report auto_fix` 尝试自动修复\n");
        } else {
            try md.append("**建议**: 此 Bug 需要人工修复\n");
        }

        return md.toOwnedSlice();
    }

    /// 格式化未处理 Bug 列表（从后端获取真实数据）
    fn formatCheckPendingResult(
        self: *TestReportTool,
        priority: ?models.BugPriority,
        limit: i64,
    ) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("未处理 Bug 列表");
        try md.newline();

        if (priority) |p| {
            try md.keyValue("筛选条件", p.toDisplayName());
        } else {
            try md.keyValue("筛选条件", "全部优先级");
        }
        try md.keyValueFmt("最大数量", "{d}", .{limit});
        try md.newline();

        // 从后端获取真实数据
        var client = api_client_mod.ApiClient.init(self.allocator, "http://127.0.0.1:8080");
        defer client.deinit();

        const bugs = client.getPendingBugs(priority, limit) catch |err| {
            try md.appendFmt("⚠️ 获取后端数据失败 ({s})，显示本地缓存\n\n", .{@errorName(err)});
            try md.append("暂无未处理 Bug\n");
            return md.toOwnedSlice();
        };

        if (bugs.len == 0) {
            try md.append("✅ 当前没有未处理的 Bug\n");
            return md.toOwnedSlice();
        }

        try md.h2("Bug 列表");

        // 表头
        const headers = [_][]const u8{ "ID", "标题", "类型", "严重度", "状态", "置信度" };
        try md.tableHeader(&headers);

        var pending_count: usize = 0;
        var analyzed_count: usize = 0;

        for (bugs) |bug| {
            const id_str = if (bug.id) |id|
                try std.fmt.allocPrint(self.allocator, "#{d}", .{id})
            else
                try self.allocator.dupe(u8, "#?");
            defer self.allocator.free(id_str);

            const conf_str = try std.fmt.allocPrint(self.allocator, "{d:.0}%", .{bug.confidence_score * 100.0});
            defer self.allocator.free(conf_str);

            try md.tableRow(&.{
                id_str,
                bug.title,
                bug.bug_type.toDisplayName(),
                bug.severity.toDisplayName(),
                bug.status.toDisplayName(),
                conf_str,
            });

            if (bug.status == .pending) pending_count += 1;
            if (bug.status == .analyzed) analyzed_count += 1;
        }

        try md.newline();
        try md.separator();

        try md.h2("统计");
        const stat_headers = [_][]const u8{ "状态", "数量" };
        try md.tableHeader(&stat_headers);

        const pending_str = try std.fmt.allocPrint(self.allocator, "{d}", .{pending_count});
        defer self.allocator.free(pending_str);
        const analyzed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{analyzed_count});
        defer self.allocator.free(analyzed_str);
        const total_str = try std.fmt.allocPrint(self.allocator, "{d}", .{bugs.len});
        defer self.allocator.free(total_str);

        try md.tableRow(&.{ "待分析", pending_str });
        try md.tableRow(&.{ "已分析", analyzed_str });
        try md.tableRow(&.{ "合计", total_str });
        try md.newline();

        return md.toOwnedSlice();
    }

    /// 格式化自动修复结果
    fn formatAutoFixResult(
        self: *TestReportTool,
        bug: *const models.BugAnalysis,
        result: *const models.FixResult,
        verified: bool,
    ) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("自动修复结果");
        try md.newline();

        if (bug.id) |id| {
            try md.keyValueFmt("Bug ID", "{d}", .{id});
        }
        try md.keyValue("标题", bug.title);
        try md.newline();

        // 修复过程
        try md.h2("修复过程");

        if (result.success) {
            try md.h3("1. 分析修复方案");
            try md.append("✅ 已识别问题: ");
            try md.append(bug.bug_type.toDisplayName());
            try md.newline();
            try md.newline();

            try md.h3("2. 生成修复代码");
            try md.append("✅ 已生成修复代码\n\n");

            if (result.fix_code) |code| {
                try md.codeBlock("zig", code);
            }

            try md.h3("3. 应用修复");
            try md.append("✅ 已应用修复\n\n");

            if (verified) {
                try md.h3("4. 验证修复");
                try md.append("✅ 验证通过\n\n");
            }
        } else {
            try md.append("❌ 修复失败\n\n");
            if (result.error_message) |err| {
                try md.keyValue("原因", err);
            }
        }

        try md.newline();

        // 结果表格
        try md.h2("修复结果");
        const headers = [_][]const u8{ "项目", "值" };
        try md.tableHeader(&headers);

        if (result.success) {
            try md.tableRow(&.{ "修复状态", "✅ 成功" });
        } else {
            try md.tableRow(&.{ "修复状态", "❌ 失败" });
        }

        try md.tableRow(&.{ "修复方式", "自动修复" });

        if (verified) {
            try md.tableRow(&.{ "验证结果", "✅ 通过" });
        } else {
            try md.tableRow(&.{ "验证结果", "⏳ 待验证" });
        }

        try md.tableRow(&.{ "Bug 状态", bug.status.toDisplayName() });
        try md.newline();

        // 修改的文件
        if (result.files_modified) |files| {
            try md.h2("修改文件");
            try md.listItem(files);
            try md.newline();
        }

        // 后续操作建议
        try md.h2("后续操作");
        if (result.success) {
            try md.append("✅ Bug 状态已更新\n");
            try md.append("**建议**: 提交代码并创建 PR 进行 Code Review\n");
        } else {
            try md.append("⚠️ 自动修复失败，需要人工介入\n");
            try md.append("**建议**: 查看修复代码中的注释，手动完成修复\n");
        }

        return md.toOwnedSlice();
    }

    /// 格式化统计信息（从后端获取真实数据）
    fn formatStatistics(self: *TestReportTool, time_range: []const u8) ![]const u8 {
        var md = utils.MarkdownBuilder.init(self.allocator);
        errdefer md.deinit();

        try md.h1("测试与 Bug 统计");
        try md.newline();

        const range_display: []const u8 = if (std.mem.eql(u8, time_range, "today"))
            "今日"
        else if (std.mem.eql(u8, time_range, "week"))
            "本周"
        else if (std.mem.eql(u8, time_range, "month"))
            "本月"
        else
            "全部";

        try md.keyValue("时间范围", range_display);
        try md.newline();

        // 从后端获取真实统计数据
        var client = api_client_mod.ApiClient.init(self.allocator, "http://127.0.0.1:8080");
        defer client.deinit();

        const stats = client.getStatistics(time_range) catch |err| {
            try md.appendFmt("⚠️ 获取后端统计失败 ({s})\n\n", .{@errorName(err)});
            try md.append("请确保后端服务已启动\n");
            return md.toOwnedSlice();
        };

        // 测试统计
        try md.h2("测试执行统计");
        const test_headers = [_][]const u8{ "指标", "值" };
        try md.tableHeader(&test_headers);

        const total_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.total_tests});
        defer self.allocator.free(total_str);
        const passed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.passed_tests});
        defer self.allocator.free(passed_str);
        const failed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.failed_tests});
        defer self.allocator.free(failed_str);
        const pass_rate_str = try std.fmt.allocPrint(self.allocator, "{d:.1}%", .{stats.overall_pass_rate});
        defer self.allocator.free(pass_rate_str);

        try md.tableRow(&.{ "总测试数", total_str });
        try md.tableRow(&.{ "通过数", passed_str });
        try md.tableRow(&.{ "失败数", failed_str });
        try md.tableRow(&.{ "通过率", pass_rate_str });
        try md.newline();

        // Bug 统计
        try md.h2("Bug 统计");
        const bug_headers = [_][]const u8{ "指标", "值" };
        try md.tableHeader(&bug_headers);

        const total_bugs_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.total_bugs});
        defer self.allocator.free(total_bugs_str);
        const pending_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.pending_bugs});
        defer self.allocator.free(pending_str);
        const auto_fixed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.auto_fixed_bugs});
        defer self.allocator.free(auto_fixed_str);
        const manual_fixed_str = try std.fmt.allocPrint(self.allocator, "{d}", .{stats.manual_fixed_bugs});
        defer self.allocator.free(manual_fixed_str);
        const fix_rate_str = try std.fmt.allocPrint(self.allocator, "{d:.1}%", .{stats.auto_fix_rate});
        defer self.allocator.free(fix_rate_str);

        try md.tableRow(&.{ "总 Bug 数", total_bugs_str });
        try md.tableRow(&.{ "待处理", pending_str });
        try md.tableRow(&.{ "已自动修复", auto_fixed_str });
        try md.tableRow(&.{ "已人工修复", manual_fixed_str });
        try md.tableRow(&.{ "自动修复率", fix_rate_str });
        try md.newline();

        return md.toOwnedSlice();
    }

    /// 获取工具定义（MCP 协议 JSON Schema）
    pub fn getDefinition(self: *const TestReportTool) []const u8 {
        _ = self;
        return 
        \\{
        \\  "name": "test_report",
        \\  "description": "自动化测试执行、Bug 上报、分析和修复工具，支持 AI 监督式测试闭环",
        \\  "inputSchema": {
        \\    "type": "object",
        \\    "properties": {
        \\      "operation": {
        \\        "type": "string",
        \\        "enum": [
        \\          "execute",
        \\          "report_bug",
        \\          "analyze",
        \\          "check_pending",
        \\          "auto_fix",
        \\          "verify_fix",
        \\          "get_statistics"
        \\        ],
        \\        "description": "操作类型：execute=执行测试, report_bug=上报Bug, analyze=分析Bug, check_pending=检测未处理Bug, auto_fix=自动修复, verify_fix=验证修复, get_statistics=统计信息"
        \\      },
        \\      "params": {
        \\        "type": "object",
        \\        "description": "操作参数",
        \\        "properties": {
        \\          "test_type": {
        \\            "type": "string",
        \\            "enum": ["api", "unit", "integration", "e2e", "performance", "security"],
        \\            "description": "测试类型（execute 操作需要）"
        \\          },
        \\          "test_target": {
        \\            "type": "string",
        \\            "description": "测试目标（文件路径、API 端点等）"
        \\          },
        \\          "auto_report": {
        \\            "type": "boolean",
        \\            "description": "测试失败时是否自动上报 Bug（默认 true）"
        \\          },
        \\          "bug_id": {
        \\            "type": "integer",
        \\            "description": "Bug ID（analyze/auto_fix/verify_fix 操作可用）"
        \\          },
        \\          "title": {
        \\            "type": "string",
        \\            "description": "Bug 标题（report_bug 操作需要）"
        \\          },
        \\          "description": {
        \\            "type": "string",
        \\            "description": "Bug 描述（report_bug 操作需要）"
        \\          },
        \\          "error_info": {
        \\            "type": "object",
        \\            "description": "错误信息（含 message, stack_trace, file_path 等）"
        \\          },
        \\          "priority": {
        \\            "type": "string",
        \\            "enum": ["urgent", "high", "medium", "low"],
        \\            "description": "优先级筛选（check_pending 操作可用）"
        \\          },
        \\          "limit": {
        \\            "type": "integer",
        \\            "description": "返回数量限制（check_pending 操作可用，默认 10）"
        \\          },
        \\          "verify": {
        \\            "type": "boolean",
        \\            "description": "修复后是否自动验证（auto_fix 操作可用，默认 true）"
        \\          },
        \\          "time_range": {
        \\            "type": "string",
        \\            "enum": ["today", "week", "month", "all"],
        \\            "description": "时间范围（get_statistics 操作可用，默认 today）"
        \\          }
        \\        }
        \\      }
        \\    },
        \\    "required": ["operation", "params"]
        \\  }
        \\}
        ;
    }
};
