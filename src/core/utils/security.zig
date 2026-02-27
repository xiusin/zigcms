//! 安全工具模块
//!
//! 提供安全相关的工具函数，包括密码哈希、输入验证等。

const std = @import("std");

/// 密码哈希算法
pub const HashAlgorithm = enum {
    Sha256,
    Sha512,
    Bcrypt,
};

/// 生成密码哈希
pub fn hashPassword(allocator: std.mem.Allocator, password: []const u8, salt: []const u8) ![]u8 {
    var hasher = std.crypto.hash.sha2.Sha256.init(.{});
    hasher.update(password);
    hasher.update(salt);
    const hash = hasher.finalResult();

    const result = try allocator.alloc(u8, hash.len * 2);
    for (hash, 0..) |byte, i| {
        const hex = "0123456789abcdef";
        result[i * 2] = hex[byte >> 4];
        result[i * 2 + 1] = hex[byte & 0x0f];
    }
    return result;
}

/// 验证密码
pub fn verifyPassword(password: []const u8, salt: []const u8, hash: []const u8, allocator: std.mem.Allocator) !bool {
    const computed = try hashPassword(allocator, password, salt);
    defer allocator.free(computed);
    return std.mem.eql(u8, computed, hash);
}

/// 生成随机盐
pub fn generateSalt(buf: []u8) void {
    std.crypto.random.bytes(buf);
}

/// 检测 SQL 注入
pub fn containsSqlInjection(input: []const u8) bool {
    const dangerous_patterns = [_][]const u8{
        "'",
        "\"",
        ";",
        "--",
        "/*",
        "*/",
        "xp_",
        "sp_",
        "0x",
    };

    const lower_input = input;
    for (dangerous_patterns) |pattern| {
        if (std.mem.indexOf(u8, lower_input, pattern) != null) {
            return true;
        }
    }
    return false;
}

/// 检测 XSS 攻击
pub fn containsXss(input: []const u8) bool {
    const dangerous_patterns = [_][]const u8{
        "<script",
        "javascript:",
        "onerror=",
        "onload=",
        "onclick=",
        "onmouseover=",
    };

    for (dangerous_patterns) |pattern| {
        if (containsIgnoreCase(input, pattern)) {
            return true;
        }
    }
    return false;
}

/// 忽略大小写的包含检测
fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    while (i + needle.len <= haystack.len) : (i += 1) {
        var match = true;
        for (needle, 0..) |c, j| {
            if (std.ascii.toLower(haystack[i + j]) != std.ascii.toLower(c)) {
                match = false;
                break;
            }
        }
        if (match) return true;
    }
    return false;
}

/// 检测路径遍历攻击
pub fn containsPathTraversal(input: []const u8) bool {
    return std.mem.indexOf(u8, input, "..") != null or
        std.mem.indexOf(u8, input, "~") != null;
}

/// 转义 HTML
pub fn escapeHtml(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
    var result = std.ArrayList(u8).init(allocator);
    errdefer result.deinit();

    for (input) |c| {
        switch (c) {
            '<' => try result.appendSlice("&lt;"),
            '>' => try result.appendSlice("&gt;"),
            '&' => try result.appendSlice("&amp;"),
            '"' => try result.appendSlice("&quot;"),
            '\'' => try result.appendSlice("&#x27;"),
            else => try result.append(c),
        }
    }

    return result.toOwnedSlice();
}
