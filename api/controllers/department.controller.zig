//! 部门管理控制器
//!
//! 提供部门的 CRUD 操作及树形结构查询

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
const OrmDepartment = sql.defineWithConfig(models.Department, .{
    .table_name = "zigcms.department",
    .primary_key = "id",
});

const OrmEmployee = sql.defineWithConfig(models.Employee, .{
    .table_name = "zigcms.employee",
    .primary_key = "id",
});

const OrmPosition = sql.defineWithConfig(models.Position, .{
    .table_name = "zigcms.position",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmDepartment.hasDb()) {
        OrmDepartment.use(global.get_db());
    }
    if (!OrmEmployee.hasDb()) {
        OrmEmployee.use(global.get_db());
    }
    if (!OrmPosition.hasDb()) {
        OrmPosition.use(global.get_db());
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

/// 获取部门树
pub const tree = MW.requireAuth(treeImpl);

/// 下拉选择列表
pub const select = MW.requireAuth(selectImpl);

/// 带关联信息的详情
pub const detail = MW.requireAuth(detailImpl);

/// 组织架构树（部门+员工）
pub const orgTree = MW.requireAuth(orgTreeImpl);

/// 部门统计（含子部门人数）
pub const stats = MW.requireAuth(statsImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    var page: i32 = 1;
    var limit: i32 = 10;
    var sort_field: []const u8 = "sort";
    var sort_dir: []const u8 = "asc";

    var params = req.parametersToOwnedStrList(self.allocator) catch unreachable;
    defer params.deinit();

    for (params.items) |value| {
        if (strings.eql(value.key, "page")) {
            page = @intCast(strings.to_int(value.value) catch 1);
        } else if (strings.eql(value.key, "limit")) {
            limit = @intCast(strings.to_int(value.value) catch 10);
        } else if (strings.starts_with(value.key, "sort[")) {
            sort_field = base.get_sort_field(value.key) orelse "sort";
            sort_dir = value.value;
        }
    }

    const total = OrmDepartment.Count() catch |e| return base.send_error(req, e);

    const order_dir: sql.OrderDir = if (strings.eql(sort_dir, "asc")) .asc else .desc;
    var q = OrmDepartment.OrderBy(sort_field, order_dir);
    defer q.deinit();
    _ = q.page(page, limit);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmDepartment.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Department){};
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

    const item_opt = OrmDepartment.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "部门不存在");
    }

    var item = item_opt.?;
    defer OrmDepartment.freeModel(self.allocator, &item);

    return base.send_ok(req, item);
}

/// 保存实现（新增/更新）
fn saveImpl(self: *Self, req: zap.Request) !void {
    req.parseBody() catch return base.send_failed(req, "解析请求体失败");
    const body = req.body orelse return base.send_failed(req, "请求体为空");

    const dto = json_mod.JSON.decode(models.Department, self.allocator, body) catch |err| {
        std.log.err("解析部门数据失败: {}", .{err});
        return base.send_failed(req, "解析数据失败");
    };

    // 验证必填字段
    if (dto.name.len == 0) {
        return base.send_failed(req, "部门名称不能为空");
    }

    // 检查编码唯一性
    if (dto.code.len > 0) {
        var check_q = OrmDepartment.Where("code", .eq, dto.code);
        defer check_q.deinit();
        if (dto.id) |id| {
            if (id > 0) {
                _ = check_q.where("id", .neq, id);
            }
        }
        const exists = check_q.first() catch null;
        if (exists != null) {
            return base.send_failed(req, "部门编码已存在");
        }
    }

    // 判断更新还是新增
    if (dto.id) |id| {
        if (id > 0) {
            const affected = OrmDepartment.Update(id, dto) catch |e| return base.send_error(req, e);
            if (affected == 0) {
                return base.send_failed(req, "更新失败");
            }
            return base.send_ok(req, dto);
        }
    }

    // 新增
    var new_item = OrmDepartment.Create(dto) catch |e| return base.send_error(req, e);
    defer OrmDepartment.freeModel(self.allocator, &new_item);

    return base.send_ok(req, new_item);
}

