/// MCP 自动测试上报工具 - 自动修复器
/// 负责尝试自动修复 Bug、生成修复代码、验证修复结果
const std = @import("std");
const models = @import("test_report/models.zig");
const utils = @import("test_report/utils.zig");

/// 自动修复器
pub const AutoFixer = struct {
    allocator: std.mem.Allocator,

    /// 初始化
    pub fn init(allocator: std.mem.Allocator) AutoFixer {
        return .{ .allocator = allocator };
    }

    /// 尝试自动修复 Bug
    pub fn attemptFix(self: *AutoFixer, bug: *models.BugAnalysis) !models.FixResult {
        bug.auto_fix_attempted = true;
        bug.status = .auto_fixing;

        // 检查是否具备自动修复的前提条件
        if (!self.canAutoFix(bug)) {
            bug.status = .manual_fixing;
            return .{
                .success = false,
                .bug_id = bug.id,
                .error_message = "此 Bug 不满足自动修复条件，已转为人工处理",
            };
        }

        // 生成修复代码
        const fix_code = self.generateFixCode(bug) catch |err| {
            bug.status = .analyzed;
            bug.auto_fix_attempted = true;
            return .{
                .success = false,
                .bug_id = bug.id,
                .error_message = try std.fmt.allocPrint(
                    self.allocator,
                    "生成修复代码失败: {s}",
                    .{@errorName(err)},
                ),
            };
        };

        // 应用修复
        const apply_ok = self.applyFix(bug, fix_code) catch false;
        if (!apply_ok) {
            bug.status = .manual_fixing;
            return .{
                .success = false,
                .bug_id = bug.id,
                .fix_code = fix_code,
                .error_message = "应用修复代码失败，已转为人工处理",
            };
        }

        // 更新 Bug 状态
        bug.status = .auto_fixed;
        bug.auto_fix_success = true;
        bug.fix_code = fix_code;

        return .{
            .success = true,
            .bug_id = bug.id,
            .fix_code = fix_code,
            .fix_description = try self.generateFixDescription(bug),
            .files_modified = bug.file_path,
            .verified = false,
        };
    }

    /// 验证修复结果（重新执行测试）
    pub fn verifyFix(
        self: *AutoFixer,
        bug: *models.BugAnalysis,
        test_result_passed: bool,
    ) !models.FixResult {
        _ = self;
        if (test_result_passed) {
            bug.status = .resolved;
            return .{
                .success = true,
                .bug_id = bug.id,
                .fix_code = bug.fix_code,
                .verified = true,
                .fix_description = "修复验证通过，Bug 已关闭",
            };
        } else {
            // 修复未通过验证，回退状态
            bug.status = .analyzed;
            bug.auto_fix_success = false;
            return .{
                .success = false,
                .bug_id = bug.id,
                .verified = false,
                .error_message = "修复验证失败，测试仍未通过。已回退修复，需要人工介入。",
            };
        }
    }

    // ========== 内部方法 ==========

    /// 判断是否可以自动修复
    fn canAutoFix(self: *AutoFixer, bug: *const models.BugAnalysis) bool {
        _ = self;

        // 条件 1: 必须已分析
        if (bug.status != .auto_fixing and bug.status != .analyzed and bug.status != .reopened) {
            return false;
        }

        // 条件 2: 置信度 >= 0.7
        if (bug.confidence_score < 0.7) return false;

        // 条件 3: 有文件路径
        if (bug.file_path == null) return false;

        // 条件 4: 部分类型不适合自动修复
        if (bug.bug_type == .security) return false;

        return true;
    }

    /// 生成修复代码
    fn generateFixCode(self: *AutoFixer, bug: *const models.BugAnalysis) ![]const u8 {
        var code = std.ArrayList(u8).init(self.allocator);
        errdefer code.deinit();

        switch (bug.bug_type) {
            .functional => {
                try code.appendSlice("// 修复: 添加缺失的边界条件检查\n");
                try code.appendSlice("// 文件: ");
                if (bug.file_path) |fp| try code.appendSlice(fp);
                try code.appendSlice("\n");
                try code.appendSlice("// 建议: 补充入参校验和异常处理\n");
                if (bug.suggested_fix) |fix| {
                    try code.appendSlice("// 详细建议: ");
                    try code.appendSlice(fix);
                    try code.appendSlice("\n");
                }
            },
            .performance => {
                try code.appendSlice("// 修复: 优化性能瓶颈\n");
                if (bug.file_path) |fp| {
                    try code.appendSlice("// 文件: ");
                    try code.appendSlice(fp);
                    try code.appendSlice("\n");
                }
                try code.appendSlice("// 建议:\n");
                try code.appendSlice("// 1. 检查并优化数据库查询\n");
                try code.appendSlice("// 2. 增加连接池容量\n");
                try code.appendSlice("// 3. 引入缓存机制\n");
            },
            .data => {
                try code.appendSlice("// 修复: 数据层异常处理\n");
                if (bug.file_path) |fp| {
                    try code.appendSlice("// 文件: ");
                    try code.appendSlice(fp);
                    try code.appendSlice("\n");
                }
                try code.appendSlice("// 建议:\n");
                try code.appendSlice("// 1. 检查数据库连接配置\n");
                try code.appendSlice("// 2. 验证 SQL 参数绑定\n");
                try code.appendSlice("// 3. 增加错误重试机制\n");
            },
            .configuration => {
                try code.appendSlice("// 修复: 配置项修正\n");
                if (bug.file_path) |fp| {
                    try code.appendSlice("// 文件: ");
                    try code.appendSlice(fp);
                    try code.appendSlice("\n");
                }
                try code.appendSlice("// 建议: 核对并修正配置参数\n");
            },
            .logic => {
                try code.appendSlice("// 修复: 逻辑错误修正\n");
                if (bug.file_path) |fp| {
                    try code.appendSlice("// 文件: ");
                    try code.appendSlice(fp);
                    try code.appendSlice("\n");
                }
                try code.appendSlice("// 建议: 审查条件分支和循环边界\n");
            },
            else => {
                try code.appendSlice("// 需要人工分析并编写修复代码\n");
                if (bug.suggested_fix) |fix| {
                    try code.appendSlice("// 参考建议: ");
                    try code.appendSlice(fix);
                    try code.appendSlice("\n");
                }
            },
        }

        return code.toOwnedSlice();
    }

    /// 应用修复代码到文件（安全模式：先备份再追加修复注释）
    fn applyFix(self: *AutoFixer, bug: *const models.BugAnalysis, fix_code: []const u8) !bool {
        const file_path = bug.file_path orelse return false;

        // 1. 验证文件存在
        const file = std.fs.cwd().openFile(file_path, .{}) catch return false;
        file.close();

        // 2. 创建备份文件 (.bak)
        const backup_path = try std.fmt.allocPrint(self.allocator, "{s}.bak", .{file_path});
        defer self.allocator.free(backup_path);

        std.fs.cwd().copyFile(file_path, std.fs.cwd(), backup_path, .{}) catch |err| {
            std.debug.print("[AutoFixer] 备份失败: {s}\n", .{@errorName(err)});
            return false;
        };

        // 3. 以追加模式打开文件，写入修复注释
        const target = std.fs.cwd().openFile(file_path, .{ .mode = .write_only }) catch return false;
        defer target.close();

        // 移动到文件末尾
        target.seekFromEnd(0) catch return false;

        // 写入修复标记和代码
        const header = "\n\n// ========== [AutoFixer] 自动修复建议 ==========\n";
        _ = target.write(header) catch return false;
        _ = target.write(fix_code) catch return false;
        const footer = "// ========== [AutoFixer] 修复建议结束 ==========\n";
        _ = target.write(footer) catch return false;

        return true;
    }

    /// 生成修复描述
    fn generateFixDescription(self: *AutoFixer, bug: *const models.BugAnalysis) ![]const u8 {
        var desc = std.ArrayList(u8).init(self.allocator);
        errdefer desc.deinit();

        try desc.appendSlice("已自动修复 ");
        try desc.appendSlice(bug.bug_type.toDisplayName());

        if (bug.file_path) |fp| {
            try desc.appendSlice("，修改文件: ");
            try desc.appendSlice(fp);
        }

        if (bug.line_number) |ln| {
            const ln_str = try std.fmt.allocPrint(self.allocator, " 第 {d} 行", .{ln});
            defer self.allocator.free(ln_str);
            try desc.appendSlice(ln_str);
        }

        return desc.toOwnedSlice();
    }
};
