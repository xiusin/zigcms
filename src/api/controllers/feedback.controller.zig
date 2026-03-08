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
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const Feedback = @import("../../domain/entities/feedback.model.zig").Feedback;
const FeedbackCreateDto = @import("../dto/feedback_create.dto.zig").FeedbackCreateDto;
const FeedbackUpdateDto = @import("../dto/feedback_update.dto.zig").FeedbackUpdateDto;
const FeedbackFollowUpDto = @import("../dto/feedback_follow_up.dto.zig").FeedbackFollowUpDto;
const BatchUpdateAssigneeDto = @import("../dto/batch_update_assignee.dto.zig").BatchUpdateAssigneeDto;

pub fn list(req: zap.Request) void {
    const allocator = global.get_allocator();

    const status = if (req.getParamSlice("status")) |s| Feedback.FeedbackStatus.fromString(s) else null;
    const assignee = req.getParamSlice("assignee");
    const severity = if (req.getParamSlice("severity")) |s| Feedback.Severity.fromString(s) else null;
    const feedback_type = if (req.getParamSlice("type")) |s| Feedback.FeedbackType.fromString(s) else null;
    const keyword = req.getParamSlice("keyword");
    const page = if (req.getParamSlice("page")) |s|
        std.fmt.parseInt(i32, s, 10) catch 1
    else
        1;
    const page_size = if (req.getParamSlice("page_size")) |s|
        std.fmt.parseInt(i32, s, 10) catch 20
    else
        20;

    const service = di.resolveService(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const result = service.findAll(PageQuery{ .page = 1, .page_size = 1000 }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freePageResult(result);

    var filtered = std.ArrayList(Feedback){};
    defer filtered.deinit(allocator);

    for (result.items) |item| {
        if (matchesFeedback(item, status, assignee, severity, feedback_type, keyword)) {
            filtered.append(allocator, copyFeedback(allocator, item) catch |err| {
                base.send_error(req, err);
                return;
            }) catch |err| {
                for (filtered.items) |copied| freeFeedbackCopy(allocator, copied);
                base.send_error(req, err);
                return;
            };
        }
    }

    defer {
        for (filtered.items) |item| freeFeedbackCopy(allocator, item);
    }

    const total: i32 = @intCast(filtered.items.len);
    const safe_page = if (page < 1) 1 else page;
    const safe_page_size = if (page_size < 1) 20 else page_size;
    const start: usize = @min(@as(usize, @intCast((safe_page - 1) * safe_page_size)), filtered.items.len);
    const end: usize = @min(start + @as(usize, @intCast(safe_page_size)), filtered.items.len);
    const paged_items = allocator.alloc(Feedback, end - start) catch |err| {
        base.send_error(req, err);
        return;
    };
    var filled: usize = 0;
    defer {
        for (paged_items[0..filled]) |item| freeFeedbackCopy(allocator, item);
        allocator.free(paged_items);
    }

    for (start..end) |idx| {
        paged_items[idx - start] = copyFeedback(allocator, filtered.items[idx]) catch |err| {
            base.send_error(req, err);
            return;
        };
        filled += 1;
    }

    const json = json_mod.JSON.encode(allocator, .{
        .code = 0,
        .msg = "查询成功",
        .data = .{
            .items = paged_items,
            .total = total,
            .page = safe_page,
            .page_size = safe_page_size,
        },
    }) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);

    req.setStatus(.ok);
    req.setHeader("Content-Type", "application/json; charset=utf-8") catch {};
    req.sendBody(json) catch {};
}

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

    const service = di.resolveService(FeedbackService) catch |err| {
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
    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(FeedbackService) catch |err| {
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

    var dto = json_mod.JSON.decode(FeedbackUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(FeedbackUpdateDto, allocator, &dto);

    const service = di.resolveService(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var feedback = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "反馈不存在");
        return;
    };
    defer service.freeFeedback(feedback);

    dto.applyTo(&feedback);
    service.update(id, &feedback) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "更新成功" });
}

