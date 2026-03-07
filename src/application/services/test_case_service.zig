//! 测试用例服务
//!
//! 提供测试用例管理的业务逻辑编排，包括：
//! - 创建、更新、删除测试用例
//! - 批量操作（批量删除、批量更新状态、批量分配负责人）
//! - 执行测试用例并记录执行历史
//! - 搜索和查询测试用例
//! - 缓存管理
//!
//! ## 设计原则
//!
//! - **职责单一**: Service 只做业务编排，不直接操作数据库
//! - **依赖抽象**: 依赖仓储接口和缓存接口，不依赖具体实现
//! - **内存安全**: 使用 errdefer 确保资源正确释放
//! - **缓存策略**: 查询带缓存，更新/删除清除缓存
//! - **批量限制**: 批量操作最多 1000 条记录
//!
//! ## 使用示例
//!
//! ```zig
//! const service = TestCaseService.init(
//!     allocator,
//!     test_case_repo,
//!     execution_repo,
//!     cache,
//! );
//!
//! // 创建测试用例
//! var test_case = TestCase{
//!     .title = "测试登录功能",
//!     .project_id = 1,
//!     .module_id = 2,
//!     .priority = .high,
//!     .created_by = "admin",
//! };
//! try service.create(&test_case);
//!
//! // 执行测试用例
//! var execution = TestExecution{
//!     .test_case_id = test_case.id.?,
//!     .executor = "tester",
//!     .status = .passed,
//!     .executed_at = std.time.timestamp(),
//! };
//! try service.execute(&execution);
//!
//! // 搜索测试用例
//! const query = SearchQuery{
//!     .project_id = 1,
//!     .status = .pending,
//!     .page = 1,
//!     .page_size = 20,
//! };
//! const result = try service.search(query);
//! defer service.freePageResult(result);
//! ```

const std = @import("std");
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;
const TestCaseStatus = @import("../../domain/entities/test_case.model.zig").TestCase.TestCaseStatus;
const TestExecution = @import("../../domain/entities/test_execution.model.zig").TestExecution;
const ExecutionStatus = @import("../../domain/entities/test_execution.model.zig").TestExecution.ExecutionStatus;
const TestCaseRepository = @import("../../domain/repositories/test_case_repository.zig").TestCaseRepository;
const TestExecutionRepository = @import("../../domain/repositories/test_execution_repository.zig").TestExecutionRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const SearchQuery = @import("../../domain/repositories/test_case_repository.zig").SearchQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;
const CacheInterface = @import("cache/contract.zig").CacheInterface;
const qc_cache = @import("../../infrastructure/cache/quality_center_cache.zig");

const Allocator = std.mem.Allocator;

