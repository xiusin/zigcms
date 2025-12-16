//! 安全防护模块
//!
//! 提供 SQL 注入、XSS 攻击、命令注入等安全防护功能。
//!
//! ## 使用示例
//!
//! ```zig
//! const security = @import("validator/mod.zig").security;
//!
//! // 检查输入是否安全
//! if (!security.isClean(user_input)) {
//!     return error.PotentialAttack;
//! }
//!
//! // 清理用户输入
//! const safe_input = try security.sanitize(allocator, user_input);
//! defer allocator.free(safe_input);
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 安全检测结果
pub const ThreatType = enum {
    none,
    sql_injection,
    xss_attack,
    command_injection,
    path_traversal,
    ldap_injection,
    header_injection,
};

/// 安全检测结果
pub const SecurityCheck = struct {
    is_safe: bool,
    threat_type: ThreatType,
    details: ?[]const u8,
};

/// 安全防护类
pub const Security = struct {
    const Self = @This();

    allocator: Allocator,

    pub fn init(allocator: Allocator) Self {
        return .{ .allocator = allocator };
    }

    /// 不区分大小写的字符串查找
    fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
        if (needle.len == 0) return true;
        if (haystack.len < needle.len) return false;

        var i: usize = 0;
        while (i <= haystack.len - needle.len) : (i += 1) {
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

    /// 检测 SQL 注入
    pub fn detectSqlInjection(self: *Self, input: []const u8) SecurityCheck {
        _ = self;

        const sql_patterns = [_][]const u8{
            "' OR ",
            "' AND ",
            "'; --",
            "' --",
            "1=1",
            "1 = 1",
            "' OR '1'='1",
            "' OR 1=1--",
            "admin'--",
            "' UNION ",
            "' SELECT ",
            "' INSERT ",
            "' UPDATE ",
            "' DELETE ",
            "' DROP ",
            "' TRUNCATE ",
            "' ALTER ",
            "' CREATE ",
            "' EXEC ",
            "' EXECUTE ",
            "/*",
            "*/",
            "@@",
            "char(",
            "nchar(",
            "varchar(",
            "nvarchar(",
            "cast(",
            "convert(",
            "table(",
            "sys.",
            "sysobjects",
            "syscolumns",
            "information_schema",
            "waitfor delay",
            "benchmark(",
            "sleep(",
            "pg_sleep",
        };

        for (sql_patterns) |pattern| {
            if (containsIgnoreCase(input, pattern)) {
                return .{
                    .is_safe = false,
                    .threat_type = .sql_injection,
                    .details = "检测到潜在的 SQL 注入攻击",
                };
            }
        }

        return .{ .is_safe = true, .threat_type = .none, .details = null };
    }

    /// 检测 XSS 攻击
    pub fn detectXss(self: *Self, input: []const u8) SecurityCheck {
        _ = self;

        const xss_patterns = [_][]const u8{
            "<script",
            "</script>",
            "javascript:",
            "vbscript:",
            "onload=",
            "onerror=",
            "onclick=",
            "onmouseover=",
            "onfocus=",
            "onblur=",
            "onsubmit=",
            "onreset=",
            "onselect=",
            "onchange=",
            "ondblclick=",
            "onkeydown=",
            "onkeypress=",
            "onkeyup=",
            "onmousedown=",
            "onmousemove=",
            "onmouseout=",
            "onmouseup=",
            "<iframe",
            "<frame",
            "<object",
            "<embed",
            "<applet",
            "<meta",
            "<link",
            "<style",
            "<img src=",
            "expression(",
            "url(",
            "<!--",
            "-->",
            "<![CDATA[",
            "]]>",
            "data:",
            "base64,",
        };

        for (xss_patterns) |pattern| {
            if (containsIgnoreCase(input, pattern)) {
                return .{
                    .is_safe = false,
                    .threat_type = .xss_attack,
                    .details = "检测到潜在的 XSS 攻击",
                };
            }
        }

        return .{ .is_safe = true, .threat_type = .none, .details = null };
    }

    /// 检测命令注入
    pub fn detectCommandInjection(self: *Self, input: []const u8) SecurityCheck {
        _ = self;

        const cmd_patterns = [_][]const u8{
            ";",
            "|",
            "&&",
            "||",
            "`",
            "$(",
            "${",
            ">>",
            "<<",
            "<",
            ">",
            "\\n",
            "\\r",
            "%0a",
            "%0d",
            "/etc/passwd",
            "/etc/shadow",
            "cmd.exe",
            "powershell",
            "/bin/sh",
            "/bin/bash",
            "wget ",
            "curl ",
            "nc ",
            "netcat ",
        };

        for (cmd_patterns) |pattern| {
            if (containsIgnoreCase(input, pattern)) {
                return .{
                    .is_safe = false,
                    .threat_type = .command_injection,
                    .details = "检测到潜在的命令注入攻击",
                };
            }
        }

        return .{ .is_safe = true, .threat_type = .none, .details = null };
    }

    /// 检测路径遍历
    pub fn detectPathTraversal(self: *Self, input: []const u8) SecurityCheck {
        _ = self;

        const path_patterns = [_][]const u8{
            "../",
            "..\\",
            "..\\/",
            "....//",
            "....\\\\",
            "%2e%2e%2f",
            "%2e%2e/",
            "..%2f",
            "%2e%2e\\",
            "..%5c",
            "%252e%252e%255c",
            "/etc/",
            "c:\\",
            "c:/",
            "%00",
        };

        for (path_patterns) |pattern| {
            if (containsIgnoreCase(input, pattern)) {
                return .{
                    .is_safe = false,
                    .threat_type = .path_traversal,
                    .details = "检测到潜在的路径遍历攻击",
                };
            }
        }

        return .{ .is_safe = true, .threat_type = .none, .details = null };
    }

    /// 检测 HTTP 头注入
    pub fn detectHeaderInjection(self: *Self, input: []const u8) SecurityCheck {
        _ = self;

        // 检测 CRLF 注入
        if (std.mem.indexOf(u8, input, "\r\n") != null or
            std.mem.indexOf(u8, input, "\r") != null or
            std.mem.indexOf(u8, input, "\n") != null or
            containsIgnoreCase(input, "%0d%0a") or
            containsIgnoreCase(input, "%0d") or
            containsIgnoreCase(input, "%0a"))
        {
            return .{
                .is_safe = false,
                .threat_type = .header_injection,
                .details = "检测到潜在的 HTTP 头注入攻击",
            };
        }

        return .{ .is_safe = true, .threat_type = .none, .details = null };
    }

    /// 综合安全检测
    pub fn check(self: *Self, input: []const u8) SecurityCheck {
        // SQL 注入检测
        var result = self.detectSqlInjection(input);
        if (!result.is_safe) return result;

        // XSS 检测
        result = self.detectXss(input);
        if (!result.is_safe) return result;

        // 命令注入检测
        result = self.detectCommandInjection(input);
        if (!result.is_safe) return result;

        // 路径遍历检测
        result = self.detectPathTraversal(input);
        if (!result.is_safe) return result;

        // 头注入检测
        result = self.detectHeaderInjection(input);
        if (!result.is_safe) return result;

        return .{ .is_safe = true, .threat_type = .none, .details = null };
    }
};

// ============================================================================
// 输入清理函数
// ============================================================================

/// 清理 HTML 特殊字符（防止 XSS）
pub fn escapeHtml(allocator: Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);
    errdefer result.deinit(allocator);

    for (input) |c| {
        switch (c) {
            '<' => try result.appendSlice(allocator, "&lt;"),
            '>' => try result.appendSlice(allocator, "&gt;"),
            '&' => try result.appendSlice(allocator, "&amp;"),
            '"' => try result.appendSlice(allocator, "&quot;"),
            '\'' => try result.appendSlice(allocator, "&#x27;"),
            '/' => try result.appendSlice(allocator, "&#x2F;"),
            '`' => try result.appendSlice(allocator, "&#x60;"),
            '=' => try result.appendSlice(allocator, "&#x3D;"),
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice(allocator);
}

/// 清理 SQL 特殊字符
pub fn escapeSql(allocator: Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);
    errdefer result.deinit(allocator);

    for (input) |c| {
        switch (c) {
            '\'' => try result.appendSlice(allocator, "''"),
            '\\' => try result.appendSlice(allocator, "\\\\"),
            0 => try result.appendSlice(allocator, "\\0"),
            '\n' => try result.appendSlice(allocator, "\\n"),
            '\r' => try result.appendSlice(allocator, "\\r"),
            '"' => try result.appendSlice(allocator, "\\\""),
            else => try result.append(allocator, c),
        }
    }

    return result.toOwnedSlice(allocator);
}

/// 移除所有 HTML 标签
pub fn stripTags(allocator: Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);
    errdefer result.deinit(allocator);

    var in_tag = false;
    for (input) |c| {
        if (c == '<') {
            in_tag = true;
        } else if (c == '>') {
            in_tag = false;
        } else if (!in_tag) {
            try result.append(allocator, c);
        }
    }

    return result.toOwnedSlice(allocator);
}

