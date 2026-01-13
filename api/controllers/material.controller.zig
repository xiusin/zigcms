//! 素材管理控制器
//!
//! 提供素材的 CRUD 操作及文件上传管理

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const sql = @import("../../application/services/sql/orm.zig");
const global = @import("../../shared/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");
const upload_service = @import("../../application/services/upload/upload.zig");
const user_context = @import("../../shared/utils/context.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,
upload_manager: ?*upload.UploadManager = null,

/// ORM 模型定义
const OrmMaterial = sql.defineWithConfig(models.Material, .{
    .table_name = "zigcms.material",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmMaterial.hasDb()) {
        OrmMaterial.use(global.get_db());
    }

    // 初始化上传管理器
    var upload_manager_opt: ?*upload.UploadManager = null;
    const upload_config = upload.UploadConfig{
        .provider = .local,
        .local = .{
            .base_path = "uploads",
            .max_file_size = 50 * 1024 * 1024, // 50MB
        },
    };

    const manager = upload.UploadManager.init(allocator, upload_config) catch {
        // 如果初始化失败，使用空管理器
        std.debug.print("警告: 上传管理器初始化失败，使用本地上传\n", .{});
    };

    if (manager) |m| {
        upload_manager_opt = m;
    }

    return .{
        .allocator = allocator,
        .upload_manager = upload_manager_opt,
    };
}

/// 销毁控制器
pub fn deinit(self: *Self) void {
    if (self.upload_manager) |manager| {
        manager.deinit();
        self.allocator.destroy(manager);
    }
}

// ============================================================================
// 公开 API（带认证中间件）
// ============================================================================

/// 分页列表
pub const list = MW.requireAuth(listImpl);

/// 获取单条记录
pub const get = MW.requireAuth(getImpl);

/// 保存（新增/更新）
pub const save = MW.requireAuth(saveImpl);

/// 删除
pub const delete = MW.requireAuth(deleteImpl);

/// 批量删除
pub const batch_delete = MW.requireAuth(batchDeleteImpl);

/// 上传文件
pub const upload = MW.requireAuth(uploadImpl);

/// 下载文件
pub const download = MW.requireAuth(downloadImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    var query_params = std.StringHashMap([]const u8).init(self.allocator);
    defer query_params.deinit();

    // 解析查询参数
    var it = r.queryParameters();
    while (it.next()) |param| {
        if (param.key) |key| {
            if (param.value) |value| {
                try query_params.put(key, value);
            }
        }
    }

    // 构建查询
    var query = OrmMaterial.query(global.get_db());
    defer query.deinit();

    // 分类筛选
    if (query_params.get("category_id")) |category_id_str| {
        if (std.fmt.parseInt(i32, category_id_str, 10)) |category_id| {
            _ = query.where("category_id", "=", category_id);
        } else |_| {}
    }

    // 文件类型筛选
    if (query_params.get("file_type")) |file_type| {
        if (file_type.len > 0) {
            _ = query.where("file_type", "=", file_type);
        }
    }

    // 状态筛选
    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            _ = query.where("status", "=", status);
        } else |_| {}
    }

    // 关键词搜索
    if (query_params.get("keyword")) |keyword| {
        if (keyword.len > 0) {
            _ = query.whereRaw("name LIKE ? OR original_name LIKE ?", .{ "%" ++ keyword ++ "%", "%" ++ keyword ++ "%" });
        }
    }

    // 排序
    _ = query.orderBy("sort", .asc).orderBy("create_time", .desc);

    // 分页
    const page = if (query_params.get("page")) |p| std.fmt.parseInt(u32, p, 10) catch 1 else 1;
    const page_size = if (query_params.get("page_size")) |ps| std.fmt.parseInt(u32, ps, 10) catch 10 else 10;

    var result = try query.paginate(page, page_size);
    defer result.deinit();

    // 构建响应
    var response_data = std.StringHashMap(json_mod.Value).init(self.allocator);
    defer response_data.deinit();

    try response_data.put("code", json_mod.Value{ .integer = 0 });
    try response_data.put("msg", json_mod.Value{ .string = "success" });
    try response_data.put("data", json_mod.Value{ .object = result.toJson() });

    try base.send_layui_table_response(self.allocator, response, response_data);
}