/// 删除实现
fn deleteImpl(_: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    // 检查是否有子部门
    var child_q = OrmDepartment.Where("parent_id", .eq, id);
    defer child_q.deinit();
    const child_count = child_q.count() catch 0;
    if (child_count > 0) {
        return base.send_failed(req, "存在子部门，无法删除");
    }

    const affected = OrmDepartment.Destroy(id) catch |e| return base.send_error(req, e);
    if (affected == 0) {
        return base.send_failed(req, "删除失败");
    }

    return base.send_ok(req, affected);
}

/// 部门树节点（带人数统计）
const DeptTreeNode = struct {
    id: i32,
    name: []const u8,
    code: []const u8,
    parent_id: i32,
    leader_name: []const u8 = "",
    employee_count: i32 = 0,
    total_employee_count: i32 = 0,
    children: []const DeptTreeNode = &[_]DeptTreeNode{},
};

/// 组织架构节点（部门+员工混合）
const OrgNode = struct {
    id: i32,
    name: []const u8,
    node_type: []const u8,
    parent_id: i32,
    position_name: []const u8 = "",
    avatar: []const u8 = "",
    children: []const OrgNode = &[_]OrgNode{},
};

/// 获取部门树实现（带人数统计）
fn treeImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    // 查询所有有效部门
    var q = OrmDepartment.Where("status", .eq, @as(i32, 1));
    defer q.deinit();
    _ = q.orderBy("sort", .asc);
    const depts = q.get() catch |e| return base.send_error(req, e);
    defer OrmDepartment.freeModels(self.allocator, depts);

    // 查询所有有效员工（用于统计）
    var emp_q = OrmEmployee.Where("is_delete", .eq, @as(i32, 0));
    defer emp_q.deinit();
    _ = emp_q.andWhere("status", .eq, @as(i32, 1));
    const employees = emp_q.get() catch &[_]models.Employee{};
    defer OrmEmployee.freeModels(self.allocator, employees);

    // 统计每个部门的直属员工数
    var dept_emp_count = std.AutoHashMap(i32, i32).init(self.allocator);
    defer dept_emp_count.deinit();
    for (employees) |emp| {
        if (emp.department_id) |dept_id| {
            const entry = dept_emp_count.getOrPut(dept_id) catch continue;
            if (!entry.found_existing) entry.value_ptr.* = 0;
            entry.value_ptr.* += 1;
        }
    }

    // 构建部门ID到部门的映射
    var dept_map = std.AutoHashMap(i32, models.Department).init(self.allocator);
    defer dept_map.deinit();
    for (depts) |dept| {
        if (dept.id) |id| {
            dept_map.put(id, dept) catch {};
        }
    }

    // 构建树形结构
    var tree_nodes = std.ArrayList(DeptTreeNode).init(self.allocator);
    defer tree_nodes.deinit();

    // 查找根节点（parent_id = 0）
    for (depts) |dept| {
        if (dept.parent_id == 0) {
            const node = buildDeptTreeNode(self.allocator, dept, depts, &dept_emp_count);
            tree_nodes.append(node) catch {};
        }
    }

    base.send_ok(req, tree_nodes.items);
}

/// 递归构建部门树节点
fn buildDeptTreeNode(
    allocator: Allocator,
    dept: models.Department,
    all_depts: []models.Department,
    emp_count_map: *std.AutoHashMap(i32, i32),
) DeptTreeNode {
    const dept_id = dept.id orelse 0;
    const direct_count = emp_count_map.get(dept_id) orelse 0;

    // 查找子部门
    var children = std.ArrayList(DeptTreeNode).init(allocator);
    var total_count: i32 = direct_count;

    for (all_depts) |child_dept| {
        if (child_dept.parent_id == dept_id) {
            const child_node = buildDeptTreeNode(allocator, child_dept, all_depts, emp_count_map);
            total_count += child_node.total_employee_count;
            children.append(child_node) catch {};
        }
    }

    return DeptTreeNode{
        .id = dept_id,
        .name = dept.name,
        .code = dept.code,
        .parent_id = dept.parent_id,
        .employee_count = direct_count,
        .total_employee_count = total_count,
        .children = children.toOwnedSlice() catch &[_]DeptTreeNode{},
    };
}

