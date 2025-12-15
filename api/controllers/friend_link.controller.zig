//! 友链管理控制器
//!
//! 提供友情链接的 CRUD 操作及申请审核管理

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
const OrmFriendLink = sql.defineWithConfig(models.FriendLink, .{
    .table_name = "zigcms.friend_link",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmFriendLink.hasDb()) {
        OrmFriendLink.use(global.get_db());
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

/// 通过审核
pub const approve = MW.requireAuth(approveImpl);

/// 拒绝审核
pub const reject = MW.requireAuth(rejectImpl);

/// 前端显示友链
pub const show = MW.optionalAuth(showImpl);

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
    var query = OrmFriendLink.query(global.get_db());
    defer query.deinit();

    // 状态筛选
    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            _ = query.where("status", "=", status);
        } else |_| {}
    }

    // 显示状态筛选
    if (query_params.get("is_show")) |is_show_str| {
        if (std.fmt.parseInt(i32, is_show_str, 10)) |is_show| {
            _ = query.where("is_show", "=", is_show);
        } else |_| {}
    }

    // 关键词搜索
    if (query_params.get("keyword")) |keyword| {
        if (keyword.len > 0) {
            _ = query.whereRaw("name LIKE ? OR url LIKE ? OR description LIKE ?", .{ "%" ++ keyword ++ "%", "%" ++ keyword ++ "%", "%" ++ keyword ++ "%" });
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
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    if (try OrmFriendLink.find(global.get_db(), id)) |friend_link| {
        try base.send_ok(response, friend_link);
    } else {
        try base.send_failed(response, "友链不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const FriendLinkCreateDto = @import("../dto/friend_link_create.dto.zig").FriendLinkCreateDto;
    const dto = json_mod.parse(FriendLinkCreateDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 验证URL格式
    if (dto.url.len == 0 or !strings.startsWith(dto.url, "http")) {
        try base.send_error(response, "请输入有效的网站URL");
        return;
    }

    // 保存数据
    const current_time = std.time.timestamp() * 1000;
    const friend_link = try OrmFriendLink.create(global.get_db(), .{
        .name = dto.name,
        .url = dto.url,
        .logo = dto.logo,
        .description = dto.description,
        .email = dto.email,
        .qq = dto.qq,
        .is_show = dto.is_show,
        .sort = dto.sort,
        .status = dto.status,
        .applicant = dto.applicant,
        .apply_time = current_time,
        .remark = dto.remark,
    });

    try base.send_ok(response, friend_link);
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

    const affected = try OrmFriendLink.destroy(global.get_db(), id);
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
        try base.send_error(response, "请选择要删除的友链");
        return;
    }

    var affected: i32 = 0;
    for (dto.ids) |id| {
        const result = try OrmFriendLink.destroy(global.get_db(), id);
        affected += result;
    }

    try base.send_ok(response, .{ .affected = affected });
}

/// 通过审核实现
fn approveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    const current_time = std.time.timestamp() * 1000;
    const affected = try OrmFriendLink.update(global.get_db(), id, .{
        .status = 1,
        .pass_time = current_time,
    });

    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "审核失败");
    }
}

/// 拒绝审核实现
fn rejectImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    const id_str = r.pathParameters().get("id") orelse {
        try base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        try base.send_error(response, "无效的ID格式");
        return;
    };

    const body = r.body orelse "";
    const remark = if (body.len > 0) body else "审核未通过";

    const affected = try OrmFriendLink.update(global.get_db(), id, .{
        .status = 0,
        .remark = remark,
    });

    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "操作失败");
    }
}

/// 前端显示友链实现
fn showImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    _ = self;
    var query = OrmFriendLink.query(global.get_db());
    defer query.deinit();

    _ = query
        .where("status", "=", 1)
        .where("is_show", "=", 1)
        .orderBy("sort", .asc)
        .orderBy("create_time", .desc);

    var links = try query.collect();
    defer links.deinit();

    // 增加点击数（如果有点击参数）
    if (r.queryParameters().get("click")) |click_id_str| {
        if (std.fmt.parseInt(i32, click_id_str, 10)) |click_id| {
            _ = try OrmFriendLink.increment(global.get_db(), click_id, "clicks", 1);
        } else |_| {}
    }

    try base.send_ok(response, links.items);
}
