/// MCP 自动测试上报工具 - 工具函数
/// 提供 Markdown 格式化、时间处理等通用能力
const std = @import("std");
const models = @import("models.zig");

/// Markdown 构建器，封装 ArrayList(u8) 简化 Markdown 输出
pub const MarkdownBuilder = struct {
    buf: std.ArrayList(u8),
    allocator: std.mem.Allocator,

    /// 初始化
    pub fn init(allocator: std.mem.Allocator) MarkdownBuilder {
        return .{
            .buf = std.ArrayList(u8).init(allocator),
            .allocator = allocator,
        };
    }

    /// 释放
    pub fn deinit(self: *MarkdownBuilder) void {
        self.buf.deinit();
    }

    /// 获取结果并转移所有权
    pub fn toOwnedSlice(self: *MarkdownBuilder) ![]const u8 {
        return self.buf.toOwnedSlice();
    }

    /// 追加原始文本
    pub fn append(self: *MarkdownBuilder, text: []const u8) !void {
        try self.buf.appendSlice(text);
    }

    /// 追加格式化文本
    pub fn appendFmt(self: *MarkdownBuilder, comptime fmt: []const u8, args: anytype) !void {
        const text = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(text);
        try self.buf.appendSlice(text);
    }

    /// 追加一级标题
    pub fn h1(self: *MarkdownBuilder, title: []const u8) !void {
        try self.buf.appendSlice("# ");
        try self.buf.appendSlice(title);
        try self.buf.appendSlice("\n\n");
    }

    /// 追加二级标题
    pub fn h2(self: *MarkdownBuilder, title: []const u8) !void {
        try self.buf.appendSlice("## ");
        try self.buf.appendSlice(title);
        try self.buf.appendSlice("\n\n");
    }

    /// 追加三级标题
    pub fn h3(self: *MarkdownBuilder, title: []const u8) !void {
        try self.buf.appendSlice("### ");
        try self.buf.appendSlice(title);
        try self.buf.appendSlice("\n\n");
    }

    /// 追加加粗键值对
    pub fn keyValue(self: *MarkdownBuilder, key: []const u8, value: []const u8) !void {
        try self.buf.appendSlice("**");
        try self.buf.appendSlice(key);
        try self.buf.appendSlice("**: ");
        try self.buf.appendSlice(value);
        try self.buf.appendSlice("\n");
    }

    /// 追加加粗键值对（格式化值）
    pub fn keyValueFmt(self: *MarkdownBuilder, key: []const u8, comptime fmt: []const u8, args: anytype) !void {
        const value = try std.fmt.allocPrint(self.allocator, fmt, args);
        defer self.allocator.free(value);
        try self.keyValue(key, value);
    }

    /// 开始表格（写表头）
    pub fn tableHeader(self: *MarkdownBuilder, headers: []const []const u8) !void {
        // 写表头行
        try self.buf.appendSlice("|");
        for (headers) |header| {
            try self.buf.appendSlice(" ");
            try self.buf.appendSlice(header);
            try self.buf.appendSlice(" |");
        }
        try self.buf.appendSlice("\n");

        // 写分隔行
        try self.buf.appendSlice("|");
        for (headers) |_| {
            try self.buf.appendSlice("------|");
        }
        try self.buf.appendSlice("\n");
    }

    /// 追加表格行
    pub fn tableRow(self: *MarkdownBuilder, cells: []const []const u8) !void {
        try self.buf.appendSlice("|");
        for (cells) |cell| {
            try self.buf.appendSlice(" ");
            try self.buf.appendSlice(cell);
            try self.buf.appendSlice(" |");
        }
        try self.buf.appendSlice("\n");
    }

    /// 追加列表项
    pub fn listItem(self: *MarkdownBuilder, text: []const u8) !void {
        try self.buf.appendSlice("- ");
        try self.buf.appendSlice(text);
        try self.buf.appendSlice("\n");
    }

    /// 追加加粗列表项
    pub fn listItemBold(self: *MarkdownBuilder, label: []const u8, value: []const u8) !void {
        try self.buf.appendSlice("- **");
        try self.buf.appendSlice(label);
        try self.buf.appendSlice("**: ");
        try self.buf.appendSlice(value);
        try self.buf.appendSlice("\n");
    }

    /// 追加代码块
    pub fn codeBlock(self: *MarkdownBuilder, lang: []const u8, code: []const u8) !void {
        try self.buf.appendSlice("```");
        try self.buf.appendSlice(lang);
        try self.buf.appendSlice("\n");
        try self.buf.appendSlice(code);
        try self.buf.appendSlice("\n```\n\n");
    }

    /// 追加空行
    pub fn newline(self: *MarkdownBuilder) !void {
        try self.buf.appendSlice("\n");
    }

    /// 追加分隔线
    pub fn separator(self: *MarkdownBuilder) !void {
        try self.buf.appendSlice("\n---\n\n");
    }
};

/// 获取当前时间戳（毫秒）
pub fn currentTimestampMs() i64 {
    return std.time.milliTimestamp();
}

/// 格式化时长（毫秒 -> 人类可读）
pub fn formatDuration(allocator: std.mem.Allocator, ms: i64) ![]const u8 {
    if (ms < 1000) {
        return std.fmt.allocPrint(allocator, "{d}ms", .{ms});
    } else if (ms < 60_000) {
        const secs = @as(f64, @floatFromInt(ms)) / 1000.0;
        return std.fmt.allocPrint(allocator, "{d:.1}s", .{secs});
    } else {
        const mins = @divFloor(ms, 60_000);
        const remaining_secs = @divFloor(@mod(ms, 60_000), 1000);
        return std.fmt.allocPrint(allocator, "{d}m {d}s", .{ mins, remaining_secs });
    }
}

/// 格式化通过率
pub fn formatPassRate(allocator: std.mem.Allocator, rate: f32) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{d:.1}%", .{rate});
}

/// 从 JSON 对象安全获取字符串字段
pub fn getJsonString(params: std.json.ObjectMap, key: []const u8) ?[]const u8 {
    if (params.get(key)) |val| {
        switch (val) {
            .string => |s| return s,
            else => return null,
        }
    }
    return null;
}

/// 从 JSON 对象安全获取整数字段
pub fn getJsonInt(params: std.json.ObjectMap, key: []const u8) ?i64 {
    if (params.get(key)) |val| {
        switch (val) {
            .integer => |i| return i,
            else => return null,
        }
    }
    return null;
}

/// 从 JSON 对象安全获取布尔字段
pub fn getJsonBool(params: std.json.ObjectMap, key: []const u8) ?bool {
    if (params.get(key)) |val| {
        switch (val) {
            .bool => |b| return b,
            else => return null,
        }
    }
    return null;
}

/// 从 JSON 对象安全获取嵌套对象
pub fn getJsonObject(params: std.json.ObjectMap, key: []const u8) ?std.json.ObjectMap {
    if (params.get(key)) |val| {
        switch (val) {
            .object => |o| return o,
            else => return null,
        }
    }
    return null;
}
