const std = @import("std");
const zap = @import("zap");

const base = @import("base.fn.zig");

const Self = @This();

const ResourceBaseDir = "resources";

allocator: std.mem.Allocator,
pub fn init(allocator: std.mem.Allocator) Self {
    return .{ .allocator = allocator };
}

pub fn upload(self: *Self, req: zap.Request) void {
    if (!std.mem.eql(u8, req.method.?, "POST")) {
        return base.send_failed(self.allocator, req, "不支持的请求方式");
    }
    if (req.body.?.len > 1024 * 1024 * 1024 * 20) return base.send_failed(self.allocator, req, "上传文件过大");

    req.parseBody() catch return base.send_failed(self.allocator, req, "数据解析错误");
    const params = req.parametersToOwnedList(self.allocator, false) catch return base.send_failed(self.allocator, req, "数据解析错误");
    defer params.deinit();
    for (params.items) |kv| {
        if (kv.value) |v| {
            switch (v) {
                zap.Request.HttpParam.Hash_Binfile => |*file| {
                    const origin_filename = file.filename orelse return base.send_failed(self.allocator, req, "文件上传失败");
                    const data = file.data orelse return base.send_failed(self.allocator, req, "文件上传失败");
                    const ext = std.fs.path.extension(origin_filename);

                    const Md5 = std.crypto.hash.Md5;
                    var out: [Md5.digest_length]u8 = undefined;
                    Md5.hash(data, &out, .{});

                    const md5 = std.fmt.allocPrint(self.allocator, "{s}", .{
                        std.fmt.fmtSliceHexLower(out[0..]),
                    }) catch return base.send_failed(self.allocator, req, "获取文件错误");
                    defer self.allocator.free(md5);

                    // 文件目录分段
                    const dir = std.fmt.allocPrint(self.allocator, "uploads/{s}/{s}", .{
                        md5[0..3],
                        md5[3..6],
                    }) catch return base.send_failed(self.allocator, req, "获取文件错误");
                    defer self.allocator.free(dir);
                    var path: [1024]u8 = undefined;
                    std.fs.cwd().makePath(std.fmt.bufPrint(path[0..], "{s}/{s}", .{
                        ResourceBaseDir[0..],
                        dir,
                    }) catch return base.send_failed(
                        self.allocator,
                        req,
                        "创建上传目录失败",
                    )) catch return base.send_failed(self.allocator, req, "创建上传目录失败");

                    // 创建目录
                    const sd = &[_][]const u8{ ResourceBaseDir[0..], "/", dir };
                    const savedir = std.mem.concat(self.allocator, u8, sd) catch return base.send_failed(self.allocator, req, "构建地址错误");
                    defer self.allocator.free(savedir);

                    // 生成相对目录
                    const fd = &[_][]const u8{ savedir, "/", md5, ext };
                    const filename = std.mem.concat(self.allocator, u8, fd) catch return base.send_failed(self.allocator, req, "上传失败");
                    defer self.allocator.free(filename);

                    var cache = true;
                    const url = std.mem.concat(
                        self.allocator,
                        u8,
                        &[_][]const u8{ "https://dev.xiusin.cn/", filename[ResourceBaseDir.len..] },
                    ) catch return base.send_failed(self.allocator, req, "生成对象地址错误:URL");
                    defer self.allocator.free(url);

                    // 判断文件是否存在, statFile 必须是绝对路径
                    _ = std.fs.cwd().statFile(filename) catch |err| {
                        std.log.debug("{any}", .{err});
                        std.fs.cwd().makePath(savedir) catch return base.send_failed(self.allocator, req, "创建上传目录失败");
                        std.fs.cwd().writeFile(.{
                            .sub_path = filename,
                            .data = data,
                            .flags = .{},
                        }) catch |e| return base.send_error(req, e);
                        cache = false;
                    };

                    return base.send_ok(self.allocator, req, .{
                        .path = filename,
                        .url = url,
                        .filename = origin_filename,
                        .cache = cache,
                    });
                },
                else => {
                    return base.send_failed(self.allocator, req, "不支持的上传类型");
                },
            }
        }
    }
}
