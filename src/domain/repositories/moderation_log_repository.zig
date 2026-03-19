//! 审核记录仓储接口

const std = @import("std");
const Allocator = std.mem.Allocator;
const ModerationLog = @import("../entities/moderation_log.model.zig").ModerationLog;

/// 审核统计数据结构
pub const ModerationStats = struct {
    total: i32,
    pending: i32,
    approved: i32,
    rejected: i32,
    auto_approved: i32,
    auto_rejected: i32,
};

/// 审核趋势数据项
pub const TrendItem = struct {
    date: []const u8,
    approved: i32,
    rejected: i32,
    pending: i32,
};

/// 敏感词统计数据项
pub const SensitiveWordStatItem = struct {
    word: []const u8,
    category: []const u8,
    hit_count: i32,
    level: i32,
};

/// 分类统计数据项
pub const CategoryStatItem = struct {
    category: []const u8,
    count: i32,
};

/// 用户违规统计数据项
pub const UserViolationStatItem = struct {
    user_id: i32,
    violation_count: i32,
    credit_score: i32,
    status: []const u8,
    last_violation_at: []const u8,
};

/// 审核效率统计数据
pub const EfficiencyStats = struct {
    avg_review_time: i32,
    auto_process_rate: f64,
    manual_review_rate: f64,
    reject_rate: f64,
    total_processed: i32,
    auto_approved: i32,
    auto_rejected: i32,
    manual_approved: i32,
    manual_rejected: i32,
};

/// 审核方式分布数据项
pub const ActionStatItem = struct {
    action: []const u8,
    count: i32,
};

/// 审核记录仓储接口
pub const ModerationLogRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    pub const VTable = struct {
        findById: *const fn (*anyopaque, i32) anyerror!?ModerationLog,
        findPending: *const fn (*anyopaque, i32, i32) anyerror!struct { items: []ModerationLog, total: i32 },
        findByContentId: *const fn (*anyopaque, []const u8, i32) anyerror!?ModerationLog,
        findByUserId: *const fn (*anyopaque, i32, i32, i32) anyerror!struct { items: []ModerationLog, total: i32 },
        save: *const fn (*anyopaque, *ModerationLog) anyerror!void,
        updateStatus: *const fn (*anyopaque, i32, []const u8, ?i32, ?[]const u8) anyerror!void,
        countByStatus: *const fn (*anyopaque, []const u8) anyerror!i32,
        countByDateRange: *const fn (*anyopaque, []const u8, []const u8, Allocator) anyerror!ModerationStats,
        getTrendByDateRange: *const fn (*anyopaque, []const u8, []const u8, Allocator) anyerror![]TrendItem,
        getSensitiveWordStats: *const fn (*anyopaque, []const u8, []const u8, i32, Allocator) anyerror![]SensitiveWordStatItem,
        getCategoryStats: *const fn (*anyopaque, []const u8, []const u8, Allocator) anyerror![]CategoryStatItem,
        getUserViolationStats: *const fn (*anyopaque, []const u8, []const u8, i32, Allocator) anyerror![]UserViolationStatItem,
        getEfficiencyStats: *const fn (*anyopaque, []const u8, []const u8) anyerror!EfficiencyStats,
        getActionDistribution: *const fn (*anyopaque, []const u8, []const u8, Allocator) anyerror![]ActionStatItem,
    };
    
    /// 根据 ID 查找
    pub fn findById(self: *Self, id: i32) !?ModerationLog {
        return self.vtable.findById(self.ptr, id);
    }
    
    /// 查找待审核列表
    pub fn findPending(self: *Self, page: i32, page_size: i32) !struct { items: []ModerationLog, total: i32 } {
        return self.vtable.findPending(self.ptr, page, page_size);
    }
    
    /// 根据内容 ID 查找
    pub fn findByContentId(self: *Self, content_type: []const u8, content_id: i32) !?ModerationLog {
        return self.vtable.findByContentId(self.ptr, content_type, content_id);
    }
    
    /// 根据用户 ID 查找
    pub fn findByUserId(self: *Self, user_id: i32, page: i32, page_size: i32) !struct { items: []ModerationLog, total: i32 } {
        return self.vtable.findByUserId(self.ptr, user_id, page, page_size);
    }
    
    /// 保存审核记录
    pub fn save(self: *Self, log: *ModerationLog) !void {
        return self.vtable.save(self.ptr, log);
    }
    
    /// 更新审核状态
    pub fn updateStatus(self: *Self, id: i32, status: []const u8, reviewer_id: ?i32, review_reason: ?[]const u8) !void {
        return self.vtable.updateStatus(self.ptr, id, status, reviewer_id, review_reason);
    }
    
    /// 统计指定状态的数量
    pub fn countByStatus(self: *Self, status: []const u8) !i32 {
        return self.vtable.countByStatus(self.ptr, status);
    }

    /// 统计指定日期范围内的审核数据
    pub fn countByDateRange(self: *Self, start_date: []const u8, end_date: []const u8, allocator: Allocator) !ModerationStats {
        return self.vtable.countByDateRange(self.ptr, start_date, end_date, allocator);
    }

    /// 获取审核趋势数据（按日期统计）
    pub fn getTrendByDateRange(self: *Self, start_date: []const u8, end_date: []const u8, allocator: Allocator) ![]TrendItem {
        return self.vtable.getTrendByDateRange(self.ptr, start_date, end_date, allocator);
    }

    /// 获取敏感词命中统计
    pub fn getSensitiveWordStats(self: *Self, start_date: []const u8, end_date: []const u8, limit: i32, allocator: Allocator) ![]SensitiveWordStatItem {
        return self.vtable.getSensitiveWordStats(self.ptr, start_date, end_date, limit, allocator);
    }

    /// 获取敏感词分类统计
    pub fn getCategoryStats(self: *Self, start_date: []const u8, end_date: []const u8, allocator: Allocator) ![]CategoryStatItem {
        return self.vtable.getCategoryStats(self.ptr, start_date, end_date, allocator);
    }

    /// 获取用户违规统计
    pub fn getUserViolationStats(self: *Self, start_date: []const u8, end_date: []const u8, limit: i32, allocator: Allocator) ![]UserViolationStatItem {
        return self.vtable.getUserViolationStats(self.ptr, start_date, end_date, limit, allocator);
    }

    /// 获取审核效率统计
    pub fn getEfficiencyStats(self: *Self, start_date: []const u8, end_date: []const u8) !EfficiencyStats {
        return self.vtable.getEfficiencyStats(self.ptr, start_date, end_date);
    }

    /// 获取审核方式分布
    pub fn getActionDistribution(self: *Self, start_date: []const u8, end_date: []const u8, allocator: Allocator) ![]ActionStatItem {
        return self.vtable.getActionDistribution(self.ptr, start_date, end_date, allocator);
    }
};

/// 创建仓储实例
pub fn create(impl: anytype, vtable: *const ModerationLogRepository.VTable) ModerationLogRepository {
    return .{
        .ptr = impl,
        .vtable = vtable,
    };
}
