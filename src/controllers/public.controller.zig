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

    // global.get_setting("max_upload_file_size", "2");

    if (req.body.?.len > 1024 * 1024 * 1024 * 20) return base.send_failed(req, "上传文件过大");

    req.parseBody() catch return;
    const params = req.parametersToOwnedList(self.allocator, false) catch return;
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
    std.log.debug("path: {s}", .{path});
    return base.send_ok(req, .{});
}

pub fn files(self: *Self, req: zap.Request) void {
    req.parseBody() catch return;
    req.parseQuery();

    var path: []const u8 = "";

    var params = req.parametersToOwnedStrList(self.allocator, true) catch return;
    defer params.deinit();

    for (params.items) |item| {
        if (strings.eql("path", item.key.str)) {
            path = item.value.str;
        }
    }

    const basepath = self.upload_base_dir();
    const FileItem = struct { type: []const u8 = "", thumb: []const u8 = "", name: []const u8, path: []const u8 = "" };

    var items = std.ArrayList(FileItem).init(self.allocator);
    defer {
        for (items.items) |item| {
            self.allocator.free(item.path);
            self.allocator.free(item.thumb);
        }
        items.deinit();
    }

    const dir = strings.rtrim(strings.sprinf("{s}/{s}", .{ basepath, path }) catch return, "/\\");
    std.log.debug("dir = {s}", .{dir});
    var iter = (std.fs.cwd().openDir(dir, .{}) catch |e| return base.send_error(req, e)).iterate();
    while (iter.next() catch return) |it| {
        var item: FileItem = .{ .name = it.name };
        if (it.kind == .directory) {
            item.type = "directory";
        } else {
            item.type = strings.ltrim(std.fs.path.extension(it.name), ".");
        }
        if (path.len == 0) {
            item.path = std.fmt.allocPrint(self.allocator, "{s}", .{it.name}) catch |e| return base.send_error(req, e);
        } else {
            item.path = std.fmt.allocPrint(self.allocator, "{s}/{s}", .{ path, it.name }) catch |e| return base.send_error(req, e);
        }
        item.thumb = std.fmt.allocPrint(self.allocator, "ico/{s}.png", .{item.type}) catch |e| return base.send_error(req, e);

        items.append(item) catch {};
    }

    base.send_ok(req, .{ .count = items.items.len, .images = items.items });
}

fn upload_base_dir(_: *Self) []const u8 {
    return global.get_setting("resources", "resources");
}
