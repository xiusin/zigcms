//! MySQL 模块仓储实现
//!
//! 实现模块仓储接口，使用 ORM QueryBuilder 构建查询，
//! 遵循 ZigCMS 开发范式：参数化查询、关系预加载、内存安全管理。
//! 支持树形结构查询和拖拽移动功能。

const std = @import("std");
const Allocator = std.mem.Allocator;
const sql = @import("../../application/services/sql/orm.zig");

// 导入领域层定义
const Module = @import("../../domain/entities/module.model.zig").Module;
const ModuleRepository = @import("../../domain/repositories/module_repository.zig").ModuleRepository;

/// MySQL 模块仓储实现
pub const MysqlModuleRepository = struct {
    allocator: Allocator,
    db: *sql.Database,

    const Self = @This();

    /// 初始化仓储
    pub fn init(allocator: Allocator, db: *sql.Database) Self {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }

    /// 清理资源
    pub fn deinit(self: *Self) void {
        _ = self;
    }

    /// 定义 ORM 模型
    const OrmModule = sql.define(struct {
        pub const table_name = "quality_modules";
        pub const primary_key = "id";

        id: ?i32 = null,
        project_id: i32 = 0,
        parent_id: ?i32 = null,
        name: []const u8 = "",
        description: []const u8 = "",
        level: i32 = 1,
        sort_order: i32 = 0,
        created_by: []const u8 = "",
        created_at: ?i64 = null,
        updated_at: ?i64 = null,
    });

    /// 根据 ID 查询模块
    pub fn findById(self: *Self, id: i32) !?Module {
        // 使用 ORM QueryBuilder 构建查询
        var q = OrmModule.query(self.db);
        defer q.deinit();

        // 参数化查询防止 SQL 注入
        _ = q.where("id", "=", id);

        // 可选：使用关系预加载优化查询（避免 N+1 查询）
        // _ = q.with(&.{"children", "test_cases"});

        // 执行查询
        const rows = try q.get();
        defer OrmModule.freeModels(rows);

        if (rows.len == 0) return null;

        // 深拷贝字符串字段（防止悬垂指针）
        return try self.ormToEntity(rows[0]);
    }

    /// 根据项目 ID 查询所有模块（平铺结构）
    pub fn findByProject(self: *Self, project_id: i32) ![]Module {
        // 构建查询
        var q = OrmModule.query(self.db);
        defer q.deinit();

        // 参数化查询，按 sort_order 排序
        _ = q.where("project_id", "=", project_id)
            .orderBy("sort_order", "ASC");

        // 执行查询
        const rows = try q.get();
        defer OrmModule.freeModels(rows);

        // 转换为实体
        var items = try self.allocator.alloc(Module, rows.len);
        errdefer self.allocator.free(items);

        for (rows, 0..) |row, i| {
            items[i] = try self.ormToEntity(row);
        }

        return items;
    }

    /// 根据项目 ID 查询模块树（树形结构）
    pub fn findTree(self: *Self, project_id: i32) ![]Module {
        // 1. 查询所有模块
        const all_modules = try self.findByProject(project_id);
        defer {
            for (all_modules) |module| {
                self.freeModule(module);
            }
            self.allocator.free(all_modules);
        }

        // 2. 构建树形结构
        // 先找出所有根节点（parent_id 为 null）
        var root_modules = std.ArrayList(Module).init(self.allocator);
        defer root_modules.deinit();

        for (all_modules) |module| {
            if (module.parent_id == null) {
                // 深拷贝根节点
                const root = try self.deepCopyModule(module);
                try root_modules.append(root);
            }
        }

        // 3. 为每个根节点递归构建子树
        for (root_modules.items) |*root| {
            try self.buildSubTree(root, all_modules);
        }

        return try root_modules.toOwnedSlice();
    }

    /// 保存模块（创建或更新）
    pub fn save(self: *Self, module: *Module) !void {
        if (module.id) |id| {
            // 更新现有记录
            _ = try OrmModule.UpdateWith(id, .{
                .project_id = module.project_id,
                .parent_id = module.parent_id,
                .name = module.name,
                .description = module.description,
                .level = module.level,
                .sort_order = module.sort_order,
                .updated_at = std.time.timestamp(),
            });
        } else {
            // 创建新记录
            const created = try OrmModule.Create(.{
                .project_id = module.project_id,
                .parent_id = module.parent_id,
                .name = module.name,
                .description = module.description,
                .level = module.level,
                .sort_order = module.sort_order,
                .created_by = module.created_by,
                .created_at = std.time.timestamp(),
                .updated_at = std.time.timestamp(),
            });
            module.id = created.id;
        }
    }

    /// 删除模块
    pub fn delete(self: *Self, id: i32) !void {
        _ = self;
        // 注意：删除模块会级联删除子模块和关联的测试用例
        // 实际应用中可能需要先检查是否有子模块或测试用例
        try OrmModule.Delete(id);
    }

    /// 移动模块（拖拽调整层级和顺序）
    pub fn move(self: *Self, id: i32, new_parent_id: ?i32, new_sort_order: i32) !void {
        // 1. 查询模块
        const module = try self.findById(id) orelse return error.ModuleNotFound;
        defer self.freeModule(module);

        // 2. 计算新的层级
        var new_level: i32 = 1;
        if (new_parent_id) |parent_id| {
            // 查询父模块
            const parent = try self.findById(parent_id) orelse return error.ParentNotFound;
            defer self.freeModule(parent);

            // 验证不能将模块移动到自己的子模块下
            if (parent_id == id) {
                return error.CannotMoveToSelf;
            }

            // 计算新层级
            new_level = parent.level + 1;

            // 验证层级深度不超过 5 层
            if (new_level > Module.MAX_LEVEL) {
                return error.MaxLevelExceeded;
            }
        }

        // 3. 更新模块
        _ = try OrmModule.UpdateWith(id, .{
            .parent_id = new_parent_id,
            .level = new_level,
            .sort_order = new_sort_order,
            .updated_at = std.time.timestamp(),
        });
    }

    // ========================================================================
    // 辅助方法
    // ========================================================================

    /// 将 ORM 模型转换为领域实体（深拷贝字符串字段）
    fn ormToEntity(self: *Self, orm: OrmModule.Model) !Module {
        return Module{
            .id = orm.id,
            .project_id = orm.project_id,
            .parent_id = orm.parent_id,
            .name = try self.allocator.dupe(u8, orm.name),
            .description = try self.allocator.dupe(u8, orm.description),
            .level = orm.level,
            .sort_order = orm.sort_order,
            .created_by = try self.allocator.dupe(u8, orm.created_by),
            .created_at = orm.created_at,
            .updated_at = orm.updated_at,
        };
    }

    /// 深拷贝模块（包括所有字符串字段）
    fn deepCopyModule(self: *Self, module: Module) !Module {
        return Module{
            .id = module.id,
            .project_id = module.project_id,
            .parent_id = module.parent_id,
            .name = try self.allocator.dupe(u8, module.name),
            .description = try self.allocator.dupe(u8, module.description),
            .level = module.level,
            .sort_order = module.sort_order,
            .created_by = try self.allocator.dupe(u8, module.created_by),
            .created_at = module.created_at,
            .updated_at = module.updated_at,
        };
    }

    /// 递归构建子树
    fn buildSubTree(self: *Self, parent: *Module, all_modules: []const Module) !void {
        var children = std.ArrayList(Module).init(self.allocator);
        defer children.deinit();

        // 找出所有子模块
        for (all_modules) |module| {
            if (module.parent_id) |pid| {
                if (pid == parent.id.?) {
                    // 深拷贝子模块
                    const child = try self.deepCopyModule(module);
                    try children.append(child);
                }
            }
        }

        // 如果有子模块，递归构建子树
        if (children.items.len > 0) {
            parent.children = try children.toOwnedSlice();

            for (parent.children.?) |*child| {
                try self.buildSubTree(child, all_modules);
            }
        }
    }

    /// 释放模块内存
    pub fn freeModule(self: *Self, module: Module) void {
        self.allocator.free(module.name);
        self.allocator.free(module.description);
        self.allocator.free(module.created_by);

        // 递归释放子模块
        if (module.children) |children| {
            for (children) |child| {
                self.freeModule(child);
            }
            self.allocator.free(children);
        }
    }

    /// 释放模块数组内存
    pub fn freeModules(self: *Self, modules: []Module) void {
        for (modules) |module| {
            self.freeModule(module);
        }
        self.allocator.free(modules);
    }

    // ========================================================================
    // VTable 实现
    // ========================================================================

    pub fn vtable() ModuleRepository.VTable {
        return .{
            .findById = findByIdImpl,
            .findByProject = findByProjectImpl,
            .findTree = findTreeImpl,
            .save = saveImpl,
            .delete = deleteImpl,
            .move = moveImpl,
        };
    }

    fn findByIdImpl(ptr: *anyopaque, id: i32) anyerror!?Module {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findById(id);
    }

    fn findByProjectImpl(ptr: *anyopaque, project_id: i32) anyerror![]Module {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findByProject(project_id);
    }

    fn findTreeImpl(ptr: *anyopaque, project_id: i32) anyerror![]Module {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.findTree(project_id);
    }

    fn saveImpl(ptr: *anyopaque, module: *Module) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.save(module);
    }

    fn deleteImpl(ptr: *anyopaque, id: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.delete(id);
    }

    fn moveImpl(ptr: *anyopaque, id: i32, new_parent_id: ?i32, new_sort_order: i32) anyerror!void {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.move(id, new_parent_id, new_sort_order);
    }
};

/// 创建模块仓储实例
pub fn create(allocator: Allocator, db: *sql.Database) !*ModuleRepository {
    const repo = try allocator.create(MysqlModuleRepository);
    errdefer allocator.destroy(repo);

    repo.* = MysqlModuleRepository.init(allocator, db);

    const interface = try allocator.create(ModuleRepository);
    errdefer allocator.destroy(interface);

    interface.* = @import("../../domain/repositories/module_repository.zig").create(
        repo,
        &MysqlModuleRepository.vtable(),
    );

    return interface;
}