/// 下拉选择列表实现
fn selectImpl(self: *Self, req: zap.Request) !void {
    var q = OrmDepartment.Where("status", .eq, @as(i32, 1));
    defer q.deinit();
    _ = q.orderBy("sort", .asc);

    const items_slice = q.get() catch |e| return base.send_error(req, e);
    defer OrmDepartment.freeModels(self.allocator, items_slice);

    var items = std.ArrayListUnmanaged(models.Department){};
    defer items.deinit(self.allocator);
    for (items_slice) |item| {
        items.append(self.allocator, item) catch {};
    }

    base.send_ok(req, items.items);
}

/// 带关联信息的详情实现
fn detailImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少 id 参数");
    const id: i32 = @intCast(strings.to_int(id_str) catch return base.send_failed(req, "id 格式错误"));

    const item_opt = OrmDepartment.Find(id) catch |e| return base.send_error(req, e);
    if (item_opt == null) {
        return base.send_failed(req, "部门不存在");
    }

    var item = item_opt.?;
    defer OrmDepartment.freeModel(self.allocator, &item);

    // 加载关联数据
    const Relations = orm_models.Relations.DepartmentRelations;

    // 获取父部门名称
    var parent_name: []const u8 = "";
    if (item.parent_id > 0) {
        if (Relations.parent(item.parent_id) catch null) |p| {
            parent_name = p.name;
        }
    }

    // 获取负责人名称
    var leader_name: []const u8 = "";
    if (Relations.leader(item.leader_id) catch null) |l| {
        leader_name = l.name;
    }

    // 统计员工数
    const employees = Relations.activeEmployees(id) catch &[_]orm_models.Employee.Model{};
    const employee_count: i32 = @intCast(employees.len);

    // 统计职位数
    const positions = Relations.positions(id) catch &[_]orm_models.Position.Model{};
    const position_count: i32 = @intCast(positions.len);

    // 统计子部门数
    const children = Relations.children(id) catch &[_]orm_models.Department.Model{};
    const children_count: i32 = @intCast(children.len);

    // 构建带关联的响应
    const DepartmentDetail = struct {
        id: ?i32,
        name: []const u8,
        code: []const u8,
        parent_id: i32,
        parent_name: []const u8,
        leader_id: ?i32,
        leader_name: []const u8,
        phone: []const u8,
        email: []const u8,
        sort: i32,
        status: i32,
        remark: []const u8,
        employee_count: i32,
        position_count: i32,
        children_count: i32,
    };

    const detail_data = DepartmentDetail{
        .id = item.id,
        .name = item.name,
        .code = item.code,
        .parent_id = item.parent_id,
        .parent_name = parent_name,
        .leader_id = item.leader_id,
        .leader_name = leader_name,
        .phone = item.phone,
        .email = item.email,
        .sort = item.sort,
        .status = item.status,
        .remark = item.remark,
        .employee_count = employee_count,
        .position_count = position_count,
        .children_count = children_count,
    };

    return base.send_ok(req, detail_data);
}

