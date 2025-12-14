//! 通用上传服务接口
//!
//! 支持多种云存储服务（TOS、COS、OSS）的统一接口

const std = @import("std");
const Allocator = std.mem.Allocator;

/// 上传结果
pub const UploadResult = struct {
    /// 文件访问URL
    url: []const u8,
    /// 文件存储路径
    path: []const u8,
    /// 文件大小
    size: usize,
    /// 文件MIME类型
    mime_type: []const u8,
    /// 原始文件名
    original_name: []const u8,
};

/// 上传提供者接口
pub const UploadProvider = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        /// 上传文件
        upload: *const fn (*anyopaque, Allocator, []const u8, []const u8, ?[]const u8) anyerror!UploadResult,
        /// 删除文件
        delete: *const fn (*anyopaque, []const u8) anyerror!void,
        /// 检查文件是否存在
        exists: *const fn (*anyopaque, []const u8) anyerror!bool,
        /// 获取文件信息
        getInfo: *const fn (*anyopaque, Allocator, []const u8) anyerror!UploadResult,
        /// 销毁提供者
        deinit: *const fn (*anyopaque, Allocator) void,
    };

    /// 上传文件
    pub fn upload(self: UploadProvider, allocator: Allocator, filename: []const u8, data: []const u8, content_type: ?[]const u8) !UploadResult {
        return self.vtable.upload(self.ptr, allocator, filename, data, content_type);
    }

    /// 删除文件
    pub fn delete(self: UploadProvider, path: []const u8) !void {
        return self.vtable.delete(self.ptr, path);
    }

    /// 检查文件是否存在
    pub fn exists(self: UploadProvider, path: []const u8) !bool {
        return self.vtable.exists(self.ptr, path);
    }

    /// 获取文件信息
    pub fn getInfo(self: UploadProvider, allocator: Allocator, path: []const u8) !UploadResult {
        return self.vtable.getInfo(self.ptr, allocator, path);
    }

    /// 销毁提供者
    pub fn deinit(self: UploadProvider, allocator: Allocator) void {
        self.vtable.deinit(self.ptr, allocator);
    }
};

/// 上传提供者类型枚举
pub const ProviderType = enum {
    local, // 本地存储
    tos, // 腾讯云对象存储 TOS
    cos, // 腾讯云对象存储 COS
    oss, // 阿里云对象存储 OSS
    qiniu, // 七牛云存储
    upyun, // 又拍云存储
};

/// 上传配置
pub const UploadConfig = struct {
    /// 提供者类型
    provider: ProviderType = .local,
    /// 本地存储配置
    local: LocalConfig = .{},
    /// TOS配置
    tos: TOSConfig = .{},
    /// COS配置
    cos: COSConfig = .{},
    /// OSS配置
    oss: OSSConfig = .{},
    /// 七牛配置
    qiniu: QiniuConfig = .{},
    /// 又拍云配置
    upyun: UpyunConfig = .{},

    /// 本地存储配置
    pub const LocalConfig = struct {
        /// 上传根目录
        root_path: []const u8 = "uploads",
        /// 访问URL前缀
        url_prefix: []const u8 = "/uploads",
        /// 最大文件大小（字节）
        max_size: usize = 10 * 1024 * 1024, // 10MB
    };

    /// TOS配置
    pub const TOSConfig = struct {
        /// Access Key ID
        access_key_id: []const u8 = "",
        /// Access Key Secret
        access_key_secret: []const u8 = "",
        /// 地域
        region: []const u8 = "",
        /// 存储桶名称
        bucket: []const u8 = "",
        /// 访问域名
        domain: []const u8 = "",
        /// 是否私有存储
        is_private: bool = false,
    };

    /// COS配置
    pub const COSConfig = struct {
        /// Secret ID
        secret_id: []const u8 = "",
        /// Secret Key
        secret_key: []const u8 = "",
        /// 地域
        region: []const u8 = "",
        /// 存储桶名称
        bucket: []const u8 = "",
        /// 访问域名
        domain: []const u8 = "",
        /// 是否私有存储
        is_private: bool = false,
    };

    /// OSS配置
    pub const OSSConfig = struct {
        /// Access Key ID
        access_key_id: []const u8 = "",
        /// Access Key Secret
        access_key_secret: []const u8 = "",
        /// Endpoint
        endpoint: []const u8 = "",
        /// 存储桶名称
        bucket: []const u8 = "",
        /// 访问域名
        domain: []const u8 = "",
        /// 是否私有存储
        is_private: bool = false,
    };

    /// 七牛配置
    pub const QiniuConfig = struct {
        /// Access Key
        access_key: []const u8 = "",
        /// Secret Key
        secret_key: []const u8 = "",
        /// 存储空间名称
        bucket: []const u8 = "",
        /// 访问域名
        domain: []const u8 = "",
        /// 是否私有存储
        is_private: bool = false,
    };

    /// 又拍云配置
    pub const UpyunConfig = struct {
        /// 操作员名称
        operator: []const u8 = "",
        /// 操作员密码
        password: []const u8 = "",
        /// 服务名称
        bucket: []const u8 = "",
        /// 访问域名
        domain: []const u8 = "",
        /// 是否私有存储
        is_private: bool = false,
    };
};

