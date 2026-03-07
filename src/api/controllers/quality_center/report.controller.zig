//! 质量中心报表控制器
//!
//! 功能：
//! - 生成测试用例报表
//! - 生成反馈报表
//! - 生成需求报表
//! - 生成项目质量报表

const std = @import("std");
const zap = @import("zap");
const zigcms = @import("zigcms");
const base = @import("../base.zig");
const QualityReportGenerator = @import("../../../infrastructure/report/quality_report_generator.zig").QualityReportGenerator;
const ReportParams = @import("../../../infrastructure/report/quality_report_generator.zig").ReportParams;
const ReportType = @import("../../../infrastructure/report/quality_report_generator.zig").ReportType;

/// 生成测试用例报表
pub fn generateTestCaseReport(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.STATISTICS_VIEW) catch {
        try base.send_error(req, 403, "无权限查看统计报表");
        return;
    };
    
    // 解析参数
    const start_date = req.getParamStr("start_date") orelse "2026-03-01";
    const end_date = req.getParamStr("end_date") orelse "2026-03-07";
    const project_id_str = req.getParamStr("project_id");
    
    const project_id = if (project_id_str) |pid_str|
        std.fmt.parseInt(i32, pid_str, 10) catch null
    else
        null;
    
    // 生成报表
    var generator = QualityReportGenerator.init(allocator);
    
    const params = ReportParams{
        .report_type = .test_case,
        .project_id = project_id,
        .start_date = start_date,
        .end_date = end_date,
    };
    
    var stats = try generator.generateTestCaseReport(params);
    defer generator.freeTestCaseStats(&stats);
    
    // 构建响应
    var response = std.json.ObjectMap.init(allocator);
    defer response.deinit();
    
    try response.put("total", .{ .integer = stats.total });
    try response.put("passed", .{ .integer = stats.passed });
    try response.put("failed", .{ .integer = stats.failed });
    try response.put("blocked", .{ .integer = stats.blocked });
    try response.put("skipped", .{ .integer = stats.skipped });
    try response.put("pass_rate", .{ .float = stats.pass_rate });
    try response.put("priority_high", .{ .integer = stats.priority_high });
    try response.put("priority_medium", .{ .integer = stats.priority_medium });
    try response.put("priority_low", .{ .integer = stats.priority_low });
    
    // 返回成功响应
    try base.send_success(req, response);
}

/// 生成反馈报表
pub fn generateFeedbackReport(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.STATISTICS_VIEW) catch {
        try base.send_error(req, 403, "无权限查看统计报表");
        return;
    };
    
    // 解析参数
    const start_date = req.getParamStr("start_date") orelse "2026-03-01";
    const end_date = req.getParamStr("end_date") orelse "2026-03-07";
    const project_id_str = req.getParamStr("project_id");
    
    const project_id = if (project_id_str) |pid_str|
        std.fmt.parseInt(i32, pid_str, 10) catch null
    else
        null;
    
    // 生成报表
    var generator = QualityReportGenerator.init(allocator);
    
    const params = ReportParams{
        .report_type = .feedback,
        .project_id = project_id,
        .start_date = start_date,
        .end_date = end_date,
    };
    
    var stats = try generator.generateFeedbackReport(params);
    defer generator.freeFeedbackStats(&stats);
    
    // 构建响应
    var response = std.json.ObjectMap.init(allocator);
    defer response.deinit();
    
    try response.put("total", .{ .integer = stats.total });
    try response.put("open", .{ .integer = stats.open });
    try response.put("in_progress", .{ .integer = stats.in_progress });
    try response.put("resolved", .{ .integer = stats.resolved });
    try response.put("closed", .{ .integer = stats.closed });
    try response.put("resolution_rate", .{ .float = stats.resolution_rate });
    try response.put("avg_resolution_time", .{ .float = stats.avg_resolution_time });
    try response.put("priority_high", .{ .integer = stats.priority_high });
    try response.put("priority_medium", .{ .integer = stats.priority_medium });
    try response.put("priority_low", .{ .integer = stats.priority_low });
    
    // 返回成功响应
    try base.send_success(req, response);
}

