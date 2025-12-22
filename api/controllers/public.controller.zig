//! 公共控制器 (Public Controller)
//!
//! 处理公共资源请求，包括文件上传、文件夹管理和文件列表。
//!
//! ## 功能
//! - 文件上传：支持多种文件类型，自动计算 MD5 去重
//! - 文件夹管理：创建和管理上传目录
//! - 文件列表：浏览上传目录中的文件
//!
//! ## 使用示例
//! ```zig
//! const PublicController = @import("api/controllers/public.controller.zig");
//! var ctrl = PublicController.init(allocator, logger);
//!
//! router.post("/api/upload", &ctrl, ctrl.upload);
//! router.get("/api/files", &ctrl, ctrl.files);
//! ```

const std = @import("std");
const log_mod = @import("../../application/services/logger/logger.zig");
const zap = @import("zap");
const Allocator = std.mem.Allocator;
const base = @import("base.fn.zig");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const global = @import("../../shared/primitives/global.zig");
const strings = @import("../../shared/utils/strings.zig");

const Self = @This();

allocator: Allocator,
logger: *log_mod.Logger,
pub fn init(allocator: Allocator, logger: *log_mod.Logger) Self {
    return .{ .allocator = allocator, .logger = logger };
}

pub fn upload(self: *Self, req: zap.Request) !void {
    if (!std.mem.eql(u8, req.method.?, "POST")) {
        return base.send_failed(req, "不支持的请求方式");
    }

    // global.get_setting("max_upload_file_size", "2");

    if (req.body.?.len > 1024 * 1024 * 1024 * 20) return base.send_failed(req, "上传文件过大");

    req.parseBody() catch return;
    var params = req.parametersToOwnedList(self.allocator) catch return;
    defer params.deinit();

    // TODO 读取path

    for (params.items) |kv| {
        if (kv.value) |v| {
            switch (v) {
                zap.Request.HttpParam.Hash_Binfile => |*file| {
                    const origin_filename = file.filename orelse return;
                    const data = file.data orelse return;
                    const ext = std.fs.path.extension(origin_filename);

                    const md5 = strings.md5(self.allocator, data) catch return;
                    defer self.allocator.free(md5);

                    // 文件目录分段
                    const dir = strings.sprinf("uploads/{s}/{s}", .{ md5[0..3], md5[3..6] }) catch |e| return base.send_error(req, e);

                    const basedir = self.upload_base_dir();

                    var path: [1024]u8 = undefined;
                    std.fs.cwd().makePath(std.fmt.bufPrint(path[0..], "{s}/{s}", .{
                        basedir,
                        dir,
                    }) catch return base.send_failed(req, "创建上传目录失败")) catch return;

                    // 创建目录
                    const savedir = strings.sprinf("{s}/{s}", .{ basedir, dir }) catch |e| return base.send_error(req, e);
                    const filename = strings.sprinf("{s}/{s}{s}", .{ savedir, md5, ext }) catch |e| return base.send_error(req, e);

                    var cache = true;
                    const url = filename[basedir.len..];

                    // 判断文件是否存在
                    _ = std.fs.cwd().statFile(filename) catch {
                        std.fs.cwd().makePath(savedir) catch return base.send_failed(req, "创建上传目录失败");
                        std.fs.cwd().writeFile(.{
                            .sub_path = filename,
                            .data = data,
                            .flags = .{},
                        }) catch |e| return base.send_error(req, e);
                        cache = false;
                    };

                    // 使用 ORM 创建上传记录
                    const Upload = orm_models.Upload;
                    const now = std.time.milliTimestamp();

                    _ = Upload.Create(.{
                        .original_name = origin_filename,
                        .path = filename,
                        .md5 = md5,
                        .ext = ext,
                        .size = 0,
                        .upload_type = 0,
                        .url = url,
                        .create_time = now,
                        .update_time = now,
                        .is_delete = 0,
                    }) catch |e| return base.send_error(req, e);

                    return base.send_ok(req, .{
                        .path = filename,
                        .url = url,
                        .filename = origin_filename,
                        .cache = cache,
                    });
                },
                else => {
                    return base.send_failed(req, "不支持的上传类型");
                },
            }
        }
    }
}

pub fn folder(self: *Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);
    if (req.body == null) return;
    var params = req.parametersToOwnedStrList(self.allocator) catch return;
    defer params.deinit();

    var fold: ?[]const u8 = null;
    var request_path: ?[]const u8 = null;

    for (params.items) |item| {
        if (strings.eql("folder", item.key)) {
            fold = item.value;
        } else if (strings.eql("path", item.key)) {
            request_path = item.value;
        }
    }

    if (fold == null or request_path == null) {
        return base.send_failed(req, "缺少必要参数");
    }

    const basepath = self.upload_base_dir();
    const path = strings.sprinf("{s}/{s}", .{ basepath, request_path.? }) catch return;

    if (strings.contains(path, "..") or
        strings.contains(fold.?, "..") or
        strings.contains(path, " ") or
        strings.contains(fold.?, " ") or
        strings.contains(fold.?, "\\") or
        strings.contains(path, "\\") or
        fold.?.len == 0)
    {
        return base.send_failed(req, "非法参数");
    }
    const dir = strings.rtrim(strings.sprinf("{s}/{s}/", .{ path, fold.? }) catch return, "/");
    std.fs.cwd().makePath(dir) catch {};
    self.logger.debug("path: {s}", .{path});
    return base.send_ok(req, .{});
}

pub fn files(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return;
    req.parseQuery();

    var path: []const u8 = "";

    var params = req.parametersToOwnedStrList(self.allocator) catch return;
    defer params.deinit();

    for (params.items) |item| {
        if (strings.eql("path", item.key)) {
            path = item.value;
        }
    }

    const basepath = self.upload_base_dir();
    const FileItem = struct { type: []const u8 = "", thumb: []const u8 = "", name: []const u8, path: []const u8 = "" };

    var items = std.ArrayListUnmanaged(FileItem){};
    defer {
        for (items.items) |item| {
            self.allocator.free(item.path);
            self.allocator.free(item.thumb);
        }
        items.deinit(self.allocator);
    }

    const dir = strings.rtrim(strings.sprinf("{s}/{s}", .{ basepath, path }) catch return, "/\\");
    self.logger.debug("dir = {s}", .{dir});
    var opened_dir = std.fs.cwd().openDir(dir, .{}) catch |e| return base.send_error(req, e);
    defer opened_dir.close(); // 确保关闭目录句柄
    var iter = opened_dir.iterate();
    while (iter.next() catch return) |it| {
        var item: FileItem = .{ .name = it.name };
        if (it.kind == .directory) {
            item.type = "directory";
        } else {
            item.type = strings.ltrim(std.fs.path.extension(it.name), ".");
        }
        if (path.len == 0) {
            item.path = self.allocator.dupe(u8, it.name) catch |e| return base.send_error(req, e);
                                } else {
                                    const full_path = try std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ path, it.name });
                                    defer self.allocator.free(full_path);
                                    item.path = self.allocator.dupe(u8, full_path) catch |e| return base.send_error(req, e);
                                }
                                const thumb_path = try std.fmt.allocPrint(self.allocator, "ico/{s}.png", .{item.type});
                                defer self.allocator.free(thumb_path);
                                item.thumb = self.allocator.dupe(u8, thumb_path) catch |e| return base.send_error(req, e);
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, .{ .count = items.items.len, .images = items.items });
}

fn upload_base_dir(_: *Self) []const u8 {
    return global.get_setting("resources", "resources");
}
