//! 审计日志控制器
//! 处理审计日志查询、导出等操作

const std = @import("std");
const zap = @import("zap");
const base = @import("../base.fn.zig");
const global = @import("../../../core/primitives/global.zig");
const sql_orm = @import("../../../application/services/sql/orm.zig");
const audit_mod = @import("../../../infrastructure/security/audit_log.zig");
const mysql_audit_repo = @import("../../../infrastructure/database/mysql_audit_log_repository.zig");
const AuditLog = audit_mod.AuditLog;
const AuditLogService = audit_mod.AuditLogService;
const AuditLogRepository = audit_mod.AuditLogRepository;
const MysqlAuditLogRepository = mysql_audit_repo.MysqlAuditLogRepository;

const Self = @This();
const OrmAuditLog = sql_orm.defineWithConfig(AuditLog, .{ .table_name = "audit_logs" });
const mysql_audit_vtable = MysqlAuditLogRepository.vtable();

fn parseOptionalInt(comptime T: type, value: ?[]const u8) ?T {
    const raw = value orelse return null;
    return std.fmt.parseInt(T, raw, 10) catch null;
}

fn parsePage(value: ?[]const u8, default_value: i32) i32 {
    return parseOptionalInt(i32, value) orelse default_value;
}

fn createAuditService(allocator: std.mem.Allocator) AuditLogService {
    const repo = allocator.create(MysqlAuditLogRepository) catch @panic("alloc MysqlAuditLogRepository failed");
    repo.* = MysqlAuditLogRepository.init(allocator, global.get_db());

    const repository = allocator.create(AuditLogRepository) catch @panic("alloc AuditLogRepository failed");
    repository.* = .{
        .ptr = repo,
        .vtable = &mysql_audit_vtable,
    };

    return AuditLogService.init(allocator, repository);
}

/// 获取审计日志列表
pub fn list(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    var audit_service = createAuditService(allocator);

    var search_query = AuditLogRepository.SearchQuery{
        .page = parsePage(req.getParamSlice("page"), 1),
        .page_size = parsePage(req.getParamSlice("page_size"), 20),
    };

    search_query.user_id = parseOptionalInt(i32, req.getParamSlice("user_id"));
    if (req.getParamSlice("action")) |act| search_query.action = act;
    if (req.getParamSlice("resource_type")) |rt| search_query.resource_type = rt;
    search_query.start_time = parseOptionalInt(i64, req.getParamSlice("start_time"));
    search_query.end_time = parseOptionalInt(i64, req.getParamSlice("end_time"));

    const query_result = audit_service.search(search_query) catch |e| return base.send_error(req, e);
    base.send_ok(req, query_result);
}

/// 获取审计日志详情
pub fn get(_: *Self, req: zap.Request) !void {
    req.parseQuery();
    const id_str = req.getParamSlice("id") orelse return base.send_failed(req, "缺少参数 id");
    const id = std.fmt.parseInt(i32, id_str, 10) catch return base.send_failed(req, "无效的 id");

    var q = OrmAuditLog.Query();
    defer q.deinit();
    _ = q.whereEq("id", id);

    const item = q.first() catch |e| return base.send_error(req, e);
    if (item == null) return base.send_failed(req, "记录不存在");

    var log_item = item.?;
    defer OrmAuditLog.freeModel(&log_item);
    base.send_ok(req, log_item);
}

/// 导出审计日志
pub fn exportLogs(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    var audit_service = createAuditService(allocator);

    var search_query = AuditLogRepository.SearchQuery{
        .page = 1,
        .page_size = parsePage(req.getParamSlice("page_size") orelse req.getParamSlice("limit"), 500),
    };

    search_query.user_id = parseOptionalInt(i32, req.getParamSlice("user_id"));
    if (req.getParamSlice("action")) |act| search_query.action = act;
    if (req.getParamSlice("resource_type")) |rt| search_query.resource_type = rt;
    search_query.start_time = parseOptionalInt(i64, req.getParamSlice("start_time"));
    search_query.end_time = parseOptionalInt(i64, req.getParamSlice("end_time"));

    const query_result = audit_service.search(search_query) catch |e| return base.send_error(req, e);
    base.send_ok(req, .{
        .list = query_result.items,
        .total = query_result.total,
        .page = query_result.page,
        .page_size = query_result.page_size,
        .exported = query_result.items.len,
    });
}

/// 获取用户操作日志
pub fn getUserLogs(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    const user_id_str = req.getParamSlice("user_id") orelse return base.send_failed(req, "缺少参数 user_id");
    const user_id = std.fmt.parseInt(i32, user_id_str, 10) catch return base.send_failed(req, "无效的 user_id");
    const page = parsePage(req.getParamSlice("page"), 1);
    const page_size = parsePage(req.getParamSlice("page_size"), 20);

    var audit_service = createAuditService(allocator);
    const result = audit_service.getUserLogs(user_id, page, page_size) catch |e| return base.send_error(req, e);
    base.send_ok(req, result);
}

/// 获取资源操作日志
pub fn getResourceLogs(_: *Self, req: zap.Request) !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    req.parseQuery();
    const resource_type = req.getParamSlice("resource_type") orelse return base.send_failed(req, "缺少参数 resource_type");
    const resource_id = parseOptionalInt(i32, req.getParamSlice("resource_id"));
    const page = parsePage(req.getParamSlice("page"), 1);
    const page_size = parsePage(req.getParamSlice("page_size"), 20);

    var audit_service = createAuditService(allocator);
    const result = audit_service.getResourceLogs(resource_type, resource_id, page, page_size) catch |e| return base.send_error(req, e);
    base.send_ok(req, result);
}
