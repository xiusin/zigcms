//! 分类管理控制器
//!
//! 提供分类的 CRUD 操作及树形结构管理
//! 遵循清洁架构，使用应用层服务处理业务逻辑

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const CategoryService = @import("../../application/services/category_service.zig").CategoryService;
const json_mod = @import("../../application/services/json/json.zig");
const strings = @import("../../shared/utils/strings.zig");
const mw = @import("../middleware/mod.zig");

const Self = @This();
const MW = mw.Controller(Self);

allocator: Allocator,
category_service: *CategoryService,

/// 初始化控制器
pub fn init(allocator: Allocator, category_service: *CategoryService) Self {
    return .{
        .allocator = allocator,
        .category_service = category_service,
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

/// 获取树形结构
pub const tree = MW.requireAuth(treeImpl);

/// 获取分类选项（用于下拉框）
pub const select = MW.requireAuth(selectImpl);

// ============================================================================
// 实现方法
// ============================================================================

/// 分页列表实现
fn listImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    // 解析查询参数
    var query_params = std.StringHashMap([]const u8).init(self.allocator);
    defer query_params.deinit();

    var it = r.queryParameters();
    while (it.next()) |param| {
        if (param.key) |key| {
            if (param.value) |value| {
                try query_params.put(key, value);
            }
        }
    }

    // 解析分页参数
    const page = query_params.get("page") orelse "1";
    const page_size = query_params.get("page_size") orelse "20";

    const page_num = std.fmt.parseInt(u32, page, 10) catch 1;
    const page_num_size = std.fmt.parseInt(u32, page_size, 10) catch 20;

    // 构建筛选条件
    var filters = CategoryService.CategoryFilters{};

    if (query_params.get("category_type")) |category_type| {
        filters.category_type = category_type;
    }

    if (query_params.get("status")) |status_str| {
        if (std.fmt.parseInt(i32, status_str, 10)) |status| {
            filters.status = status;
        } else |_| {}
    }

    if (query_params.get("keyword")) |keyword| {
        filters.keyword = keyword;
    }

    // 使用服务分页查询
    const result = try self.category_service.getCategoriesWithPagination(page_num, page_num_size, filters);
    defer {
        for (result.data) |_| {}
        self.allocator.free(result.data);
    }

    try base.send_ok(response, .{
        .data = result.data,
        .page = result.page,
        .page_size = result.page_size,
        .total_count = result.total_count,
        .total_pages = result.total_pages,
    });
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

    // 使用应用层服务获取分类
    if (try self.category_service.getCategory(id)) |category| {
        try base.send_ok(response, category);
    } else {
        try base.send_failed(response, "分类不存在");
    }
}

/// 保存实现
fn saveImpl(self: Self, r: zap.Request, response: zap.Response) !void {
    const body = r.body orelse {
        base.send_error(response, "请求体为空");
        return;
    };

    const CategoryCreateDto = @import("../dto/category_create.dto.zig").CategoryCreateDto;
    const dto = json_mod.parse(CategoryCreateDto, self.allocator, body) catch {
        base.send_error(response, "JSON格式错误");
        return;
    };
    defer json_mod.free(self.allocator, dto);

    // 使用应用层服务创建分类（包含所有业务验证）
    const category = self.category_service.createCategory(dto.name, dto.code, dto.category_type, dto.parent_id) catch |err| switch (err) {
        error.InvalidCategoryName => base.send_error(response, "无效的分类名称"),
        error.InvalidCategoryCode => base.send_error(response, "无效的分类编码"),
        else => {
            base.send_error(response, "创建分类失败");
            return err;
        },
    };

    try base.send_ok(response, category);
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

    // 使用应用层服务删除分类（包含子分类检查）
    try self.category_service.deleteCategory(id) catch |err| switch (err) {
        error.CategoryNotFound => base.send_failed(response, "分类不存在"),
        error.HasChildCategories => base.send_error(response, "该分类下还有子分类，无法删除"),
        else => {
            base.send_error(response, "删除失败");
            return err;
        },
    };

    try base.send_ok(response, .{ .message = "删除成功" });
}

/// 树形结构实现
fn treeImpl(self: Self, r: zap.Request, response: zap.Response) !void {
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

    // 获取分类类型筛选参数
    var category_type: ?[]const u8 = null;
    if (query_params.get("category_type")) |ct| {
        if (ct.len > 0) {
            category_type = ct;
        }
    }

    // 构建完整的分类树形结构
    const tree_nodes = try self.category_service.getCategoryTree(category_type, false);
    defer {
        // 释放树形结构内存
        for (tree_nodes) |*node| {
            node.deinit(self.allocator);
        }
        self.allocator.free(tree_nodes);
    }

    try base.send_ok(response, tree_nodes);
}

/// 分类选项实现
fn selectImpl(self: Self, r: zap.Request, response: zap.Response) !void {
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

    // 获取分类类型筛选参数
    var category_type: ?[]const u8 = null;
    if (query_params.get("category_type")) |ct| {
        if (ct.len > 0) {
            category_type = ct;
        }
    }

    // 获取分类选项
    const options = try self.category_service.getCategoryOptions(category_type, false);
    defer {
        // 释放选项内存
        for (options) |*option| {
            option.deinit(self.allocator);
        }
        self.allocator.free(options);
    }

    try base.send_ok(response, options);
}
