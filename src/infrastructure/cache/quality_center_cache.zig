//! 质量中心缓存层
//!
//! 提供质量中心模块的缓存键生成、失效策略和预热功能。
//!
//! ## 缓存策略
//!
//! - 测试用例：5 分钟 TTL
//! - 项目统计：10 分钟 TTL
//! - 模块树：15 分钟 TTL
//! - 热门测试用例：30 分钟 TTL
//!
//! ## 缓存键命名规范
//!
//! - 测试用例：`quality:test_case:{id}`
//! - 项目统计：`quality:project:{id}:stats`
//! - 模块树：`quality:module:tree:{project_id}`
//! - 热门测试用例：`quality:hot_test_cases:{project_id}`
//!
//! ## 使用示例
//!
//! ```zig
//! const qc_cache = @import("quality_center_cache.zig");
//!
//! // 生成缓存键
//! const key = try qc_cache.testCaseKey(allocator, 123);
//! defer allocator.free(key);
//!
//! // 清除项目相关缓存
//! try qc_cache.clearProjectCache(cache, allocator, 1);
//!
//! // 预热缓存
//! try qc_cache.warmupCache(cache, allocator, db, 1);
//! ```

const std = @import("std");
const CacheInterface = @import("../../application/services/cache/contract.zig").CacheInterface;

/// 缓存 TTL 配置（秒）
pub const TTL = struct {
    /// 测试用例缓存 TTL（5 分钟）
    pub const TEST_CASE: u64 = 5 * 60;
    pub const PROJECT: u64 = TEST_CASE;

    /// 项目统计缓存 TTL（10 分钟）
    pub const PROJECT_STATS: u64 = 10 * 60;
    pub const PROJECT_STATISTICS: u64 = PROJECT_STATS;

    /// 模块树缓存 TTL（15 分钟）
    pub const MODULE_TREE: u64 = 15 * 60;

    /// 热门测试用例缓存 TTL（30 分钟）
    pub const HOT_TEST_CASES: u64 = 30 * 60;
};

/// 缓存键前缀
pub const PREFIX = struct {
    /// 质量中心模块前缀
    pub const QUALITY: []const u8 = "quality:";

    /// 测试用例前缀
    pub const TEST_CASE: []const u8 = "quality:test_case:";

    /// 项目前缀
    pub const PROJECT: []const u8 = "quality:project:";

    /// 模块前缀
    pub const MODULE: []const u8 = "quality:module:";

    /// 需求前缀
    pub const REQUIREMENT: []const u8 = "quality:requirement:";

    /// 反馈前缀
    pub const FEEDBACK: []const u8 = "quality:feedback:";
};

// ========================================
// 缓存键生成函数
// ========================================

/// 生成测试用例缓存键
///
/// 格式：`quality:test_case:{id}`
///
/// 参数:
/// - allocator: 内存分配器
/// - id: 测试用例 ID
///
/// 返回:
/// - 缓存键（调用者拥有所有权，必须释放）
pub fn testCaseKey(allocator: std.mem.Allocator, id: i32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "quality:test_case:{d}", .{id});
}

/// 生成项目统计缓存键
///
/// 格式：`quality:project:{id}:stats`
///
/// 参数:
/// - allocator: 内存分配器
/// - project_id: 项目 ID
///
/// 返回:
/// - 缓存键（调用者拥有所有权，必须释放）
pub fn projectStatsKey(allocator: std.mem.Allocator, project_id: i32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "quality:project:{d}:stats", .{project_id});
}

pub fn projectKey(allocator: std.mem.Allocator, id: i32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "quality:project:{d}", .{id});
}

pub fn projectStatisticsKey(allocator: std.mem.Allocator, project_id: i32) ![]const u8 {
    return try projectStatsKey(allocator, project_id);
}

/// 生成模块树缓存键
///
/// 格式：`quality:module:tree:{project_id}`
///
/// 参数:
/// - allocator: 内存分配器
/// - project_id: 项目 ID
///
/// 返回:
/// - 缓存键（调用者拥有所有权，必须释放）
pub fn moduleTreeKey(allocator: std.mem.Allocator, project_id: i32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "quality:module:tree:{d}", .{project_id});
}

