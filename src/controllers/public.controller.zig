const std = @import("std");
const zap = @import("zap");

const base = @import("base.fn.zig");

pub const Public = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    pub fn init(allocator: std.mem.Allocator) Self {
        return .{ .allocator = allocator };
    }

    pub fn upload(self: *Self, req: zap.Request) void {
        req.parseBody() catch return base.send_failed(self.allocator, req, "数据解析错误");

        const params = req.parametersToOwnedList(self.allocator, false) catch return base.send_failed(self.allocator, req, "数据解析错误");
        defer params.deinit();
        for (params.items) |kv| {
            if (kv.value) |v| {
                switch (v) {
                    zap.Request.HttpParam.Hash_Binfile => |*file| {
                        // 验证文件md5
                        const filename = file.filename orelse return base.send_failed(self.allocator, req, "文件上传失败");
                        const data = file.data orelse return base.send_failed(self.allocator, req, "文件上传失败");

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

                        const savedir = std.mem.concat(self.allocator, u8, &[_][]const u8{
                            "resources",
                            "/",
                            dir,
                        }) catch return base.send_failed(self.allocator, req, "构建地址错误");
                        defer self.allocator.free(savedir);

                        const sub_path = std.mem.concat(self.allocator, u8, &[_][]const u8{
                            savedir,
                            "/",
                            filename,
                        }) catch return base.send_failed(self.allocator, req, "构建地址错误");
                        defer self.allocator.free(sub_path);

                        std.fs.cwd().makePath(savedir) catch return base.send_failed(self.allocator, req, "创建上传目录失败");
                        std.fs.cwd().writeFile(.{
                            .sub_path = sub_path,
                            .data = data,
                            .flags = .{},
                        }) catch |e| return base.send_error(self.allocator, req, e);

                        return base.send_ok(self.allocator, req, .{
                            .path = sub_path,
                        });
                    },
                    else => {
                        return base.send_failed(self.allocator, req, "不支持的上传类型");
                    },
                }
            }
        }
    }
};
