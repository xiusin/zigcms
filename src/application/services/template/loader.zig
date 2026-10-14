//! 模板加载器
//!
//! 负责加载模板文件并提供缓存功能

const std = @import("std");
const core_meta = @import("../../../core/meta.zig");
const core_io = @import("../../../core/io.zig");

pub const Loader = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap([]const u8),
    load_fn: *const fn (allocator: std.mem.Allocator, template_name: []const u8) anyerror![]const u8,
    /// 缓存互斥锁：保护 cache 表的并发读写
    mutex: std.Io.Mutex = .init,

    pub fn init(allocator: std.mem.Allocator, load_fn: *const fn (allocator: std.mem.Allocator, template_name: []const u8) anyerror![]const u8) Loader {
        return .{
            .allocator = allocator,
            .cache = std.StringHashMap([]const u8).init(allocator),
            .load_fn = load_fn,
        };
    }

    pub fn deinit(self: *Loader) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// 加载模板（带缓存）。返回内容归缓存所有，缓存被清理前一直有效。
    /// 全程持锁：load_fn 返回后内容立即入表，避免并发加载同一模板时
    /// 后写覆盖先写导致内容泄漏。
    pub fn load(self: *Loader, template_name: []const u8) ![]const u8 {
        self.mutex.lockUncancelable(core_io.getIo());
        defer self.mutex.unlock(core_io.getIo());

        // 检查缓存
        if (self.cache.get(template_name)) |cached| {
            return cached;
        }

        // 加载模板
        const content = try self.load_fn(self.allocator, template_name);
        errdefer self.allocator.free(content);

        // 缓存模板（key 必须复制，调用方切片可能随时失效）
        const key = try self.allocator.dupe(u8, template_name);
        errdefer self.allocator.free(key);
        try self.cache.put(key, content);

        return content;
    }

    /// 清除缓存
    pub fn clearCache(self: *Loader) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.clearRetainingCapacity();
    }
};

/// 默认的文件系统加载函数
pub fn loadFromFile(allocator: std.mem.Allocator, template_name: []const u8) ![]const u8 {
    const file_path = try std.fmt.allocPrint(allocator, "resources/page/{s}.html", .{template_name});
    defer allocator.free(file_path);

    return std.Io.Dir.readFileAlloc(std.Io.Dir.cwd(), core_io.getIo(), file_path, allocator, std.Io.Limit.limited(1024 * 1024));
}