pub fn delete(req: zap.Request) void {
    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(FeedbackService) catch |err| {
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
    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };
    const feedback_id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };
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

    const service = di.resolveService(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.addFollowUp(feedback_id, dto.follower, dto.content) catch |err| {
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

    const service = di.resolveService(FeedbackService) catch |err| {
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

    const Payload = struct {
        ids: []const i32,
        status: Feedback.FeedbackStatus,
    };

    var dto = json_mod.JSON.decode(Payload, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(Payload, allocator, &dto);

    if (dto.ids.len == 0 or dto.ids.len > 1000) {
        base.send_failed(req, "参数 ids 格式错误");
        return;
    }

    const service = di.resolveService(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.batchUpdateStatus(dto.ids, dto.status) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "批量更新状态成功" });
}

pub fn batchDelete(req: zap.Request) void {
    const allocator = global.get_allocator();
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    const Payload = struct {
        ids: []const i32,
    };

    var dto = json_mod.JSON.decode(Payload, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(Payload, allocator, &dto);

    if (dto.ids.len == 0 or dto.ids.len > 1000) {
        base.send_failed(req, "参数 ids 格式错误");
        return;
    }

    const service = di.resolveService(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    for (dto.ids) |id| {
        service.delete(id) catch |err| {
            base.send_error(req, err);
            return;
        };
    }

    base.send_ok(req, .{ .message = "批量删除成功" });
}

pub fn updateStatus(req: zap.Request) void {
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

    const Payload = struct {
        status: Feedback.FeedbackStatus,
    };

    var dto = json_mod.JSON.decode(Payload, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(Payload, allocator, &dto);

    const service = di.resolveService(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var feedback = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "反馈不存在");
        return;
    };
    defer service.freeFeedback(feedback);

    feedback.status = dto.status;
    service.update(id, &feedback) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "更新成功" });
}

pub fn exportToExcel(req: zap.Request) void {
    const csv = "id,title,status\n";
    req.setStatus(.ok);
    req.setHeader("Content-Type", "text/csv; charset=utf-8") catch {};
    req.sendBody(csv) catch {};
}

fn matchesFeedback(
    feedback: Feedback,
    status: ?Feedback.FeedbackStatus,
    assignee: ?[]const u8,
    severity: ?Feedback.Severity,
    feedback_type: ?Feedback.FeedbackType,
    keyword: ?[]const u8,
) bool {
    if (status) |expected| {
        if (feedback.status != expected) return false;
    }
    if (severity) |expected| {
        if (feedback.severity != expected) return false;
    }
    if (feedback_type) |expected| {
        if (feedback.type != expected) return false;
    }
    if (assignee) |expected| {
        if (feedback.assignee) |value| {
            if (!std.mem.eql(u8, value, expected)) return false;
        } else {
            return false;
        }
    }
    if (keyword) |expected| {
        if (!std.mem.containsAtLeast(u8, feedback.title, 1, expected) and
            !std.mem.containsAtLeast(u8, feedback.content, 1, expected))
        {
            return false;
        }
    }
    return true;
}

fn copyFeedback(allocator: std.mem.Allocator, feedback: Feedback) !Feedback {
    return .{
        .id = feedback.id,
        .title = try allocator.dupe(u8, feedback.title),
        .content = try allocator.dupe(u8, feedback.content),
        .type = feedback.type,
        .severity = feedback.severity,
        .status = feedback.status,
        .assignee = if (feedback.assignee) |value| try allocator.dupe(u8, value) else null,
        .submitter = try allocator.dupe(u8, feedback.submitter),
        .follow_ups = try allocator.dupe(u8, feedback.follow_ups),
        .follow_count = feedback.follow_count,
        .last_follow_at = feedback.last_follow_at,
        .created_at = feedback.created_at,
        .updated_at = feedback.updated_at,
    };
}

fn freeFeedbackCopy(allocator: std.mem.Allocator, feedback: Feedback) void {
    if (feedback.title.len > 0) allocator.free(feedback.title);
    if (feedback.content.len > 0) allocator.free(feedback.content);
    if (feedback.assignee) |value| {
        if (value.len > 0) allocator.free(value);
    }
    if (feedback.submitter.len > 0) allocator.free(feedback.submitter);
    if (feedback.follow_ups.len > 0) allocator.free(feedback.follow_ups);
}
