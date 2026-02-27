//! HTTP 客户端模块
//!
//! 提供可复用的 HTTP 客户端，支持文件上传、Cookie 管理、自定义请求头等功能。
//!
//! ## 使用示例
//!
//! ```zig
//! var client = try HttpClient.init(allocator);
//! defer client.deinit();
//!
//! // GET 请求
//! const resp = try client.get("https://api.example.com/data");
//! defer resp.deinit();
//!
//! // POST JSON
//! const body = try client.postJson("https://api.example.com/users", .{ .name = "张三" });
//!
//! // 上传文件
//! const upload_resp = try client.uploadFile("https://api.example.com/upload", "/path/to/file.png");
//!
//! // 下载文件（带进度回调）
//! try client.downloadFile("https://example.com/file.zip", "/tmp/file.zip", .{
//!     .on_progress = struct {
//!         fn callback(progress: *const ProgressInfo) void {
//!             std.debug.print("\r下载进度: {d:.1}%", .{progress.percent()});
//!         }
//!     }.callback,
//! });
//! ```

const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;
const Uri = std.Uri;
const ArrayList = std.array_list.Managed;

/// HTTP 方法
pub const Method = http.Method;

/// 进度信息
pub const ProgressInfo = struct {
    /// 已传输字节数
    bytes_transferred: usize,
    /// 总字节数（0表示未知）
    total_bytes: usize,
    /// 传输方向
    direction: enum { download, upload },
    /// 当前速率（字节/秒）
    speed_bytes_per_sec: usize,
    /// 已用时间（纳秒）
    elapsed_ns: u64,
    /// 用户自定义数据
    user_data: ?*anyopaque,

    /// 获取进度百分比（0-100）
    pub fn percent(self: *const ProgressInfo) f64 {
        if (self.total_bytes == 0) return 0;
        return @as(f64, @floatFromInt(self.bytes_transferred)) / @as(f64, @floatFromInt(self.total_bytes)) * 100.0;
    }

    /// 是否已完成
    pub fn isComplete(self: *const ProgressInfo) bool {
        return self.total_bytes > 0 and self.bytes_transferred >= self.total_bytes;
    }

    /// 获取预估剩余时间（秒）
    pub fn estimatedRemainingSecs(self: *const ProgressInfo) ?f64 {
        if (self.speed_bytes_per_sec == 0 or self.total_bytes == 0) return null;
        const remaining = self.total_bytes - self.bytes_transferred;
        return @as(f64, @floatFromInt(remaining)) / @as(f64, @floatFromInt(self.speed_bytes_per_sec));
    }

    /// 格式化字节大小
    pub fn formatBytes(bytes: usize) struct { value: f64, unit: []const u8 } {
        if (bytes >= 1024 * 1024 * 1024) {
            return .{ .value = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0 * 1024.0), .unit = "GB" };
        } else if (bytes >= 1024 * 1024) {
            return .{ .value = @as(f64, @floatFromInt(bytes)) / (1024.0 * 1024.0), .unit = "MB" };
        } else if (bytes >= 1024) {
            return .{ .value = @as(f64, @floatFromInt(bytes)) / 1024.0, .unit = "KB" };
        }
        return .{ .value = @as(f64, @floatFromInt(bytes)), .unit = "B" };
    }
};

/// 进度回调函数类型
pub const ProgressCallback = *const fn (info: *const ProgressInfo) void;

/// 进度配置
pub const ProgressOptions = struct {
    /// 进度回调函数
    on_progress: ?ProgressCallback = null,
    /// 回调间隔（毫秒），防止过于频繁调用
    interval_ms: u32 = 100,
    /// 用户自定义数据，会传递给回调函数
    user_data: ?*anyopaque = null,
};

/// 超时配置
pub const TimeoutOptions = struct {
    /// 连接超时（毫秒）
    connect_ms: u64 = 10_000,
    /// 读取超时（毫秒）
    read_ms: u64 = 30_000,
    /// 写入超时（毫秒）
    write_ms: u64 = 30_000,
    /// 总超时（毫秒，0=无限制）
    total_ms: u64 = 60_000,

    /// 无超时
    pub const none = TimeoutOptions{
        .connect_ms = 0,
        .read_ms = 0,
        .write_ms = 0,
        .total_ms = 0,
    };

    /// 快速超时（5秒）
    pub const fast = TimeoutOptions{
        .connect_ms = 2_000,
        .read_ms = 5_000,
        .write_ms = 5_000,
        .total_ms = 10_000,
    };

    /// 长超时（5分钟）
    pub const slow = TimeoutOptions{
        .connect_ms = 30_000,
        .read_ms = 300_000,
        .write_ms = 300_000,
        .total_ms = 600_000,
    };
};

/// 请求配置
pub const RequestOptions = struct {
    /// 超时配置
    timeout: TimeoutOptions = .{},
    /// 请求超时（毫秒）- 已弃用，请使用 timeout
    timeout_ms: u64 = 30_000,
    /// 连接超时（毫秒）- 已弃用，请使用 timeout
    connect_timeout_ms: u64 = 10_000,
    /// 最大重定向次数
    max_redirects: u8 = 5,
    /// 是否跟随重定向
    follow_redirects: bool = true,
    /// 自定义 User-Agent
    user_agent: ?[]const u8 = null,
    /// 内容类型
    content_type: ?[]const u8 = null,
    /// Accept 头
    accept: ?[]const u8 = null,
    /// Authorization 头
    authorization: ?[]const u8 = null,
    /// 是否验证 SSL 证书
    verify_ssl: bool = true,
    /// 请求体
    body: ?[]const u8 = null,
    /// 进度配置
    progress: ProgressOptions = .{},
};