/// 上传服务管理器
pub const UploadManager = struct {
    allocator: Allocator,
    config: UploadConfig,
    provider: UploadProvider,

    /// 初始化上传管理器
    pub fn init(allocator: Allocator, config: UploadConfig) !UploadManager {
        const provider = try createProvider(allocator, config);
        return .{
            .allocator = allocator,
            .config = config,
            .provider = provider,
        };
    }

    /// 销毁上传管理器
    pub fn deinit(self: *UploadManager) void {
        self.provider.deinit(self.allocator);
    }

    /// 上传文件
    pub fn upload(self: *UploadManager, filename: []const u8, data: []const u8, content_type: ?[]const u8) !UploadResult {
        return try self.provider.upload(self.allocator, filename, data, content_type);
    }

    /// 删除文件
    pub fn delete(self: *UploadManager, path: []const u8) !void {
        return try self.provider.delete(path);
    }

    /// 检查文件是否存在
    pub fn exists(self: *UploadManager, path: []const u8) !bool {
        return try self.provider.exists(path);
    }

    /// 获取文件信息
    pub fn getInfo(self: *UploadManager, path: []const u8) !UploadResult {
        return try self.provider.getInfo(self.allocator, path);
    }
};

/// 创建上传提供者
fn createProvider(allocator: Allocator, config: UploadConfig) !UploadProvider {
    return switch (config.provider) {
        .local => try LocalProvider.create(allocator, config.local),
        .tos => try TOSProvider.create(allocator, config.tos),
        .cos => try COSProvider.create(allocator, config.cos),
        .oss => try OSSProvider.create(allocator, config.oss),
        .qiniu => try QiniuProvider.create(allocator, config.qiniu),
        .upyun => try UpyunProvider.create(allocator, config.upyun),
    };
}

// ============================================================================
// 提供者实现
// ============================================================================

/// 本地存储提供者
pub const LocalProvider = struct {
    config: UploadConfig.LocalConfig,
    allocator: Allocator,

    pub fn create(allocator: Allocator, config: UploadConfig.LocalConfig) !UploadProvider {
        const self = try allocator.create(LocalProvider);
        self.* = .{
            .config = config,
            .allocator = allocator,
        };

        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = UploadProvider.VTable{
        .upload = upload,
        .delete = delete,
        .exists = exists,
        .getInfo = getInfo,
        .deinit = deinit,
    };

    fn upload(ptr: *anyopaque, allocator: Allocator, filename: []const u8, data: []const u8, content_type: ?[]const u8) anyerror!UploadResult {
        const self: *LocalProvider = @ptrCast(@alignCast(ptr));
        _ = content_type; // 本地存储暂时不使用

        // 生成文件路径
        const timestamp = std.time.timestamp();
        const file_ext = std.fs.path.extension(filename);
        const base_name = std.fs.path.stem(filename);
        const new_filename = try std.fmt.allocPrint(allocator, "{s}_{d}{s}", .{ base_name, timestamp, file_ext });
        defer allocator.free(new_filename);

        const file_path = try std.fs.path.join(allocator, &.{ self.config.root_path, new_filename });
        defer allocator.free(file_path);

        // 确保目录存在
        const dir_path = std.fs.path.dirname(file_path) orelse self.config.root_path;
        try std.fs.cwd().makePath(dir_path);

        // 写入文件
        const file = try std.fs.cwd().createFile(file_path, .{});
        defer file.close();
        _ = try file.writeAll(data);

        // 构造URL
        const url = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.config.url_prefix, new_filename });

        return UploadResult{
            .url = url,
            .path = try allocator.dupe(u8, file_path),
            .size = data.len,
            .mime_type = "application/octet-stream", // 暂时固定
            .original_name = try allocator.dupe(u8, filename),
        };
    }

    fn delete(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *LocalProvider = @ptrCast(@alignCast(ptr));
        _ = self;
        try std.fs.cwd().deleteFile(path);
    }

    fn exists(ptr: *anyopaque, path: []const u8) anyerror!bool {
        const self: *LocalProvider = @ptrCast(@alignCast(ptr));
        _ = self;
        std.fs.cwd().access(path, .{}) catch return false;
        return true;
    }

    fn getInfo(ptr: *anyopaque, allocator: Allocator, path: []const u8) anyerror!UploadResult {
        const self: *LocalProvider = @ptrCast(@alignCast(ptr));
        _ = self;

        const stat = try std.fs.cwd().statFile(path);
        const filename = std.fs.path.basename(path);
        const url = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.config.url_prefix, filename });

        return UploadResult{
            .url = url,
            .path = try allocator.dupe(u8, path),
            .size = stat.size,
            .mime_type = "application/octet-stream",
            .original_name = try allocator.dupe(u8, filename),
        };
    }

    fn deinit(ptr: *anyopaque, allocator: Allocator) void {
        const self: *LocalProvider = @ptrCast(@alignCast(ptr));
        allocator.destroy(self);
    }
};

