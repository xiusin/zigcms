//! 统计服务
//!
//! 提供质量中心统计数据的业务逻辑编排,包括:
//! - 模块质量分布统计
//! - Bug 质量分布统计
//! - 反馈状态分布统计
//! - 质量趋势统计
//! - 图表导出
//!
//! ## 设计原则
//!
//! - **职责单一**: Service 只做业务编排,不直接操作数据库
//! - **依赖抽象**: 依赖仓储接口和缓存接口,不依赖具体实现
//! - **内存安全**: 使用 errdefer 确保资源正确释放
//! - **缓存策略**: 统计数据使用缓存优化性能

const std = @import("std");
const Module = @import("../../domain/entities/module.model.zig").Module;
const ModuleRepository = @import("../../domain/repositories/module_repository.zig").ModuleRepository;
const TestCaseRepository = @import("../../domain/repositories/test_case_repository.zig").TestCaseRepository;
const FeedbackRepository = @import("../../domain/repositories/feedback_repository.zig").FeedbackRepository;
const CacheInterface = @import("cache/contract.zig").CacheInterface;
const qc_cache = @import("../../infrastructure/cache/quality_center_cache.zig");

const Allocator = std.mem.Allocator;

/// 模块分布数据项
pub const ModuleDistributionItem = struct {
    module_id: i32,
    module_name: []const u8,
    test_case_count: i32,
    pass_rate: f32,
};

/// Bug 分布数据项
pub const BugDistributionItem = struct {
    bug_type: []const u8,
    count: i32,
    percentage: f32,
};

/// 反馈分布数据项
pub const FeedbackDistributionItem = struct {
    status: []const u8,
    count: i32,
    percentage: f32,
};

/// 质量趋势数据点
pub const QualityTrendPoint = struct {
    date: []const u8,
    pass_rate: f32,
    bug_count: i32,
    execution_count: i32,
};

/// 时间范围
pub const TimeRange = enum {
    last_7_days,
    last_30_days,
    last_90_days,
    custom,
};

