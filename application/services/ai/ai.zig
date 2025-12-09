//! AI 服务客户端
//!
//! 提供统一的AI API接口，支持：
//! - OpenAI API 标准接口
//! - 第三方兼容服务（Azure、Claude API、DeepSeek、Moonshot等）
//! - 本地模型（Ollama、LM Studio等）
//! - 聊天完成（Chat Completions）
//! - 流式响应
//! - 函数调用（Function Calling）
//! - 嵌入向量（Embeddings）
//!
//! 使用示例：
//! ```zig
//! var client = try AiClient.init(allocator, .{
//!     .api_key = "sk-xxx",
//!     .base_url = "https://api.openai.com/v1",
//! });
//! defer client.deinit();
//!
//! const response = try client.chat(.{
//!     .model = "gpt-4",
//!     .messages = &.{
//!         .{ .role = .system, .content = "你是一个助手" },
//!         .{ .role = .user, .content = "你好" },
//!     },
//! });
//! defer response.deinit();
//!
//! std.debug.print("{s}\n", .{response.content()});
//! ```

const std = @import("std");
const Allocator = std.mem.Allocator;
const http = std.http;

// ============================================================================
// 类型定义
// ============================================================================

/// AI 服务提供商
pub const Provider = enum {
    /// OpenAI 官方
    openai,
    /// Azure OpenAI
    azure,
    /// Anthropic Claude
    claude,
    /// DeepSeek
    deepseek,
    /// Moonshot（月之暗面）
    moonshot,
    /// 智谱 GLM
    zhipu,
    /// 通义千问
    qwen,
    /// Ollama 本地模型
    ollama,
    /// LM Studio 本地模型
    lmstudio,
    /// 自定义（兼容 OpenAI API）
    custom,

    /// 获取默认基础URL
    pub fn defaultBaseUrl(self: Provider) []const u8 {
        return switch (self) {
            .openai => "https://api.openai.com/v1",
            .azure => "", // 需要自定义
            .claude => "https://api.anthropic.com/v1",
            .deepseek => "https://api.deepseek.com/v1",
            .moonshot => "https://api.moonshot.cn/v1",
            .zhipu => "https://open.bigmodel.cn/api/paas/v4",
            .qwen => "https://dashscope.aliyuncs.com/compatible-mode/v1",
            .ollama => "http://localhost:11434/v1",
            .lmstudio => "http://localhost:1234/v1",
            .custom => "",
        };
    }

    /// 获取默认模型
    pub fn defaultModel(self: Provider) []const u8 {
        return switch (self) {
            .openai => "gpt-4o",
            .azure => "gpt-4",
            .claude => "claude-3-5-sonnet-20241022",
            .deepseek => "deepseek-chat",
            .moonshot => "moonshot-v1-8k",
            .zhipu => "glm-4",
            .qwen => "qwen-plus",
            .ollama => "llama3.2",
            .lmstudio => "local-model",
            .custom => "gpt-4o",
        };
    }
};

/// 消息角色
pub const Role = enum {
    system,
    user,
    assistant,
    tool,
    function,

    pub fn toString(self: Role) []const u8 {
        return switch (self) {
            .system => "system",
            .user => "user",
            .assistant => "assistant",
            .tool => "tool",
            .function => "function",
        };
    }

    pub fn fromString(s: []const u8) ?Role {
        if (std.mem.eql(u8, s, "system")) return .system;
        if (std.mem.eql(u8, s, "user")) return .user;
        if (std.mem.eql(u8, s, "assistant")) return .assistant;
        if (std.mem.eql(u8, s, "tool")) return .tool;
        if (std.mem.eql(u8, s, "function")) return .function;
        return null;
    }
};

/// 消息内容类型
pub const ContentPart = union(enum) {
    /// 文本内容
    text: []const u8,
    /// 图片URL
    image_url: struct {
        url: []const u8,
        detail: enum { auto, low, high } = .auto,
    },
};

