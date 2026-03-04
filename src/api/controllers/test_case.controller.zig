//! 测试用例控制器
//!
//! 提供测试用例管理的 HTTP 接口，包括：
//! - 创建、查询、更新、删除测试用例
//! - 批量操作（批量删除、批量更新状态、批量分配负责人）
//! - 执行测试用例并查看执行历史
//! - 搜索和筛选测试用例
//!
//! ## 设计原则
//!
//! - **职责最小化**: 控制器只做参数解析和响应返回
//! - **不包含业务逻辑**: 所有业务逻辑由 Service 层处理
//! - **统一错误处理**: 使用 base.send_error 统一处理错误
//! - **参数验证**: 在控制器层进行基础参数验证
//!
//! ## 路由映射
//!
//! - POST   /api/quality/test-cases          - 创建测试用例
//! - GET    /api/quality/test-cases/:id      - 查询测试用例
//! - PUT    /api/quality/test-cases/:id      - 更新测试用例
//! - DELETE /api/quality/test-cases/:id      - 删除测试用例
//! - GET    /api/quality/test-cases          - 搜索测试用例
//! - POST   /api/quality/test-cases/batch-delete - 批量删除
//! - POST   /api/quality/test-cases/batch-update-status - 批量更新状态
//! - POST   /api/quality/test-cases/batch-update-assignee - 批量分配负责人
//! - POST   /api/quality/test-cases/:id/execute - 执行测试用例
//! - GET    /api/quality/test-cases/:id/executions - 查看执行历史
//!
//! 需求: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 1.9, 10.8, 12.3

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

// 导入服务
const TestCaseService = @import("../../application/services/test_case_service.zig").TestCaseService;

// 导入实体
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;
const TestCaseStatus = @import("../../domain/entities/test_case.model.zig").TestCase.TestCaseStatus;
const TestExecution = @import("../../domain/entities/test_execution.model.zig").TestExecution;
const ExecutionStatus = @import("../../domain/entities/test_execution.model.zig").TestExecution.ExecutionStatus;

// 导入 DTO
const TestCaseCreateDto = @import("../dto/test_case_create.dto.zig").TestCaseCreateDto;
const TestCaseUpdateDto = @import("../dto/test_case_update.dto.zig").TestCaseUpdateDto;
const TestCaseExecuteDto = @import("../dto/test_case_execute.dto.zig").TestCaseExecuteDto;
const BatchDeleteDto = @import("../dto/batch_delete.dto.zig").BatchDeleteDto;
const BatchUpdateStatusDto = @import("../dto/batch_update_status.dto.zig").BatchUpdateStatusDto;
const BatchUpdateAssigneeDto = @import("../dto/batch_update_assignee.dto.zig").BatchUpdateAssigneeDto;

// 导入查询类型
const SearchQuery = @import("../../domain/repositories/test_case_repository.zig").SearchQuery;
const PageQuery = @import("../../domain/repositories/test_case_repository.zig").PageQuery;

