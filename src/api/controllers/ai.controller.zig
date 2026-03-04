//! AI 生成控制器
//!
//! 提供 AI 自动生成功能的 HTTP 接口，包括：
//! - 基于需求生成测试用例
//! - 基于项目描述生成需求
//! - 分析反馈内容
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
//! - POST /api/quality/ai/generate-test-cases - 生成测试用例
//! - POST /api/quality/ai/generate-requirement - 生成需求
//! - POST /api/quality/ai/analyze-feedback - 分析反馈
//!
//! 需求: 2.1, 2.4, 5.3, 7.5

const std = @import("std");
const zap = @import("zap");
const Allocator = std.mem.Allocator;

const base = @import("base.fn.zig");
const global = @import("../../core/primitives/global.zig");
const json_mod = @import("../../application/services/json/json.zig");
const di = @import("../../core/di/mod.zig");

// 导入服务
const TestCaseService = @import("../../application/services/test_case_service.zig").TestCaseService;
const RequirementService = @import("../../application/services/requirement_service.zig").RequirementService;
const FeedbackService = @import("../../application/services/feedback_service.zig").FeedbackService;

// 导入 AI 生成器接口
const AIGeneratorInterface = @import("../../domain/services/ai_generator_interface.zig").AIGeneratorInterface;
const GenerateOptions = @import("../../domain/services/ai_generator_interface.zig").GenerateOptions;

// 导入实体
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;

// 导入 DTO
const AIGenerateTestCasesDto = @import("../dto/ai_generate_test_cases.dto.zig").AIGenerateTestCasesDto;
const AIGenerateRequirementDto = @import("../dto/ai_generate_requirement.dto.zig").AIGenerateRequirementDto;
const AIAnalyzeFeedbackDto = @import("../dto/ai_analyze_feedback.dto.zig").AIAnalyzeFeedbackDto;

/// 生成测试用例
///
/// POST /api/quality/ai/generate-test-cases
///
/// 请求体:
/// ```json
/// {
///   "requirement_id": 1,
///   "max_cases": 10,
///   "include_edge_cases": true,
///   "include_performance": false,
///   "language": "zh-CN"
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "生成成功",
///   "data": {
///     "test_cases": [
///       {
///         "title": "测试正常登录",
///         "precondition": "用户已注册",
///         "steps": "1. 打开登录页面\n2. 输入用户名密码\n3. 点击登录",
///         "expected_result": "登录成功",
///         "priority": "high",
///         "tags": ["登录", "功能测试"]
///       },
///       ...
///     ]
///   }
/// }
/// ```
///
/// 需求: 2.1, 2.4
pub fn generateTestCases(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(AIGenerateTestCasesDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(AIGenerateTestCasesDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const requirement_service = container.resolve(RequirementService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const ai_generator = container.resolve(AIGeneratorInterface) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 查询需求
    const requirement = requirement_service.findById(dto.requirement_id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "需求不存在");
        return;
    };
    defer requirement_service.freeRequirement(requirement);

    // 5. 构建生成选项
    const options = GenerateOptions{
        .max_cases = dto.max_cases orelse 10,
        .include_edge_cases = dto.include_edge_cases orelse true,
        .include_performance = dto.include_performance orelse false,
        .language = dto.language orelse "zh-CN",
    };

    // 6. 调用 AI 生成器生成测试用例
    const generated_cases = ai_generator.generateTestCases(requirement, options) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer ai_generator.freeGeneratedTestCases(generated_cases);

    // 7. 返回成功响应
    const response = .{
        .code = 0,
        .msg = "生成成功",
        .data = .{
            .test_cases = generated_cases,
        },
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

/// 生成需求
///
/// POST /api/quality/ai/generate-requirement
///
/// 请求体:
/// ```json
/// {
///   "project_id": 1,
///   "description": "用户登录功能，支持用户名密码登录和第三方登录",
///   "language": "zh-CN"
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "生成成功",
///   "data": {
///     "title": "用户登录功能",
///     "description": "实现用户登录功能，支持用户名密码登录和第三方登录（微信、QQ、微博）",
///     "priority": "high",
///     "estimated_cases": 15
///   }
/// }
/// ```
///
/// 需求: 5.3
pub fn generateRequirement(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(AIGenerateRequirementDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(AIGenerateRequirementDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const ai_generator = container.resolve(AIGeneratorInterface) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 构建生成选项
    const options = GenerateOptions{
        .language = dto.language orelse "zh-CN",
    };

    // 5. 调用 AI 生成器生成需求
    const generated_requirement = ai_generator.generateRequirement(dto.description, options) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer ai_generator.freeGeneratedRequirement(generated_requirement);

    // 6. 返回成功响应
    const response = .{
        .code = 0,
        .msg = "生成成功",
        .data = generated_requirement,
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

/// 分析反馈
///
/// POST /api/quality/ai/analyze-feedback
///
/// 请求体:
/// ```json
/// {
///   "feedback_id": 1
/// }
/// ```
///
/// 响应:
/// ```json
/// {
///   "code": 0,
///   "msg": "分析成功",
///   "data": {
///     "bug_type": "功能缺陷",
///     "severity": "high",
///     "affected_modules": ["登录模块", "用户中心"],
///     "suggested_actions": ["修复登录逻辑", "增加输入验证", "添加单元测试"]
///   }
/// }
/// ```
///
/// 需求: 7.5
pub fn analyzeFeedback(req: zap.Request) void {
    const allocator = global.get_allocator();

    // 1. 解析请求体
    const body = req.body orelse {
        base.send_failed(req, "请求体为空");
        return;
    };

    var dto = json_mod.JSON.decode(AIAnalyzeFeedbackDto, allocator, body) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer json_mod.JSON.free(AIAnalyzeFeedbackDto, allocator, &dto);

    // 2. 验证参数
    dto.validate() catch |err| {
        base.send_error(req, err);
        return;
    };

    // 3. 获取服务
    const container = di.getGlobalContainer();
    const feedback_service = container.resolve(FeedbackService) catch |err| {
        base.send_error(req, err);
        return;
    };

    const ai_generator = container.resolve(AIGeneratorInterface) catch |err| {
        base.send_error(req, err);
        return;
    };

    // 4. 查询反馈
    const feedback = feedback_service.findById(dto.feedback_id) catch |err| {
        base.send_error(req, err);
        return;
    } orelse {
        base.send_failed(req, "反馈不存在");
        return;
    };
    defer feedback_service.freeFeedback(feedback);

    // 5. 调用 AI 生成器分析反馈
    const analysis = ai_generator.analyzeFeedback(feedback.content) catch |err| {
        base.send_error(req, err);
        return;
    };
    defer ai_generator.freeFeedbackAnalysis(analysis);

    // 6. 返回成功响应
    const response = .{
        .code = 0,
        .msg = "分析成功",
        .data = analysis,
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