/// 聊天消息
pub const Message = struct {
    /// 角色
    role: Role,
    /// 内容（文本或多模态）
    content: ?[]const u8 = null,
    /// 多模态内容
    content_parts: ?[]const ContentPart = null,
    /// 助手消息的名称
    name: ?[]const u8 = null,
    /// 工具调用ID（tool角色时需要）
    tool_call_id: ?[]const u8 = null,
    /// 工具调用列表（assistant角色时可能有）
    tool_calls: ?[]const ToolCall = null,

    /// 创建系统消息
    pub fn system(content: []const u8) Message {
        return .{ .role = .system, .content = content };
    }

    /// 创建用户消息
    pub fn user(content: []const u8) Message {
        return .{ .role = .user, .content = content };
    }

    /// 创建助手消息
    pub fn assistant(content: []const u8) Message {
        return .{ .role = .assistant, .content = content };
    }

    /// 创建工具响应消息
    pub fn toolResponse(tool_call_id: []const u8, content: []const u8) Message {
        return .{ .role = .tool, .content = content, .tool_call_id = tool_call_id };
    }
};

/// 工具调用
pub const ToolCall = struct {
    /// 调用ID
    id: []const u8,
    /// 类型（通常是 "function"）
    type: []const u8 = "function",
    /// 函数信息
    function: struct {
        /// 函数名
        name: []const u8,
        /// 参数（JSON字符串）
        arguments: []const u8,
    },
};

/// 工具定义
pub const Tool = struct {
    /// 类型（目前只支持 "function"）
    type: []const u8 = "function",
    /// 函数定义
    function: FunctionDef,
};

/// 函数定义
pub const FunctionDef = struct {
    /// 函数名
    name: []const u8,
    /// 描述
    description: ?[]const u8 = null,
    /// 参数（JSON Schema）
    parameters: ?[]const u8 = null,
};

/// 聊天请求配置
pub const ChatRequest = struct {
    /// 模型名称
    model: ?[]const u8 = null,
    /// 消息列表
    messages: []const Message,
    /// 温度（0-2）
    temperature: ?f32 = null,
    /// Top P 采样
    top_p: ?f32 = null,
    /// 最大生成Token数
    max_tokens: ?u32 = null,
    /// 停止序列
    stop: ?[]const []const u8 = null,
    /// 是否流式输出
    stream: bool = false,
    /// 工具列表
    tools: ?[]const Tool = null,
    /// 工具选择策略
    tool_choice: ?[]const u8 = null,
    /// 频率惩罚
    frequency_penalty: ?f32 = null,
    /// 存在惩罚
    presence_penalty: ?f32 = null,
    /// 用户标识
    user: ?[]const u8 = null,
    /// 响应格式
    response_format: ?ResponseFormat = null,
    /// 随机种子
    seed: ?i64 = null,
};

/// 响应格式
pub const ResponseFormat = struct {
    type: enum { text, json_object, json_schema } = .text,
    json_schema: ?[]const u8 = null,
};

/// 使用统计
pub const Usage = struct {
    /// 输入Token数
    prompt_tokens: u32 = 0,
    /// 输出Token数
    completion_tokens: u32 = 0,
    /// 总Token数
    total_tokens: u32 = 0,
};

/// 选择结果
pub const Choice = struct {
    /// 索引
    index: u32,
    /// 消息
    message: Message,
    /// 结束原因
    finish_reason: ?[]const u8,
};

/// 聊天响应
pub const ChatResponse = struct {
    allocator: Allocator,
    /// 响应ID
    id: []const u8,
    /// 对象类型
    object: []const u8,
    /// 创建时间戳
    created: i64,
    /// 模型名称
    model: []const u8,
    /// 选择列表
    choices: []Choice,
    /// 使用统计
    usage: ?Usage,
    /// 原始JSON
    raw_json: []const u8,

    /// 获取第一个响应内容
    pub fn content(self: *const ChatResponse) ?[]const u8 {
        if (self.choices.len == 0) return null;
        return self.choices[0].message.content;
    }

    /// 获取工具调用
    pub fn toolCalls(self: *const ChatResponse) ?[]const ToolCall {
        if (self.choices.len == 0) return null;
        return self.choices[0].message.tool_calls;
    }

    /// 获取结束原因
    pub fn finishReason(self: *const ChatResponse) ?[]const u8 {
        if (self.choices.len == 0) return null;
        return self.choices[0].finish_reason;
    }

    /// 释放资源
    pub fn deinit(self: *const ChatResponse) void {
        self.allocator.free(self.raw_json);
    }
};

