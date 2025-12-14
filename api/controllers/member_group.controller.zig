//! 会员分组管理控制器
//!
//! 提供会员分组的 CRUD 操作及权限管理

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
const OrmMemberGroup = sql.defineWithConfig(models.MemberGroup, .{
    .table_name = "zigcms.member_group",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmMemberGroup.hasDb()) {
        OrmMemberGroup.use(global.get_db());
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

/// 获取分组选项（用于下拉框）
pub const select = MW.requireAuth(selectImpl);

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
    var query = OrmMemberGroup.query(global.get_db());
    defer query.deinit();

    // 状态筛选
    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            _ = query.where("status", "=", status);
        } else |_| {}
    }

    // 关键词搜索
    if (query_params.get("keyword")) |keyword| {
        if (keyword.len > 0) {
            _ = query.whereRaw("name LIKE ? OR code LIKE ? OR description LIKE ?", .{ "%" ++ keyword ++ "%", "%" ++ keyword ++ "%", "%" ++ keyword ++ "%" });
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
    const id_str = r.pathParameters().get("id") orelse {
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmMemberGroup.find(global.get_db(), id)) |group| {
        try base.send_ok(response, group);
    } else {
        try base.send_failed(response, "会员分组不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const MemberGroupCreateDto = @import("../dto/member_group_create.dto.zig").MemberGroupCreateDto;
    const dto = json_mod.parse(MemberGroupCreateDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 检查编码唯一性
    if (dto.code.len > 0) {
        var query = OrmMemberGroup.query(global.get_db());
        defer query.deinit();

        _ = query.where("code", "=", dto.code);

        // 如果是更新，排除自身
        if (r.pathParameters().get("id")) |id_str| {
            if (std.fmt.parseInt(i32, id_str, 10)) |existing_id| {
                _ = query.where("id", "!=", existing_id);
            } else |_| {}
        }

        const exists = try query.exists();
        if (exists) {
            try base.send_error(response, "分组编码已存在");
            return;
        }
    }

    // 如果设置为默认分组，先取消其他默认分组
    if (dto.is_default == 1) {
        _ = try OrmMemberGroup.updateWhere(global.get_db(), .{ .is_default = 1 }, .{ .is_default = 0 });
    }

    // 保存数据
    const group = try OrmMemberGroup.create(global.get_db(), .{
        .name = dto.name,
        .code = dto.code,
        .description = dto.description,
        .icon = dto.icon,
        .permissions = dto.permissions,
        .points_required = dto.points_required,
        .discount_rate = dto.discount_rate,
        .sort = dto.sort,
        .status = dto.status,
        .is_default = dto.is_default,
        .remark = dto.remark,
    });

    try base.send_ok(response, group);
}

/// 删除实现
fn deleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const id_str = r.pathParameters().get("id") orelse {
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    // 检查是否有会员使用此分组
    const Member = @import("../../domain/entities/member.model.zig").Member;
    const OrmMember = sql.defineWithConfig(Member, .{
        .table_name = "zigcms.member",
        .primary_key = "id",
    });

    if (!OrmMember.hasDb()) {
        OrmMember.use(global.get_db());
    }

    var member_query = OrmMember.query(global.get_db());
    defer member_query.deinit();

    const has_members = try member_query.where("group_id", "=", id).exists();
    if (has_members) {
        try base.send_error(response, "该分组下还有会员，无法删除");
        return;
    }

    const affected = try OrmMemberGroup.destroy(global.get_db(), id);
    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "删除失败");
    }
}

/// 分组选项实现
fn selectImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    var query = OrmMemberGroup.query(global.get_db());
    defer query.deinit();

    _ = query.where("status", "=", 1).orderBy("sort", .asc);

    var list = try query.collect();
    defer list.deinit();

    // 转换为选项格式
    var options = std.ArrayList(struct {
        value: i32,
        label: []const u8,
    }).init(self.allocator);
    defer {
        for (options.items) |*opt| {
            self.allocator.free(opt.label);
        }
        options.deinit();
    }

    for (list.items()) |group| {
        const label = try std.fmt.allocPrint(self.allocator, "{s}", .{group.name});
        try options.append(.{
            .value = group.id.?,
            .label = label,
        });
    }

    try base.send_ok(response, options.items);
}