/// Cookie 结构
pub const Cookie = struct {
    name: []const u8,
    value: []const u8,
    domain: ?[]const u8 = null,
    path: ?[]const u8 = null,
    expires: ?i64 = null,
    secure: bool = false,
    http_only: bool = false,

    /// 格式化为请求头格式
    pub fn format(self: Cookie, allocator: Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{s}={s}", .{ self.name, self.value });
    }
};

/// HTTP 响应
pub const Response = struct {
    allocator: Allocator,
    status: http.Status,
    headers: std.StringHashMap([]const u8),
    body: []const u8,
    cookies: ArrayList(Cookie),

    /// 释放响应资源
    pub fn deinit(self: *Response) void {
        self.allocator.free(self.body);
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.headers.deinit();
        for (self.cookies.items) |cookie| {
            self.allocator.free(cookie.name);
            self.allocator.free(cookie.value);
            if (cookie.domain) |d| self.allocator.free(d);
            if (cookie.path) |p| self.allocator.free(p);
        }
        self.cookies.deinit();
    }

    /// 获取响应头
    pub fn getHeader(self: *const Response, name: []const u8) ?[]const u8 {
        return self.headers.get(name);
    }

    /// 判断请求是否成功
    pub fn isSuccess(self: *const Response) bool {
        const code = @intFromEnum(self.status);
        return code >= 200 and code < 300;
    }

    /// 解析 JSON 响应体
    pub fn json(self: *const Response, comptime T: type) !T {
        return try std.json.parseFromSlice(T, self.allocator, self.body, .{});
    }
};

/// Multipart 表单字段
pub const FormField = union(enum) {
    /// 普通文本字段
    text: struct {
        name: []const u8,
        value: []const u8,
    },
    /// 文件字段（从路径读取）
    file: struct {
        name: []const u8,
        filename: []const u8,
        path: []const u8,
        content_type: ?[]const u8 = null,
    },
    /// 流数据字段（直接传入字节）
    stream: struct {
        name: []const u8,
        filename: []const u8,
        data: []const u8,
        content_type: ?[]const u8 = null,
    },
};

