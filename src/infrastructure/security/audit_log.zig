//! 审计日志系统
//!
//! 记录所有敏感操作和重要业务操作

const std = @import("std");

/// 审计日志实体
pub const AuditLog = struct {
    /// 日志 ID
    id: ?i32 = null,
    /// 用户 ID
    user_id: i32,
    /// 用户名
    username: []const u8 = "",
    /// 操作类型
    action: []const u8,
    /// 资源类型
    resource_type: []const u8,
    /// 资源 ID
    resource_id: ?i32 = null,
    /// 资源名称
    resource_name: []const u8 = "",
    /// 操作描述
    description: []const u8 = "",
    /// 操作前数据（JSON）
    before_data: []const u8 = "{}",
    /// 操作后数据（JSON）
    after_data: []const u8 = "{}",
    /// 客户端 IP
    client_ip: []const u8 = "",
    /// User-Agent
    user_agent: []const u8 = "",
    /// 操作结果（success/failed）
    result: []const u8 = "success",
    /// 错误信息
    error_message: []const u8 = "",
    /// 创建时间
    created_at: ?i64 = null,
};

/// 审计日志仓储接口
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
    
    pub const PageQuery = struct {
        page: i32 = 1,
        page_size: i32 = 20,
    };
    
    pub const SearchQuery = struct {
        user_id: ?i32 = null,
        resource_type: ?[]const u8 = null,
        action: ?[]const u8 = null,
        start_time: ?i64 = null,
        end_time: ?i64 = null,
        page: i32 = 1,
        page_size: i32 = 20,
    };
    
    pub const PageResult = struct {
        items: []AuditLog,
        total: i32,
        page: i32,
        page_size: i32,
    };
    
    pub fn save(self: *Self, log: *AuditLog) !void {
        return self.vtable.save(self.ptr, log);
    }
    
    pub fn findByUser(self: *Self, user_id: i32, query: PageQuery) !PageResult {
        return self.vtable.findByUser(self.ptr, user_id, query);
    }
    
    pub fn findByResource(self: *Self, resource_type: []const u8, resource_id: ?i32, query: PageQuery) !PageResult {
        return self.vtable.findByResource(self.ptr, resource_type, resource_id, query);
    }
    
    pub fn findByAction(self: *Self, action: []const u8, query: PageQuery) !PageResult {
        return self.vtable.findByAction(self.ptr, action, query);
    }
    
    pub fn search(self: *Self, query: SearchQuery) !PageResult {
        return self.vtable.search(self.ptr, query);
    }
    
    const Self = @This();
};

/// 审计日志服务
pub const AuditLogService = struct {
    allocator: std.mem.Allocator,
    repository: *AuditLogRepository,
    
    const Self = @This();
    
    /// 初始化审计日志服务
    pub fn init(allocator: std.mem.Allocator, repository: *AuditLogRepository) Self {
        return .{
            .allocator = allocator,
            .repository = repository,
        };
    }
    
    /// 记录审计日志
    pub fn log(
        self: *Self,
        user_id: i32,
        username: []const u8,
        action: []const u8,
        resource_type: []const u8,
        resource_id: ?i32,
        resource_name: []const u8,
        description: []const u8,
        client_ip: []const u8,
    ) !void {
        var audit_log = AuditLog{
            .user_id = user_id,
            .username = username,
            .action = action,
            .resource_type = resource_type,
            .resource_id = resource_id,
            .resource_name = resource_name,
            .description = description,
            .client_ip = client_ip,
            .created_at = std.time.timestamp(),
        };
        
        try self.repository.*.save(&audit_log);
    }
    
    /// 记录操作（带数据变更）
    pub fn logWithData(
        self: *Self,
        user_id: i32,
        username: []const u8,
        action: []const u8,
        resource_type: []const u8,
        resource_id: ?i32,
        resource_name: []const u8,
        description: []const u8,
        before_data: []const u8,
        after_data: []const u8,
        client_ip: []const u8,
    ) !void {
        var audit_log = AuditLog{
            .user_id = user_id,
            .username = username,
            .action = action,
            .resource_type = resource_type,
            .resource_id = resource_id,
            .resource_name = resource_name,
            .description = description,
            .before_data = before_data,
            .after_data = after_data,
            .client_ip = client_ip,
            .created_at = std.time.timestamp(),
        };
        
        try self.repository.*.save(&audit_log);
    }
    
    /// 记录失败操作
    pub fn logFailure(
        self: *Self,
        user_id: i32,
        username: []const u8,
        action: []const u8,
        resource_type: []const u8,
        error_message: []const u8,
        client_ip: []const u8,
    ) !void {
        var audit_log = AuditLog{
            .user_id = user_id,
            .username = username,
            .action = action,
            .resource_type = resource_type,
            .result = "failed",
            .error_message = error_message,
            .client_ip = client_ip,
            .created_at = std.time.timestamp(),
        };
        
        try self.repository.*.save(&audit_log);
    }
    
    /// 查询用户操作日志
    pub fn getUserLogs(self: *Self, user_id: i32, page: i32, page_size: i32) !AuditLogRepository.PageResult {
        return try self.repository.*.findByUser(user_id, .{
            .page = page,
            .page_size = page_size,
        });
    }
    
    /// 查询资源操作日志
    pub fn getResourceLogs(
        self: *Self,
        resource_type: []const u8,
        resource_id: ?i32,
        page: i32,
        page_size: i32,
    ) !AuditLogRepository.PageResult {
        return try self.repository.*.findByResource(resource_type, resource_id, .{
            .page = page,
            .page_size = page_size,
        });
    }
    
    /// 搜索审计日志
    pub fn search(self: *Self, query: AuditLogRepository.SearchQuery) !AuditLogRepository.PageResult {
        return try self.repository.*.search(query);
    }
};

/// 质量中心审计操作定义
pub const QualityCenterAuditActions = struct {
    // 测试用例操作
    pub const TEST_CASE_CREATE = "创建测试用例";
    pub const TEST_CASE_UPDATE = "更新测试用例";
    pub const TEST_CASE_DELETE = "删除测试用例";
    pub const TEST_CASE_BATCH_DELETE = "批量删除测试用例";
    pub const TEST_CASE_EXECUTE = "执行测试用例";
    
    // 项目操作
    pub const PROJECT_CREATE = "创建项目";
    pub const PROJECT_UPDATE = "更新项目";
    pub const PROJECT_DELETE = "删除项目";
    pub const PROJECT_ARCHIVE = "归档项目";
    
    // 模块操作
    pub const MODULE_CREATE = "创建模块";
    pub const MODULE_UPDATE = "更新模块";
    pub const MODULE_DELETE = "删除模块";
    pub const MODULE_MOVE = "移动模块";
    
    // 需求操作
    pub const REQUIREMENT_CREATE = "创建需求";
    pub const REQUIREMENT_UPDATE = "更新需求";
    pub const REQUIREMENT_DELETE = "删除需求";
    pub const REQUIREMENT_LINK = "关联测试用例";
    
    // 反馈操作
    pub const FEEDBACK_CREATE = "创建反馈";
    pub const FEEDBACK_UPDATE = "更新反馈";
    pub const FEEDBACK_DELETE = "删除反馈";
    pub const FEEDBACK_ASSIGN = "分配反馈";
    pub const FEEDBACK_FOLLOW_UP = "跟进反馈";
    
    // 数据导出
    pub const EXPORT_TEST_CASES = "导出测试用例";
    pub const EXPORT_REQUIREMENTS = "导出需求";
    pub const EXPORT_FEEDBACKS = "导出反馈";
    pub const EXPORT_STATISTICS = "导出统计数据";
};
