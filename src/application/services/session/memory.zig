const std = @import("std");
const core_meta = @import("../../../core/meta.zig");
const core_io = @import("../../../core/io.zig");

// Note: This implementation is not thread-safe. For multi-threaded use, implement lock-free data structure or use external synchronization.

/// 内存会话驱动：内部只存序列化后的 JSON 字符串，
/// 读取时再按调用方分配器解析（0.17 已移除 parseFree，避免手动深释放）。
pub const MemoryDriver = struct {
    data: std.StringHashMap([]const u8),

    pub fn init(allocator: std.mem.Allocator) MemoryDriver {
        return .{
            .data = std.StringHashMap([]const u8).init(allocator),
        };
    }

    pub fn deinit(self: *MemoryDriver) void {
        var it = self.data.iterator();
        while (it.next()) |entry| {
            self.data.allocator.free(entry.key_ptr.*);
            self.data.allocator.free(entry.value_ptr.*);
        }
        self.data.deinit();
    }

    fn saveFn(ptr: *anyopaque, id: []const u8, data: std.json.Value) !void {
        const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
        const str = try std.json.Stringify.valueAlloc(self.data.allocator, data, .{});
        errdefer self.data.allocator.free(str);

        const gop = try self.data.getOrPut(id);
        if (gop.found_existing) {
            self.data.allocator.free(gop.value_ptr.*);
        } else {
            gop.key_ptr.* = try self.data.allocator.dupe(u8, id);
        }
        gop.value_ptr.* = str;
    }

    fn loadFn(ptr: *anyopaque, allocator: std.mem.Allocator, id: []const u8) !std.json.Value {
        const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
        if (self.data.get(id)) |str| {
            return std.json.parseFromSliceLeaky(std.json.Value, allocator, str, .{});
        } else {
            return std.json.Value{ .object = std.json.ObjectMap.empty };
        }
    }

    fn deleteFn(ptr: *anyopaque, id: []const u8) !void {
        const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
        if (self.data.fetchRemove(id)) |kv| {
            self.data.allocator.free(kv.key);
            self.data.allocator.free(kv.value);
        }
    }
};