/// HTTP 客户端
pub const HttpClient = struct {
    const Self = @This();

    allocator: Allocator,
    client: http.Client,
    default_headers: std.StringHashMap([]const u8),
    cookies: ArrayList(Cookie),

    /// 初始化客户端
    pub fn init(allocator: Allocator) Self {
        return Self{
            .allocator = allocator,
            .client = .{ .allocator = allocator },
            .default_headers = std.StringHashMap([]const u8).init(allocator),
            .cookies = ArrayList(Cookie).init(allocator),
        };
    }

    /// 释放客户端资源
    pub fn deinit(self: *Self) void {
        self.client.deinit();
        var iter = self.default_headers.iterator();
        while (iter.next()) |entry| {
            self.allocator.free(entry.key_ptr.*);
            self.allocator.free(entry.value_ptr.*);
        }
        self.default_headers.deinit();
        for (self.cookies.items) |cookie| {
            self.allocator.free(cookie.name);
            self.allocator.free(cookie.value);
            if (cookie.domain) |d| self.allocator.free(d);
            if (cookie.path) |p| self.allocator.free(p);
        }
        self.cookies.deinit();
    }

    /// 设置默认请求头
    pub fn setHeader(self: *Self, name: []const u8, value: []const u8) !void {
        const owned_name = try self.allocator.dupe(u8, name);
        const owned_value = try self.allocator.dupe(u8, value);
        try self.default_headers.put(owned_name, owned_value);
    }

    /// 删除默认请求头
    pub fn removeHeader(self: *Self, name: []const u8) void {
        if (self.default_headers.fetchRemove(name)) |kv| {
            self.allocator.free(kv.key);
            self.allocator.free(kv.value);
        }
    }

    /// 添加 Cookie
    pub fn addCookie(self: *Self, cookie: Cookie) !void {
        const owned_cookie = Cookie{
            .name = try self.allocator.dupe(u8, cookie.name),
            .value = try self.allocator.dupe(u8, cookie.value),
            .domain = if (cookie.domain) |d| try self.allocator.dupe(u8, d) else null,
            .path = if (cookie.path) |p| try self.allocator.dupe(u8, p) else null,
            .expires = cookie.expires,
            .secure = cookie.secure,
            .http_only = cookie.http_only,
        };
        try self.cookies.append(owned_cookie);
    }

    /// 清除所有 Cookie
    pub fn clearCookies(self: *Self) void {
        for (self.cookies.items) |cookie| {
            self.allocator.free(cookie.name);
            self.allocator.free(cookie.value);
            if (cookie.domain) |d| self.allocator.free(d);
            if (cookie.path) |p| self.allocator.free(p);
        }
        self.cookies.clearRetainingCapacity();
    }

    /// 获取指定名称的 Cookie
    pub fn getCookie(self: *const Self, name: []const u8) ?Cookie {
        for (self.cookies.items) |cookie| {
            if (std.mem.eql(u8, cookie.name, name)) {
                return cookie;
            }
        }
        return null;
    }

    /// 发送 GET 请求
    pub fn get(self: *Self, url: []const u8) !Response {
        return self.request(.GET, url, .{});
    }

    /// 发送带参数的 GET 请求
    pub fn getWithOptions(self: *Self, url: []const u8, options: RequestOptions) !Response {
        return self.request(.GET, url, options);
    }

    /// 发送 POST 请求
    pub fn post(self: *Self, url: []const u8, body: ?[]const u8) !Response {
        const options = RequestOptions{ .body = body };
        return self.request(.POST, url, options);
    }

    /// 发送 POST JSON 请求
    pub fn postJson(self: *Self, url: []const u8, data: anytype) !Response {
        const json_body = try std.json.stringifyAlloc(self.allocator, data, .{});
        defer self.allocator.free(json_body);

        const options = RequestOptions{
            .content_type = "application/json",
            .body = json_body,
        };
        return self.request(.POST, url, options);
    }

    /// 发送 PUT 请求
    pub fn put(self: *Self, url: []const u8, body: ?[]const u8) !Response {
        const options = RequestOptions{ .body = body };
        return self.request(.PUT, url, options);
    }

    /// 发送 DELETE 请求
    pub fn delete(self: *Self, url: []const u8) !Response {
        return self.request(.DELETE, url, .{});
    }

    /// 发送 PATCH 请求
    pub fn patch(self: *Self, url: []const u8, body: ?[]const u8) !Response {
        const options = RequestOptions{ .body = body };
        return self.request(.PATCH, url, options);
    }

    /// 下载文件到本地
    pub fn downloadFile(self: *Self, url: []const u8, save_path: []const u8, progress_opts: ProgressOptions) !void {
        const uri = try Uri.parse(url);

        var server_header_buffer: [16 * 1024]u8 = undefined;
        var req = try self.client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        // 获取文件大小
        const content_length: usize = if (req.response.content_length) |len| len else 0;

        // 创建输出文件
        const file = try std.fs.cwd().createFile(save_path, .{});
        defer file.close();

        // 带进度读取
        var reader = req.reader();
        var buffer: [8192]u8 = undefined;
        var total_read: usize = 0;
        var last_callback_time: i64 = std.time.milliTimestamp();
        const start_time = std.time.nanoTimestamp();

        while (true) {
            const bytes_read = try reader.read(&buffer);
            if (bytes_read == 0) break;

            try file.writeAll(buffer[0..bytes_read]);
            total_read += bytes_read;

            // 进度回调
            if (progress_opts.on_progress) |callback| {
                const now = std.time.milliTimestamp();
                if (now - last_callback_time >= progress_opts.interval_ms or bytes_read == 0) {
                    last_callback_time = now;
                    const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - start_time);
                    const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
                    const speed: usize = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(total_read)) / elapsed_secs) else 0;

                    const info = ProgressInfo{
                        .bytes_transferred = total_read,
                        .total_bytes = content_length,
                        .direction = .download,
                        .speed_bytes_per_sec = speed,
                        .elapsed_ns = elapsed_ns,
                        .user_data = progress_opts.user_data,
                    };
                    callback(&info);
                }
            }
        }

        // 最终回调（确保100%）
        if (progress_opts.on_progress) |callback| {
            const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - start_time);
            const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            const speed: usize = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(total_read)) / elapsed_secs) else 0;

            const info = ProgressInfo{
                .bytes_transferred = total_read,
                .total_bytes = if (content_length > 0) content_length else total_read,
                .direction = .download,
                .speed_bytes_per_sec = speed,
                .elapsed_ns = elapsed_ns,
                .user_data = progress_opts.user_data,
            };
            callback(&info);
        }
    }

    /// 下载到内存（带进度）
    pub fn downloadBytes(self: *Self, url: []const u8, progress_opts: ProgressOptions) ![]u8 {
        const uri = try Uri.parse(url);

        var server_header_buffer: [16 * 1024]u8 = undefined;
        var req = try self.client.open(.GET, uri, .{
            .server_header_buffer = &server_header_buffer,
        });
        defer req.deinit();

        try req.send();
        try req.wait();

        const content_length: usize = if (req.response.content_length) |len| len else 0;

        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        var reader = req.reader();
        var buffer: [8192]u8 = undefined;
        var total_read: usize = 0;
        var last_callback_time: i64 = std.time.milliTimestamp();
        const start_time = std.time.nanoTimestamp();

        while (true) {
            const bytes_read = try reader.read(&buffer);
            if (bytes_read == 0) break;

            try result.appendSlice(self.allocator, buffer[0..bytes_read]);
            total_read += bytes_read;

            if (progress_opts.on_progress) |callback| {
                const now = std.time.milliTimestamp();
                if (now - last_callback_time >= progress_opts.interval_ms) {
                    last_callback_time = now;
                    const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - start_time);
                    const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
                    const speed: usize = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(total_read)) / elapsed_secs) else 0;

                    const info = ProgressInfo{
                        .bytes_transferred = total_read,
                        .total_bytes = content_length,
                        .direction = .download,
                        .speed_bytes_per_sec = speed,
                        .elapsed_ns = elapsed_ns,
                        .user_data = progress_opts.user_data,
                    };
                    callback(&info);
                }
            }
        }

        // 最终回调
        if (progress_opts.on_progress) |callback| {
            const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - start_time);
            const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            const speed: usize = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(total_read)) / elapsed_secs) else 0;

            const info = ProgressInfo{
                .bytes_transferred = total_read,
                .total_bytes = if (content_length > 0) content_length else total_read,
                .direction = .download,
                .speed_bytes_per_sec = speed,
                .elapsed_ns = elapsed_ns,
                .user_data = progress_opts.user_data,
            };
            callback(&info);
        }

        return result.toOwnedSlice(self.allocator);
    }

    /// 上传文件（带进度）
    pub fn uploadFileWithProgress(
        self: *Self,
        url: []const u8,
        field_name: []const u8,
        file_path: []const u8,
        progress_opts: ProgressOptions,
    ) !Response {
        const uri = try Uri.parse(url);

        // 读取文件
        const file = try std.fs.cwd().openFile(file_path, .{});
        defer file.close();

        const stat = try file.stat();
        const file_size = stat.size;
        const filename = std.fs.path.basename(file_path);
        const content_type_str = guessContentType(filename);

        // 构建 multipart 头部
        const boundary = "----ZigCMSBoundary7MA4YWxkTrZu0gW";
        var header_buf = std.ArrayListUnmanaged(u8){};
        defer header_buf.deinit(self.allocator);

        const header_writer = header_buf.writer(self.allocator);
        try header_writer.print("--{s}\r\nContent-Disposition: form-data; name=\"{s}\"; filename=\"{s}\"\r\nContent-Type: {s}\r\n\r\n", .{ boundary, field_name, filename, content_type_str });

        const footer = "\r\n--" ++ boundary ++ "--\r\n";
        const total_size = header_buf.items.len + file_size + footer.len;

        // 打开连接
        var server_header_buffer: [16 * 1024]u8 = undefined;
        var req = try self.client.open(.POST, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = &.{
                .{ .name = "Content-Type", .value = "multipart/form-data; boundary=" ++ boundary },
            },
        });
        defer req.deinit();

        req.transfer_encoding = .{ .content_length = total_size };
        try req.send();

        const writer = req.writer();
        const start_time = std.time.nanoTimestamp();
        var total_sent: usize = 0;
        var last_callback_time: i64 = std.time.milliTimestamp();

        // 发送头部
        try writer.writeAll(header_buf.items);
        total_sent += header_buf.items.len;

        // 发送文件内容（分块）
        var buffer: [8192]u8 = undefined;
        while (true) {
            const bytes_read = try file.read(&buffer);
            if (bytes_read == 0) break;

            try writer.writeAll(buffer[0..bytes_read]);
            total_sent += bytes_read;

            // 进度回调
            if (progress_opts.on_progress) |callback| {
                const now = std.time.milliTimestamp();
                if (now - last_callback_time >= progress_opts.interval_ms) {
                    last_callback_time = now;
                    const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - start_time);
                    const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
                    const speed: usize = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(total_sent)) / elapsed_secs) else 0;

                    const info = ProgressInfo{
                        .bytes_transferred = total_sent,
                        .total_bytes = total_size,
                        .direction = .upload,
                        .speed_bytes_per_sec = speed,
                        .elapsed_ns = elapsed_ns,
                        .user_data = progress_opts.user_data,
                    };
                    callback(&info);
                }
            }
        }

        // 发送尾部
        try writer.writeAll(footer);
        total_sent += footer.len;

        // 最终回调
        if (progress_opts.on_progress) |callback| {
            const elapsed_ns: u64 = @intCast(std.time.nanoTimestamp() - start_time);
            const elapsed_secs = @as(f64, @floatFromInt(elapsed_ns)) / 1_000_000_000.0;
            const speed: usize = if (elapsed_secs > 0) @intFromFloat(@as(f64, @floatFromInt(total_sent)) / elapsed_secs) else 0;

            const info = ProgressInfo{
                .bytes_transferred = total_sent,
                .total_bytes = total_size,
                .direction = .upload,
                .speed_bytes_per_sec = speed,
                .elapsed_ns = elapsed_ns,
                .user_data = progress_opts.user_data,
            };
            callback(&info);
        }

        try req.finish();
        try req.wait();

        // 读取响应
        var body_reader = req.reader();
        var response_body = ArrayList(u8).init(self.allocator);
        errdefer response_body.deinit();

        try body_reader.readAllArrayList(&response_body, 10 * 1024 * 1024);

        var resp_headers = std.StringHashMap([]const u8).init(self.allocator);
        const resp_cookies = ArrayList(Cookie).init(self.allocator);

        var iter = req.response.iterateHeaders();
        while (iter.next()) |header| {
            const key = try self.allocator.dupe(u8, header.name);
            const val = try self.allocator.dupe(u8, header.value);
            try resp_headers.put(key, val);
        }

        return Response{
            .allocator = self.allocator,
            .status = req.response.status,
            .headers = resp_headers,
            .body = try response_body.toOwnedSlice(),
            .cookies = resp_cookies,
        };
    }

    /// 上传单个文件
    pub fn uploadFile(self: *Self, url: []const u8, field_name: []const u8, file_path: []const u8) !Response {
        const fields = [_]FormField{
            .{ .file = .{
                .name = field_name,
                .filename = std.fs.path.basename(file_path),
                .path = file_path,
            } },
        };
        return self.uploadMultipart(url, &fields);
    }

    /// 上传流数据
    pub fn uploadStream(self: *Self, url: []const u8, field_name: []const u8, filename: []const u8, data: []const u8, content_type: ?[]const u8) !Response {
        const fields = [_]FormField{
            .{ .stream = .{
                .name = field_name,
                .filename = filename,
                .data = data,
                .content_type = content_type,
            } },
        };
        return self.uploadMultipart(url, &fields);
    }

    /// Multipart 表单上传
    pub fn uploadMultipart(self: *Self, url: []const u8, fields: []const FormField) !Response {
        const boundary = "----ZigCMSBoundary" ++ "7MA4YWxkTrZu0gW";

        var body_parts = ArrayList(u8).init(self.allocator);
        defer body_parts.deinit();

        for (fields) |field| {
            switch (field) {
                .text => |t| {
                    try body_parts.appendSlice("--");
                    try body_parts.appendSlice(boundary);
                    try body_parts.appendSlice("\r\n");
                    try body_parts.appendSlice("Content-Disposition: form-data; name=\"");
                    try body_parts.appendSlice(t.name);
                    try body_parts.appendSlice("\"\r\n\r\n");
                    try body_parts.appendSlice(t.value);
                    try body_parts.appendSlice("\r\n");
                },
                .file => |f| {
                    const file_data = try readFileContent(self.allocator, f.path);
                    defer self.allocator.free(file_data);

                    try body_parts.appendSlice("--");
                    try body_parts.appendSlice(boundary);
                    try body_parts.appendSlice("\r\n");
                    try body_parts.appendSlice("Content-Disposition: form-data; name=\"");
                    try body_parts.appendSlice(f.name);
                    try body_parts.appendSlice("\"; filename=\"");
                    try body_parts.appendSlice(f.filename);
                    try body_parts.appendSlice("\"\r\n");
                    try body_parts.appendSlice("Content-Type: ");
                    try body_parts.appendSlice(f.content_type orelse guessContentType(f.filename));
                    try body_parts.appendSlice("\r\n\r\n");
                    try body_parts.appendSlice(file_data);
                    try body_parts.appendSlice("\r\n");
                },
                .stream => |s| {
                    try body_parts.appendSlice("--");
                    try body_parts.appendSlice(boundary);
                    try body_parts.appendSlice("\r\n");
                    try body_parts.appendSlice("Content-Disposition: form-data; name=\"");
                    try body_parts.appendSlice(s.name);
                    try body_parts.appendSlice("\"; filename=\"");
                    try body_parts.appendSlice(s.filename);
                    try body_parts.appendSlice("\"\r\n");
                    try body_parts.appendSlice("Content-Type: ");
                    try body_parts.appendSlice(s.content_type orelse guessContentType(s.filename));
                    try body_parts.appendSlice("\r\n\r\n");
                    try body_parts.appendSlice(s.data);
                    try body_parts.appendSlice("\r\n");
                },
            }
        }

        try body_parts.appendSlice("--");
        try body_parts.appendSlice(boundary);
        try body_parts.appendSlice("--\r\n");

        const content_type = try std.fmt.allocPrint(self.allocator, "multipart/form-data; boundary={s}", .{boundary});
        defer self.allocator.free(content_type);

        const options = RequestOptions{
            .content_type = content_type,
            .body = body_parts.items,
        };

        return self.request(.POST, url, options);
    }

    /// 发送表单数据
    pub fn postForm(self: *Self, url: []const u8, form_data: std.StringHashMap([]const u8)) !Response {
        var body = ArrayList(u8).init(self.allocator);
        defer body.deinit();

        var first = true;
        var iter = form_data.iterator();
        while (iter.next()) |entry| {
            if (!first) try body.append('&');
            first = false;

            try appendUrlEncoded(&body, entry.key_ptr.*);
            try body.append('=');
            try appendUrlEncoded(&body, entry.value_ptr.*);
        }

        const options = RequestOptions{
            .content_type = "application/x-www-form-urlencoded",
            .body = body.items,
        };

        return self.request(.POST, url, options);
    }

    /// 通用请求方法
    pub fn request(self: *Self, method: Method, url: []const u8, options: RequestOptions) !Response {
        const uri = try Uri.parse(url);

        var extra_headers = ArrayList(http.Header).init(self.allocator);
        defer extra_headers.deinit();

        // 添加默认头
        var default_iter = self.default_headers.iterator();
        while (default_iter.next()) |entry| {
            try extra_headers.append(.{
                .name = entry.key_ptr.*,
                .value = entry.value_ptr.*,
            });
        }

        // 添加 Cookie 头
        if (self.cookies.items.len > 0) {
            var cookie_str = ArrayList(u8).init(self.allocator);
            defer cookie_str.deinit();

            for (self.cookies.items, 0..) |cookie, i| {
                if (i > 0) try cookie_str.appendSlice("; ");
                try cookie_str.appendSlice(cookie.name);
                try cookie_str.append('=');
                try cookie_str.appendSlice(cookie.value);
            }

            const cookie_header = try self.allocator.dupe(u8, cookie_str.items);
            defer self.allocator.free(cookie_header);

            try extra_headers.append(.{ .name = "Cookie", .value = cookie_header });
        }

        // 添加自定义头
        if (options.user_agent) |ua| {
            try extra_headers.append(.{ .name = "User-Agent", .value = ua });
        }
        if (options.content_type) |ct| {
            try extra_headers.append(.{ .name = "Content-Type", .value = ct });
        }
        if (options.accept) |acc| {
            try extra_headers.append(.{ .name = "Accept", .value = acc });
        }
        if (options.authorization) |auth| {
            try extra_headers.append(.{ .name = "Authorization", .value = auth });
        }

        var server_header_buffer: [16 * 1024]u8 = undefined;

        var req = try self.client.open(method, uri, .{
            .server_header_buffer = &server_header_buffer,
            .extra_headers = extra_headers.items,
        });
        defer req.deinit();

        if (options.body) |body| {
            req.transfer_encoding = .{ .content_length = body.len };
        }

        try req.send();

        if (options.body) |body| {
            try req.writer().writeAll(body);
            try req.finish();
        }

        try req.wait();

        // 读取响应体
        var body_reader = req.reader();
        var response_body = ArrayList(u8).init(self.allocator);
        errdefer response_body.deinit();

        try body_reader.readAllArrayList(&response_body, 10 * 1024 * 1024);

        // 解析响应头
        var resp_headers = std.StringHashMap([]const u8).init(self.allocator);
        var resp_cookies = ArrayList(Cookie).init(self.allocator);

        // 从 http_response 解析 Set-Cookie 等头
        var iter = req.response.iterateHeaders();
        while (iter.next()) |header| {
            const key = try self.allocator.dupe(u8, header.name);
            const val = try self.allocator.dupe(u8, header.value);

            if (std.ascii.eqlIgnoreCase(header.name, "Set-Cookie")) {
                if (try parseCookie(self.allocator, header.value)) |cookie| {
                    try resp_cookies.append(cookie);
                    try self.cookies.append(cookie);
                }
            }

            try resp_headers.put(key, val);
        }

        return Response{
            .allocator = self.allocator,
            .status = req.response.status,
            .headers = resp_headers,
            .body = try response_body.toOwnedSlice(),
            .cookies = resp_cookies,
        };
    }
};