/// 测试用例服务
///
/// 负责测试用例管理的业务逻辑编排，遵循整洁架构原则。
pub const TestCaseService = struct {
    allocator: Allocator,
    test_case_repo: TestCaseRepository,
    execution_repo: TestExecutionRepository,
    cache: CacheInterface,

    const Self = @This();

    /// 批量操作最大记录数限制
    pub const MAX_BATCH_SIZE: usize = 1000;

    /// 初始化测试用例服务
    ///
    /// 参数:
    /// - allocator: 内存分配器
    /// - test_case_repo: 测试用例仓储接口
    /// - execution_repo: 测试执行记录仓储接口
    /// - cache: 缓存接口
    ///
    /// 返回:
    /// - TestCaseService 实例
    pub fn init(
        allocator: Allocator,
        test_case_repo: TestCaseRepository,
        execution_repo: TestExecutionRepository,
        cache: CacheInterface,
    ) Self {
        return .{
            .allocator = allocator,
            .test_case_repo = test_case_repo,
            .execution_repo = execution_repo,
            .cache = cache,
        };
    }

    // ========================================
    // 创建、更新、删除操作
    // ========================================

    /// 创建测试用例
    ///
    /// 验证必填字段后创建测试用例，并清除相关缓存。
    ///
    /// 参数:
    /// - test_case: 测试用例对象指针
    ///
    /// 错误:
    /// - TitleRequired: 标题为空
    /// - TitleTooLong: 标题超过 200 字符
    /// - ProjectIdRequired: 项目 ID 为 0
    /// - ModuleIdRequired: 模块 ID 为 0
    ///
    /// 需求: 1.1, 1.2
    pub fn create(self: *Self, test_case: *TestCase) !void {
        // 1. 验证必填字段
        try test_case.validate();

        // 2. 设置创建时间
        if (test_case.created_at == null) {
            test_case.created_at = std.time.timestamp();
        }
        test_case.updated_at = test_case.created_at;

        // 3. 保存到数据库
        try self.test_case_repo.save(test_case);

        // 4. 清除相关缓存
        try self.clearProjectCache(test_case.project_id);
        try self.clearModuleCache(test_case.module_id, test_case.project_id);
    }

    /// 更新测试用例
    ///
    /// 查询测试用例，更新字段后保存，并清除相关缓存。
    ///
    /// 参数:
    /// - id: 测试用例 ID
    /// - test_case: 包含更新字段的测试用例对象
    ///
    /// 错误:
    /// - TestCaseNotFound: 测试用例不存在
    /// - TitleRequired: 标题为空
    /// - TitleTooLong: 标题超过 200 字符
    ///
    /// 需求: 1.1
    pub fn update(self: *Self, id: i32, test_case: *const TestCase) !void {
        // 1. 查询现有测试用例
        const existing = try self.test_case_repo.findById(id) orelse {
            return error.TestCaseNotFound;
        };
        defer self.freeTestCase(existing);

        // 2. 验证更新后的数据
        try test_case.validate();

        // 3. 创建更新后的测试用例
        var updated = test_case.*;
        updated.id = id;
        updated.updated_at = std.time.timestamp();

        // 4. 保存到数据库
        try self.test_case_repo.save(&updated);

        // 5. 清除相关缓存
        try self.clearTestCaseCache(id);
        try self.clearProjectCache(updated.project_id);
        try self.clearModuleCache(updated.module_id, updated.project_id);
    }

    /// 删除测试用例
    ///
    /// 删除测试用例并清除相关缓存。
    ///
    /// 参数:
    /// - id: 测试用例 ID
    ///
    /// 需求: 1.1
    pub fn delete(self: *Self, id: i32) !void {
        // 1. 查询测试用例获取项目和模块 ID（用于清除缓存）
        const test_case = try self.test_case_repo.findById(id) orelse {
            return error.TestCaseNotFound;
        };
        defer self.freeTestCase(test_case);

        const project_id = test_case.project_id;
        const module_id = test_case.module_id;

        // 2. 删除测试用例
        try self.test_case_repo.delete(id);

        // 3. 清除相关缓存
        try self.clearTestCaseCache(id);
        try self.clearProjectCache(project_id);
        try self.clearModuleCache(module_id, project_id);
    }

    // ========================================
    // 批量操作
    // ========================================

    /// 批量删除测试用例
    ///
    /// 批量删除测试用例并清除相关缓存。
    /// 最多支持 1000 条记录。
    ///
    /// 参数:
    /// - ids: 测试用例 ID 数组
    ///
    /// 错误:
    /// - BatchSizeTooLarge: 批量操作超过 1000 条记录
    ///
    /// 需求: 1.3, 12.3
    pub fn batchDelete(self: *Self, ids: []const i32) !void {
        // 1. 验证批量操作数量限制
        if (ids.len > MAX_BATCH_SIZE) {
            return error.BatchSizeTooLarge;
        }

        if (ids.len == 0) {
            return;
        }

        // 2. 收集项目和模块 ID（用于清除缓存）
        var project_ids = std.AutoHashMap(i32, void).init(self.allocator);
        defer project_ids.deinit();

        var module_ids = std.AutoHashMap(i32, void).init(self.allocator);
        defer module_ids.deinit();

        for (ids) |id| {
            if (try self.test_case_repo.findById(id)) |test_case| {
                defer self.freeTestCase(test_case);
                try project_ids.put(test_case.project_id, {});
                try module_ids.put(test_case.module_id, {});
            }
        }

        // 3. 批量删除
        try self.test_case_repo.batchDelete(ids);

        // 4. 清除相关缓存
        var project_it = project_ids.keyIterator();
        while (project_it.next()) |project_id| {
            try self.clearProjectCache(project_id.*);
        }

        var module_it = module_ids.keyIterator();
        while (module_it.next()) |_| {
            // 注意：这里无法获取 project_id，需要清除所有模块缓存
            // 实际实现中可以优化为清除特定模块的缓存
            try self.cache.delByPrefix(qc_cache.PREFIX.MODULE);
        }

        // 清除所有测试用例搜索结果缓存
        try self.cache.delByPrefix("quality:search:test_case:");
    }

    /// 批量更新测试用例状态
    ///
    /// 批量更新测试用例状态并清除相关缓存。
    /// 最多支持 1000 条记录。
    ///
    /// 参数:
    /// - ids: 测试用例 ID 数组
    /// - status: 目标状态
    ///
    /// 错误:
    /// - BatchSizeTooLarge: 批量操作超过 1000 条记录
    ///
    /// 需求: 1.4, 12.3
    pub fn batchUpdateStatus(self: *Self, ids: []const i32, status: TestCaseStatus) !void {
        // 1. 验证批量操作数量限制
        if (ids.len > MAX_BATCH_SIZE) {
            return error.BatchSizeTooLarge;
        }

        if (ids.len == 0) {
            return;
        }

        // 2. 批量更新状态
        try self.test_case_repo.batchUpdateStatus(ids, status);

        // 3. 清除相关缓存
        for (ids) |id| {
            try self.clearTestCaseCache(id);
        }

        // 清除所有测试用例搜索结果缓存
        try self.cache.delByPrefix("quality:search:test_case:");
    }

    /// 批量更新测试用例负责人
    ///
    /// 批量更新测试用例负责人并清除相关缓存。
    /// 最多支持 1000 条记录。
    ///
    /// 参数:
    /// - ids: 测试用例 ID 数组
    /// - assignee: 负责人用户名
    ///
    /// 错误:
    /// - BatchSizeTooLarge: 批量操作超过 1000 条记录
    ///
    /// 需求: 1.5, 12.3
    pub fn batchUpdateAssignee(self: *Self, ids: []const i32, assignee: []const u8) !void {
        // 1. 验证批量操作数量限制
        if (ids.len > MAX_BATCH_SIZE) {
            return error.BatchSizeTooLarge;
        }

        if (ids.len == 0) {
            return;
        }

        // 2. 批量更新负责人
        try self.test_case_repo.batchUpdateAssignee(ids, assignee);

        // 3. 清除相关缓存
        for (ids) |id| {
            try self.clearTestCaseCache(id);
        }

        // 清除所有测试用例搜索结果缓存
        try self.cache.delByPrefix("quality:search:test_case:");
    }

    // ========================================
    // 执行测试用例
    // ========================================

    /// 执行测试用例
    ///
    /// 创建执行记录并更新测试用例状态。
    ///
    /// 参数:
    /// - execution: 测试执行记录对象指针
    ///
    /// 错误:
    /// - TestCaseNotFound: 测试用例不存在
    /// - TestCaseIdRequired: 测试用例 ID 为 0
    /// - ExecutorRequired: 执行人为空
    /// - ExecutedAtRequired: 执行时间为 0
    ///
    /// 需求: 1.6
    pub fn execute(self: *Self, execution: *TestExecution) !void {
        // 1. 验证执行记录
        try execution.validate();

        // 2. 查询测试用例
        const test_case = try self.test_case_repo.findById(execution.test_case_id) orelse {
            return error.TestCaseNotFound;
        };
        defer self.freeTestCase(test_case);

        // 3. 创建执行记录
        try self.execution_repo.save(execution);

        // 4. 更新测试用例状态和实际结果
        var updated_case = test_case;
        updated_case.status = switch (execution.status) {
            .passed => .passed,
            .failed => .failed,
            .blocked => .blocked,
        };
        updated_case.actual_result = execution.actual_result;
        updated_case.updated_at = std.time.timestamp();

        try self.test_case_repo.save(&updated_case);

        // 5. 清除缓存
        try self.clearTestCaseCache(execution.test_case_id);
        try self.clearProjectCache(test_case.project_id);
        try self.clearModuleCache(test_case.module_id, test_case.project_id);
    }

    // ========================================
    // 查询操作
    // ========================================

    /// 根据 ID 查询测试用例（带缓存）
    ///
    /// 先查缓存，未命中则从数据库查询并回填缓存。
    ///
    /// 参数:
    /// - id: 测试用例 ID
    ///
    /// 返回:
    /// - 测试用例对象（调用者拥有所有权，必须调用 freeTestCase 释放）
    /// - null（如果不存在）
    ///
    /// 需求: 1.9, 12.5
    pub fn findById(self: *Self, id: i32) !?TestCase {
        // 1. 构建缓存键
        const cache_key = try qc_cache.testCaseKey(self.allocator, id);
        defer self.allocator.free(cache_key);

        // 2. 尝试从缓存获取
        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);

            // 检查是否为空值缓存
            if (std.mem.eql(u8, cached, "null")) {
                return null;
            }

            // 反序列化测试用例
            return try self.deserializeTestCase(cached);
        }

        // 3. 从数据库查询
        const test_case = try self.test_case_repo.findById(id);

        // 4. 缓存结果（包括空值）
        if (test_case) |tc| {
            const json = try self.serializeTestCase(tc);
            defer self.allocator.free(json);
            try self.cache.set(cache_key, json, qc_cache.TTL.TEST_CASE);
            return tc;
        } else {
            try self.cache.set(cache_key, "null", 60); // 空值缓存 1 分钟
            return null;
        }
    }

    /// 搜索测试用例（带缓存）
    ///
    /// 支持多条件筛选和分页，结果会被缓存。
    ///
    /// 参数:
    /// - query: 搜索查询参数
    ///
    /// 返回:
    /// - 分页结果（调用者拥有所有权，必须调用 freePageResult 释放）
    ///
    /// 需求: 1.9, 1.10, 12.1, 12.5
    pub fn search(self: *Self, query: SearchQuery) !PageResult(TestCase) {
        // 1. 构建缓存键（基于查询参数的哈希）
        const query_hash = self.hashSearchQuery(query);
        const cache_key = try qc_cache.testCaseSearchKey(self.allocator, query_hash);
        defer self.allocator.free(cache_key);

        // 2. 尝试从缓存获取
        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializePageResult(cached);
        }

        // 3. 从数据库查询
        const result = try self.test_case_repo.search(query);

        // 4. 缓存结果（5 分钟）
        const json = try self.serializePageResult(result);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.TEST_CASE);

        return result;
    }

    /// 根据项目 ID 分页查询测试用例
    ///
    /// 参数:
    /// - project_id: 项目 ID
    /// - query: 分页查询参数
    ///
    /// 返回:
    /// - 分页结果（调用者拥有所有权，必须调用 freePageResult 释放）
    pub fn findByProject(self: *Self, project_id: i32, query: PageQuery) !PageResult(TestCase) {
        return try self.test_case_repo.findByProject(project_id, query);
    }

    /// 根据模块 ID 分页查询测试用例
    ///
    /// 参数:
    /// - module_id: 模块 ID
    /// - query: 分页查询参数
    ///
    /// 返回:
    /// - 分页结果（调用者拥有所有权，必须调用 freePageResult 释放）
    pub fn findByModule(self: *Self, module_id: i32, query: PageQuery) !PageResult(TestCase) {
        return try self.test_case_repo.findByModule(module_id, query);
    }

    // ========================================
    // 缓存管理
    // ========================================

    /// 清除测试用例缓存
    fn clearTestCaseCache(self: *Self, id: i32) !void {
        try qc_cache.clearTestCaseCache(self.cache, self.allocator, id);
    }

    /// 清除项目相关缓存
    fn clearProjectCache(self: *Self, project_id: i32) !void {
        try qc_cache.clearProjectCache(self.cache, self.allocator, project_id);
    }

    /// 清除模块相关缓存
    fn clearModuleCache(self: *Self, module_id: i32, project_id: i32) !void {
        try qc_cache.clearModuleCache(self.cache, self.allocator, module_id, project_id);
    }

    // ========================================
    // 序列化和反序列化
    // ========================================

    /// 序列化测试用例为 JSON
    fn serializeTestCase(self: *Self, test_case: TestCase) ![]const u8 {
        // 简化实现：使用 std.json.stringify
        // 实际项目中应该使用更完善的序列化方案
        return try std.json.stringifyAlloc(self.allocator, test_case, .{});
    }

    /// 反序列化 JSON 为测试用例
    fn deserializeTestCase(self: *Self, json: []const u8) !TestCase {
        // 简化实现：使用 std.json.parseFromSlice
        // 实际项目中应该使用更完善的反序列化方案
        const parsed = try std.json.parseFromSlice(TestCase, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    /// 序列化分页结果为 JSON
    fn serializePageResult(self: *Self, result: PageResult(TestCase)) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, result, .{});
    }

    /// 反序列化 JSON 为分页结果
    fn deserializePageResult(self: *Self, json: []const u8) !PageResult(TestCase) {
        const parsed = try std.json.parseFromSlice(PageResult(TestCase), self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    /// 计算搜索查询的哈希值
    fn hashSearchQuery(self: *Self, query: SearchQuery) u64 {
        _ = self;
        var hasher = std.hash.Wyhash.init(0);

        if (query.project_id) |pid| {
            hasher.update(std.mem.asBytes(&pid));
        }
        if (query.module_id) |mid| {
            hasher.update(std.mem.asBytes(&mid));
        }
        if (query.status) |status| {
            const status_str = status.toString();
            hasher.update(status_str);
        }
        if (query.assignee) |assignee| {
            hasher.update(assignee);
        }
        if (query.keyword) |keyword| {
            hasher.update(keyword);
        }
        hasher.update(std.mem.asBytes(&query.page));
        hasher.update(std.mem.asBytes(&query.page_size));

        return hasher.final();
    }

    // ========================================
    // 内存管理
    // ========================================

    /// 释放测试用例对象
    ///
    /// 释放测试用例对象中所有字符串字段的内存。
    ///
    /// 参数:
    /// - test_case: 测试用例对象
    pub fn freeTestCase(self: *Self, test_case: TestCase) void {
        if (test_case.title.len > 0) self.allocator.free(test_case.title);
        if (test_case.precondition.len > 0) self.allocator.free(test_case.precondition);
        if (test_case.steps.len > 0) self.allocator.free(test_case.steps);
        if (test_case.expected_result.len > 0) self.allocator.free(test_case.expected_result);
        if (test_case.actual_result.len > 0) self.allocator.free(test_case.actual_result);
        if (test_case.assignee) |assignee| {
            if (assignee.len > 0) self.allocator.free(assignee);
        }
        if (test_case.tags.len > 0) self.allocator.free(test_case.tags);
        if (test_case.created_by.len > 0) self.allocator.free(test_case.created_by);
    }

    /// 释放分页结果
    ///
    /// 释放分页结果中所有测试用例对象的内存。
    ///
    /// 参数:
    /// - result: 分页结果
    pub fn freePageResult(self: *Self, result: PageResult(TestCase)) void {
        for (result.items) |test_case| {
            self.freeTestCase(test_case);
        }
        self.allocator.free(result.items);
    }
};

// ========================================
// 测试
// ========================================

test "TestCaseService.MAX_BATCH_SIZE is 1000" {
    try std.testing.expectEqual(@as(usize, 1000), TestCaseService.MAX_BATCH_SIZE);
}
