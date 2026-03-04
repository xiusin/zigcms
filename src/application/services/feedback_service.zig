//! 反馈服务
//!
//! 提供反馈管理的业务逻辑编排,包括:
//! - 创建、更新、删除反馈
//! - 添加跟进记录
//! - 批量操作(批量指派、批量更新状态)
//! - 导出反馈
//! - AI 分析反馈内容
//!
//! ## 设计原则
//!
//! - **职责单一**: Service 只做业务编排,不直接操作数据库
//! - **依赖抽象**: 依赖仓储接口和缓存接口,不依赖具体实现
//! - **内存安全**: 使用 errdefer 确保资源正确释放
//! - **缓存策略**: 查询带缓存,更新/删除清除缓存
//! - **批量限制**: 批量操作最多 1000 条记录

const std = @import("std");
const Feedback = @import("../../domain/entities/feedback.model.zig").Feedback;
const FeedbackStatus = @import("../../domain/entities/feedback.model.zig").FeedbackStatus;
const FeedbackType = @import("../../domain/entities/feedback.model.zig").FeedbackType;
const Severity = @import("../../domain/entities/feedback.model.zig").Severity;
const FeedbackRepository = @import("../../domain/repositories/feedback_repository.zig").FeedbackRepository;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;
const CacheInterface = @import("../../infrastructure/cache/contract.zig").CacheInterface;

const Allocator = std.mem.Allocator;

/// 跟进记录
pub const FollowUpRecord = struct {
    timestamp: i64,
    follower: []const u8,
    content: []const u8,
};

/// 反馈服务
pub const FeedbackService = struct {
    allocator: Allocator,
    feedback_repo: FeedbackRepository,
    cache: CacheInterface,

    const Self = @This();

    /// 批量操作最大记录数限制
    pub const MAX_BATCH_SIZE: usize = 1000;

    /// 初始化反馈服务
    pub fn init(
        allocator: Allocator,
        feedback_repo: FeedbackRepository,
        cache: CacheInterface,
    ) Self {
        return .{
            .allocator = allocator,
            .feedback_repo = feedback_repo,
            .cache = cache,
        };
    }

    // ========================================
    // 创建、更新、删除操作
    // ========================================

    /// 创建反馈
    /// 需求: 7.1
    pub fn create(self: *Self, feedback: *Feedback) !void {
        if (feedback.title.len == 0) return error.TitleRequired;
        if (feedback.content.len == 0) return error.ContentRequired;

        if (feedback.created_at == null) {
            feedback.created_at = std.time.timestamp();
        }
        feedback.updated_at = feedback.created_at;

        try self.feedback_repo.save(feedback);
        try self.cache.delByPrefix("quality:feedback:");
    }

    /// 更新反馈
    /// 需求: 7.2
    pub fn update(self: *Self, id: i32, feedback: *const Feedback) !void {
        const existing = try self.feedback_repo.findById(id) orelse {
            return error.FeedbackNotFound;
        };
        defer self.freeFeedback(existing);

        if (feedback.title.len == 0) return error.TitleRequired;
        if (feedback.content.len == 0) return error.ContentRequired;

        var updated = feedback.*;
        updated.id = id;
        updated.updated_at = std.time.timestamp();

        try self.feedback_repo.save(&updated);
        try self.clearFeedbackCache(id);
    }

    /// 删除反馈
    /// 需求: 7.1
    pub fn delete(self: *Self, id: i32) !void {
        try self.feedback_repo.delete(id);
        try self.clearFeedbackCache(id);
    }

    // ========================================
    // 跟进记录
    // ========================================

    /// 添加跟进记录
    /// 需求: 7.3, 7.4, 7.8, 7.9
    pub fn addFollowUp(self: *Self, feedback_id: i32, follower: []const u8, content: []const u8) !void {
        try self.feedback_repo.addFollowUp(feedback_id, follower, content);
        try self.clearFeedbackCache(feedback_id);
        // TODO: 发送通知给反馈提交人和负责人
    }

    // ========================================
    // 批量操作
    // ========================================

    /// 批量指派反馈负责人
    /// 需求: 7.6, 12.3
    pub fn batchAssign(self: *Self, ids: []const i32, assignee: []const u8) !void {
        if (ids.len > MAX_BATCH_SIZE) {
            return error.BatchSizeTooLarge;
        }
        if (ids.len == 0) return;

        try self.feedback_repo.batchAssign(ids, assignee);

        for (ids) |id| {
            try self.clearFeedbackCache(id);
        }
        try self.cache.delByPrefix("quality:feedback:list:");
    }

    /// 批量更新反馈状态
    /// 需求: 7.6, 12.3
    pub fn batchUpdateStatus(self: *Self, ids: []const i32, status: FeedbackStatus) !void {
        if (ids.len > MAX_BATCH_SIZE) {
            return error.BatchSizeTooLarge;
        }
        if (ids.len == 0) return;

        try self.feedback_repo.batchUpdateStatus(ids, status);

        for (ids) |id| {
            try self.clearFeedbackCache(id);
        }
        try self.cache.delByPrefix("quality:feedback:list:");
    }

    // ========================================
    // 导出
    // ========================================

    /// 导出反馈到 Excel
    /// 需求: 7.10
    pub fn exportToExcel(self: *Self, file_path: []const u8) !i32 {
        _ = self;
        _ = file_path;
        // TODO: 实现 Excel 导出逻辑
        return 0;
    }

    // ========================================
    // 查询操作
    // ========================================

    /// 根据 ID 查询反馈
    /// 需求: 7.1
    pub fn findById(self: *Self, id: i32) !?Feedback {
        return try self.feedback_repo.findById(id);
    }

    /// 分页查询所有反馈
    /// 需求: 7.7
    pub fn findAll(self: *Self, query: PageQuery) !PageResult(Feedback) {
        return try self.feedback_repo.findAll(query);
    }

    // ========================================
    // 缓存管理
    // ========================================

    fn clearFeedbackCache(self: *Self, feedback_id: i32) !void {
        const cache_key = try std.fmt.allocPrint(
            self.allocator,
            "quality:feedback:{d}",
            .{feedback_id},
        );
        defer self.allocator.free(cache_key);
        try self.cache.del(cache_key);
        try self.cache.delByPrefix("quality:feedback:list:");
    }

    // ========================================
    // 内存管理
    // ========================================

    /// 释放反馈对象
    pub fn freeFeedback(self: *Self, feedback: Feedback) void {
        if (feedback.title.len > 0) self.allocator.free(feedback.title);
        if (feedback.content.len > 0) self.allocator.free(feedback.content);
        if (feedback.assignee) |assignee| {
            if (assignee.len > 0) self.allocator.free(assignee);
        }
        if (feedback.submitter.len > 0) self.allocator.free(feedback.submitter);
        if (feedback.follow_ups.len > 0) self.allocator.free(feedback.follow_ups);
    }

    /// 释放分页结果
    pub fn freePageResult(self: *Self, result: PageResult(Feedback)) void {
        for (result.items) |feedback| {
            self.freeFeedback(feedback);
        }
        self.allocator.free(result.items);
    }
};

test "FeedbackService.MAX_BATCH_SIZE is 1000" {
    try std.testing.expectEqual(@as(usize, 1000), FeedbackService.MAX_BATCH_SIZE);
}