/// 统计服务
pub const StatisticsService = struct {
    allocator: Allocator,
    module_repo: ModuleRepository,
    test_case_repo: TestCaseRepository,
    feedback_repo: FeedbackRepository,
    cache: CacheInterface,

    const Self = @This();

    /// 初始化统计服务
    pub fn init(
        allocator: Allocator,
        module_repo: ModuleRepository,
        test_case_repo: TestCaseRepository,
        feedback_repo: FeedbackRepository,
        cache: CacheInterface,
    ) Self {
        return .{
            .allocator = allocator,
            .module_repo = module_repo,
            .test_case_repo = test_case_repo,
            .feedback_repo = feedback_repo,
            .cache = cache,
        };
    }


    // ========================================
    // 模块质量分布
    // ========================================

    /// 获取模块质量分布(带缓存)
    /// 需求: 6.1, 12.5
    pub fn getModuleDistribution(self: *Self, project_id: i32) ![]ModuleDistributionItem {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "quality:stats:module_dist:{d}",
            .{project_id},
        );
        defer self.allocator.free(cache_key);

        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializeModuleDistribution(cached);
        }

        const modules = try self.module_repo.findByProject(project_id);
        defer self.freeModuleList(modules);

        var items = std.ArrayList(ModuleDistributionItem).init(self.allocator);
        errdefer items.deinit();

        for (modules) |module| {
            const item = ModuleDistributionItem{
                .module_id = module.id.?,
                .module_name = try self.allocator.dupe(u8, module.name),
                .test_case_count = 0, // TODO: 查询测试用例数量
                .pass_rate = 0.0,     // TODO: 计算通过率
            };
            try items.append(item);
        }

        const result = try items.toOwnedSlice();
        const json = try self.serializeModuleDistribution(result);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.PROJECT_STATISTICS);

        return result;
    }

    // ========================================
    // Bug 质量分布
    // ========================================

    /// 获取 Bug 质量分布(带缓存)
    /// 需求: 6.3, 12.5
    pub fn getBugDistribution(self: *Self, project_id: i32) ![]BugDistributionItem {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "quality:stats:bug_dist:{d}",
            .{project_id},
        );
        defer self.allocator.free(cache_key);

        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializeBugDistribution(cached);
        }

        // TODO: 实现 Bug 分布统计逻辑
        var items = std.ArrayList(BugDistributionItem).init(self.allocator);
        errdefer items.deinit();

        const bug_types = [_][]const u8{ "功能缺陷", "性能问题", "UI问题", "兼容性问题" };
        for (bug_types) |bug_type| {
            const item = BugDistributionItem{
                .bug_type = try self.allocator.dupe(u8, bug_type),
                .count = 0,
                .percentage = 0.0,
            };
            try items.append(item);
        }

        const result = try items.toOwnedSlice();
        const json = try self.serializeBugDistribution(result);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.PROJECT_STATISTICS);

        return result;
    }

    // ========================================
    // 反馈状态分布
    // ========================================

    /// 获取反馈状态分布(带缓存)
    /// 需求: 6.4, 12.5
    pub fn getFeedbackDistribution(self: *Self) ![]FeedbackDistributionItem {
        const cache_key = "quality:stats:feedback_dist";

        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializeFeedbackDistribution(cached);
        }

        // TODO: 实现反馈分布统计逻辑
        var items = std.ArrayList(FeedbackDistributionItem).init(self.allocator);
        errdefer items.deinit();

        const statuses = [_][]const u8{ "待处理", "处理中", "已解决", "已关闭" };
        for (statuses) |status| {
            const item = FeedbackDistributionItem{
                .status = try self.allocator.dupe(u8, status),
                .count = 0,
                .percentage = 0.0,
            };
            try items.append(item);
        }

        const result = try items.toOwnedSlice();
        const json = try self.serializeFeedbackDistribution(result);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.PROJECT_STATISTICS);

        return result;
    }

    // ========================================
    // 质量趋势
    // ========================================

    /// 获取质量趋势(带缓存)
    /// 需求: 6.5, 6.6, 12.5
    pub fn getQualityTrend(self: *Self, project_id: i32, time_range: TimeRange) ![]QualityTrendPoint {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "quality:stats:trend:{d}:{s}",
            .{ project_id, @tagName(time_range) },
        );
        defer self.allocator.free(cache_key);

        if (try self.cache.get(cache_key, self.allocator)) |cached| {
            defer self.allocator.free(cached);
            return try self.deserializeQualityTrend(cached);
        }

        // TODO: 实现质量趋势统计逻辑
        var points = std.ArrayList(QualityTrendPoint).init(self.allocator);
        errdefer points.deinit();

        const days = switch (time_range) {
            .last_7_days => 7,
            .last_30_days => 30,
            .last_90_days => 90,
            .custom => 30,
        };

        var i: i32 = 0;
        while (i < days) : (i += 1) {
            const date = try std.fmt.allocPrint(self.allocator, "2024-01-{d:0>2}", .{i + 1});
            const point = QualityTrendPoint{
                .date = date,
                .pass_rate = 0.0,
                .bug_count = 0,
                .execution_count = 0,
            };
            try points.append(point);
        }

        const result = try points.toOwnedSlice();
        const json = try self.serializeQualityTrend(result);
        defer self.allocator.free(json);
        try self.cache.set(cache_key, json, qc_cache.TTL.PROJECT_STATISTICS);

        return result;
    }

    // ========================================
    // 图表导出
    // ========================================

    /// 导出图表
    /// 需求: 6.7
    pub fn exportChart(self: *Self, chart_type: []const u8, format: []const u8, file_path: []const u8) !void {
        _ = self;
        _ = chart_type;
        _ = format;
        _ = file_path;
        // TODO: 实现图表导出逻辑(PNG/SVG/PDF)
    }

    // ========================================
    // 序列化和反序列化
    // ========================================

    fn serializeModuleDistribution(self: *Self, items: []ModuleDistributionItem) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, items, .{});
    }

    fn deserializeModuleDistribution(self: *Self, json: []const u8) ![]ModuleDistributionItem {
        const parsed = try std.json.parseFromSlice([]ModuleDistributionItem, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    fn serializeBugDistribution(self: *Self, items: []BugDistributionItem) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, items, .{});
    }

    fn deserializeBugDistribution(self: *Self, json: []const u8) ![]BugDistributionItem {
        const parsed = try std.json.parseFromSlice([]BugDistributionItem, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    fn serializeFeedbackDistribution(self: *Self, items: []FeedbackDistributionItem) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, items, .{});
    }

    fn deserializeFeedbackDistribution(self: *Self, json: []const u8) ![]FeedbackDistributionItem {
        const parsed = try std.json.parseFromSlice([]FeedbackDistributionItem, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    fn serializeQualityTrend(self: *Self, points: []QualityTrendPoint) ![]const u8 {
        return try std.json.stringifyAlloc(self.allocator, points, .{});
    }

    fn deserializeQualityTrend(self: *Self, json: []const u8) ![]QualityTrendPoint {
        const parsed = try std.json.parseFromSlice([]QualityTrendPoint, self.allocator, json, .{});
        defer parsed.deinit();
        return parsed.value;
    }

    // ========================================
    // 内存管理
    // ========================================

    fn freeModuleList(self: *Self, modules: []Module) void {
        _ = self;
        _ = modules;
        // TODO: 实现模块列表释放逻辑
    }

    /// 释放模块分布数据
    pub fn freeModuleDistribution(self: *Self, items: []ModuleDistributionItem) void {
        for (items) |item| {
            self.allocator.free(item.module_name);
        }
        self.allocator.free(items);
    }

    /// 释放 Bug 分布数据
    pub fn freeBugDistribution(self: *Self, items: []BugDistributionItem) void {
        for (items) |item| {
            self.allocator.free(item.bug_type);
        }
        self.allocator.free(items);
    }

    /// 释放反馈分布数据
    pub fn freeFeedbackDistribution(self: *Self, items: []FeedbackDistributionItem) void {
        for (items) |item| {
            self.allocator.free(item.status);
        }
        self.allocator.free(items);
    }

    /// 释放质量趋势数据
    pub fn freeQualityTrend(self: *Self, points: []QualityTrendPoint) void {
        for (points) |point| {
            self.allocator.free(point.date);
        }
        self.allocator.free(points);
    }
};
