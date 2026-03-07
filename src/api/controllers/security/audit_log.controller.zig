//! 审计日志控制器
//! 处理审计日志查询、导出等操作

const std = @import("std");
const zap = @import("zap");
const base = @import("../base.fn.zig");
const zigcms = @import("../../../../root.zig");
const AuditLogService = @import("../../../infrastructure/security/audit_log.zig").AuditLogService;
const AuditLogRepository = @import("../../../infrastructure/security/audit_log.zig").AuditLogRepository;

const Self = @This();

/// 获取审计日志列表
pub fn list(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const container = zigcms.core.di.getGlobalContainer() orelse return base.send_failed(req, "DI容器未初始化");
    const audit_service = container.resolve(AuditLogService) catch |e| return base.send_error(req, e);
    
    // 解析参数
    const user_id_str = try req.getParamStr(allocator, "user_id");
    const action = try req.getParamStr(allocator, "action");
    const resource_type = try req.getParamStr(allocator, "resource_type");
    const start_time_str = try req.getParamStr(allocator, "start_time");
    const end_time_str = try req.getParamStr(allocator, "end_time");
    
    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;
    
    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;
    
    // 构建查询
    var search_query = AuditLogRepository.SearchQuery{
        .page = page,
        .page_size = page_size,
    };
    
    if (user_id_str) |uid_str| {
        search_query.user_id = std.fmt.parseInt(i32, uid_str, 10) catch null;
    }
    
    if (action) |act| {
        search_query.action = act;
    }
    
    if (resource_type) |rt| {
        search_query.resource_type = rt;
    }
    
    if (start_time_str) |st| {
        search_query.start_time = std.fmt.parseInt(i64, st, 10) catch null;
    }
    
    if (end_time_str) |et| {
        search_query.end_time = std.fmt.parseInt(i64, et, 10) catch null;
    }
    
    // 调用服务
    const query_result = audit_service.*.search(search_query) catch |e| return base.send_error(req, e);
    
    base.send_ok(req, query_result);
}

/// 获取审计日志详情
pub fn get(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const id_str = try req.getParamStr(allocator, "id");
    if (id_str == null) return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str.?, 10) catch return base.send_failed(req, "无效的 id");
    
    _ = id; // TODO: 实现单条查询
    
    base.send_failed(req, "功能开发中");
}

/// 导出审计日志
pub fn exportLogs(_: *Self, req: zap.Request) !void {
    // TODO: 实现导出功能
    // 1. 查询数据
    // 2. 生成 Excel 文件
    // 3. 返回文件流
    base.send_failed(req, "功能开发中");
}

/// 获取用户操作日志
pub fn getUserLogs(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const user_id_str = try req.getParamStr(allocator, "user_id");
    if (user_id_str == null) return base.send_failed(req, "缺少参数 user_id");
    const user_id = std.fmt.parseInt(i32, user_id_str.?, 10) catch return base.send_failed(req, "无效的 user_id");
    
    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;
    
    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;
    
    const container = zigcms.core.di.getGlobalContainer() orelse return base.send_failed(req, "DI容器未初始化");
    const audit_service = container.resolve(AuditLogService) catch |e| return base.send_error(req, e);
    
    const result = audit_service.*.getUserLogs(user_id, page, page_size) catch |e| return base.send_error(req, e);
    
    base.send_ok(req, result);
}

/// 获取资源操作日志
pub fn getResourceLogs(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    
    const resource_type = try req.getParamStr(allocator, "resource_type");
    if (resource_type == null) return base.send_failed(req, "缺少参数 resource_type");
    
    const resource_id_str = try req.getParamStr(allocator, "resource_id");
    
    const page_str = try req.getParamStr(allocator, "page");
    const page = if (page_str) |ps| try std.fmt.parseInt(i32, ps, 10) else 1;
    
    const page_size_str = try req.getParamStr(allocator, "page_size");
    const page_size = if (page_size_str) |pss| try std.fmt.parseInt(i32, pss, 10) else 20;
    
    var resource_id: ?i32 = null;
    if (resource_id_str) |rid_str| {
        resource_id = std.fmt.parseInt(i32, rid_str, 10) catch null;
    }
    
    const container = zigcms.core.di.getGlobalContainer() orelse return base.send_failed(req, "DI容器未初始化");
    const audit_service = container.resolve(AuditLogService) catch |e| return base.send_error(req, e);
    
    const result = audit_service.*.getResourceLogs(resource_type.?, resource_id, page, page_size) catch |e| return base.send_error(req, e);
    
    base.send_ok(req, result);
}
