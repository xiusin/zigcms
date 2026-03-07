//! 模块服务
//!
//! 提供模块管理的业务逻辑编排,包括:
//! - 创建、更新、删除模块
//! - 构建模块树形结构
//! - 拖拽移动模块
//! - 模块统计数据计算
//!
//! ## 设计原则
//!
//! - **职责单一**: Service 只做业务编排,不直接操作数据库
//! - **依赖抽象**: 依赖仓储接口和缓存接口,不依赖具体实现
//! - **内存安全**: 使用 errdefer 确保资源正确释放
//! - **缓存策略**: 查询带缓存,更新/删除清除缓存
//! - **层级限制**: 模块层级深度不超过 5 层
//!
//! ## 使用示例
//!
//! ```zig
//! const service = ModuleService.init(
//!     allocator,
//!     module_repo,
//!     test_case_repo,
//!     cache,
//! );
//!
//! // 创建模块
//! var module = Module{
//!     .project_id = 1,
//!     .name = "用户管理",
//!     .description = "用户管理模块",
//!     .created_by = "admin",
//! };
//! try service.create(&module);
//!
//! // 获取模块树
//! const tree = try service.getTree(1);
//! defer service.freeModuleList(tree);
//! ```

const std = @import("std");
const Module = @import("../../domain/entities/module.model.zig").Module;
const ModuleRepository = @import("../../domain/repositories/module_repository.zig").ModuleRepository;
const TestCaseRepository = @import("../../domain/repositories/test_case_repository.zig").TestCaseRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const CacheInterface = @import("cache/contract.zig").CacheInterface;
const qc_cache = @import("../../infrastructure/cache/quality_center_cache.zig");

const Allocator = std.mem.Allocator;

/// 模块统计数据
pub const ModuleStatistics = struct {
    module_id: i32,
    test_case_count: i32 = 0, // 用例总数
    pass_rate: f32 = 0.0, // 通过率
    bug_count: i32 = 0, // Bug 数量
    coverage_rate: f32 = 0.0, // 覆盖率
};