/// 流式响应块
pub const StreamChunk = struct {
    /// 响应ID
    id: []const u8,
    /// 内容增量
    delta_content: ?[]const u8,
    /// 工具调用增量
    delta_tool_calls: ?[]const ToolCall,
    /// 结束原因
    finish_reason: ?[]const u8,

    /// 是否结束
    pub fn isDone(self: *const StreamChunk) bool {
        return self.finish_reason != null;
    }
};

/// 嵌入向量请求
pub const EmbeddingRequest = struct {
    /// 模型名称
    model: ?[]const u8 = null,
    /// 输入文本
    input: []const u8,
    /// 编码格式
    encoding_format: enum { float, base64 } = .float,
    /// 维度
    dimensions: ?u32 = null,
};

/// 嵌入向量响应
pub const EmbeddingResponse = struct {
    allocator: Allocator,
    /// 嵌入向量
    embedding: []f32,
    /// 使用统计
    usage: Usage,
    /// 原始JSON
    raw_json: []const u8,

    pub fn deinit(self: *const EmbeddingResponse) void {
        self.allocator.free(self.embedding);
        self.allocator.free(self.raw_json);
    }
};

// ============================================================================
// 客户端配置
// ============================================================================

/// 客户端配置
pub const ClientConfig = struct {
    /// API 密钥
    api_key: ?[]const u8 = null,
    /// 基础URL
    base_url: ?[]const u8 = null,
    /// 服务提供商
    provider: Provider = .openai,
    /// 默认模型
    default_model: ?[]const u8 = null,
    /// 组织ID（OpenAI）
    organization: ?[]const u8 = null,
    /// 请求超时（毫秒）
    timeout_ms: u32 = 60_000,
    /// 最大重试次数
    max_retries: u32 = 3,
    /// 重试间隔（毫秒）
    retry_delay_ms: u32 = 1000,
    /// 自定义请求头
    extra_headers: ?[]const Header = null,
};

/// HTTP 头
pub const Header = struct {
    name: []const u8,
    value: []const u8,
};

// ============================================================================
// 错误类型
// ============================================================================

/// AI 客户端错误
pub const AiError = error{
    /// 无效的API密钥
    InvalidApiKey,
    /// 请求被拒绝（权限不足）
    Forbidden,
    /// 资源未找到
    NotFound,
    /// 请求过于频繁
    RateLimited,
    /// 服务器错误
    ServerError,
    /// 请求超时
    Timeout,
    /// 网络错误
    NetworkError,
    /// 无效的请求
    BadRequest,
    /// 响应解析错误
    ParseError,
    /// 内容被过滤
    ContentFiltered,
    /// 上下文长度超限
    ContextLengthExceeded,
    /// 模型不可用
    ModelNotAvailable,
    /// 余额不足
    InsufficientQuota,
    /// 未知错误
    Unknown,
    /// 内存分配失败
    OutOfMemory,
};

// ============================================================================
// AI 客户端
// ============================================================================

