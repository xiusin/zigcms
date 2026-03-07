const std = @import("std");
const Allocator = std.mem.Allocator;
const AIGeneratorInterface = @import("../../domain/services/ai_generator_interface.zig").AIGeneratorInterface;
const Requirement = @import("../../domain/entities/requirement.model.zig").Requirement;
const TestCase = @import("../../domain/entities/test_case.model.zig").TestCase;
const Feedback = @import("../../domain/entities/feedback.model.zig").Feedback;

/// OpenAI 生成器实现
/// 使用 OpenAI GPT-4 API 生成测试用例、需求和分析反馈
pub const OpenAIGenerator = struct {
    allocator: Allocator,
    api_key: []const u8,
    base_url: []const u8,
    model: []const u8,
    timeout_ms: u32,
    max_retries: u32,

    const Self = @This();

    /// 初始化 OpenAI 生成器
    /// 参数:
    ///   - allocator: 内存分配器
    ///   - api_key: OpenAI API 密钥
    ///   - base_url: API 基础 URL（默认: https://api.openai.com）
    ///   - model: 模型名称（默认: gpt-4）
    ///   - timeout_ms: 超时时间（默认: 30000ms）
    ///   - max_retries: 最大重试次数（默认: 3）
    pub fn init(
        allocator: Allocator,
        api_key: []const u8,
        base_url: []const u8,
        model: []const u8,
        timeout_ms: u32,
        max_retries: u32,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .allocator = allocator,
            .api_key = try allocator.dupe(u8, api_key),
            .base_url = try allocator.dupe(u8, base_url),
            .model = try allocator.dupe(u8, model),
            .timeout_ms = timeout_ms,
            .max_retries = max_retries,
        };
        return self;
    }

    /// 释放资源
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.api_key);
        self.allocator.free(self.base_url);
        self.allocator.free(self.model);
        self.allocator.destroy(self);
    }

    /// 获取 VTable
    pub fn vtable() AIGeneratorInterface.VTable {
        return .{
            .generateTestCases = generateTestCasesImpl,
            .generateRequirement = generateRequirementImpl,
            .analyzeFeedback = analyzeFeedbackImpl,
        };
    }

    /// 生成测试用例实现
    fn generateTestCasesImpl(
        ptr: *anyopaque,
        requirement: Requirement,
        options: AIGeneratorInterface.GenerateOptions,
    ) anyerror![]AIGeneratorInterface.GeneratedTestCase {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.generateTestCases(requirement, options);
    }

    /// 生成需求实现
    fn generateRequirementImpl(
        ptr: *anyopaque,
        description: []const u8,
        options: AIGeneratorInterface.GenerateOptions,
    ) anyerror!AIGeneratorInterface.GeneratedRequirement {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.generateRequirement(description, options);
    }

    /// 分析反馈实现
    fn analyzeFeedbackImpl(
        ptr: *anyopaque,
        content: []const u8,
    ) anyerror!AIGeneratorInterface.FeedbackAnalysis {
        const self: *Self = @ptrCast(@alignCast(ptr));
        return self.analyzeFeedback(content);
    }

    /// 生成测试用例
    pub fn generateTestCases(
        self: *Self,
        requirement: Requirement,
        options: AIGeneratorInterface.GenerateOptions,
    ) ![]AIGeneratorInterface.GeneratedTestCase {
        // 构建 Prompt
        const prompt = try self.buildTestCasePrompt(requirement, options);
        defer self.allocator.free(prompt);

        // 调用 OpenAI API（带重试）
        const response = try self.callOpenAIWithRetry(prompt);
        defer self.allocator.free(response);

        // 解析响应
        return try self.parseTestCaseResponse(response);
    }

    /// 生成需求
    pub fn generateRequirement(
        self: *Self,
        description: []const u8,
        options: AIGeneratorInterface.GenerateOptions,
    ) !AIGeneratorInterface.GeneratedRequirement {
        // 构建 Prompt
        const prompt = try self.buildRequirementPrompt(description, options);
        defer self.allocator.free(prompt);

        // 调用 OpenAI API（带重试）
        const response = try self.callOpenAIWithRetry(prompt);
        defer self.allocator.free(response);

        // 解析响应
        return try self.parseRequirementResponse(response);
    }

    /// 分析反馈
    pub fn analyzeFeedback(
        self: *Self,
        content: []const u8,
    ) !AIGeneratorInterface.FeedbackAnalysis {
        // 构建 Prompt
        const prompt = try self.buildFeedbackPrompt(content);
        defer self.allocator.free(prompt);

        // 调用 OpenAI API（带重试）
        const response = try self.callOpenAIWithRetry(prompt);
        defer self.allocator.free(response);

        // 解析响应
        return try self.parseFeedbackResponse(response);
    }

    /// 构建测试用例生成 Prompt
    fn buildTestCasePrompt(
        self: *Self,
        requirement: Requirement,
        options: AIGeneratorInterface.GenerateOptions,
    ) ![]const u8 {
        const priority_str = @tagName(requirement.priority);

        var edge_cases_hint: []const u8 = "";
        if (options.include_edge_cases) {
            edge_cases_hint = "- 包含边界条件测试（空值、最大值、最小值、特殊字符等）\n";
        }

        var performance_hint: []const u8 = "";
        if (options.include_performance) {
            performance_hint = "- 包含性能测试（响应时间、并发、吞吐量等）\n";
        }

        return try std.fmt.allocPrint(
            self.allocator,
            \\你是一个专业的测试工程师。请根据以下需求生成测试用例。
            \\
            \\需求标题: {s}
            \\需求描述: {s}
            \\优先级: {s}
            \\
            \\要求:
            \\1. 生成最多 {d} 个测试用例
            \\2. 包含正常流程、边界条件、异常场景
            \\{s}{s}3. 每个测试用例包含: 标题、前置条件、测试步骤、预期结果、优先级、标签
            \\4. 使用 JSON 格式返回
            \\5. 测试步骤和预期结果要详细具体，可操作性强
            \\6. 标签应包含测试类型（如: 功能测试、边界测试、异常测试、性能测试）
            \\
            \\返回格式（必须是有效的 JSON）:
            \\{{
            \\  "test_cases": [
            \\    {{
            \\      "title": "测试用例标题",
            \\      "precondition": "前置条件",
            \\      "steps": "1. 步骤1\n2. 步骤2\n3. 步骤3",
            \\      "expected_result": "预期结果描述",
            \\      "priority": "high|medium|low|critical",
            \\      "tags": ["功能测试", "正常流程"]
            \\    }}
            \\  ]
            \\}}
        ,
            .{
                requirement.title,
                requirement.description,
                priority_str,
                options.max_cases,
                edge_cases_hint,
                performance_hint,
            },
        );
    }

    /// 构建需求生成 Prompt
    fn buildRequirementPrompt(
        self: *Self,
        description: []const u8,
        options: AIGeneratorInterface.GenerateOptions,
    ) ![]const u8 {
        _ = options;
        return try std.fmt.allocPrint(
            self.allocator,
            \\你是一个专业的产品经理。请根据以下项目描述生成结构化需求。
            \\
            \\项目描述: {s}
            \\
            \\要求:
            \\1. 生成需求标题（简洁明了）
            \\2. 生成需求描述（详细具体，包含用户故事、验收标准）
            \\3. 评估优先级（critical/high/medium/low）
            \\4. 估算建议测试用例数（基于需求复杂度）
            \\5. 使用 JSON 格式返回
            \\
            \\返回格式（必须是有效的 JSON）:
            \\{{
            \\  "title": "需求标题",
            \\  "description": "需求描述",
            \\  "priority": "high|medium|low|critical",
            \\  "estimated_cases": 10
            \\}}
        ,
            .{description},
        );
    }

    /// 构建反馈分析 Prompt
    fn buildFeedbackPrompt(
        self: *Self,
        content: []const u8,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            self.allocator,
            \\你是一个专业的质量分析师。请分析以下用户反馈。
            \\
            \\反馈内容: {s}
            \\
            \\要求:
            \\1. 识别 Bug 类型（功能缺陷、性能问题、UI问题、兼容性问题、其他）
            \\2. 评估严重程度（critical/high/medium/low）
            \\3. 识别影响模块（列出可能受影响的功能模块）
            \\4. 提供建议操作（如何修复或改进）
            \\5. 使用 JSON 格式返回
            \\
            \\返回格式（必须是有效的 JSON）:
            \\{{
            \\  "bug_type": "功能缺陷|性能问题|UI问题|兼容性问题|其他",
            \\  "severity": "critical|high|medium|low",
            \\  "affected_modules": ["模块1", "模块2"],
            \\  "suggested_actions": ["建议1", "建议2"]
            \\}}
        ,
            .{content},
        );
    }

    /// 调用 OpenAI API（带重试机制）
    fn callOpenAIWithRetry(self: *Self, prompt: []const u8) ![]const u8 {
        var retry_count: u32 = 0;
        var last_error: ?anyerror = null;

        while (retry_count < self.max_retries) : (retry_count += 1) {
            const result = self.callOpenAI(prompt) catch |err| {
                last_error = err;
                std.log.warn("OpenAI API 调用失败 (尝试 {d}/{d}): {any}", .{ retry_count + 1, self.max_retries, err });

                // 等待后重试（指数退避）
                const wait_ms = @as(u64, 1000) * (@as(u64, 1) << @intCast(retry_count));
                std.Thread.sleep(wait_ms * std.time.ns_per_ms);
                continue;
            };
            return result;
        }

        // 所有重试都失败
        return last_error orelse error.OpenAICallFailed;
    }

    /// 调用 OpenAI API
    fn callOpenAI(self: *Self, prompt: []const u8) ![]const u8 {
        _ = prompt;
        _ = self;
        // TODO: 实现 OpenAI API 调用（Zig 0.15 HTTP Client API 需要更新）
        // 当前版本暂时返回模拟数据
        std.log.warn("OpenAI API 调用功能暂未实现（等待 Zig 0.15 HTTP Client API 适配）", .{});
        return error.NotImplemented;
    }

    /// 转义 JSON 字符串
    fn escapeJsonString(self: *Self, input: []const u8) ![]const u8 {
        var result = std.ArrayListUnmanaged(u8){};
        errdefer result.deinit(self.allocator);

        for (input) |c| {
            switch (c) {
                '"' => try result.appendSlice(self.allocator, "\\\""),
                '\\' => try result.appendSlice(self.allocator, "\\\\"),
                '\n' => try result.appendSlice(self.allocator, "\\n"),
                '\r' => try result.appendSlice(self.allocator, "\\r"),
                '\t' => try result.appendSlice(self.allocator, "\\t"),
                else => try result.append(self.allocator, c),
            }
        }

        return try result.toOwnedSlice(self.allocator);
    }

    /// 解析测试用例响应
    fn parseTestCaseResponse(self: *Self, response: []const u8) ![]AIGeneratorInterface.GeneratedTestCase {
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;

        // 提取 content
        const choices = root.get("choices") orelse return error.InvalidResponse;
        if (choices != .array or choices.array.items.len == 0) return error.InvalidResponse;

        const message = choices.array.items[0].object.get("message") orelse return error.InvalidResponse;
        const content = message.object.get("content") orelse return error.InvalidResponse;
        if (content != .string) return error.InvalidResponse;

        // 解析测试用例 JSON
        var test_cases_parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content.string,
            .{},
        );
        defer test_cases_parsed.deinit();

        const test_cases_obj = test_cases_parsed.value.object;
        const test_cases_array = test_cases_obj.get("test_cases") orelse return error.InvalidResponse;
        if (test_cases_array != .array) return error.InvalidResponse;

        // 转换为 GeneratedTestCase 数组
        var result = try std.ArrayList(AIGeneratorInterface.GeneratedTestCase).initCapacity(self.allocator, 0);
        defer result.deinit(self.allocator);

        for (test_cases_array.array.items) |item| {
            if (item != .object) continue;

            const title = item.object.get("title") orelse continue;
            const precondition = item.object.get("precondition") orelse continue;
            const steps = item.object.get("steps") orelse continue;
            const expected_result = item.object.get("expected_result") orelse continue;
            const priority_str = item.object.get("priority") orelse continue;
            const tags_array = item.object.get("tags") orelse continue;

            if (title != .string or precondition != .string or steps != .string or
                expected_result != .string or priority_str != .string or tags_array != .array)
            {
                continue;
            }

            // 解析优先级
            const priority = std.meta.stringToEnum(TestCase.Priority, priority_str.string) orelse .medium;

            // 解析标签
            var tags = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
            defer tags.deinit(self.allocator);

            for (tags_array.array.items) |tag_item| {
                if (tag_item == .string) {
                    try tags.append(self.allocator, try self.allocator.dupe(u8, tag_item.string));
                }
            }

            try result.append(self.allocator, .{
                .title = try self.allocator.dupe(u8, title.string),
                .precondition = try self.allocator.dupe(u8, precondition.string),
                .steps = try self.allocator.dupe(u8, steps.string),
                .expected_result = try self.allocator.dupe(u8, expected_result.string),
                .priority = priority,
                .tags = try tags.toOwnedSlice(self.allocator),
            });
        }

        return try result.toOwnedSlice(self.allocator);
    }

    /// 解析需求响应
    fn parseRequirementResponse(self: *Self, response: []const u8) !AIGeneratorInterface.GeneratedRequirement {
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;

        // 提取 content
        const choices = root.get("choices") orelse return error.InvalidResponse;
        if (choices != .array or choices.array.items.len == 0) return error.InvalidResponse;

        const message = choices.array.items[0].object.get("message") orelse return error.InvalidResponse;
        const content = message.object.get("content") orelse return error.InvalidResponse;
        if (content != .string) return error.InvalidResponse;

        // 解析需求 JSON
        var requirement_parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content.string,
            .{},
        );
        defer requirement_parsed.deinit();

        const req_obj = requirement_parsed.value.object;

        const title = req_obj.get("title") orelse return error.InvalidResponse;
        const description = req_obj.get("description") orelse return error.InvalidResponse;
        const priority_str = req_obj.get("priority") orelse return error.InvalidResponse;
        const estimated_cases = req_obj.get("estimated_cases") orelse return error.InvalidResponse;

        if (title != .string or description != .string or priority_str != .string or estimated_cases != .integer) {
            return error.InvalidResponse;
        }

        // 解析优先级
        const priority = std.meta.stringToEnum(Requirement.Priority, priority_str.string) orelse .medium;

        return .{
            .title = try self.allocator.dupe(u8, title.string),
            .description = try self.allocator.dupe(u8, description.string),
            .priority = priority,
            .estimated_cases = @intCast(estimated_cases.integer),
        };
    }

    /// 解析反馈响应
    fn parseFeedbackResponse(self: *Self, response: []const u8) !AIGeneratorInterface.FeedbackAnalysis {
        var parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            response,
            .{},
        );
        defer parsed.deinit();

        const root = parsed.value.object;

        // 提取 content
        const choices = root.get("choices") orelse return error.InvalidResponse;
        if (choices != .array or choices.array.items.len == 0) return error.InvalidResponse;

        const message = choices.array.items[0].object.get("message") orelse return error.InvalidResponse;
        const content = message.object.get("content") orelse return error.InvalidResponse;
        if (content != .string) return error.InvalidResponse;

        // 解析反馈分析 JSON
        var feedback_parsed = try std.json.parseFromSlice(
            std.json.Value,
            self.allocator,
            content.string,
            .{},
        );
        defer feedback_parsed.deinit();

        const feedback_obj = feedback_parsed.value.object;

        const bug_type = feedback_obj.get("bug_type") orelse return error.InvalidResponse;
        const severity_str = feedback_obj.get("severity") orelse return error.InvalidResponse;
        const affected_modules_array = feedback_obj.get("affected_modules") orelse return error.InvalidResponse;
        const suggested_actions_array = feedback_obj.get("suggested_actions") orelse return error.InvalidResponse;

        if (bug_type != .string or severity_str != .string or
            affected_modules_array != .array or suggested_actions_array != .array)
        {
            return error.InvalidResponse;
        }

        // 解析严重程度
        const severity = std.meta.stringToEnum(Feedback.Severity, severity_str.string) orelse .medium;

        // 解析影响模块
        var affected_modules = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
        defer affected_modules.deinit(self.allocator);

        for (affected_modules_array.array.items) |module_item| {
            if (module_item == .string) {
                try affected_modules.append(self.allocator, try self.allocator.dupe(u8, module_item.string));
            }
        }

        // 解析建议操作
        var suggested_actions = try std.ArrayList([]const u8).initCapacity(self.allocator, 0);
        defer suggested_actions.deinit(self.allocator);

        for (suggested_actions_array.array.items) |action_item| {
            if (action_item == .string) {
                try suggested_actions.append(self.allocator, try self.allocator.dupe(u8, action_item.string));
            }
        }

        return .{
            .bug_type = try self.allocator.dupe(u8, bug_type.string),
            .severity = severity,
            .affected_modules = try affected_modules.toOwnedSlice(self.allocator),
            .suggested_actions = try suggested_actions.toOwnedSlice(self.allocator),
        };
    }
};

