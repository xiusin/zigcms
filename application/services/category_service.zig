//! 分类应用服务 (Category Application Service)
//!
//! 应用层分类服务，实现分类相关的业务逻辑。
//! 该服务协调领域层实体和仓储，处理复杂的业务用例。

const std = @import("std");
const Category = @import("../../domain/entities/category.model.zig").Category;
const CategoryRepository = @import("../../domain/repositories/category_repository.zig").CategoryRepository;

/// 分类应用服务
///
/// 应用层服务，负责协调领域对象，处理业务用例逻辑。
/// 遵循应用服务模式，封装分类相关的业务流程。
pub const CategoryService = struct {
    allocator: std.mem.Allocator,
    category_repository: CategoryRepository,

    /// 初始化分类服务
    pub fn init(allocator: std.mem.Allocator, category_repository: CategoryRepository) CategoryService {
        return .{
            .allocator = allocator,
            .category_repository = category_repository,
        };
    }

    /// 根据ID获取分类
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 返回
    /// 分类实体，如果不存在返回null
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getCategory(self: *CategoryService, category_id: i32) !?Category {
        // 调用领域层仓储接口
        const category = try self.category_repository.findById(category_id);
        return category;
    }

    /// 创建新分类
    ///
    /// ## 参数
    /// - `name`: 分类名称
    /// - `code`: 分类编码
    /// - `category_type`: 分类类型
    /// - `parent_id`: 父分类ID
    ///
    /// ## 返回
    /// 创建的分类实体
    ///
    /// ## 错误
    /// - 分类名称或编码无效
    /// - 仓储层错误
    pub fn createCategory(self: *CategoryService, name: []const u8, code: []const u8, category_type: []const u8, parent_id: i32) !Category {
        // 业务规则验证
        if (!Category.isValidName(Category{}, name)) {
            return error.InvalidCategoryName;
        }

        if (!Category.isValidCode(Category{}, code)) {
            return error.InvalidCategoryCode;
        }

        // 创建分类实体
        const category = Category.create(name, code, category_type, parent_id);

        // 保存到仓储
        const saved_category = try self.category_repository.save(category);

        return saved_category;
    }

    /// 更新分类基本信息
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    /// - `name`: 新名称（可选）
    /// - `description`: 新描述（可选）
    /// - `icon`: 新图标（可选）
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 参数无效
    /// - 仓储层错误
    pub fn updateCategoryInfo(self: *CategoryService, category_id: i32, name: ?[]const u8, description: ?[]const u8, icon: ?[]const u8) !void {
        // 验证名称格式
        if (name) |n| {
            if (!Category.isValidName(Category{}, n)) {
                return error.InvalidCategoryName;
            }
        }

        // 获取现有分类
        const existing_category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        // 复制分类进行修改（避免直接修改）
        var category = existing_category;
        category.updateInfo(name, description, icon);

        // 保存更新
        try self.category_repository.update(category);
    }

    /// 更新分类SEO信息
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    /// - `title`: SEO标题（可选）
    /// - `keywords`: SEO关键词（可选）
    /// - `description`: SEO描述（可选）
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 仓储层错误
    pub fn updateCategorySeo(self: *CategoryService, category_id: i32, title: ?[]const u8, keywords: ?[]const u8, seo_description: ?[]const u8) !void {
        // 获取现有分类
        const existing_category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        var category = existing_category;
        category.updateSeo(title, keywords, seo_description);

        // 保存更新
        try self.category_repository.update(category);
    }

    /// 移动分类到新的父分类
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    /// - `new_parent_id`: 新父分类ID
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 父分类不存在
    /// - 不能移动到自己或子分类下
    /// - 仓储层错误
    pub fn moveCategory(self: *CategoryService, category_id: i32, new_parent_id: i32) !void {
        // 获取要移动的分类
        const category_to_move = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        // 验证新父分类存在（如果不是顶级分类）
        if (new_parent_id != 0) {
            _ = try self.category_repository.findById(new_parent_id) orelse {
                return error.ParentCategoryNotFound;
            };
        }

        // 检查是否可以移动
        if (!(try category_to_move.canMoveTo(new_parent_id, self.category_repository))) {
            return error.InvalidMove;
        }

        var updated_category = category_to_move;
        updated_category.setParent(new_parent_id);

        // 保存更新
        try self.category_repository.update(updated_category);
    }

    /// 增加分类访问量
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 仓储层错误
    pub fn incrementCategoryViews(self: *CategoryService, category_id: i32) !void {
        const category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        var updated_category = category;
        updated_category.incrementViews();
        try self.category_repository.update(updated_category);
    }

    /// 启用分类
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 仓储层错误
    pub fn enableCategory(self: *CategoryService, category_id: i32) !void {
        const category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        var updated_category = category;
        updated_category.enable();
        try self.category_repository.update(updated_category);
    }

    /// 禁用分类
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 仓储层错误
    pub fn disableCategory(self: *CategoryService, category_id: i32) !void {
        const category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        var updated_category = category;
        updated_category.disable();
        try self.category_repository.update(updated_category);
    }

    /// 删除分类
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 分类下有子分类（需要先删除子分类）
    /// - 仓储层错误
    pub fn deleteCategory(self: *CategoryService, category_id: i32) !void {
        // 验证分类存在
        const category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        // 检查是否有子分类（实际实现需要仓储层支持）
        const children_count = try category.getChildrenCount(self.category_repository);
        if (children_count > 0) {
            return error.HasChildCategories;
        }

        // 删除分类
        try self.category_repository.delete(category_id);
    }

    /// 获取分类的完整路径
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 返回
    /// 分类的完整路径字符串
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 仓储层错误
    pub fn getCategoryPath(self: *CategoryService, category_id: i32) ![]const u8 {
        const category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        return try category.getFullPath(self.allocator, self.category_repository);
    }

    /// 获取分类的层级深度
    ///
    /// ## 参数
    /// - `category_id`: 分类ID
    ///
    /// ## 返回
    /// 分类的层级深度
    ///
    /// ## 错误
    /// - 分类不存在
    /// - 仓储层错误
    pub fn getCategoryDepth(self: *CategoryService, category_id: i32) !i32 {
        const category = try self.category_repository.findById(category_id) orelse {
            return error.CategoryNotFound;
        };

        return try category.getDepth(self.category_repository);
    }

    /// 获取分类统计信息
    ///
    /// ## 返回
    /// 分类总数
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getCategoryCount(self: *CategoryService) !usize {
        return try self.category_repository.count();
    }

    /// 获取所有分类
    ///
    /// ## 返回
    /// 分类列表
    ///
    /// ## 注意
    /// 这个方法可能返回大量数据，生产环境中应该分页
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getAllCategories(self: *CategoryService) ![]Category {
        return try self.category_repository.findAll();
    }

    /// 获取顶级分类
    ///
    /// ## 返回
    /// 顶级分类列表
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getRootCategories(self: *CategoryService) ![]Category {
        // 实际实现需要仓储层支持按条件查询
        // 这里返回所有分类的简化版本
        const all_categories = try self.category_repository.findAll();
        defer self.allocator.free(all_categories);

        // 过滤顶级分类
        var root_categories = std.ArrayList(Category).init(self.allocator);
        defer root_categories.deinit();

        for (all_categories) |category| {
            if (category.isRoot()) {
                try root_categories.append(category);
            }
        }

        return root_categories.toOwnedSlice();
    }

    /// 获取分类树形结构
    ///
    /// ## 参数
    /// - `category_type`: 分类类型筛选（可选）
    /// - `include_inactive`: 是否包含未启用的分类
    ///
    /// ## 返回
    /// 完整的分类树形结构
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getCategoryTree(self: *CategoryService, category_type: ?[]const u8, include_inactive: bool) ![]CategoryTreeNode {
        // 获取所有分类
        const all_categories = try self.category_repository.findAll();
        defer self.allocator.free(all_categories);

        // 应用筛选条件
        var filtered_categories = std.ArrayList(Category).init(self.allocator);
        defer filtered_categories.deinit();

        for (all_categories) |category| {
            // 类型筛选
            if (category_type) |ct| {
                if (!std.mem.eql(u8, category.category_type, ct)) {
                    continue;
                }
            }

            // 状态筛选
            if (!include_inactive and !category.isActive()) {
                continue;
            }

            try filtered_categories.append(category);
        }

        // 构建树形结构
        return try self.buildCategoryTree(filtered_categories.items);
    }

    /// 构建分类树形结构
    fn buildCategoryTree(self: *CategoryService, categories: []const Category) ![]CategoryTreeNode {
        var result = std.ArrayList(CategoryTreeNode).init(self.allocator);
        defer result.deinit();

        // 找到顶级分类并递归构建
        for (categories) |category| {
            if (category.isRoot()) {
                const node = try self.buildTreeNode(categories, category);
                try result.append(node);
            }
        }

        return result.toOwnedSlice();
    }

    /// 构建树节点
    fn buildTreeNode(self: *CategoryService, categories: []const Category, category: Category) !CategoryTreeNode {
        if (category.id == null) {
            return error.InvalidCategory;
        }

        // 创建节点
        var node = CategoryTreeNode{
            .id = category.id.?,
            .name = try self.allocator.dupe(u8, category.name),
            .code = try self.allocator.dupe(u8, category.code),
            .parent_id = category.parent_id,
            .category_type = try self.allocator.dupe(u8, category.category_type),
            .sort = category.sort,
            .status = category.status,
            .children = undefined, // 稍后设置
        };

        // 查找子分类
        var children = std.ArrayList(CategoryTreeNode).init(self.allocator);
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

    /// 获取分类选项（用于下拉框）
    ///
    /// ## 参数
    /// - `category_type`: 分类类型筛选（可选）
    /// - `include_inactive`: 是否包含未启用的分类
    ///
    /// ## 返回
    /// 分类选项列表
    ///
    /// ## 错误
    /// - 仓储层错误
    pub fn getCategoryOptions(self: *CategoryService, category_type: ?[]const u8, include_inactive: bool) ![]CategoryOption {
        const categories = try self.category_repository.findAll();
        defer self.allocator.free(categories);

        var options = std.ArrayList(CategoryOption).init(self.allocator);
        defer options.deinit();

        for (categories) |category| {
            // 类型筛选
            if (category_type) |ct| {
                if (!std.mem.eql(u8, category.category_type, ct)) {
                    continue;
                }
            }

            // 状态筛选
            if (!include_inactive and !category.isActive()) {
                continue;
            }

            if (category.id) |id| {
                const option = CategoryOption{
                    .value = id,
                    .label = try self.allocator.dupe(u8, category.name),
                };
                try options.append(option);
            }
        }

        return options.toOwnedSlice();
    }
};

/// 分类树节点
pub const CategoryTreeNode = struct {
    id: i32,
    name: []const u8,
    code: []const u8,
    parent_id: i32,
    category_type: []const u8,
    sort: i32,
    status: i32,
    children: []CategoryTreeNode,

    /// 释放树节点内存
    pub fn deinit(self: *CategoryTreeNode, allocator: std.mem.Allocator) void {
        allocator.free(self.name);
        allocator.free(self.code);
        allocator.free(self.category_type);

        for (self.children) |*child| {
            child.deinit(allocator);
        }
        allocator.free(self.children);
    }
};

/// 分类选项
pub const CategoryOption = struct {
    value: i32,
    label: []const u8,

    /// 释放选项内存
    pub fn deinit(self: *CategoryOption, allocator: std.mem.Allocator) void {
        allocator.free(self.label);
    }
};
