//! MySQL 审计日志仓储实现
//!
//! 实现审计日志的数据库持久化操作

const std = @import("std");
const AuditLog = @import("../../infrastructure/security/audit_log.zig").AuditLog;
const AuditLogRepository = @import("../../infrastructure/security/audit_log.zig").AuditLogRepository;
const sql_orm = @import("../../application/services/sql/orm.zig");

/// MySQL 审计日志仓储实现
pub const MysqlAuditLogRepository = struct {
    allocator: std.mem.Allocator,
    db: *sql_orm.Database,
    
    const Self = @This();
    
    /// 初始化仓储
    pub fn init(allocator: std.mem.Allocator, db: *sql_orm.Database) Self {
        return .{
            .allocator = allocator,
            .db = db,
        };
    }
    
    /// 保存审计日志
    pub fn save(self: *Self, log: *AuditLog) !void {
        _ = self;
        const OrmAuditLog = sql_orm.defineWithConfig(AuditLog, .{ .table_name = "audit_logs" });
        
        // 设置创建时间
        if (log.created_at == null) {
            log.created_at = std.time.timestamp();
        }
        
        // 插入数据库
        const created = try OrmAuditLog.Create(log.*);
        log.id = created.id;
    }
    
    /// 按用户查询审计日志
    pub fn findByUser(self: *Self, user_id: i32, query: AuditLogRepository.PageQuery) !AuditLogRepository.PageResult {
        _ = self;
        const OrmAuditLog = sql_orm.defineWithConfig(AuditLog, .{ .table_name = "audit_logs" });
        
        var q = OrmAuditLog.Query();
        defer q.deinit();
        
        _ = q.where("user_id", "=", user_id)
             .orderBy("created_at", .desc)
             .limit(@intCast(query.page_size))
             .offset(@intCast((query.page - 1) * query.page_size));
        
        const items = try q.get();
        const total = try q.count();
        
        return .{
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }
    
    /// 按资源查询审计日志
    pub fn findByResource(
        self: *Self,
        resource_type: []const u8,
        resource_id: ?i32,
        query: AuditLogRepository.PageQuery,
    ) !AuditLogRepository.PageResult {
        _ = self;
        const OrmAuditLog = sql_orm.defineWithConfig(AuditLog, .{ .table_name = "audit_logs" });
        
        var q = OrmAuditLog.Query();
        defer q.deinit();
        
        _ = q.where("resource_type", "=", resource_type);
        
        if (resource_id) |rid| {
            _ = q.where("resource_id", "=", rid);
        }
        
        _ = q.orderBy("created_at", .desc)
             .limit(@intCast(query.page_size))
             .offset(@intCast((query.page - 1) * query.page_size));
        
        const items = try q.get();
        const total = try q.count();
        
        return .{
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }
    
    /// 按操作类型查询审计日志
    pub fn findByAction(self: *Self, action: []const u8, query: AuditLogRepository.PageQuery) !AuditLogRepository.PageResult {
        _ = self;
        const OrmAuditLog = sql_orm.defineWithConfig(AuditLog, .{ .table_name = "audit_logs" });
        
        var q = OrmAuditLog.Query();
        defer q.deinit();
        
        _ = q.where("action", "=", action)
             .orderBy("created_at", .desc)
             .limit(@intCast(query.page_size))
             .offset(@intCast((query.page - 1) * query.page_size));
        
        const items = try q.get();
        const total = try q.count();
        
        return .{
            .items = items,
            .total = @intCast(total),
            .page = query.page,
            .page_size = query.page_size,
        };
    }
    
    /// 搜索审计日志
    pub fn search(self: *Self, search_query: AuditLogRepository.SearchQuery) !AuditLogRepository.PageResult {
        _ = self;
        const OrmAuditLog = sql_orm.defineWithConfig(AuditLog, .{ .table_name = "audit_logs" });
        
        var q = OrmAuditLog.Query();
        defer q.deinit();
        
        // 构建查询条件
        if (search_query.user_id) |uid| {
            _ = q.where("user_id", "=", uid);
        }
        
        if (search_query.resource_type) |rt| {
            _ = q.where("resource_type", "=", rt);
        }
        
        if (search_query.action) |act| {
            _ = q.where("action", "=", act);
        }
        
        if (search_query.start_time) |st| {
            _ = q.where("created_at", ">=", st);
        }
        
        if (search_query.end_time) |et| {
            _ = q.where("created_at", "<=", et);
        }
        
        _ = q.orderBy("created_at", .desc)
             .limit(@intCast(search_query.page_size))
             .offset(@intCast((search_query.page - 1) * search_query.page_size));
        
        const items = try q.get();
        const total = try q.count();
        
        return .{
            .items = items,
            .total = @intCast(total),
            .page = search_query.page,
            .page_size = search_query.page_size,
        };
    }
    
    /// VTable 实现
    pub fn vtable() AuditLogRepository.VTable {
        return .{
            .save = saveImpl,
            .findByUser = findByUserImpl,
            .findByResource = findByResourceImpl,
            .findByAction = findByActionImpl,
            .search = searchImpl,
        };
    }
    
    fn saveImpl(ptr: *anyopaque, log: *AuditLog) anyerror!void {
        const self: *MysqlAuditLogRepository = @ptrCast(@alignCast(ptr));
        return self.save(log);
    }
    
    fn findByUserImpl(ptr: *anyopaque, user_id: i32, query: AuditLogRepository.PageQuery) anyerror!AuditLogRepository.PageResult {
        const self: *MysqlAuditLogRepository = @ptrCast(@alignCast(ptr));
        return self.findByUser(user_id, query);
    }
    
    fn findByResourceImpl(
        ptr: *anyopaque,
        resource_type: []const u8,
        resource_id: ?i32,
        query: AuditLogRepository.PageQuery,
    ) anyerror!AuditLogRepository.PageResult {
        const self: *MysqlAuditLogRepository = @ptrCast(@alignCast(ptr));
        return self.findByResource(resource_type, resource_id, query);
    }
    
    fn findByActionImpl(ptr: *anyopaque, action: []const u8, query: AuditLogRepository.PageQuery) anyerror!AuditLogRepository.PageResult {
        const self: *MysqlAuditLogRepository = @ptrCast(@alignCast(ptr));
        return self.findByAction(action, query);
    }
    
    fn searchImpl(ptr: *anyopaque, query: AuditLogRepository.SearchQuery) anyerror!AuditLogRepository.PageResult {
        const self: *MysqlAuditLogRepository = @ptrCast(@alignCast(ptr));
        return self.search(query);
    }
};