/// 模块服务
///
/// 负责模块管理的业务逻辑编排,遵循整洁架构原则。
pub const ModuleService = struct {
    allocator: Allocator,
    module_repo: ModuleRepository,
    test_case_repo: TestCaseRepository,
    cache: CacheInterface,

    const Self = @This();

    /// 最大层级深度
    pub const MAX_LEVEL: i32 = 5;

    /// 初始化模块服务
    ///
    /// 参数:
    /// - allocator: 内存分配器
    /// - module_repo: 模块仓储接口
    /// - test_case_repo: 测试用例仓储接口
    /// - cache: 缓存接口
    ///
    /// 返回:
    /// - ModuleService 实例
    pub fn init(
        allocator: Allocator,
        module_repo: ModuleRepository,
        test_case_repo: TestCaseRepository,
        cache: CacheInterface,
    ) Self {
        return .{
            .allocator = allocator,
            .module_repo = module_repo,
            .test_case_repo = test_case_repo,
            .cache = cache,
        };
    }

    // ========================================
    // 创建、更新、删除操作
    // ========================================

    /// 创建模块
    ///
    /// 验证必填字段和层级深度后创建模块,并清除相关缓存。
    ///
    /// 参数:
    /// - module: 模块对象指针
    ///
    /// 错误:
    /// - NameRequired: 模块名称为空
    /// - ProjectIdRequired: 项目 ID 为 0
    /// - LevelTooDeep: 层级深度超过 5 层
    ///
    /// 需求: 4.1, 4.3, 4.10
    pub fn create(self: *Self, module: *Module) !void {
        // 1. 验证必填字段
        if (module.name.len == 0) return error.NameRequired;
        if (module.project_id == 0) return error.ProjectIdRequired;

        // 2. 计算层级深度
        if (module.parent_id) |parent_id| {
            const parent = try self.module_repo.findById(parent_id) orelse {
                return error.ParentModuleNotFound;
            };
            defer self.freeModule(parent);

            module.level = parent.level + 1;

            // 验证层级深度不超过 5 层
            if (module.level > MAX_LEVEL) {
                return error.LevelTooDeep;
            }
        } else {
            module.level = 1;
        }

        // 3. 设置创建时间
        if (module.created_at == null) {
            module.created_at = std.time.timestamp();
        }
        module.updated_at = module.created_at;

        // 4. 保存到数据库
        try self.module_repo.save(module);

        // 5. 清除相关缓存
        try self.clearModuleCache(module.project_id);
    }

    /// 更新模块
    ///
    /// 查询模块,更新字段后保存,并清除相关缓存。
    ///
    /// 参数:
    /// - id: 模块 ID
    /// - module: 包含更新字段的模块对象
    ///
    /// 错误:
    /// - ModuleNotFound: 模块不存在
    /// - NameRequired: 模块名称为空
    ///
    /// 需求: 4.2
    pub fn update(self: *Self, id: i32, module: *const Module) !void {
        // 1. 查询现有模块
        const existing = try self.module_repo.findById(id) orelse {
            return error.ModuleNotFound;
        };
        defer self.freeModule(existing);

        // 2. 验证更新后的数据
        if (module.name.len == 0) return error.NameRequired;

        // 3. 创建更新后的模块
        var updated = module.*;
        updated.id = id;
        updated.updated_at = std.time.timestamp();

        // 4. 保存到数据库
        try self.module_repo.save(&updated);

        // 5. 清除相关缓存
        try self.clearModuleCache(existing.project_id);
    }

    /// 删除模块
    ///
    /// 删除模块并清除相关缓存。
    ///
    /// 参数:
    /// - id: 模块 ID
    ///
    /// 需求: 4.2
    pub fn delete(self: *Self, id: i32) !void {
        // 1. 查询模块获取项目 ID(用于清除缓存)
        const module = try self.module_repo.findById(id) orelse {
            return error.ModuleNotFound;
        };
        defer self.freeModule(module);

        const project_id = module.project_id;

        // 2. 删除模块
        try self.module_repo.delete(id);

        // 3. 清除相关缓存
        try self.clearModuleCache(project_id);
    }

    // ========================================
    // 查询操作
    // ========================================

    /// 根据 ID 查询模块
    ///
    /// 参数:
    /// - id: 模块 ID
    ///
    /// 返回:
    /// - 模块对象(调用者拥有所有权,必须调用 freeModule 释放)
    /// - null(如果不存在)
    ///
    /// 需求: 4.1
    pub fn findById(self: *Self, id: i32) !?Module {
        return try self.module_repo.findById(id);
    }

    /// 获取模块树(带缓存)
    ///
    /// 构建项目下所有模块的树形结构。
    ///
    /// 参数:
    /// - project_id: 项目 ID
    ///
    /// 返回:
    /// - 模块数组(树形结构,调用者拥有所有权,必须调用 freeModuleList 释放)
    ///
    /// 需求: 4.1, 12.5
    pub fn getTree(self: *Self, project_id: i32) ![]Module {
        // 1. 构建缓存键
        const cache_key = try qc_cache.moduleTreeKey(self.allocator, project_id);
        defer self.allocator.free(cache_key);

        // 2. 尝试从缓存获取
        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializeModuleList(cached);
        }

        // 3. 从数据库查询
        const tree = try self.module_repo.findTree(project_id);

        // 4. 缓存结果(5 分钟)
        const json = try self.serializeModuleList(tree);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.MODULE_TREE);

        return tree;
    }

    // ========================================
    // 拖拽移动
    // ========================================

    /// 移动模块(拖拽调整层级和顺序)
    ///
    /// 验证层级深度后移动模块,并清除相关缓存。
    ///
    /// 参数:
    /// - id: 模块 ID
    /// - new_parent_id: 新的父模块 ID(null 表示移动到根节点)
    /// - new_sort_order: 新的排序值
    ///
    /// 错误:
    /// - ModuleNotFound: 模块不存在
    /// - LevelTooDeep: 移动后层级深度超过 5 层
    /// - CannotMoveToSelf: 不能将模块移动到自己
    /// - CannotMoveToChild: 不能将模块移动到自己的子模块下
    ///
    /// 需求: 4.4, 4.5
    pub fn move(self: *Self, id: i32, new_parent_id: ?i32, new_sort_order: i32) !void {
        // 1. 查询模块
        const module = try self.module_repo.findById(id) orelse {
            return error.ModuleNotFound;
        };
        defer self.freeModule(module);

        // 2. 验证不能移动到自己
        if (new_parent_id) |parent_id| {
            if (parent_id == id) {
                return error.CannotMoveToSelf;
            }

            // 3. 验证不能移动到自己的子模块下
            if (try self.isDescendant(id, parent_id)) {
                return error.CannotMoveToChild;
            }

            // 4. 验证移动后的层级深度不超过 5 层
            const parent = try self.module_repo.findById(parent_id) orelse {
                return error.ParentModuleNotFound;
            };
            defer self.freeModule(parent);

            const new_level = parent.level + 1;

            // 检查子树的最大深度
            const max_child_depth = try self.getMaxChildDepth(id);
            if (new_level + max_child_depth > MAX_LEVEL) {
                return error.LevelTooDeep;
            }
        }

        // 5. 移动模块
        try self.module_repo.move(id, new_parent_id, new_sort_order);

        // 6. 清除相关缓存
        try self.clearModuleCache(module.project_id);
    }

    /// 判断模块是否为另一个模块的后代
    fn isDescendant(self: *Self, ancestor_id: i32, descendant_id: i32) !bool {
        var current_id = descendant_id;

        while (true) {
            const current = try self.module_repo.findById(current_id) orelse {
                return false;
            };
            defer self.freeModule(current);

            if (current.parent_id) |parent_id| {
                if (parent_id == ancestor_id) {
                    return true;
                }
                current_id = parent_id;
            } else {
                return false;
            }
        }
    }

    /// 获取模块子树的最大深度
    fn getMaxChildDepth(self: *Self, module_id: i32) !i32 {
        _ = self;
        _ = module_id;
        
        // 简化实现:假设子树深度为 0
        // TODO: 实现完整的子树深度计算逻辑
        return 0;
    }

    // ========================================
    // 统计数据
    // ========================================

    /// 获取模块统计数据
    ///
    /// 计算模块的用例总数、通过率、Bug 数量、覆盖率。
    ///
    /// 参数:
    /// - module_id: 模块 ID
    ///
    /// 返回:
    /// - 模块统计数据
    ///
    /// 需求: 4.6, 4.10
    pub fn getStatistics(self: *Self, module_id: i32) !ModuleStatistics {
        var stats = ModuleStatistics{
            .module_id = module_id,
        };

        // 1. 查询测试用例总数
        const query = PageQuery{ .page = 1, .page_size = 1 };
        const result = try self.test_case_repo.findByModule(module_id, query);
        defer {
            for (result.items) |tc| {
                self.freeTestCase(tc);
            }
            self.allocator.free(result.items);
        }
        stats.test_case_count = result.total;

        // 2. 计算通过率(简化实现)
        // TODO: 实现完整的通过率计算逻辑
        stats.pass_rate = 0.0;

        // 3. 计算 Bug 数量(简化实现)
        // TODO: 实现 Bug 数量统计逻辑
        stats.bug_count = 0;

        // 4. 计算覆盖率(简化实现)
        // TODO: 实现覆盖率计算逻辑
        stats.coverage_rate = 0.0;

        return stats;
    }

    // ========================================
    // 缓存管理
    // ========================================

    /// 清除模块相关缓存
    fn clearModuleCache(self: *Self, project_id: i32) !void {
        // 清除模块树缓存
        const tree_key = try qc_cache.moduleTreeKey(self.allocator, project_id);
        defer self.allocator.free(tree_key);
        try self.cache.del(tree_key);

        // 清除所有模块相关缓存
        try self.cache.delByPrefix(qc_cache.PREFIX.MODULE);
    }

    // ========================================
    // 序列化和反序列化
    // ========================================

    /// 序列化模块列表为 JSON
    fn serializeModuleList(self: *Self, modules: []Module) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, modules, .{});
    }

    /// 反序列化 JSON 为模块列表
    fn deserializeModuleList(self: *Self, json: []const u8) ![]Module {
        const parsed = try std.json.parseFromSlice([]Module, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    // ========================================
    // 内存管理
    // ========================================

    /// 释放模块对象
    ///
    /// 释放模块对象中所有字符串字段的内存。
    ///
    /// 参数:
    /// - module: 模块对象
    pub fn freeModule(self: *Self, module: Module) void {
        if (module.name.len > 0) self.allocator.free(module.name);
        if (module.description.len > 0) self.allocator.free(module.description);
        if (module.created_by.len > 0) self.allocator.free(module.created_by);
    }

    /// 释放模块列表
    ///
    /// 释放模块列表中所有模块对象的内存。
    ///
    /// 参数:
    /// - modules: 模块数组
    pub fn freeModuleList(self: *Self, modules: []Module) void {
        for (modules) |module| {
            self.freeModule(module);
        }
        self.allocator.free(modules);
    }

    /// 释放测试用例对象(简化实现)
    fn freeTestCase(self: *Self, test_case: anytype) void {
        _ = self;
        _ = test_case;
        // TODO: 实现完整的测试用例释放逻辑
    }
};

// ========================================
// 测试
// ========================================

test "ModuleService.MAX_LEVEL is 5" {
    try std.testing.expectEqual(@as(i32, 5), ModuleService.MAX_LEVEL);
}