/// 生成热门测试用例缓存键
///
/// 格式：`quality:hot_test_cases:{project_id}`
///
/// 参数:
/// - allocator: 内存分配器
/// - project_id: 项目 ID
///
/// 返回:
/// - 缓存键（调用者拥有所有权，必须释放）
pub fn hotTestCasesKey(allocator: std.mem.Allocator, project_id: i32) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "quality:hot_test_cases:{d}", .{project_id});
}

/// 生成测试用例搜索缓存键
///
/// 格式：`quality:search:test_case:{hash}`
///
/// 参数:
/// - allocator: 内存分配器
/// - query_hash: 查询条件的哈希值
///
/// 返回:
/// - 缓存键（调用者拥有所有权，必须释放）
pub fn testCaseSearchKey(allocator: std.mem.Allocator, query_hash: u64) ![]const u8 {
    return try std.fmt.allocPrint(allocator, "quality:search:test_case:{d}", .{query_hash});
}

// ========================================
// 缓存失效策略
// ========================================

/// 清除测试用例缓存
///
/// 删除指定测试用例的缓存。
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - id: 测试用例 ID
pub fn clearTestCaseCache(cache: CacheInterface, allocator: std.mem.Allocator, id: i32) !void {
    const key = try testCaseKey(allocator, id);
    defer allocator.free(key);
    try cache.del(key);
}

/// 清除项目相关缓存
///
/// 删除指定项目的所有缓存，包括：
/// - 项目统计
/// - 模块树
/// - 热门测试用例
/// - 所有测试用例搜索结果
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - project_id: 项目 ID
pub fn clearProjectCache(cache: CacheInterface, allocator: std.mem.Allocator, project_id: i32) !void {
    // 构建项目前缀
    const prefix = try std.fmt.allocPrint(allocator, "quality:project:{d}:", .{project_id});
    defer allocator.free(prefix);

    // 按前缀批量删除
    try cache.delByPrefix(prefix);

    // 删除模块树缓存
    const tree_key = try moduleTreeKey(allocator, project_id);
    defer allocator.free(tree_key);
    try cache.del(tree_key);

    // 删除热门测试用例缓存
    const hot_key = try hotTestCasesKey(allocator, project_id);
    defer allocator.free(hot_key);
    try cache.del(hot_key);

    // 删除所有测试用例搜索结果缓存
    try cache.delByPrefix("quality:search:test_case:");
}

/// 清除模块相关缓存
///
/// 删除指定模块的所有缓存，包括：
/// - 模块树（整个项目的）
/// - 相关测试用例搜索结果
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - module_id: 模块 ID
/// - project_id: 项目 ID
pub fn clearModuleCache(
    cache: CacheInterface,
    allocator: std.mem.Allocator,
    module_id: i32,
    project_id: i32,
) !void {
    _ = module_id; // 保留参数以便将来扩展

    // 删除模块树缓存（整个项目的）
    const tree_key = try moduleTreeKey(allocator, project_id);
    defer allocator.free(tree_key);
    try cache.del(tree_key);

    // 删除测试用例搜索结果缓存
    try cache.delByPrefix("quality:search:test_case:");
}

/// 清除需求相关缓存
///
/// 删除指定需求的所有缓存。
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - requirement_id: 需求 ID
pub fn clearRequirementCache(cache: CacheInterface, allocator: std.mem.Allocator, requirement_id: i32) !void {
    const prefix = try std.fmt.allocPrint(allocator, "quality:requirement:{d}:", .{requirement_id});
    defer allocator.free(prefix);
    try cache.delByPrefix(prefix);
}

/// 清除反馈相关缓存
///
/// 删除指定反馈的所有缓存。
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - feedback_id: 反馈 ID
pub fn clearFeedbackCache(cache: CacheInterface, allocator: std.mem.Allocator, feedback_id: i32) !void {
    const prefix = try std.fmt.allocPrint(allocator, "quality:feedback:{d}:", .{feedback_id});
    defer allocator.free(prefix);
    try cache.delByPrefix(prefix);
}

