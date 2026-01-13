const std = @import("std");

pub const SecurityError = error{
    InvalidInput,
    PotentialInjection,
    PathTraversal,
    TooLong,
    InvalidFormat,
};

pub const Validator = struct {
    const Self = @This();
    max_string_len: usize = 10000,
    max_array_len: usize = 1000,

    pub fn notEmpty(_: *const Self, input: []const u8) SecurityError!void {
        if (input.len == 0) return error.InvalidInput;
    }

    pub fn length(_: *const Self, input: []const u8, min: usize, max: usize) SecurityError!void {
        if (input.len < min or input.len > max) return error.InvalidInput;
    }

    pub fn email(_: *const Self, input: []const u8) SecurityError!void {
        if (input.len < 5 or input.len > 254) return error.InvalidInput;
        const at_idx = std.mem.indexOf(u8, input, "@") orelse return error.InvalidInput;
        if (at_idx == 0 or at_idx == input.len - 1) return error.InvalidInput;
        const domain = input[at_idx + 1 ..];
        if (domain.len < 3) return error.InvalidInput;
        for (input) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '@' and c != '.' and c != '-' and c != '_') {
                return error.InvalidInput;
            }
        }
    }

    pub fn username(_: *const Self, input: []const u8) SecurityError!void {
        if (input.len < 3 or input.len > 32) return error.InvalidInput;
        for (input) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') return error.InvalidInput;
        }
    }

    pub fn passwordStrength(_: *const Self, input: []const u8) SecurityError!void {
        if (input.len < 8) return error.InvalidInput;
        var has_upper = false;
        var has_lower = false;
        var has_digit = false;
        var has_special = false;
        for (input) |c| {
            if (std.ascii.isUpper(c)) has_upper = true;
            if (std.ascii.isLower(c)) has_lower = true;
            if (std.ascii.isDigit(c)) has_digit = true;
            if (!std.ascii.isAlphanumeric(c)) has_special = true;
        }
        if (!has_upper or !has_lower or !has_digit or !has_special) return error.InvalidInput;
    }

    pub fn intRange(_: *const Self, value: i64, min: i64, max: i64) SecurityError!void {
        if (value < min or value > max) return error.InvalidInput;
    }

    pub fn noControlChars(_: *const Self, input: []const u8) SecurityError!void {
        for (input) |c| {
            if (c < 0x20 and c != '\t' and c != '\n' and c != '\r') return error.InvalidInput;
        }
    }
};

pub const SqlSanitizer = struct {
    pub fn escapeString(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var result = try allocator.alloc(u8, input.len * 2 + 2);
        var idx: usize = 0;
        result[idx] = '\'';
        idx += 1;
        for (input) |c| {
            switch (c) {
                '\'' => {
                    result[idx] = '\'';
                    idx += 1;
                    result[idx] = '\'';
                },
                '\\' => {
                    result[idx] = '\\';
                    idx += 1;
                    result[idx] = '\\';
                },
                '\n' => {
                    result[idx] = '\\';
                    idx += 1;
                    result[idx] = 'n';
                },
                '\r' => {
                    result[idx] = '\\';
                    idx += 1;
                    result[idx] = 'r';
                },
                '\t' => {
                    result[idx] = '\\';
                    idx += 1;
                    result[idx] = 't';
                },
                else => result[idx] = c,
            }
            idx += 1;
        }
        result[idx] = '\'';
        return result[0 .. idx + 1];
    }

    pub fn detectInjection(input: []const u8) SecurityError!void {
        var buffer: [256]u8 = undefined;
        const lower = std.ascii.lowerString(&buffer, input);
        const dangerous = [_][]const u8{
            "union select", "select.*from", "insert into",    "update.*set",
            "delete from",  "drop table",   "truncate table", "--",
            "/*",           "*/",           "xp_",            "exec(",
            "execute(",
        };
        for (dangerous) |pattern| {
            if (std.mem.indexOf(u8, lower, pattern) != null) return error.PotentialInjection;
        }
    }

    pub fn validateColumnName(name: []const u8) SecurityError!void {
        if (name.len == 0 or name.len > 64) return error.InvalidInput;
        for (name) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') return error.InvalidInput;
        }
    }

    pub fn validateTableName(name: []const u8) SecurityError!void {
        if (name.len == 0 or name.len > 128) return error.InvalidInput;
        for (name) |c| {
            if (!std.ascii.isAlphanumeric(c) and c != '_') return error.InvalidInput;
        }
    }
};

