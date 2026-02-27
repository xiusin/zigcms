//! 模板加载器
//!
//! 负责加载模板文件并提供缓存功能

const std = @import("std");

pub const Loader = struct {
    allocator: std.mem.Allocator,
    cache: std.StringHashMap([]const u8),
    load_fn: *const fn (allocator: std.mem.Allocator, template_name: []const u8) anyerror![]const u8,

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
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.deinit();
    }

    /// 加载模板（带缓存）
    pub fn load(self: *Loader, template_name: []const u8) ![]const u8 {
        // 检查缓存
        if (self.cache.get(template_name)) |cached| {
            return cached;
        }

        // 加载模板
        const content = try self.load_fn(self.allocator, template_name);
        errdefer self.allocator.free(content);

        // 缓存模板
        try self.cache.put(template_name, content);

        return content;
    }

    /// 清除缓存
    pub fn clearCache(self: *Loader) void {
        var it = self.cache.iterator();
        while (it.next()) |entry| {
            self.allocator.free(entry.value_ptr.*);
        }
        self.cache.clearRetainingCapacity();
    }
};

/// 默认的文件系统加载函数
pub fn loadFromFile(allocator: std.mem.Allocator, template_name: []const u8) ![]const u8 {
    const file_path = try std.fmt.allocPrint(allocator, "resources/page/{s}.html", .{template_name});
    defer allocator.free(file_path);

    const file = try std.fs.cwd().openFile(file_path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try allocator.alloc(u8, @intCast(stat.size));
    _ = try file.readAll(content);

    return content;
}