/// 获取单条记录实现
fn getImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmMaterial.find(global.get_db(), id)) |material| {
        try base.send_ok(response, material);
    } else {
        try base.send_failed(response, "素材不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const MaterialCreateDto = @import("../dto/material_create.dto.zig").MaterialCreateDto;
    const dto = json_mod.parse(MaterialCreateDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 从上下文获取用户信息
    const ctx = user_context.getContext();

    // 保存数据
    const material = try OrmMaterial.create(global.get_db(), .{
        .name = dto.name,
        .original_name = dto.original_name,
        .file_path = dto.file_path,
        .file_url = dto.file_url,
        .file_size = dto.file_size,
        .file_type = dto.file_type,
        .mime_type = dto.mime_type,
        .extension = dto.extension,
        .category_id = dto.category_id,
        .user_id = ctx.user_id,
        .user_name = if (ctx.username.len > 0) ctx.username else "unknown",
        .tags = dto.tags,
        .description = dto.description,
        .thumb_path = dto.thumb_path,
        .thumb_url = dto.thumb_url,
        .width = dto.width,
        .height = dto.height,
        .sort = dto.sort,
        .status = dto.status,
        .is_private = dto.is_private,
        .remark = dto.remark,
    });

    try base.send_ok(response, material);
}

/// 删除物理文件
fn deletePhysicalFile(file_path: []const u8) !void {
    if (file_path.len == 0) return;

    const full_path = std.fs.cwd().realpathAlloc(std.heap.page_allocator, file_path) catch {
        return error.InvalidPath;
    };
    defer std.heap.page_allocator.free(full_path);

    std.fs.cwd().deleteFile(full_path) catch {
        return error.FileNotFound;
    };
}

/// 删除实现
fn deleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    // 获取素材信息，用于删除物理文件
    var file_path: []const u8 = "";
    var thumb_path: []const u8 = "";
    if (try OrmMaterial.find(global.get_db(), id)) |material| {
        file_path = material.file_path;
        thumb_path = material.thumb_path;
    }

    // 删除物理文件
    if (file_path.len > 0) {
        deletePhysicalFile(file_path) catch |err| {
            std.debug.print("警告: 删除物理文件失败: {s}\n", .{@errorName(err)});
        };
    }
    if (thumb_path.len > 0 and !std.mem.eql(u8, thumb_path, file_path)) {
        deletePhysicalFile(thumb_path) catch |err| {
            std.debug.print("警告: 删除缩略图失败: {s}\n", .{@errorName(err)});
        };
    }

    const affected = try OrmMaterial.destroy(global.get_db(), id);
    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "删除失败");
    }
}

/// 批量删除实现
fn batchDeleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const BatchDeleteDto = struct {
        ids: []i32,
    };

    const dto = json_mod.parse(BatchDeleteDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    if (dto.ids.len == 0) {
        base.send_error(response, "请选择要删除的素材");
        return;
    }

    var affected: i32 = 0;
    for (dto.ids) |id| {
        // 获取素材信息用于删除物理文件
        var file_path: []const u8 = "";
        var thumb_path: []const u8 = "";
        if (try OrmMaterial.find(global.get_db(), id)) |material| {
            file_path = material.file_path;
            thumb_path = material.thumb_path;
        }

        // 删除物理文件
        if (file_path.len > 0) {
            deletePhysicalFile(file_path) catch {};
        }
        if (thumb_path.len > 0 and !std.mem.eql(u8, thumb_path, file_path)) {
            deletePhysicalFile(thumb_path) catch {};
        }

        const result = try OrmMaterial.destroy(global.get_db(), id);
        affected += result;
    }

    try base.send_ok(response, .{ .affected = affected });
}