/// AI 客户端
pub const AiClient = struct {
    const Self = @This();

    allocator: Allocator,
    config: ClientConfig,
    http_client: http.Client,

    /// 初始化客户端
    pub fn init(allocator: Allocator, config: ClientConfig) !*Self {
        const client = try allocator.create(Self);
        errdefer allocator.destroy(client);

        client.* = .{
            .allocator = allocator,
            .config = config,
            .http_client = http.Client{ .allocator = allocator },
        };

        return client;
    }

    /// 释放资源
    pub fn deinit(self: *Self) void {
        self.http_client.deinit();
        self.allocator.destroy(self);
    }

    /// 获取基础URL
    fn getBaseUrl(self: *const Self) []const u8 {
        if (self.config.base_url) |url| return url;
        return self.config.provider.defaultBaseUrl();
    }

    /// 获取默认模型
    fn getDefaultModel(self: *const Self) []const u8 {
        if (self.config.default_model) |model| return model;
        return self.config.provider.defaultModel();
    }

    /// 聊天完成
    pub fn chat(self: *Self, request: ChatRequest) !ChatResponse {
        const model = request.model orelse self.getDefaultModel();

        // 构建请求体
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();

        const writer = json_buf.writer();
        try self.buildChatRequestJson(writer, request, model);

        // 发送请求
        const response_body = try self.sendRequest("/chat/completions", json_buf.items);
        errdefer self.allocator.free(response_body);

        // 解析响应
        return self.parseChatResponse(response_body);
    }

    /// 流式聊天完成
    pub fn chatStream(self: *Self, request: ChatRequest) !StreamIterator {
        var stream_request = request;
        stream_request.stream = true;

        const model = request.model orelse self.getDefaultModel();

        // 构建请求体
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();

        const writer = json_buf.writer();
        try self.buildChatRequestJson(writer, stream_request, model);

        // 返回流迭代器
        return StreamIterator.init(self, "/chat/completions", json_buf.items);
    }

    /// 获取嵌入向量
    pub fn embedding(self: *Self, request: EmbeddingRequest) !EmbeddingResponse {
        const model = request.model orelse switch (self.config.provider) {
            .openai => "text-embedding-3-small",
            .zhipu => "embedding-2",
            else => "text-embedding-ada-002",
        };

        // 构建请求体
        var json_buf = std.ArrayList(u8).init(self.allocator);
        defer json_buf.deinit();

        const writer = json_buf.writer();
        try writer.writeAll("{\"model\":\"");
        try writer.writeAll(model);
        try writer.writeAll("\",\"input\":\"");
        try self.writeJsonString(writer, request.input);
        try writer.writeAll("\"");

        if (request.dimensions) |dim| {
            try writer.print(",\"dimensions\":{d}", .{dim});
        }

        try writer.writeAll("}");

        // 发送请求
        const response_body = try self.sendRequest("/embeddings", json_buf.items);
        errdefer self.allocator.free(response_body);

        // 解析响应
        return self.parseEmbeddingResponse(response_body);
    }

    /// 列出可用模型
    pub fn listModels(self: *Self) ![]const u8 {
        return self.sendRequest("/models", null);
    }

    /// 构建聊天请求JSON
    fn buildChatRequestJson(self: *Self, writer: anytype, request: ChatRequest, model: []const u8) !void {
        try writer.writeAll("{\"model\":\"");
        try writer.writeAll(model);
        try writer.writeAll("\",\"messages\":[");

        for (request.messages, 0..) |msg, i| {
            if (i > 0) try writer.writeAll(",");
            try self.writeMessageJson(writer, msg);
        }

        try writer.writeAll("]");

        // 可选参数
        if (request.temperature) |temp| {
            try writer.print(",\"temperature\":{d:.2}", .{temp});
        }
        if (request.top_p) |top_p| {
            try writer.print(",\"top_p\":{d:.2}", .{top_p});
        }
        if (request.max_tokens) |max| {
            try writer.print(",\"max_tokens\":{d}", .{max});
        }
        if (request.stream) {
            try writer.writeAll(",\"stream\":true");
        }
        if (request.frequency_penalty) |fp| {
            try writer.print(",\"frequency_penalty\":{d:.2}", .{fp});
        }
        if (request.presence_penalty) |pp| {
            try writer.print(",\"presence_penalty\":{d:.2}", .{pp});
        }
        if (request.seed) |seed| {
            try writer.print(",\"seed\":{d}", .{seed});
        }
        if (request.user) |usr| {
            try writer.writeAll(",\"user\":\"");
            try self.writeJsonString(writer, usr);
            try writer.writeAll("\"");
        }

        // 工具
        if (request.tools) |tools| {
            try writer.writeAll(",\"tools\":[");
            for (tools, 0..) |tool, i| {
                if (i > 0) try writer.writeAll(",");
                try self.writeToolJson(writer, tool);
            }
            try writer.writeAll("]");
        }

        if (request.tool_choice) |choice| {
            try writer.writeAll(",\"tool_choice\":\"");
            try writer.writeAll(choice);
            try writer.writeAll("\"");
        }

        // 响应格式
        if (request.response_format) |fmt| {
            switch (fmt.type) {
                .json_object => try writer.writeAll(",\"response_format\":{\"type\":\"json_object\"}"),
                .json_schema => {
                    try writer.writeAll(",\"response_format\":{\"type\":\"json_schema\"");
                    if (fmt.json_schema) |schema| {
                        try writer.writeAll(",\"json_schema\":");
                        try writer.writeAll(schema);
                    }
                    try writer.writeAll("}");
                },
                .text => {},
            }
        }

        try writer.writeAll("}");
    }

    /// 写入消息JSON
    fn writeMessageJson(self: *Self, writer: anytype, msg: Message) !void {
        try writer.writeAll("{\"role\":\"");
        try writer.writeAll(msg.role.toString());
        try writer.writeAll("\"");

        if (msg.content) |content| {
            try writer.writeAll(",\"content\":\"");
            try self.writeJsonString(writer, content);
            try writer.writeAll("\"");
        }

        if (msg.name) |name| {
            try writer.writeAll(",\"name\":\"");
            try self.writeJsonString(writer, name);
            try writer.writeAll("\"");
        }

        if (msg.tool_call_id) |id| {
            try writer.writeAll(",\"tool_call_id\":\"");
            try writer.writeAll(id);
            try writer.writeAll("\"");
        }

        if (msg.tool_calls) |calls| {
            try writer.writeAll(",\"tool_calls\":[");
            for (calls, 0..) |call, i| {
                if (i > 0) try writer.writeAll(",");
                try writer.writeAll("{\"id\":\"");
                try writer.writeAll(call.id);
                try writer.writeAll("\",\"type\":\"");
                try writer.writeAll(call.type);
                try writer.writeAll("\",\"function\":{\"name\":\"");
                try writer.writeAll(call.function.name);
                try writer.writeAll("\",\"arguments\":\"");
                try self.writeJsonString(writer, call.function.arguments);
                try writer.writeAll("\"}}");
            }
            try writer.writeAll("]");
        }

        try writer.writeAll("}");
    }

    /// 写入工具JSON
    fn writeToolJson(self: *Self, writer: anytype, tool: Tool) !void {
        _ = self;
        try writer.writeAll("{\"type\":\"");
        try writer.writeAll(tool.type);
        try writer.writeAll("\",\"function\":{\"name\":\"");
        try writer.writeAll(tool.function.name);
        try writer.writeAll("\"");

        if (tool.function.description) |desc| {
            try writer.writeAll(",\"description\":\"");
            try writer.writeAll(desc);
            try writer.writeAll("\"");
        }

        if (tool.function.parameters) |params| {
            try writer.writeAll(",\"parameters\":");
            try writer.writeAll(params);
        }

        try writer.writeAll("}}");
    }

    /// 写入JSON转义字符串
    fn writeJsonString(self: *Self, writer: anytype, str: []const u8) !void {
        _ = self;
        for (str) |c| {
            switch (c) {
                '"' => try writer.writeAll("\\\""),
                '\\' => try writer.writeAll("\\\\"),
                '\n' => try writer.writeAll("\\n"),
                '\r' => try writer.writeAll("\\r"),
                '\t' => try writer.writeAll("\\t"),
                else => {
                    if (c < 0x20) {
                        try writer.print("\\u{x:0>4}", .{c});
                    } else {
                        try writer.writeByte(c);
                    }
                },
            }
        }
    }

    /// 发送HTTP请求
    fn sendRequest(self: *Self, endpoint: []const u8, body: ?[]const u8) ![]const u8 {
        const base_url = self.getBaseUrl();

        // 构建完整URL
        var url_buf: [2048]u8 = undefined;
        const url = std.fmt.bufPrint(&url_buf, "{s}{s}", .{ base_url, endpoint }) catch return AiError.BadRequest;

        // 解析URI
        const uri = std.Uri.parse(url) catch return AiError.BadRequest;

        // 准备请求头
        var headers = http.Client.Request.Headers{};

        // 设置认证头
        var auth_buf: [256]u8 = undefined;
        if (self.config.api_key) |key| {
            if (self.config.provider == .claude) {
                headers.content_type = .{ .override = "application/json" };
            } else {
                const auth = std.fmt.bufPrint(&auth_buf, "Bearer {s}", .{key}) catch return AiError.BadRequest;
                headers.authorization = .{ .override = auth };
            }
        }

        headers.content_type = .{ .override = "application/json" };

        // 发送请求
        var req = self.http_client.open(.POST, uri, headers, .{}) catch return AiError.NetworkError;
        defer req.deinit();

        if (body) |b| {
            req.write(b) catch return AiError.NetworkError;
        }

        req.finish() catch return AiError.NetworkError;
        req.wait() catch return AiError.NetworkError;

        // 检查状态码
        switch (req.response.status) {
            .ok => {},
            .bad_request => return AiError.BadRequest,
            .unauthorized => return AiError.InvalidApiKey,
            .forbidden => return AiError.Forbidden,
            .not_found => return AiError.NotFound,
            .too_many_requests => return AiError.RateLimited,
            else => {
                if (@intFromEnum(req.response.status) >= 500) {
                    return AiError.ServerError;
                }
                return AiError.Unknown;
            },
        }

        // 读取响应体
        var response_buf = std.ArrayList(u8).init(self.allocator);
        errdefer response_buf.deinit();

        var reader = req.reader();
        reader.readAllArrayList(&response_buf, 10 * 1024 * 1024) catch return AiError.NetworkError;

        return response_buf.toOwnedSlice() catch return AiError.OutOfMemory;
    }

    /// 解析聊天响应
    fn parseChatResponse(self: *Self, json_data: []const u8) !ChatResponse {
        // 简化解析：查找关键字段
        const id = self.extractJsonString(json_data, "\"id\"") orelse "unknown";
        const object = self.extractJsonString(json_data, "\"object\"") orelse "chat.completion";
        const model = self.extractJsonString(json_data, "\"model\"") orelse "unknown";

        // 提取内容
        var content: ?[]const u8 = null;
        if (self.extractJsonString(json_data, "\"content\"")) |c| {
            content = c;
        }

        // 提取finish_reason
        const finish_reason = self.extractJsonString(json_data, "\"finish_reason\"");

        // 构建响应
        var choices = try self.allocator.alloc(Choice, 1);
        choices[0] = .{
            .index = 0,
            .message = .{
                .role = .assistant,
                .content = content,
            },
            .finish_reason = finish_reason,
        };

        return ChatResponse{
            .allocator = self.allocator,
            .id = id,
            .object = object,
            .created = std.time.timestamp(),
            .model = model,
            .choices = choices,
            .usage = null,
            .raw_json = json_data,
        };
    }

    /// 解析嵌入向量响应
    fn parseEmbeddingResponse(self: *Self, json_data: []const u8) !EmbeddingResponse {
        // 查找 embedding数组
        var embed_list = std.ArrayListUnmanaged(f32){};
        errdefer embed_list.deinit(self.allocator);

        // 简化解析：查找 "embedding": [ 并解析数字
        if (std.mem.indexOf(u8, json_data, "\"embedding\"")) |start| {
            var i = start;
            // 跳过到 [
            while (i < json_data.len and json_data[i] != '[') : (i += 1) {}
            i += 1;

            // 解析数字
            while (i < json_data.len and json_data[i] != ']') {
                // 跳过空白和逗号
                while (i < json_data.len and (json_data[i] == ' ' or json_data[i] == ',' or json_data[i] == '\n')) : (i += 1) {}

                if (json_data[i] == ']') break;

                // 解析浮点数
                var end = i;
                while (end < json_data.len and (json_data[end] == '-' or json_data[end] == '.' or json_data[end] == 'e' or json_data[end] == 'E' or json_data[end] == '+' or (json_data[end] >= '0' and json_data[end] <= '9'))) : (end += 1) {}

                if (end > i) {
                    const num_str = json_data[i..end];
                    const num = std.fmt.parseFloat(f32, num_str) catch 0;
                    try embed_list.append(self.allocator, num);
                    i = end;
                } else {
                    i += 1;
                }
            }
        }

        return EmbeddingResponse{
            .allocator = self.allocator,
            .embedding = try embed_list.toOwnedSlice(self.allocator),
            .usage = .{},
            .raw_json = json_data,
        };
    }

    /// 从JSON中提取字符串值
    fn extractJsonString(self: *Self, json: []const u8, key: []const u8) ?[]const u8 {
        _ = self;
        const key_pos = std.mem.indexOf(u8, json, key) orelse return null;
        var i = key_pos + key.len;

        // 跳过 : 和空白
        while (i < json.len and (json[i] == ':' or json[i] == ' ' or json[i] == '\n' or json[i] == '\t')) : (i += 1) {}

        if (i >= json.len) return null;

        // 检查是否是字符串
        if (json[i] == '"') {
            i += 1;
            const start = i;
            while (i < json.len and json[i] != '"') {
                if (json[i] == '\\') i += 1;
                i += 1;
            }
            return json[start..i];
        }

        // 检查是否是 null
        if (i + 4 <= json.len and std.mem.eql(u8, json[i .. i + 4], "null")) {
            return null;
        }

        return null;
    }
};

