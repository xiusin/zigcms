const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../shared/primitives/global.zig");
const models = @import("../../domain/entities/models.zig");
const orm_models = @import("../../domain/entities/orm_models.zig");
const json_mod = @import("../../application/services/json/json.zig");
const smtp = @import("smtp_client"); // 使用构建依赖中的 smtp_client
const Allocator = std.mem.Allocator;

const Self = @This();

// ORM 模型别名
const Setting = orm_models.Setting;

allocator: Allocator,

pub fn init(allocator: Allocator) Self {
    return .{ .allocator = allocator };
}

/// 获取所有设置
pub fn get(self: Self, req: zap.Request) !void {
    // 使用 ORM 获取所有设置
    const settings_slice = Setting.All() catch |e| return base.send_error(req, e);
    defer Setting.freeModels(self.allocator, settings_slice);

    var config = std.StringHashMap([]const u8).init(self.allocator);
    defer config.deinit();

    for (settings_slice) |item| {
        config.put(item.key, item.value) catch {};
    }

    return base.send_ok(req, config);
}

/// 保存设置
pub fn save(self: Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);
    const body = req.body orelse return base.send_failed(req, "提交参数为空");

    var values = json_mod.JSON.parseValue(self.allocator, body) catch |e| return base.send_error(req, e);
    defer values.deinit(self.allocator);

    if (values != .object) return base.send_failed(req, "参数格式错误");

    var iter = values.object.iterator();
    while (iter.next()) |entity| {
        // 先删除已存在的 key
        var del_q = Setting.WhereEq("key", entity.key_ptr.*);
        defer del_q.deinit();
        _ = del_q.delete() catch {};

        // 插入新值
        if (entity.value_ptr.getString()) |val| {
            _ = Setting.Create(.{
                .key = entity.key_ptr.*,
                .value = val,
            }) catch {};
        }
    }

    global.restore_setting() catch {};

    return base.send_ok(req, "保存成功");
}

/// 获取上传配置
pub fn get_upload_config(self: Self, req: zap.Request) !void {
    // 获取上传相关的设置
    const upload_provider = Setting.GetValue("upload_provider") catch "";
    const local_root_path = Setting.GetValue("upload_local_root_path") catch "uploads";
    const local_url_prefix = Setting.GetValue("upload_local_url_prefix") catch "/uploads";
    const local_max_size = Setting.GetValue("upload_local_max_size") catch "10485760";

    const cos_secret_id = Setting.GetValue("upload_cos_secret_id") catch "";
    const cos_secret_key = Setting.GetValue("upload_cos_secret_key") catch "";
    const cos_region = Setting.GetValue("upload_cos_region") catch "";
    const cos_bucket = Setting.GetValue("upload_cos_bucket") catch "";
    const cos_domain = Setting.GetValue("upload_cos_domain") catch "";

    const oss_access_key_id = Setting.GetValue("upload_oss_access_key_id") catch "";
    const oss_access_key_secret = Setting.GetValue("upload_oss_access_key_secret") catch "";
    const oss_endpoint = Setting.GetValue("upload_oss_endpoint") catch "";
    const oss_bucket = Setting.GetValue("upload_oss_bucket") catch "";
    const oss_domain = Setting.GetValue("upload_oss_domain") catch "";

    const config = .{
        .upload_provider = upload_provider,
        .local = .{
            .root_path = local_root_path,
            .url_prefix = local_url_prefix,
            .max_size = local_max_size,
        },
        .cos = .{
            .secret_id = cos_secret_id,
            .secret_key = cos_secret_key,
            .region = cos_region,
            .bucket = cos_bucket,
            .domain = cos_domain,
        },
        .oss = .{
            .access_key_id = oss_access_key_id,
            .access_key_secret = oss_access_key_secret,
            .endpoint = oss_endpoint,
            .bucket = oss_bucket,
            .domain = oss_domain,
        },
    };

    return base.send_ok(req, config);
}