/// 组织架构树实现（部门+员工混合）
fn orgTreeImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    // 可选参数：指定根部门ID
    var root_id: i32 = 0;
    if (req.getParamSlice("department_id")) |id_str| {
        root_id = @intCast(strings.to_int(id_str) catch 0);
    }

    // 查询所有有效部门
    var dept_q = OrmDepartment.Where("status", .eq, @as(i32, 1));
    defer dept_q.deinit();
    _ = dept_q.orderBy("sort", .asc);
    const depts = dept_q.get() catch |e| return base.send_error(req, e);
    defer OrmDepartment.freeModels(self.allocator, depts);

    // 查询所有有效员工
    var emp_q = OrmEmployee.Where("is_delete", .eq, @as(i32, 0));
    defer emp_q.deinit();
    _ = emp_q.andWhere("status", .eq, @as(i32, 1));
    const employees = emp_q.get() catch &[_]models.Employee{};
    defer OrmEmployee.freeModels(self.allocator, employees);

    // 查询职位（用于显示员工职位名）
    var pos_q = OrmPosition.Where("status", .eq, @as(i32, 1));
    defer pos_q.deinit();
    const positions = pos_q.get() catch &[_]models.Position{};
    defer OrmPosition.freeModels(self.allocator, positions);

    // 职位ID到名称映射
    var pos_map = std.AutoHashMap(i32, []const u8).init(self.allocator);
    defer pos_map.deinit();
    for (positions) |pos| {
        if (pos.id) |id| {
            pos_map.put(id, pos.name) catch {};
        }
    }

    // 员工按部门分组
    var dept_employees = std.AutoHashMap(i32, std.ArrayList(models.Employee)).init(self.allocator);
    defer {
        var it = dept_employees.valueIterator();
        while (it.next()) |emp_list| {
            emp_list.deinit();
        }
        dept_employees.deinit();
    }

    for (employees) |emp| {
        if (emp.department_id) |dept_id| {
            const entry = dept_employees.getOrPut(dept_id) catch continue;
            if (!entry.found_existing) {
                entry.value_ptr.* = std.ArrayList(models.Employee).init(self.allocator);
            }
            entry.value_ptr.append(emp) catch {};
        }
    }

    // 构建组织架构树
    var org_nodes = std.ArrayList(OrgNode).init(self.allocator);
    defer org_nodes.deinit();

    // 查找根节点
    for (depts) |dept| {
        if (root_id == 0 and dept.parent_id == 0) {
            const node = buildOrgTreeNode(self.allocator, dept, depts, &dept_employees, &pos_map);
            org_nodes.append(node) catch {};
        } else if (root_id > 0 and dept.id != null and dept.id.? == root_id) {
            const node = buildOrgTreeNode(self.allocator, dept, depts, &dept_employees, &pos_map);
            org_nodes.append(node) catch {};
        }
    }

    base.send_ok(req, org_nodes.items);
}

/// 递归构建组织架构树节点
fn buildOrgTreeNode(
    allocator: Allocator,
    dept: models.Department,
    all_depts: []models.Department,
    dept_employees: *std.AutoHashMap(i32, std.ArrayList(models.Employee)),
    pos_map: *std.AutoHashMap(i32, []const u8),
) OrgNode {
    const dept_id = dept.id orelse 0;
    var children = std.ArrayList(OrgNode).init(allocator);

    // 先添加该部门的员工节点
    if (dept_employees.get(dept_id)) |emp_list| {
        for (emp_list.items) |emp| {
            const pos_name = if (emp.position_id) |pid| pos_map.get(pid) orelse "" else "";
            children.append(OrgNode{
                .id = emp.id orelse 0,
                .name = emp.name,
                .node_type = "employee",
                .parent_id = dept_id,
                .position_name = pos_name,
                .avatar = emp.avatar,
            }) catch {};
        }
    }

    // 再添加子部门节点
    for (all_depts) |child_dept| {
        if (child_dept.parent_id == dept_id) {
            const child_node = buildOrgTreeNode(allocator, child_dept, all_depts, dept_employees, pos_map);
            children.append(child_node) catch {};
        }
    }

    return OrgNode{
        .id = dept_id,
        .name = dept.name,
        .node_type = "department",
        .parent_id = dept.parent_id,
        .children = children.toOwnedSlice() catch &[_]OrgNode{},
    };
}

