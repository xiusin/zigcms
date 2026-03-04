const std = @import("std");
const Requirement = @import("../entities/requirement.model.zig").Requirement;
const TestCase = @import("../entities/test_case.model.zig").TestCase;
const Feedback = @import("../entities/feedback.model.zig").Feedback;

/// AI 生成器接口
/// 使用 VTable 模式实现接口抽象，支持多种 AI 模型实现
pub const AIGeneratorInterface = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    const Self = @This();

    /// 虚函数表定义
    pub const VTable = struct {
        /// 生成测试用例
        generateTestCases: *const fn (
            *anyopaque,
            Requirement,
            GenerateOptions,
        ) anyerror![]GeneratedTestCase,

        /// 生成需求
        generateRequirement: *const fn (
            *anyopaque,
            []const u8,
            GenerateOptions,
        ) anyerror!GeneratedRequirement,

        /// 分析反馈
        analyzeFeedback: *const fn (
            *anyopaque,
            []const u8,
        ) anyerror!FeedbackAnalysis,
    };

    /// 生成选项
    pub const GenerateOptions = struct {
        max_cases: i32 = 10, // 最大生成数量
        include_edge_cases: bool = true, // 包含边界条件
        include_performance: bool = false, // 包含性能测试
        language: []const u8 = "zh-CN", // 语言
    };

    /// 生成的测试用例
    pub const GeneratedTestCase = struct {
        title: []const u8, // 标题
        precondition: []const u8, // 前置条件
        steps: []const u8, // 测试步骤
        expected_result: []const u8, // 预期结果
        priority: TestCase.Priority, // 优先级
        tags: []const []const u8, // 标签
    };

    /// 生成的需求
    pub const GeneratedRequirement = struct {
        title: []const u8, // 标题
        description: []const u8, // 描述
        priority: Requirement.Priority, // 优先级
        estimated_cases: i32, // 建议测试用例数
    };

    /// 反馈分析结果
    pub const FeedbackAnalysis = struct {
        bug_type: []const u8, // Bug 类型
        severity: Feedback.Severity, // 严重程度
        affected_modules: []const []const u8, // 影响模块
        suggested_actions: []const []const u8, // 建议操作
    };

    /// 生成测试用例
    /// 参数:
    ///   - requirement: 需求对象
    ///   - options: 生成选项
    /// 返回:
    ///   - []GeneratedTestCase: 生成的测试用例数组
    /// 说明:
    ///   - 分析需求内容，识别关键测试点
    ///   - 生成正常流程、边界条件、异常场景测试用例
    ///   - 根据需求优先级设置测试用例优先级
    pub fn generateTestCases(
        self: *Self,
        requirement: Requirement,
        options: GenerateOptions,
    ) ![]GeneratedTestCase {
        return self.vtable.generateTestCases(self.ptr, requirement, options);
    }

    /// 生成需求
    /// 参数:
    ///   - description: 项目描述或用户故事
    ///   - options: 生成选项
    /// 返回:
    ///   - GeneratedRequirement: 生成的需求
    /// 说明:
    ///   - 基于项目描述生成结构化需求
    ///   - 自动估算建议测试用例数
    pub fn generateRequirement(
        self: *Self,
        description: []const u8,
        options: GenerateOptions,
    ) !GeneratedRequirement {
        return self.vtable.generateRequirement(self.ptr, description, options);
    }

    /// 分析反馈
    /// 参数:
    ///   - content: 反馈内容
    /// 返回:
    ///   - FeedbackAnalysis: 分析结果
    /// 说明:
    ///   - 识别 Bug 类型（功能缺陷、性能问题、UI 问题、兼容性问题）
    ///   - 评估严重程度
    ///   - 识别影响模块
    ///   - 提供建议操作
    pub fn analyzeFeedback(
        self: *Self,
        content: []const u8,
    ) !FeedbackAnalysis {
        return self.vtable.analyzeFeedback(self.ptr, content);
    }
};

/// 创建 AI 生成器实例
/// 参数:
///   - ptr: 实现类实例指针
///   - vtable: 虚函数表指针
/// 返回:
///   - AIGeneratorInterface: AI 生成器接口实例
pub fn create(ptr: anytype, vtable: *const AIGeneratorInterface.VTable) AIGeneratorInterface {
    return .{
        .ptr = ptr,
        .vtable = vtable,
    };
}