/// 文件上传实现
fn uploadImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    // 解析 multipart 表单数据（简化版本）
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    // 提取文件名
    const filename = extractFilename(body) orelse {
        base.send_error(response, "无法提取文件名");
        return;
    };

    // 提取文件内容
    const file_content = extractFileContent(body) orelse {
        base.send_error(response, "无法提取文件内容");
        return;
    };

    // 生成文件路径
    const timestamp = std.time.timestamp();
    const ext = getFileExtension(filename);
    const unique_name = try std.fmt.allocPrint(self.allocator, "{d}_{s}", .{ timestamp, filename });
    defer self.allocator.free(unique_name);

    const relative_path = try std.fmt.allocPrint(self.allocator, "uploads/{d}/{s}", .{ timestamp / 86400, unique_name });
    defer self.allocator.free(relative_path);

    // 确保目录存在
    const full_dir = try std.fmt.allocPrint(self.allocator, "uploads/{d}", .{timestamp / 86400});
    defer self.allocator.free(full_dir);
    std.fs.cwd().makeDir(full_dir) catch {};

    // 保存文件
    const full_path = try std.fmt.allocPrint(self.allocator, "{s}", .{relative_path});
    defer self.allocator.free(full_path);

    std.fs.cwd().writeFile(full_path, file_content) catch {
        base.send_error(response, "保存文件失败");
        return;
    };

    // 获取用户信息
    const ctx = user_context.getContext();

    // 创建素材记录
    const material = try OrmMaterial.create(global.get_db(), .{
        .name = filename,
        .original_name = filename,
        .file_path = relative_path,
        .file_url = try std.fmt.allocPrint(self.allocator, "/{s}", .{relative_path}),
        .file_size = file_content.len,
        .file_type = getFileType(ext),
        .mime_type = getMimeType(ext),
        .extension = ext,
        .category_id = 0,
        .user_id = ctx.user_id,
        .user_name = if (ctx.username.len > 0) ctx.username else "unknown",
        .tags = "",
        .description = "",
        .thumb_path = "",
        .thumb_url = "",
        .width = 0,
        .height = 0,
        .sort = 0,
        .status = 1,
        .is_private = 0,
        .remark = "",
    });

    try base.send_ok(response, material);
}

/// 从 multipart 数据中提取文件名
fn extractFilename(body: []const u8) ?[]const u8 {
    const filename_marker = "filename=\"";
    const idx = std.mem.indexOf(u8, body, filename_marker) orelse return null;
    const start = idx + filename_marker.len;
    const end = std.mem.indexOfPos(body, start, "\"") orelse return null;
    if (end <= start) return null;
    return body[start..end];
}

/// 从 multipart 数据中提取文件内容
fn extractFileContent(body: []const u8) ?[]const u8 {
    // 查找内容开始位置（两个 CRLF 之后）
    const markers = [_][]const u8{ "\r\n\r\n", "\n\n" };
    var content_start: usize = 0;
    for (markers) |marker| {
        if (std.mem.indexOf(u8, body, marker)) |idx| {
            content_start = idx + marker.len;
            break;
        }
    }
    if (content_start >= body.len) return null;

    // 查找内容结束位置（--boundary 之前）
    const boundary_end = std.mem.lastIndexOf(u8, body, "--") orelse body.len;
    const content_end = std.mem.lastIndexOfPos(body, content_start, body[0..boundary_end], "\r\n--") orelse boundary_end;

    if (content_start >= content_end) return null;
    return body[content_start..content_end];
}

/// 获取文件扩展名
fn getFileExtension(filename: []const u8) []const u8 {
    const dot_idx = std.mem.lastIndexOf(u8, filename, ".") orelse 0;
    if (dot_idx > 0 and dot_idx < filename.len - 1) {
        return filename[dot_idx + 1 ..];
    }
    return "";
}

