const std = @import("std");
const core_meta = @import("../../../core/meta.zig");
const core_io = @import("../../../core/io.zig");

pub const Session = struct {
    id: []const u8,
    data: std.json.Value,
    allocator: std.mem.Allocator,
    data_arena: *std.heap.ArenaAllocator,
    driver: *SessionDriver,

    pub const SessionDriver = struct {
        ptr: *anyopaque,
        saveFn: *const fn (ptr: *anyopaque, id: []const u8, data: std.json.Value) anyerror!void,
        loadFn: *const fn (ptr: *anyopaque, allocator: std.mem.Allocator, id: []const u8) anyerror!std.json.Value,
        deleteFn: *const fn (ptr: *anyopaque, id: []const u8) anyerror!void,

        pub fn save(self: *SessionDriver, id: []const u8, data: std.json.Value) !void {
            return self.saveFn(self.ptr, id, data);
        }

        pub fn load(self: *SessionDriver, allocator: std.mem.Allocator, id: []const u8) !std.json.Value {
            return self.loadFn(self.ptr, allocator, id);
        }

        pub fn delete(self: *SessionDriver, id: []const u8) !void {
            return self.deleteFn(self.ptr, id);
        }
    };

    pub fn init(allocator: std.mem.Allocator, driver: *SessionDriver, id: ?[]const u8) !Session {
        const session_id = id orelse try generateId(allocator);
        errdefer allocator.free(session_id);

        // 会话数据使用独立 arena，destroy 时一次性释放（0.17 无 parseFree）
        const data_arena = try allocator.create(std.heap.ArenaAllocator);
        errdefer allocator.destroy(data_arena);
        data_arena.* = std.heap.ArenaAllocator.init(allocator);

        const data = if (id != null) try driver.load(data_arena.allocator(), session_id) else std.json.Value{ .object = std.json.ObjectMap.empty };
        return .{
            .id = session_id,
            .data = data,
            .allocator = allocator,
            .data_arena = data_arena,
            .driver = driver,
        };
    }

    pub fn save(self: *Session) !void {
        try self.driver.save(self.id, self.data);
    }

    pub fn destroy(self: *Session) !void {
        try self.driver.delete(self.id);
        self.data_arena.deinit();
        self.allocator.destroy(self.data_arena);
        self.allocator.free(self.id);
    }

    fn generateId(allocator: std.mem.Allocator) ![]u8 {
        var buf: [16]u8 = undefined;
        core_io.getIo().random(&buf);
        return std.fmt.allocPrint(allocator, "{x}", .{@as([]const u8, &buf)});
    }
};

pub const MemoryDriver = @import("memory.zig").MemoryDriver;

/// Helper function to create a SessionDriver from MemoryDriver
pub fn createMemoryDriver(memory_driver: *MemoryDriver) Session.SessionDriver {
    return .{
        .ptr = memory_driver,
        .saveFn = struct {
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
        }.saveFn,
        .loadFn = struct {
            fn loadFn(ptr: *anyopaque, allocator: std.mem.Allocator, id: []const u8) !std.json.Value {
                const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
                if (self.data.get(id)) |str| {
                    return std.json.parseFromSliceLeaky(std.json.Value, allocator, str, .{});
                } else {
                    return std.json.Value{ .object = std.json.ObjectMap.empty };
                }
            }
        }.loadFn,
        .deleteFn = struct {
            fn deleteFn(ptr: *anyopaque, id: []const u8) !void {
                const self: *MemoryDriver = @ptrCast(@alignCast(ptr));
                if (self.data.fetchRemove(id)) |kv| {
                    self.data.allocator.free(kv.key);
                    self.data.allocator.free(kv.value);
                }
            }
        }.deleteFn,
    };
}

test "session save and load" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var driver = MemoryDriver.init(allocator);
    defer driver.deinit();
    var drv = createMemoryDriver(&driver);
    var session = try Session.init(allocator, &drv, null);
    defer session.destroy() catch {};
    try session.data.object.put(allocator, "key", std.json.Value{ .string = "value" });
    try session.save();
    var drv2 = createMemoryDriver(&driver);
    var session2 = try Session.init(allocator, &drv2, session.id);
    defer session2.destroy() catch {};
    if (session2.data.object.get("key")) |val| {
        try std.testing.expectEqualStrings("value", val.string);
    } else {
        return error.KeyNotFound;
    }
}