/// 创建 OpenAI 生成器实例（便捷函数）
/// 参数:
///   - allocator: 内存分配器
///   - api_key: OpenAI API 密钥
/// 返回:
///   - *OpenAIGenerator: OpenAI 生成器实例
pub fn create(allocator: Allocator, api_key: []const u8) !*OpenAIGenerator {
    return OpenAIGenerator.init(
        allocator,
        api_key,
        "https://api.openai.com",
        "gpt-4",
        30000, // 30 秒超时
        3, // 最多重试 3 次
    );
}

/// 创建 OpenAI 生成器实例（自定义配置）
/// 参数:
///   - allocator: 内存分配器
///   - api_key: OpenAI API 密钥
///   - base_url: API 基础 URL
///   - model: 模型名称
///   - timeout_ms: 超时时间（毫秒）
///   - max_retries: 最大重试次数
/// 返回:
///   - *OpenAIGenerator: OpenAI 生成器实例
pub fn createWithConfig(
    allocator: Allocator,
    api_key: []const u8,
    base_url: []const u8,
    model: []const u8,
    timeout_ms: u32,
    max_retries: u32,
) !*OpenAIGenerator {
    return OpenAIGenerator.init(
        allocator,
        api_key,
        base_url,
        model,
        timeout_ms,
        max_retries,
    );
}