/// 清理文件名（移除危险字符）
pub fn sanitizeFilename(allocator: Allocator, input: []const u8) ![]u8 {
    var result = try std.ArrayList(u8).initCapacity(allocator, input.len);
    errdefer result.deinit(allocator);

    for (input) |c| {
        // 只允许字母、数字、下划线、点和横线
        if (std.ascii.isAlphanumeric(c) or c == '_' or c == '.' or c == '-') {
            try result.append(allocator, c);
        }
    }

    // 防止空文件名
    if (result.items.len == 0) {
        try result.appendSlice(allocator, "unnamed");
    }

    return result.toOwnedSlice(allocator);
}

/// 综合清理用户输入
pub fn sanitize(allocator: Allocator, input: []const u8) ![]u8 {
    // 先移除 HTML 标签，再转义特殊字符
    const stripped = try stripTags(allocator, input);
    defer allocator.free(stripped);

    return escapeHtml(allocator, stripped);
}

/// 检查输入是否安全
pub fn isClean(input: []const u8) bool {
    var security = Security.init(undefined);
    const result = security.check(input);
    return result.is_safe;
}

/// 获取威胁类型名称
pub fn getThreatName(threat: ThreatType) []const u8 {
    return switch (threat) {
        .none => "无威胁",
        .sql_injection => "SQL 注入",
        .xss_attack => "XSS 攻击",
        .command_injection => "命令注入",
        .path_traversal => "路径遍历",
        .ldap_injection => "LDAP 注入",
        .header_injection => "HTTP 头注入",
    };
}

