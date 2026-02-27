//! 字符串工具模块
//!
//! 提供字符串处理相关的工具函数。

const std = @import("std");

/// 去除首尾空白
pub fn trim(s: []const u8) []const u8 {
    return std.mem.trim(u8, s, " \t\n\r");
}

/// 去除左侧空白
pub fn trimLeft(s: []const u8) []const u8 {
    return std.mem.trimLeft(u8, s, " \t\n\r");
}

/// 去除右侧空白
pub fn trimRight(s: []const u8) []const u8 {
    return std.mem.trimRight(u8, s, " \t\n\r");
}

/// 判断是否为空
pub fn isEmpty(s: []const u8) bool {
    return s.len == 0;
}

/// 判断是否为空白
pub fn isBlank(s: []const u8) bool {
    return trim(s).len == 0;
}

/// 判断是否以指定前缀开头
pub fn startsWith(s: []const u8, prefix: []const u8) bool {
    return std.mem.startsWith(u8, s, prefix);
}

/// 判断是否以指定后缀结尾
pub fn endsWith(s: []const u8, suffix: []const u8) bool {
    return std.mem.endsWith(u8, s, suffix);
}

/// 判断是否包含子串
pub fn contains(s: []const u8, needle: []const u8) bool {
    return std.mem.indexOf(u8, s, needle) != null;
}

/// 转换为小写
pub fn toLower(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = std.ascii.toLower(c);
    }
    return result;
}

/// 转换为大写
pub fn toUpper(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    const result = try allocator.alloc(u8, s.len);
    for (s, 0..) |c, i| {
        result[i] = std.ascii.toUpper(c);
    }
    return result;
}

/// 替换所有匹配项
pub fn replaceAll(allocator: std.mem.Allocator, s: []const u8, old: []const u8, new: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    var i: usize = 0;
    while (i < s.len) {
        if (i + old.len <= s.len and std.mem.eql(u8, s[i .. i + old.len], old)) {
            try result.appendSlice(new);
            i += old.len;
        } else {
            try result.append(s[i]);
            i += 1;
        }
    }

    return result.toOwnedSlice();
}

/// 分割字符串
pub fn split(s: []const u8, delimiter: u8) std.mem.SplitIterator(u8, .scalar) {
    return std.mem.splitScalar(u8, s, delimiter);
}

/// 连接字符串数组
pub fn join(allocator: std.mem.Allocator, parts: []const []const u8, separator: []const u8) ![]u8 {
    if (parts.len == 0) return try allocator.alloc(u8, 0);

    var total_len: usize = 0;
    for (parts) |part| {
        total_len += part.len;
    }
    total_len += separator.len * (parts.len - 1);

    const result = try allocator.alloc(u8, total_len);
    var pos: usize = 0;

    for (parts, 0..) |part, i| {
        @memcpy(result[pos .. pos + part.len], part);
        pos += part.len;
        if (i < parts.len - 1) {
            @memcpy(result[pos .. pos + separator.len], separator);
            pos += separator.len;
        }
    }

    return result;
}
