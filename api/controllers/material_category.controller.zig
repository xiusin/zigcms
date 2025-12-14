//! 素材分类管理控制器
//!
//! 提供素材分类的 CRUD 操作及树形结构管理

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
const OrmMaterialCategory = sql.defineWithConfig(models.MaterialCategory, .{
    .table_name = "zigcms.material_category",
    .primary_key = "id",
});

/// 初始化控制器
pub fn init(allocator: Allocator) Self {
    if (!OrmMaterialCategory.hasDb()) {
        OrmMaterialCategory.use(global.get_db());
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

/// 获取树形结构
pub const tree = MW.requireAuth(treeImpl);

/// 获取分类选项（用于下拉框）
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
    var query = OrmMaterialCategory.query(global.get_db());
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
            _ = query.whereRaw("name LIKE ? OR code LIKE ?", .{ "%" ++ keyword ++ "%", "%" ++ keyword ++ "%" });
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

    if (try OrmMaterialCategory.find(global.get_db(), id)) |category| {
        try base.send_ok(response, category);
    } else {
        try base.send_failed(response, "素材分类不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        try base.send_error(response, "请求体为空");
        return;
    };

    const MaterialCategoryCreateDto = @import("../dto/material_category_create.dto.zig").MaterialCategoryCreateDto;
    const dto = json_mod.parse(MaterialCategoryCreateDto, self.allocator, body) catch {
        try base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 检查编码唯一性
    if (dto.code.len > 0) {
        var query = OrmMaterialCategory.query(global.get_db());
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
            try base.send_error(response, "分类编码已存在");
            return;
        }
    }

    // 保存数据
    const category = try OrmMaterialCategory.create(global.get_db(), .{
        .name = dto.name,
        .code = dto.code,
        .parent_id = dto.parent_id,
        .description = dto.description,
        .icon = dto.icon,
        .allowed_types = dto.allowed_types,
        .max_size = dto.max_size,
        .sort = dto.sort,
        .status = dto.status,
        .remark = dto.remark,
    });

    try base.send_ok(response, category);
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

    // 检查是否有子分类
    var query = OrmMaterialCategory.query(global.get_db());
    defer query.deinit();

    const has_children = try query.where("parent_id", "=", id).exists();
    if (has_children) {
        try base.send_error(response, "该分类下还有子分类，无法删除");
        return;
    }

    // 检查是否有素材使用此分类
    const Material = @import("../../domain/entities/material.model.zig").Material;
    const OrmMaterial = sql.defineWithConfig(Material, .{
        .table_name = "zigcms.material",
        .primary_key = "id",
    });

    if (!OrmMaterial.hasDb()) {
        OrmMaterial.use(global.get_db());
    }

    var material_query = OrmMaterial.query(global.get_db());
    defer material_query.deinit();

    const has_materials = try material_query.where("category_id", "=", id).exists();
    if (has_materials) {
        try base.send_error(response, "该分类下还有素材，无法删除");
        return;
    }

    const affected = try OrmMaterialCategory.destroy(global.get_db(), id);
    if (affected > 0) {
        try base.send_ok(response, .{ .affected = affected });
    } else {
        try base.send_failed(response, "删除失败");
    }
}

/// 树形结构实现
fn treeImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    // 获取所有分类
    var query = OrmMaterialCategory.query(global.get_db());
    defer query.deinit();

    _ = query.where("status", "=", 1).orderBy("sort", .asc);

    var list = try query.collect();
    defer list.deinit();

    // 构建树形结构
    const tree = try self.buildCategoryTree(list.items());
    defer self.freeCategoryTree(self.allocator, tree);

    try base.send_ok(response, tree);
}

/// 分类选项实现
fn selectImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    var query = OrmMaterialCategory.query(global.get_db());
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

    for (list.items()) |category| {
        const label = try std.fmt.allocPrint(self.allocator, "{s}", .{category.name});
        try options.append(.{
            .value = category.id.?,
            .label = label,
        });
    }

    try base.send_ok(response, options.items);
}

// ============================================================================
// 辅助方法
// ============================================================================

/// 构建分类树形结构
fn buildCategoryTree(self: Self, categories: []const models.MaterialCategory) ![]MaterialCategoryTreeNode {
    var tree = std.ArrayList(MaterialCategoryTreeNode).init(self.allocator);
    defer tree.deinit();

    // 找到顶级分类
    for (categories) |category| {
        if (category.parent_id == 0) {
            const node = try self.buildTreeNode(categories, category);
            try tree.append(node);
        }
    }

    return tree.toOwnedSlice();
}

/// 构建树节点
fn buildTreeNode(self: Self, categories: []const models.MaterialCategory, category: models.MaterialCategory) !MaterialCategoryTreeNode {
    var node = MaterialCategoryTreeNode{
        .id = category.id.?,
        .name = try self.allocator.dupe(u8, category.name),
        .code = try self.allocator.dupe(u8, category.code),
        .parent_id = category.parent_id,
        .sort = category.sort,
        .status = category.status,
        .children = undefined,
    };

    // 查找子分类
    var children = std.ArrayList(MaterialCategoryTreeNode).init(self.allocator);
    defer children.deinit();

    for (categories) |child| {
        if (child.parent_id == category.id.?) {
            const child_node = try self.buildTreeNode(categories, child);
            try children.append(child_node);
        }
    }

    node.children = children.toOwnedSlice();
    return node;
}

/// 释放树形结构内存
fn freeCategoryTree(self: Self, allocator: Allocator, tree: []MaterialCategoryTreeNode) void {
    for (tree) |*node| {
        allocator.free(node.name);
        allocator.free(node.code);
        if (node.children.len > 0) {
            self.freeCategoryTree(allocator, node.children);
        }
        allocator.free(node.children);
    }
    allocator.free(tree);
}

/// 素材分类树节点
const MaterialCategoryTreeNode = struct {
    id: i32,
    name: []const u8,
    code: []const u8,
    parent_id: i32,
    sort: i32,
    status: i32,
    children: []MaterialCategoryTreeNode,
};
