//! 反馈控制器
//!
//! 提供反馈管理的 HTTP 接口
//! 需求: 7.1, 7.2, 7.3, 7.6, 7.8, 7.10

const std = @import("std");
const zap = @import("zap");
const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

const FeedbackService = @import("../../application/services/feedback_service.zig").FeedbackService;
const FeedbackCreateDto = @import("../dto/feedback_create.dto.zig").FeedbackCreateDto;
const FeedbackUpdateDto = @import("../dto/feedback_update.dto.zig").FeedbackUpdateDto;
const FeedbackFollowUpDto = @import("../dto/feedback_follow_up.dto.zig").FeedbackFollowUpDto;
const BatchUpdateStatusDto = @import("../dto/batch_update_status.dto.zig").BatchUpdateStatusDto;
const BatchUpdateAssigneeDto = @import("../dto/batch_update_assignee.dto.zig").BatchUpdateAssigneeDto;

pub fn create(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(FeedbackCreateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(FeedbackCreateDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var feedback = dto.toEntity();
    service.create(&feedback) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .code = 0, .msg = "创建成功", .data = feedback });
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
    const service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const feedback = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "反馈不存在");
        return;
    };
    defer service.freeFeedback(feedback);

    const json = json_mod.JSON.encode(allocator, .{ .code = 0, .msg = "查询成功", .data = feedback }) catch |err| {
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

    var dto = json_mod.JSON.decode(FeedbackUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(FeedbackUpdateDto, allocator, &dto);

    const container = di.getGlobalContainer();
    const service = container.resolve(FeedbackService) catch |err| {
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
    const service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.delete(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "删除成功" });
}

pub fn addFollowUp(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(FeedbackFollowUpDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(FeedbackFollowUpDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.addFollowUp(dto.feedback_id, dto.content, dto.follower) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "添加跟进记录成功" });
}

pub fn batchAssign(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(BatchUpdateAssigneeDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(BatchUpdateAssigneeDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.batchAssign(dto.ids, dto.assignee) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "批量指派成功" });
}

pub fn batchUpdateStatus(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(BatchUpdateStatusDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(BatchUpdateStatusDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const container = di.getGlobalContainer();
    const service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.batchUpdateStatus(dto.ids, dto.status) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "批量更新状态成功" });
}

pub fn exportToExcel(req: zap.Request) void {
    _ = req;
    // TODO: 实现 Excel 导出
}