/// 流式响应迭代器
pub const StreamIterator = struct {
    client: *AiClient,
    endpoint: []const u8,
    body: []const u8,
    started: bool,
    done: bool,
    buffer: std.ArrayList(u8),

    pub fn init(client: *AiClient, endpoint: []const u8, body: []const u8) StreamIterator {
        return .{
            .client = client,
            .endpoint = endpoint,
            .body = body,
            .started = false,
            .done = false,
            .buffer = std.ArrayList(u8).init(client.allocator),
        };
    }

    pub fn deinit(self: *StreamIterator) void {
        self.buffer.deinit();
    }

    /// 获取下一个块
    pub fn next(self: *StreamIterator) !?StreamChunk {
        if (self.done) return null;

        // TODO: 实现真正的流式读取
        // 目前简化为一次性读取
        if (!self.started) {
            self.started = true;
            const response = self.client.sendRequest(self.endpoint, self.body) catch |err| {
                self.done = true;
                return err;
            };
            defer self.client.allocator.free(response);

            // 提取内容
            if (self.client.extractJsonString(response, "\"content\"")) |content| {
                self.done = true;
                return StreamChunk{
                    .id = "stream",
                    .delta_content = content,
                    .delta_tool_calls = null,
                    .finish_reason = "stop",
                };
            }
        }

        self.done = true;
        return null;
    }
};