// ========================================
// 缓存预热
// ========================================

/// 缓存预热选项
pub const WarmupOptions = struct {
    /// 是否预热项目统计
    project_stats: bool = true,

    /// 是否预热模块树
    module_tree: bool = true,

    /// 是否预热热门测试用例
    hot_test_cases: bool = true,

    /// 热门测试用例数量限制
    hot_test_cases_limit: i32 = 20,
};

/// 预热项目缓存
///
/// 预加载项目的热门数据到缓存，包括：
/// - 项目统计数据
/// - 模块树
/// - 热门测试用例
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - project_id: 项目 ID
/// - options: 预热选项
/// - data_loader: 数据加载器（用于从数据库加载数据）
///
/// 注意：
/// - 此函数需要传入数据加载器来获取实际数据
/// - 数据加载器应该实现 DataLoader 接口
pub fn warmupProjectCache(
    cache: CacheInterface,
    allocator: std.mem.Allocator,
    project_id: i32,
    options: WarmupOptions,
    data_loader: anytype,
) !void {
    // 预热项目统计
    if (options.project_stats) {
        const stats_key = try projectStatsKey(allocator, project_id);
        defer allocator.free(stats_key);

        // 检查缓存是否已存在
        if (!cache.exists(stats_key)) {
            // 从数据库加载统计数据
            const stats_json = try data_loader.loadProjectStats(project_id);
            defer allocator.free(stats_json);

            // 缓存统计数据
            try cache.set(stats_key, stats_json, TTL.PROJECT_STATS);
        }
    }

    // 预热模块树
    if (options.module_tree) {
        const tree_key = try moduleTreeKey(allocator, project_id);
        defer allocator.free(tree_key);

        if (!cache.exists(tree_key)) {
            // 从数据库加载模块树
            const tree_json = try data_loader.loadModuleTree(project_id);
            defer allocator.free(tree_json);

            // 缓存模块树
            try cache.set(tree_key, tree_json, TTL.MODULE_TREE);
        }
    }

    // 预热热门测试用例
    if (options.hot_test_cases) {
        const hot_key = try hotTestCasesKey(allocator, project_id);
        defer allocator.free(hot_key);

        if (!cache.exists(hot_key)) {
            // 从数据库加载热门测试用例
            const hot_cases_json = try data_loader.loadHotTestCases(project_id, options.hot_test_cases_limit);
            defer allocator.free(hot_cases_json);

            // 缓存热门测试用例
            try cache.set(hot_key, hot_cases_json, TTL.HOT_TEST_CASES);
        }
    }
}

/// 批量预热多个项目的缓存
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - project_ids: 项目 ID 列表
/// - options: 预热选项
/// - data_loader: 数据加载器
pub fn warmupMultipleProjects(
    cache: CacheInterface,
    allocator: std.mem.Allocator,
    project_ids: []const i32,
    options: WarmupOptions,
    data_loader: anytype,
) !void {
    for (project_ids) |project_id| {
        try warmupProjectCache(cache, allocator, project_id, options, data_loader);
    }
}

// ========================================
// 回源策略辅助函数
// ========================================

/// 获取或加载数据（Remember 模式）
///
/// 先查缓存，未命中则回源加载并回填缓存。
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - key: 缓存键
/// - ttl: 过期时间（秒）
/// - loader: 数据加载函数
///
/// 返回:
/// - 数据（调用者拥有所有权，必须释放）
///
/// 示例:
/// ```zig
/// const stats = try getOrLoad(cache, allocator, stats_key, TTL.PROJECT_STATS, struct {
///     pub fn load() ![]const u8 {
///         return try db.getProjectStats(project_id);
///     }
/// }.load);
/// defer allocator.free(stats);
/// ```
pub fn getOrLoad(
    cache: CacheInterface,
    allocator: std.mem.Allocator,
    key: []const u8,
    ttl: u64,
    comptime loader: fn () anyerror![]const u8,
) ![]const u8 {
    // 1. 尝试从缓存获取
    if (try cache.get(key, allocator)) |cached| {
        return cached;
    }

    // 2. 缓存未命中，回源加载
    const data = try loader();
    errdefer allocator.free(data);

    // 3. 回填缓存（失败不影响主流程）
    cache.set(key, data, ttl) catch |err| {
        std.log.warn("Failed to cache data for key '{s}': {}", .{ key, err });
    };

    return data;
}