/// 读取文件内容
fn readFileContent(allocator: Allocator, path: []const u8) ![]const u8 {
    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const stat = try file.stat();
    const content = try allocator.alloc(u8, stat.size);
    errdefer allocator.free(content);

    const bytes_read = try file.readAll(content);
    if (bytes_read != stat.size) {
        return error.UnexpectedEof;
    }

    return content;
}

/// 根据文件扩展名猜测 Content-Type
fn guessContentType(filename: []const u8) []const u8 {
    const ext = std.fs.path.extension(filename);
    const mime_types = std.StaticStringMap([]const u8).initComptime(.{
        .{ ".html", "text/html" },
        .{ ".htm", "text/html" },
        .{ ".css", "text/css" },
        .{ ".js", "application/javascript" },
        .{ ".json", "application/json" },
        .{ ".xml", "application/xml" },
        .{ ".txt", "text/plain" },
        .{ ".png", "image/png" },
        .{ ".jpg", "image/jpeg" },
        .{ ".jpeg", "image/jpeg" },
        .{ ".gif", "image/gif" },
        .{ ".webp", "image/webp" },
        .{ ".svg", "image/svg+xml" },
        .{ ".ico", "image/x-icon" },
        .{ ".pdf", "application/pdf" },
        .{ ".zip", "application/zip" },
        .{ ".gz", "application/gzip" },
        .{ ".tar", "application/x-tar" },
        .{ ".mp3", "audio/mpeg" },
        .{ ".mp4", "video/mp4" },
        .{ ".webm", "video/webm" },
        .{ ".woff", "font/woff" },
        .{ ".woff2", "font/woff2" },
        .{ ".ttf", "font/ttf" },
        .{ ".otf", "font/otf" },
    });

    return mime_types.get(ext) orelse "application/octet-stream";
}