// ============================================================================
// 辅助函数
// ============================================================================

// ============================================================================
// 测试
// ============================================================================

test "Security: SQL 注入检测" {
    var security = Security.init(std.testing.allocator);

    const result1 = security.detectSqlInjection("' OR 1=1--");
    try std.testing.expect(!result1.is_safe);
    try std.testing.expectEqual(ThreatType.sql_injection, result1.threat_type);

    const result2 = security.detectSqlInjection("normal input");
    try std.testing.expect(result2.is_safe);
}

test "Security: XSS 检测" {
    var security = Security.init(std.testing.allocator);

    const result1 = security.detectXss("<script>alert('xss')</script>");
    try std.testing.expect(!result1.is_safe);
    try std.testing.expectEqual(ThreatType.xss_attack, result1.threat_type);

    const result2 = security.detectXss("normal text");
    try std.testing.expect(result2.is_safe);
}

test "Security: 路径遍历检测" {
    var security = Security.init(std.testing.allocator);

    const result1 = security.detectPathTraversal("../../../etc/passwd");
    try std.testing.expect(!result1.is_safe);
    try std.testing.expectEqual(ThreatType.path_traversal, result1.threat_type);

    const result2 = security.detectPathTraversal("normal/path/file.txt");
    try std.testing.expect(result2.is_safe);
}

test "escapeHtml" {
    const allocator = std.testing.allocator;
    const escaped = try escapeHtml(allocator, "<script>alert('xss')</script>");
    defer allocator.free(escaped);

    try std.testing.expect(std.mem.indexOf(u8, escaped, "<") == null);
    try std.testing.expect(std.mem.indexOf(u8, escaped, "&lt;") != null);
}

test "stripTags" {
    const allocator = std.testing.allocator;
    const stripped = try stripTags(allocator, "<p>Hello <b>World</b></p>");
    defer allocator.free(stripped);

    try std.testing.expectEqualStrings("Hello World", stripped);
}