// TODO: 实现其他云存储提供者
// TOS (腾讯云对象存储)
pub const TOSProvider = struct {
    pub fn create(allocator: Allocator, config: UploadConfig.TOSConfig) !UploadProvider {
        _ = allocator;
        _ = config;
        @panic("TOS provider not implemented yet");
    }
};

// COS (腾讯云对象存储)
pub const COSProvider = struct {
    config: UploadConfig.COSConfig,
    allocator: Allocator,
    http_client: std.http.Client,

    pub fn create(allocator: Allocator, config: UploadConfig.COSConfig) !UploadProvider {
        const self = try allocator.create(COSProvider);
        errdefer allocator.destroy(self);

        self.* = .{
            .config = config,
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
        };

        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = UploadProvider.VTable{
        .upload = upload,
        .delete = delete,
        .exists = exists,
        .getInfo = getInfo,
        .deinit = deinit,
    };

    fn upload(ptr: *anyopaque, allocator: Allocator, filename: []const u8, data: []const u8, content_type: ?[]const u8) anyerror!UploadResult {
        const self: *COSProvider = @ptrCast(@alignCast(ptr));

        // 生成唯一的文件名
        const timestamp = std.time.timestamp();
        const file_ext = std.fs.path.extension(filename);
        const base_name = std.fs.path.stem(filename);
        const unique_filename = try std.fmt.allocPrint(allocator, "{s}_{d}{s}", .{ base_name, timestamp, file_ext });
        defer allocator.free(unique_filename);

        // 构建COS请求URL
        const object_key = try std.fmt.allocPrint(allocator, "uploads/{s}", .{unique_filename});
        defer allocator.free(object_key);

        const url = try std.fmt.allocPrint(allocator, "https://{s}.cos.{s}.myqcloud.com/{s}", .{ self.config.bucket, self.config.region, object_key });
        defer allocator.free(url);

        // 计算签名（简化的HMAC-SHA1签名）
        const signature = try self.calculateSignature(allocator, "PUT", object_key, "", data);
        defer allocator.free(signature);

        const auth_header = try std.fmt.allocPrint(allocator, "q-sign-algorithm=sha1&q-ak={s}&q-sign-time={d};{d}&q-key-time={d};{d}&q-header-list=host&q-url-param-list=&q-signature={s}", .{
            self.config.secret_id,
            timestamp - 600, // 10分钟前
            timestamp + 600, // 10分钟后
            timestamp - 600,
            timestamp + 600,
            signature,
        });
        defer allocator.free(auth_header);

        // 发送PUT请求上传文件
        var req = try self.http_client.open(.PUT, try std.Uri.parse(url), .{});
        defer req.deinit();

        // 设置请求头
        req.headers.add("Authorization", auth_header);
        req.headers.add("Host", try std.fmt.allocPrint(allocator, "{s}.cos.{s}.myqcloud.com", .{ self.config.bucket, self.config.region }));
        if (content_type) |ct| {
            req.headers.add("Content-Type", ct);
        } else {
            req.headers.add("Content-Type", "application/octet-stream");
        }
        req.headers.add("Content-Length", try std.fmt.allocPrint(allocator, "{d}", .{data.len}));

        // 发送请求体
        try req.send(.{});
        _ = try req.writer().writeAll(data);
        try req.finish();
        try req.wait();

        if (req.response.status != .ok) {
            return error.UploadFailed;
        }

        // 构造访问URL
        const access_url = if (self.config.domain.len > 0)
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.config.domain, object_key })
        else
            try std.fmt.allocPrint(allocator, "https://{s}.cos.{s}.myqcloud.com/{s}", .{ self.config.bucket, self.config.region, object_key });

        return UploadResult{
            .url = access_url,
            .path = try allocator.dupe(u8, object_key),
            .size = data.len,
            .mime_type = content_type orelse "application/octet-stream",
            .original_name = try allocator.dupe(u8, filename),
        };
    }

    fn delete(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *COSProvider = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}.cos.{s}.myqcloud.com/{s}", .{ self.config.bucket, self.config.region, path });
        defer self.allocator.free(url);

        // 计算签名
        const timestamp = std.time.timestamp();
        const signature = try self.calculateSignature(self.allocator, "DELETE", path, "", "");
        defer self.allocator.free(signature);

        const auth_header = try std.fmt.allocPrint(self.allocator, "q-sign-algorithm=sha1&q-ak={s}&q-sign-time={d};{d}&q-key-time={d};{d}&q-header-list=host&q-url-param-list=&q-signature={s}", .{ self.config.secret_id, timestamp - 600, timestamp + 600, timestamp - 600, timestamp + 600, signature });
        defer self.allocator.free(auth_header);

        // 发送DELETE请求
        var req = try self.http_client.open(.DELETE, try std.Uri.parse(url), .{});
        defer req.deinit();

        req.headers.add("Authorization", auth_header);
        req.headers.add("Host", try std.fmt.allocPrint(self.allocator, "{s}.cos.{s}.myqcloud.com", .{ self.config.bucket, self.config.region }));

        try req.send(.{});
        try req.finish();
        try req.wait();

        if (req.response.status != .no_content and req.response.status != .ok) {
            return error.DeleteFailed;
        }
    }

    fn exists(ptr: *anyopaque, path: []const u8) anyerror!bool {
        const self: *COSProvider = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}.cos.{s}.myqcloud.com/{s}", .{ self.config.bucket, self.config.region, path });
        defer self.allocator.free(url);

        // 发送HEAD请求检查文件是否存在
        var req = try self.http_client.open(.HEAD, try std.Uri.parse(url), .{});
        defer req.deinit();

        try req.send(.{});
        try req.finish();
        try req.wait();

        return req.response.status == .ok;
    }

    fn getInfo(ptr: *anyopaque, allocator: Allocator, path: []const u8) anyerror!UploadResult {
        const self: *COSProvider = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(allocator, "https://{s}.cos.{s}.myqcloud.com/{s}", .{ self.config.bucket, self.config.region, path });
        defer allocator.free(url);

        // 发送HEAD请求获取文件信息
        var req = try self.http_client.open(.HEAD, try std.Uri.parse(url), .{});
        defer req.deinit();

        try req.send(.{});
        try req.finish();
        try req.wait();

        if (req.response.status != .ok) {
            return error.FileNotFound;
        }

        const content_length = req.response.headers.getFirstValue("Content-Length") orelse "0";
        const size = try std.fmt.parseInt(usize, content_length, 10);
        const content_type = req.response.headers.getFirstValue("Content-Type") orelse "application/octet-stream";

        const filename = std.fs.path.basename(path);
        const access_url = if (self.config.domain.len > 0)
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.config.domain, path })
        else
            try allocator.dupe(u8, url);

        return UploadResult{
            .url = access_url,
            .path = try allocator.dupe(u8, path),
            .size = size,
            .mime_type = try allocator.dupe(u8, content_type),
            .original_name = try allocator.dupe(u8, filename),
        };
    }

    fn deinit(ptr: *anyopaque, allocator: Allocator) void {
        const self: *COSProvider = @ptrCast(@alignCast(ptr));
        self.http_client.deinit();
        allocator.destroy(self);
    }

    /// 计算COS签名
    fn calculateSignature(self: *COSProvider, allocator: Allocator, method: []const u8, object_key: []const u8, params: []const u8, body: []const u8) ![]const u8 {
        _ = self;
        _ = allocator;
        _ = method;
        _ = object_key;
        _ = params;
        _ = body;
        // TODO: 实现COS签名算法
        // 这里需要实现腾讯云COS的签名算法，包括：
        // 1. 构造StringToSign
        // 2. 使用HMAC-SHA1计算签名
        // 3. Base64编码

        // 暂时返回空字符串，实际使用时需要完整实现
        return allocator.dupe(u8, "");
    }
};

