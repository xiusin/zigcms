//! 分类仓储接口 (Category Repository Interface)
//!
//! 定义分类数据访问的抽象接口，具体实现在基础设施层。
//! 该接口遵循领域驱动设计原则，封装分类数据访问逻辑。

const std = @import("std");
const Category = @import("../entities/category.model.zig").Category;

/// 分类仓储接口类型
///
/// 使用通用的Repository.Interface(Category)来定义分类数据访问接口
pub const CategoryRepository = @import("mod.zig").Repository.Interface(Category);

/// 分类仓储接口的便捷类型别名
pub const Interface = CategoryRepository;

/// 分类仓储实现的辅助函数
pub fn create(ptr: *anyopaque, vtable: *const CategoryRepository.VTable) CategoryRepository {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}

/// 分类仓储实现示例（基础设施层使用）
///
/// 这个结构体展示了如何实现CategoryRepository接口
pub const CategoryRepositoryImpl = struct {
    allocator: std.mem.Allocator,

    /// 实现findById方法
    pub fn findById(ptr: *anyopaque, id: i32) !?Category {
        const self: *CategoryRepositoryImpl = @ptrCast(@alignCast(ptr));

        // 这里是基础设施层的具体实现
        // 实际实现会调用数据库或其他数据源
        _ = self; // 避免未使用警告

        // 示例实现：模拟查找分类
        if (id == 1) {
            return Category{
                .id = 1,
                .name = "技术文章",
                .code = "tech-articles",
                .category_type = "article",
                .status = 1,
            };
        }
        return null;
    }

    /// 实现findAll方法
    pub fn findAll(ptr: *anyopaque) ![]Category {
        const self: *CategoryRepositoryImpl = @ptrCast(@alignCast(ptr));

        // 示例实现：返回空数组
        _ = self;
        return &[_]Category{};
    }

    /// 实现save方法
    pub fn save(ptr: *anyopaque, category: Category) !Category {
        const self: *CategoryRepositoryImpl = @ptrCast(@alignCast(ptr));

        // 示例实现：简单返回分类（实际应保存到数据库）
        _ = self;
        var saved_category = category;
        if (saved_category.id == null) {
            saved_category.id = 1; // 分配新ID
        }
        saved_category.update_time = std.time.timestamp();
        return saved_category;
    }

    /// 实现update方法
    pub fn update(ptr: *anyopaque, category: Category) !void {
        const self: *CategoryRepositoryImpl = @ptrCast(@alignCast(ptr));

        // 示例实现：模拟更新
        _ = self;
        _ = category;
        // 实际实现会更新数据库
    }

    /// 实现delete方法
    pub fn delete(ptr: *anyopaque, id: i32) !void {
        const self: *CategoryRepositoryImpl = @ptrCast(@alignCast(ptr));

        // 示例实现：模拟删除
        _ = self;
        _ = id;
        // 实际实现会从数据库删除
    }

    /// 实现count方法
    pub fn count(ptr: *anyopaque) !usize {
        const self: *CategoryRepositoryImpl = @ptrCast(@alignCast(ptr));

        // 示例实现：返回0
        _ = self;
        return 0;
    }

    /// 创建vtable（供基础设施层使用）
    pub fn vtable() CategoryRepository.VTable {
        return .{
            .findById = findById,
            .findAll = findAll,
            .save = save,
            .update = update,
            .delete = delete,
            .count = count,
        };
    }
};
