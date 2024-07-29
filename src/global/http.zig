const std = @import("std");

pub const Http = struct {
    debug: bool = false,
    allocator: std.mem.Allocator,
    key: []const u8,
    passphrase: []const u8,
    secret: []const u8,
    last_error_message: ?[]const u8 = null,

    pub fn init(allocator: std.mem.Allocator, key: []const u8, secret: []const u8, passphrase: []const u8) !Http {
        return .{
            .allocator = allocator,
            .key = try allocator.dupe(u8, key),
            .secret = try allocator.dupe(u8, secret),
            .passphrase = try allocator.dupe(u8, passphrase),
        };
    }

    pub fn deinit(self: *OkxApi) void {
        self.allocator.free(self.key);
        self.allocator.free(self.secret);
        self.allocator.free(self.passphrase);
        self.* = undefined;
    }

    pub fn set_debug(self: *OkxApi, enable: bool) void {
        self.debug = enable;
    }

    fn request(self: *OkxApi, path: []const u8, method: std.http.Method, body: []const u8) !std.http.Client.FetchResult {
        var headers = std.http.Headers.init(self.allocator);
        defer headers.deinit();

        var start = try std.time.Timer.start();

        const timestamp = std.time.timestamp();

        const es = std.time.epoch.EpochSeconds{ .secs = @as(u64, @intCast(timestamp)) };
        const year = es.getEpochDay().calculateYearDay().year;
        const month = es.getEpochDay().calculateYearDay().calculateMonthDay().month;
        const day = es.getEpochDay().calculateYearDay().calculateMonthDay().day_index + 1;
        const hour = es.getDaySeconds().getHoursIntoDay();
        const min = es.getDaySeconds().getMinutesIntoHour();
        const sec = es.getDaySeconds().getSecondsIntoMinute();

        var out: [24]u8 = undefined;
        const datetime = try std.fmt.bufPrint(&out, "{d}-{d:0>2}-{d:0>2}T{d:0>2}:{d:0>2}:{d:0>2}.000Z", .{ year, month.numeric(), day, hour, min, sec });

        const signstr = try self.sign(datetime, method, path, body);
        defer self.allocator.free(signstr);

        try headers.append("OK-ACCESS-KEY", self.key);
        try headers.append("OK-ACCESS-SIGN", signstr);
        try headers.append("OK-ACCESS-TIMESTAMP", datetime);
        try headers.append("OK-ACCESS-PASSPHRASE", self.passphrase);

        var client = std.http.Client{ .allocator = self.allocator };
        defer client.deinit();
        // try client.loadDefaultProxies(); // www的域名必须代理, zig目前代理支持有问题, 会提醒http的请求转发给https

        const fullpath = try self.get_abs_path(path);
        defer self.allocator.free(fullpath);

        var options = std.http.Client.FetchOptions{ .method = method, .location = .{ .url = fullpath }, .headers = headers };
        if (options.method == .POST and body.len > 0) {
            options.payload = .{ .string = body };
        }

        const resp = try client.fetch(self.allocator, options);

        if (self.debug) {
            std.debug.print("[OKX][{s}]use time: {d}ms\n", .{ path, @ceil(@as(f64, @floatCast(@as(f128, @floatFromInt(start.read())) / @as(f128, std.time.ns_per_ms)))) });
        }

        if (self.last_error_message) |message| {
            self.allocator.free(message);
            self.last_error_message = null;
        }

        if (resp.status != std.http.Status.ok and resp.status != std.http.Status.no_content) {
            if (resp.body) |body_| {
                if (body_.len > 0 and body_[0] == '<') {
                    self.last_error_message = try self.allocator.dupe(u8, body_);
                } else {
                    if (self.debug) {
                        std.debug.print("[OKX]response failed message: {s}\n", .{resp.body.?});
                    }
                    const message = std.json.parseFromSlice(OkxFailedResponse, self.allocator, body_, .{ .ignore_unknown_fields = true }) catch |e| return e;
                    self.last_error_message = message.value.msg;
                }
            } else {
                self.last_error_message = try std.fmt.allocPrint(self.allocator, "{s} response code is: {any}", .{ path, resp.status });
            }
            return error.OkxApiError;
        }
        return resp;
    }
};
