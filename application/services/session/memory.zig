const std = @import("std");

// Note: This implementation is not thread-safe. For multi-threaded use, implement lock-free data structure or use external synchronization.

pub const MemoryDriver = struct {
    data: std.StringHashMap(std.json.Value),

    pub fn init(allocator: std.mem.Allocator) MemoryDriver {
        return .{
            .data = std.StringHashMap(std.json.Value).init(allocator),
        };
    }

    pub fn deinit(self: *MemoryDriver) void {
        var iter = self.data.valueIterator();
        while (iter.next()) |val| {
            std.json.parseFree(std.json.Value, val.*, self.data.allocator);
        }
        var key_iter = self.data.keyIterator();
        while (key_iter.next()) |key| {
            self.data.allocator.free(key.*);
        }
        self.data.deinit();
    }

    fn saveFn(ptr: *anyopaque, id: []const u8, data: std.json.Value) !void {
        const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
        const key = try self.data.allocator.dupe(u8, id);
        errdefer self.data.allocator.free(key);
        const str = try std.json.stringifyAlloc(self.data.allocator, data, .{});
        defer self.data.allocator.free(str);
        const value = try std.json.parseFromSlice(std.json.Value, self.data.allocator, str, .{});
        try self.data.put(key, value);
    }

    fn loadFn(ptr: *anyopaque, allocator: std.mem.Allocator, id: []const u8) !std.json.Value {
        const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
        if (self.data.get(id)) |val| {
            const str = try std.json.stringifyAlloc(self.data.allocator, val, .{});
            defer self.data.allocator.free(str);
            return std.json.parseFromSlice(std.json.Value, allocator, str, .{});
        } else {
            return std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
        }
    }

    fn deleteFn(ptr: *anyopaque, id: []const u8) !void {
        const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
        if (self.data.fetchRemove(id)) |kv| {
            self.data.allocator.free(kv.key);
            std.json.parseFree(std.json.Value, kv.value, self.data.allocator);
        }
    }
};