/// 解析 Set-Cookie 头
fn parseCookie(allocator: Allocator, header: []const u8) !?Cookie {
    var parts = std.mem.splitSequence(u8, header, ";");
    const first = parts.next() orelse return null;

    var name_value = std.mem.splitScalar(u8, first, '=');
    const name = std.mem.trim(u8, name_value.next() orelse return null, " ");
    const value = std.mem.trim(u8, name_value.rest(), " ");

    if (name.len == 0) return null;

    var cookie = Cookie{
        .name = try allocator.dupe(u8, name),
        .value = try allocator.dupe(u8, value),
    };

    while (parts.next()) |part| {
        const trimmed = std.mem.trim(u8, part, " ");
        var attr_parts = std.mem.splitScalar(u8, trimmed, '=');
        const attr_name = std.mem.trim(u8, attr_parts.next() orelse continue, " ");
        const attr_value = std.mem.trim(u8, attr_parts.rest(), " ");

        if (std.ascii.eqlIgnoreCase(attr_name, "domain")) {
            cookie.domain = try allocator.dupe(u8, attr_value);
        } else if (std.ascii.eqlIgnoreCase(attr_name, "path")) {
            cookie.path = try allocator.dupe(u8, attr_value);
        } else if (std.ascii.eqlIgnoreCase(attr_name, "secure")) {
            cookie.secure = true;
        } else if (std.ascii.eqlIgnoreCase(attr_name, "httponly")) {
            cookie.http_only = true;
        }
    }

    return cookie;
}

