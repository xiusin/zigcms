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
const ProjectService = @import("../../application/services/project_service.zig").ProjectService;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;
const PageResult = @import("../../domain/repositories/test_case_repository.zig").PageResult;
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;
const RequirementCreateDto = @import("../dto/requirement_create.dto.zig").RequirementCreateDto;
const RequirementUpdateDto = @import("../dto/requirement_update.dto.zig").RequirementUpdateDto;
const RequirementLinkTestCaseDto = @import("../dto/requirement_link_test_case.dto.zig").RequirementLinkTestCaseDto;

pub fn list(req: zap.Request) void {
    const allocator = global.get_allocator();

    const project_id = if (req.getParamSlice("project_id")) |s|
        std.fmt.parseInt(i32, s, 10) catch null
    else
        null;
    const status = if (req.getParamSlice("status")) |s| Requirement.RequirementStatus.fromString(s) else null;
    const priority = if (req.getParamSlice("priority")) |s| Requirement.Priority.fromString(s) else null;
    const assignee = req.getParamSlice("assignee");
    const keyword = req.getParamSlice("keyword");
    const page = if (req.getParamSlice("page")) |s|
        std.fmt.parseInt(i32, s, 10) catch 1
    else
        1;
    const page_size = if (req.getParamSlice("page_size")) |s|
        std.fmt.parseInt(i32, s, 10) catch 20
    else
        20;

    const service = di.resolveService(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var filtered = std.ArrayList(Requirement){};
    defer filtered.deinit(allocator);
    errdefer {
        for (filtered.items) |item| {
            service.freeRequirement(item);
        }
    }

    if (project_id) |pid| {
        const result = service.findByProject(pid, PageQuery{ .page = 1, .page_size = 1000 }) catch |err| {
            base.send_error(req, err);
            return;
        };

        for (result.items) |item| {
            if (matchesRequirement(item, status, priority, assignee, keyword)) {
                filtered.append(allocator, item) catch |err| {
                    service.freeRequirement(item);
                    allocator.free(result.items);
                    base.send_error(req, err);
                    return;
                };
            } else {
                service.freeRequirement(item);
            }
        }
        allocator.free(result.items);
    } else {
        const project_service = di.resolveService(ProjectService) catch |err| {
            base.send_error(req, err);
            return;
        };

        const projects = project_service.findAll(PageQuery{ .page = 1, .page_size = 1000 }) catch |err| {
            base.send_error(req, err);
            return;
        };
        defer project_service.freePageResult(projects);

        for (projects.items) |project| {
            const pid = project.id orelse continue;
            const result = service.findByProject(pid, PageQuery{ .page = 1, .page_size = 1000 }) catch |err| {
                base.send_error(req, err);
                return;
            };

            for (result.items) |item| {
                if (matchesRequirement(item, status, priority, assignee, keyword)) {
                    filtered.append(allocator, item) catch |err| {
                        service.freeRequirement(item);
                        allocator.free(result.items);
                        base.send_error(req, err);
                        return;
                    };
                } else {
                    service.freeRequirement(item);
                }
            }
            allocator.free(result.items);
        }
    }

    const total: i32 = @intCast(filtered.items.len);
    const safe_page = if (page < 1) 1 else page;
    const safe_page_size = if (page_size < 1) 20 else page_size;
    const start: usize = @min(@as(usize, @intCast((safe_page - 1) * safe_page_size)), filtered.items.len);
    const end: usize = @min(start + @as(usize, @intCast(safe_page_size)), filtered.items.len);
    const paged_items = allocator.alloc(Requirement, end - start) catch |err| {
        base.send_error(req, err);
        return;
    };

    for (filtered.items, 0..) |item, idx| {
        if (idx >= start and idx < end) {
            paged_items[idx - start] = item;
        } else {
            service.freeRequirement(item);
        }
    }

    const response = .{
        .code = 0,
        .msg = "查询成功",
        .data = .{
            .items = paged_items,
            .total = total,
            .page = safe_page,
            .page_size = safe_page_size,
        },
    };

    const page_result: PageResult(Requirement) = .{
        .items = paged_items,
        .total = total,
        .page = safe_page,
        .page_size = safe_page_size,
    };

    const json = json_mod.JSON.encode(allocator, response) catch |err| {
        service.freePageResult(page_result);
        base.send_error(req, err);
        return;
    };
    defer allocator.free(json);
    defer service.freePageResult(page_result);

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

    var dto = json_mod.JSON.decode(RequirementCreateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(RequirementCreateDto, allocator, &dto);

    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    const service = di.resolveService(RequirementService) catch |err| {
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
    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    const service = di.resolveService(RequirementService) catch |err| {
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

    var dto = json_mod.JSON.decode(RequirementUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(RequirementUpdateDto, allocator, &dto);

    const service = di.resolveService(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    var requirement = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "需求不存在");
        return;
    };
    defer service.freeRequirement(requirement);

    dto.applyTo(&requirement);
    service.update(id, &requirement) catch |err| {
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

    const service = di.resolveService(RequirementService) catch |err| {
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
    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };
    const requirement_id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };
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

    const service = di.resolveService(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.linkTestCase(requirement_id, dto.test_case_id) catch |err| {
        base.send_error(req, err);
        return;
    };

    base.send_ok(req, .{ .message = "关联成功" });
}

pub fn unlinkTestCase(req: zap.Request) void {
    const id_str = req.getParamSlice("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };
    const requirement_id = std.fmt.parseInt(i32, id_str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };
    const case_id_str = req.getParamSlice("caseId") orelse {
        base.send_failed(req, "缺少参数 caseId");
        return;
    };
    const test_case_id = std.fmt.parseInt(i32, case_id_str, 10) catch {
        base.send_failed(req, "参数 caseId 格式错误");
        return;
    };

    const service = di.resolveService(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    service.unlinkTestCase(requirement_id, test_case_id) catch |err| {
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

fn matchesRequirement(
    requirement: Requirement,
    status: ?Requirement.RequirementStatus,
    priority: ?Requirement.Priority,
    assignee: ?[]const u8,
    keyword: ?[]const u8,
) bool {
    if (status) |expected| {
        if (requirement.status != expected) return false;
    }
    if (priority) |expected| {
        if (requirement.priority != expected) return false;
    }
    if (assignee) |expected| {
        if (requirement.assignee) |value| {
            if (!std.mem.eql(u8, value, expected)) return false;
        } else {
            return false;
        }
    }
    if (keyword) |expected| {
        if (!std.mem.containsAtLeast(u8, requirement.title, 1, expected) and
            !std.mem.containsAtLeast(u8, requirement.description, 1, expected))
        {
            return false;
        }
    }
    return true;
}
