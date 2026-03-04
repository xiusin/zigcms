//! 项目服务
//!
//! 提供项目管理的业务逻辑编排,包括:
//! - 创建、更新、删除项目
//! - 归档和恢复项目
//! - 项目统计数据计算
//! - 缓存预热
//!
//! ## 设计原则
//!
//! - **职责单一**: Service 只做业务编排,不直接操作数据库
//! - **依赖抽象**: 依赖仓储接口和缓存接口,不依赖具体实现
//! - **内存安全**: 使用 errdefer 确保资源正确释放
//! - **缓存策略**: 查询带缓存,更新/删除清除缓存
//!
//! ## 使用示例
//!
//! ```zig
//! const service = ProjectService.init(
//!     allocator,
//!     project_repo,
//!     test_case_repo,
//!     requirement_repo,
//!     cache,
//! );
//!
//! // 创建项目
//! var project = Project{
//!     .name = "电商系统",
//!     .description = "电商系统测试项目",
//!     .owner = "admin",
//!     .created_by = "admin",
//! };
//! try service.create(&project);
//!
//! // 获取项目统计
//! const stats = try service.getStatistics(project.id.?);
//! defer service.freeStatistics(stats);
//! ```

const std = @import("std");
const Project = @import("../../domain/entities/project.model.zig").Project;
const ProjectStatus = @import("../../domain/entities/project.model.zig").ProjectStatus;
const ProjectRepository = @import("../../domain/repositories/project_repository.zig").ProjectRepository;
const TestCaseRepository = @import("../../domain/repositories/test_case_repository.zig").TestCaseRepository;
const RequirementRepository = @import("../../domain/repositories/requirement_repository.zig").RequirementRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;
const CacheInterface = @import("../../infrastructure/cache/contract.zig").CacheInterface;
const qc_cache = @import("../../infrastructure/cache/quality_center_cache.zig");

const Allocator = std.mem.Allocator;

/// 项目统计数据
pub const ProjectStatistics = struct {
    project_id: i32,
    test_case_count: i32 = 0, // 用例总数
    execution_count: i32 = 0, // 执行次数
    pass_rate: f32 = 0.0, // 通过率
    bug_count: i32 = 0, // Bug 数量
    requirement_coverage: f32 = 0.0, // 需求覆盖率
};

