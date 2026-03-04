//! 需求控制器
//!
//! 提供需求管理的 HTTP 接口
//! 需求: 5.1, 5.2, 5.8, 5.10

const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

const RequirementService = @import("../../application/services/requirement_service.zig").RequirementService;
const RequirementCreateDto = @import("../dto/requirement_create.dto.zig").RequirementCreateDto;
const RequirementUpdateDto = @import("../dto/requirement_update.dto.zig").RequirementUpdateDto;
const RequirementLinkTestCaseDto = @import("../dto/requirement_link_test_case.dto.zig").RequirementLinkTestCaseDto;

pub fn create(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(RequirementCreateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(RequirementCreateDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var requirement = dto.toEntity();
    service.create(&requirement) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .code = 0, .msg = "创建成功", .data = requirement });
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
    const service = container.resolve(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const requirement = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "需求不存在");
        return;
    };
    defer service.freeRequirement(requirement);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = requirement }) catch |err| {
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

    var dto = json_mod.JSON.decode(RequirementUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(RequirementUpdateDto, allocator, &dto);

    const container = di.getGlobalContainer();
    const service = container.resolve(RequirementService) catch |err| {
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
    const service = container.resolve(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.delete(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "删除成功" });
}

pub fn linkTestCase(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(RequirementLinkTestCaseDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(RequirementLinkTestCaseDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.linkTestCase(dto.requirement_id, dto.test_case_id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "关联成功" });
}

pub fn unlinkTestCase(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(RequirementLinkTestCaseDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(RequirementLinkTestCaseDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.unlinkTestCase(dto.requirement_id, dto.test_case_id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "取消关联成功" });
}

pub fn importFromExcel(req: zap.Request) void {
    _ = req;
    // TODO: 实现 Excel 导入
}

pub fn exportToExcel(req: zap.Request) void {
    _ = req;
    // TODO: 实现 Excel 导出
}
