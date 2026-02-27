//! 工具函数模块 (Utils Module)
//!
//! 提供跨层共享的工具函数，包括字符串处理、JWT、加密等。
//! 从原 shared/utils 迁移而来。

const std = @import("std");

// 重导出子模块
pub const strings = @import("strings.zig");
pub const jwt = @import("jwt.zig");
pub const security = @import("security.zig");
pub const health = @import("health.zig");
pub const metrics = @import("metrics.zig");

/// 字符串工具
pub const StringUtils = struct {
    /// 去除首尾空白
    pub fn trim(s: []const u8) []const u8 {
        return std.mem.trim(u8, s, " \t\n\r");
    }

    /// 判断是否为空
    pub fn isEmpty(s: []const u8) bool {
        return s.len == 0;
    }

    /// 判断是否为空白
    pub fn isBlank(s: []const u8) bool {
        return trim(s).len == 0;
    }

    /// 分割字符串
    pub fn split(s: []const u8, delimiter: u8) std.mem.SplitIterator(u8, .scalar) {
        return std.mem.splitScalar(u8, s, delimiter);
    }
};

/// 时间工具
pub const TimeUtils = struct {
    /// 获取当前时间戳（秒）
    pub fn now() i64 {
        return std.time.timestamp();
    }

    /// 获取当前时间戳（毫秒）
    pub fn nowMs() i64 {
        return std.time.milliTimestamp();
    }
};

/// 随机工具
pub const RandomUtils = struct {
    /// 生成随机字节
    pub fn bytes(buf: []u8) void {
        std.crypto.random.bytes(buf);
    }

    /// 生成随机整数
    pub fn int(comptime T: type) T {
        return std.crypto.random.int(T);
    }

    /// 生成 UUID v4
    pub fn uuid() [36]u8 {
        var buf: [16]u8 = undefined;
        std.crypto.random.bytes(&buf);

        // 设置版本和变体
        buf[6] = (buf[6] & 0x0f) | 0x40;
        buf[8] = (buf[8] & 0x3f) | 0x80;

        var result: [36]u8 = undefined;
        const hex = "0123456789abcdef";
        var i: usize = 0;
        var j: usize = 0;

        while (i < 16) : (i += 1) {
            if (i == 4 or i == 6 or i == 8 or i == 10) {
                result[j] = '-';
                j += 1;
            }
            result[j] = hex[buf[i] >> 4];
            result[j + 1] = hex[buf[i] & 0x0f];
            j += 2;
        }

        return result;
    }
};
