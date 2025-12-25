const std = @import("std");

pub const Session = struct {
    id: []const u8,
    data: std.json.Value,
    allocator: std.mem.Allocator,
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
        const data = if (id != null) try driver.load(allocator, session_id) else std.json.Value{ .object = std.json.ObjectMap.init(allocator) };
        return .{
            .id = session_id,
            .data = data,
            .allocator = allocator,
            .driver = driver,
        };
    }

    pub fn save(self: *Session) !void {
        try self.driver.save(self.id, self.data);
    }

    pub fn destroy(self: *Session) !void {
        try self.driver.delete(self.id);
        std.json.parseFree(std.json.Value, self.data, self.allocator);
        self.allocator.free(self.id);
    }

    fn generateId(allocator: std.mem.Allocator) ![]u8 {
        var buf: [16]u8 = undefined;
        std.crypto.random.bytes(&buf);
        return std.fmt.allocPrint(allocator, "{x}", .{std.fmt.fmtSliceHexLower(&buf)});
    }
};

pub const MemoryDriver = @import("memory.zig").MemoryDriver;

test "session save and load" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    var driver = MemoryDriver.init(allocator);
    defer driver.deinit();
    var session = try Session.init(allocator, driver.driver(), null);
    defer session.destroy();
    try session.data.object.put("key", std.json.Value{ .string = "value" });
    try session.save();
    var session2 = try Session.init(allocator, driver.driver(), session.id);
    defer session2.destroy();
    if (session2.data.object.get("key")) |val| {
        try std.testing.expectEqualStrings("value", val.string);
    } else {
        return error.KeyNotFound;
    }
}