/// 部门统计实现
fn statsImpl(self: *Self, req: zap.Request) !void {
    req.parseQuery();

    // 查询所有有效部门
    var dept_q = OrmDepartment.Where("status", .eq, @as(i32, 1));
    defer dept_q.deinit();
    const depts = dept_q.get() catch |e| return base.send_error(req, e);
    defer OrmDepartment.freeModels(self.allocator, depts);

    // 查询所有有效员工
    var emp_q = OrmEmployee.Where("is_delete", .eq, @as(i32, 0));
    defer emp_q.deinit();
    _ = emp_q.andWhere("status", .eq, @as(i32, 1));
    const employees = emp_q.get() catch &[_]models.Employee{};
    defer OrmEmployee.freeModels(self.allocator, employees);

    // 查询所有职位
    var pos_q = OrmPosition.Where("status", .eq, @as(i32, 1));
    defer pos_q.deinit();
    const positions = pos_q.get() catch &[_]models.Position{};
    defer OrmPosition.freeModels(self.allocator, positions);

    // 统计每个部门的员工数
    var dept_emp_count = std.AutoHashMap(i32, i32).init(self.allocator);
    defer dept_emp_count.deinit();
    for (employees) |emp| {
        if (emp.department_id) |dept_id| {
            const entry = dept_emp_count.getOrPut(dept_id) catch continue;
            if (!entry.found_existing) entry.value_ptr.* = 0;
            entry.value_ptr.* += 1;
        }
    }

    // 统计每个部门的职位数
    var dept_pos_count = std.AutoHashMap(i32, i32).init(self.allocator);
    defer dept_pos_count.deinit();
    for (positions) |pos| {
        if (pos.department_id) |dept_id| {
            const entry = dept_pos_count.getOrPut(dept_id) catch continue;
            if (!entry.found_existing) entry.value_ptr.* = 0;
            entry.value_ptr.* += 1;
        }
    }

    // 构建部门统计列表
    const DeptStats = struct {
        id: i32,
        name: []const u8,
        code: []const u8,
        parent_id: i32,
        employee_count: i32,
        total_employee_count: i32,
        position_count: i32,
    };

    var stats_list = std.ArrayList(DeptStats).init(self.allocator);
    defer stats_list.deinit();

    // 计算每个部门的总人数（含子部门）
    for (depts) |dept| {
        const dept_id = dept.id orelse continue;
        const direct_count = dept_emp_count.get(dept_id) orelse 0;
        const pos_count = dept_pos_count.get(dept_id) orelse 0;

        // 递归计算子部门人数
        const total_count = calcTotalEmployees(dept_id, depts, &dept_emp_count);

        stats_list.append(DeptStats{
            .id = dept_id,
            .name = dept.name,
            .code = dept.code,
            .parent_id = dept.parent_id,
            .employee_count = direct_count,
            .total_employee_count = total_count,
            .position_count = pos_count,
        }) catch {};
    }

    // 汇总统计
    const Summary = struct {
        total_departments: i32,
        total_employees: i32,
        total_positions: i32,
        departments: []DeptStats,
    };

    const summary = Summary{
        .total_departments = @intCast(depts.len),
        .total_employees = @intCast(employees.len),
        .total_positions = @intCast(positions.len),
        .departments = stats_list.toOwnedSlice() catch &[_]DeptStats{},
    };

    base.send_ok(req, summary);
}

/// 递归计算部门总员工数（含子部门）
fn calcTotalEmployees(
    dept_id: i32,
    all_depts: []models.Department,
    emp_count_map: *std.AutoHashMap(i32, i32),
) i32 {
    var total: i32 = emp_count_map.get(dept_id) orelse 0;

    for (all_depts) |child_dept| {
        if (child_dept.parent_id == dept_id) {
            const child_id = child_dept.id orelse continue;
            total += calcTotalEmployees(child_id, all_depts, emp_count_map);
        }
    }

    return total;
}
