const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;
const base = @import("base.fn.zig");
const models = @import("../models/models.zig");
const global = @import("../global/global.zig");
const strings = @import("../modules/strings.zig");

const Self = @This();

allocator: Allocator,
pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn upload(self: *Self, req: zap.Request) void {
    if (!std.mem.eql(u8, req.method.?, "POST")) {
        return base.send_failed(req, "不支持的请求方式");
    }
    if (req.body.?.len > 1024 * 1024 * 1024 * 20) return base.send_failed(req, "上传文件过大");

    req.parseBody() catch return base.send_failed(req, "数据解析错误");
    const params = req.parametersToOwnedList(self.allocator, false) catch return base.send_failed(req, "数据解析错误");
    defer params.deinit();
    for (params.items) |kv| {
        if (kv.value) |v| {
            switch (v) {
                zap.Request.HttpParam.Hash_Binfile => |*file| {
                    const origin_filename = file.filename orelse return base.send_failed(req, "文件上传失败");
                    const data = file.data orelse return base.send_failed(req, "文件上传失败");
                    const ext = std.fs.path.extension(origin_filename);

                    const md5 = strings.md5(self.allocator, data) catch return;
                    defer self.allocator.free(md5);

                    // 文件目录分段
                    const dir = std.fmt.allocPrint(self.allocator, "uploads/{s}/{s}", .{
                        md5[0..3],
                        md5[3..6],
                    }) catch return base.send_failed(req, "获取文件错误");
                    defer self.allocator.free(dir);
                    var path: [1024]u8 = undefined;

                    const resources = global.get_setting("resources", "resources");

                    std.fs.cwd().makePath(std.fmt.bufPrint(path[0..], "{s}/{s}", .{
                        resources,
                        dir,
                    }) catch
                        return base.send_failed(req, "创建上传目录失败")) catch return;

                    // 创建目录
                    const sd = &[_][]const u8{ resources, "/", dir };
                    const savedir = std.mem.concat(self.allocator, u8, sd) catch return base.send_failed(req, "构建地址错误");
                    defer self.allocator.free(savedir);

                    const fd = &[_][]const u8{ savedir, "/", md5, ext };
                    const filename = std.mem.concat(self.allocator, u8, fd) catch return base.send_failed(req, "上传失败");
                    defer self.allocator.free(filename);

                    var cache = true;
                    const url = filename[resources.len..];

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

                    const sql = base.build_insert_sql(models.Upload, self.allocator) catch return;
                    defer self.allocator.free(sql);

                    const dto = .{ origin_filename, filename, md5, ext, 0, 0, url, std.time.milliTimestamp(), std.time.milliTimestamp(), 0 };
                    _ = global.get_pg_pool().exec(sql, dto) catch |e| return base.send_error(req, e);

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

pub fn folder(self: *Self, req: zap.Request) void {
    req.parseBody() catch |e| return base.send_error(req, e);
    if (req.body == null) return;
    var params = req.parametersToOwnedStrList(self.allocator, true) catch return;
    defer params.deinit();

    var fold: ?[]const u8 = null;
    var request_path: ?[]const u8 = null;

    for (params.items) |item| {
        if (strings.eql("folder", item.key.str)) {
            fold = item.value.str;
        } else if (strings.eql("path", item.key.str)) {
            request_path = item.value.str;
        }
    }

    if (fold == null or request_path == null) {
        return base.send_failed(req, "缺少必要参数");
    }

    const basepath = global.get_setting("resources", "resources"); // 配置目录
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
    std.log.debug("path: {s}", .{path});
    return base.send_ok(req, .{});
}

pub fn files(self: *Self, req: zap.Request) void {
    const basepath = global.get_setting("resources", "resources"); // 配置目录

    var directories = std.ArrayList([]const u8).init(self.allocator);
    defer directories.deinit();

    var file_items = std.ArrayList([]const u8).init(self.allocator);
    defer file_items.deinit();

    const dir = std.fs.cwd().openDir(basepath, .{}) catch return base.send_failed(req, "权限不足");
    var iter = dir.iterate();
    while (iter.next() catch return) |it| {
        if (it.kind == .directory) {
            directories.append(it.name) catch {};
        } else {
            file_items.append(it.name) catch {};
        }
    }
    directories.appendSlice(file_items.items) catch {};

    base.send_ok(req, .{
        .count = directories.items.len,
        .images = directories.items,
    });
}
