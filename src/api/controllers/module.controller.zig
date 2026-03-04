//! 模块控制器
//!
//! 提供模块管理的 HTTP 接口，包括：
//! - 创建、查询、更新、删除模块
//! - 查询模块树形结构
//! - 拖拽移动模块
//! - 查询模块统计数据
//!
//! 需求: 4.1, 4.2, 4.4, 4.6

const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

const ModuleService = @import("../../application/services/module_service.zig").ModuleService;
const ModuleCreateDto = @import("../dto/module_create.dto.zig").ModuleCreateDto;
const ModuleUpdateDto = @import("../dto/module_update.dto.zig").ModuleUpdateDto;
const ModuleMoveDto = @import("../dto/module_move.dto.zig").ModuleMoveDto;

pub fn create(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(ModuleCreateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(ModuleCreateDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var module = dto.toEntity();
    service.create(&module) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .code = 0, .msg = "创建成功", .data = module });
}

pub fn get(req: zap.Request) void {
    const allocator = global.get_allocator();
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const module = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "模块不存在");
        return;
    };
    defer service.freeModule(module);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = module }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

pub fn update(req: zap.Request) void {
    const allocator = global.get_allocator();
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(ModuleUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(ModuleUpdateDto, allocator, &dto);

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.update(id, dto) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "更新成功" });
}

pub fn delete(req: zap.Request) void {
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.delete(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "删除成功" });
}

pub fn getTree(req: zap.Request) void {
    const allocator = global.get_allocator();
    const project_id_str = req.getParamStr("project_id") orelse {
        base.send_failed(req, "缺少参数 project_id");
        return;
    };

    const project_id = std.fmt.parseInt(i32, project_id_str.str, 10) catch {
        base.send_failed(req, "参数 project_id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const tree = service.getTree(project_id) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeTree(tree);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = tree }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

pub fn move(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(ModuleMoveDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(ModuleMoveDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.move(dto.module_id, dto.target_parent_id, dto.sort_order) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "移动成功" });
}

pub fn getStatistics(req: zap.Request) void {
    const allocator = global.get_allocator();
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(ModuleService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const statistics = service.getStatistics(id) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeStatistics(statistics);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = statistics }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}
