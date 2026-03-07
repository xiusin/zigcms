//! 审核记录仓储接口

const std = @import("std");
const ModerationLog = @import("../entities/moderation_log.model.zig").ModerationLog;

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
};

/// 创建仓储实例
pub fn create(impl: anytype, vtable: *const ModerationLogRepository.VTable) ModerationLogRepository {
    return .{
        .ptr = impl,
        .vtable = vtable,
    };
}
