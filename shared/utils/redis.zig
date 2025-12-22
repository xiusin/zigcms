const std = @import("std");
const builtin = @import("builtin");

pub const DataType = enum { SimpleString, Integer, Bulk, Array, Error };
const Allocator = std.mem.Allocator;

pub const Config = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 6379,
    user: []const u8 = "",
    password: []const u8 = "",
    db: u16 = 0,
    timeout: u32 = 5000,
};

const Reply = struct {
    buf: []u8 = undefined,
    type: DataType = undefined,
    eof: []const u8 = "\r\n",
    err: anyerror = undefined,

    allocator: Allocator,
    alloc_map: ?std.StringArrayHashMap([]const u8) = null,

    pub fn init(allocator: Allocator, buf: []u8) !Reply {
        return .{
            .buf = try allocator.dupe(u8, buf),
            .allocator = allocator,
            .type = switch (buf[0]) {
                ':' => .Integer,
                '+' => .SimpleString,
                '$' => .Bulk,
                '*' => .Array,
                '-' => .Error,
                else => unreachable,
            },
        };
    }

    pub fn deinit(self: *Reply) void {
        if (self.alloc_map != null) self.alloc_map.?.deinit();
        self.allocator.free(self.buf);

        self.* = undefined;
    }

    pub fn ok(self: *const Reply) !bool {
        if (self.type != .SimpleString) return error.WrongType;
        return std.mem.eql(u8, self.buf[1..], "OK");
    }

    fn get_all_next(self: *const Reply) []u8 {
        if (std.mem.indexOf(u8, self.buf, "\n")) |start| {
            return self.buf[start + 1 ..];
        } else {
            return self.buf[1..];
        }
    }

    pub fn number(self: *const Reply) !usize {
        if (self.type == .Array) return error.WrongType;

        return switch (self.type) {
            .Integer, .SimpleString => std.fmt.parseInt(usize, self.buf[1..], 10),
            .Bulk => std.fmt.parseInt(usize, self.get_all_next(), 10),
            else => unreachable,
        };
    }

    pub fn string(self: *const Reply) []u8 {
        return switch (self.type) {
            .Integer, .SimpleString => self.buf[1..],
            .Bulk => self.get_all_next(),
            .Error => self.buf[5..],
            else => unreachable,
        };
    }

    pub fn parse_struct(self: *Reply, comptime T: type) !T {
        return std.json.parseFromSliceLeaky(T, self.allocator, self.string(), .{ .ignore_unknown_fields = true });
    }

    pub fn map(self: *Reply) !std.StringArrayHashMap([]const u8) {
        if (self.type != .Array) return error.WrongType;

        if (self.alloc_map == null) {
            var iter = std.mem.split(u8, self.buf, self.eof);
            _ = iter.first(); // 丢弃第一行

            self.alloc_map = std.StringArrayHashMap([]const u8).init(self.allocator);
            var k: ?[]const u8 = null;
            while (iter.next()) |line_| {
                if (line_.len > 0 and line_[0] == '$') continue;

                if (k == null) k = line_ else {
                    try self._map.?.put(k.?, line_);
                    k = null;
                }
            }
        }
        return self.alloc_map.?;
    }

    pub fn strings(self: *Reply) ![][]const u8 {
        var list = std.ArrayList([]const u8).init(self.allocator);
        defer list.deinit();

        switch (self.type) {
            .SimpleString, .Integer => try list.append(self.buf[1..]),
            .Error => try list.append(self.buf[5..]),
            .Bulk => try list.append(self.get_all_next()),
            .Array => {
                var iter = std.mem.split(u8, self.buf, self.eof);
                _ = iter.first();
                while (iter.next()) |line_| {
                    if (line_.len == 0 or line_[0] != '$') {
                        try list.append(line_);
                    }
                }
            },
        }
        return list.toOwnedSlice();
    }
};

// 定义redis客户端
pub const Client = struct {
    allocator: Allocator,
    stream: std.net.Stream = undefined,
    mu: std.Thread.Mutex = .{},
    config: Config,

    /// 初始化客户端
    pub fn init(allocator: Allocator, config: Config) !Client {
        var client = Client{ .allocator = allocator, .config = config };

        try client.connect();
        return client;
    }

    /// 释放内存
    pub fn deinit(self: *Client) void {
        self.stream.close();
        self.stream = undefined;
        self.* = undefined;
    }

    /// 连接redis并验证权限
    fn connect(self: *Client) !void {
        self.stream = try std.net.tcpConnectToHost(self.allocator, self.config.host, self.config.port);

        if (self.config.password.len > 0) {
            const cmd = try std.mem.concat(self.allocator, u8, &[_][]const u8{ "AUTH \"", self.config.password, "\"" });
            defer self.allocator.free(cmd);
            var reply = try self.do(cmd);
            defer reply.deinit();

            if (reply.type == .Error) {
                return error.AuthenticationFailed;
            }
            reply = undefined;
        }
    }

    /// 发送命令
    pub fn do(self: *Client, cmd: []const u8) !Reply {
        self.mu.lock();
        defer {
            self.mu.unlock();
        }
        _ = try self.stream.write(cmd);
        _ = try self.stream.write("\n");

        var buf: [4096000]u8 = undefined;
        var content = buf[0..try self.stream.read(&buf)];
        if (content.len == 0) unreachable;
        if (content.len == 5 and std.mem.eql(u8, content[0..3], "$-1")) return error.NilReturned;
        return Reply.init(self.allocator, content[0 .. content.len - 2]);
    }
};
