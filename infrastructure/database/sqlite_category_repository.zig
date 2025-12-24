//! SQLite 分类仓储实现 (SQLite Category Repository Implementation)
//
//! 基础设施层分类仓储的具体实现，使用SQLite数据库。
//! 实现领域层定义的CategoryRepository接口。

const std = @import("std");
const sql = @import("../../application/services/sql/orm.zig");
const Category = @import("../../domain/entities/category.model.zig").Category;
const CategoryRepository = @import("../../domain/repositories/category_repository.zig").CategoryRepository;

/// SQLite 分类仓储实现
///
/// 实现CategoryRepository接口，负责分类数据的持久化。
/// 使用项目的ORM模块与SQLite数据库交互。
pub const SqliteCategoryRepository = struct {
    allocator: std.mem.Allocator,
    db: *sql.Database,

    /// 初始化SQLite分类仓储
    pub fn init(allocator: std.mem.Allocator, db: *sql.Database) SqliteCategoryRepository {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    /// 实现findById方法
    pub fn findById(ptr: *anyopaque, id: i32) !?Category {
        const self: *SqliteCategoryRepository = @ptrCast(@alignCast(ptr));

        // 使用Database.rawQuery查询分类
        const query = "SELECT id, name, code, parent_id, category_type, description, cover_image, icon, sort, status, seo_title, seo_keywords, seo_description, views, remark, create_time, update_time, is_delete FROM categories WHERE id = ? AND is_delete = 0";
        var result_set = try self.db.rawQuery(query, .{id});
        defer result_set.deinit();

        if (!result_set.next()) {
            return null;
        }

        // 构建Category实体
        return Category{
            .id = try result_set.get(i32, 0),
            .name = try self.allocator.dupe(u8, try result_set.get([]const u8, 1)),
            .code = try self.allocator.dupe(u8, try result_set.get([]const u8, 2)),
            .parent_id = try result_set.get(i32, 3),
            .category_type = try self.allocator.dupe(u8, try result_set.get([]const u8, 4)),
            .description = try self.allocator.dupe(u8, try result_set.get([]const u8, 5)),
            .cover_image = try self.allocator.dupe(u8, try result_set.get([]const u8, 6)),
            .icon = try self.allocator.dupe(u8, try result_set.get([]const u8, 7)),
            .sort = try result_set.get(i32, 8),
            .status = try result_set.get(i32, 9),
            .seo_title = try self.allocator.dupe(u8, try result_set.get([]const u8, 10)),
            .seo_keywords = try self.allocator.dupe(u8, try result_set.get([]const u8, 11)),
            .seo_description = try self.allocator.dupe(u8, try result_set.get([]const u8, 12)),
            .views = try result_set.get(i32, 13),
            .remark = try self.allocator.dupe(u8, try result_set.get([]const u8, 14)),
            .create_time = try result_set.get(?i64, 15),
            .update_time = try result_set.get(?i64, 16),
            .is_delete = try result_set.get(i32, 17),
        };
    }

    /// 实现findAll方法
    pub fn findAll(ptr: *anyopaque) ![]Category {
        const self: *SqliteCategoryRepository = @ptrCast(@alignCast(ptr));

        // 查询所有未删除的分类
        const query = "SELECT id, name, code, parent_id, category_type, description, cover_image, icon, sort, status, seo_title, seo_keywords, seo_description, views, remark, create_time, update_time, is_delete FROM categories WHERE is_delete = 0 ORDER BY sort ASC, create_time DESC";
        var result_set = try self.db.rawQuery(query, .{});
        defer result_set.deinit();

        // 转换为Category数组
        var categories = try std.ArrayList(Category).initCapacity(self.allocator, 16);
        defer categories.deinit(self.allocator);

        while (result_set.next()) {
            const category = Category{
                .id = try result_set.get(i32, 0),
                .name = try self.allocator.dupe(u8, try result_set.get([]const u8, 1)),
                .code = try self.allocator.dupe(u8, try result_set.get([]const u8, 2)),
                .parent_id = try result_set.get(i32, 3),
                .category_type = try self.allocator.dupe(u8, try result_set.get([]const u8, 4)),
                .description = try self.allocator.dupe(u8, try result_set.get([]const u8, 5)),
                .cover_image = try self.allocator.dupe(u8, try result_set.get([]const u8, 6)),
                .icon = try self.allocator.dupe(u8, try result_set.get([]const u8, 7)),
                .sort = try result_set.get(i32, 8),
                .status = try result_set.get(i32, 9),
                .seo_title = try self.allocator.dupe(u8, try result_set.get([]const u8, 10)),
                .seo_keywords = try self.allocator.dupe(u8, try result_set.get([]const u8, 11)),
                .seo_description = try self.allocator.dupe(u8, try result_set.get([]const u8, 12)),
                .views = try result_set.get(i32, 13),
                .remark = try self.allocator.dupe(u8, try result_set.get([]const u8, 14)),
                .create_time = try result_set.get(?i64, 15),
                .update_time = try result_set.get(?i64, 16),
                .is_delete = try result_set.get(i32, 17),
            };
            try categories.append(self.allocator, category);
        }

        return categories.toOwnedSlice(self.allocator);
    }

    /// 实现save方法
    pub fn save(ptr: *anyopaque, category: Category) !Category {
        const self: *SqliteCategoryRepository = @ptrCast(@alignCast(ptr));

        // 检查是否为新分类
        const is_new = category.id == null;

        if (is_new) {
            // 插入新分类
            const insert_query = "INSERT INTO categories (name, code, parent_id, category_type, description, cover_image, icon, sort, status, seo_title, seo_keywords, seo_description, views, remark, create_time, update_time, is_delete) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)";
            const now = std.time.timestamp();
            _ = try self.db.rawExec(insert_query, .{
                category.name,
                category.code,
                category.parent_id,
                category.category_type,
                category.description,
                category.cover_image,
                category.icon,
                category.sort,
                category.status,
                category.seo_title,
                category.seo_keywords,
                category.seo_description,
                category.views,
                category.remark,
                now,
                now,
            });

            // 获取插入的ID
            const last_id = self.db.lastInsertId();

            // 返回包含ID的分类
            return Category{
                .id = @as(i32, @intCast(last_id)),
                .name = try self.allocator.dupe(u8, category.name),
                .code = try self.allocator.dupe(u8, category.code),
                .parent_id = category.parent_id,
                .category_type = try self.allocator.dupe(u8, category.category_type),
                .description = try self.allocator.dupe(u8, category.description),
                .cover_image = try self.allocator.dupe(u8, category.cover_image),
                .icon = try self.allocator.dupe(u8, category.icon),
                .sort = category.sort,
                .status = category.status,
                .seo_title = try self.allocator.dupe(u8, category.seo_title),
                .seo_keywords = try self.allocator.dupe(u8, category.seo_keywords),
                .seo_description = try self.allocator.dupe(u8, category.seo_description),
                .views = category.views,
                .remark = try self.allocator.dupe(u8, category.remark),
                .create_time = now,
                .update_time = now,
                .is_delete = 0,
            };
        } else {
            // 更新现有分类
            const update_query = "UPDATE categories SET name = ?, code = ?, parent_id = ?, category_type = ?, description = ?, cover_image = ?, icon = ?, sort = ?, status = ?, seo_title = ?, seo_keywords = ?, seo_description = ?, views = ?, remark = ?, update_time = ? WHERE id = ? AND is_delete = 0";
            const now = std.time.timestamp();
            _ = try self.db.rawExec(update_query, .{
                category.name,
                category.code,
                category.parent_id,
                category.category_type,
                category.description,
                category.cover_image,
                category.icon,
                category.sort,
                category.status,
                category.seo_title,
                category.seo_keywords,
                category.seo_description,
                category.views,
                category.remark,
                now,
                category.id.?,
            });

            // 返回更新后的分类
            return Category{
                .id = category.id,
                .name = try self.allocator.dupe(u8, category.name),
                .code = try self.allocator.dupe(u8, category.code),
                .parent_id = category.parent_id,
                .category_type = try self.allocator.dupe(u8, category.category_type),
                .description = try self.allocator.dupe(u8, category.description),
                .cover_image = try self.allocator.dupe(u8, category.cover_image),
                .icon = try self.allocator.dupe(u8, category.icon),
                .sort = category.sort,
                .status = category.status,
                .seo_title = try self.allocator.dupe(u8, category.seo_title),
                .seo_keywords = try self.allocator.dupe(u8, category.seo_keywords),
                .seo_description = try self.allocator.dupe(u8, category.seo_description),
                .views = category.views,
                .remark = try self.allocator.dupe(u8, category.remark),
                .create_time = category.create_time,
                .update_time = now,
                .is_delete = 0,
            };
        }
    }

    /// 实现update方法
    pub fn update(ptr: *anyopaque, category: Category) !void {
        const self: *SqliteCategoryRepository = @ptrCast(@alignCast(ptr));

        if (category.id == null) {
            return error.InvalidCategoryId;
        }

        const query = "UPDATE categories SET name = ?, code = ?, parent_id = ?, category_type = ?, description = ?, cover_image = ?, icon = ?, sort = ?, status = ?, seo_title = ?, seo_keywords = ?, seo_description = ?, views = ?, remark = ?, update_time = ? WHERE id = ? AND is_delete = 0";
        const now = std.time.timestamp();
        _ = try self.db.rawExec(query, .{
            category.name,
            category.code,
            category.parent_id,
            category.category_type,
            category.description,
            category.cover_image,
            category.icon,
            category.sort,
            category.status,
            category.seo_title,
            category.seo_keywords,
            category.seo_description,
            category.views,
            category.remark,
            now,
            category.id.?,
        });
    }

    /// 实现delete方法（软删除）
    pub fn delete(ptr: *anyopaque, id: i32) !void {
        const self: *SqliteCategoryRepository = @ptrCast(@alignCast(ptr));

        const query = "UPDATE categories SET is_delete = 1, update_time = ? WHERE id = ? AND is_delete = 0";
        const now = std.time.timestamp();
        _ = try self.db.rawExec(query, .{ now, id });
    }

    /// 实现count方法
    pub fn count(ptr: *anyopaque) !usize {
        const self: *SqliteCategoryRepository = @ptrCast(@alignCast(ptr));

        const query = "SELECT COUNT(*) as count FROM categories WHERE is_delete = 0";
        var result_set = try self.db.rawQuery(query, .{});
        defer result_set.deinit();

        if (!result_set.next()) {
            return 0;
        }

        return @as(usize, @intCast(try result_set.get(i64, 0)));
    }

    /// 创建vtable（供CategoryRepository使用）
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