// OSS (阿里云对象存储)
pub const OSSProvider = struct {
    config: UploadConfig.OSSConfig,
    allocator: Allocator,
    http_client: std.http.Client,

    pub fn create(allocator: Allocator, config: UploadConfig.OSSConfig) !UploadProvider {
        const self = try allocator.create(OSSProvider);
        errdefer allocator.destroy(self);

        self.* = .{
            .config = config,
            .allocator = allocator,
            .http_client = std.http.Client{ .allocator = allocator },
        };

        return .{
            .ptr = self,
            .vtable = &vtable,
        };
    }

    const vtable = UploadProvider.VTable{
        .upload = upload,
        .delete = delete,
        .exists = exists,
        .getInfo = getInfo,
        .deinit = deinit,
    };

    fn upload(ptr: *anyopaque, allocator: Allocator, filename: []const u8, data: []const u8, content_type: ?[]const u8) anyerror!UploadResult {
        const self: *OSSProvider = @ptrCast(@alignCast(ptr));

        // 生成唯一的文件名
        const timestamp = std.time.timestamp();
        const file_ext = std.fs.path.extension(filename);
        const base_name = std.fs.path.stem(filename);
        const unique_filename = try std.fmt.allocPrint(allocator, "{s}_{d}{s}", .{ base_name, timestamp, file_ext });
        defer allocator.free(unique_filename);

        // 构建OSS请求URL
        const object_key = try std.fmt.allocPrint(allocator, "uploads/{s}", .{unique_filename});
        defer allocator.free(object_key);

        const url = try std.fmt.allocPrint(allocator, "https://{s}.{s}/{s}", .{ self.config.bucket, self.config.endpoint, object_key });
        defer allocator.free(url);

        // 计算签名
        const signature = try self.calculateSignature(allocator, "PUT", object_key, content_type orelse "", data);
        defer allocator.free(signature);

        const auth_header = try std.fmt.allocPrint(allocator, "OSS {s}:{s}", .{ self.config.access_key_id, signature });
        defer allocator.free(auth_header);

        // 发送PUT请求上传文件
        var req = try self.http_client.open(.PUT, try std.Uri.parse(url), .{});
        defer req.deinit();

        // 设置请求头
        req.headers.add("Authorization", auth_header);
        req.headers.add("Host", try std.fmt.allocPrint(allocator, "{s}.{s}", .{ self.config.bucket, self.config.endpoint }));
        req.headers.add("Date", try self.getGMTDate(allocator));
        if (content_type) |ct| {
            req.headers.add("Content-Type", ct);
        } else {
            req.headers.add("Content-Type", "application/octet-stream");
        }
        req.headers.add("Content-Length", try std.fmt.allocPrint(allocator, "{d}", .{data.len}));

        // 发送请求体
        try req.send(.{});
        _ = try req.writer().writeAll(data);
        try req.finish();
        try req.wait();

        if (req.response.status != .ok) {
            return error.UploadFailed;
        }

        // 构造访问URL
        const access_url = if (self.config.domain.len > 0)
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.config.domain, object_key })
        else
            try allocator.dupe(u8, url);

        return UploadResult{
            .url = access_url,
            .path = try allocator.dupe(u8, object_key),
            .size = data.len,
            .mime_type = content_type orelse "application/octet-stream",
            .original_name = try allocator.dupe(u8, filename),
        };
    }

    fn delete(ptr: *anyopaque, path: []const u8) anyerror!void {
        const self: *OSSProvider = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}.{s}/{s}", .{ self.config.bucket, self.config.endpoint, path });
        defer self.allocator.free(url);

        // 计算签名
        const signature = try self.calculateSignature(self.allocator, "DELETE", path, "", "");
        defer self.allocator.free(signature);

        const auth_header = try std.fmt.allocPrint(self.allocator, "OSS {s}:{s}", .{ self.config.access_key_id, signature });
        defer self.allocator.free(auth_header);

        const date_header = try self.getGMTDate(self.allocator);
        defer self.allocator.free(date_header);

        // 发送DELETE请求
        var req = try self.http_client.open(.DELETE, try std.Uri.parse(url), .{});
        defer req.deinit();

        req.headers.add("Authorization", auth_header);
        req.headers.add("Host", try std.fmt.allocPrint(self.allocator, "{s}.{s}", .{ self.config.bucket, self.config.endpoint }));
        req.headers.add("Date", date_header);

        try req.send(.{});
        try req.finish();
        try req.wait();

        if (req.response.status != .no_content and req.response.status != .ok) {
            return error.DeleteFailed;
        }
    }

    fn exists(ptr: *anyopaque, path: []const u8) anyerror!bool {
        const self: *OSSProvider = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(self.allocator, "https://{s}.{s}/{s}", .{ self.config.bucket, self.config.endpoint, path });
        defer self.allocator.free(url);

        // 发送HEAD请求检查文件是否存在
        var req = try self.http_client.open(.HEAD, try std.Uri.parse(url), .{});
        defer req.deinit();

        try req.send(.{});
        try req.finish();
        try req.wait();

        return req.response.status == .ok;
    }

    fn getInfo(ptr: *anyopaque, allocator: Allocator, path: []const u8) anyerror!UploadResult {
        const self: *OSSProvider = @ptrCast(@alignCast(ptr));

        const url = try std.fmt.allocPrint(allocator, "https://{s}.{s}/{s}", .{ self.config.bucket, self.config.endpoint, path });
        defer allocator.free(url);

        // 发送HEAD请求获取文件信息
        var req = try self.http_client.open(.HEAD, try std.Uri.parse(url), .{});
        defer req.deinit();

        try req.send(.{});
        try req.finish();
        try req.wait();

        if (req.response.status != .ok) {
            return error.FileNotFound;
        }

        const content_length = req.response.headers.getFirstValue("Content-Length") orelse "0";
        const size = try std.fmt.parseInt(usize, content_length, 10);
        const content_type = req.response.headers.getFirstValue("Content-Type") orelse "application/octet-stream";

        const filename = std.fs.path.basename(path);
        const access_url = if (self.config.domain.len > 0)
            try std.fmt.allocPrint(allocator, "{s}/{s}", .{ self.config.domain, path })
        else
            try allocator.dupe(u8, url);

        return UploadResult{
            .url = access_url,
            .path = try allocator.dupe(u8, path),
            .size = size,
            .mime_type = try allocator.dupe(u8, content_type),
            .original_name = try allocator.dupe(u8, filename),
        };
    }

    fn deinit(ptr: *anyopaque, allocator: Allocator) void {
        const self: *OSSProvider = @ptrCast(@alignCast(ptr));
        self.http_client.deinit();
        allocator.destroy(self);
    }

    /// 计算OSS签名
    fn calculateSignature(self: *OSSProvider, allocator: Allocator, method: []const u8, object_key: []const u8, content_type: []const u8, body: []const u8) ![]const u8 {
        _ = self;
        _ = allocator;
        _ = method;
        _ = object_key;
        _ = content_type;
        _ = body;
        // TODO: 实现OSS签名算法
        // 这里需要实现阿里云OSS的签名算法，包括：
        // 1. 构造StringToSign
        // 2. 使用HMAC-SHA1计算签名
        // 3. Base64编码

        // 暂时返回空字符串，实际使用时需要完整实现
        return allocator.dupe(u8, "");
    }

    /// 获取GMT格式的日期
    fn getGMTDate(self: *OSSProvider, allocator: Allocator) ![]const u8 {
        _ = self;
        _ = allocator;
        // TODO: 实现GMT日期格式化
        // 返回类似 "Wed, 21 Oct 2015 07:28:00 GMT" 的格式

        // 暂时返回固定字符串，实际使用时需要完整实现
        return allocator.dupe(u8, "Wed, 21 Oct 2015 07:28:00 GMT");
    }
};

// 七牛云存储
pub const QiniuProvider = struct {
    pub fn create(allocator: Allocator, config: UploadConfig.QiniuConfig) !UploadProvider {
        _ = allocator;
        _ = config;
        @panic("Qiniu provider not implemented yet");
    }
};

// 又拍云存储
pub const UpyunProvider = struct {
    pub fn create(allocator: Allocator, config: UploadConfig.UpyunConfig) !UploadProvider {
        _ = allocator;
        _ = config;
        @panic("Upyun provider not implemented yet");
    }
};