/// 创建测试用例
///
/// POST /api/quality/test-cases
///
/// 请求体:
/// ```json
/// {
///   "title": "测试登录功能",
///   "project_id": 1,
///   "module_id": 2,
///   "requirement_id": 3,
///   "priority": "high",
///   "precondition": "用户已注册",
///   "steps": "1. 打开登录页面\n2. 输入用户名密码\n3. 点击登录",
///   "expected_result": "登录成功，跳转到首页",
///   "assignee": "tester1",
///   "tags": "[\"登录\", \"功能测试\"]",
///   "created_by": "admin"
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "创建成功",
///   "data": {
///     "id": 1,
///     "title": "测试登录功能",
///     ...
///   }
/// }
/// ```
///
/// 需求: 1.1, 1.2
pub fn create(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(TestCaseCreateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(TestCaseCreateDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 转换为实体
    var test_case = dto.toEntity();

    // 5. 调用服务创建
    service.create(&test_case) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 6. 返回成功响应
    const response = .{
        .code = 0,
        .msg = "创建成功",
        .data = test_case,
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

/// 查询测试用例
///
/// GET /api/quality/test-cases/:id
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "查询成功",
///   "data": {
///     "id": 1,
///     "title": "测试登录功能",
///     ...
///   }
/// }
/// ```
///
/// 需求: 1.1
pub fn get(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析路径参数
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    // 2. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 调用服务查询
    const test_case = service.findById(id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "测试用例不存在");
        return;
    };
    defer service.freeTestCase(test_case);

    // 4. 返回成功响应
    const response = .{
        .code = 0,
        .msg = "查询成功",
        .data = test_case,
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

/// 更新测试用例
///
/// PUT /api/quality/test-cases/:id
///
/// 请求体:
/// ```json
/// {
///   "title": "测试登录功能（更新）",
///   "status": "passed",
///   "assignee": "tester2"
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "更新成功"
/// }
/// ```
///
/// 需求: 1.2
pub fn update(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析路径参数
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    // 2. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(TestCaseUpdateDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(TestCaseUpdateDto, allocator, &dto);

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 调用服务更新
    service.update(id, dto) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 5. 返回成功响应
    base.send_ok(req, .{ .message = "更新成功" });
}

/// 删除测试用例
///
/// DELETE /api/quality/test-cases/:id
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "删除成功"
/// }
/// ```
///
/// 需求: 1.3
pub fn delete(req: zap.Request) void {
    const allocator = global.get_allocator();
    _ = allocator;

    // 1. 解析路径参数
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    // 2. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 调用服务删除
    service.delete(id) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 返回成功响应
    base.send_ok(req, .{ .message = "删除成功" });
}

/// 搜索测试用例
///
/// GET /api/quality/test-cases?project_id=1&module_id=2&status=pending&page=1&page_size=20
///
/// 查询参数:
/// - project_id: 项目 ID（可选）
/// - module_id: 模块 ID（可选）
/// - status: 状态（可选）
/// - assignee: 负责人（可选）
/// - keyword: 关键字（可选）
/// - page: 页码（默认 1）
/// - page_size: 每页大小（默认 20）
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "查询成功",
///   "data": {
///     "items": [...],
///     "total": 100,
///     "page": 1,
///     "page_size": 20
///   }
/// }
/// ```
///
/// 需求: 1.9
pub fn search(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析查询参数
    const project_id = if (req.getParamStr("project_id")) |s|
        std.fmt.parseInt(i32, s.str, 10) catch null
    else
        null;

    const module_id = if (req.getParamStr("module_id")) |s|
        std.fmt.parseInt(i32, s.str, 10) catch null
    else
        null;

    const status_str = if (req.getParamStr("status")) |s| s.str else null;
    const status = if (status_str) |s| parseStatus(s) else null;

    const assignee = if (req.getParamStr("assignee")) |s| s.str else null;
    const keyword = if (req.getParamStr("keyword")) |s| s.str else null;

    const page = if (req.getParamStr("page")) |s|
        std.fmt.parseInt(i32, s.str, 10) catch 1
    else
        1;

    const page_size = if (req.getParamStr("page_size")) |s|
        std.fmt.parseInt(i32, s.str, 10) catch 20
    else
        20;

    // 2. 构建查询对象
    const query = SearchQuery{
        .project_id = project_id,
        .module_id = module_id,
        .status = status,
        .assignee = assignee,
        .keyword = keyword,
        .page = page,
        .page_size = page_size,
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 调用服务搜索
    const result = service.search(query) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freePageResult(result);

    // 5. 返回成功响应
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

/// 批量删除测试用例
///
/// POST /api/quality/test-cases/batch-delete
///
/// 请求体:
/// ```json
/// {
///   "ids": [1, 2, 3]
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "批量删除成功"
/// }
/// ```
///
/// 需求: 1.3
pub fn batchDelete(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(BatchDeleteDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(BatchDeleteDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 调用服务批量删除
    service.batchDelete(dto.ids) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 5. 返回成功响应
    base.send_ok(req, .{ .message = "批量删除成功" });
}

/// 批量更新测试用例状态
///
/// POST /api/quality/test-cases/batch-update-status
///
/// 请求体:
/// ```json
/// {
///   "ids": [1, 2, 3],
///   "status": "passed"
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "批量更新状态成功"
/// }
/// ```
///
/// 需求: 1.4
pub fn batchUpdateStatus(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(BatchUpdateStatusDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(BatchUpdateStatusDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 调用服务批量更新状态
    service.batchUpdateStatus(dto.ids, dto.status) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 5. 返回成功响应
    base.send_ok(req, .{ .message = "批量更新状态成功" });
}

/// 批量分配测试用例负责人
///
/// POST /api/quality/test-cases/batch-update-assignee
///
/// 请求体:
/// ```json
/// {
///   "ids": [1, 2, 3],
///   "assignee": "tester1"
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "批量分配负责人成功"
/// }
/// ```
///
/// 需求: 1.5
pub fn batchUpdateAssignee(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(BatchUpdateAssigneeDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(BatchUpdateAssigneeDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 调用服务批量分配负责人
    service.batchUpdateAssignee(dto.ids, dto.assignee) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 5. 返回成功响应
    base.send_ok(req, .{ .message = "批量分配负责人成功" });
}

/// 执行测试用例
///
/// POST /api/quality/test-cases/:id/execute
///
/// 请求体:
/// ```json
/// {
///   "executor": "tester1",
///   "status": "passed",
///   "actual_result": "登录成功",
///   "remark": "测试通过",
///   "duration_ms": 1500
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "执行成功",
///   "data": {
///     "id": 1,
///     "test_case_id": 1,
///     "executor": "tester1",
///     ...
///   }
/// }
/// ```
///
/// 需求: 1.6
pub fn execute(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析路径参数
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    // 2. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(TestCaseExecuteDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(TestCaseExecuteDto, allocator, &dto);

    // 3. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 5. 转换为实体
    var execution = dto.toEntity(id);

    // 6. 调用服务执行
    service.execute(&execution) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 7. 返回成功响应
    const response = .{
        .code = 0,
        .msg = "执行成功",
        .data = execution,
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

/// 查看测试用例执行历史
///
/// GET /api/quality/test-cases/:id/executions?page=1&page_size=20
///
/// 查询参数:
/// - page: 页码（默认 1）
/// - page_size: 每页大小（默认 20）
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "查询成功",
///   "data": {
///     "items": [...],
///     "total": 10,
///     "page": 1,
///     "page_size": 20
///   }
/// }
/// ```
///
/// 需求: 1.7
pub fn getExecutions(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析路径参数
    const id_str = req.getParamStr("id") orelse {
        base.send_failed(req, "缺少参数 id");
        return;
    };

    const id = std.fmt.parseInt(i32, id_str.str, 10) catch {
        base.send_failed(req, "参数 id 格式错误");
        return;
    };

    // 2. 解析查询参数
    const page = if (req.getParamStr("page")) |s|
        std.fmt.parseInt(i32, s.str, 10) catch 1
    else
        1;

    const page_size = if (req.getParamStr("page_size")) |s|
        std.fmt.parseInt(i32, s.str, 10) catch 20
    else
        20;

    const query = PageQuery{
        .page = page,
        .page_size = page_size,
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const service = container.resolve(TestCaseService) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 调用服务查询执行历史
    const result = service.getExecutions(id, query) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer service.freeExecutionPageResult(result);

    // 5. 返回成功响应
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

// ========================================
// 辅助函数
// ========================================

/// 解析状态字符串
fn parseStatus(s: []const u8) ?TestCaseStatus {
    if (std.mem.eql(u8, s, "pending")) return .pending;
    if (std.mem.eql(u8, s, "in_progress")) return .in_progress;
    if (std.mem.eql(u8, s, "passed")) return .passed;
    if (std.mem.eql(u8, s, "failed")) return .failed;
    if (std.mem.eql(u8, s, "blocked")) return .blocked;
    return null;
}
