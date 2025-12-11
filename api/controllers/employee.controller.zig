//! 员工管理控制器
//!
//! 提供员工的 CRUD 操作及关联查询

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
const orm_models = @import("../../domain/entities/orm_models.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,

/// ORM 模型定义
const OrmEmployee = sql.defineWithConfig(models.Employee, .{
    .table_name = "zigcms.employee",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmEmployee.hasDb()) {
        OrmEmployee.use(global.get_db());
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

/// 下拉选择列表
pub const select = MW.requireAuth(selectImpl);

/// 按部门筛选
pub const byDepartment = MW.requireAuth(byDepartmentImpl);

/// 带关联信息的详情
pub const detail = MW.requireAuth(detailImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var sort_field: []const u8 = "id";
    var sort_dir: []const u8 = "desc";
    var department_id: ?i32 = null;
    var status: ?i32 = null;

    var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "page")) {
            page = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.eql(value.key, "limit")) {
            limit = @intCast(strings.to_int(value.value) catch 10);
        } else if (strings.eql(value.key, "department_id")) {
            department_id = @intCast(strings.to_int(value.value) catch 0);
        } else if (strings.eql(value.key, "status")) {
            status = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.starts_with(value.key, "sort[")) {
            sort_field = base.get_sort_field(value.key) orelse "id";
            sort_dir = value.value;
        }
    }

    // 构建查询
    var q = OrmEmployee.Where("is_delete", .eq, @as(i32, 0));
    defer q.deinit();

    if (department_id) |dept_id| {
        if (dept_id > 0) {
            _ = q.where("department_id", .eq, dept_id);
        }
    }

    if (status) |s| {
        _ = q.where("status", .eq, s);
    }

    const total = q.count() catch |e| return base.send_error(req, e);

    const order_dir: sql.OrderDir = if (strings.eql(sort_dir, "asc")) .asc else .desc;
    _ = q.orderBy(sort_field, order_dir);
    _ = q.page(page, limit);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmEmployee.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Employee){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_layui_table_response(req, items.items, total, .{});
}

/// 获取单条记录实现
fn getImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const item_opt = OrmEmployee.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "员工不存在");
    }

    var item = item_opt.?;
    defer OrmEmployee.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

/// 带关联信息的详情实现
fn detailImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const item_opt = OrmEmployee.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "员工不存在");
    }

    var item = item_opt.?;
    defer OrmEmployee.freeModel(self.allocator, &item);

    // 加载关联数据
    const Relations = orm_models.Relations.EmployeeRelations;

    // 获取部门信息
    var dept_name: []const u8 = "";
    if (Relations.department(item.department_id) catch null) |dept| {
        dept_name = dept.name;
    }

    // 获取职位信息
    var position_name: []const u8 = "";
    if (Relations.position(item.position_id) catch null) |pos| {
        position_name = pos.name;
    }

    // 获取角色信息
    var role_name: []const u8 = "";
    if (Relations.role(item.role_id) catch null) |r| {
        role_name = r.name;
    }

    // 获取领导信息
    var leader_name: []const u8 = "";
    if (Relations.leader(item.leader_id) catch null) |l| {
        leader_name = l.name;
    }

    // 构建带关联的响应
    const EmployeeDetail = struct {
        id: ?i32,
        employee_no: []const u8,
        name: []const u8,
        gender: i32,
        phone: []const u8,
        email: []const u8,
        department_id: ?i32,
        department_name: []const u8,
        position_id: ?i32,
        position_name: []const u8,
        role_id: ?i32,
        role_name: []const u8,
        leader_id: ?i32,
        leader_name: []const u8,
        hire_date: ?i64,
        avatar: []const u8,
        status: i32,
        remark: []const u8,
    };

    const detail_data = EmployeeDetail{
        .id = item.id,
        .employee_no = item.employee_no,
        .name = item.name,
        .gender = item.gender,
        .phone = item.phone,
        .email = item.email,
        .department_id = item.department_id,
        .department_name = dept_name,
        .position_id = item.position_id,
        .position_name = position_name,
        .role_id = item.role_id,
        .role_name = role_name,
        .leader_id = item.leader_id,
        .leader_name = leader_name,
        .hire_date = item.hire_date,
        .avatar = item.avatar,
        .status = item.status,
        .remark = item.remark,
    };

    return base.send_ok(req, detail_data);
}

/// 保存实现（新增/更新）
fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(models.Employee, self.allocator, body) catch |err| {
        std.log.err("解析员工数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };

    // 验证必填字段
    if (dto.name.len == 0) {
        return base.send_failed(req, "员工姓名不能为空");
    }
    if (dto.employee_no.len == 0) {
        return base.send_failed(req, "工号不能为空");
    }

    // 检查工号唯一性
    var check_q = OrmEmployee.Where("employee_no", .eq, dto.employee_no);
    defer check_q.deinit();
    _ = check_q.where("is_delete", .eq, @as(i32, 0));
    if (dto.id) |id| {
        if (id > 0) {
            _ = check_q.where("id", .neq, id);
        }
    }
    const exists = check_q.first() catch null;
    if (exists != null) {
        return base.send_failed(req, "工号已存在");
    }

    // 判断更新还是新增
    if (dto.id) |id| {
        if (id > 0) {
            const affected = OrmEmployee.Update(id, dto) catch |e| return base.send_error(req, e);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }
            return base.send_ok(req, dto);
        }
    }

    // 新增
    var new_item = OrmEmployee.Create(dto) catch |e| return base.send_error(req, e);
    defer OrmEmployee.freeModel(self.allocator, &new_item);

    return base.send_ok(req, new_item);
}

/// 删除实现（软删除）
fn deleteImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    // 软删除：更新 is_delete 字段
    const sql_str = strings.sprinf(
        "UPDATE zigcms.employee SET is_delete = 1, update_time = {d} WHERE id = {d}",
        .{ std.time.microTimestamp(), id },
    ) catch return base.send_failed(req, "SQL 构建失败");
    defer self.allocator.free(sql_str);

    _ = global.get_db().rawExec(sql_str) catch |e| return base.send_error(req, e);

    return base.send_ok(req, "删除成功");
}

/// 下拉选择列表实现
fn selectImpl(self: *Self, req: zap.Request) !void {
    var q = OrmEmployee.Where("status", .eq, @as(i32, 1));
    defer q.deinit();
    _ = q.where("is_delete", .eq, @as(i32, 0));
    _ = q.orderBy("sort", .asc);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmEmployee.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Employee){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, items.items);
}

/// 按部门筛选实现
fn byDepartmentImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const dept_id_str = req.getParamSlice("department_id") orelse return base.send_failed(req, "缺少部门ID");
    const dept_id: i32 = @intCast(strings.to_int(dept_id_str) catch return base.send_failed(req, "部门ID格式错误"));

    var q = OrmEmployee.Where("department_id", .eq, dept_id);
    defer q.deinit();
    _ = q.where("is_delete", .eq, @as(i32, 0));
    _ = q.where("status", .eq, @as(i32, 1));
    _ = q.orderBy("sort", .asc);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmEmployee.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Employee){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, items.items);
}