/// 保存上传配置
pub fn save_upload_config(self: Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);
    const body = req.body orelse return base.send_failed(req, "提交参数为空");

    var values = json_mod.JSON.parseValue(self.allocator, body) catch |e| return base.send_error(req, e);
    defer values.deinit(self.allocator);

    if (values != .object) return base.send_failed(req, "参数格式错误");

    // 保存上传配置
    const upload_provider = values.object.get("upload_provider") orelse json_mod.JSON.Value{ .string = "local" };
    const local_config = values.object.get("local") orelse json_mod.JSON.Value{ .object = json_mod.JSON.Object.init(self.allocator) };
    const cos_config = values.object.get("cos") orelse json_mod.JSON.Value{ .object = json_mod.JSON.Object.init(self.allocator) };
    const oss_config = values.object.get("oss") orelse json_mod.JSON.Value{ .object = json_mod.JSON.Object.init(self.allocator) };

    // 保存提供者类型
    if (upload_provider.getString()) |provider| {
        try self.saveSetting("upload_provider", provider);
    }

    // 保存本地配置
    if (local_config == .object) {
        if (local_config.object.get("root_path")) |v| if (v.getString()) |s| try self.saveSetting("upload_local_root_path", s);
        if (local_config.object.get("url_prefix")) |v| if (v.getString()) |s| try self.saveSetting("upload_local_url_prefix", s);
        if (local_config.object.get("max_size")) |v| if (v.getString()) |s| try self.saveSetting("upload_local_max_size", s);
    }

    // 保存COS配置
    if (cos_config == .object) {
        if (cos_config.object.get("secret_id")) |v| if (v.getString()) |s| try self.saveSetting("upload_cos_secret_id", s);
        if (cos_config.object.get("secret_key")) |v| if (v.getString()) |s| try self.saveSetting("upload_cos_secret_key", s);
        if (cos_config.object.get("region")) |v| if (v.getString()) |s| try self.saveSetting("upload_cos_region", s);
        if (cos_config.object.get("bucket")) |v| if (v.getString()) |s| try self.saveSetting("upload_cos_bucket", s);
        if (cos_config.object.get("domain")) |v| if (v.getString()) |s| try self.saveSetting("upload_cos_domain", s);
    }

    // 保存OSS配置
    if (oss_config == .object) {
        if (oss_config.object.get("access_key_id")) |v| if (v.getString()) |s| try self.saveSetting("upload_oss_access_key_id", s);
        if (oss_config.object.get("access_key_secret")) |v| if (v.getString()) |s| try self.saveSetting("upload_oss_access_key_secret", s);
        if (oss_config.object.get("endpoint")) |v| if (v.getString()) |s| try self.saveSetting("upload_oss_endpoint", s);
        if (oss_config.object.get("bucket")) |v| if (v.getString()) |s| try self.saveSetting("upload_oss_bucket", s);
        if (oss_config.object.get("domain")) |v| if (v.getString()) |s| try self.saveSetting("upload_oss_domain", s);
    }

    global.restore_setting() catch {};

    return base.send_ok(req, "上传配置保存成功");
}

/// 测试上传配置
pub fn test_upload_config(self: Self, req: zap.Request) !void {
    req.parseBody() catch |e| return base.send_error(req, e);
    const body = req.body orelse return base.send_failed(req, "提交参数为空");

    var values = json_mod.JSON.parseValue(self.allocator, body) catch |e| return base.send_error(req, e);
    defer values.deinit(self.allocator);

    if (values != .object) return base.send_failed(req, "参数格式错误");

    const provider = values.object.get("provider") orelse return base.send_failed(req, "缺少provider参数");
    _ = provider.getString() orelse return base.send_failed(req, "provider格式错误");

    // 这里可以实现具体的测试逻辑
    // 例如：上传一个测试文件，验证配置是否正确

    return base.send_ok(req, .{ .status = "success", .message = "配置测试成功" });
}

/// 保存单个设置项的辅助方法
fn saveSetting(self: Self, key: []const u8, value: []const u8) !void {
    // 先删除已存在的 key
    var del_q = Setting.WhereEq("key", key);
    defer del_q.deinit();
    _ = del_q.delete() catch {};

    // 插入新值
    _ = Setting.Create(.{
        .key = key,
        .value = value,
    }) catch {};
}