/// URL 编码追加
fn appendUrlEncoded(list: *ArrayList(u8), input: []const u8) !void {
    for (input) |c| {
        if (std.ascii.isAlphanumeric(c) or c == '-' or c == '_' or c == '.' or c == '~') {
            try list.append(c);
        } else if (c == ' ') {
            try list.append('+');
        } else {
            try list.append('%');
            const hex = "0123456789ABCDEF";
            try list.append(hex[c >> 4]);
            try list.append(hex[c & 0x0F]);
        }
    }
}

// ============================================================================
// 便捷构建器
// ============================================================================

/// 请求构建器
pub const RequestBuilder = struct {
    const Self = @This();

    client: *HttpClient,
    method: Method,
    url: []const u8,
    options: RequestOptions = .{},
    headers: std.StringHashMap([]const u8),
    form_fields: ?ArrayList(FormField) = null,

    /// 创建构建器
    pub fn init(client: *HttpClient, method: Method, url: []const u8) Self {
        return Self{
            .client = client,
            .method = method,
            .url = url,
            .headers = std.StringHashMap([]const u8).init(client.allocator),
            .form_fields = null,
        };
    }

    /// 设置超时
    pub fn timeout(self: *Self, ms: u64) *Self {
        self.options.timeout_ms = ms;
        self.options.timeout.total_ms = ms;
        return self;
    }

    /// 设置超时配置
    pub fn timeoutOptions(self: *Self, opts: TimeoutOptions) *Self {
        self.options.timeout = opts;
        return self;
    }

    /// 设置快速超时
    pub fn fastTimeout(self: *Self) *Self {
        self.options.timeout = TimeoutOptions.fast;
        return self;
    }

    /// 设置慢速超时
    pub fn slowTimeout(self: *Self) *Self {
        self.options.timeout = TimeoutOptions.slow;
        return self;
    }

    /// 设置请求体
    pub fn body(self: *Self, data: []const u8) *Self {
        self.options.body = data;
        return self;
    }

    /// 设置 Content-Type
    pub fn contentType(self: *Self, ct: []const u8) *Self {
        self.options.content_type = ct;
        return self;
    }

    /// 设置 Authorization
    pub fn auth(self: *Self, authorization: []const u8) *Self {
        self.options.authorization = authorization;
        return self;
    }

    /// 设置 Bearer Token
    pub fn bearerToken(self: *Self, token: []const u8) !*Self {
        const auth_header = try std.fmt.allocPrint(self.client.allocator, "Bearer {s}", .{token});
        self.options.authorization = auth_header;
        return self;
    }

    /// 设置 User-Agent
    pub fn userAgent(self: *Self, ua: []const u8) *Self {
        self.options.user_agent = ua;
        return self;
    }

    /// 添加请求头
    pub fn header(self: *Self, name: []const u8, value: []const u8) !*Self {
        try self.headers.put(name, value);
        return self;
    }

    /// 发送请求
    pub fn send(self: *Self) !Response {
        defer {
            self.headers.deinit();
            if (self.form_fields) |*fields| fields.deinit();
        }

        // 临时添加构建器中的头到客户端
        var iter = self.headers.iterator();
        while (iter.next()) |entry| {
            try self.client.setHeader(entry.key_ptr.*, entry.value_ptr.*);
        }

        defer {
            // 清理临时添加的头
            var clean_iter = self.headers.iterator();
            while (clean_iter.next()) |entry| {
                self.client.removeHeader(entry.key_ptr.*);
            }
        }

        if (self.form_fields) |fields| {
            return self.client.uploadMultipart(self.url, fields.items);
        }

        return self.client.request(self.method, self.url, self.options);
    }
};