pub const XssSanitizer = struct {
    const dangerous_patterns = [_][]const u8{
        "<script",      "javascript:", "onload=", "onerror=",  "onclick=",
        "onmouseover=", "onfocus=",    "onblur=", "onsubmit=", "<iframe",
        "<object",      "<embed",      "<svg",    "<math",
    };

    pub fn detect(input: []const u8) SecurityError!void {
        var buffer: [256]u8 = undefined;
        const lower = std.ascii.lowerString(&buffer, input);
        for (dangerous_patterns) |pattern| {
            if (std.mem.indexOf(u8, lower, pattern) != null) return error.InvalidInput;
        }
    }

    pub fn escapeHtml(allocator: std.mem.Allocator, input: []const u8) ![]u8 {
        var result = try allocator.alloc(u8, input.len * 6);
        var idx: usize = 0;
        for (input) |c| {
            switch (c) {
                '<' => {
                    std.mem.copy(u8, result[idx..], "&lt;");
                    idx += 4;
                },
                '>' => {
                    std.mem.copy(u8, result[idx..], "&gt;");
                    idx += 4;
                },
                '&' => {
                    std.mem.copy(u8, result[idx..], "&amp;");
                    idx += 5;
                },
                '"' => {
                    std.mem.copy(u8, result[idx..], "&quot;");
                    idx += 6;
                },
                '\'' => {
                    std.mem.copy(u8, result[idx..], "&#39;");
                    idx += 5;
                },
                else => {
                    result[idx] = c;
                    idx += 1;
                },
            }
        }
        return result[0..idx];
    }
};

pub const PathSanitizer = struct {
    pub fn sanitize(base_path: []const u8, user_path: []const u8) SecurityError![]const u8 {
        if (user_path.len == 0) return error.InvalidInput;
        if (std.mem.indexOf(u8, user_path, "..") != null) return error.PathTraversal;
        if (user_path[0] == '/' or (user_path.len > 1 and user_path[1] == ':')) return error.PathTraversal;
        if (std.mem.indexOf(u8, user_path, "\x00") != null) return error.InvalidInput;
        const full_path = std.fs.path.join(std.testing.allocator, &.{ base_path, user_path }) catch {
            return error.InvalidInput;
        };
        defer std.testing.allocator.free(full_path);
        if (!std.mem.startsWith(u8, full_path, base_path)) return error.PathTraversal;
        return user_path;
    }
};

pub const DataMasker = struct {
    pub fn email(allocator: std.mem.Allocator, email_input: []const u8) ![]u8 {
        const at_idx = std.mem.indexOf(u8, email_input, "@") orelse return allocator.dupe(u8, email_input);
        const local_part = email_input[0..at_idx];
        const domain = email_input[at_idx..];
        const masked_len = if (local_part.len > 2) 2 else local_part.len;
        const masked = try allocator.alloc(u8, masked_len + domain.len);
        @memset(masked[0..masked_len], '*');
        std.mem.copy(u8, masked[masked_len..], domain);
        return masked;
    }

    pub fn phone(allocator: std.mem.Allocator, phone_input: []const u8) ![]u8 {
        if (phone_input.len < 11) return allocator.dupe(u8, phone_input);
        const masked = try allocator.alloc(u8, phone_input.len);
        @memset(masked[0..3], '*');
        @memset(masked[7..], '*');
        std.mem.copy(u8, masked[3..7], phone_input[3..7]);
        std.mem.copy(u8, masked[7..], phone_input[7..11]);
        return masked;
    }

    pub fn idCard(allocator: std.mem.Allocator, id: []const u8) ![]u8 {
        if (id.len < 18) return allocator.dupe(u8, id);
        const masked = try allocator.alloc(u8, id.len);
        @memset(masked[0..6], '*');
        std.mem.copy(u8, masked[6..], id[6 .. id.len - 4]);
        @memset(masked[id.len - 4 ..], '*');
        return masked;
    }
};