/// 获取或加载数据（带上下文）
///
/// 先查缓存，未命中则回源加载并回填缓存。
/// 支持传递上下文参数给加载函数。
///
/// 参数:
/// - cache: 缓存接口
/// - allocator: 内存分配器
/// - key: 缓存键
/// - ttl: 过期时间（秒）
/// - context: 上下文参数
/// - loader: 数据加载函数（接受上下文参数）
///
/// 返回:
/// - 数据（调用者拥有所有权，必须释放）
pub fn getOrLoadWithContext(
    cache: CacheInterface,
    allocator: std.mem.Allocator,
    key: []const u8,
    ttl: u64,
    context: anytype,
    comptime loader: fn (@TypeOf(context)) anyerror![]const u8,
) ![]const u8 {
    // 1. 尝试从缓存获取
    if (try cache.get(key, allocator)) |cached| {
        return cached;
    }

    // 2. 缓存未命中，回源加载
    const data = try loader(context);
    errdefer allocator.free(data);

    // 3. 回填缓存（失败不影响主流程）
    cache.set(key, data, ttl) catch |err| {
        std.log.warn("Failed to cache data for key '{s}': {}", .{ key, err });
    };

    return data;
}

// ========================================
// 测试
// ========================================

test "testCaseKey generates correct format" {
    const allocator = std.testing.allocator;

    const key = try testCaseKey(allocator, 123);
    defer allocator.free(key);

    try std.testing.expectEqualStrings("quality:test_case:123", key);
}

test "projectStatsKey generates correct format" {
    const allocator = std.testing.allocator;

    const key = try projectStatsKey(allocator, 456);
    defer allocator.free(key);

    try std.testing.expectEqualStrings("quality:project:456:stats", key);
}

test "moduleTreeKey generates correct format" {
    const allocator = std.testing.allocator;

    const key = try moduleTreeKey(allocator, 789);
    defer allocator.free(key);

    try std.testing.expectEqualStrings("quality:module:tree:789", key);
}

test "hotTestCasesKey generates correct format" {
    const allocator = std.testing.allocator;

    const key = try hotTestCasesKey(allocator, 101);
    defer allocator.free(key);

    try std.testing.expectEqualStrings("quality:hot_test_cases:101", key);
}

test "testCaseSearchKey generates correct format" {
    const allocator = std.testing.allocator;

    const key = try testCaseSearchKey(allocator, 12345678);
    defer allocator.free(key);

    try std.testing.expectEqualStrings("quality:search:test_case:12345678", key);
}

test "TTL constants are correct" {
    try std.testing.expectEqual(@as(u64, 5 * 60), TTL.TEST_CASE);
    try std.testing.expectEqual(@as(u64, 10 * 60), TTL.PROJECT_STATS);
    try std.testing.expectEqual(@as(u64, 15 * 60), TTL.MODULE_TREE);
    try std.testing.expectEqual(@as(u64, 30 * 60), TTL.HOT_TEST_CASES);
}

test "PREFIX constants are correct" {
    try std.testing.expectEqualStrings("quality:", PREFIX.QUALITY);
    try std.testing.expectEqualStrings("quality:test_case:", PREFIX.TEST_CASE);
    try std.testing.expectEqualStrings("quality:project:", PREFIX.PROJECT);
    try std.testing.expectEqualStrings("quality:module:", PREFIX.MODULE);
    try std.testing.expectEqualStrings("quality:requirement:", PREFIX.REQUIREMENT);
    try std.testing.expectEqualStrings("quality:feedback:", PREFIX.FEEDBACK);
}