// ============================================================================
// 便捷构造函数
// ============================================================================

/// 创建 OpenAI 客户端
pub fn openai(allocator: Allocator, api_key: []const u8) !*AiClient {
    return AiClient.init(allocator, .{
        .provider = .openai,
        .api_key = api_key,
    });
}

/// 创建 DeepSeek 客户端
pub fn deepseek(allocator: Allocator, api_key: []const u8) !*AiClient {
    return AiClient.init(allocator, .{
        .provider = .deepseek,
        .api_key = api_key,
    });
}

/// 创建 Moonshot 客户端
pub fn moonshot(allocator: Allocator, api_key: []const u8) !*AiClient {
    return AiClient.init(allocator, .{
        .provider = .moonshot,
        .api_key = api_key,
    });
}

/// 创建 Claude 客户端
pub fn claude(allocator: Allocator, api_key: []const u8) !*AiClient {
    return AiClient.init(allocator, .{
        .provider = .claude,
        .api_key = api_key,
    });
}

/// 创建 Ollama 客户端（本地）
pub fn ollama(allocator: Allocator) !*AiClient {
    return AiClient.init(allocator, .{
        .provider = .ollama,
    });
}

/// 创建自定义客户端
pub fn custom(allocator: Allocator, base_url: []const u8, api_key: ?[]const u8) !*AiClient {
    return AiClient.init(allocator, .{
        .provider = .custom,
        .base_url = base_url,
        .api_key = api_key,
    });
}

