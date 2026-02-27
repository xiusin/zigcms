const std = @import("std");

pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    path: ?[]const u8 = null,
    domain: ?[]const u8 = null,
    max_age: ?i64 = null,
    secure: bool = false,
    http_only: bool = false,
    same_site: ?[]const u8 = null,

    pub fn parse(allocator: std.mem.Allocator, cookie_header: []const u8) !std.StringHashMap([]const u8) {
        var map = std.StringHashMap([]const u8).init(allocator);
        var iter = std.mem.split(u8, cookie_header, ";");
        while (iter.next()) |pair| {
            const trimmed = std.mem.trim(u8, pair, " ");
            if (std.mem.indexOf(u8, trimmed, "=")) |idx| {
                const name = trimmed[0..idx];
                const value = trimmed[idx + 1 ..];
                try map.put(try allocator.dupe(u8, name), try allocator.dupe(u8, value));
            }
        }
        return map;
    }

    pub fn serialize(self: *const Cookie, allocator: std.mem.Allocator) ![]u8 {
        var buf = std.ArrayList(u8).init(allocator);
        defer buf.deinit();
        try buf.appendSlice(self.name);
        try buf.append('=');
        try buf.appendSlice(self.value);
        if (self.path) |p| {
            try buf.appendSlice("; Path=");
            try buf.appendSlice(p);
        }
        if (self.domain) |d| {
            try buf.appendSlice("; Domain=");
            try buf.appendSlice(d);
        }
        if (self.max_age) |ma| {
            try buf.appendSlice("; Max-Age=");
            try std.fmt.format(buf.writer(), "{}", .{ma});
        }
        if (self.secure) {
            try buf.appendSlice("; Secure");
        }
        if (self.http_only) {
            try buf.appendSlice("; HttpOnly");
        }
        if (self.same_site) |ss| {
            try buf.appendSlice("; SameSite=");
            try buf.appendSlice(ss);
        }
        return buf.toOwnedSlice();
    }
};

test "cookie serialize" {
    const cookie = Cookie{
        .name = "session",
        .value = "123",
        .http_only = true,
    };
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    const str = try cookie.serialize(allocator);
    defer allocator.free(str);
    try std.testing.expect(std.mem.indexOf(u8, str, "session=123") != null);
    try std.testing.expect(std.mem.indexOf(u8, str, "HttpOnly") != null);
}
