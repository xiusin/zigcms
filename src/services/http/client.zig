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
//! ```

const std = @import("std");
const http = std.http;
const Allocator = std.mem.Allocator;
const Uri = std.Uri;
const ArrayList = std.array_list.Managed;

/// HTTP 方法
pub const Method = http.Method;

/// 请求配置
pub const RequestOptions = struct {
    /// 请求超时（毫秒）
    timeout_ms: u64 = 30_000,
    /// 连接超时（毫秒）
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