// ============================================================================
// 测试
// ============================================================================

test "AiClient: 初始化和销毁" {
    const allocator = std.testing.allocator;

    var client = try AiClient.init(allocator, .{
        .provider = .openai,
        .api_key = "test-key",
    });
    defer client.deinit();

    try std.testing.expectEqual(Provider.openai, client.config.provider);
    try std.testing.expectEqualStrings("test-key", client.config.api_key.?);
}

test "AiClient: 默认URL和模型" {
    const allocator = std.testing.allocator;

    var client = try AiClient.init(allocator, .{
        .provider = .deepseek,
        .api_key = "test",
    });
    defer client.deinit();

    try std.testing.expectEqualStrings("https://api.deepseek.com/v1", client.getBaseUrl());
    try std.testing.expectEqualStrings("deepseek-chat", client.getDefaultModel());
}

test "Provider: 默认配置" {
    try std.testing.expectEqualStrings("https://api.openai.com/v1", Provider.openai.defaultBaseUrl());
    try std.testing.expectEqualStrings("gpt-4o", Provider.openai.defaultModel());

    try std.testing.expectEqualStrings("https://api.deepseek.com/v1", Provider.deepseek.defaultBaseUrl());
    try std.testing.expectEqualStrings("deepseek-chat", Provider.deepseek.defaultModel());

    try std.testing.expectEqualStrings("http://localhost:11434/v1", Provider.ollama.defaultBaseUrl());
    try std.testing.expectEqualStrings("llama3.2", Provider.ollama.defaultModel());
}

