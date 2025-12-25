//! 会员管理控制器
//!
//! 提供会员的 CRUD 操作及会员信息管理
//! 遵循清洁架构，使用应用层服务处理业务逻辑

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const MemberService = @import("../../application/services/member_service.zig").MemberService;
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,
member_service: *MemberService,

/// 初始化控制器
pub fn init(allocator: Allocator, member_service: *MemberService) Self {
    return .{
        .allocator = allocator,
        .member_service = member_service,
    };
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

    const MemberFilters = self.member_service.MemberFilters;

    var filters = MemberFilters{};
    var filters_allocated = false;
    defer if (filters_allocated) {
        self.allocator.free(filters.keyword);
    };

    // 分组筛选
    if (query_params.get("group_id")) |group_id_str| {
        if (std.fmt.parseInt(i32, group_id_str, 10)) |group_id| {
            filters.group_id = group_id;
        } else |_| {}
    }

    // 状态筛选
    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            filters.status = status;
        } else |_| {}
    }

    // 等级筛选
    if (query_params.get("level")) |level_str| {
        if (std.fmt.parseInt(i32, level_str, 10)) |level| {
            filters.level = level;
        } else |_| {}
    }

    // 关键词搜索
    if (query_params.get("keyword")) |keyword| {
        if (keyword.len > 0) {
            filters.keyword = try self.allocator.dupe(u8, keyword);
            filters_allocated = true;
        }
    }

    // 注册时间筛选
    if (query_params.get("start_date")) |start_date| {
        if (start_date.len > 0) {
            const start_time = std.fmt.parseInt(i64, start_date ++ "000000", 10) catch 0;
            filters.start_date = start_time;
        }
    }

    if (query_params.get("end_date")) |end_date| {
        if (end_date.len > 0) {
            const end_time = std.fmt.parseInt(i64, end_date ++ "235959", 10) catch 0;
            filters.end_date = end_time;
        }
    }

    // 分页参数
    const page = if (query_params.get("page")) |p| std.fmt.parseInt(u32, p, 10) catch 1 else 1;
    const page_size = if (query_params.get("page_size")) |ps| std.fmt.parseInt(u32, ps, 10) catch 10 else 10;

    // 调用服务层分页查询
    const result = try self.member_service.getMembersWithPagination(page, page_size, filters);
    defer self.allocator.free(result.data);

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
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    // 使用应用层服务获取会员
    if (try self.member_service.getMember(id)) |member| {
        try base.send_ok(response, member);
    } else {
        try base.send_failed(response, "会员不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const MemberCreateDto = @import("../dto/member_create.dto.zig").MemberCreateDto;
    const dto = json_mod.parse(MemberCreateDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 使用应用层服务创建会员（包含所有业务验证）
    const member = self.member_service.createMember(dto.username, dto.email, dto.nickname) catch |err| switch (err) {
        error.InvalidUsername => base.send_error(response, "无效的用户名"),
        error.InvalidEmail => base.send_error(response, "无效的邮箱格式"),
        error.UsernameExists => base.send_error(response, "用户名已存在"),
        else => {
            base.send_error(response, "创建会员失败");
            return err;
        },
    };

    try base.send_ok(response, member);
}

/// 删除实现
fn deleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    // 使用应用层服务删除会员
    try self.member_service.deleteMember(id) catch |err| switch (err) {
        error.MemberNotFound => base.send_failed(response, "会员不存在"),
        else => {
            base.send_error(response, "删除失败");
            return err;
        },
    };

    try base.send_ok(response, .{ .message = "删除成功" });
}

/// 批量删除实现
fn batchDeleteImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const BatchDeleteDto = struct {
        ids: []i32,
    };

    const dto = json_mod.parse(BatchDeleteDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    if (dto.ids.len == 0) {
        base.send_error(response, "请选择要删除的会员");
        return;
    }

    // TODO: 实现批量删除逻辑
    // 目前逐个删除，后续可优化为批量操作
    var success_count: i32 = 0;
    for (dto.ids) |id| {
        self.member_service.deleteMember(id) catch {
            // 继续处理其他ID
            continue;
        };
        success_count += 1;
    }

    try base.send_ok(response, .{ .affected = success_count });
}

/// 调整积分实现
fn adjustPointsImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const AdjustPointsDto = struct {
        id: i32,
        points: i32,
        remark: []const u8 = "",
    };

    const dto = json_mod.parse(AdjustPointsDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 使用MemberService调整积分
    try self.member_service.adjustPoints(dto.id, dto.points);

    try base.send_ok(response, .{ .message = "积分调整成功" });
}

/// 调整等级实现
fn adjustLevelImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const AdjustLevelDto = struct {
        id: i32,
        level: i32,
        remark: []const u8 = "",
    };

    const dto = json_mod.parse(AdjustLevelDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // TODO: 实现使用MemberService调整等级
    // 目前MemberService还没有调整等级的方法
    try base.send_ok(response, .{ .message = "等级调整功能开发中" });
}

/// 启用/禁用实现
fn toggleStatusImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const id_str = r.pathParameters().get("id") orelse {
        base.send_error(response, "缺少ID参数");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_error(response, "无效的ID格式");
        return;
    };

    // 获取当前会员状态
    const member = try self.member_service.getMember(id) orelse {
        base.send_failed(response, "会员不存在");
        return;
    };

    // 根据当前状态切换
    const new_status: i32 = if (member.isActive()) 0 else 1;

    if (new_status == 1) {
        try self.member_service.enableMember(id);
    } else {
        try self.member_service.disableMember(id);
    }

    try base.send_ok(response, .{ .status = new_status, .message = if (new_status == 1) "已启用" else "已禁用" });
}