/// 项目服务
///
/// 负责项目管理的业务逻辑编排,遵循整洁架构原则。
pub const ProjectService = struct {
    allocator: Allocator,
    project_repo: ProjectRepository,
    test_case_repo: TestCaseRepository,
    requirement_repo: RequirementRepository,
    cache: CacheInterface,

    const Self = @This();

    /// 初始化项目服务
    ///
    /// 参数:
    /// - allocator: 内存分配器
    /// - project_repo: 项目仓储接口
    /// - test_case_repo: 测试用例仓储接口
    /// - requirement_repo: 需求仓储接口
    /// - cache: 缓存接口
    ///
    /// 返回:
    /// - ProjectService 实例
    pub fn init(
        allocator: Allocator,
        project_repo: ProjectRepository,
        test_case_repo: TestCaseRepository,
        requirement_repo: RequirementRepository,
        cache: CacheInterface,
    ) Self {
        return .{
            .allocator = allocator,
            .project_repo = project_repo,
            .test_case_repo = test_case_repo,
            .requirement_repo = requirement_repo,
            .cache = cache,
        };
    }

    // ========================================
    // 创建、更新、删除操作
    // ========================================

    /// 创建项目
    ///
    /// 验证必填字段后创建项目,并清除相关缓存。
    ///
    /// 参数:
    /// - project: 项目对象指针
    ///
    /// 错误:
    /// - NameRequired: 项目名称为空
    /// - DescriptionRequired: 项目描述为空
    ///
    /// 需求: 3.1, 3.2
    pub fn create(self: *Self, project: *Project) !void {
        // 1. 验证必填字段
        if (project.name.len == 0) return error.NameRequired;
        if (project.description.len == 0) return error.DescriptionRequired;

        // 2. 设置创建时间
        if (project.created_at == null) {
            project.created_at = std.time.timestamp();
        }
        project.updated_at = project.created_at;

        // 3. 保存到数据库
        try self.project_repo.save(project);

        // 4. 清除项目列表缓存
        try self.cache.delByPrefix("quality:project:list:");
    }

    /// 更新项目
    ///
    /// 查询项目,更新字段后保存,并清除相关缓存。
    ///
    /// 参数:
    /// - id: 项目 ID
    /// - project: 包含更新字段的项目对象
    ///
    /// 错误:
    /// - ProjectNotFound: 项目不存在
    /// - NameRequired: 项目名称为空
    /// - DescriptionRequired: 项目描述为空
    ///
    /// 需求: 3.1
    pub fn update(self: *Self, id: i32, project: *const Project) !void {
        // 1. 查询现有项目
        const existing = try self.project_repo.findById(id) orelse {
            return error.ProjectNotFound;
        };
        defer self.freeProject(existing);

        // 2. 验证更新后的数据
        if (project.name.len == 0) return error.NameRequired;
        if (project.description.len == 0) return error.DescriptionRequired;

        // 3. 创建更新后的项目
        var updated = project.*;
        updated.id = id;
        updated.updated_at = std.time.timestamp();

        // 4. 保存到数据库
        try self.project_repo.save(&updated);

        // 5. 清除相关缓存
        try self.clearProjectCache(id);
    }

    /// 删除项目
    ///
    /// 删除项目并清除相关缓存。
    ///
    /// 参数:
    /// - id: 项目 ID
    ///
    /// 需求: 3.1, 3.8
    pub fn delete(self: *Self, id: i32) !void {
        // 1. 删除项目
        try self.project_repo.delete(id);

        // 2. 清除相关缓存
        try self.clearProjectCache(id);
        try self.cache.delByPrefix("quality:project:list:");
    }

    /// 归档项目
    ///
    /// 归档项目并清除相关缓存。
    ///
    /// 参数:
    /// - id: 项目 ID
    ///
    /// 需求: 3.7
    pub fn archive(self: *Self, id: i32) !void {
        // 1. 归档项目
        try self.project_repo.archive(id);

        // 2. 清除相关缓存
        try self.clearProjectCache(id);
        try self.cache.delByPrefix("quality:project:list:");
    }

    /// 恢复项目
    ///
    /// 恢复归档的项目并清除相关缓存。
    ///
    /// 参数:
    /// - id: 项目 ID
    ///
    /// 需求: 3.7
    pub fn restore(self: *Self, id: i32) !void {
        // 1. 恢复项目
        try self.project_repo.restore(id);

        // 2. 清除相关缓存
        try self.clearProjectCache(id);
        try self.cache.delByPrefix("quality:project:list:");
    }

    // ========================================
    // 查询操作
    // ========================================

    /// 根据 ID 查询项目(带缓存)
    ///
    /// 先查缓存,未命中则从数据库查询并回填缓存。
    ///
    /// 参数:
    /// - id: 项目 ID
    ///
    /// 返回:
    /// - 项目对象(调用者拥有所有权,必须调用 freeProject 释放)
    /// - null(如果不存在)
    ///
    /// 需求: 3.1, 12.5
    pub fn findById(self: *Self, id: i32) !?Project {
        // 1. 构建缓存键
        const cache_key = try qc_cache.projectKey(self.allocator, id);
        defer self.allocator.free(cache_key);

        // 2. 尝试从缓存获取
        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);

            // 检查是否为空值缓存
            if (std.mem.eql(u8, cached, "null")) {
                return null;
            }

            // 反序列化项目
            return try self.deserializeProject(cached);
        }

        // 3. 从数据库查询
        const project = try self.project_repo.findById(id);

        // 4. 缓存结果(包括空值)
        if (project) |p| {
            const json = try self.serializeProject(p);
            defer self.allocator.free(json);
            try self.cache.set(cache_key, json, qc_cache.TTL.PROJECT);
            return p;
        } else {
            try self.cache.set(cache_key, "null", 60); // 空值缓存 1 分钟
            return null;
        }
    }

    /// 分页查询所有项目
    ///
    /// 参数:
    /// - query: 分页查询参数
    ///
    /// 返回:
    /// - 分页结果(调用者拥有所有权,必须调用 freePageResult 释放)
    ///
    /// 需求: 3.1
    pub fn findAll(self: *Self, query: PageQuery) !PageResult(Project) {
        return try self.project_repo.findAll(query);
    }

    // ========================================
    // 统计数据
    // ========================================

    /// 获取项目统计数据(带缓存)
    ///
    /// 计算项目的用例总数、执行次数、通过率、Bug 数量、需求覆盖率。
    ///
    /// 参数:
    /// - project_id: 项目 ID
    ///
    /// 返回:
    /// - 项目统计数据(调用者拥有所有权,必须调用 freeStatistics 释放)
    ///
    /// 需求: 3.5, 3.6, 12.2, 12.5
    pub fn getStatistics(self: *Self, project_id: i32) !ProjectStatistics {
        // 1. 构建缓存键
        const cache_key = try qc_cache.projectStatisticsKey(self.allocator, project_id);
        defer self.allocator.free(cache_key);

        // 2. 尝试从缓存获取
        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializeStatistics(cached);
        }

        // 3. 计算统计数据
        var stats = ProjectStatistics{
            .project_id = project_id,
        };

        // 3.1 查询测试用例总数和通过率
        const test_case_query = PageQuery{ .page = 1, .page_size = 1 };
        const test_case_result = try self.test_case_repo.findByProject(project_id, test_case_query);
        defer {
            for (test_case_result.items) |tc| {
                self.freeTestCase(tc);
            }
            self.allocator.free(test_case_result.items);
        }
        stats.test_case_count = test_case_result.total;

        // 3.2 计算通过率(简化实现,实际应查询执行记录)
        // TODO: 实现完整的通过率计算逻辑
        stats.pass_rate = 0.0;
        stats.execution_count = 0;

        // 3.3 计算 Bug 数量(简化实现)
        // TODO: 实现 Bug 数量统计逻辑
        stats.bug_count = 0;

        // 3.4 计算需求覆盖率
        const requirement_query = PageQuery{ .page = 1, .page_size = 1 };
        const requirement_result = try self.requirement_repo.findByProject(project_id, requirement_query);
        defer {
            for (requirement_result.items) |req| {
                self.freeRequirement(req);
            }
            self.allocator.free(requirement_result.items);
        }

        if (requirement_result.total > 0) {
            // 简化实现:假设所有需求的覆盖率相同
            // TODO: 实现完整的需求覆盖率计算逻辑
            stats.requirement_coverage = 0.0;
        }

        // 4. 缓存结果(5 分钟)
        const json = try self.serializeStatistics(stats);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.PROJECT_STATISTICS);

        return stats;
    }

    /// 预热缓存
    ///
    /// 预加载项目统计数据、模块树、热门测试用例到缓存。
    ///
    /// 参数:
    /// - project_id: 项目 ID
    ///
    /// 需求: 3.10, 12.5
    pub fn warmupCache(self: *Self, project_id: i32) !void {
        // 1. 预加载项目统计数据
        _ = try self.getStatistics(project_id);

        // 2. 预加载项目基本信息
        _ = try self.findById(project_id);

        // 3. 预加载模块树(简化实现)
        // TODO: 调用 ModuleService.getTree 预加载模块树

        // 4. 预加载热门测试用例(简化实现)
        // TODO: 查询最近执行的测试用例并缓存
    }

    // ========================================
    // 缓存管理
    // ========================================

    /// 清除项目相关缓存
    fn clearProjectCache(self: *Self, project_id: i32) !void {
        try qc_cache.clearProjectCache(self.cache, self.allocator, project_id);
    }

    // ========================================
    // 序列化和反序列化
    // ========================================

    /// 序列化项目为 JSON
    fn serializeProject(self: *Self, project: Project) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, project, .{});
    }

    /// 反序列化 JSON 为项目
    fn deserializeProject(self: *Self, json: []const u8) !Project {
        const parsed = try std.json.parseFromSlice(Project, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    /// 序列化统计数据为 JSON
    fn serializeStatistics(self: *Self, stats: ProjectStatistics) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, stats, .{});
    }

    /// 反序列化 JSON 为统计数据
    fn deserializeStatistics(self: *Self, json: []const u8) !ProjectStatistics {
        const parsed = try std.json.parseFromSlice(ProjectStatistics, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    // ========================================
    // 内存管理
    // ========================================

    /// 释放项目对象
    ///
    /// 释放项目对象中所有字符串字段的内存。
    ///
    /// 参数:
    /// - project: 项目对象
    pub fn freeProject(self: *Self, project: Project) void {
        if (project.name.len > 0) self.allocator.free(project.name);
        if (project.description.len > 0) self.allocator.free(project.description);
        if (project.owner.len > 0) self.allocator.free(project.owner);
        if (project.members.len > 0) self.allocator.free(project.members);
        if (project.settings.len > 0) self.allocator.free(project.settings);
        if (project.created_by.len > 0) self.allocator.free(project.created_by);
    }

    /// 释放测试用例对象(简化实现)
    fn freeTestCase(self: *Self, test_case: anytype) void {
        _ = self;
        _ = test_case;
        // TODO: 实现完整的测试用例释放逻辑
    }

    /// 释放需求对象(简化实现)
    fn freeRequirement(self: *Self, requirement: anytype) void {
        _ = self;
        _ = requirement;
        // TODO: 实现完整的需求释放逻辑
    }

    /// 释放统计数据
    ///
    /// 参数:
    /// - stats: 统计数据
    pub fn freeStatistics(self: *Self, stats: ProjectStatistics) void {
        _ = self;
        _ = stats;
        // 统计数据不包含需要释放的字段
    }

    /// 释放分页结果
    ///
    /// 释放分页结果中所有项目对象的内存。
    ///
    /// 参数:
    /// - result: 分页结果
    pub fn freePageResult(self: *Self, result: PageResult(Project)) void {
        for (result.items) |project| {
            self.freeProject(project);
        }
        self.allocator.free(result.items);
    }
};