test "Role: 转换" {
    try std.testing.expectEqualStrings("system", Role.system.toString());
    try std.testing.expectEqualStrings("user", Role.user.toString());
    try std.testing.expectEqualStrings("assistant", Role.assistant.toString());

    try std.testing.expectEqual(Role.user, Role.fromString("user").?);
    try std.testing.expect(Role.fromString("invalid") == null);
}

test "Message: 便捷构造" {
    const sys = Message.system("你是助手");
    try std.testing.expectEqual(Role.system, sys.role);
    try std.testing.expectEqualStrings("你是助手", sys.content.?);

    const usr = Message.user("你好");
    try std.testing.expectEqual(Role.user, usr.role);

    const asst = Message.assistant("你好！");
    try std.testing.expectEqual(Role.assistant, asst.role);
}

test "JSON 字符串转义" {
    const allocator = std.testing.allocator;

    var client = try AiClient.init(allocator, .{});
    defer client.deinit();

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    try client.writeJsonString(buf.writer(allocator), "hello\nworld\"test");
    try std.testing.expectEqualStrings("hello\\nworld\\\"test", buf.items);
}

test "ChatRequest: 构建JSON" {
    const allocator = std.testing.allocator;

    var client = try AiClient.init(allocator, .{});
    defer client.deinit();

    var buf = std.ArrayListUnmanaged(u8){};
    defer buf.deinit(allocator);

    const request = ChatRequest{
        .messages = &.{
            Message.system("你是助手"),
            Message.user("你好"),
        },
        .temperature = 0.7,
        .max_tokens = 1000,
    };

    try client.buildChatRequestJson(buf.writer(allocator), request, "gpt-4");

    // 验证包含关键字段
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "\"model\":\"gpt-4\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "\"messages\":[") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "\"role\":\"system\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "\"role\":\"user\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "\"temperature\":0.70") != null);
    try std.testing.expect(std.mem.indexOf(u8, buf.items, "\"max_tokens\":1000") != null);
}

test "便捷函数" {
    const allocator = std.testing.allocator;

    var client1 = try openai(allocator, "key1");
    defer client1.deinit();
    try std.testing.expectEqual(Provider.openai, client1.config.provider);

    var client2 = try deepseek(allocator, "key2");
    defer client2.deinit();
    try std.testing.expectEqual(Provider.deepseek, client2.config.provider);

    var client3 = try ollama(allocator);
    defer client3.deinit();
    try std.testing.expectEqual(Provider.ollama, client3.config.provider);
}