/// 根据扩展名获取文件类型
fn getFileType(ext: []const u8) []const u8 {
    const image_exts = [_][]const u8{ "jpg", "jpeg", "png", "gif", "webp", "svg", "bmp" };
    const video_exts = [_][]const u8{ "mp4", "avi", "mov", "mkv", "webm" };
    const audio_exts = [_][]const u8{ "mp3", "wav", "ogg", "flac", "aac" };
    const doc_exts = [_][]const u8{ "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx" };

    const lower = std.ascii.lowerString(ext, ext);

    for (image_exts) |e| {
        if (std.mem.eql(u8, lower, e)) return "image";
    }
    for (video_exts) |e| {
        if (std.mem.eql(u8, lower, e)) return "video";
    }
    for (audio_exts) |e| {
        if (std.mem.eql(u8, lower, e)) return "audio";
    }
    for (doc_exts) |e| {
        if (std.mem.eql(u8, lower, e)) return "document";
    }

    return "other";
}

/// 根据扩展名获取 MIME 类型
fn getMimeType(ext: []const u8) []const u8 {
    const mime_types = .{
        .{ "jpg", "image/jpeg" },
        .{ "jpeg", "image/jpeg" },
        .{ "png", "image/png" },
        .{ "gif", "image/gif" },
        .{ "webp", "image/webp" },
        .{ "svg", "image/svg+xml" },
        .{ "pdf", "application/pdf" },
        .{ "mp4", "video/mp4" },
        .{ "mp3", "audio/mpeg" },
        .{ "doc", "application/msword" },
        .{ "docx", "application/vnd.openxmlformats-officedocument.wordprocessingml.document" },
    };

    for (mime_types) |mt| {
        if (std.mem.eql(u8, ext, mt[0])) return mt[1];
    }

    return "application/octet-stream";
}

/// 文件下载实现
fn downloadImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmMaterial.find(global.get_db(), id)) |material| {
        if (material.is_private == 1) {
            const ctx = user_context.getContext();
            if (!ctx.is_authenticated or ctx.user_id != material.user_id) {
                try base.send_failed(response, "无权访问私有文件");
                return;
            }
        }

        const file_path = if (material.file_path.len > 0) material.file_path else material.file_url;
        if (file_path.len == 0) {
            try base.send_failed(response, "文件路径不存在");
            return;
        }

        const file = std.fs.cwd().openFile(file_path, .{}) catch {
            try base.send_failed(response, "文件不存在");
            return;
        };
        defer file.close();

        const stat = try file.stat();
        const file_size = @as(u64, @intCast(stat.size));

        response.setStatus(.ok);
        try response.setHeader("Content-Type", material.mime_type orelse "application/octet-stream");
        const filename = material.original_name orelse "download";
        const disposition = try std.fmt.allocPrint(global.get_allocator(), "attachment; filename=\"{s}\"; filename*=UTF-8''{s}", .{ filename, filename });
        defer global.get_allocator().free(disposition);
        try response.setHeader("Content-Disposition", disposition);
        try response.setHeader("Content-Length", try std.fmt.allocPrint(global.get_allocator(), "{d}", .{file_size}));
        defer global.get_allocator().free(response.headers.getFirstValue("Content-Length") orelse "");

        const buffer_size = 64 * 1024;
        const buffer = try global.get_allocator().alloc(u8, buffer_size);
        defer global.get_allocator().free(buffer);

        var total_sent: u64 = 0;
        while (total_sent < file_size) {
            const to_read = @min(buffer_size, file_size - total_sent);
            const bytes_read = try file.read(buffer[0..to_read]);
            if (bytes_read == 0) break;
            try response.sendBody(buffer[0..bytes_read]);
            total_sent += bytes_read;
        }
    } else {
        try base.send_failed(response, "素材不存在");
    }
}
