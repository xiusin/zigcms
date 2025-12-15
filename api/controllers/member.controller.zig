//! 会员管理控制器
//!
//! 提供会员的 CRUD 操作及会员信息管理

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

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,

/// ORM 模型定义
const OrmMember = sql.defineWithConfig(models.Member, .{
    .table_name = "zigcms.member",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmMember.hasDb()) {
        OrmMember.use(global.get_db());
    }
    return .{ .allocator = allocator };
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

/// 调整积分
pub const adjust_points = MW.requireAuth(adjustPointsImpl);

/// 调整等级
pub const adjust_level = MW.requireAuth(adjustLevelImpl);

/// 启用/禁用
pub const toggle_status = MW.requireAuth(toggleStatusImpl);

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
    var query = OrmMember.query(global.get_db());
    defer query.deinit();

    // 分组筛选
    if (query_params.get("group_id")) |group_id_str| {
        if (std.fmt.parseInt(i32, group_id_str, 10)) |group_id| {
            _ = query.where("group_id", "=", group_id);
        } else |_| {}
    }

    // 状态筛选
    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            _ = query.where("status", "=", status);
        } else |_| {}
    }

    // 等级筛选
    if (query_params.get("level")) |level_str| {
        if (std.fmt.parseInt(i32, level_str, 10)) |level| {
            _ = query.where("level", "=", level);
        } else |_| {}
    }

    // 关键词搜索
    if (query_params.get("keyword")) |keyword| {
        if (keyword.len > 0) {
            _ = query.whereRaw("username LIKE ? OR nickname LIKE ? OR email LIKE ? OR mobile LIKE ?", .{ "%" ++ keyword ++ "%", "%" ++ keyword ++ "%", "%" ++ keyword ++ "%", "%" ++ keyword ++ "%" });
        }
    }

    // 注册时间筛选
    if (query_params.get("start_date")) |start_date| {
        if (start_date.len > 0) {
            const start_time = std.fmt.parseInt(i64, start_date ++ "000000", 10) catch 0;
            _ = query.where("register_time", ">=", start_time);
        }
    }

    if (query_params.get("end_date")) |end_date| {
        if (end_date.len > 0) {
            const end_time = std.fmt.parseInt(i64, end_date ++ "235959", 10) catch 0;
            _ = query.where("register_time", "<=", end_time);
        }
    }

    // 排序
    _ = query.orderBy("create_time", .desc);

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
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmMember.find(global.get_db(), id)) |member| {
        try base.send_ok(response, member);
    } else {
        try base.send_failed(response, "会员不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const MemberCreateDto = @import("../dto/member_create.dto.zig").MemberCreateDto;
    const dto = json_mod.parse(MemberCreateDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 验证用户名唯一性
    if (dto.username.len > 0) {
        var query = OrmMember.query(global.get_db());
        defer query.deinit();

        _ = query.where("username", "=", dto.username);

        // 如果是更新，排除自身
        if (r.pathParameters().get("id")) |id_str| {
            if (std.fmt.parseInt(i32, id_str, 10)) |existing_id| {
                _ = query.where("id", "!=", existing_id);
            } else |_| {}
        }

        const exists = try query.exists();
        if (exists) {
            try base.send_error(response, "用户名已存在");
            return;
        }
    }

    // 验证邮箱唯一性
    if (dto.email.len > 0) {
        var query = OrmMember.query(global.get_db());
        defer query.deinit();

        _ = query.where("email", "=", dto.email);

        // 如果是更新，排除自身
        if (r.pathParameters().get("id")) |id_str| {
            if (std.fmt.parseInt(i32, id_str, 10)) |existing_id| {
                _ = query.where("id", "!=", existing_id);
            } else |_| {}
        }

        const exists = try query.exists();
        if (exists) {
            try base.send_error(response, "邮箱已被注册");
            return;
        }
    }

    // 验证手机号唯一性
    if (dto.mobile.len > 0) {
        var query = OrmMember.query(global.get_db());
        defer query.deinit();

        _ = query.where("mobile", "=", dto.mobile);

        // 如果是更新，排除自身
        if (r.pathParameters().get("id")) |id_str| {
            if (std.fmt.parseInt(i32, id_str, 10)) |existing_id| {
                _ = query.where("id", "!=", existing_id);
            } else |_| {}
        }

        const exists = try query.exists();
        if (exists) {
            try base.send_error(response, "手机号已被注册");
            return;
        }
    }

    const current_time = std.time.timestamp() * 1000;

    // 保存数据
    const member = try OrmMember.create(global.get_db(), .{
        .username = dto.username,
        .email = dto.email,
        .mobile = dto.mobile,
        .nickname = dto.nickname,
        .avatar = dto.avatar,
        .gender = dto.gender,
        .birthday = dto.birthday,
        .location = dto.location,
        .signature = dto.signature,
        .group_id = dto.group_id,
        .points = dto.points,
        .experience = dto.experience,
        .level = dto.level,
        .total_consume = dto.total_consume,
        .status = dto.status,
        .email_verified = dto.email_verified,
        .mobile_verified = dto.mobile_verified,
        .register_time = current_time,
        .register_ip = "", // TODO: 获取客户端IP
        .remark = dto.remark,
    });

    try base.send_ok(response, member);
}

/// 删除实现
fn deleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    const affected = try OrmMember.destroy(global.get_db(), id);
    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "删除失败");
    }
}

/// 批量删除实现
fn batchDeleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const BatchDeleteDto = struct {
        ids: []i32,
    };

    const dto = json_mod.parse(BatchDeleteDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    if (dto.ids.len == 0) {
        try base.send_error(response, "请选择要删除的会员");
        return;
    }

    var affected: i32 = 0;
    for (dto.ids) |id| {
        const result = try OrmMember.destroy(global.get_db(), id);
        affected += result;
    }

    try base.send_ok(response, .{ .affected = affected });
}

/// 调整积分实现
fn adjustPointsImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const AdjustPointsDto = struct {
        id: i32,
        points: i32,
        remark: []const u8 = "",
    };

    const dto = json_mod.parse(AdjustPointsDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    const affected = try OrmMember.increment(global.get_db(), dto.id, "points", dto.points);
    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "调整积分失败");
    }
}

/// 调整等级实现
fn adjustLevelImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const AdjustLevelDto = struct {
        id: i32,
        level: i32,
        remark: []const u8 = "",
    };

    const dto = json_mod.parse(AdjustLevelDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    const affected = try OrmMember.update(global.get_db(), dto.id, .{
        .level = dto.level,
        .remark = dto.remark,
    });

    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "调整等级失败");
    }
}

/// 启用/禁用实现
fn toggleStatusImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    // 获取当前状态
    if (try OrmMember.find(global.get_db(), id)) |member| {
        const new_status = if (member.status == 1) i32(0) else i32(1);

        const affected = try OrmMember.update(global.get_db(), id, .{
            .status = new_status,
        });

        if (affected > 0) {
            try base.send_ok(response, .{ .affected = affected, .status = new_status });
        } else {
            try base.send_failed(response, "操作失败");
        }
    } else {
        try base.send_failed(response, "会员不存在");
    }
}