/// 生成需求报表
pub fn generateRequirementReport(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.STATISTICS_VIEW) catch {
        try base.send_error(req, 403, "无权限查看统计报表");
        return;
    };
    
    // 解析参数
    const start_date = req.getParamStr("start_date") orelse "2026-03-01";
    const end_date = req.getParamStr("end_date") orelse "2026-03-07";
    const project_id_str = req.getParamStr("project_id");
    
    const project_id = if (project_id_str) |pid_str|
        std.fmt.parseInt(i32, pid_str, 10) catch null
    else
        null;
    
    // 生成报表
    var generator = QualityReportGenerator.init(allocator);
    
    const params = ReportParams{
        .report_type = .requirement,
        .project_id = project_id,
        .start_date = start_date,
        .end_date = end_date,
    };
    
    var stats = try generator.generateRequirementReport(params);
    defer generator.freeRequirementStats(&stats);
    
    // 构建响应
    var response = std.json.ObjectMap.init(allocator);
    defer response.deinit();
    
    try response.put("total", .{ .integer = stats.total });
    try response.put("draft", .{ .integer = stats.draft });
    try response.put("reviewing", .{ .integer = stats.reviewing });
    try response.put("approved", .{ .integer = stats.approved });
    try response.put("in_development", .{ .integer = stats.in_development });
    try response.put("completed", .{ .integer = stats.completed });
    try response.put("completion_rate", .{ .float = stats.completion_rate });
    try response.put("priority_high", .{ .integer = stats.priority_high });
    try response.put("priority_medium", .{ .integer = stats.priority_medium });
    try response.put("priority_low", .{ .integer = stats.priority_low });
    try response.put("total_changes", .{ .integer = stats.total_changes });
    try response.put("avg_changes_per_requirement", .{ .float = stats.avg_changes_per_requirement });
    
    // 返回成功响应
    try base.send_success(req, response);
}

/// 生成项目质量报表
pub fn generateProjectQualityReport(req: zap.Request) !void {
    const allocator = req.allocator orelse return error.NoAllocator;
    
    // 权限检查
    const RbacMiddleware = @import("../../middleware/rbac.zig").RbacMiddleware;
    const QualityCenterPermissions = @import("../../middleware/rbac.zig").QualityCenterPermissions;
    const container = zigcms.core.di.getGlobalContainer();
    
    const rbac = try container.resolve(RbacMiddleware);
    rbac.checkPermission(&req, QualityCenterPermissions.STATISTICS_VIEW) catch {
        try base.send_error(req, 403, "无权限查看统计报表");
        return;
    };
    
    // 解析参数
    const start_date = req.getParamStr("start_date") orelse "2026-03-01";
    const end_date = req.getParamStr("end_date") orelse "2026-03-07";
    const project_id_str = req.getParamStr("project_id");
    
    const project_id = if (project_id_str) |pid_str|
        std.fmt.parseInt(i32, pid_str, 10) catch null
    else
        null;
    
    // 生成报表
    var generator = QualityReportGenerator.init(allocator);
    
    const params = ReportParams{
        .report_type = .project_quality,
        .project_id = project_id,
        .start_date = start_date,
        .end_date = end_date,
    };
    
    var stats = try generator.generateProjectQualityReport(params);
    defer generator.freeProjectQualityStats(&stats);
    
    // 构建响应
    var response = std.json.ObjectMap.init(allocator);
    defer response.deinit();
    
    try response.put("project_name", .{ .string = stats.project_name });
    try response.put("test_coverage", .{ .float = stats.test_coverage });
    try response.put("defect_density", .{ .float = stats.defect_density });
    try response.put("quality_score", .{ .float = stats.quality_score });
    try response.put("risk_level", .{ .string = stats.risk_level });
    try response.put("progress", .{ .float = stats.progress });
    
    // 返回成功响应
    try base.send_success(req, response);
}