// ============================================================================
// 测试
// ============================================================================

test "HttpClient: 基本初始化" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();

    try std.testing.expect(client.cookies.items.len == 0);
    try std.testing.expect(client.default_headers.count() == 0);
}

test "HttpClient: Cookie 管理" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();

    try client.addCookie(.{
        .name = "session",
        .value = "abc123",
        .domain = "example.com",
    });

    try std.testing.expectEqual(@as(usize, 1), client.cookies.items.len);
    const cookie = client.getCookie("session");
    try std.testing.expect(cookie != null);
    try std.testing.expectEqualStrings("abc123", cookie.?.value);

    client.clearCookies();
    try std.testing.expectEqual(@as(usize, 0), client.cookies.items.len);
}

test "HttpClient: 默认头管理" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();

    try client.setHeader("X-Custom-Header", "test-value");
    try std.testing.expectEqual(@as(usize, 1), client.default_headers.count());

    client.removeHeader("X-Custom-Header");
    try std.testing.expectEqual(@as(usize, 0), client.default_headers.count());
}

test "guessContentType" {
    try std.testing.expectEqualStrings("image/png", guessContentType("test.png"));
    try std.testing.expectEqualStrings("application/json", guessContentType("data.json"));
    try std.testing.expectEqualStrings("text/html", guessContentType("index.html"));
    try std.testing.expectEqualStrings("application/octet-stream", guessContentType("unknown.xyz"));
}

test "parseCookie" {
    const allocator = std.testing.allocator;

    const cookie = try parseCookie(allocator, "session=abc123; Path=/; HttpOnly; Secure");
    try std.testing.expect(cookie != null);

    defer {
        allocator.free(cookie.?.name);
        allocator.free(cookie.?.value);
        if (cookie.?.path) |p| allocator.free(p);
    }

    try std.testing.expectEqualStrings("session", cookie.?.name);
    try std.testing.expectEqualStrings("abc123", cookie.?.value);
    try std.testing.expectEqualStrings("/", cookie.?.path.?);
    try std.testing.expect(cookie.?.http_only);
    try std.testing.expect(cookie.?.secure);
}

test "appendUrlEncoded" {
    const allocator = std.testing.allocator;
    var list = ArrayList(u8).init(allocator);
    defer list.deinit();

    try appendUrlEncoded(&list, "hello world");
    try std.testing.expectEqualStrings("hello+world", list.items);

    list.clearRetainingCapacity();
    try appendUrlEncoded(&list, "name=value&foo=bar");
    try std.testing.expectEqualStrings("name%3Dvalue%26foo%3Dbar", list.items);
}

