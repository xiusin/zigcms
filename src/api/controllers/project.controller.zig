//! 项目控制器
//!
//! 提供项目管理的 HTTP 接口，包括：
//! - 创建、查询、更新、删除项目
//! - 归档和恢复项目
//! - 查询项目统计数据
//!
//! ## 路由映射
//!
//! - POST   /api/quality/projects          - 创建项目
//! - GET    /api/quality/projects/:id      - 查询项目
//! - PUT    /api/quality/projects/:id      - 更新项目
//! - DELETE /api/quality/projects/:id      - 删除项目
//! - POST   /api/quality/projects/:id/archive - 归档项目
//! - POST   /api/quality/projects/:id/restore - 恢复项目
//! - GET    /api/quality/projects/:id/statistics - 查询项目统计
//!
//! 需求: 3.1, 3.2, 3.5, 3.6, 3.7, 3.8

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

// 导入服务
const ProjectService = @import("../../application/services/project_service.zig").ProjectService;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;

// 导入实体
const Project = @import("../../domain/entities/project.model.zig").Project;

// 导入 DTO
const ProjectCreateDto = @import("../dto/project_create.dto.zig").ProjectCreateDto;
const ProjectUpdateDto = @import("../dto/project_update.dto.zig").ProjectUpdateDto;

pub fn list(req: zap.Request) void {
    const allocator = global.get_allocator();

    const page = if (req.getParamSlice("page")) |s|
        std.fmt.parseInt(i32, s, 10) catch 1
    else
        1;

    const page_size = if (req.getParamSlice("page_size")) |s|
        std.fmt.parseInt(i32, s, 10) catch 100
    else
        100;

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const result = service.findAll(PageQuery{
        .page = page,
        .page_size = page_size,
    }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freePageResult(result);

    const response = .{
        .code = 0,
        .msg = "查询成功",
        .data = result,
    };

    const json = json_mod.JSON.encode(allocator, response) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

/// 创建项目
pub fn create(req: zap.Request) void {
    const allocator = global.get_allocator();

    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(ProjectCreateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(ProjectCreateDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var project = dto.toEntity();
    service.create(&project) catch |err| {
        base.send_error(req, err);
        return;
    };

    const response = .{
        .code = 0,
        .msg = "创建成功",
        .data = project,
    };

    const json = json_mod.JSON.encode(allocator, response) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

/// 查询项目
pub fn get(req: zap.Request) void {
    const allocator = global.get_allocator();

    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const project = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "项目不存在");
        return;
    };
    defer service.freeProject(project);

    const response = .{
        .code = 0,
        .msg = "查询成功",
        .data = project,
    };

    const json = json_mod.JSON.encode(allocator, response) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

/// 更新项目
pub fn update(req: zap.Request) void {
    const allocator = global.get_allocator();

    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(ProjectUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(ProjectUpdateDto, allocator, &dto);

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var project = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "项目不存在");
        return;
    };
    defer service.freeProject(project);

    dto.applyTo(&project);
    service.update(id, &project) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "更新成功" });
}

/// 删除项目
pub fn delete(req: zap.Request) void {
    const allocator = global.get_allocator();
    _ = allocator;

    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.delete(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "删除成功" });
}

/// 归档项目
pub fn archive(req: zap.Request) void {
    const allocator = global.get_allocator();
    _ = allocator;

    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.archive(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "归档成功" });
}

/// 恢复项目
pub fn restore(req: zap.Request) void {
    const allocator = global.get_allocator();
    _ = allocator;

    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.restore(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "恢复成功" });
}

/// 查询项目统计
pub fn getStatistics(req: zap.Request) void {
    const allocator = global.get_allocator();

    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(ProjectService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const statistics = service.getStatistics(id) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeStatistics(statistics);

    const response = .{
        .code = 0,
        .msg = "查询成功",
        .data = statistics,
    };

    const json = json_mod.JSON.encode(allocator, response) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}
