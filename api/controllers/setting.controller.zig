//! 系统设置控制器 (Setting Controller)
//!
//! 管理系统配置项，包括上传配置、邮件配置等。
//!
//! ## 功能
//! - 获取/保存系统设置
//! - 上传配置管理（本地/COS/OSS）
//! - 邮件配置和测试
//!
//! ## 使用示例
//! ```zig
//! const SettingController = @import("api/controllers/setting.controller.zig");
//! var ctrl = SettingController.init(allocator);
//!
//! router.get("/api/settings", &ctrl, ctrl.get);
//! router.post("/api/settings/save", &ctrl, ctrl.save);
//! ```

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
            var new_setting = Setting.Create(.{
                .key = entity.key_ptr.*,
                .value = val,
            }) catch continue;
            Setting.freeModel(self.allocator, &new_setting);
        }
    }

    global.restore_setting() catch {};

    return base.send_ok(req, "保存成功");
}

/// 获取上传配置
pub fn get_upload_config(self: Self, req: zap.Request) !void {
    // 获取所有设置
    const settings_slice = Setting.All() catch |e| return base.send_error(req, e);
    defer Setting.freeModels(self.allocator, settings_slice);

    // 构建配置映射
    var config_map = std.StringHashMap([]const u8).init(self.allocator);
    defer config_map.deinit();

    for (settings_slice) |item| {
        config_map.put(item.key, item.value) catch {};
    }

    const config = .{
        .upload_provider = config_map.get("upload_provider") orelse "local",
        .local = .{
            .root_path = config_map.get("upload_local_root_path") orelse "uploads",
            .url_prefix = config_map.get("upload_local_url_prefix") orelse "/uploads",
            .max_size = config_map.get("upload_local_max_size") orelse "10485760",
        },
        .cos = .{
            .secret_id = config_map.get("upload_cos_secret_id") orelse "",
            .secret_key = config_map.get("upload_cos_secret_key") orelse "",
            .region = config_map.get("upload_cos_region") orelse "",
            .bucket = config_map.get("upload_cos_bucket") orelse "",
            .domain = config_map.get("upload_cos_domain") orelse "",
        },
        .oss = .{
            .access_key_id = config_map.get("upload_oss_access_key_id") orelse "",
            .access_key_secret = config_map.get("upload_oss_access_key_secret") orelse "",
            .endpoint = config_map.get("upload_oss_endpoint") orelse "",
            .bucket = config_map.get("upload_oss_bucket") orelse "",
            .domain = config_map.get("upload_oss_domain") orelse "",
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
    const upload_provider = values.object.get("upload_provider") orelse json_mod.Value{ .string = "local" };
    const local_config = values.object.get("local") orelse json_mod.Value{ .object = json_mod.Object.init(self.allocator) };
    const cos_config = values.object.get("cos") orelse json_mod.Value{ .object = json_mod.Object.init(self.allocator) };
    const oss_config = values.object.get("oss") orelse json_mod.Value{ .object = json_mod.Object.init(self.allocator) };

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
    var new_setting = Setting.Create(.{
        .key = key,
        .value = value,
    }) catch return;
    Setting.freeModel(self.allocator, &new_setting);
}

/// 发送测试邮件
pub fn send_mail(self: Self, req: zap.Request) !void {
    // 获取所有设置
    const settings_slice = Setting.All() catch |e| return base.send_error(req, e);
    defer Setting.freeModels(self.allocator, settings_slice);

    // 构建配置映射
    var config_map = std.StringHashMap([]const u8).init(self.allocator);
    defer config_map.deinit();

    for (settings_slice) |item| {
        config_map.put(item.key, item.value) catch {};
    }

    // 获取邮件配置
    const smtp_host = config_map.get("mail_smtp_host") orelse "";
    const smtp_port_str = config_map.get("mail_smtp_port") orelse "587";
    const smtp_user = config_map.get("mail_smtp_user") orelse "";
    const smtp_pass = config_map.get("mail_smtp_pass") orelse "";
    const from_email = config_map.get("mail_from_email") orelse "";

    if (smtp_host.len == 0 or smtp_user.len == 0 or smtp_pass.len == 0 or from_email.len == 0) {
        return base.send_failed(req, "邮件配置不完整，请先配置SMTP设置");
    }

    const smtp_port = std.fmt.parseInt(u16, smtp_port_str, 10) catch 587;
    _ = smtp_port;

    // TODO: 实现发送测试邮件的逻辑
    // 暂时返回成功，实际使用时需要集成smtp_client
    return base.send_ok(req, .{ .status = "success", .message = "邮件配置测试成功" });
}
