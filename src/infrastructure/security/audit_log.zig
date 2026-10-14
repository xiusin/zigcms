//! 审计日志实体与仓储接口
//!
//! 定义审计日志的数据模型和仓储抽象。

const std = @import("std");
const core_io = @import("../../core/io.zig");

/// 审计日志实体（映射 audit_logs 表）
pub const AuditLog = struct {
    id: ?i32 = null,
    user_id: i32 = 0,
    username: []const u8 = "",
    action: []const u8 = "",
    resource_type: []const u8 = "",
    resource_id: ?i32 = null,
    resource_name: []const u8 = "",
    description: []const u8 = "",
    before_data: []const u8 = "",
    after_data: []const u8 = "",
    client_ip: []const u8 = "",
    user_agent: []const u8 = "",
    result: []const u8 = "success",
    error_message: []const u8 = "",
    created_at: ?i64 = null,
};

/// 分页查询参数
pub const PageQuery = struct {
    page: i32 = 1,
    page_size: i32 = 20,
};

/// 分页查询结果
pub const PageResult = struct {
    items: []AuditLog,
    total: i64,
    page: i32,
    page_size: i32,
};

/// 搜索查询参数
pub const SearchQuery = struct {
    user_id: ?i32 = null,
    resource_type: ?[]const u8 = null,
    action: ?[]const u8 = null,
    start_time: ?i64 = null,
    end_time: ?i64 = null,
    page: i32 = 1,
    page_size: i32 = 20,
};

/// 审计日志仓储接口（使用 vtable 模式）
pub const AuditLogRepository = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        save: *const fn (*anyopaque, *AuditLog) anyerror!void,
        findByUser: *const fn (*anyopaque, i32, PageQuery) anyerror!PageResult,
        findByResource: *const fn (*anyopaque, []const u8, ?i32, PageQuery) anyerror!PageResult,
        findByAction: *const fn (*anyopaque, []const u8, PageQuery) anyerror!PageResult,
        search: *const fn (*anyopaque, SearchQuery) anyerror!PageResult,
    };

    pub fn save(self: *AuditLogRepository, log: *AuditLog) !void {
        return self.vtable.save(self.ptr, log);
    }

    pub fn findByUser(self: *AuditLogRepository, user_id: i32, query: PageQuery) !PageResult {
        return self.vtable.findByUser(self.ptr, user_id, query);
    }

    pub fn findByResource(self: *AuditLogRepository, resource_type: []const u8, resource_id: ?i32, query: PageQuery) !PageResult {
        return self.vtable.findByResource(self.ptr, resource_type, resource_id, query);
    }

    pub fn findByAction(self: *AuditLogRepository, action: []const u8, query: PageQuery) !PageResult {
        return self.vtable.findByAction(self.ptr, action, query);
    }

    pub fn search(self: *AuditLogRepository, query: SearchQuery) !PageResult {
        return self.vtable.search(self.ptr, query);
    }
};