test "ProgressInfo: 百分比计算" {
    const info = ProgressInfo{
        .bytes_transferred = 500,
        .total_bytes = 1000,
        .direction = .download,
        .speed_bytes_per_sec = 100,
        .elapsed_ns = 5_000_000_000,
        .user_data = null,
    };

    try std.testing.expectEqual(@as(f64, 50.0), info.percent());
    try std.testing.expect(!info.isComplete());

    // 完成状态
    const complete_info = ProgressInfo{
        .bytes_transferred = 1000,
        .total_bytes = 1000,
        .direction = .download,
        .speed_bytes_per_sec = 100,
        .elapsed_ns = 10_000_000_000,
        .user_data = null,
    };
    try std.testing.expect(complete_info.isComplete());
    try std.testing.expectEqual(@as(f64, 100.0), complete_info.percent());
}

test "ProgressInfo: 剩余时间估算" {
    const info = ProgressInfo{
        .bytes_transferred = 500,
        .total_bytes = 1000,
        .direction = .download,
        .speed_bytes_per_sec = 100,
        .elapsed_ns = 5_000_000_000,
        .user_data = null,
    };

    const remaining = info.estimatedRemainingSecs();
    try std.testing.expect(remaining != null);
    try std.testing.expectEqual(@as(f64, 5.0), remaining.?);
}

test "ProgressInfo: 字节格式化" {
    const bytes_b = ProgressInfo.formatBytes(500);
    try std.testing.expectEqual(@as(f64, 500.0), bytes_b.value);
    try std.testing.expectEqualStrings("B", bytes_b.unit);

    const bytes_kb = ProgressInfo.formatBytes(2048);
    try std.testing.expectEqual(@as(f64, 2.0), bytes_kb.value);
    try std.testing.expectEqualStrings("KB", bytes_kb.unit);

    const bytes_mb = ProgressInfo.formatBytes(5 * 1024 * 1024);
    try std.testing.expectEqual(@as(f64, 5.0), bytes_mb.value);
    try std.testing.expectEqualStrings("MB", bytes_mb.unit);

    const bytes_gb = ProgressInfo.formatBytes(2 * 1024 * 1024 * 1024);
    try std.testing.expectEqual(@as(f64, 2.0), bytes_gb.value);
    try std.testing.expectEqualStrings("GB", bytes_gb.unit);
}

test "ProgressOptions: 默认值" {
    const opts = ProgressOptions{};
    try std.testing.expect(opts.on_progress == null);
    try std.testing.expectEqual(@as(u32, 100), opts.interval_ms);
    try std.testing.expect(opts.user_data == null);
}

test "ProgressCallback: 函数类型" {
    const TestContext = struct {
        var call_count: usize = 0;
        var last_percent: f64 = 0;

        fn callback(info: *const ProgressInfo) void {
            call_count += 1;
            last_percent = info.percent();
        }
    };

    TestContext.call_count = 0;
    TestContext.last_percent = 0;

    const info = ProgressInfo{
        .bytes_transferred = 750,
        .total_bytes = 1000,
        .direction = .download,
        .speed_bytes_per_sec = 100,
        .elapsed_ns = 7_500_000_000,
        .user_data = null,
    };

    const callback: ProgressCallback = TestContext.callback;
    callback(&info);

    try std.testing.expectEqual(@as(usize, 1), TestContext.call_count);
    try std.testing.expectEqual(@as(f64, 75.0), TestContext.last_percent);
}

test "TimeoutOptions: 预设值" {
    // 默认超时
    const default_opts = TimeoutOptions{};
    try std.testing.expectEqual(@as(u64, 10_000), default_opts.connect_ms);
    try std.testing.expectEqual(@as(u64, 30_000), default_opts.read_ms);
    try std.testing.expectEqual(@as(u64, 60_000), default_opts.total_ms);

    // 快速超时
    try std.testing.expectEqual(@as(u64, 2_000), TimeoutOptions.fast.connect_ms);
    try std.testing.expectEqual(@as(u64, 5_000), TimeoutOptions.fast.read_ms);
    try std.testing.expectEqual(@as(u64, 10_000), TimeoutOptions.fast.total_ms);

    // 慢速超时
    try std.testing.expectEqual(@as(u64, 30_000), TimeoutOptions.slow.connect_ms);
    try std.testing.expectEqual(@as(u64, 300_000), TimeoutOptions.slow.read_ms);
    try std.testing.expectEqual(@as(u64, 600_000), TimeoutOptions.slow.total_ms);

    // 无超时
    try std.testing.expectEqual(@as(u64, 0), TimeoutOptions.none.connect_ms);
    try std.testing.expectEqual(@as(u64, 0), TimeoutOptions.none.total_ms);
}

test "RequestBuilder: 超时设置" {
    const allocator = std.testing.allocator;
    var client = HttpClient.init(allocator);
    defer client.deinit();

    var builder = RequestBuilder.init(&client, .GET, "https://example.com");
    defer builder.headers.deinit();

    // 简单超时
    _ = builder.timeout(5000);
    try std.testing.expectEqual(@as(u64, 5000), builder.options.timeout.total_ms);

    // 快速超时
    _ = builder.fastTimeout();
    try std.testing.expectEqual(@as(u64, 10_000), builder.options.timeout.total_ms);

    // 慢速超时
    _ = builder.slowTimeout();
    try std.testing.expectEqual(@as(u64, 600_000), builder.options.timeout.total_ms);

    // 自定义超时
    _ = builder.timeoutOptions(.{
        .connect_ms = 1000,
        .read_ms = 2000,
        .write_ms = 3000,
        .total_ms = 4000,
    });
    try std.testing.expectEqual(@as(u64, 1000), builder.options.timeout.connect_ms);
    try std.testing.expectEqual(@as(u64, 4000), builder.options.timeout.total_ms);
}
